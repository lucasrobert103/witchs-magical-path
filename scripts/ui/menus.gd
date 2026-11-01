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
		set_anchors_preset(Control.PRESET_FULL_RECT)
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
		_credits = UIKit.label("Capítulo I — O Despertar  ·  v1.0", UIKit.sans, 15, Color(0.85, 0.85, 0.8, 0.6))
		_credits.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_credits.position = Vector2(96, -48)
		add_child(_credits)
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
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
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
		panel.reset_size()
		panel.position = -panel.size * 0.5
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
	var _first: Button
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0.01, 0.02, 0.02, 0.6)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
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
		var s := UIKit.button("Configurações", false, 360)
		s.pressed.connect(func(): settings.emit())
		v.add_child(s)
		var t := UIKit.button("Salvar e voltar ao título", false, 360)
		t.pressed.connect(func(): to_title.emit())
		v.add_child(t)
		var help := UIKit.label("Joystick: andar (empurre até o fim para correr)  ·  Arraste à direita: câmera\n✦ Magia  ·  Pular  ·  Mão: interagir  ·  Lua/Chama: trocar essência", UIKit.sans, 16, Color(0.9, 0.88, 0.8, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(help)
		v.reset_size()
		v.position = -v.size * 0.5
	func focus_first() -> void:
		_first.grab_focus()

class EndingScreen extends Control:
	signal to_title
	var _stats: Label
	var _box: VBoxContainer
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var bg := ColorRect.new()
		bg.color = Color(0.01, 0.015, 0.02, 0.92)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		_box = VBoxContainer.new()
		_box.add_theme_constant_override("separation", 16)
		_box.set_anchors_preset(Control.PRESET_CENTER)
		_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_box.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(_box)
		_box.add_child(UIKit.label("FIM DO CAPÍTULO I", UIKit.sans_bold, 18, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		_box.add_child(UIKit.label("O Despertar", UIKit.title_font, 64, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		var o := UIKit.ornament(420)
		o.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_box.add_child(o)
		var quote := UIKit.label("“Mas poucos se lembrariam de onde a magia realmente veio.”", UIKit.serif_italic, 30, Color("efe4cb"), HORIZONTAL_ALIGNMENT_CENTER)
		_box.add_child(quote)
		_stats = UIKit.label("", UIKit.sans_bold, 22, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		_box.add_child(_stats)
		_box.add_child(UIKit.label("O caminho de Asterion continua...", UIKit.serif_italic, 26, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var b := UIKit.button("Voltar ao título", true, 340)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): to_title.emit())
		_box.add_child(b)
	func show_stats(stats: Dictionary) -> void:
		_stats.text = "Centelhas encontradas: %d/%d     ·     Tempo de jornada: %s" % [int(stats.get("sparks", 0)), Game.TOTAL_SPARKS, Game.format_time(float(stats.get("time", 0.0)))]
		_box.reset_size()
		_box.position = -_box.size * 0.5
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 2.0)
