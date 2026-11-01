class_name TouchControls
extends Control
## Multi-touch controls: floating joystick (left), camera drag (right) and action buttons.

signal action(name: String)

var move := Vector2.ZERO          # x right, y forward
var look_delta := Vector2.ZERO    # accumulated drag, consumed by main
var show_interact := false
var interact_text := ""
var interact_icon := "interact"
var show_essence := false
var show_magic := false
var essence := "moon"
var run_on := false
var highlight := {}   # button -> seconds of gentle pulsing when it first appears

var _ring: Texture2D = load("res://assets/ui/ring.png")
var _ring_ticks: Texture2D = load("res://assets/ui/ring_ticks.png")
var _icons := {}
var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_index := -1
var _look_last := Vector2.ZERO
var _pressed := {}       # button -> touch index
var _flash := {}

const STICK_R := 92.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n in ["magic", "jump", "interact", "pause", "moon", "flame", "read", "run"]:
		_icons[n] = UIKit.icon_tex(n)

func _buttons() -> Dictionary:
	var s := size
	var b := {
		"jump": [Vector2(s.x - 300, s.y - 92), 50.0],
		"run": [Vector2(s.x - 420, s.y - 70), 42.0],
		"pause": [Vector2(s.x - 58, 58), 34.0],
	}
	if show_magic:
		b["magic"] = [Vector2(s.x - 148, s.y - 150), 72.0]
	if show_interact:
		b["interact"] = [Vector2(s.x - 150, s.y - 318), 52.0]
	if show_essence:
		b["essence"] = [Vector2(s.x - 298, s.y - 236), 42.0]
	return b

func _hit_button(p: Vector2) -> String:
	var b := _buttons()
	for k in b.keys():
		if p.distance_to(b[k][0]) <= b[k][1] * 1.18:
			return k
	return ""

func reset() -> void:
	_stick_index = -1
	_look_index = -1
	_pressed.clear()
	move = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var p := t.position
		if t.pressed:
			var btn := _hit_button(p)
			if btn != "":
				_pressed[btn] = t.index
				_flash[btn] = 1.0
				action.emit(btn)
				get_viewport().set_input_as_handled()
			elif p.x < size.x * 0.42 and p.y > size.y * 0.3 and _stick_index == -1:
				_stick_index = t.index
				_stick_origin = p
				_stick_pos = p
				get_viewport().set_input_as_handled()
			elif p.x >= size.x * 0.42 and _look_index == -1:
				_look_index = t.index
				_look_last = p
		else:
			if t.index == _stick_index:
				_stick_index = -1
				move = Vector2.ZERO
			if t.index == _look_index:
				_look_index = -1
			for k in _pressed.keys():
				if _pressed[k] == t.index:
					_pressed.erase(k)
					if k == "jump":
						action.emit("jump_release")
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_index:
			_stick_pos = d.position
			var v := _stick_pos - _stick_origin
			if v.length() > STICK_R:
				# Let the base follow the finger a little for comfort.
				_stick_origin = _stick_pos - v.normalized() * STICK_R
				v = v.normalized() * STICK_R
			move = Vector2(v.x, -v.y) / STICK_R
			if move.length() < 0.12:
				move = Vector2.ZERO
			get_viewport().set_input_as_handled()
		elif d.index == _look_index:
			look_delta += d.position - _look_last
			_look_last = d.position
		queue_redraw()

func _process(delta: float) -> void:
	for k in _flash.keys():
		_flash[k] = maxf(0.0, _flash[k] - delta * 4.0)
	for k in highlight.keys():
		highlight[k] = maxf(0.0, highlight[k] - delta)
	queue_redraw()

func _draw() -> void:
	# Joystick.
	var base := _stick_origin if _stick_index != -1 else Vector2(175, size.y - 165)
	var knob := _stick_pos if _stick_index != -1 else base
	var alpha := 0.95 if _stick_index != -1 else 0.55
	draw_texture_rect(_ring_ticks, Rect2(base - Vector2.ONE * STICK_R * 1.15, Vector2.ONE * STICK_R * 2.3), false, Color(1, 1, 1, alpha))
	draw_circle(knob, 38.0, Color(0.86, 0.76, 0.54, 0.35 * alpha + 0.1))
	draw_arc(knob, 38.0, 0, TAU, 40, Color(0.95, 0.88, 0.7, alpha), 3.0, true)
	# Buttons.
	var b := _buttons()
	for k in b.keys():
		var c: Vector2 = b[k][0]
		var r: float = b[k][1]
		var pressed := _pressed.has(k)
		var tint := Color(1, 1, 1, 1.0 if pressed else 0.85)
		var fill := Color(0.05, 0.1, 0.07, 0.55)
		if k == "magic":
			fill = Color(0.86, 0.72, 0.42, 0.42 + _flash.get(k, 0.0) * 0.4)
		if k == "run" and run_on:
			fill = Color(0.95, 0.8, 0.45, 0.75)
			var ph := fposmod(Time.get_ticks_msec() * 0.0015, 1.0)
			draw_arc(c, r * (1.05 + ph * 0.3), 0, TAU, 40, Color(1.0, 0.9, 0.6, (1.0 - ph) * 0.6), 2.0, true)
		if pressed:
			fill = fill.lightened(0.25)
		if highlight.get(k, 0.0) > 0.0:
			var ph := fposmod(Time.get_ticks_msec() * 0.0012, 1.0)
			draw_arc(c, r * (1.1 + ph * 0.6), 0, TAU, 48, Color(1.0, 0.9, 0.6, (1.0 - ph) * 0.8), 3.0, true)
		draw_circle(c, r, fill)
		draw_texture_rect(_ring, Rect2(c - Vector2.ONE * r * 1.12, Vector2.ONE * r * 2.24), false, tint)
		var icon_name: String = k
		var icol := UIKit.CREAM
		if k == "run" and run_on:
			icol = UIKit.INK
		if k == "essence":
			icon_name = essence
			icol = UIKit.MOON if essence == "moon" else UIKit.FLAME
		elif k == "interact":
			icon_name = interact_icon if _icons.has(interact_icon) else "interact"
		var tex: Texture2D = _icons.get(icon_name)
		if tex:
			var isz := r * 1.0
			draw_texture_rect(tex, Rect2(c - Vector2.ONE * isz * 0.5, Vector2.ONE * isz), false, icol)
		if k == "interact" and interact_text != "":
			var f := UIKit.sans_bold
			var w := f.get_string_size(interact_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20).x
			var lp := c + Vector2(-w * 0.5, r + 30)
			draw_string_outline(f, lp, interact_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, 0.7))
			draw_string(f, lp, interact_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIKit.CREAM)
