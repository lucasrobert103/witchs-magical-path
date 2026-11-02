class_name Player
extends Node3D
## Asterion: movement, jumping, casting, damage and the rigged 3D model (cel-shaded).

signal cast_requested(origin: Vector3, direction: Vector3)
signal died
signal footstep

const MODEL_PATH := "res://assets/characters/asterion/asterion.glb"
const CLIP_INFO_PATH := "res://assets/characters/asterion/asterion_clips.json"
## Game state -> animation clip in the model (idle reactions keep their old names).
const CLIP_OF := {"wind": "look"}
const LOOPING := ["idle", "walk", "run", "fall"]
const WALK_SPEED := 2.0
const RUN_SPEED := 5.4
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
var _last_phase := 0.0
var dead := false
var _lean := 0.0
var _squash := 1.0
var _squash_v := 0.0
var _heading := 0.0
var dust: CPUParticles3D

var model: Node3D
var anim_player: AnimationPlayer
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var shadow: MeshInstance3D
var hand_glow: MeshInstance3D
var _mats: Array[ShaderMaterial] = []
var _outlines: Array[ShaderMaterial] = []
var _face_mat: ShaderMaterial
var hair_springs: SpringBoneSimulator3D
var _clip := ""
var _clip_speed := {"walk": 1.6, "run": 4.7}
var _kneel_phase := ""          # "down", "hold", "up"
var _blink_t := 2.0
var _expr := "neutral"
var _expr_t := 0.0
var _yaw := 0.0
var look_target := Vector3.INF # set by the world when she pauses to observe
var carrying := ""             # "water" while holding a ribbon of river water
var water_orb: Node3D

func _ready() -> void:
	_build_model()
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
	shadow = Props.blob_shadow(1.1, 0.6)
	add_child(shadow)
	hand_glow = Props.glow(Color(1.0, 0.9, 0.6), 0.9, 0.0)
	# The glow lives in her right hand (it follows the casting gesture).
	var hand := BoneAttachment3D.new()
	hand.bone_name = "RightHand"
	skeleton.add_child(hand)
	hand.add_child(hand_glow)
	hand_glow.position = Vector3(0, 0.1, 0)
	Game.settings_changed.connect(_apply_quality)
	_apply_quality()
	_set_anim("idle")

## Loads the rigged model, gives every surface the cel shader and sets the clips up.
func _build_model() -> void:
	var ps: PackedScene = load(MODEL_PATH)
	model = ps.instantiate()
	add_child(model)
	anim_player = model.find_child("AnimationPlayer", true, false)
	skeleton = model.find_child("Skeleton3D", true, false)
	body_mesh = model.find_children("*", "MeshInstance3D", true, false)[0]
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if FileAccess.file_exists(CLIP_INFO_PATH):
		var info = JSON.parse_string(FileAccess.get_file_as_string(CLIP_INFO_PATH))
		if typeof(info) == TYPE_DICTIONARY:
			for k in info.keys():
				if typeof(info[k]) == TYPE_DICTIONARY and info[k].has("speed"):
					_clip_speed[k] = float(info[k]["speed"])
	for clip in anim_player.get_animation_list():
		var a := anim_player.get_animation(clip)
		a.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
	anim_player.playback_default_blend_time = 0.18
	var toon: Shader = load("res://shaders/toon.gdshader")
	var toon2: Shader = load("res://shaders/toon_double.gdshader")
	var outline: Shader = load("res://shaders/toon_outline.gdshader")
	var mesh := body_mesh.mesh
	for i in mesh.get_surface_count():
		var src := mesh.surface_get_material(i) as BaseMaterial3D
		var key := src.resource_name if src else ""
		var style: Dictionary = MATERIAL_STYLE.get(key, {})
		var m := ShaderMaterial.new()
		m.shader = toon2 if src and src.cull_mode == BaseMaterial3D.CULL_DISABLED else toon
		m.set_shader_parameter("albedo", src.albedo_color if src else Color.WHITE)
		if src and src.albedo_texture:
			m.set_shader_parameter("tex", src.albedo_texture)
			m.set_shader_parameter("use_tex", true)
		for p in style.keys():
			if p == "detail":
				m.set_shader_parameter("detail", load("res://assets/characters/asterion/detail_%s.png" % style[p]))
			else:
				m.set_shader_parameter(p, style[p])
		if key == "face":
			_face_mat = m
		var o := ShaderMaterial.new()
		o.shader = outline
		o.set_shader_parameter("width", 0.0028 if key.begins_with("hair") else 0.0042)
		o.set_shader_parameter("color", OUTLINE_COLOR.get(key, Color(0.16, 0.08, 0.06)))
		_outlines.append(o)
		m.next_pass = o
		body_mesh.set_surface_override_material(i, m)
		_mats.append(m)
	_build_hair_springs()

