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
	_portrait_frame.custom_minimum_size = Vector2(168, 168)
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
	## Living portrait: breathes, blinks, sways while she talks and reacts to the mood
	## of the line (a tilt for questions, a small start for exclamations).
	var tex: Texture2D = load("res://assets/sprites/witch/portrait.png")
	var eyes: Array = []
	var skin: Array = []
	var talking := false
	var t := 0.0
	var blink := 0.0
	var _blink_t := -1.0
	var _next_blink := 2.0
	var pop := 0.0
	var tilt_target := 0.0
	var _tilt := 0.0
	var dim_target := 0.0
	var _dim := 0.0
	const SRC_C := Vector2(256, 246)
	const SRC_R := 236.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var f := FileAccess.open("res://assets/sprites/witch/portrait.json", FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if typeof(data) == TYPE_DICTIONARY:
				eyes = data.get("eyes", [])
		var img := tex.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			for e in eyes:
				var c := img.get_pixel(clampi(int(e[0]), 0, img.get_width() - 1), clampi(int(e[1] - e[3] * 0.95), 0, img.get_height() - 1))
				skin.append(c)
	func mood(text: String) -> void:
		tilt_target = 0.0
		dim_target = 0.0
		if text.contains("?"):
			tilt_target = deg_to_rad(3.5)
		if text.contains("!"):
			pop = 1.0
		if text.begins_with("...") or text == "…":
			dim_target = 0.22
			tilt_target = deg_to_rad(-2.0)
	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		t += delta
		pop = maxf(0.0, pop - delta * 3.0)
		_tilt = lerpf(_tilt, tilt_target, clampf(delta * 5.0, 0.0, 1.0))
		_dim = lerpf(_dim, dim_target, clampf(delta * 4.0, 0.0, 1.0))
		_next_blink -= delta
		if _next_blink <= 0.0 and _blink_t < 0.0:
			_blink_t = 0.0
			_next_blink = randf_range(2.2, 5.0) if randf() > 0.2 else 0.35
		if _blink_t >= 0.0:
			_blink_t += delta
			blink = clampf(1.0 - absf(_blink_t - 0.07) / 0.07, 0.0, 1.0)
			if _blink_t > 0.14:
				_blink_t = -1.0
				blink = 0.0
		queue_redraw()
	func _to_screen(src: Vector2, c: Vector2, r: float, scale: float, bob: Vector2) -> Vector2:
		var d := (src - SRC_C - bob) / SRC_R * scale
		return c + d.rotated(_tilt) * r
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 6.0
		var scale := 1.0 + 0.012 * sin(t * 1.7) + pop * 0.06
		var bob := Vector2(0, sin(t * 15.0) * 2.2) if talking else Vector2.ZERO
		bob.y += sin(t * 1.7) * 2.0
		# Soft halo and shadow.
		draw_circle(c + Vector2(0, 4), r + 9.0, Color(0, 0, 0, 0.35))
		draw_circle(c, r + 7.0, Color(1.0, 0.85, 0.5, 0.18 + 0.1 * pop))
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var ts := tex.get_size()
		for i in 64:
			var a := TAU * i / 64.0
			var d := Vector2(cos(a), sin(a))
			pts.append(c + d * r)
			var src := SRC_C + bob + d.rotated(-_tilt) * SRC_R / scale
			uvs.append(src / ts)
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
		# Eyelids for blinking, painted with her own skin tone.
		if blink > 0.01:
			for i in eyes.size():
				var e: Array = eyes[i]
				var ec := Vector2(e[0], e[1])
				var w: float = e[2] * 0.62
				var h: float = e[3] * 0.62
				var lid := PackedVector2Array()
				var lash := PackedVector2Array()
				for k in 17:
					var u := float(k) / 16.0
					var x := lerpf(-w, w, u)
					var top := -h * (1.0 - 0.55 * pow(2.0 * u - 1.0, 2.0))
					lid.append(_to_screen(ec + Vector2(x, top - 2.0), c, r, scale, bob))
				for k in 17:
					var u := 1.0 - float(k) / 16.0
					var x := lerpf(-w, w, u)
					var top := -h * (1.0 - 0.55 * pow(2.0 * u - 1.0, 2.0))
					var bottom := h * 0.75 * (1.0 - 0.6 * pow(2.0 * u - 1.0, 2.0))
					var p := _to_screen(ec + Vector2(x, lerpf(top, bottom, blink)), c, r, scale, bob)
					lid.append(p)
					lash.append(p)
				var col: Color = skin[i] if i < skin.size() else Color(0.6, 0.38, 0.28)
				draw_colored_polygon(lid, col)
				draw_polyline(lash, Color(0.12, 0.06, 0.04, 0.9 * blink), 2.2, true)
		if _dim > 0.01:
			draw_circle(c, r, Color(0.02, 0.04, 0.08, _dim))
		# Frame: double gold ring, a crescent above and a leaf diamond below.
		draw_arc(c, r + 1.5, 0, TAU, 96, UIKit.GOLD, 4.0, true)
		draw_arc(c, r + 6.5, 0, TAU, 96, Color(0.86, 0.76, 0.54, 0.6), 1.6, true)
		var mc := c + Vector2(r * 0.66, -r * 0.74)
		var moon := PackedVector2Array()
		for k in 25:
			var a := lerpf(PI * 0.35, PI * 1.65, k / 24.0)
			moon.append(mc + Vector2(cos(a), sin(a)) * 11.0)
		for k in 25:
			var a := lerpf(PI * 1.5, PI * 0.5, k / 24.0)
			moon.append(mc + Vector2(4.5, 0) + Vector2(cos(a) * 7.5, sin(a) * 10.0))
		draw_colored_polygon(moon, UIKit.GOLD)
		var dia := c + Vector2(0, r + 4)
		var dpts := PackedVector2Array([dia + Vector2(0, -12), dia + Vector2(12, 0), dia + Vector2(0, 12), dia + Vector2(-12, 0)])
		draw_colored_polygon(dpts, Color(0.05, 0.09, 0.07))
		draw_polyline(dpts + PackedVector2Array([dpts[0]]), UIKit.GOLD, 2.0, true)
		draw_line(dia + Vector2(0, -7), dia + Vector2(0, 7), UIKit.GOLD, 1.6, true)
		draw_arc(dia, 6.0, -PI * 0.5, PI * 0.5, 10, UIKit.GOLD, 1.6, true)

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
	(_portrait_frame as PortraitFrame).mood(_text.text)
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
	(_portrait_frame as PortraitFrame).talking = _text.visible_characters < total
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
