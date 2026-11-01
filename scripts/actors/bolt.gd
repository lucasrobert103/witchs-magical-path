class_name Bolt
extends Node3D
## Magic orb that homes toward its target and reports hits to the world.

var world
var vel := Vector3.ZERO
var target: Node3D
var essence := ""
var color := Color(1, 0.9, 0.6)
var life := 1.3
var _trail: CPUParticles3D

func setup(w, origin: Vector3, dir: Vector3, tgt: Node3D, ess: String, col: Color) -> void:
	world = w
	essence = ess
	color = col
	target = tgt
	vel = dir.normalized() * 17.0
	position = origin

func _ready() -> void:
	add_child(Props.glow(color, 1.1, 1.4))
	var core := Props.glow(Color(1, 1, 1), 0.38, 1.2, "fx/soft_core.png")
	add_child(core)
	_trail = Props.particles("fx/soft_dot.png", 28, 0.45, 0.32, color)
	_trail.local_coords = false
	_trail.emitting = true
	_trail.spread = 180.0
	_trail.initial_velocity_min = 0.1
	_trail.initial_velocity_max = 0.5
	_trail.scale_amount_min = 0.5
	_trail.scale_amount_max = 1.0
	add_child(_trail)

func _process(delta: float) -> void:
	life -= delta
	if is_instance_valid(target) and target.is_inside_tree():
		var aim: Vector3 = target.global_position + Vector3(0, float(target.get("aim_height") if target.get("aim_height") != null else 1.0), 0)
		var to := aim - global_position
		var desired := to.normalized() * 19.0
		vel = vel.lerp(desired, clampf(delta * 9.0, 0.0, 1.0))
		if to.length() < 0.7:
			_hit(target)
			return
	else:
		target = null
	global_position += vel * delta
	if world and target == null:
		var hit = world.bolt_probe(global_position)
		if hit:
			_hit(hit)
			return
	if life <= 0.0:
		_fizzle()

func _hit(node: Node3D) -> void:
	if world:
		world.on_bolt_hit(node, essence, global_position)
	Props.burst(get_parent(), global_position, color, 30, 4.0, 0.4)
	Audio.sfx("hit", -4.0)
	queue_free()

func _fizzle() -> void:
	Props.burst(get_parent(), global_position, color, 12, 1.5, 0.3, 0.6)
	queue_free()