## Real hair physics: every hair bone chain is a spring that swings with her motion
## (turning, stopping, jumping) and collides with her head, back and arms.
func _build_hair_springs() -> void:
	# The baked hair sway is replaced by the live simulation.
	for clip in anim_player.get_animation_list():
		var a := anim_player.get_animation(clip)
		for t in range(a.get_track_count() - 1, -1, -1):
			if str(a.track_get_path(t)).contains(":Hair"):
				a.remove_track(t)
	var chains := {}
	for i in skeleton.get_bone_count():
		var bn := skeleton.get_bone_name(i)
		if bn.begins_with("Hair"):
			var base := bn.rstrip("0123456789")
			chains[base] = maxi(int(chains.get(base, 0)), int(bn.substr(base.length())))
	hair_springs = SpringBoneSimulator3D.new()
	hair_springs.name = "HairSprings"
	skeleton.add_child(hair_springs)
	hair_springs.setting_count = chains.size()
	var k := 0
	for base in chains.keys():
		var near_face: bool = base.begins_with("HairCheek") or base.begins_with("HairFront")
		hair_springs.set_root_bone_name(k, base + "1")
		hair_springs.set_end_bone_name(k, "%s%d" % [base, chains[base]])
		hair_springs.set_extend_end_bone(k, true)
		hair_springs.set_end_bone_length(k, 0.08)
		hair_springs.set_radius(k, 0.012 if base.begins_with("HairCheek") else 0.03)
		hair_springs.set_stiffness(k, 4.0 if near_face else 3.0)
		hair_springs.set_drag(k, 0.65)
		hair_springs.set_gravity(k, 1.6)
		hair_springs.set_gravity_direction(k, Vector3.DOWN)
		hair_springs.set_enable_all_child_collisions(k, true)
		k += 1
	_spring_collider(SpringBoneCollisionSphere3D.new(), "Head", Vector3(0, 0.08, 0), 0.095)
	var torso := SpringBoneCollisionCapsule3D.new()
	torso.height = 0.55
	_spring_collider(torso, "Chest", Vector3(0, 0.1, 0), 0.14)
	for side in ["Left", "Right"]:
		_spring_collider(SpringBoneCollisionSphere3D.new(), side + "UpperArm", Vector3(0, 0.06, 0), 0.065)
		_spring_collider(SpringBoneCollisionSphere3D.new(), side + "Shoulder", Vector3(0, 0.08, 0), 0.07)

func _spring_collider(c: SpringBoneCollision3D, bone: String, offset: Vector3, radius: float) -> void:
	hair_springs.add_child(c)
	c.bone_name = bone
	c.position_offset = offset
	if c is SpringBoneCollisionSphere3D:
		(c as SpringBoneCollisionSphere3D).radius = radius
	elif c is SpringBoneCollisionCapsule3D:
		(c as SpringBoneCollisionCapsule3D).radius = radius

