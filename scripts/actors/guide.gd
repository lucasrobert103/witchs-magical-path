class_name Guide
extends Node3D
## Lume: a small guiding light that floats ahead along the route to the objective.

var route: Array = []     # Array[Vector3]
var _index := 0
var _t := 0.0
var _vis := 0.0
var active := false
var _glow: MeshInstance3D
var _core: MeshInstance3D
var _motes: CPUParticles3D

func _ready() -> void:
	_glow = Props.glow(Color(1.0, 0.92, 0.65), 1.6, 1.0, "fx/soft_dot.png", 0.25)
	add_child(_glow)
	_core = Props.glow(Color(1, 1, 1), 0.45, 1.3, "fx/sparkle.png")
	add_child(_core)
	_motes = Props.particles("fx/soft_dot.png", 18, 1.2, 0.18, Color(1.0, 0.9, 0.6))
	_motes.emitting = true
	_motes.local_coords = false
	_motes.spread = 180.0
	_motes.initial_velocity_min = 0.1
	_motes.initial_velocity_max = 0.4
	_motes.gravity = Vector3(0, 0.3, 0)
	add_child(_motes)
	visible = false

func set_route(points: Array, terrain: Terrain, start_near := Vector3.INF) -> void:
	route = []
	for p in points:
		route.append(Vector3(p.x, terrain.height(p.x, p.y) + 1.6, p.y))
	_index = 0
	active = route.size() > 0
	if active and start_near != Vector3.INF:
		# Skip points already behind the player.
		var best := 0
		var best_d := 1e9
		for i in route.size():
			var d: float = route[i].distance_to(start_near)
			if d < best_d:
				best_d = d
				best = i
		_index = best
	if active and global_position == Vector3.ZERO:
		global_position = route[_index]

func clear() -> void:
	active = false

func tick(delta: float, player_pos: Vector3) -> void:
	_t += delta
	_vis = move_toward(_vis, 1.0 if active else 0.0, delta * 1.5)
	visible = _vis > 0.01
	scale = Vector3.ONE * maxf(_vis, 0.01)
	if not active or route.is_empty():
		return
	var tgt: Vector3 = route[_index]
	if _index < route.size() - 1 and player_pos.distance_to(tgt) < 5.5:
		_index += 1
		tgt = route[_index]
	var hover := Vector3(sin(_t * 1.7) * 0.25, sin(_t * 2.3) * 0.2, cos(_t * 1.3) * 0.25)
	global_position = global_position.lerp(tgt + hover, clampf(delta * 1.8, 0.0, 1.0))
