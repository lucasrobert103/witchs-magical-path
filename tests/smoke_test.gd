extends SceneTree
## Runs the actual scene and game loop, independent of a rendering device.
## godot --headless --path . --script res://tests/smoke_test.gd

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "Main scene loads")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	game.autosave_path = "user://smoke-discovery.cfg"
	root.add_child(game)
	await process_frame
	await physics_frame
	check(not game.player.movement_enabled, "Menu prevents gameplay movement")
	game.interface._begin_prologue()
	check(game.interface._prologue.visible, "Opening starts before exploration")
	game.interface._finish_prologue()
	check(game.journey_started and game.player.movement_enabled, "Skipping prologue starts the journey")
	check(root.get_camera_3d() != null, "Third-person camera is active")
	var start: Vector3 = game.player.position
	game._move_touch(Vector2(0, -1))
	for tick in range(55):
		await physics_frame
	check(game.player.position.z < start.z - 2.0, "Touch input moves toward forest objective")
	check(game.player.position.y > -0.1, "Ground collision prevents falling")
	game.interface._set_paused(true)
	for tick in range(20):
		await physics_frame
	var stopped: Vector3 = game.player.position
	game._move_touch(Vector2(1, 0))
	game._request_magic()
	for tick in range(20):
		await physics_frame
	check(game.player.position.distance_to(stopped) < 0.05, "Pause blocks locomotion")
	check(not game.discovered, "Pause prevents discovery")
	game.interface._set_paused(false)
	game._request_magic()
	check(not game.discovered, "Magic outside interaction range cannot complete objective")
	for tick in range(50):
		await physics_frame
	game.player.position = game.forest.flower_position + Vector3(0, 0.08, 2)
	game.player.velocity = Vector3.ZERO
	game._request_magic()
	check(game.discovered and game.forest.awakened, "Nearby magic changes the flower and completes objective")
	check(game.interface._discovery.visible and game.is_paused, "Discovery displays completion and releases controls")
	var save := ConfigFile.new()
	check(save.load(game.autosave_path) == OK and save.get_value("prototype", "discovered", false), "Completed milestone writes local record")
	game._restart()
	check(not game.discovered and not game.forest.awakened, "Replay resets objective and flower")
	check(game.player.position.distance_to(Vector3(0, 0.08, 8)) < 0.01, "Replay restores spawn point")
	check(game.player.movement_enabled and not game.is_paused, "Replay restores gameplay controls")
	for tick in range(85):
		await physics_frame
	check(game.forest.flower.scale.is_equal_approx(Vector3.ONE), "Replay cancels a discovery animation already in progress")
	game.interface.show_title()
	check(not game.player.movement_enabled, "Returning to title disables movement")
	game.queue_free()
	DirAccess.remove_absolute("user://smoke-discovery.cfg")
	await process_frame
	print("\n%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
