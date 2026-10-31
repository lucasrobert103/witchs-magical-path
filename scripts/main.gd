extends Node3D
## All scenery and interactions are prototype staging, not additional mythology.

const PlayerScript = preload("res://scripts/player.gd")
const UIScript = preload("res://scripts/game_ui.gd")
const ForestScript = preload("res://scripts/forest.gd")

var player: CharacterBody3D
var interface: CanvasLayer
var forest: Node3D
var journey_started := false
var discovered := false
var is_paused := false
var autosave_path := "user://discovery.cfg"


func _ready() -> void:
	_setup_input()
	forest = ForestScript.new()
	add_child(forest)
	player = PlayerScript.new()
	player.name = "AsterionPlayer"
	add_child(player)
	player.position = Vector3(0, 0.08, 8)
	player.movement_enabled = false
	interface = UIScript.new()
	add_child(interface)
	interface.start_requested.connect(_start_game)
	interface.magic_pressed.connect(_request_magic)
	interface.move_changed.connect(_move_touch)
	interface.look_dragged.connect(_look_touch)
	interface.pause_changed.connect(_pause_changed)
	interface.replay_requested.connect(_restart)
	player.magic_requested.connect(_cast_magic)
	interface.show_title()


func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"magic": [KEY_SPACE, KEY_E], "pause": [KEY_ESCAPE]
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("magic") and not event.is_echo():
		_request_magic()


func _start_game() -> void:
	discovered = false
	forest.reset_flower()
	player.position = Vector3(0, 0.08, 8)
	player.velocity = Vector3.ZERO
	player.touch_move = Vector2.ZERO
	player.orbit_yaw = 0.0
	player.orbit_pitch = -0.23
	journey_started = true
	is_paused = false
	player.movement_enabled = true
	interface.show_game()
	interface.set_objective("Siga as luzes até a planta luminosa")
	interface.set_hint("Mova-se pelo bosque. Arraste à direita para olhar ao redor.")


func _move_touch(direction: Vector2) -> void:
	player.touch_move = direction if journey_started and not is_paused else Vector2.ZERO


func _look_touch(relative: Vector2) -> void:
	if journey_started and not is_paused:
		player.orbit_camera(relative)


func _pause_changed(paused: bool) -> void:
	is_paused = paused
	player.movement_enabled = journey_started and not paused
	player.touch_move = Vector2.ZERO


func _request_magic() -> void:
	if journey_started and not is_paused:
		player.cast_magic()


func _cast_magic() -> void:
	if not journey_started or is_paused:
		return
	forest.magic_wave(player.global_position)
	if player.global_position.distance_to(forest.flower_position) > 4.5:
		interface.show_toast("A luz distante parece responder. Aproxime-se da planta.")
		return
	if discovered:
		interface.show_toast("A planta acompanha o movimento da sua magia.")
		return
	discovered = true
	forest.awaken_flower()
	interface.set_objective("Primeiro contato com a magia · concluído")
	interface.set_hint("Continue explorando a clareira.")
	var save := ConfigFile.new()
	save.set_value("prototype", "discovered", true)
	var error := save.save(autosave_path)
	if error != OK:
		push_warning("Não foi possível salvar a descoberta: %s" % error)
	interface.show_discovery()


func _restart() -> void:
	# Replays are deliberately fresh; the local record is a completed milestone only.
	var save := ConfigFile.new()
	save.set_value("prototype", "discovered", false)
	save.save(autosave_path)
	_start_game()


func _process(_delta: float) -> void:
	if not journey_started or discovered:
		return
	if player.global_position.distance_to(forest.flower_position) <= 4.5:
		interface.set_hint("Toque em Magia para interagir com a planta luminosa.")
	else:
		interface.set_hint("Siga os pequenos pontos de luz pela clareira.")
