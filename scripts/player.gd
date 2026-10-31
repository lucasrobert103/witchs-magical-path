class_name AsterionPlayer
extends CharacterBody3D
## Free traversal controller. Visuals are kept independent of movement and physics.

signal magic_requested

const WALK_SPEED := 4.8
const RUN_SPEED := 8.0
const JUMP_SPEED := 7.8
const MAX_STAMINA := 100.0

var touch_move := Vector2.ZERO
var movement_enabled := true
var sprint_held := false
var speed := WALK_SPEED
var stamina := MAX_STAMINA
var is_gliding := false
var is_climbing := false
var is_sprinting := false
var orbit_yaw := 0.0
var orbit_pitch := -0.28
var gravity := 22.0
var _jump_buffer := 0.0
var _floor_grace := 0.0
var _cast_remaining := 0.0
var _air_time := 0.0
var _stamina_delay := 0.0
var _exhausted := false
var _visual: Node3D
var _camera_rig: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D


func _ready() -> void:
	name = "Asterion"
	floor_snap_length = 0.38
	floor_max_angle = deg_to_rad(48)
	floor_constant_speed = true
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.78
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.89
	add_child(collider)
	if ResourceLoader.exists("res://scripts/character_visual.gd"):
		var visual_script = load("res://scripts/character_visual.gd")
		_visual = visual_script.new()
	else:
		_visual = Node3D.new()
		push_warning("Character visual is not available yet.")
	add_child(_visual)
	_camera_rig = Node3D.new()
	_camera_rig.name = "CameraRig"
	add_child(_camera_rig)
	_camera_rig.top_level = true
	_camera_rig.global_position = global_position + Vector3(0, 1.25, 0)
	_camera_rig.rotation = Vector3(orbit_pitch, orbit_yaw, 0)
	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "CameraCollision"
	_spring_arm.spring_length = 6.8
	_spring_arm.margin = 0.22
	_spring_arm.collision_mask = 1
	var probe := SphereShape3D.new()
	probe.radius = 0.22
	_spring_arm.shape = probe
	_spring_arm.add_excluded_object(get_rid())
	_camera_rig.add_child(_spring_arm)
	_camera = Camera3D.new()
	_camera.name = "ThirdPersonCamera"
	_camera.fov = 64
	_camera.near = 0.08
	_camera.far = 450
	_camera.current = true
	_spring_arm.add_child(_camera)


func _physics_process(delta: float) -> void:
	_cast_remaining = maxf(_cast_remaining - delta, 0)
	if not movement_enabled:
		velocity = Vector3.ZERO
		touch_move = Vector2.ZERO
		sprint_held = false
		_jump_buffer = 0
		is_sprinting = false
		_update_camera(delta)
		_animate(delta)
		return
	if InputMap.has_action("jump") and Input.is_action_just_pressed("jump"):
		request_jump()
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back") + touch_move
	input_vector = input_vector.limit_length(1)
	var direction := Vector3(input_vector.x, 0, input_vector.y).rotated(Vector3.UP, orbit_yaw)
	if is_on_floor():
		_air_time = 0
		_floor_grace = 0.10
	else:
		_air_time += delta
		_floor_grace = maxf(_floor_grace - delta, 0)
	_jump_buffer = maxf(_jump_buffer - delta, 0)
	var wants_sprint := sprint_held or (InputMap.has_action("sprint") and Input.is_action_pressed("sprint"))
	is_sprinting = wants_sprint and is_on_floor() and direction.length_squared() > 0.1 and stamina > 0 and not _exhausted
	var desired_speed := RUN_SPEED if is_sprinting else WALK_SPEED
	var acceleration := 24.0 if is_on_floor() else 9.0
	if direction.length_squared() < 0.01:
		acceleration = 32.0 if is_on_floor() else 5.0
	velocity.x = move_toward(velocity.x, direction.x * desired_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * desired_speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y <= 0:
		velocity.y = -0.4
	# Buffered input and a short coyote window make ledge jumps forgiving.
	# No air jump, climbing or gliding: traversal serves the guided region puzzles.
	if _jump_buffer > 0 and _floor_grace > 0:
		_jump_buffer = 0
		_floor_grace = 0
		velocity.y = JUMP_SPEED
		_air_time = 0.02
	if is_sprinting:
		stamina = maxf(stamina - 12.0 * delta, 0)
		_stamina_delay = 0.7
		if stamina <= 0:
			is_sprinting = false
			_exhausted = true
	else:
		_stamina_delay = maxf(_stamina_delay - delta, 0)
		if _stamina_delay <= 0 and is_on_floor():
			stamina = minf(stamina + 26.0 * delta, MAX_STAMINA)
			if stamina >= 20:
				_exhausted = false
	move_and_slide()
	if direction.length_squared() > 0.01:
		var heading := atan2(-direction.x, -direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, heading, minf(delta * 12, 1))
	_update_camera(delta)
	_animate(delta)


func _update_camera(delta: float) -> void:
	_camera_rig.global_position = _camera_rig.global_position.lerp(global_position + Vector3(0, 1.25, 0), 1.0 - exp(-12.0 * delta))
	_camera_rig.rotation.x = lerp_angle(_camera_rig.rotation.x, orbit_pitch, 1.0 - exp(-16 * delta))
	_camera_rig.rotation.y = lerp_angle(_camera_rig.rotation.y, orbit_yaw, 1.0 - exp(-16 * delta))
	var target_fov := 70.0 if is_sprinting else 64.0
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-4 * delta))


func _animate(delta: float) -> void:
	if _visual.has_method("animate"):
		_visual.animate(delta, Vector2(velocity.x, velocity.z).length(), velocity.y, is_gliding, is_climbing, _cast_remaining > 0)


func orbit_camera(relative_motion: Vector2) -> void:
	if not movement_enabled:
		return
	orbit_yaw -= relative_motion.x * 0.005
	orbit_pitch = clampf(orbit_pitch - relative_motion.y * 0.0035, -0.95, 0.16)


func request_jump() -> void:
	if movement_enabled:
		_jump_buffer = 0.14


func cast_magic() -> void:
	if not movement_enabled or _cast_remaining > 0:
		return
	_cast_remaining = 0.75
	magic_requested.emit()


func reset_traversal() -> void:
	velocity = Vector3.ZERO
	touch_move = Vector2.ZERO
	sprint_held = false
	stamina = MAX_STAMINA
	is_gliding = false
	is_climbing = false
	is_sprinting = false
	_exhausted = false
	_jump_buffer = 0
	_floor_grace = 0
	_cast_remaining = 0
	_air_time = 0
	_stamina_delay = 0
	orbit_yaw = 0
	orbit_pitch = -0.28
	_camera_rig.global_position = global_position + Vector3(0, 1.25, 0)


func focus_on(target: Vector3) -> void:
	if not movement_enabled:
		return
	var direction := target - global_position
	if Vector2(direction.x, direction.z).length_squared() > 0.01:
		orbit_yaw = atan2(-direction.x, -direction.z)
		orbit_pitch = -0.25


func center_camera() -> void:
	if movement_enabled:
		orbit_yaw = _visual.rotation.y
		orbit_pitch = -0.28
