class_name AsterionUI
extends CanvasLayer

signal start_requested
signal magic_pressed
signal pause_changed(paused: bool)
signal move_changed(direction: Vector2)
signal look_dragged(relative: Vector2)
signal replay_requested

const INK := Color("101824")
const GOLD := Color("e5c98a")
const PAPER := Color("f4eee3")
const MUTED := Color("aebbc4")
const PROLOGUE: Array[String] = [
	"No princípio, não havia céu ou terra. Não havia estrelas, não havia tempo.\n\nHavia apenas o Infinito.",
	"Juntos, deram forma aos mundos, teceram os céus e estabeleceram os ciclos que regeriam a existência.",
	"E, em cada coisa criada, depositaram uma centelha de sua essência.\n\nAssim, a magia tornou-se parte de tudo o que existia."
]

class Stardust extends Control:
	var points: Array[Vector3] = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 9146
		for index in range(100):
			points.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.5, 1.8)))
		resized.connect(queue_redraw)
	func _draw() -> void:
		for point in points:
			draw_circle(Vector2(point.x * size.x, point.y * size.y), point.z, Color(0.8, 0.85, 0.91, 0.22 + point.z * 0.13))
		var center := Vector2(size.x * 0.77, size.y * 0.44)
		draw_arc(center, size.y * 0.28, 0, TAU, 100, Color(0.9, 0.79, 0.54, 0.2), 1.0, true)
		draw_arc(center, size.y * 0.23, 0, TAU, 100, Color(0.9, 0.79, 0.54, 0.12), 1.0, true)
		draw_circle(center, size.y * 0.12, Color("d9c99d"))
		draw_circle(center + Vector2(size.y * 0.052, -size.y * 0.035), size.y * 0.112, Color("141e2b"))

var _root: Control
var _title: Control
var _prologue: Control
var _hud: Control
var _pause: Control
var _discovery: Control
var _objective: Label
var _hint: Label
var _toast: Label
var _prologue_text: Label
var _prologue_count: Label
var _next_button: Button
var _stick_base: Panel
var _stick_knob: Panel
var _magic_button: Button
var _pause_button: Button
var _toast_time := 0.0
var _prologue_index := 0
var _playing := false
var _paused := false
var _move_touch := -1
var _look_touch := -1
var _mouse_look := false
var _stick_center := Vector2.ZERO
var _stick_radius := 54.0

func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var theme := Theme.new()
	theme.default_font_size = 18
	_root.theme = theme
	_build_title()
	_build_prologue()
	_build_hud()
	_build_pause()
	_build_discovery()
	show_title()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _playing:
		_set_paused(true)

func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = minf(_toast_time * 2.0, 1.0)
		_toast.visible = _toast_time > 0.0

func _full(parent: Node, input_filter: int = Control.MOUSE_FILTER_IGNORE) -> Control:
	var control := Control.new()
	parent.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = input_filter
	return control

