extends Node3D
## A self-contained, guided exploration region. Puzzle staging is a proposal,
## not a new explanation of Asterion's powers or history.

const PlayerScript = preload("res://scripts/player.gd")
const UIScript = preload("res://scripts/game_ui.gd")
const ForestScript = preload("res://scripts/forest.gd")
const PUZZLE_ORDER: Array[int] = [0, 1, 2]
const SOURCE_NAMES: Array[String] = ["Água", "Raiz", "Luz"]
const INTERACTION_RANGE := 3.8

var player: CharacterBody3D
var interface: CanvasLayer
var forest: Node3D
var title_camera: Camera3D
var ambience: AudioStreamPlayer
var journey_started := false
var discovered := false
var is_paused := true
var puzzle_progress := 0
var clue_read := false
var gate_reveal_time := 0.0
var last_checkpoint := "entrance"
var autosave_path := "user://journey.cfg"


func _ready() -> void:
	_setup_input()
	forest = ForestScript.new()
	add_child(forest)
	player = PlayerScript.new()
	add_child(player)
	player.position = _spawn_position()
	player.reset_traversal()
	player.movement_enabled = false
	_create_title_camera()
	_create_ambience()
	interface = UIScript.new()
	add_child(interface)
	interface.start_requested.connect(_start_game)
	interface.magic_pressed.connect(_request_magic)
	interface.jump_pressed.connect(_jump)
	interface.focus_pressed.connect(_focus)
	interface.sprint_changed.connect(_sprint)
	interface.move_changed.connect(_move_touch)
	interface.look_dragged.connect(_look_touch)
	interface.pause_changed.connect(_pause_changed)
	interface.replay_requested.connect(_start_game)
	player.magic_requested.connect(_cast_magic)
	interface.show_title()
	_show_title_camera()
	get_tree().auto_accept_quit = false


