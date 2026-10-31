class_name AsterionUI
extends CanvasLayer
## Original fantasy UI. Region names and puzzle staging remain prototype proposals.

signal start_requested
signal magic_pressed
signal jump_pressed
signal focus_pressed
signal sprint_changed(held: bool)
signal pause_changed(paused: bool)
signal move_changed(direction: Vector2)
signal look_dragged(relative: Vector2)
signal replay_requested
signal title_requested

const PAPER := Color("f6f0dc")
const GOLD := Color("dfc58c")
const MUTED := Color("c6d3c4")
const INK := Color("142e2a")
const SERIF = preload("res://assets/ui_fonts/DejaVuSerif.ttf")
const PROLOGUE: Array[String] = [
	"No princípio, não havia céu ou terra. Não havia estrelas, não havia tempo.\n\nHavia apenas o Infinito.",
	"Juntos, deram forma aos mundos, teceram os céus e estabeleceram os ciclos que regeriam a existência.",
	"E, em cada coisa criada, depositaram uma centelha de sua essência.\n\nAssim, a magia tornou-se parte de tudo o que existia."
]

class Glyph extends Control:
	var kind := 0
	var active := false
	var ink := Color("dfc58c")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var center := size * 0.5
		var r := minf(size.x, size.y) * 0.32
		var tint := ink if active else Color(0.85, 0.88, 0.81, 0.65)
		if active:
			draw_circle(center, r * 1.45, Color(0.82, 0.70, 0.38, 0.10))
		match kind:
			0:
				var points := PackedVector2Array()
				for index in range(33):
					var angle := float(index) / 32.0 * TAU
					points.append(center + Vector2(sin(angle) * r * 0.72 * (1.0 - cos(angle) * 0.3), -cos(angle) * r))
				draw_polyline(points, tint, 2.0, true)
				draw_arc(center + Vector2(0, r * 0.3), r * 0.35, 0.2, 1.8, 16, tint, 1.0, true)
			1:
				draw_line(center + Vector2(0, -r), center + Vector2(0, r), tint, 2.0, true)
				for side in [-1.0, 1.0]:
					draw_line(center + Vector2(0, -r * 0.1), center + Vector2(side * r * 0.7, -r * 0.65), tint, 2.0, true)
					draw_line(center + Vector2(0, r * 0.35), center + Vector2(side * r * 0.68, r * 0.82), tint, 2.0, true)
					draw_line(center + Vector2(side * r * 0.68, r * 0.82), center + Vector2(side * r * 0.92, r * 0.62), tint, 1.5, true)
			2:
				draw_circle(center, r * 0.34, tint)
				for ray in range(8):
					var direction := Vector2.from_angle(ray * TAU / 8.0)
					draw_line(center + direction * r * 0.62, center + direction * r, tint, 1.7, true)

class Flourish extends Control:
	var tint := Color("dfc58c")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var center := size * 0.5
		draw_line(Vector2(0, center.y), Vector2(center.x - 14, center.y), tint, 1.0, true)
		draw_line(Vector2(center.x + 14, center.y), Vector2(size.x, center.y), tint, 1.0, true)
		var diamond := PackedVector2Array([center + Vector2(0, -5), center + Vector2(5, 0), center + Vector2(0, 5), center + Vector2(-5, 0), center + Vector2(0, -5)])
		draw_polyline(diamond, tint, 1.2, true)

var _root: Control
var _title: Control
var _prologue: Control
var _hud: Control
var _pause: Control
var _clue: Control
var _help: Control
var _discovery: Control
var _objective: Label
var _hint: Label
var _toast: Label
var _prologue_text: Label
var _prologue_count: Label
var _next_button: Button
var _start_button: Button
var _stick_base: Panel
var _stick_knob: Panel
var _magic_button: Button
var _jump_button: Button
var _focus_button: Button
var _sprint_button: Button
var _pause_button: Button
var _clue_button: Button
var _stamina: ProgressBar
var _glyphs: Array[Glyph] = []
var _toast_time := 0.0
var _prologue_index := 0
var _playing := false
var _paused := false
var _move_touch := -1
var _look_touch := -1
var _sprint_touch := -1
var _action_touches: Dictionary = {}
var _mouse_look := false
var _stick_radius := 48.0

func _ready() -> void:
	layer = 10
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 18
	_root.theme = theme
	_build_title()
	_build_prologue()
	_build_hud()
	_build_pause()
	_build_clue()
	_build_help()
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

