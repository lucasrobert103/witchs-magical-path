extends SceneTree
## Integration: actual scene, terrain collision, contextual reading, ordered
## puzzle, closed/open gate traversal, completion and clean replay.

var failures := 0
var checks := 0
var game: Node3D


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func ticks(count: int) -> void:
	for tick in range(count):
		await physics_frame


func at(position: Vector3) -> void:
	game.player.position = position + Vector3(0, 0.08, 1.6)
	game.player.reset_traversal()
	await ticks(3)


func cast_at(index: int) -> void:
	await at(game.forest.landmarks[index].position)
	game._request_magic()
	await ticks(48)


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene loads")
	if scene == null:
		quit(1)
		return
	game = scene.instantiate()
	game.autosave_path = "user://smoke-journey.cfg"
	root.add_child(game)
	await process_frame
	await ticks(2)
	check(not game.player.movement_enabled and game.title_camera.current, "Menu uses cinematic view and prevents movement")
	check(game.player._visual.get_child_count() > 10, "Authored anime visual is attached to the player")
	game.interface._begin_prologue()
	check(game.interface._prologue.visible, "Cosmological opening precedes exploration")
	game.interface._finish_prologue()
	await ticks(4)
	check(game.journey_started and game.player.movement_enabled, "Skipping opening starts exploration")
	check(game.player._camera.current, "Gameplay takes over the third-person camera")
	var start: Vector3 = game.player.position
	game._move_touch(Vector2(0, -1))
	await ticks(45)
	check(game.player.position.z < start.z - 2.0, "Touch movement advances along entrance path")
	game._move_touch(Vector2.ZERO)
	await ticks(15)
	var floor_y: float = game.forest.ground_height(game.player.position.x, game.player.position.z)
	check(absf(game.player.position.y - floor_y) < 0.25, "Generated terrain matches physical floor")
	game.interface._set_paused(true)
	var stopped: Vector3 = game.player.position
	game._move_touch(Vector2(1, 0))
	game._request_magic()
	await ticks(12)
	check(game.player.position.distance_to(stopped) < 0.01, "Pause blocks movement and actions")
	game.interface._set_paused(false)
	await at(game.forest.inscription_position)
	game._request_magic()
	check(game.clue_read and game.interface._clue.visible and game.is_paused, "Contextual reading opens the inscription and pauses controls")
	game.interface._clue.hide()
	game.interface._set_paused(false)
	# An incorrect source must not increment progress or unlock the gate.
	await cast_at(1)
	check(game.puzzle_progress == 0 and not game.forest.gate_open, "Wrong first source cannot bypass the enigma")
	await cast_at(0)
	check(game.puzzle_progress == 1, "Water starts the sequence")
	await cast_at(2)
	check(game.puzzle_progress == 0, "Out-of-order light resets active sources")
	# Check the physical gate while it is closed, with the real player capsule.
	game.player.position = Vector3(0, game.forest.ground_height(0, -30) + 0.08, -30)
	game.player.reset_traversal()
	game._move_touch(Vector2(0, -1))
	await ticks(80)
	check(game.player.position.z > -34.1, "Closed gate physically blocks the next region")
	game._move_touch(Vector2.ZERO)
	await cast_at(0)
	await cast_at(1)
	await cast_at(2)
	check(game.puzzle_progress == 3 and game.forest.gate_open, "Water → root → light opens the passage")
	check(not game.discovered, "Solving puzzle does not skip exploration of next area")
	await ticks(120)
	game.player.position = Vector3(0, game.forest.ground_height(0, -30) + 0.08, -30)
	game.player.reset_traversal()
	game._move_touch(Vector2(0, -1))
	await ticks(100)
	check(game.player.position.z < -35, "Opened passage permits physical traversal")
	game._move_touch(Vector2.ZERO)
	await at(game.forest.destination_position)
	await ticks(4)
	check(game.discovered and game.interface._discovery.visible, "Reaching sanctuary completes this guided region")
	var save := ConfigFile.new()
	check(save.load(game.autosave_path) == OK and save.get_value("region", "puzzle_solved", false), "Completion records the resolved puzzle locally")
	game._start_game()
	check(game.puzzle_progress == 0 and not game.forest.gate_open and not game.discovered, "Replay clears puzzle, gate and completion")
	await ticks(110)
	check(not game.forest.gate_open, "Replay cancels any gate animation still in progress")
	game.interface.show_title()
	check(not game.player.movement_enabled and game.title_camera.current, "Returning to title restores cinematic view")
	game.queue_free()
	DirAccess.remove_absolute("user://smoke-journey.cfg")
	await process_frame
	print("\nINTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