func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"magic": [KEY_E], "jump": [KEY_SPACE], "sprint": [KEY_SHIFT],
		"focus": [KEY_Q, KEY_F], "pause": [KEY_ESCAPE]
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(interface):
		if interface._help.visible:
			interface._help.hide()
		elif interface._clue.visible:
			interface._clue.hide()
			interface._set_paused(false)
		elif interface._prologue.visible:
			interface._finish_prologue()
		elif interface._title.visible:
			get_tree().quit()
		elif not interface._discovery.visible:
			interface._set_paused(not is_paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("magic"):
		_request_magic()
	elif event.is_action_pressed("focus"):
		_focus()


func _spawn_position() -> Vector3:
	return Vector3(0, forest.ground_height(0, 30) + 0.08, 30)


func _create_title_camera() -> void:
	title_camera = Camera3D.new()
	title_camera.name = "OpeningCamera"
	title_camera.fov = 52
	title_camera.far = 450
	add_child(title_camera)


func _create_ambience() -> void:
	# The cloud's silent driver cannot consume a continuous playback stream.
	if AudioServer.get_driver_name() == "Dummy":
		return
	var stream := load("res://assets/audio/forest_theme.wav") as AudioStreamWAV
	if stream == null:
		push_warning("A trilha da floresta não pôde ser carregada.")
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
	ambience = AudioStreamPlayer.new()
	ambience.name = "ForestAmbience"
	ambience.stream = stream
	ambience.volume_db = -14
	add_child(ambience)
	ambience.play()


func _exit_tree() -> void:
	# Release loop playback before the audio server shuts down.
	if is_instance_valid(ambience):
		ambience.stop()


func _show_title_camera() -> void:
	var spawn := _spawn_position()
	player.position = spawn
	player.reset_traversal()
	player._visual.rotation.y = PI - 0.24
	title_camera.global_position = spawn + Vector3(-1.8, 1.55, 4.6)
	title_camera.look_at(spawn + Vector3(-1.45, 1.05, -2.0))
	title_camera.make_current()


func _start_game() -> void:
	discovered = false
	puzzle_progress = 0
	clue_read = false
	last_checkpoint = "entrance"
	gate_reveal_time = 0
	forest.reset_landmarks()
	forest.set_gate_open(false)
	player.position = _spawn_position()
	player.reset_traversal()
	player._visual.rotation.y = 0
	player._camera.make_current()
	journey_started = true
	is_paused = false
	player.movement_enabled = true
	interface.show_game()
	interface.set_progress(0)
	interface.set_stamina(100)
	interface.set_objective("Encontre a inscrição no caminho da clareira")
	interface.set_hint("Explore a trilha. Os sinais na pedra podem revelar uma passagem.")


func _move_touch(direction: Vector2) -> void:
	player.touch_move = direction if _can_act() else Vector2.ZERO


func _look_touch(relative: Vector2) -> void:
	if _can_act():
		player.orbit_camera(relative)


func _sprint(held: bool) -> void:
	player.sprint_held = held and _can_act()


func _jump() -> void:
	if _can_act():
		player.request_jump()


func _focus() -> void:
	if not _can_act():
		return
	var nearest := _nearby_source(12.0)
	if nearest >= 0:
		player.focus_on(forest.landmarks[nearest].position + Vector3.UP)
	else:
		player.center_camera()


func _pause_changed(paused: bool) -> void:
	is_paused = paused
	player.movement_enabled = journey_started and not paused and gate_reveal_time <= 0
	player.touch_move = Vector2.ZERO
	player.sprint_held = false
	if paused and interface._title.visible:
		_show_title_camera()


func _can_act() -> bool:
	return journey_started and not is_paused and gate_reveal_time <= 0


func _request_magic() -> void:
	if not _can_act():
		return
	if player.position.distance_to(forest.inscription_position) < INTERACTION_RANGE:
		clue_read = true
		last_checkpoint = "grove"
		interface.set_objective("Desperte os três sinais na ordem da inscrição")
		interface.show_clue()
	else:
		player.cast_magic()


func _nearby_source(max_distance: float = INTERACTION_RANGE) -> int:
	var nearest := -1
	var best_distance := max_distance
	for i in range(forest.landmarks.size()):
		var distance: float = player.position.distance_to(forest.landmarks[i].position)
		if distance < best_distance:
			best_distance = distance
			nearest = i
	return nearest


func _cast_magic() -> void:
	if not _can_act():
		return
	forest.magic_wave(player.global_position)
	var source := _nearby_source()
	if source < 0:
		interface.show_toast("Aproxime-se de um sinal para alcançá-lo com a magia.")
		return
	if forest.gate_open:
		interface.show_toast("Os três sinais permanecem em harmonia.")
		return
	if source != PUZZLE_ORDER[puzzle_progress]:
		puzzle_progress = 0
		forest.reset_landmarks()
		interface.set_progress(0)
		interface.set_objective("Observe a inscrição e recomece a sequência · 0/3")
		interface.show_toast("As luzes se apagam. Observe a relação entre os três sinais.")
		return
	forest.activate_landmark(source)
	puzzle_progress += 1
	interface.set_progress(puzzle_progress)
	if puzzle_progress < PUZZLE_ORDER.size():
		interface.show_toast("%s respondeu. A sequência ainda está incompleta." % SOURCE_NAMES[source])
		interface.set_objective("Complete a sequência dos três sinais · %d/3" % puzzle_progress)
	else:
		_open_passage()


func _open_passage() -> void:
	forest.set_gate_open(true)
	last_checkpoint = "passage"
	interface.set_objective("Atravesse a passagem e encontre a árvore além da clareira")
	interface.show_toast("A passagem se abriu.")
	player.focus_on(Vector3(0, forest.ground_height(0, -34) + 2, -34))
	player.movement_enabled = false
	player.touch_move = Vector2.ZERO
	gate_reveal_time = 1.8


func _complete_region() -> void:
	discovered = true
	last_checkpoint = "sanctuary"
	interface.set_objective("Um novo caminho se abriu")
	interface.show_discovery()
	var save := ConfigFile.new()
	save.set_value("region", "completed", true)
	save.set_value("region", "puzzle_solved", true)
	var error := save.save(autosave_path)
	if error != OK:
		push_warning("Não foi possível registrar a jornada: %s" % error)


func _restart() -> void:
	_start_game()


func _process(delta: float) -> void:
	if not journey_started:
		return
	interface.set_stamina(player.stamina)
	if interface._title.visible:
		return
	if gate_reveal_time > 0 and not is_paused:
		gate_reveal_time = maxf(gate_reveal_time - delta, 0)
		if gate_reveal_time <= 0:
			player.movement_enabled = true
	if player.position.y < -18:
		player.position = _spawn_position()
		player.reset_traversal()
		interface.show_toast("Você voltou ao início da trilha.")
	if not _can_act():
		return
	if not discovered and forest.gate_open and player.position.distance_to(forest.destination_position) < 5:
		_complete_region()
		return
	var inscription_near := player.position.distance_to(forest.inscription_position) < INTERACTION_RANGE
	interface.set_action_label("Ler" if inscription_near else "Magia")
	if inscription_near:
		interface.set_hint("Leia a inscrição · E / Ler")
	else:
		var nearby := _nearby_source()
		if nearby >= 0:
			interface.set_hint("%s · use Magia para despertar este sinal" % SOURCE_NAMES[nearby])
		elif forest.gate_open:
			interface.set_hint("Siga pelo arco de pedra. Há um caminho além dele.")
		elif not clue_read:
			interface.set_hint("A inscrição está junto à trilha. Aproxime-se para ler.")
		else:
			interface.set_hint("A água nutre a raiz. A raiz alcança a luz.")