func _full(parent: Node, filter := Control.MOUSE_FILTER_IGNORE) -> Control:
	var control := Control.new()
	parent.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = filter
	return control

func _place(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.anchor_left = x
	control.anchor_top = y
	control.anchor_right = x + w
	control.anchor_bottom = y + h
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0

func _fixed_at(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.anchor_left = x
	control.anchor_right = x
	control.anchor_top = y
	control.anchor_bottom = y
	control.offset_left = -width * 0.5
	control.offset_right = width * 0.5
	control.offset_top = -height * 0.5
	control.offset_bottom = height * 0.5

func _label(parent: Node, text: String, font_size: int, color := PAPER, serif := false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.08, 0.06, 0.65))
	label.add_theme_constant_override("shadow_offset_y", 2)
	if serif:
		label.add_theme_font_override("font", SERIF)
	parent.add_child(label)
	return label

func _style(color: Color, radius := 6, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _button(parent: Node, text: String, accent := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 50)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", INK if accent else PAPER)
	button.add_theme_color_override("font_hover_color", INK if accent else GOLD)
	button.add_theme_color_override("font_pressed_color", INK if accent else GOLD)
	button.add_theme_stylebox_override("normal", _style(GOLD if accent else Color(0.04, 0.12, 0.10, 0.65), 5, Color(0.8, 0.73, 0.49, 0.65)))
	button.add_theme_stylebox_override("hover", _style(Color("f0dca9") if accent else Color("244b3c"), 5, GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("b6a57a") if accent else Color("12382d"), 5, GOLD))
	parent.add_child(button)
	return button

func _gradient(parent: Node, opacity := 0.9, reverse := false) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	gradient.colors = PackedColorArray([Color(0.02, 0.08, 0.06, opacity), Color(0.03, 0.10, 0.08, opacity * 0.78), Color(0.03, 0.10, 0.08, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(1, 0) if reverse else Vector2.ZERO
	texture.fill_to = Vector2.ZERO if reverse else Vector2(1, 0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _veil(parent: Node, opacity := 0.6) -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.025, 0.065, 0.05, opacity)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_title() -> void:
	_title = _full(_root, Control.MOUSE_FILTER_STOP)
	_gradient(_title, 0.92)
	var tag := _label(_title, "UMA JORNADA ENTRE MAGIA E MEMÓRIA", 13, GOLD)
	_place(tag, 0.075, 0.18, 0.55, 0.05)
	var title := _label(_title, "ASTERION", 76, PAPER, true)
	_place(title, 0.067, 0.25, 0.68, 0.15)
	var line := Flourish.new()
	_title.add_child(line)
	_place(line, 0.078, 0.405, 0.29, 0.025)
	var subtitle := _label(_title, "O despertar", 27, GOLD, true)
	_place(subtitle, 0.077, 0.445, 0.40, 0.065)
	var copy := _label(_title, "O mundo guarda caminhos esquecidos.\nEncontre o seu.", 19, MUTED)
	_place(copy, 0.078, 0.545, 0.48, 0.09)
	_start_button = _button(_title, "Iniciar jornada     ›", true)
	_place(_start_button, 0.078, 0.69, 0.285, 0.075)
	_start_button.pressed.connect(_begin_prologue)
	var help_button := _button(_title, "Como jogar")
	_place(help_button, 0.078, 0.79, 0.285, 0.072)
	help_button.pressed.connect(func() -> void: _help.show())
	var footer := _label(_title, "PROTÓTIPO  •  ANDROID / PC", 11, Color(0.83, 0.87, 0.80, 0.7))
	_place(footer, 0.078, 0.94, 0.65, 0.035)

func _build_prologue() -> void:
	_prologue = _full(_root, Control.MOUSE_FILTER_STOP)
	_veil(_prologue, 0.72)
	var chapter := _label(_prologue, "ANTES DOS PRIMEIROS CAMINHOS", 14, GOLD)
	_place(chapter, 0.14, 0.15, 0.72, 0.05)
	_prologue_text = _label(_prologue, "", 29, PAPER, true)
	_prologue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prologue_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_prologue_text, 0.14, 0.27, 0.72, 0.40)
	_prologue_count = _label(_prologue, "", 14, MUTED)
	_place(_prologue_count, 0.14, 0.78, 0.15, 0.06)
	_next_button = _button(_prologue, "Continuar   ›", true)
	_place(_next_button, 0.63, 0.77, 0.23, 0.08)
	_next_button.pressed.connect(_next_prologue)
	var skip := _button(_prologue, "Pular prólogo")
	_place(skip, 0.14, 0.88, 0.22, 0.07)
	skip.pressed.connect(_finish_prologue)

func _round_button(parent: Node, text: String, x: float, y: float, diameter: float, accent := false) -> Button:
	var button := _button(parent, text, accent)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _style(Color(0.90, 0.80, 0.57, 0.93) if accent else Color(0.04, 0.13, 0.11, 0.72), int(diameter * 0.5), Color(0.95, 0.88, 0.68, 0.70)))
	button.add_theme_stylebox_override("hover", _style(Color("efdbac") if accent else Color("315b48"), int(diameter * 0.5), PAPER))
	button.add_theme_stylebox_override("pressed", _style(Color("b9a97f") if accent else Color("183d30"), int(diameter * 0.5), GOLD))
	for state in ["normal", "hover", "pressed"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		style.content_margin_left = 5
		style.content_margin_right = 5
		style.content_margin_top = 4
		style.content_margin_bottom = 4
	_fixed_at(button, x, y, diameter, diameter)
	return button

func _build_hud() -> void:
	_hud = _full(_root)
	var objective_area := _full(_hud)
	_place(objective_area, 0, 0, 0.43, 0.22)
	_gradient(objective_area, 0.67)
	var region := _label(_hud, "A CLAREIRA", 12, GOLD)
	_place(region, 0.033, 0.035, 0.30, 0.045)
	_objective = _label(_hud, "Encontre o caminho pela floresta", 19)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_objective, 0.033, 0.085, 0.35, 0.09)
	var progress_area := Panel.new()
	progress_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_area.add_theme_stylebox_override("panel", _style(Color(0.03, 0.10, 0.08, 0.58), 26, Color(0.8, 0.75, 0.54, 0.35)))
	_hud.add_child(progress_area)
	_fixed_at(progress_area, 0.52, 0.077, 174, 54)
	for index in range(3):
		var glyph := Glyph.new()
		glyph.kind = index
		progress_area.add_child(glyph)
		glyph.position = Vector2(13 + index * 54, 5)
		glyph.size = Vector2(40, 43)
		_glyphs.append(glyph)
	_clue_button = _button(_hud, "Enigma")
	_place(_clue_button, 0.755, 0.037, 0.105, 0.071)
	_clue_button.pressed.connect(show_clue)
	_pause_button = _button(_hud, "Ⅱ")
	_place(_pause_button, 0.901, 0.037, 0.065, 0.071)
	_pause_button.pressed.connect(func() -> void: _set_paused(true))
	_stick_base = Panel.new()
	_stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_base.add_theme_stylebox_override("panel", _style(Color(0.03, 0.12, 0.09, 0.30), 68, Color(0.94, 0.89, 0.71, 0.45)))
	_hud.add_child(_stick_base)
	_fixed_at(_stick_base, 0.115, 0.80, 132, 132)
	_stick_knob = Panel.new()
	_stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_knob.add_theme_stylebox_override("panel", _style(Color(0.94, 0.89, 0.71, 0.28), 25, Color(0.94, 0.89, 0.71, 0.75)))
	_stick_base.add_child(_stick_knob)
	_stick_knob.position = Vector2(41, 41)
	_stick_knob.size = Vector2(50, 50)
	_stamina = ProgressBar.new()
	_stamina.show_percentage = false
	_stamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina.add_theme_stylebox_override("background", _style(Color(0.03, 0.10, 0.08, 0.60), 3))
	_stamina.add_theme_stylebox_override("fill", _style(Color("a7d6a5"), 3))
	for state in ["background", "fill"]:
		var style := _stamina.get_theme_stylebox(state) as StyleBoxFlat
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	_hud.add_child(_stamina)
	_fixed_at(_stamina, 0.115, 0.935, 110, 6)
	_stamina.value = 100
	_stamina.visible = false
	_magic_button = _round_button(_hud, "✧\nMagia", 0.902, 0.79, 106, true)
	_magic_button.add_theme_font_size_override("font_size", 20)
	_magic_button.pressed.connect(func() -> void: magic_pressed.emit())
	_jump_button = _round_button(_hud, "↑\nSaltar", 0.815, 0.90, 76)
	_jump_button.pressed.connect(func() -> void: jump_pressed.emit())
	_focus_button = _round_button(_hud, "◎\nOlhar", 0.805, 0.66, 72)
	_focus_button.pressed.connect(func() -> void: focus_pressed.emit())
	_sprint_button = _round_button(_hud, "Correr", 0.226, 0.88, 68)
	_sprint_button.add_theme_font_size_override("font_size", 14)
	_sprint_button.button_down.connect(func() -> void: sprint_changed.emit(true))
	_sprint_button.button_up.connect(func() -> void: sprint_changed.emit(false))
	_hint = _label(_hud, "", 17)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_hint, 0.30, 0.865, 0.42, 0.09)
	_toast = _label(_hud, "", 22, PAPER, true)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_toast, 0.22, 0.22, 0.56, 0.12)

func _modal(parent: Control, title: String, tag: String) -> VBoxContainer:
	_veil(parent, 0.58)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.105, 0.08, 0.96), 7, Color(0.79, 0.71, 0.47, 0.75)))
	parent.add_child(panel)
	_place(panel, 0.25, 0.15, 0.50, 0.70)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 23)
	margin.add_theme_constant_override("margin_bottom", 23)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	_label(box, tag, 12, GOLD)
	var heading := _label(box, title, 29, PAPER, true)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var flourish := Flourish.new()
	flourish.custom_minimum_size.y = 16
	box.add_child(flourish)
	return box

