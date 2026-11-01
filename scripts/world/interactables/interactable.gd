class_name Interactable
extends Node3D
## Base for things Asterion can touch, read or strike with magic.

var world
var id := ""
var prompt := "Interagir"
var icon := "interact"
var radius := 2.2
var interactive := true
var magic_target := false
var aim_height := 1.0

func can_interact() -> bool:
	return interactive

func interact() -> void:
	pass

func accepts_magic() -> bool:
	return magic_target

func on_magic(_essence: String, _from: Vector3) -> void:
	pass

func tick(_delta: float, _player: Player) -> void:
	pass

func ground_y() -> float:
	return world.terrain.height(global_position.x, global_position.z) if world else 0.0
