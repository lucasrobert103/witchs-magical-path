class_name Shade
extends Node3D
## Sombra: a wisp of living shadow. Drifts near home, chases Asterion and fades when struck by light.

signal defeated(shade: Shade)

var world
var home := Vector3.ZERO
var hp := 3
var aim_height := 1.1
var _t := 0.0
var _state := "idle"
var _alerted := false
var _hit_flash := 0.0
var _knock := Vector3.ZERO
var _attack_cd := 0.0
var _spawn_time := 0.0
var sprite: MeshInstance3D
var _mat: ShaderMaterial
var _eyes: MeshInstance3D
var _smoke: CPUParticles3D
var dying := false

func _ready() -> void:
	_t = randf() * 10.0
	sprite = Props.sprite("enemy/shade.png", 1.9, true, {"uv_scale": Vector2(0.25, 1.0), "ground_shade": 0.0}, true)
	_mat = sprite.material_override
	sprite.mesh = Props.quad(1.9 * 192.0 / 224.0, 1.9)
	add_child(sprite)
	_eyes = Props.glow(Color(0.7, 0.45, 1.0), 1.0, 0.7, "fx/soft_dot.png", 0.3)
	_eyes.position = Vector3(0, 1.1, 0.05)
	add_child(_eyes)
	_smoke = Props.particles("fx/soft_dot.png", 14, 1.4, 0.7, Color(0.12, 0.05, 0.2, 0.5), false)
	_smoke.emitting = true
	_smoke.direction = Vector3.UP
	_smoke.initial_velocity_min = 0.2
	_smoke.initial_velocity_max = 0.6
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.4
	_smoke.position.y = 0.7
	add_child(_smoke)
	add_child(Props.blob_shadow(1.2, 0.5))
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func tick(delta: float, player: Player) -> void:
	if dying:
		return
	_t += delta
	_spawn_time += delta
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
	_mat.set_shader_parameter("flash", _hit_flash)
	_mat.set_shader_parameter("uv_offset", Vector2(float(int(_t * 6.0) % 4) * 0.25, 0.0))
	var p := global_position
	var to_player := player.global_position - p
	to_player.y = 0
	var dist := to_player.length()
	var move := Vector3.ZERO
	if not player.dead and dist < 11.0 and home.distance_to(player.global_position) < 20.0:
		if not _alerted:
			_alerted = true
			Audio.sfx("shade_alert", -6.0)
		_state = "chase"
	elif home.distance_to(p) > 1.5:
		_state = "return"
	else:
		_state = "idle"
	match _state:
		"chase":
			if dist > 0.95:
				move = to_player.normalized() * 2.5
			# Orbit a little so they don't stack.
			move += to_player.normalized().cross(Vector3.UP) * sin(_t * 1.3) * 0.8
		"return":
			move = (home - p).normalized() * 2.0
		"idle":
			move = Vector3(cos(_t * 0.7), 0, sin(_t * 0.9)) * 0.5
	move += _knock
	_knock = _knock.move_toward(Vector3.ZERO, delta * 12.0)
	var np := Vector2(p.x + move.x * delta, p.z + move.z * delta)
	if world:
		np = world.terrain.clamp_walkable(np, 0.4)
	var gy: float = world.terrain.height(np.x, np.y) if world else 0.0
	global_position = Vector3(np.x, gy + 0.15 + sin(_t * 2.2) * 0.12, np.y)
	if _spawn_time > 0.8 and dist < 1.05 and _attack_cd <= 0.0 and absf(player.global_position.y - global_position.y) < 1.4:
		player.take_damage(14.0, global_position)
		_attack_cd = 1.2
		if world:
			world.cam_rig.shake(0.6)

func on_magic(_essence: String, from: Vector3) -> void:
	if dying:
		return
	hp -= 1
	_hit_flash = 1.0
	var away := global_position - from
	away.y = 0
	_knock = away.normalized() * 6.0
	if hp <= 0:
		_die()

func _die() -> void:
	dying = true
	Audio.sfx("shade_die", -3.0)
	Props.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(0.75, 0.6, 1.0), 40, 3.0, 0.45, 1.2)
	Props.burst(get_parent(), global_position + Vector3(0, 1, 0), Color(1.0, 0.95, 0.8), 20, 2.0, 0.3, 1.0)
	defeated.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.4, 0.05, 1.4), 0.45).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(queue_free)
