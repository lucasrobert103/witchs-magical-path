extends Node
## Screen flow: title → prologue → chapter → ending, plus input routing and pause.

var world: World
var ui: UIRoot
var state := "title"   # title, prologue, play, paused, ending, loading
var _settings_from := ""

func _ready() -> void:
	ui = UIRoot.new()
	add_child(ui)
	ui.title.new_game.connect(_on_new_game)
	ui.title.continue_game.connect(_on_continue)
	ui.title.open_settings.connect(func(): _open_settings("title"))
	ui.pause_menu.resume.connect(_resume)
	ui.pause_menu.settings.connect(func(): _open_settings("pause"))
	ui.pause_menu.to_title.connect(_pause_to_title)
	ui.settings.closed.connect(_close_settings)
	ui.ending.to_title.connect(_ending_to_title)
	ui.prologue.done.connect(_on_prologue_done)
	ui.dialogue.finished.connect(_on_dialogue_finished)
	ui.touch.action.connect(_on_touch_action)
	if Game.has_save() and Game.load_game():
		pass
	else:
		Game.new_state()
	_make_world()
	_show_title()

func _make_world() -> void:
	if world:
		world.queue_free()
		remove_child(world)
	world = World.new()
	add_child(world)
	move_child(world, 0)
	world.dialogue_requested.connect(_on_dialogue_requested)
	world.fade_requested.connect(func(to_black, d): ui.fade_to(1.0 if to_black else 0.0, d))
	world.chapter_completed.connect(_on_chapter_completed)
	ui.hud.bind(world)

func _show_title() -> void:
	state = "title"
	get_tree().paused = false
	world.mode = "title"
	world.visible = true
	ui.set_gameplay_visible(false)
	ui.title.visible = true
	ui.title.refresh()
	ui.title.focus_first()
	ui.ending.visible = false
	ui.pause_menu.visible = false
	Audio.play_music("res://assets/audio/music_forest.ogg", 2.5, -5.0)
	Audio.play_ambience("res://assets/audio/ambience_forest.ogg", -12.0)
	ui.fade_to(0.0, 1.6)

func _on_new_game() -> void:
	if state != "title":
		return
	state = "loading"
	await ui.fade_to(1.0, 0.8).finished
	Game.delete_save()
	Game.new_state()
	_make_world()
	world.mode = "cutscene"
	world.visible = false
	ui.title.visible = false
	ui.prologue.visible = true
	ui.prologue.start()
	Audio.play_ambience("")
	state = "prologue"
	ui.fade_to(0.0, 1.2)

func _on_prologue_done() -> void:
	if state != "prologue":
		return
	state = "loading"
	await ui.fade_to(1.0, 1.5).finished
	ui.prologue.visible = false
	world.visible = true
	Audio.play_music("res://assets/audio/music_forest.ogg", 4.0, -5.0)
	Audio.play_ambience("res://assets/audio/ambience_forest.ogg", -12.0)
	ui.set_gameplay_visible(true)
	state = "play"
	world.begin_new_game()
	ui.fade_to(0.0, 3.0)

func _on_continue() -> void:
	if state != "title":
		return
	state = "loading"
	await ui.fade_to(1.0, 0.8).finished
	Game.load_game()
	_make_world()
	ui.title.visible = false
	ui.set_gameplay_visible(true)
	state = "play"
	world.begin_play()
	ui.fade_to(0.0, 1.2)

func _on_dialogue_requested(lines: Array) -> void:
	ui.dialogue.show_lines(lines)
	world.set_dialogue_open(true)
	if world.mode == "play":
		world.mode = "cutscene"

func _on_dialogue_finished() -> void:
	world.set_dialogue_open(false)
	world.on_dialogue_finished()

func _on_chapter_completed(stats: Dictionary) -> void:
	state = "ending"
	ui.set_gameplay_visible(false)
	ui.ending.visible = true
	ui.ending.show_stats(stats)
	Audio.play_music("res://assets/audio/music_prologue.ogg", 3.0, -4.0)

