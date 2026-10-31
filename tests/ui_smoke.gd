extends SceneTree
## Run: godot --headless --path . --script tests/ui_smoke.gd
## Uses actual dispatched touch events to check simultaneous move/look/cast.

var ui: CanvasLayer
var movement := Vector2.ZERO
var camera_motion := Vector2.ZERO
var started := false
var magic_count := 0
var failed := false

func _initialize() -> void:
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
	ui = preload("res://scripts/game_ui.gd").new()
	root.add_child.call_deferred(ui)
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("UI SMOKE: " + message)

func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)

func _run() -> void:
	await process_frame
	ui.move_changed.connect(func(value: Vector2) -> void: movement = value)
	ui.look_dragged.connect(func(value: Vector2) -> void: camera_motion += value)
	ui.start_requested.connect(func() -> void: started = true)
	ui.magic_pressed.connect(func() -> void: magic_count += 1)
	_check(ui._title.visible, "title should be visible initially")
	var start_button: Button
	for control in ui._title.get_children():
		if control is Button:
			start_button = control
			break
	_touch(0, start_button.get_global_rect().get_center(), true)
	await process_frame
	_touch(0, start_button.get_global_rect().get_center(), false)
	await process_frame
	_check(ui._prologue.visible, "native touch activates title start button")
	for page in range(3):
		_touch(0, ui._next_button.get_global_rect().get_center(), true)
		await process_frame
		_touch(0, ui._next_button.get_global_rect().get_center(), false)
		await process_frame
	_check(started and ui._hud.visible, "prologue ends with start signal and gameplay UI")
	await process_frame
	var stick_point: Vector2 = ui._stick_base.get_global_rect().get_center() + Vector2(40, 0)
	_touch(0, stick_point, true)
	await process_frame
	_check(movement.x > 0.5, "first finger moves character right")
	_touch(2, Vector2(900, 400), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = root.get_final_transform() * Vector2(925, 392)
	drag.relative = root.get_final_transform().basis_xform(Vector2(25, -8))
	Input.parse_input_event(drag)
	await process_frame
	_check(camera_motion.is_equal_approx(Vector2(25, -8)), "second finger orbits camera exactly once")
	_touch(3, ui._magic_button.get_global_rect().get_center(), true)
	await process_frame
	_check(magic_count == 1, "third finger casts once while move and camera remain held")
	_check(movement.x > 0.5, "magic leaves movement active")
	_touch(3, ui._magic_button.get_global_rect().get_center(), false)
	_touch(2, Vector2(925, 392), false)
	await process_frame
	_check(movement.x > 0.5, "releasing camera finger preserves movement")
	_touch(4, ui._pause_button.get_global_rect().get_center(), true)
	await process_frame
	_check(ui._paused and movement == Vector2.ZERO, "pause clears held movement")
	_touch(4, ui._pause_button.get_global_rect().get_center(), false)
	_touch(0, stick_point, false)
	ui._set_paused(false)
	ui.show_discovery()
	_check(ui._discovery.visible and ui._paused, "discovery suspends gameplay input")
	ui.show_title()
	_check(ui._title.visible and not ui._hud.visible, "return to title hides gameplay UI")
	if not failed:
		print("UI_SMOKE_OK: native touch menu/prologue, move/look/cast multitouch, isolated release, pause, discovery, title")
	quit(1 if failed else 0)
