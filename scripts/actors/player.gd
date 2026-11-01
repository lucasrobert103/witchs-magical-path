class_name Player
extends Node3D
## Asterion: movement, jumping, casting, damage and 8-direction sprite animation.

signal cast_requested(origin: Vector3, direction: Vector3)
signal died
signal footstep

const SHEETS := {
	"idle": {"frames": 8, "fps": 6.0, "loop": true},
	"walk": {"frames": 8, "fps": 10.0, "loop": true},
	"run": {"frames": 8, "fps": 13.0, "loop": true},
	"cast": {"frames": 6, "fps": 15.0, "loop": false},
	"jump": {"frames": 4, "fps": 0.0, "loop": false},
	"kneel": {"frames": 6, "fps": 4.0, "loop": false},
	"hurt": {"frames": 1, "fps": 0.0, "loop": false},
}
const PIXELS_PER_METER := 210.0
const FRAME_H := 384
const FOOT := 18
const ROWS := 3  # front, side (facing right), back
const WALK_SPEED := 3.3
const RUN_SPEED := 6.2
const GRAVITY := 24.0
const JUMP_VELOCITY := 8.2
const RADIUS := 0.35
const MANA_COST := 9.0

var world  # World (untyped to avoid a cyclic class reference)
var vel := Vector3.ZERO
var facing := Vector3(0, 0, -1)
var on_ground := true
var move_input := Vector2.ZERO   # x right, y forward (from joystick / keys)
var run_held := false
var cam_yaw := 0.0
var control_enabled := true

var max_hp := 100.0
var hp := 100.0
var max_mana := 60.0
var mana := 60.0
var magic_unlocked := false
var essence := ""               # "", "moon", "flame"

var anim := "idle"
var anim_time := 0.0
var _anim_frame := 0
var _cast_timer := 0.0
var _cast_fired := false
var _cast_dir := Vector3.FORWARD
var _hurt_timer := 0.0
var _invuln := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _mana_delay := 0.0
var _kneel_hold := 0.0
var _last_step_frame := -1
var dead := false
var _row := 2

var sprite: Sprite3D
var shadow: MeshInstance3D
var hand_glow: MeshInstance3D
var _textures := {}

func _ready() -> void:
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = 1.0 / PIXELS_PER_METER
	sprite.offset = Vector2(0, FRAME_H * 0.5 - FOOT)
	sprite.modulate = Color(0.96, 0.95, 0.92)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	for key in SHEETS.keys():
		_textures[key] = load("res://assets/sprites/witch/%s.png" % key)
	shadow = Props.blob_shadow(1.1, 0.6)
	add_child(shadow)
	hand_glow = Props.glow(Color(1.0, 0.9, 0.6), 0.9, 0.0)
	hand_glow.position = Vector3(0, 1.15, 0)
	add_child(hand_glow)
	_set_anim("idle")

func reset_state(full := true) -> void:
	vel = Vector3.ZERO
	dead = false
	_hurt_timer = 0.0
	_invuln = 0.0
	_cast_timer = 0.0
	if full:
		hp = max_hp
		mana = max_mana
	_set_anim("idle")

func start_kneeling(hold: float) -> void:
	_kneel_hold = hold
	_set_anim("kneel")
	anim_time = 0.0

func is_busy() -> bool:
	return anim == "kneel" or dead

func _set_anim(name: String) -> void:
	if anim == name and sprite.texture == _textures[name]:
		return
	anim = name
	anim_time = 0.0
	sprite.texture = _textures[name]
	sprite.hframes = SHEETS[name]["frames"]
	sprite.vframes = ROWS

func request_jump() -> void:
	_jump_buffer = 0.15

func request_cast() -> bool:
	if not magic_unlocked or dead or anim == "kneel" or _cast_timer > 0.0:
		return false
	if mana < MANA_COST:
		Audio.sfx("click", -12.0)
		return false
	mana -= MANA_COST
	_mana_delay = 0.9
	_cast_timer = 0.42
	_cast_fired = false
	var target = world.find_magic_target(global_position, facing) if world else null
	if target:
		var to: Vector3 = target.global_position - global_position
		to.y = 0
		if to.length() > 0.1:
			facing = to.normalized()
	_cast_dir = facing
	_set_anim("cast")
	return true

func take_damage(amount: float, from: Vector3) -> void:
	if _invuln > 0.0 or dead:
		return
	hp = maxf(0.0, hp - amount)
	_invuln = 1.1
	_hurt_timer = 0.35
	var away := global_position - from
	away.y = 0
	if away.length() > 0.01:
		vel = away.normalized() * 6.0 + Vector3(0, 3.5, 0)
		on_ground = false
	Audio.sfx("hurt", -2.0)
	_set_anim("hurt")
	if hp <= 0.0:
		dead = true
		died.emit()

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)

func restore_mana(amount: float) -> void:
	mana = minf(max_mana, mana + amount)

