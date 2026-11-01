class_name CameraRig
extends Node3D
## Third-person orbit camera that eases behind Asterion while she moves.

var cam: Camera3D
var yaw := 0.0
var pitch := deg_to_rad(17.0)
var distance := 5.1
var target_height := 1.25
var _focus := Vector3.ZERO
var _manual_timer := 0.0
var _shake := 0.0
var cinematic := false
var cine_pos := Vector3.ZERO
var cine_look := Vector3.ZERO

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 52.0
	cam.near = 0.1
	cam.far = 95.0
	cam.current = true
	add_child(cam)

func rotate_by(dx: float, dy: float) -> void:
	var sens := float(Game.settings.get("sensitivity", 1.0))
	yaw -= dx * 0.0055 * sens
	pitch = clampf(pitch + dy * 0.004 * sens, deg_to_rad(4.0), deg_to_rad(48.0))
	_manual_timer = 1.6

func snap_behind(dir: Vector3) -> void:
	yaw = atan2(-dir.x, -dir.z)

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func update(delta: float, player: Player, terrain: Terrain) -> void:
	_manual_timer = maxf(0.0, _manual_timer - delta)
	if cinematic:
		cam.global_position = cam.global_position.lerp(cine_pos, clampf(delta * 1.6, 0.0, 1.0))
		_look(cam.global_position, cine_look)
		return
	var target := player.global_position + Vector3(0, target_height, 0)
	_focus = _focus.lerp(target, clampf(delta * 8.0, 0.0, 1.0)) if _focus != Vector3.ZERO else target
	# Auto-follow: drift behind the movement direction when the player isn't steering the camera.
	var hv := Vector2(player.vel.x, player.vel.z)
	if _manual_timer <= 0.0 and hv.length() > 1.0 and player.move_input.y > -0.3:
		var want := atan2(-player.vel.x, -player.vel.z)
		yaw = lerp_angle(yaw, want, clampf(delta * 0.9 * clampf(hv.length() / 4.0, 0.2, 1.0), 0.0, 1.0))
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	var pos := _focus + off
	var ground := terrain.height(pos.x, pos.z) + 0.6
	if pos.y < ground:
		pos.y = ground
	if _shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.15
		_shake = maxf(0.0, _shake - delta * 2.5)
	cam.global_position = pos
	_look(pos, _focus + Vector3(0, 0.15, 0))

func _look(from: Vector3, to: Vector3) -> void:
	if from.distance_to(to) > 0.01:
		cam.look_at_from_position(from, to, Vector3.UP)