func _body(parent: Node, value: String, font_size := 18) -> Label:
	var copy := _label(parent, value, font_size, MUTED)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return copy

func _build_pause() -> void:
	_pause = _full(_root, Control.MOUSE_FILTER_STOP)
	var box := _modal(_pause, "Uma pausa na jornada", "ASTERION")
	_body(box, "Escute a floresta. Observe os sinais.\n\nExplore os caminhos e experimente sua magia para descobrir como seguir adiante.")
	var resume := _button(box, "Continuar", true)
	resume.pressed.connect(func() -> void: _set_paused(false))
	var sound := _button(box, "Som: ligado")
	sound.pressed.connect(func() -> void:
		var muted := not AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0, muted)
		sound.text = "Som: desligado" if muted else "Som: ligado"
	)
	var menu := _button(box, "Voltar ao início")
	menu.pressed.connect(show_title)

func _build_clue() -> void:
	_clue = _full(_root, Control.MOUSE_FILTER_STOP)
	var box := _modal(_clue, "O que une os sinais?", "UMA INSCRIÇÃO NA CLAREIRA")
	var verse := _body(box, "A água nutre a raiz.\nA raiz alcança a luz.", 25)
	verse.add_theme_font_override("font", SERIF)
	verse.add_theme_color_override("font_color", PAPER)
	verse.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body(box, "Observe o que responde à sua magia.", 16)
	var close := _button(box, "Guardar as palavras", true)
	close.pressed.connect(func() -> void:
		_clue.hide()
		_set_paused(false)
	)

