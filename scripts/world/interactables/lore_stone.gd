class_name LoreStone
extends Interactable
## Standing stone with a carved inscription.

var rune := "star"
var lines: Array = []
var title := "Inscrição"
var _glow: MeshInstance3D

func _ready() -> void:
	prompt = "Ler"
	icon = "read"
	radius = 2.4
	add_child(Props.sprite("env/runestone_%s.png" % rune, 2.3, true))
	_glow = Props.glow(Color(1, 1, 1), 0.85, 0.35, "fx/rune_%s.png" % rune, 0.25)
	_glow.position = Vector3(0, 1.32, 0.08)
	add_child(_glow)
	add_child(Props.blob_shadow(1.3, 0.5))

func interact() -> void:
	world.show_lore(self)
	_glow.material_override.set_shader_parameter("energy", 1.2)
