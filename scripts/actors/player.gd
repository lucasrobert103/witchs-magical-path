class_name Player
extends Node3D
## Asterion: movement, jumping, casting, damage and 8-direction sprite animation.

signal cast_requested(origin: Vector3, direction: Vector3)
signal died
signal footstep

const SHEETS := {
	"idle": {"frames": 12, "fps": 6.0, "loop": true},
	"walk": {"frames": 12, "fps": 14.0, "loop": true},
	"run": {"frames": 10, "fps": 17.0, "loop": true},
	"sigh": {"frames": 12, "fps": 8.0, "loop": false},
	"wind": {"frames": 12, "fps": 9.0, "loop": false},
	"shift": {"frames": 12, "fps": 6.0, "loop": false},
	"cast": {"frames": 6, "fps": 15.0, "loop": false},
	"jump": {"frames": 4, "fps": 0.0, "loop": false},
	"kneel": {"frames": 6, "fps": 4.0, "loop": false},
	"hurt": {"frames": 1, "fps": 0.0, "loop": false},
}
const PIXELS_PER_METER := 210.0
const FRAME_H := 384
const FOOT := 18
const ROWS := 3  # front, side (facing right), back
const WALK_SPEED := 2.7
const RUN_SPEED := 6.0
const IDLE_VARIANTS := ["sigh", "wind", "shift"]
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
var run_toggle := false          # the on-screen "Correr" button
var _still_t := 0.0
var _run_time := 0.0          # how long she has been running (to catch her breath after)
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
var _kneel_in := 0.0          # >0 while lowering herself (kneel frames played backwards)
var _last_step_frame := -1
var dead := false
var _row := 2
var _cycle := 0.0              # walk/run phase, continuous across speed changes
var _lean := 0.0
var _squash := 1.0
var _squash_v := 0.0
var _heading := 0.0
var dust: CPUParticles3D

var sprite: Sprite3D
var shadow: MeshInstance3D
var hand_glow: MeshInstance3D
var _textures := {}
var _mat: ShaderMaterial
var ghost: Sprite3D            # previous view, cross-faded when Asterion turns
var _ghost_mat: ShaderMaterial
var _ghost_a := 0.0
var _last_row := -1
var _last_flip := false
var look_target := Vector3.INF # set by the world when she pauses to observe
var carrying := ""             # "water" while holding a ribbon of river water
var water_orb: Node3D

