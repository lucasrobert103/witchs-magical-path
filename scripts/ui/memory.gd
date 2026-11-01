class_name Memory
extends Control
## "A lembrança — Uma saudade sem rosto". Crossing the arch, Asterion glimpses a
## brief, incomplete fragment of the first story. Nothing is explained: two
## presences that dissolve when observed, a light between them, other lights
## born from it, flashes of deep water and a figure among stars. Emotion first.

signal done

const BEATS := [
	{"d": 4.0, "s": "black", "text": "Asterion atravessou o arco."},
	{"d": 5.0, "s": "black", "text": "O som da floresta desapareceu antes que seu pé encontrasse o outro lado."},
	{"d": 4.0, "s": "dark", "text": "Por um instante, houve apenas escuridão."},
	{"d": 6.0, "s": "presences", "text": "Então, duas presenças surgiram na distância."},
	{"d": 6.5, "s": "dissolve", "text": "Suas formas se desfaziam sempre que ela tentava observá-las."},
	{"d": 7.0, "s": "gesture", "text": "Ainda assim, havia algo naquele encontro que prendia sua atenção: a delicadeza de um gesto, uma aproximação, a luz que crescia entre elas."},
	{"d": 7.0, "s": "lights", "text": "Dessa luz, outras começaram a surgir. Pequenas, imensas, próximas, distantes."},
	{"d": 6.0, "s": "lights", "text": "Algumas permaneciam juntas por um instante; outras se afastavam até desaparecer."},
	{"d": 1.4, "s": "flash", "text": ""},
	{"d": 4.0, "s": "water", "text": "Algo semelhante ao movimento de águas profundas."},
	{"d": 4.5, "s": "stars", "text": "Uma silhueta envolvida por estrelas."},
	{"d": 4.5, "s": "dissolve", "text": "Depois, novamente as duas presenças."},
	{"d": 5.5, "s": "dissolve", "text": "Asterion levou a mão ao peito. Sentia saudade."},
	{"d": 5.5, "s": "dissolve", "text": "A sensação era tão intensa que seus olhos se encheram de lágrimas, embora não conseguisse reconhecer ninguém."},
	{"d": 3.8, "s": "dissolve", "text": "— Por que…?", "voice": true},
	{"d": 6.0, "s": "dissolve", "text": "Ela procurou algum detalhe familiar. Um rosto. Um som. Qualquer coisa que pudesse segurar antes que tudo desaparecesse."},
	{"d": 4.5, "s": "leaving", "text": "Uma das luzes se afastou."},
	{"d": 3.2, "s": "leaving", "text": "— Espera.", "voice": true},
	{"d": 1.8, "s": "shatter", "text": "A visão se partiu."},
	{"d": 3.6, "s": "black", "text": "Seus joelhos encontraram pedra úmida."},
]

var _i := 0
var _t := 0.0
var _bt := 0.0
var _text: Label
var _skip: Button
var _tex := {}
var _alpha := {}
var _motes: Array = []
var _finished := true
var _flash := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for n in ["goddess", "god", "goddess_reach", "god_reach"]:
		_tex[n] = load("res://assets/sprites/prologue/%s.png" % n)
	_tex["dot"] = load("res://assets/sprites/fx/soft_dot.png")
	_tex["spark"] = load("res://assets/sprites/fx/sparkle.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 70:
		_motes.append({"a": rng.randf() * TAU, "sp": rng.randf_range(0.02, 0.09), "size": rng.randf_range(4.0, 40.0), "pair": i % 5 == 0, "fade": rng.randf_range(0.3, 1.0), "ph": rng.randf() * TAU})
	_text = UIKit.label("", UIKit.serif_italic, 36, Color("efe4cb"), HORIZONTAL_ALIGNMENT_CENTER)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(1000, 200)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_text)
	UIKit.pin(_text, 0.5, 1.0, 0.0, -64.0)
	_skip = UIKit.button("Pular  ›", false, 150)
	_skip.custom_minimum_size = Vector2(150, 48)
	_skip.add_theme_font_size_override("font_size", 18)
	_skip.pressed.connect(finish)
	add_child(_skip)
	UIKit.pin(_skip, 1.0, 0.0, -28.0, 26.0)

func start() -> void:
	_finished = false
	_i = 0
	_bt = 0.0
	_t = 0.0
	_alpha.clear()
	_set_beat(0)

