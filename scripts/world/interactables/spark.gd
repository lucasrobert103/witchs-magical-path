class_name Spark
extends Interactable
## Centelha: a mote of the first gods' essence, left in every created thing.

var echo := ""
var _t := 0.0
var _base_y := 0.0
var collected := false

func _ready() -> void:
	interactive = false
	_t = randf() * 6.0
	_base_y = position.y
	var halo := Props.glow(Color(1.0, 0.86, 0.5), 1.6, 0.9, "fx/soft_dot.png", 0.3)
	add_child(halo)
	var star := Props.glow(Color(1.0, 0.97, 0.85), 0.75, 1.3, "fx/sparkle.png", 0.4)
	add_child(star)
	var motes := Props.particles("fx/soft_dot.png", 10, 1.6, 0.12, Color(1.0, 0.9, 0.6))
	motes.emitting = true
	motes.spread = 180.0
	motes.initial_velocity_min = 0.15
	motes.initial_velocity_max = 0.45
	motes.gravity = Vector3(0, 0.25, 0)
	add_child(motes)

func tick(delta: float, player: Player) -> void:
	if collected:
		return
	_t += delta
	position.y = _base_y + sin(_t * 2.0) * 0.18
	rotation.y = _t
	if player.global_position.distance_to(global_position - Vector3(0, 0.9, 0)) < 1.4:
		collected = true
		world.on_spark_collected(self)
		Props.burst(get_parent(), global_position, Color(1.0, 0.9, 0.6), 36, 3.5, 0.35)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.35)
		tw.tween_callback(queue_free)
