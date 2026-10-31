class_name AsterionPlayer
extends CharacterBody3D
## Playable placeholder. The tunic is temporary, not the approved final outfit.
## Meshes suggest the established silhouette; a production 3D model is still needed.

signal magic_requested

var touch_move: Vector2 = Vector2.ZERO
var movement_enabled: bool = true
var speed: float = 4.5
var orbit_yaw: float = 0.0
var orbit_pitch: float = -0.23
var gravity: float = 18.0
var _walk_time: float = 0.0
var _cast_remaining: float = 0.0
var _visual: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _camera_rig: Node3D
var _camera: Camera3D
var _magic_orb: MeshInstance3D
var _magic_light: OmniLight3D

func _ready() -> void:
	name = "Asterion"
	floor_snap_length = 0.3
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.88
	add_child(collider)
	_build_character()
	_camera_rig = Node3D.new()
	_camera_rig.name = "CameraRig"
	add_child(_camera_rig)
	_camera_rig.top_level = true
	_camera_rig.global_position = global_position + Vector3(0.0, 1.15, 0.0)
	_camera_rig.rotation = Vector3(orbit_pitch, orbit_yaw, 0.0)
	_camera = Camera3D.new()
	_camera.name = "ThirdPersonCamera"
	_camera.fov = 60.0
	_camera.near = 0.12
	_camera.far = 140.0
	_camera.current = true
	_camera_rig.add_child(_camera)
	_camera.position.z = 5.2

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if movement_enabled:
		input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back") + touch_move
		input_vector = input_vector.limit_length(1.0)
	var direction := Vector3(input_vector.x, 0.0, input_vector.y).rotated(Vector3.UP, orbit_yaw)
	var acceleration: float = 16.0 if direction.length_squared() > 0.001 else 22.0
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.4
	move_and_slide()
	if direction.length_squared() > 0.01:
		var heading := atan2(-direction.x, -direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, heading, minf(delta * 12.0, 1.0))
	_animate(delta, Vector2(velocity.x, velocity.z).length())
	_camera_rig.global_position = _camera_rig.global_position.lerp(global_position + Vector3(0.0, 1.15, 0.0), 1.0 - exp(-12.0 * delta))
	_camera_rig.rotation = Vector3(orbit_pitch, orbit_yaw, 0.0)

func orbit_camera(relative_motion: Vector2) -> void:
	if not movement_enabled:
		return
	orbit_yaw -= relative_motion.x * 0.006
	orbit_pitch = clampf(orbit_pitch - relative_motion.y * 0.004, -0.72, -0.06)

func cast_magic() -> void:
	if not movement_enabled or _cast_remaining > 0.0:
		return
	_cast_remaining = 0.75
	magic_requested.emit()

func _animate(delta: float, horizontal_speed: float) -> void:
	_walk_time += delta * horizontal_speed * 2.1
	var walking := clampf(horizontal_speed / speed, 0.0, 1.0)
	var swing := sin(_walk_time) * 0.48 * walking
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	_left_arm.rotation.x = -swing * 0.75
	_right_arm.rotation.x = swing * 0.75
	_visual.position.y = absf(sin(_walk_time)) * 0.035 * walking
	if _cast_remaining > 0.0:
		_cast_remaining = maxf(_cast_remaining - delta, 0.0)
		_right_arm.rotation.x = -1.25
		var phase: float = 1.0 - _cast_remaining / 0.75
		_magic_orb.visible = true
		_magic_orb.scale = Vector3.ONE * (0.55 + sin(phase * PI) * 0.65)
		_magic_light.light_energy = sin(phase * PI) * 1.8
	else:
		_magic_orb.visible = false
		_magic_light.light_energy = 0.0

