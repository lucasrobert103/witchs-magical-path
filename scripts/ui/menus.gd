class_name Menus
## Title, pause, settings and chapter-end screens.

static func _center_column(parent: Control, sep := 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(v)
	return v

class TitleScreen extends Control:
	signal new_game
	signal continue_game
	signal open_settings
	var _continue: Button
	var _col: VBoxContainer
	var _credits: Label
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Left-side gradient so the title reads over the forest.
		var shade := TextureRect.new()
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.04, 0.03, 0.88))
		g.set_color(1, Color(0.02, 0.04, 0.03, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(1, 0)
		shade.texture = gt
		shade.stretch_mode = TextureRect.STRETCH_SCALE
		shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shade.anchor_bottom = 1.0
		shade.anchor_right = 0.62
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		_col = VBoxContainer.new()
		_col.add_theme_constant_override("separation", 10)
		_col.position = Vector2(96, 92)
		add_child(_col)
		_col.add_child(UIKit.label("UMA JORNADA ENTRE MAGIA E MEMÓRIA", UIKit.sans_bold, 16, UIKit.GOLD))
		var t := UIKit.label("ASTERION", UIKit.title_font, 96, UIKit.CREAM)
		_col.add_child(t)
		_col.add_child(UIKit.ornament(420))
		_col.add_child(UIKit.label("O Caminho da Bruxa", UIKit.serif_italic, 40, UIKit.GOLD))
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 30)
		_col.add_child(spacer)
		_continue = UIKit.button("Continuar", true, 360)
		_continue.pressed.connect(func(): continue_game.emit())
		_col.add_child(_continue)
		var ng := UIKit.button("Nova jornada", false, 360)
		ng.pressed.connect(func(): new_game.emit())
		_col.add_child(ng)
		var st := UIKit.button("Configurações", false, 360)
		st.pressed.connect(func(): open_settings.emit())
		_col.add_child(st)
		_credits = UIKit.label("Capítulo I — O Despertar  ·  Capítulo II — Um lugar para ficar  ·  v1.2", UIKit.sans, 15, Color(0.85, 0.85, 0.8, 0.6))
		add_child(_credits)
		UIKit.pin(_credits, 0.0, 1.0, 96.0, -36.0)
		refresh()
	func refresh() -> void:
		_continue.visible = Game.has_save()
		_continue.text = "Continuar" if Game.has_save() else ""
	func focus_first() -> void:
		if _continue.visible:
			_continue.grab_focus()
		else:
			_col.get_child(5).grab_focus()

class SettingsPanel extends Control:
	signal closed
	var _quality: Button
	var _touch: Button
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.55)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.04, 0.07, 0.05, 0.95), UIKit.GOLD_DIM, 18, 2))
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		panel.add_child(v)
		v.add_child(UIKit.label("Configurações", UIKit.title_font, 34, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UIKit.ornament(420))
		_row(v, "Música", "music")
		_row(v, "Efeitos sonoros", "sfx")
		_row(v, "Sensibilidade da câmera", "sensitivity", 0.3, 2.0)
		var q := HBoxContainer.new()
		q.add_theme_constant_override("separation", 20)
		v.add_child(q)
		var ql := UIKit.label("Gráficos", UIKit.sans_bold, 22, UIKit.CREAM)
		ql.custom_minimum_size = Vector2(270, 0)
		q.add_child(ql)
		_quality = UIKit.button("", false, 300)
		_quality.add_theme_font_size_override("font_size", 20)
		_quality.pressed.connect(_toggle_quality)
		q.add_child(_quality)
		var hint := UIKit.label("A qualidade “Leve” vale ao iniciar uma jornada.", UIKit.sans, 15, Color(0.85, 0.85, 0.8, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(hint)
		var back := UIKit.button("Voltar", true, 300)
		back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		back.pressed.connect(func(): closed.emit())
		v.add_child(back)
		_update_labels()
		UIKit.pin(panel, 0.5, 0.5, 0.0, 0.0)
	func _row(v: VBoxContainer, text: String, key: String, lo := 0.0, hi := 1.0) -> void:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 20)
		v.add_child(h)
		var l := UIKit.label(text, UIKit.sans_bold, 22, UIKit.CREAM)
		l.custom_minimum_size = Vector2(270, 0)
		h.add_child(l)
		var s := UIKit.slider(float(Game.settings[key]))
		s.min_value = lo
		s.max_value = hi
		s.value = float(Game.settings[key])
		s.value_changed.connect(func(val): Game.set_setting(key, val))
		h.add_child(s)
	func _toggle_quality() -> void:
		Game.set_setting("quality", 0 if int(Game.settings["quality"]) == 1 else 1)
		_update_labels()
	func _update_labels() -> void:
		_quality.text = "Bonito" if int(Game.settings["quality"]) == 1 else "Leve"

class PauseMenu extends Control:
	signal resume
	signal settings
	signal to_title
	signal map
	var _first: Button
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0.01, 0.02, 0.02, 0.6)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		v.set_anchors_preset(Control.PRESET_CENTER)
		v.grow_horizontal = Control.GROW_DIRECTION_BOTH
		v.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(v)
		v.add_child(UIKit.label("Pausa", UIKit.title_font, 52, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		var o := UIKit.ornament(360)
		v.add_child(o)
		_first = UIKit.button("Continuar", true, 360)
		_first.pressed.connect(func(): resume.emit())
		v.add_child(_first)
		var m := UIKit.button("Mapa", false, 360)
		m.pressed.connect(func(): map.emit())
		v.add_child(m)
		var s := UIKit.button("Configurações", false, 360)
		s.pressed.connect(func(): settings.emit())
		v.add_child(s)
		var t := UIKit.button("Salvar e voltar ao título", false, 360)
		t.pressed.connect(func(): to_title.emit())
		v.add_child(t)
		var help := UIKit.label("Joystick: andar (quanto mais longe, mais rápido)  ·  » Correr: liga/desliga  ·  Arraste à direita: câmera\n✦ Magia  ·  Pular  ·  Mão: interagir  ·  Lua/Chama: trocar essência", UIKit.sans, 16, Color(0.9, 0.88, 0.8, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(help)
		UIKit.pin(v, 0.5, 0.5, 0.0, 0.0)
	func focus_first() -> void:
		_first.grab_focus()

class MapView extends Control:
	signal closed
	var _map: TextureRect
	var _marker := Vector2(0.27, 0.55)   # normalized position on the map image
	var _t := 0.0
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0.01, 0.02, 0.02, 0.88)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
		_map = TextureRect.new()
		_map.texture = load("res://assets/ui/map_continent.jpg")
		_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_map.offset_top = 20
		_map.offset_bottom = -20
		_map.offset_left = 20
		_map.offset_right = -20
		_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_map)
		var mk := MapMarker.new()
		mk.view = self
		add_child(mk)
		var back := UIKit.button("Voltar", true, 180)
		back.custom_minimum_size = Vector2(180, 52)
		back.pressed.connect(func(): closed.emit())
		add_child(back)
		UIKit.pin(back, 1.0, 1.0, -36.0, -32.0)
	func set_marker(p: Vector2) -> void:
		_marker = p
	func _process(delta: float) -> void:
		if visible:
			_t += delta
			queue_redraw()
	func _image_rect() -> Rect2:
		var area := Rect2(_map.position, _map.size)
		var ts := _map.texture.get_size()
		var k := minf(area.size.x / ts.x, area.size.y / ts.y)
		var sz := ts * k
		return Rect2(area.position + (area.size - sz) * 0.5, sz)

class MapMarker extends Control:
	var view: MapView
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if view == null:
			return
		var r := view._image_rect()
		var p := r.position + r.size * view._marker
		var pulse := 0.5 + 0.5 * sin(view._t * 3.0)
		draw_circle(p, 16.0 + pulse * 10.0, Color(1.0, 0.85, 0.45, 0.25 * (1.0 - pulse)))
		draw_circle(p, 9.0, Color(1.0, 0.92, 0.6))
		draw_arc(p, 12.0, 0, TAU, 32, Color(0.2, 0.12, 0.05), 3.0, true)
		var f := UIKit.sans_bold
		var txt := "Asterion está aqui"
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var lp := p + Vector2(-w * 0.5, -26)
		draw_string_outline(f, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 7, Color(0.15, 0.08, 0.03, 0.9))
		draw_string(f, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.95, 0.8))

class EndingScreen extends Control:
	signal to_title
	var _stats: Label
	var _box: VBoxContainer
	var _header: Label
	var _title: Label
	var _quote: Label
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var bg := ColorRect.new()
		bg.color = Color(0.01, 0.015, 0.02, 0.92)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		_box = VBoxContainer.new()
		_box.add_theme_constant_override("separation", 16)
		_box.set_anchors_preset(Control.PRESET_CENTER)
		_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_box.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(_box)
		_header = UIKit.label("FIM DO CAPÍTULO II", UIKit.sans_bold, 18, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_box.add_child(_header)
		_title = UIKit.label("Um lugar para ficar", UIKit.title_font, 60, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		_box.add_child(_title)
		var o := UIKit.ornament(420)
		o.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_box.add_child(o)
		_quote = UIKit.label("— Amanhã eu continuo.", UIKit.serif_italic, 32, Color("efe4cb"), HORIZONTAL_ALIGNMENT_CENTER)
		_box.add_child(_quote)
		_stats = UIKit.label("", UIKit.sans_bold, 22, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		_box.add_child(_stats)
		_box.add_child(UIKit.label("O caminho de Asterion continua...", UIKit.serif_italic, 26, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var b := UIKit.button("Voltar ao título", true, 340)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): to_title.emit())
		_box.add_child(b)
	func show_stats(stats: Dictionary) -> void:
		_stats.text = "Centelhas encontradas: %d/%d     ·     Tempo de jornada: %s" % [int(stats.get("sparks", 0)), Game.TOTAL_SPARKS, Game.format_time(float(stats.get("time", 0.0)))]
		UIKit.pin(_box, 0.5, 0.5, 0.0, 0.0)
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 2.0)