func tick(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_mana_delay = maxf(0.0, _mana_delay - delta)
	if magic_unlocked and _mana_delay <= 0.0:
		mana = minf(max_mana, mana + 7.0 * delta)
	sprite.visible = _invuln <= 0.0 or int(_invuln * 14.0) % 2 == 0 or dead

	var can_move := control_enabled and not dead and anim != "kneel" and _hurt_timer <= 0.0
	# Desired horizontal velocity from input relative to the camera.
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var wish := Vector3.ZERO
	var stick := move_input.limit_length(1.0)
	if can_move:
		wish = right * stick.x + fwd * stick.y
	var running := run_held or stick.length() > 0.92
	var speed := RUN_SPEED if running else WALK_SPEED
	if _cast_timer > 0.0:
		speed *= 0.35
	var target_v := wish * speed
	var accel := 22.0 if on_ground else 8.0
	if _hurt_timer > 0.0:
		accel = 2.0
	var hv := Vector3(vel.x, 0, vel.z)
	hv = hv.move_toward(target_v, accel * delta)
	vel.x = hv.x
	vel.z = hv.z
	if wish.length() > 0.08 and _cast_timer <= 0.0:
		facing = facing.slerp(wish.normalized(), clampf(delta * 12.0, 0.0, 1.0)).normalized()

	# Jumping with coyote time and input buffering.
	if on_ground:
		_coyote = 0.12
	else:
		_coyote = maxf(0.0, _coyote - delta)
	if can_move and _jump_buffer > 0.0 and _coyote > 0.0:
		vel.y = JUMP_VELOCITY
		on_ground = false
		_coyote = 0.0
		_jump_buffer = 0.0
		Audio.sfx("jump", -6.0)
	if not on_ground:
		vel.y -= GRAVITY * delta

	# Integrate and collide on the XZ plane.
	var p := global_position
	var next := Vector2(p.x + vel.x * delta, p.z + vel.z * delta)
	if world:
		next = world.terrain.resolve(next, RADIUS, p.y)
		next = world.terrain.clamp_walkable(next, RADIUS)
	var ground := world.terrain.height(next.x, next.y) if world else 0.0
	var ny := p.y + vel.y * delta
	if on_ground:
		# Stick to gentle slopes.
		ny = ground
		vel.y = 0.0
	elif ny <= ground:
		ny = ground
		if vel.y < -2.0:
			Audio.sfx("land", -8.0)
		vel.y = 0.0
		on_ground = true
	if on_ground and ground < p.y - 0.6:
		on_ground = false
	global_position = Vector3(next.x, ny, next.y)
	shadow.global_position = Vector3(next.x, ground + 0.03, next.y)
	var air := clampf(1.0 - (ny - ground) / 3.0, 0.3, 1.0)
	shadow.scale = Vector3.ONE * air

	# Casting.
	if _cast_timer > 0.0:
		_cast_timer -= delta
		if not _cast_fired and _cast_timer < 0.26:
			_cast_fired = true
			var origin := global_position + Vector3(0, 1.15, 0) + _cast_dir * 0.55
			cast_requested.emit(origin, _cast_dir)
	var glow_mat: ShaderMaterial = hand_glow.material_override
	var glow_target := 0.0
	if _cast_timer > 0.0:
		glow_target = 1.6
	elif magic_unlocked and mana >= max_mana * 0.99:
		glow_target = 0.0
	glow_mat.set_shader_parameter("energy", lerpf(float(glow_mat.get_shader_parameter("energy")), glow_target, clampf(delta * 10.0, 0.0, 1.0)))
	glow_mat.set_shader_parameter("color", essence_color())
	hand_glow.position = Vector3(0, 1.15, 0) + facing * 0.45

	_update_anim(delta, Vector2(vel.x, vel.z).length(), running)

func essence_color() -> Color:
	match essence:
		"moon":
			return Color(0.45, 0.85, 1.0)
		"flame":
			return Color(1.0, 0.65, 0.28)
	return Color(1.0, 0.92, 0.65)

func _update_anim(delta: float, hspeed: float, running: bool) -> void:
	anim_time += delta
	var want := anim
	if dead:
		want = "hurt"
	elif anim == "kneel":
		if _kneel_hold > 0.0:
			_kneel_hold -= delta
			anim_time = 0.0
		elif anim_time * SHEETS["kneel"]["fps"] >= SHEETS["kneel"]["frames"] + 0.5:
			want = "idle"
	elif _hurt_timer > 0.0:
		want = "hurt"
	elif _cast_timer > 0.0:
		want = "cast"
	elif not on_ground:
		want = "jump"
	elif hspeed > 0.3:
		want = "run" if (running and hspeed > WALK_SPEED + 0.4) else "walk"
	else:
		want = "idle"
	if want != anim:
		_set_anim(want)
	var info: Dictionary = SHEETS[anim]
	var n: int = info["frames"]
	var f := 0
	match anim:
		"jump":
			f = 0 if vel.y > 2.5 else (1 if vel.y > -1.5 else 2)
		"walk":
			f = int(anim_time * info["fps"] * clampf(hspeed / WALK_SPEED, 0.6, 1.4)) % n
		"run":
			f = int(anim_time * info["fps"] * clampf(hspeed / RUN_SPEED, 0.7, 1.2)) % n
		_:
			if info["fps"] > 0.0:
				f = int(anim_time * info["fps"])
				f = f % n if info["loop"] else mini(f, n - 1)
	_anim_frame = f
	if (anim == "walk" or anim == "run") and (f == 2 or f == 6) and f != _last_step_frame:
		footstep.emit()
		Audio.sfx("step%d" % (randi() % 4), -16.0 if anim == "walk" else -12.0, 0.12)
	_last_step_frame = f
	_apply_direction()

## Picks one of the five drawn directions (mirrored for the other side).
func _apply_direction() -> void:
	var cam := get_viewport().get_camera_3d()
	var row := 2
	var flip := false
	if cam:
		var local := cam.global_transform.basis.inverse() * facing
		var ang := rad_to_deg(atan2(local.x, local.z))  # 0 = toward camera
		var a := absf(ang)
		# Hysteresis avoids flickering between views near the boundaries.
		var lo := 50.0 if _row == 0 else 40.0
		var hi := 130.0 if _row == 2 else 140.0
		if a < lo:
			row = 0
		elif a < hi:
			row = 1
		else:
			row = 2
		flip = ang < 0.0
	_row = row
	sprite.flip_h = flip
	sprite.frame = row * int(SHEETS[anim]["frames"]) + _anim_frame
