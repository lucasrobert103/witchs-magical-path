class_name StoneLantern
extends Interactable
## Ancient stone lantern; magic rekindles its light.

var lit := false
var _flame: MeshInstance3D
var _halo: MeshInstance3D
var _sparks: CPUParticles3D

func _ready() -> void:
	interactive = false
	magic_target = true
	aim_height = 1.35
	add_child(Props.sprite("env/lantern.png", 2.0, true))
	_flame = Props.glow(Color(1.0, 0.75, 0.4), 0.7, 0.0, "fx/soft_core.png", 0.2)
	_flame.position = Vector3(0, 1.38, 0.05)
	add_child(_flame)
	_halo = Props.glow(Color(1.0, 0.7, 0.35), 3.5, 0.0, "fx/soft_dot.png", 0.1)
	_halo.position = Vector3(0, 1.38, 0)
	add_child(_halo)
	_sparks = Props.particles("fx/sparkle.png", 10, 1.4, 0.14, Color(1.0, 0.8, 0.45))
	_sparks.direction = Vector3.UP
	_sparks.initial_velocity_min = 0.3
	_sparks.initial_velocity_max = 0.7
	_sparks.position = Vector3(0, 1.5, 0)
	_sparks.emitting = false
	add_child(_sparks)
	add_child(Props.blob_shadow(1.2, 0.5))
	if lit:
		set_lit(true, true)

func accepts_magic() -> bool:
	return not lit

func set_lit(value: bool, instant := false) -> void:
	lit = value
	var e := 1.4 if value else 0.0
	var h := 0.55 if value else 0.0
	if instant:
		(_flame.material_override as ShaderMaterial).set_shader_parameter("energy", e)
		(_halo.material_override as ShaderMaterial).set_shader_parameter("energy", h)
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_flame.material_override, "shader_parameter/energy", e, 0.6)
		tw.tween_property(_halo.material_override, "shader_parameter/energy", h, 1.2)
	_sparks.emitting = value

func on_magic(_essence: String, _from: Vector3) -> void:
	if lit:
		return
	set_lit(true)
	Audio.sfx("rune", -4.0)
	world.on_lantern_lit(self)