func _label(parent: Node, value: String, font_size: int, tint: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _style(color: Color, radius: int = 14, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _button(parent: Node, value: String, accent: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", INK if accent else PAPER)
	button.add_theme_color_override("font_hover_color", INK if accent else GOLD)
	button.add_theme_color_override("font_pressed_color", INK if accent else GOLD)
	button.add_theme_stylebox_override("normal", _style(GOLD if accent else Color("1b2a3c"), 12, Color("786c50") if accent else Color("3c4c5c")))
	button.add_theme_stylebox_override("hover", _style(Color("f4dda8") if accent else Color("283b50"), 12, GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("bca471") if accent else Color("132336"), 12, GOLD))
	parent.add_child(button)
	return button

func _place(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.anchor_left = x
	control.anchor_top = y
	control.anchor_right = x + w
	control.anchor_bottom = y + h
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0

func _backdrop(parent: Node, opacity: float = 0.88) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.035, 0.055, 0.085, opacity)
	parent.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect

func _build_title() -> void:
	_title = _full(_root, Control.MOUSE_FILTER_STOP)
	var backdrop := _backdrop(_title, 1.0)
	backdrop.color = Color("141e2b")
	var stars := Stardust.new()
	_title.add_child(stars)
	stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tag := _label(_title, "UM MUNDO AINDA SEM MEMÓRIA", 15, GOLD)
	_place(tag, 0.07, 0.16, 0.58, 0.05)
	var title := _label(_title, "ASTERION", 70)
	_place(title, 0.065, 0.235, 0.64, 0.15)
	var subtitle := _label(_title, "O despertar", 32, GOLD)
	_place(subtitle, 0.07, 0.39, 0.6, 0.075)
	var copy := _label(_title, "Uma floresta antiga. Um poder desconhecido.\nUma jornada para descobrir quem você é.", 20, MUTED)
	_place(copy, 0.07, 0.50, 0.57, 0.12)
	var start := _button(_title, "Iniciar jornada   →", true)
	_place(start, 0.07, 0.675, 0.30, 0.085)
	start.pressed.connect(_begin_prologue)
	var controls := _label(_title, "TOQUE: mover • olhar • magia\nPC: WASD / setas • arrastar para olhar • E / Espaço", 15, MUTED)
	_place(controls, 0.07, 0.795, 0.65, 0.10)
	var prototype := _label(_title, "PROTÓTIPO JOGÁVEL  /  ANDROID + PC", 13, Color("8999a9"))
	_place(prototype, 0.07, 0.94, 0.78, 0.04)

func _build_prologue() -> void:
	_prologue = _full(_root, Control.MOUSE_FILTER_STOP)
	_backdrop(_prologue, 1.0)
	var stars := Stardust.new()
	_prologue.add_child(stars)
	stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tag := _label(_prologue, "PRÓLOGO  /  A ORIGEM DA MAGIA", 16, GOLD)
	_place(tag, 0.09, 0.12, 0.8, 0.06)
	_prologue_text = _label(_prologue, "", 29)
	_prologue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prologue_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_prologue_text, 0.09, 0.25, 0.64, 0.40)
	_prologue_count = _label(_prologue, "", 16, MUTED)
	_place(_prologue_count, 0.09, 0.76, 0.2, 0.06)
	_next_button = _button(_prologue, "Continuar   →", true)
	_place(_next_button, 0.62, 0.76, 0.28, 0.09)
	_next_button.pressed.connect(_next_prologue)
	var skip := _button(_prologue, "Pular prólogo")
	_place(skip, 0.09, 0.87, 0.24, 0.08)
	skip.pressed.connect(_finish_prologue)

func _build_hud() -> void:
	_hud = _full(_root)
	var objective_panel := Panel.new()
	objective_panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.08, 0.12, 0.86), 12, Color(0.8, 0.73, 0.54, 0.35)))
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(objective_panel)
	_place(objective_panel, 0.025, 0.035, 0.48, 0.135)
	var chapter := _label(objective_panel, "O DESPERTAR", 13, GOLD)
	_place(chapter, 0.04, 0.08, 0.91, 0.30)
	_objective = _label(objective_panel, "Explore a clareira", 20)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_objective, 0.04, 0.36, 0.92, 0.58)
	_pause_button = _button(_hud, "Ⅱ")
	_place(_pause_button, 0.91, 0.035, 0.065, 0.085)
	_pause_button.pressed.connect(func() -> void: _set_paused(true))
	_stick_base = Panel.new()
	_stick_base.add_theme_stylebox_override("panel", _style(Color(0.05, 0.1, 0.15, 0.50), 75, Color(0.9, 0.84, 0.68, 0.45)))
	_stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_stick_base)
	_stick_base.anchor_left = 0.12
	_stick_base.anchor_right = 0.12
	_stick_base.anchor_top = 0.79
	_stick_base.anchor_bottom = 0.79
	_stick_base.offset_left = -73
	_stick_base.offset_right = 73
	_stick_base.offset_top = -73
	_stick_base.offset_bottom = 73
	_stick_knob = Panel.new()
	_stick_knob.add_theme_stylebox_override("panel", _style(Color(0.86, 0.81, 0.66, 0.45), 28, Color(0.96, 0.9, 0.75, 0.65)))
	_stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_base.add_child(_stick_knob)
	_stick_knob.position = Vector2(46, 46)
	_stick_knob.size = Vector2(54, 54)
	var move_label := _label(_hud, "MOVER", 12, MUTED)
	_place(move_label, 0.055, 0.925, 0.13, 0.035)
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_magic_button = _button(_hud, "✧\nMagia", true)
	_magic_button.add_theme_font_size_override("font_size", 23)
	_magic_button.add_theme_stylebox_override("normal", _style(Color(0.90, 0.79, 0.54, 0.92), 64, Color("fff0c4")))
	_magic_button.anchor_left = 0.89
	_magic_button.anchor_right = 0.89
	_magic_button.anchor_top = 0.80
	_magic_button.anchor_bottom = 0.80
	_magic_button.offset_left = -58
	_magic_button.offset_right = 58
	_magic_button.offset_top = -58
	_magic_button.offset_bottom = 58
	_magic_button.pressed.connect(func() -> void: magic_pressed.emit())
	_hint = _label(_hud, "Arraste à direita para olhar", 17)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_place(_hint, 0.25, 0.87, 0.50, 0.09)
	_toast = _label(_hud, "", 22, GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_shadow_color", Color.BLACK)
	_toast.add_theme_constant_override("shadow_offset_y", 2)
	_place(_toast, 0.20, 0.23, 0.60, 0.12)

func _modal(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("142333"), 20, Color("695d44")))
	parent.add_child(panel)
	_place(panel, 0.24, 0.17, 0.52, 0.66)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 15)
	margin.add_child(box)
	return box

func _build_pause() -> void:
	_pause = _full(_root, Control.MOUSE_FILTER_STOP)
	_backdrop(_pause, 0.86)
	var box := _modal(_pause)
	_label(box, "Uma pausa na jornada", 29, GOLD)
	var instructions := _label(box, "Android: joystick para caminhar; arraste à direita para olhar; toque em Magia.\n\nPC: WASD ou setas para caminhar; arraste o mouse para olhar; E ou Espaço para magia; Esc para pausar.", 18, MUTED)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var resume := _button(box, "Continuar", true)
	resume.pressed.connect(func() -> void: _set_paused(false))
	var menu := _button(box, "Voltar ao início")
	menu.pressed.connect(show_title)

