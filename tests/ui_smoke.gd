extends SceneTree
## Real native touches verify Android menus and independent multi-finger controls.

var ui: CanvasLayer
var movement := Vector2.ZERO
var camera_motion := Vector2.ZERO
var started := false
var magic_count := 0
var jump_count := 0
var focus_count := 0
var sprint_held := false
var checks := 0
var failed := false

func _initialize() -> void:
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
	ui = preload("res://scripts/game_ui.gd").new()
	root.add_child.call_deferred(ui)
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("UI SMOKE: " + message)

func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)

func _tap(button: Button, index := 0) -> void:
	_touch(index, button.get_global_rect().get_center(), true)
	await process_frame
	_touch(index, button.get_global_rect().get_center(), false)
	await process_frame

func _run() -> void:
	await process_frame
	ui.move_changed.connect(func(value: Vector2) -> void: movement = value)
	ui.look_dragged.connect(func(value: Vector2) -> void: camera_motion += value)
	ui.start_requested.connect(func() -> void: started = true)
	ui.magic_pressed.connect(func() -> void: magic_count += 1)
	ui.jump_pressed.connect(func() -> void: jump_count += 1)
	ui.focus_pressed.connect(func() -> void: focus_count += 1)
	ui.sprint_changed.connect(func(held: bool) -> void: sprint_held = held)
	_check(ui._title.visible, "title is initially visible")
	await _tap(ui._start_button)
	_check(ui._prologue.visible, "native touch activates start button")
	for page in range(3):
		await _tap(ui._next_button)
	_check(started and ui._hud.visible, "prologue ends with start signal")
	var stick_point: Vector2 = ui._stick_base.get_global_rect().get_center() + Vector2(38, 0)
	_touch(0, stick_point, true)
	await process_frame
	_check(movement.x > 0.5, "first finger moves right")
	_touch(2, Vector2(800, 350), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = root.get_final_transform() * Vector2(825, 342)
	drag.relative = root.get_final_transform().basis_xform(Vector2(25, -8))
	Input.parse_input_event(drag)
	await process_frame
	_check(camera_motion.is_equal_approx(Vector2(25, -8)), "second finger orbits exactly once")
	await _tap(ui._magic_button, 3)
	_check(magic_count == 1 and movement.x > 0.5, "magic works independently during movement")
	await _tap(ui._jump_button, 3)
	_check(jump_count == 1 and movement.x > 0.5, "jump works while movement is held")
	await _tap(ui._focus_button, 3)
	_check(focus_count == 1, "camera focus works with an independent touch")
	_touch(3, ui._sprint_button.get_global_rect().get_center(), true)
	await process_frame
	_check(sprint_held and movement.x > 0.5, "sprint can be held while walking")
	_touch(3, ui._sprint_button.get_global_rect().get_center(), false)
	await process_frame
	_check(not sprint_held and movement.x > 0.5, "releasing sprint preserves movement")
	_touch(2, Vector2(825, 342), false)
	await process_frame
	_check(movement.x > 0.5, "releasing look preserves movement")
	await _tap(ui._pause_button, 4)
	_check(ui._paused and movement == Vector2.ZERO and not sprint_held, "pause clears movement and sprint")
	_touch(0, stick_point, false)
	ui._set_paused(false)
	await _tap(ui._clue_button)
	_check(ui._clue.visible and ui._paused, "inscription opens on request and suspends movement")
	ui._clue.hide()
	ui._set_paused(false)
	ui.set_progress(2)
	_check(ui._glyphs[0].active and ui._glyphs[1].active and not ui._glyphs[2].active, "puzzle progress illuminates the expected glyphs")
	ui.set_stamina(43)
	_check(ui._stamina.visible and ui._stamina.value == 43, "stamina appears when spent")
	ui.set_action_label("Ler")
	_check(ui._magic_button.text.contains("Ler"), "contextual action can become Read")
	ui.show_discovery()
	_check(ui._discovery.visible and ui._paused, "destination card suspends gameplay")
	ui.show_title()
	_check(ui._title.visible and not ui._hud.visible, "return to title hides gameplay")
	print("UI_SMOKE: %d checks, %s" % [checks, "FAILED" if failed else "PASSED"])
	quit(1 if failed else 0)
