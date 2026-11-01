class_name UIKit
## Fonts, colors and styled widgets shared by every screen.

const GOLD := Color("dcc28a")
const GOLD_DIM := Color(0.86, 0.76, 0.54, 0.45)
const CREAM := Color("f4ead2")
const INK := Color("0d1712")
const PANEL := Color(0.05, 0.09, 0.07, 0.82)
const MOON := Color(0.5, 0.86, 1.0)
const FLAME := Color(1.0, 0.66, 0.3)

static var title_font: Font = load("res://assets/fonts/Cinzel-SemiBold.woff")
static var title_regular: Font = load("res://assets/fonts/Cinzel-Regular.woff")
static var serif: Font = load("res://assets/fonts/CormorantGaramond-Medium.woff")
static var serif_italic: Font = load("res://assets/fonts/CormorantGaramond-MediumItalic.woff")
static var sans: Font = load("res://assets/fonts/Nunito-SemiBold.woff")
static var sans_bold: Font = load("res://assets/fonts/Nunito-ExtraBold.woff")

static func label(text: String, font: Font, size: int, color := CREAM, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func panel_style(bg := PANEL, border := GOLD_DIM, radius := 14, border_w := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	return s

static func button(text: String, primary := false, min_w := 320) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 62)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", title_font)
	b.add_theme_font_size_override("font_size", 24)
	var normal := panel_style(Color(0.86, 0.75, 0.5, 0.95) if primary else Color(0.04, 0.08, 0.06, 0.72), GOLD if primary else GOLD_DIM, 10, 2)
	var hover := panel_style(Color(0.95, 0.85, 0.6, 1.0) if primary else Color(0.1, 0.16, 0.12, 0.85), GOLD, 10, 2)
	var pressed := panel_style(Color(0.75, 0.64, 0.42, 1.0) if primary else Color(0.14, 0.2, 0.15, 0.9), GOLD, 10, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", panel_style(Color(0, 0, 0, 0), GOLD, 10, 2))
	var txt := INK if primary else CREAM
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, txt)
	b.pressed.connect(func(): Audio.sfx("click", -6.0))
	return b

static func slider(value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(300, 40)
	var grab := StyleBoxFlat.new()
	grab.bg_color = GOLD
	grab.set_corner_radius_all(4)
	grab.content_margin_top = 4
	grab.content_margin_bottom = 4
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.15)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", grab)
	s.add_theme_stylebox_override("grabber_area_highlight", grab)
	return s

static func ornament(width := 260.0) -> Control:
	var c := Ornament.new()
	c.custom_minimum_size = Vector2(width, 18)
	return c

class Ornament extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var c := size * 0.5
		draw_line(Vector2(0, c.y), Vector2(c.x - 16, c.y), UIKit.GOLD_DIM, 1.5, true)
		draw_line(Vector2(c.x + 16, c.y), Vector2(size.x, c.y), UIKit.GOLD_DIM, 1.5, true)
		var d := PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)])
		draw_colored_polygon(d, UIKit.GOLD)

static func icon_tex(name: String) -> Texture2D:
	return load("res://assets/ui/icon_%s.png" % name)
