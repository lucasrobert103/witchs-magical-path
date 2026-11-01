class_name Pedestal
extends Interactable
## Sanctuary altar of the Moon (the Goddess) or the Flame (the God).

const HOLD_TIME := 14.0
var kind := "moon"
var lit := false
var locked := false        # stays lit once both altars are awake
var timer := 0.0
var _rune: MeshInstance3D
var _halo: MeshInstance3D
var _fire: CPUParticles3D

func _ready() -> void:
	interactive = false
	magic_target = true
	aim_height = 1.3
	add_child(Props.sprite("env/pedestal_%s.png" % kind, 1.7, true))
	var col := color()
	_rune = Props.glow(Color(1, 1, 1), 0.9, 0.0, "fx/rune_%s.png" % kind)
	_rune.position = Vector3(0, 0.62, 0.12)
	_rune.material_override.set_shader_parameter("face_camera", true)
	add_child(_rune)
	_halo = Props.glow(col, 3.2, 0.0, "fx/soft_dot.png", 0.15)
	_halo.position = Vector3(0, 1.5, 0)
	add_child(_halo)
	_fire = Props.particles("fx/soft_dot.png", 36, 1.1, 0.5, col)
	_fire.direction = Vector3.UP
	_fire.spread = 18.0
	_fire.initial_velocity_min = 0.8
	_fire.initial_velocity_max = 1.6
	_fire.scale_amount_min = 0.4
	_fire.scale_amount_max = 1.0
	_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fire.emission_sphere_radius = 0.25
	_fire.position = Vector3(0, 1.35, 0)
	_fire.emitting = false
	add_child(_fire)
	add_child(Props.blob_shadow(1.4, 0.5))

func color() -> Color:
	return Color(0.45, 0.85, 1.0) if kind == "moon" else Color(1.0, 0.62, 0.25)

func accepts_magic() -> bool:
	return not locked

func set_lit(value: bool) -> void:
	lit = value
	timer = HOLD_TIME if value else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_rune.material_override, "shader_parameter/energy", 1.6 if value else 0.0, 0.5)
	tw.tween_property(_halo.material_override, "shader_parameter/energy", 0.7 if value else 0.0, 0.8)
	_fire.emitting = value

func tick(delta: float, _player: Player) -> void:
	if lit and not locked:
		timer -= delta
		var flicker := 1.6 if timer > 4.0 else (1.6 if int(timer * 6.0) % 2 == 0 else 0.4)
		_rune.material_override.set_shader_parameter("energy", flicker)
		if timer <= 0.0:
			set_lit(false)
			world.on_pedestal_faded(self)

func on_magic(essence: String, _from: Vector3) -> void:
	if locked:
		return
	if essence == kind:
		set_lit(true)
		Audio.sfx("rune", -2.0)
		world.on_pedestal_lit(self)
	else:
		Props.burst(get_parent(), global_position + Vector3(0, 1.4, 0), Color(0.6, 0.6, 0.6), 14, 1.5, 0.3)
		world.on_pedestal_rejected(self, essence)
