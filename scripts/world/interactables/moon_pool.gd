class_name MoonPool
extends Interactable
## A spring of glowing water; the Goddess's tears still shine in it.

const WATER := preload("res://shaders/water.gdshader")
var size := 3.2
var _water_mat: ShaderMaterial
var _glow: MeshInstance3D
var _t := 0.0

func _ready() -> void:
	prompt = "Tocar a água"
	radius = size + 1.2
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size * 2.0, size * 2.0)
	water.mesh = plane
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = WATER
	_water_mat.set_shader_parameter("noise_tex", world.dapple)
	water.material_override = _water_mat
	water.position.y = 0.06
	add_child(water)
	_glow = Props.glow(Color(0.4, 0.9, 1.0), size * 2.6, 0.45, "fx/soft_dot.png", 0.15)
	_glow.position.y = 0.6
	add_child(_glow)
	var motes := Props.particles("fx/soft_dot.png", 24, 3.0, 0.16, Color(0.6, 0.95, 1.0))
	motes.emitting = true
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(size * 0.8, 0.1, size * 0.8)
	motes.direction = Vector3.UP
	motes.initial_velocity_min = 0.2
	motes.initial_velocity_max = 0.5
	motes.position.y = 0.2
	add_child(motes)
	# Rim of mossy stones.
	for i in 9:
		var a := TAU * i / 9.0 + randf() * 0.3
		var s := Props.sprite("env/boulder_b.png" if i % 2 else "env/boulder_a.png", randf_range(0.45, 0.8), true, {"ground_shade": 0.3})
		s.position = Vector3(cos(a) * (size + 0.25), 0, sin(a) * (size + 0.25))
		add_child(s)

func tick(delta: float, player: Player) -> void:
	_t += delta
	var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if d < size + 1.5 and not player.dead:
		player.heal(12.0 * delta)
		if player.magic_unlocked:
			player.restore_mana(10.0 * delta)

func interact() -> void:
	world.on_pool_touched(self)