func _ready() -> void:
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = 1.0 / PIXELS_PER_METER
	sprite.offset = Vector2(0, FRAME_H * 0.5 - FOOT)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/character.gdshader")
	sprite.material_override = _mat
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	ghost = Sprite3D.new()
	ghost.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	ghost.shaded = false
	ghost.double_sided = true
	ghost.pixel_size = sprite.pixel_size
	ghost.offset = sprite.offset
	_ghost_mat = ShaderMaterial.new()
	_ghost_mat.shader = _mat.shader
	ghost.material_override = _ghost_mat
	ghost.sorting_offset = -0.01
	ghost.visible = false
	add_child(ghost)
	water_orb = Node3D.new()
	water_orb.add_child(Props.glow(Color(0.45, 0.85, 1.0), 0.9, 1.0, "fx/soft_dot.png", 0.2))
	water_orb.add_child(Props.glow(Color(0.85, 0.97, 1.0), 0.35, 1.2, "fx/soft_core.png"))
	var drops := Props.particles("fx/soft_dot.png", 14, 0.7, 0.1, Color(0.6, 0.9, 1.0))
	drops.emitting = true
	drops.gravity = Vector3(0, -3, 0)
	drops.spread = 180.0
	drops.initial_velocity_min = 0.2
	drops.initial_velocity_max = 0.6
	water_orb.add_child(drops)
	water_orb.visible = false
	add_child(water_orb)
	dust = Props.particles("fx/soft_dot.png", 18, 0.8, 0.45, Color(0.62, 0.52, 0.4, 0.55), false)
	dust.local_coords = false
	dust.direction = Vector3.UP
	dust.spread = 70.0
	dust.initial_velocity_min = 0.3
	dust.initial_velocity_max = 0.9
	dust.gravity = Vector3(0, 0.2, 0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.2
	dust.emitting = false
	add_child(dust)
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

func start_kneeling(hold: float, smooth := false) -> void:
	_kneel_hold = hold
	_kneel_in = 0.5 if smooth else 0.0
	_set_anim("kneel")
	anim_time = 0.0

func stand_up() -> void:
	_kneel_hold = 0.0

## Small idle reactions (a sigh, the wind in her hair, shifting her weight).
func play_idle(name: String) -> bool:
	if anim != "idle" or not on_ground or dead or Vector2(vel.x, vel.z).length() > 0.1:
		return false
	_set_anim(name)
	return true

func _dust_burst(n: int) -> void:
	var b := Props.particles("fx/soft_dot.png", n, 0.9, 0.5, Color(0.62, 0.52, 0.4, 0.5), false)
	b.one_shot = true
	b.explosiveness = 0.9
	b.direction = Vector3.UP
	b.spread = 85.0
	b.initial_velocity_min = 0.6
	b.initial_velocity_max = 1.4
	b.gravity = Vector3(0, -0.5, 0)
	get_parent().add_child(b)
	b.global_position = global_position + Vector3(0, 0.1, 0)
	b.emitting = true
	b.finished.connect(b.queue_free)

func is_busy() -> bool:
	return anim == "kneel" or dead

func _set_anim(name: String) -> void:
	if anim == name and sprite.texture == _textures[name]:
		return
	anim = name
	anim_time = 0.0
	sprite.texture = _textures[name]
	_mat.set_shader_parameter("tex", _textures[name])
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

## Plays the casting gesture without releasing a bolt (everyday magic).
func request_cast_visual() -> void:
	_cast_timer = 0.42
	_cast_fired = true
	_cast_dir = facing
	_set_anim("cast")

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
	sprite.visible = _invuln <= 0.6 or int(_invuln * 14.0) % 2 == 0 or dead
	_mat.set_shader_parameter("flash", clampf(_hurt_timer / 0.35, 0.0, 1.0))

	var can_move := control_enabled and not dead and anim != "kneel" and _hurt_timer <= 0.0
	# Desired horizontal velocity from input relative to the camera.
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var wish := Vector3.ZERO
	var stick := move_input.limit_length(1.0)
	if can_move:
		wish = right * stick.x + fwd * stick.y
	# Run with the on-screen button (or Shift); the stick sets the pace.
	if stick.length() < 0.1:
		_still_t += delta
		if _still_t > 1.6:
			run_toggle = false
	else:
		_still_t = 0.0
	var running := (run_held or run_toggle) and stick.length() > 0.2
	var pace := clampf(inverse_lerp(0.1, 0.85, stick.length()), 0.35, 1.0)
	var speed := RUN_SPEED * maxf(pace, 0.75) if running else WALK_SPEED * pace
	if _cast_timer > 0.0:
		speed *= 0.35
	var target_v := wish.normalized() * speed if wish.length() > 0.05 else Vector3.ZERO
	# Gentle acceleration, a little quicker to slow down: soft, natural steps.
	var accel := 11.0 if target_v.length() > Vector3(vel.x, 0, vel.z).length() else 15.0
	if not on_ground:
		accel = 6.0
	if _hurt_timer > 0.0:
		accel = 2.0
	var hv := Vector3(vel.x, 0, vel.z)
	hv = hv.move_toward(target_v, accel * delta)
	# Turning while moving bends the path instead of snapping it.
	if hv.length() > 0.5 and target_v.length() > 0.5:
		var turn := hv.signed_angle_to(target_v, Vector3.UP)
		hv = hv.rotated(Vector3.UP, clampf(turn, -6.0 * delta, 6.0 * delta))
	vel.x = hv.x
	vel.z = hv.z
	var face_to := Vector3.ZERO
	if wish.length() > 0.08 and _cast_timer <= 0.0:
		face_to = wish
	elif look_target != Vector3.INF and can_move:
		face_to = look_target - global_position
		face_to.y = 0
	if face_to.length() > 0.05:
		var a0 := atan2(facing.x, facing.z)
		var a1 := atan2(face_to.x, face_to.z)
		var rate := 7.0 if wish.length() > 0.08 else 2.2
		var diff := angle_difference(a0, a1)
		var a := a0 + clampf(diff, -rate * delta, rate * delta) * (0.6 + 0.4 * clampf(absf(diff), 0.0, 1.0))
		facing = Vector3(sin(a), 0.0, cos(a))
	water_orb.visible = carrying == "water"
	if water_orb.visible:
		water_orb.position = Vector3(0, 1.1 + sin(anim_time * 3.0) * 0.06, 0) + facing * 0.5

	# Jumping with coyote time and input buffering.
	if on_ground:
		_coyote = 0.12
	else:
		_coyote = maxf(0.0, _coyote - delta)
	if can_move and _jump_buffer > 0.0 and _coyote > 0.0:
		vel.y = JUMP_VELOCITY
		on_ground = false
		_squash_v = 0.6
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
	var ground: float = world.terrain.height(next.x, next.y) if world else 0.0
	var ny := p.y + vel.y * delta
	if on_ground:
		# Stick to gentle slopes.
		ny = ground
		vel.y = 0.0
	elif ny <= ground:
		ny = ground
		if vel.y < -2.0:
			Audio.sfx("land", -8.0)
			_squash_v = -clampf(-vel.y * 0.06, 0.3, 0.9)
			_dust_burst(12)
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

	# Procedural polish: lean into turns, squash and stretch, dust when running.
	var hsp := Vector2(vel.x, vel.z).length()
	var heading := atan2(vel.x, vel.z)
	var turn_rate := angle_difference(_heading, heading) / maxf(delta, 0.001) if hsp > 1.0 else 0.0
	_heading = heading
	var cam := get_viewport().get_camera_3d()
	var side_sign := 1.0
	if cam:
		# Shear toward the inside of the turn as seen by the camera.
		side_sign = signf(cam.global_transform.basis.z.dot(Vector3(vel.x, 0, vel.z).normalized()) + 0.001)
	var want_lean := clampf(-turn_rate * 0.018 * clampf(hsp / RUN_SPEED, 0.0, 1.0), -0.12, 0.12) * side_sign
	_lean = lerpf(_lean, want_lean, clampf(delta * 6.0, 0.0, 1.0))
	_squash_v += ((1.0 - _squash) * 140.0 - _squash_v * 14.0) * delta
	_squash += _squash_v * delta
	if not on_ground:
		_squash = lerpf(_squash, 1.0 + clampf(vel.y * 0.008, -0.04, 0.05), clampf(delta * 8.0, 0.0, 1.0))
	_mat.set_shader_parameter("lean", _lean)
	_mat.set_shader_parameter("squash", _squash)
	_ghost_mat.set_shader_parameter("lean", _lean)
	_ghost_mat.set_shader_parameter("squash", _squash)
	dust.emitting = on_ground and hsp > WALK_SPEED + 1.0
	dust.global_position = global_position + Vector3(0, 0.08, 0)
	if on_ground and hsp > 4.0 and absf(turn_rate) > 5.0 and randf() < 0.2:
		_dust_burst(5)

	if anim == "run":
		_run_time += delta
	elif hsp < 0.3 and anim == "idle" and on_ground:
		if _run_time > 3.5:
			play_idle("sigh")   # catching her breath after a long run
		_run_time = 0.0
	elif anim == "walk":
		_run_time = maxf(0.0, _run_time - delta * 2.0)

	_update_anim(delta, hsp, running)

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
		if _kneel_in > 0.0:
			_kneel_in -= delta
			anim_time = 0.0
		elif _kneel_hold > 0.0:
			_kneel_hold -= delta
			anim_time = 0.0
		elif anim_time * SHEETS["kneel"]["fps"] >= SHEETS["kneel"]["frames"] + 0.5:
			want = "idle"
	elif anim in IDLE_VARIANTS and hspeed < 0.3 and on_ground and _hurt_timer <= 0.0 and _cast_timer <= 0.0 and move_input.length() < 0.05:
		if anim_time * SHEETS[anim]["fps"] >= SHEETS[anim]["frames"]:
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
			# Phase is kept in whole cycles so walk ↔ run blends without skipping a step.
			_cycle = fposmod(_cycle + delta * info["fps"] / n * clampf(hspeed / WALK_SPEED, 0.5, 1.5), 1.0)
			f = int(_cycle * n) % n
		"run":
			_cycle = fposmod(_cycle + delta * info["fps"] / n * clampf(hspeed / RUN_SPEED, 0.7, 1.2), 1.0)
			f = int(_cycle * n) % n
		"kneel":
			if _kneel_in > 0.0:
				f = clampi(int(_kneel_in / 0.5 * (n - 1)), 0, n - 1)
			else:
				f = mini(int(anim_time * info["fps"]), n - 1)
		_:
			if info["fps"] > 0.0:
				f = int(anim_time * info["fps"])
				f = f % n if info["loop"] else mini(f, n - 1)
	_anim_frame = f
	if (anim == "walk" or anim == "run") and (f == 0 or f == n / 2) and f != _last_step_frame:
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
	if (row != _last_row or flip != _last_flip) and _last_row != -1 and sprite.texture:
		# Keep the previous view briefly and fade it out: turns read as smooth.
		ghost.texture = sprite.texture
		_ghost_mat.set_shader_parameter("tex", sprite.texture)
		ghost.hframes = sprite.hframes
		ghost.vframes = sprite.vframes
		ghost.frame = sprite.frame
		ghost.flip_h = sprite.flip_h
		_ghost_a = 1.0
	_last_row = row
	_last_flip = flip
	sprite.flip_h = flip
	sprite.frame = row * int(SHEETS[anim]["frames"]) + _anim_frame
	_ghost_a = maxf(0.0, _ghost_a - get_process_delta_time() * 7.0)
	ghost.visible = _ghost_a > 0.01 and sprite.visible
	_ghost_mat.set_shader_parameter("tint", Color(1.06, 1.05, 1.02, _ghost_a))
	_mat.set_shader_parameter("tint", Color(1.06, 1.05, 1.02, 1.0 - _ghost_a * 0.5))
