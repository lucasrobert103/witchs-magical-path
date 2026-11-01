class_name Brazier
extends Interactable
## The Eternal Flame: fire that does not burn, only dances.

func _ready() -> void:
	prompt = "Tocar a chama"
	radius = 2.6
	aim_height = 1.6
	add_child(Props.sprite("env/pedestal_flame.png", 1.8, true))
	var halo := Props.glow(Color(1.0, 0.6, 0.25), 5.0, 0.6, "fx/soft_dot.png", 0.12)
	halo.position = Vector3(0, 1.8, 0)
	add_child(halo)
	var core := Props.glow(Color(1.0, 0.85, 0.5), 1.2, 1.2, "fx/soft_core.png", 0.2)
	core.position = Vector3(0, 1.75, 0)
	add_child(core)
	var fire := Props.particles("fx/soft_dot.png", 60, 1.0, 0.65, Color(1.0, 0.55, 0.18))
	fire.emitting = true
	fire.direction = Vector3.UP
	fire.spread = 14.0
	fire.initial_velocity_min = 1.0
	fire.initial_velocity_max = 2.0
	fire.scale_amount_min = 0.3
	fire.scale_amount_max = 1.0
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.3
	fire.position = Vector3(0, 1.45, 0)
	add_child(fire)
	var embers := Props.particles("fx/sparkle.png", 16, 2.2, 0.16, Color(1.0, 0.8, 0.4))
	embers.emitting = true
	embers.direction = Vector3.UP
	embers.initial_velocity_min = 0.8
	embers.initial_velocity_max = 1.8
	embers.spread = 35.0
	embers.position = Vector3(0, 1.6, 0)
	add_child(embers)
	add_child(Props.blob_shadow(1.6, 0.5))

func interact() -> void:
	world.on_brazier_touched(self)