func _ending_to_title() -> void:
	await ui.fade_to(1.0, 0.8).finished
	ui.ending.visible = false
	Game.load_game()
	_make_world()
	_show_title()

func _pause() -> void:
	if state != "play":
		return
	state = "paused"
	get_tree().paused = true
	ui.pause_menu.visible = true
	ui.pause_menu.focus_first()
	ui.touch.reset()
	Audio.sfx("open", -8.0)

func _resume() -> void:
	if state != "paused":
		return
	state = "play"
	ui.pause_menu.visible = false
	get_tree().paused = false

func _pause_to_title() -> void:
	world.checkpoint(String(Game.state.get("checkpoint", "clearing")))
	ui.pause_menu.visible = false
	get_tree().paused = false
	await ui.fade_to(1.0, 0.6).finished
	Game.load_game()
	_make_world()
	_show_title()

func _open_settings(from: String) -> void:
	_settings_from = from
	ui.settings.visible = true

func _close_settings() -> void:
	ui.settings.visible = false
	if _settings_from == "pause":
		ui.pause_menu.focus_first()
	else:
		ui.title.focus_first()

func _on_touch_action(name: String) -> void:
	if state != "play":
		return
	if ui.dialogue.active:
		ui.dialogue.advance()
		return
	match name:
		"magic":
			world.do_cast()
		"jump":
			world.do_jump()
		"interact":
			world.do_interact()
		"essence":
			world.do_swap_essence()
		"pause":
			_pause()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match state:
			"play":
				_pause()
			"paused":
				if ui.settings.visible:
					_close_settings()
				else:
					_resume()
			"title":
				if ui.settings.visible:
					_close_settings()
				else:
					get_tree().quit()
			"prologue":
				ui.prologue.finish()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause()

func _input(event: InputEvent) -> void:
	if state == "play" and ui.dialogue.active:
		var tap: bool = (event is InputEventScreenTouch and event.pressed)
		if tap or event.is_action_pressed("interact") or event.is_action_pressed("cast") or event.is_action_pressed("jump"):
			ui.dialogue.advance()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		if state == "play":
			_pause()
		elif state == "paused" and not ui.settings.visible:
			_resume()
		return
	if state == "play" and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		world.cam_rig.rotate_by(event.relative.x, event.relative.y)

func _process(delta: float) -> void:
	if state != "play" or world == null:
		return
	ui.touch.show_magic = world.player.magic_unlocked
	ui.touch.show_essence = Game.flag("flame_done")
	ui.touch.essence = world.player.essence if world.player.essence != "" else "moon"
	ui.touch.show_interact = world._prompt_text != "" and world.mode == "play"
	ui.touch.interact_text = world._prompt_text
	ui.touch.visible = ui.hud.visible and not ui.dialogue.active and (Game.is_touch_device() or OS.get_environment("ASTERION_TOUCH") == "1")
	if ui.dialogue.active:
		world.player.move_input = Vector2.ZERO
		return
	var kb := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var mv := ui.touch.move if ui.touch.move.length() > kb.length() else kb
	world.player.move_input = mv
	world.player.run_held = Input.is_action_pressed("run")
	if ui.touch.look_delta != Vector2.ZERO:
		world.cam_rig.rotate_by(ui.touch.look_delta.x, ui.touch.look_delta.y)
		ui.touch.look_delta = Vector2.ZERO
	var turn := Input.get_axis("cam_left", "cam_right")
	if turn != 0.0:
		world.cam_rig.rotate_by(turn * 500.0 * delta, 0.0)
	if Input.is_action_just_pressed("cast"):
		world.do_cast()
	if Input.is_action_just_pressed("jump"):
		world.do_jump()
	if Input.is_action_just_pressed("interact"):
		world.do_interact()
	if Input.is_action_just_pressed("swap_essence"):
		world.do_swap_essence()