const MATERIAL_STYLE := {
	"skin": {"shade_tint": Color(0.8, 0.58, 0.54), "rim_amount": 0.38, "shade_soft": 0.08},
	"face": {"shade_tint": Color(0.9, 0.74, 0.7), "shade_threshold": 0.14, "shade_soft": 0.2, "rim_amount": 0.22, "ao_amount": 0.2},
	"hair_dark": {"spec_amount": 0.25, "shade_tint": Color(0.7, 0.6, 0.66), "rim_amount": 0.25, "detail": "hair", "detail_amount": 0.7},
	"hair": {"spec_amount": 0.55, "spec_size": 0.1, "shade_tint": Color(0.66, 0.56, 0.62), "rim_amount": 0.4, "detail": "hair", "detail_amount": 0.9},
	"hair_light": {"spec_amount": 0.65, "spec_size": 0.12, "shade_tint": Color(0.66, 0.56, 0.62), "rim_amount": 0.45, "detail": "hair", "detail_amount": 0.9},
	"cloth_green": {"shade_tint": Color(0.6, 0.58, 0.6), "detail": "cloth", "detail_amount": 0.8},
	"cloth_dark": {"shade_tint": Color(0.62, 0.6, 0.62), "detail": "cloth", "detail_amount": 0.8},
	"trim": {"spec_amount": 0.4, "shade_tint": Color(0.66, 0.6, 0.62)},
	"leather": {"spec_amount": 0.3, "shade_tint": Color(0.66, 0.56, 0.58), "detail": "leather", "detail_amount": 1.0},
	"leather_dark": {"spec_amount": 0.22, "shade_tint": Color(0.66, 0.56, 0.58), "detail": "leather", "detail_amount": 0.8, "detail_scale": Vector2(3, 3)},
	"sole": {"detail": "leather", "detail_amount": 0.6},
	"bronze": {"spec_amount": 1.1, "spec_size": 0.22, "shade_tint": Color(0.6, 0.5, 0.45), "ao_amount": 0.5},
}
const OUTLINE_COLOR := {
	"skin": Color(0.26, 0.12, 0.08), "face": Color(0.26, 0.12, 0.08),
	"hair": Color(0.06, 0.03, 0.02), "hair_dark": Color(0.05, 0.025, 0.02), "hair_light": Color(0.07, 0.035, 0.025),
	"cloth_green": Color(0.05, 0.11, 0.08), "cloth_dark": Color(0.03, 0.07, 0.05),
}

## "Leve" quality drops the outline pass (half the vertex work on weak phones).
func _apply_quality() -> void:
	var pretty := int(Game.settings.get("quality", 1)) >= 1
	for i in _mats.size():
		_mats[i].next_pass = _outlines[i] if pretty else null

## Face expressions live in a 2x2 atlas: neutral, blink, happy, surprised.
func set_expression(name: String, seconds := 2.5) -> void:
	_expr = name
	_expr_t = seconds

func _update_face(delta: float) -> void:
	if _face_mat == null:
		return
	_expr_t -= delta
	if _expr_t <= 0.0:
		_expr = "neutral"
	_blink_t -= delta
	var tile := Vector2.ZERO
	match _expr:
		"happy":
			tile = Vector2(0.0, 0.5)
		"surprised":
			tile = Vector2(0.5, 0.5)
	if _blink_t < 0.0 or anim == "hurt":
		tile = Vector2(0.5, 0.0)
		if _blink_t < -0.11:
			_blink_t = randf_range(2.2, 5.5)
	_face_mat.set_shader_parameter("uv_offset", tile)

func _set_flash(v: float) -> void:
	for m in _mats:
		m.set_shader_parameter("flash", v)

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
	if hair_springs:
		hair_springs.reset()   # no whiplash after a respawn / teleport

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
	if anim == name and _clip != "":
		return
	anim = name
	anim_time = 0.0
	_kneel_phase = ""
	if name == "kneel":
		return   # _update_kneel starts the clip
	_play(CLIP_OF.get(name, name))

