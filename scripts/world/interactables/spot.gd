class_name Spot
extends Interactable
## A generic place or object Asterion can act on; the world decides what happens.

var enabled := true
var tag := ""
var visual: Node3D

func _ready() -> void:
	if visual:
		add_child(visual)

func can_interact() -> bool:
	return enabled and interactive

func interact() -> void:
	world.on_spot(self)