func _set_beat(i: int) -> void:
	_i = i
	_bt = 0.0
	var b: Dictionary = BEATS[i]
	_text.text = b["text"]
	_text.visible_ratio = 0.0
	var voice: bool = b.get("voice", false)
	_text.add_theme_font_override("font", UIKit.serif_italic if not voice else UIKit.serif)
	_text.add_theme_font_size_override("font_size", 44 if voice else 34)
	_text.add_theme_color_override("font_color", UIKit.GOLD if voice else Color("efe4cb"))
	if b["s"] == "flash" or b["s"] == "shatter":
		_flash = 1.0
		Audio.sfx("rune", -4.0)
	if voice:
		Audio.sfx("open", -14.0)

func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if tap:
		if _text.visible_ratio < 1.0:
			_text.visible_ratio = 1.0
		else:
			_next()
		accept_event()

func _next() -> void:
	if _i < BEATS.size() - 1:
		_set_beat(_i + 1)
	else:
		finish()

func finish() -> void:
	if _finished:
		return
	_finished = true
	done.emit()

func _process(delta: float) -> void:
	if not visible or _finished:
		return
	_t += delta
	_bt += delta
	_flash = maxf(0.0, _flash - delta * 0.9)
	var b: Dictionary = BEATS[_i]
	var txt: String = b["text"]
	if txt != "":
		_text.visible_ratio = maxf(_text.visible_ratio, clampf((_bt - 0.4) * 28.0 / maxf(1.0, txt.length()), 0.0, 1.0))
	if _bt > float(b["d"]) + (txt.length() / 30.0 if txt != "" else 0.0):
		_next()
	var want: Array = {
		"black": [], "dark": ["dust"], "presences": ["dust", "pres_far"], "dissolve": ["dust", "pres"],
		"gesture": ["dust", "pres", "between"], "lights": ["dust", "pres", "between", "lights"], "flash": ["lights"],
		"water": ["water"], "stars": ["starfig"], "leaving": ["dust", "pres", "leaving"], "shatter": [],
	}[b["s"]]
	for k in ["dust", "pres_far", "pres", "between", "lights", "water", "starfig", "leaving"]:
		var target := 1.0 if want.has(k) else 0.0
		_alpha[k] = move_toward(_alpha.get(k, 0.0), target, delta * (0.45 if target > 0 else 0.9))
	queue_redraw()

func _a(k: String) -> float:
	return _alpha.get(k, 0.0)