func _build_discovery() -> void:
	_discovery = _full(_root, Control.MOUSE_FILTER_STOP)
	_backdrop(_discovery, 0.86)
	var box := _modal(_discovery)
	_label(box, "UMA PRIMEIRA DESCOBERTA", 14, GOLD)
	var title := _label(box, "Uma resposta na floresta", 28)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var copy := _label(box, "Você tocou algo que ainda não compreende.\n\nFim desta primeira experiência jogável. A origem de Asterion continua um mistério.", 19, MUTED)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var explore := _button(box, "Continuar explorando", true)
	explore.pressed.connect(func() -> void:
		_discovery.hide()
		_set_paused(false)
	)
	var replay := _button(box, "Recomeçar")
	replay.pressed.connect(func() -> void:
		_discovery.hide()
		show_game()
		replay_requested.emit()
	)

func show_title() -> void:
	_playing = false
	_paused = true
	_release_touches()
	_title.show()
	_prologue.hide()
	_hud.hide()
	_pause.hide()
	_discovery.hide()
	pause_changed.emit(true)

func _begin_prologue() -> void:
	_title.hide()
	_prologue.show()
	_prologue_index = 0
	_update_prologue()

func _update_prologue() -> void:
	_prologue_text.text = PROLOGUE[_prologue_index]
	_prologue_count.text = "%02d / 03" % (_prologue_index + 1)
	_next_button.text = "Despertar   →" if _prologue_index == 2 else "Continuar   →"

func _next_prologue() -> void:
	_prologue_index += 1
	if _prologue_index >= PROLOGUE.size():
		_finish_prologue()
	else:
		_update_prologue()

func _finish_prologue() -> void:
	show_game()
	start_requested.emit()

func show_game() -> void:
	_playing = true
	_title.hide()
	_prologue.hide()
	_discovery.hide()
	_hud.show()
	_set_paused(false)

func _set_paused(value: bool) -> void:
	_paused = value
	_pause.visible = value and _playing and not _discovery.visible
	if value:
		_release_touches()
	pause_changed.emit(value)

func set_objective(value: String) -> void:
	_objective.text = value

func set_hint(value: String) -> void:
	_hint.text = value

func show_toast(value: String) -> void:
	_toast.text = value
	_toast_time = 4.0
	_toast.modulate.a = 1.0
	_toast.show()

func show_discovery() -> void:
	_discovery.show()
	_set_paused(true)

func _release_touches() -> void:
	_move_touch = -1
	_look_touch = -1
	_mouse_look = false
	if is_instance_valid(_stick_knob):
		_stick_knob.position = Vector2(46, 46)
	move_changed.emit(Vector2.ZERO)

func _update_stick(point: Vector2) -> void:
	_stick_center = _stick_base.get_global_rect().get_center()
	var offset := (point - _stick_center).limit_length(_stick_radius)
	_stick_knob.position = Vector2(46, 46) + offset
	var direction := offset / _stick_radius
	move_changed.emit(direction if direction.length() > 0.12 else Vector2.ZERO)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _playing and not _discovery.visible:
		_set_paused(not _paused)
		get_viewport().set_input_as_handled()
		return
	if not _playing or _paused:
		return
	var area := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			if touch.index == _move_touch:
				_move_touch = -1
				_stick_knob.position = Vector2(46, 46)
				move_changed.emit(Vector2.ZERO)
			if touch.index == _look_touch:
				_look_touch = -1
			return
		if _magic_button.get_global_rect().has_point(touch.position):
			magic_pressed.emit()
			get_viewport().set_input_as_handled()
			return
		if _pause_button.get_global_rect().has_point(touch.position):
			_set_paused(true)
			get_viewport().set_input_as_handled()
			return
		if touch.position.x < area.x * 0.4 and touch.position.y > area.y * 0.4 and _move_touch == -1:
			_move_touch = touch.index
			_update_stick(touch.position)
			get_viewport().set_input_as_handled()
		elif touch.position.x >= area.x * 0.4 and _look_touch == -1:
			_look_touch = touch.index
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _move_touch:
			_update_stick(drag.position)
			get_viewport().set_input_as_handled()
		elif drag.index == _look_touch:
			look_dragged.emit(drag.relative)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT or mouse.button_index == MOUSE_BUTTON_RIGHT:
			if not mouse.pressed:
				_mouse_look = false
			elif not _magic_button.get_global_rect().has_point(mouse.position) and not _pause_button.get_global_rect().has_point(mouse.position):
				_mouse_look = mouse.position.x > area.x * 0.25
	elif event is InputEventMouseMotion and _mouse_look and event.device != InputEvent.DEVICE_ID_EMULATION:
		look_dragged.emit((event as InputEventMouseMotion).relative)