func _build_character() -> void:
	_visual = Node3D.new()
	_visual.name = "TemporaryCharacterModel"
	add_child(_visual)
	var skin := _material(Color("a56b48"))
	var hair := _material(Color("302018"))
	var fabric := _material(Color("637068"))
	var dark_fabric := _material(Color("353f39"))
	var amber := _material(Color("e8b249"))
	var eye_white := _material(Color("f0e3cf"))
	# Waist, shoulders and hips retain a curved silhouette without final-costume claims.
	_sphere(_visual, Vector3(0.0, 1.13, 0.0), Vector3(0.48, 0.51, 0.31), fabric)
	_sphere(_visual, Vector3(0.0, 0.92, 0.015), Vector3(0.39, 0.34, 0.29), fabric)
	_sphere(_visual, Vector3(0.0, 0.75, 0.015), Vector3(0.59, 0.40, 0.37), fabric)
	_sphere(_visual, Vector3(0.0, 1.43, 0.0), Vector3(0.16, 0.19, 0.17), skin)
	_sphere(_visual, Vector3(0.0, 1.65, -0.01), Vector3(0.36, 0.43, 0.33), skin)
	_sphere(_visual, Vector3(0.0, 1.73, 0.055), Vector3(0.40, 0.35, 0.37), hair)
	# The face points along -Z.
	for side: float in [-1.0, 1.0]:
		_sphere(_visual, Vector3(side * 0.073, 1.665, -0.158), Vector3(0.065, 0.040, 0.021), eye_white)
		_sphere(_visual, Vector3(side * 0.073, 1.665, -0.17), Vector3(0.029, 0.034, 0.012), amber)
		_sphere(_visual, Vector3(side * 0.073, 1.665, -0.178), Vector3(0.012, 0.023, 0.009), hair)
	_sphere(_visual, Vector3(0.0, 1.62, -0.174), Vector3(0.04, 0.05, 0.05), skin)
	_sphere(_visual, Vector3(0.0, 1.56, -0.152), Vector3(0.065, 0.012, 0.015), _material(Color("78452f")))
	_build_curls(hair)
	_left_arm = _limb(_visual, Vector3(-0.27, 1.27, 0.0), Vector3(0.12, 0.45, 0.13), skin, Vector3(0.0, -0.2, 0.0))
	_right_arm = _limb(_visual, Vector3(0.27, 1.27, 0.0), Vector3(0.12, 0.45, 0.13), skin, Vector3(0.0, -0.2, 0.0))
	_sphere(_left_arm, Vector3(0.0, -0.41, 0.0), Vector3(0.12, 0.14, 0.11), skin)
	_sphere(_right_arm, Vector3(0.0, -0.41, 0.0), Vector3(0.12, 0.14, 0.11), skin)
	_left_leg = _limb(_visual, Vector3(-0.13, 0.68, 0.0), Vector3(0.17, 0.56, 0.18), dark_fabric, Vector3(0.0, -0.23, 0.0))
	_right_leg = _limb(_visual, Vector3(0.13, 0.68, 0.0), Vector3(0.17, 0.56, 0.18), dark_fabric, Vector3(0.0, -0.23, 0.0))
	_sphere(_left_leg, Vector3(0.0, -0.58, -0.045), Vector3(0.18, 0.16, 0.29), dark_fabric)
	_sphere(_right_leg, Vector3(0.0, -0.58, -0.045), Vector3(0.18, 0.16, 0.29), dark_fabric)
	var glow := _material(Color("8ee5ca"))
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_magic_orb = _sphere(_right_arm, Vector3(0.0, -0.48, 0.0), Vector3(0.2, 0.2, 0.2), glow)
	_magic_orb.visible = false
	_magic_light = OmniLight3D.new()
	_magic_light.light_color = Color("8ee5ca")
	_magic_light.omni_range = 3.5
	_magic_light.light_energy = 0.0
	_magic_orb.add_child(_magic_light)

func _build_curls(material: StandardMaterial3D) -> void:
	# Low-resolution curved strands are batched into one draw call for mobile.
	var curl_mesh := SphereMesh.new()
	curl_mesh.radius = 0.5
	curl_mesh.height = 1.0
	curl_mesh.radial_segments = 8
	curl_mesh.rings = 4
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = curl_mesh
	instances.instance_count = 12 * 10
	for strand: int in range(12):
		var angle: float = float(strand) / 12.0 * TAU
		for segment: int in range(10):
			var phase: float = float(segment) * 1.55 + float(strand) * 0.7
			var t: float = float(segment) / 9.0
			var position := Vector3(sin(angle) * 0.17 + sin(phase) * 0.025, 1.75 - t * 0.83, 0.11 + absf(cos(angle)) * 0.085 + cos(phase) * 0.025)
			var width: float = 0.10 - t * 0.025
			instances.set_instance_transform(strand * 10 + segment, Transform3D(Basis.IDENTITY.scaled(Vector3(width, 0.125, width)), position))
	var curls := MultiMeshInstance3D.new()
	curls.name = "WaistLengthDarkCurls"
	curls.multimesh = instances
	curls.material_override = material
	_visual.add_child(curls)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material

func _sphere(parent: Node3D, position_value: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	instance.scale = size
	parent.add_child(instance)
	return instance

func _limb(parent: Node3D, position_value: Vector3, size: Vector3, material: StandardMaterial3D, mesh_offset: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = position_value
	parent.add_child(pivot)
	_sphere(pivot, mesh_offset, size, material)
	return pivot