func _glow(p: Vector2, r: float, col: Color) -> void:
	draw_texture_rect(_tex["dot"], Rect2(p - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, col)

## A presence that never holds still: soft echoes drift away from its shape, so it
## seems to come apart whenever one looks at it.
func _presence(tex_name: String, center: Vector2, h: float, alpha: float, flip: bool, seed: float) -> void:
	var t: Texture2D = _tex[tex_name]
	var w := h * 0.5
	var breathe := 0.5 + 0.5 * sin(_t * 0.9 + seed)
	for k in 4:
		var off := Vector2(sin(_t * (0.7 + k * 0.23) + seed + k) * (6.0 + k * 9.0), cos(_t * (0.5 + k * 0.17) + k * 2.0) * (3.0 + k * 4.0))
		var grow := 1.0 + k * 0.035 * breathe
		var a := alpha * (0.5 if k == 0 else 0.16 / k) * (0.75 + 0.25 * sin(_t * 1.3 + k + seed))
		var sz := Vector2(w, h) * grow
		var rect := Rect2(center + off - sz * 0.5, sz)
		if flip:
			rect = Rect2(rect.position + Vector2(sz.x, 0), Vector2(-sz.x, sz.y))
		draw_texture_rect(t, rect, false, Color(0.9, 0.93, 1.0, a))
	_glow(center + Vector2(0, -h * 0.15), h * 0.45, Color(0.85, 0.88, 1.0, 0.16 * alpha))

func _draw() -> void:
	var s := size
	var c := s * 0.5 + Vector2(0, -s.y * 0.08)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.008, 0.01, 0.02))
	var da := _a("dust")
	if da > 0.0:
		for m in _motes:
			var p := Vector2(fposmod(cos(m["a"]) * 0.4 + 0.5 + _t * m["sp"] * 0.2, 1.0), fposmod(sin(m["a"]) * 0.4 + 0.5 + sin(_t * 0.2 + m["ph"]) * 0.02, 1.0)) * s
			_glow(p, 5.0, Color(0.7, 0.75, 0.9, 0.18 * da))
	var fh := s.y * 0.62
	var pf := _a("pres_far")
	if pf > 0.0:
		_presence("goddess", c + Vector2(-s.x * 0.22, 0), fh * 0.55, pf * 0.7, false, 0.0)
		_presence("god", c + Vector2(s.x * 0.22, 0), fh * 0.55, pf * 0.7, true, 2.0)
	var pa := _a("pres")
	var leave := _a("leaving")
	if pa > 0.0:
		var gap := lerpf(s.x * 0.16, s.x * 0.11, _a("between"))
		_presence("goddess_reach" if _a("between") > 0.5 else "goddess", c + Vector2(-gap, 0), fh, pa, false, 0.0)
		var away := leave * s.x * 0.35
		_presence("god_reach" if _a("between") > 0.5 else "god", c + Vector2(gap + away, -leave * 40.0), fh * (1.0 - leave * 0.4), pa * (1.0 - leave * 0.85), true, 2.0)
	var ba := _a("between")
	if ba > 0.0:
		var grow := 0.6 + 0.4 * sin(_t * 1.3)
		_glow(c + Vector2(0, -fh * 0.12), 70.0 + 90.0 * ba * grow, Color(1.0, 0.95, 0.85, 0.75 * ba))
		_glow(c + Vector2(0, -fh * 0.12), 20.0 + 14.0 * ba, Color(1, 1, 1, ba))
	var la := _a("lights")
	if la > 0.0:
		var origin := c + Vector2(0, -fh * 0.12)
		for m in _motes:
			var life := fposmod(_t * m["sp"] * 2.0 + m["ph"], 1.0)
			var r := life * s.x * 0.55
			var ang: float = m["a"] + (sin(_t * 0.3 + m["ph"]) * 0.2 if m["pair"] else 0.0)
			var p := origin + Vector2(cos(ang), sin(ang) * 0.6) * r
			var fade := (1.0 - life) if not m["pair"] else (1.0 - life * 0.5)
			var col := Color(1.0, 0.95, 0.85) if int(m["size"]) % 3 else Color(0.75, 0.88, 1.0)
			_glow(p, m["size"] * (0.4 + life), Color(col, 0.55 * la * fade * m["fade"]))
			if m["pair"]:
				_glow(p + Vector2(14, -6), m["size"] * 0.5, Color(1.0, 0.85, 0.6, 0.5 * la * fade))
	var wa := _a("water")
	if wa > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.05, 0.1, wa * 0.9))
		for row in 9:
			var prev := Vector2.ZERO
			for i in 48:
				var x := i / 47.0 * s.x
				var y := s.y * (0.2 + row * 0.08) + sin(x * 0.006 + _t * (0.5 + row * 0.07) + row) * 26.0 + sin(x * 0.017 - _t * 0.8) * 8.0
				var p := Vector2(x, y)
				if i > 0:
					draw_line(prev, p, Color(0.35, 0.6, 0.85, wa * 0.25 * (1.0 - row / 10.0)), 3.0, true)
				prev = p
	var sa := _a("starfig")
	if sa > 0.0:
		for i in 40:
			var a := i * 0.61 + _t * 0.15 * (1.0 if i % 2 else -1.0)
			var rr := 90.0 + (i % 7) * 26.0
			var p := c + Vector2(cos(a) * rr, sin(a) * rr * 1.4)
			draw_texture_rect(_tex["spark"], Rect2(p - Vector2.ONE * 9, Vector2.ONE * 18), false, Color(1, 0.97, 0.9, sa * (0.5 + 0.5 * sin(_t * 3.0 + i))))
		var t: Texture2D = _tex["goddess"]
		var h := fh * 0.8
		draw_texture_rect(t, Rect2(c - Vector2(h * 0.25, h * 0.5), Vector2(h * 0.5, h)), false, Color(0.02, 0.03, 0.06, sa * 0.95))
		_glow(c, h * 0.55, Color(0.6, 0.7, 1.0, 0.12 * sa))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 0.98, 0.94, _flash * 0.85))
		if BEATS[_i]["s"] == "shatter":
			for i in 14:
				var a := i * TAU / 14.0 + 0.3
				draw_line(c, c + Vector2(cos(a), sin(a)) * s.x, Color(0.1, 0.1, 0.15, _flash), 3.0, true)
	# Darken behind the text.
	var gh := s.y * 0.4
	for i in 10:
		draw_rect(Rect2(0, s.y - gh * (i + 1) / 10.0, s.x, gh / 10.0 + 1), Color(0, 0, 0, 0.06 * (10 - i) / 10.0 * 3.0))
