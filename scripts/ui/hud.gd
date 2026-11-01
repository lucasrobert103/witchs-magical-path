class_name HUD
extends Control
## Health/mana with the leaf emblem, sparks, objective, area titles, toasts and prompts.

var world: World
var _bars: Bars
var _sparks: Label
var _objective: Label
var _objective_panel: PanelContainer
var _area: VBoxContainer
var _area_title: Label
var _area_sub: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_icon: TextureRect
var _prompt: Label
var _toast_queue: Array = []
var _toast_busy := false
var _area_tween: Tween

class Bars extends Control:
	var hp := 1.0
	var mana := 1.0
	var show_mana := false
	var mana_color := Color(0.5, 0.86, 1.0)
	var essence_icon: Texture2D
	var _shown_hp := 1.0
	var _shown_mana := 1.0
	var emblem: Texture2D = load("res://assets/ui/emblem.png")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(430, 110)
	func _process(delta: float) -> void:
		_shown_hp = lerpf(_shown_hp, hp, clampf(delta * 6.0, 0.0, 1.0))
		_shown_mana = lerpf(_shown_mana, mana, clampf(delta * 8.0, 0.0, 1.0))
		queue_redraw()
	func _bar(pos: Vector2, w: float, h: float, value: float, ghost: float, col: Color, col2: Color) -> void:
		var frame := Rect2(pos - Vector2(3, 3), Vector2(w + 6, h + 6))
		draw_rect(frame, Color(0.03, 0.05, 0.04, 0.75))
		draw_rect(frame, UIKit.GOLD_DIM, false, 1.5)
		if ghost > value:
			draw_rect(Rect2(pos, Vector2(w * ghost, h)), Color(1, 1, 1, 0.25))
		var fw := w * clampf(value, 0.0, 1.0)
		if fw > 0.5:
			draw_rect(Rect2(pos, Vector2(fw, h)), col)
			draw_rect(Rect2(pos, Vector2(fw, h * 0.42)), col2)
	func _draw() -> void:
		draw_texture_rect(emblem, Rect2(0, 0, 104, 104), false)
		_bar(Vector2(100, 34), 300, 14, hp, _shown_hp, Color(0.86, 0.36, 0.3), Color(1.0, 0.62, 0.5))
		if show_mana:
			_bar(Vector2(100, 60), 240, 10, mana, _shown_mana, mana_color.darkened(0.15), mana_color.lightened(0.35))
			if essence_icon:
				draw_texture_rect(essence_icon, Rect2(352, 52, 26, 26), false, mana_color)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars = Bars.new()
	_bars.position = Vector2(26, 18)
	add_child(_bars)
	var sp := HBoxContainer.new()
	sp.position = Vector2(132, 96)
	sp.add_theme_constant_override("separation", 6)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sp)
	var si := TextureRect.new()
	si.texture = UIKit.icon_tex("spark")
	si.custom_minimum_size = Vector2(24, 24)
	si.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	si.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	si.modulate = UIKit.GOLD
	sp.add_child(si)
	_sparks = UIKit.label("0/5", UIKit.sans_bold, 20, UIKit.CREAM)
	sp.add_child(_sparks)
	# Objective banner.
	_objective_panel = PanelContainer.new()
	_objective_panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.04, 0.07, 0.05, 0.6), Color(0.86, 0.76, 0.54, 0.35), 22, 1))
	_objective_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_objective_panel.position.y = 22
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective_panel)
	_objective_panel.visible = false
	var ob := HBoxContainer.new()
	ob.add_theme_constant_override("separation", 10)
	_objective_panel.add_child(ob)
	var dia := UIKit.label("◆", UIKit.sans_bold, 16, UIKit.GOLD)
	ob.add_child(dia)
	_objective = UIKit.label("", UIKit.sans, 21, UIKit.CREAM)
	ob.add_child(_objective)
	# Area title.
	_area = VBoxContainer.new()
	_area.set_anchors_preset(Control.PRESET_CENTER)
	_area.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_area.grow_vertical = Control.GROW_DIRECTION_BOTH
	_area.position.y -= 150
	_area.alignment = BoxContainer.ALIGNMENT_CENTER
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.modulate.a = 0.0
	add_child(_area)
	_area_title = UIKit.label("", UIKit.title_font, 46, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_area.add_child(_area_title)
	_area.add_child(UIKit.ornament(320))
	_area_sub = UIKit.label("", UIKit.serif_italic, 26, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_area.add_child(_area_sub)
	# Toast.
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.04, 0.07, 0.05, 0.85), UIKit.GOLD_DIM, 26, 1))
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.position.y -= 210
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 12)
	_toast.add_child(th)
	_toast_icon = TextureRect.new()
	_toast_icon.custom_minimum_size = Vector2(30, 30)
	_toast_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_toast_icon.modulate = UIKit.GOLD
	th.add_child(_toast_icon)
	_toast_label = UIKit.label("", UIKit.sans_bold, 22, UIKit.CREAM)
	th.add_child(_toast_label)
	# Keyboard prompt (desktop).
	_prompt = UIKit.label("", UIKit.sans_bold, 22, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y += 120
	add_child(_prompt)

func bind(w: World) -> void:
	world = w
	w.objective_changed.connect(set_objective)
	w.area_entered.connect(show_area)
	w.toast_requested.connect(toast)
	w.prompt_changed.connect(_on_prompt)
	w.hud_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if world == null:
		return
	_sparks.text = "%d/%d" % [Game.spark_count(), Game.TOTAL_SPARKS]

func _process(_delta: float) -> void:
	if world == null:
		return
	var p := world.player
	_bars.hp = p.hp / p.max_hp
	_bars.mana = p.mana / p.max_mana
	_bars.show_mana = p.magic_unlocked
	_bars.mana_color = p.essence_color() if p.essence != "" else UIKit.MOON
	_bars.essence_icon = UIKit.icon_tex(p.essence) if p.essence != "" else null

func set_objective(text: String) -> void:
	_objective.text = text
	_objective_panel.visible = text != ""
	UIKit.pin(_objective_panel, 0.5, 0.0, 0.0, 22.0)
	if text != "":
		_objective_panel.modulate = Color(1.4, 1.3, 1.0, 1.0)
		create_tween().tween_property(_objective_panel, "modulate", Color.WHITE, 1.0)

func show_area(title: String, sub: String) -> void:
	_area_title.text = title
	_area_sub.text = sub
	_area_sub.visible = sub != ""
	UIKit.pin(_area, 0.5, 0.5, 0.0, -150.0)
	if _area_tween:
		_area_tween.kill()
	_area_tween = create_tween()
	_area_tween.tween_property(_area, "modulate:a", 1.0, 1.2)
	_area_tween.tween_interval(2.4)
	_area_tween.tween_property(_area, "modulate:a", 0.0, 1.4)

func toast(text: String, icon := "spark") -> void:
	_toast_queue.append([text, icon])
	if not _toast_busy:
		_next_toast()

func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	var t: Array = _toast_queue.pop_front()
	_toast_label.text = t[0]
	var tex := UIKit.icon_tex(t[1]) if ResourceLoader.exists("res://assets/ui/icon_%s.png" % t[1]) else UIKit.icon_tex("spark")
	_toast_icon.texture = tex
	UIKit.pin(_toast, 0.5, 1.0, 0.0, -230.0)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.35)
	tw.tween_interval(2.8)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_next_toast)

func _on_prompt(text: String, _icon: String) -> void:
	if Game.is_touch_device() or OS.get_environment("ASTERION_TOUCH") == "1":
		_prompt.text = ""
	else:
		_prompt.text = ("[F]  " + text) if text != "" else ""
	UIKit.pin(_prompt, 0.5, 0.5, 0.0, 130.0)
