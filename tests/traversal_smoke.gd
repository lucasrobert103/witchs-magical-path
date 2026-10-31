extends SceneTree
## Exercises the actual guided-region controller against collision geometry.
var checks := 0
var failures := 0
var player: CharacterBody3D
var magic_count := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _ticks(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = at
	body.add_child(shape)
	root.add_child(body)
	return body

func _run() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "jump", "sprint"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var ground := _box(Vector3(0, -0.25, 0), Vector3(200, 0.5, 200))
	var wall := _box(Vector3(0, 2, 3), Vector3(6, 4, 0.4))
	player = load("res://scripts/player.gd").new()
	root.add_child(player)
	player.position = Vector3(0, 0.05, 0)
	player.magic_requested.connect(func() -> void: magic_count += 1)
	await _ticks(12)
	_check(player.is_on_floor(), "Capsule stands on ground")
	_check(player._spring_arm.get_hit_length() < 4.0, "Camera spring arm retracts before an obstacle")
	wall.queue_free()
	await _ticks(4)
	var start: Vector3 = player.position
	player.touch_move = Vector2(0, -1)
	await _ticks(45)
	_check(player.position.z < start.z - 2.0, "Forward touch movement follows camera")
	player.movement_enabled = false
	await _ticks(1)
	var stopped: Vector3 = player.position
	player.touch_move = Vector2(1, 0)
	player.request_jump()
	await _ticks(8)
	_check(player.position.distance_to(stopped) < 0.001, "Pausing stops movement immediately")
	player.movement_enabled = true
	player.touch_move = Vector2.ZERO
	await _ticks(3)
	var ground_y: float = player.position.y
	player.request_jump()
	await _ticks(10)
	_check(player.position.y > ground_y + 0.6, "Jump lifts the character above the ground")
	var airborne_velocity: float = player.velocity.y
	player.request_jump()
	await _ticks(2)
	_check(player.velocity.y < airborne_velocity, "A second airborne press cannot double-jump")
	await _ticks(65)
	_check(player.is_on_floor() and absf(player.position.y - ground_y) < 0.03, "Jump lands back on collision floor")
	player.touch_move = Vector2(0, -1)
	player.sprint_held = true
	await _ticks(70)
	_check(player.is_sprinting and absf(player.velocity.z) > 7.0, "Sprint is faster than walking")
	_check(player.stamina < 90.0, "Sprint consumes stamina")
	player.touch_move = Vector2.ZERO
	player.sprint_held = false
	var spent: float = player.stamina
	await _ticks(95)
	_check(player.stamina > spent, "Resting restores stamina after delay")
	player.stamina = 0.1
	player.touch_move = Vector2(0, -1)
	player.sprint_held = true
	await _ticks(5)
	_check(player.stamina <= 0 and not player.is_sprinting, "Exhaustion prevents sprinting")
	player.touch_move = Vector2.ZERO
	player.sprint_held = false
	await _ticks(110)
	_check(player.stamina > 20.0, "Exhausted stamina recovers")
	player.reset_traversal()
	player.focus_on(player.position + Vector3(10, 0, 0))
	await _ticks(20)
	_check(absf(player.orbit_yaw + PI * 0.5) < 0.01, "Focus turns camera toward target")
	var focused_position: Vector3 = player.position
	player.touch_move = Vector2(0, -1)
	await _ticks(25)
	_check(player.position.x > focused_position.x + 0.7, "Movement follows the focused camera direction")
	player.cast_magic()
	player.cast_magic()
	_check(magic_count == 1, "Magic cooldown prevents duplicate activation")
	player.movement_enabled = false
	player.cast_magic()
	_check(magic_count == 1, "Pause prevents magic activation")
	_check(not player.is_gliding and not player.is_climbing, "Traversal follows guided-region design without glide or climb")
	player.queue_free()
	ground.queue_free()
	await process_frame
	print("TRAVERSAL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
