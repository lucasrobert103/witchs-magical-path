class_name DialogueBox
extends Control
## Bottom dialogue panel with Asterion's portrait and a typewriter reveal.

signal finished

var _lines: Array = []
var _index := 0
var _panel: PanelContainer
var _portrait_frame: Control
var _portrait: TextureRect
var _name: Label
var _text: Label
var _hint: Label
var _typing := 0.0
var active := false
var _cooldown := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	var style := UIKit.panel_style(Color(0.035, 0.06, 0.05, 0.9), UIKit.GOLD_DIM, 18, 2)
	style.content_margin_left = 30
	style.content_margin_right = 34
	style.content_margin_top = 20
	style.content_margin_bottom = 22
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.custom_minimum_size = Vector2(980, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.position = Vector2(-490, -30)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	_panel.add_child(row)
	_portrait_frame = PortraitFrame.new()
	_portrait_frame.custom_minimum_size = Vector2(150, 150)
	row.add_child(_portrait_frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	_name = UIKit.label("Asterion", UIKit.title_font, 24, UIKit.GOLD)
	col.add_child(_name)
	_text = UIKit.label("", UIKit.serif, 33, UIKit.CREAM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(740, 96)
	col.add_child(_text)
	_hint = UIKit.label("toque para continuar  ▸", UIKit.sans, 16, Color(0.86, 0.76, 0.54, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
	col.add_child(_hint)

class PortraitFrame extends Control:
	var tex: Texture2D = load("res://assets/sprites/witch/portrait.png")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(0.12, 0.2, 0.15))
		# Clip the portrait to a circle by drawing a textured polygon.
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var src := Rect2(120, 40, 280, 280)
		var ts := tex.get_size()
		for i in 48:
			var a := TAU * i / 48.0
			var d := Vector2(cos(a), sin(a))
			pts.append(c + d * (r - 3))
			uvs.append((src.get_center() + d * src.size.x * 0.5) / ts)
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
		draw_arc(c, r - 2, 0, TAU, 64, UIKit.GOLD, 3.0, true)

func show_lines(lines: Array) -> void:
	if lines.is_empty():
		return
	if active:
		_lines.append_array(lines)
		return
	_lines = lines.duplicate()
	_index = 0
	active = true
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	_show_current()

func _show_current() -> void:
	var line: Dictionary = _lines[_index]
	var speaker: String = line.get("speaker", "")
	var has_portrait: bool = line.get("portrait", false)
	_portrait_frame.visible = has_portrait
	_name.visible = speaker != ""
	_name.text = speaker
	_text.text = line.get("text", "")
	var narration := speaker == ""
	_text.add_theme_font_override("font", UIKit.serif_italic if narration else UIKit.serif)
	_text.add_theme_color_override("font_color", Color("f1e2bd") if narration else UIKit.CREAM)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narration else HORIZONTAL_ALIGNMENT_LEFT
	_text.visible_characters = 0
	_typing = 0.0
	UIKit.pin(_panel, 0.5, 1.0, 0.0, -26.0)
	_cooldown = 0.15

func _process(delta: float) -> void:
	if not active:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	var total := _text.get_total_character_count()
	if _text.visible_characters < total:
		_typing += delta * 52.0
		_text.visible_characters = mini(total, int(_typing))
	_hint.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005) if _text.visible_characters >= total else 0.0

func advance() -> void:
	if not active or _cooldown > 0.0:
		return
	var total := _text.get_total_character_count()
	if _text.visible_characters < total:
		_text.visible_characters = total
		_typing = total
		return
	_index += 1
	if _index >= _lines.size():
		close()
	else:
		Audio.sfx("click", -14.0)
		_show_current()

func close() -> void:
	active = false
	_lines.clear()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): visible = false)
	finished.emit()

func _gui_input(_event: InputEvent) -> void:
	pass