func _build_help() -> void:
	_help = _full(_root, Control.MOUSE_FILTER_STOP)
	var box := _modal(_help, "Encontre seu caminho", "COMO JOGAR")
	_body(box, "ANDROID\nControle à esquerda para andar. Arraste à direita para olhar. Use Magia, Saltar e Olhar. Segure Correr para acelerar.\n\nPC\nWASD ou setas para andar • mouse para olhar\nE: magia • Espaço: salto • Shift: correr\nQ: centralizar câmera • Esc: pausa", 16)
	var close := _button(box, "Voltar", true)
	close.pressed.connect(func() -> void: _help.hide())

func _build_discovery() -> void:
	_discovery = _full(_root, Control.MOUSE_FILTER_STOP)
	var box := _modal(_discovery, "Um novo caminho", "ALÉM DA CLAREIRA")
	_body(box, "A floresta se abre diante de você.\n\nO que existe além dela ainda é um mistério.", 22)
	var explore := _button(box, "Continuar explorando", true)
	explore.pressed.connect(func() -> void:
		_discovery.hide()
		_set_paused(false)
	)
	var replay := _button(box, "Recomeçar")
	replay.pressed.connect(func() -> void:
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
	_clue.hide()
	_help.hide()
	_discovery.hide()
	pause_changed.emit(true)
	title_requested.emit()

func _begin_prologue() -> void:
	_title.hide()
	_prologue.show()
	_prologue_index = 0
	_update_prologue()

func _update_prologue() -> void:
	_prologue_text.text = PROLOGUE[_prologue_index]
	_prologue_count.text = "%02d  /  03" % (_prologue_index + 1)
	_next_button.text = "Despertar   ›" if _prologue_index == 2 else "Continuar   ›"

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
	_clue.hide()
	_help.hide()
	_hud.show()
	_set_paused(false)

func _set_paused(value: bool) -> void:
	_paused = value
	_pause.visible = value and _playing and not _discovery.visible and not _clue.visible
	if value:
		_release_touches()
	pause_changed.emit(value)

func set_objective(value: String) -> void:
	_objective.text = value

func set_hint(value: String) -> void:
	_hint.text = value

func set_action_label(value: String) -> void:
	_magic_button.text = "✧\n" + value

func set_progress(count: int) -> void:
	for index in range(_glyphs.size()):
		_glyphs[index].active = index < count
		_glyphs[index].queue_redraw()

func set_stamina(value: float) -> void:
	_stamina.value = clampf(value, 0, 100)
	_stamina.visible = value < 99.0

func show_toast(value: String) -> void:
	_toast.text = value
	_toast_time = 4.0
	_toast.modulate.a = 1.0
	_toast.show()

func show_clue() -> void:
	if not _playing:
		return
	_clue.show()
	_set_paused(true)

func show_discovery() -> void:
	_discovery.show()
	_set_paused(true)

func _release_touches() -> void:
	_move_touch = -1
	_look_touch = -1
	_sprint_touch = -1
	_action_touches.clear()
	_mouse_look = false
	if is_instance_valid(_stick_knob):
		_stick_knob.position = Vector2(41, 41)
	move_changed.emit(Vector2.ZERO)
	sprint_changed.emit(false)

func _update_stick(point: Vector2) -> void:
	var center := _stick_base.get_global_rect().get_center()
	var offset := (point - center).limit_length(_stick_radius)
	_stick_knob.position = Vector2(41, 41) + offset
	var direction := offset / _stick_radius
	move_changed.emit(direction if direction.length() > 0.12 else Vector2.ZERO)

func _on_action_touch(point: Vector2, index: int) -> bool:
	var buttons: Array[Button] = [_magic_button, _jump_button, _focus_button, _sprint_button, _clue_button, _pause_button]
	for button in buttons:
		if button.get_global_rect().has_point(point):
			_action_touches[index] = true
			if button == _magic_button:
				magic_pressed.emit()
			elif button == _jump_button:
				jump_pressed.emit()
			elif button == _focus_button:
				focus_pressed.emit()
			elif button == _sprint_button:
				_sprint_touch = index
				sprint_changed.emit(true)
			elif button == _clue_button:
				show_clue()
			else:
				_set_paused(true)
			return true
	return false

func _over_game_button(point: Vector2) -> bool:
	for button: Button in [_magic_button, _jump_button, _focus_button, _sprint_button, _clue_button, _pause_button]:
		if button.get_global_rect().has_point(point):
			return true
	return false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _playing and not _discovery.visible:
		if _clue.visible:
			_clue.hide()
			_set_paused(false)
		else:
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
				_stick_knob.position = Vector2(41, 41)
				move_changed.emit(Vector2.ZERO)
			if touch.index == _look_touch:
				_look_touch = -1
			if touch.index == _sprint_touch:
				_sprint_touch = -1
				sprint_changed.emit(false)
			if _action_touches.has(touch.index):
				_action_touches.erase(touch.index)
				get_viewport().set_input_as_handled()
			return
		if _on_action_touch(touch.position, touch.index):
			get_viewport().set_input_as_handled()
			return
		if touch.position.x < area.x * 0.36 and touch.position.y > area.y * 0.38 and _move_touch == -1:
			_move_touch = touch.index
			_update_stick(touch.position)
			get_viewport().set_input_as_handled()
		elif touch.position.x >= area.x * 0.36 and _look_touch == -1:
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
			elif not _over_game_button(mouse.position):
				_mouse_look = mouse.position.x > area.x * 0.25
	elif event is InputEventMouseMotion and _mouse_look and event.device != InputEvent.DEVICE_ID_EMULATION:
		look_dragged.emit((event as InputEventMouseMotion).relative)