func _play(clip: String, blend := -1.0, phase := -1.0) -> void:
	if anim_player == null or not anim_player.has_animation(clip):
		return
	if clip == _clip and anim_player.is_playing() and phase < 0.0:
		return
	_clip = clip
	anim_player.speed_scale = 1.0
	anim_player.play(clip, blend)
	if phase >= 0.0:
		anim_player.seek(phase * anim_player.current_animation_length, true)

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
	model.visible = _invuln <= 0.6 or int(_invuln * 14.0) % 2 == 0 or dead
	_set_flash(clampf(_hurt_timer / 0.35, 0.0, 1.0))
	_update_face(delta)

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

	# Procedural polish: lean into turns, squash and stretch, dust when running.
	var hsp := Vector2(vel.x, vel.z).length()
	var heading := atan2(vel.x, vel.z)
	var turn_rate := angle_difference(_heading, heading) / maxf(delta, 0.001) if hsp > 1.0 else 0.0
	_heading = heading
	# Lean into the turn (she tilts toward the inside of the curve).
	var want_lean := clampf(-turn_rate * 0.03 * clampf(hsp / RUN_SPEED, 0.0, 1.0), -0.16, 0.16)
	_lean = lerpf(_lean, want_lean, clampf(delta * 6.0, 0.0, 1.0))
	_squash_v += ((1.0 - _squash) * 140.0 - _squash_v * 14.0) * delta
	_squash += _squash_v * delta
	if not on_ground:
		_squash = lerpf(_squash, 1.0 + clampf(vel.y * 0.008, -0.04, 0.05), clampf(delta * 8.0, 0.0, 1.0))
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
		_update_kneel(delta)
		if _kneel_phase == "done":
			want = "idle"
	elif anim in IDLE_VARIANTS and hspeed < 0.3 and on_ground and _hurt_timer <= 0.0 and _cast_timer <= 0.0 and move_input.length() < 0.05:
		if not anim_player.is_playing() or anim_player.current_animation_position >= anim_player.current_animation_length - 0.05:
			want = "idle"
	elif _hurt_timer > 0.0:
		want = "hurt"
	elif _cast_timer > 0.0:
		want = "cast"
	elif not on_ground:
		want = "jump" if vel.y > 1.5 and anim != "fall" else "fall"
	elif hspeed > 0.3:
		want = "run" if (running and hspeed > WALK_SPEED + 0.4) else "walk"
	else:
		want = "idle"
	if want != anim:
		var from_loco := anim == "walk" or anim == "run"
		var phase := _phase()
		anim = want
		anim_time = 0.0
		_kneel_phase = ""
		var blend := 0.18
		match want:
			"walk", "run":
				blend = 0.22
			"idle":
				blend = 0.3
			"hurt", "cast":
				blend = 0.08
			"jump":
				blend = 0.1
			"fall":
				blend = 0.25
		# Keep the step phase when switching walk <-> run so no foot skips.
		var keep := from_loco and (want == "walk" or want == "run")
		_play(CLIP_OF.get(want, want), blend, phase if keep else -1.0)
	# Locomotion plays at the speed she really moves, so the feet stay planted.
	if anim == "walk" or anim == "run":
		var natural: float = _clip_speed.get(anim, 1.6)
		anim_player.speed_scale = clampf(hspeed / natural, 0.55, 1.6)
		var ph := _phase()
		if (ph < _last_phase and _last_phase - ph > 0.5) or (_last_phase < 0.5 and ph >= 0.5):
			footstep.emit()
			Audio.sfx("step%d" % (randi() % 4), -16.0 if anim == "walk" else -12.0, 0.12)
		_last_phase = ph
	elif anim != "kneel":
		anim_player.speed_scale = 1.0
	_apply_model(delta)

func _phase() -> float:
	if anim_player == null or anim_player.current_animation_length <= 0.0:
		return 0.0
	return fposmod(anim_player.current_animation_position / anim_player.current_animation_length, 1.0)

## Kneeling: lower herself, hold while the world needs her down, then stand back up.
func _update_kneel(delta: float) -> void:
	match _kneel_phase:
		"":
			_kneel_phase = "down"
			_clip = ""
			_play("kneel", 0.15)
			anim_player.speed_scale = 1.0 if _kneel_in > 0.0 else 2.2
		"down":
			if not anim_player.is_playing() or anim_player.current_animation_position >= anim_player.current_animation_length - 0.01:
				_kneel_phase = "hold"
				anim_player.speed_scale = 1.0
		"hold":
			_kneel_hold -= delta
			if _kneel_hold <= 0.0:
				_kneel_phase = "up"
				anim_player.speed_scale = 1.3
				anim_player.play_backwards("kneel", 0.0)
		"up":
			if not anim_player.is_playing() or anim_player.current_animation_position <= 0.02:
				_kneel_phase = "done"
				anim_player.speed_scale = 1.0

## Turns the model toward where she faces and adds the lean / squash polish.
func _apply_model(delta: float) -> void:
	var target_yaw := atan2(facing.x, facing.z)
	_yaw = lerp_angle(_yaw, target_yaw, clampf(delta * 14.0, 0.0, 1.0))
	var b := Basis(Vector3.UP, _yaw) * Basis(Vector3(0, 0, 1), _lean)
	var sq := clampf(_squash, 0.6, 1.4)
	model.transform = Transform3D(b.scaled_local(Vector3(1.0 / sqrt(sq), sq, 1.0 / sqrt(sq))), Vector3.ZERO)
