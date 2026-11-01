class_name StudioSplash
extends Control
## Abertura "Desenvolvido por RetroNexa" (a mesma de GuardiPatas): o Pingo entra rolando
## enroladinho, pula de letra em letra (cada uma amassa no pulo), cai no buraco do "o" e
## vira a letra — desenrola, pisca e sorri. Fundo índigo, "RetroNexa" em Inter Bold
## branco, site embaixo. Toque para pular.

signal done

const BRAND := "RetroNexa"
const SITE := "retronexa.com.br"
const SLOT := 4                     # o "o" de Retro: é ali que o Pingo cai
const INDIGO := Color8(78, 69, 220)
const INDIGO_LIGHT := Color8(98, 90, 236)
const SOFT := Color8(225, 223, 255)
const FONT_BOLD := preload("res://assets/fonts/Inter-Bold.otf")
const FONT_MEDIUM := preload("res://assets/fonts/Inter-Medium.otf")

## Tempo da animação (segundos)
const T_ENTER := 0.9                # o Pingo aparece
const HOP := 0.42                   # duração de cada pulo entre letras
const HOP_LETTERS := [0, 1, 2, 3]   # R, e, t, r — depois cai no "o"
const T_LAND := T_ENTER + HOP * 5.0
const SETTLE := [[0.28, 26.0], [0.2, 10.0]]
const T_UNCURL := T_LAND + 0.48 + 0.15
const DURATION := T_UNCURL + 2.3

var _t := 0.0
var _done := true
var _pingo: Pingo
var _squash: Array[float] = []      # amassado de cada letra (0..1)
var _ball_squash := 0.0
var _hops_done := 0
var _uncurled := false
var _layout := {}


## O Pingo de GuardiPatas (desenho vetorial com contorno ameixa, como no jogo original).
class Pingo extends Node2D:
	const OUTLINE := Color("3a2b3c")
	const WHITE := Color("fffaf2")
	const BLUSH := Color(1.0, 0.56, 0.68, 0.75)
	const MAIN := Color("6d5a8c")
	const LIGHT := Color("f6dcb8")
	const DARK := Color("4e3f66")
	var mood := "scared"             # scared (enroladinho) | idle | happy
	var look := Vector2.RIGHT
	var _t := 0.0
	var _blink := 0.0
	var _next_blink := 2.5
	var _mood_t := 0.0
	var _last_mood := ""

	func _process(delta: float) -> void:
		_t += delta
		if mood != _last_mood:
			_last_mood = mood
			_mood_t = 0.0
		_mood_t += delta
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink = 0.14
			_next_blink = randf_range(2.2, 4.5)
		_blink = maxf(_blink - delta, 0.0)
		queue_redraw()

	static func _ellipse(center: Vector2, radii: Vector2, rot := 0.0, segments := 28) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in segments:
			var a := TAU * float(i) / float(segments)
			pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(rot))
		return pts

	func _shape(pts: PackedVector2Array, fill: Color, width := 4.0) -> void:
		draw_colored_polygon(pts, fill)
		if width > 0.0:
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, OUTLINE, width, true)

	func _oval(c: Vector2, r: Vector2, fill: Color, width := 4.0, rot := 0.0) -> void:
		_shape(_ellipse(c, r, rot), fill, width)

	func _disc(c: Vector2, r: float, fill: Color, width := 4.0) -> void:
		if width > 0.0:
			draw_circle(c, r + width * 0.5, OUTLINE, true, -1.0, true)
		draw_circle(c, maxf(r - width * 0.5, 0.5), fill, true, -1.0, true)

	func _eye(c: Vector2, r: float) -> void:
		var lk := look.limit_length(1.0)
		if _blink > 0.0 and mood != "happy":
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), OUTLINE, 3.0, true)
			return
		if mood == "happy":
			draw_arc(c + Vector2(0, r * 0.5), r * 0.9, PI * 1.12, PI * 1.88, 12, OUTLINE, 3.2, true)
			return
		var white_r := r * (1.3 if mood == "scared" else 1.0)
		_disc(c, white_r, WHITE, 2.5)
		var pupil_r := r * (0.38 if mood == "scared" else 0.58)
		var pc := c + lk * (white_r - pupil_r) * 0.55
		draw_circle(pc, pupil_r, OUTLINE, true, -1.0, true)
		draw_circle(pc + Vector2(-pupil_r * 0.35, -pupil_r * 0.4), pupil_r * 0.38, WHITE, true, -1.0, true)

	func _mouth(c: Vector2, w: float) -> void:
		if mood == "happy":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI * float(i) / 12.0
				pts.append(c + Vector2(cos(a) * w * 0.6, sin(a) * w * 0.7))
			_shape(pts, Color("7a2e3a"), 2.5)
			_oval(c + Vector2(0, w * 0.42), Vector2(w * 0.3, w * 0.18), Color("ff7f9a"), 0.0)
		else:
			draw_arc(c + Vector2(0, -w * 0.35), w * 0.5, 0.35, PI - 0.35, 12, OUTLINE, 2.8, true)

	func _draw() -> void:
		var off := Vector2.ZERO
		var sc := Vector2.ONE
		var rot := 0.0
		match mood:
			"idle":
				var b := sin(_t * 2.4)
				sc = Vector2(1.0 - 0.012 * b, 1.0 + 0.03 * b)
			"scared":
				off.x = sin(_t * 55.0) * 1.6
				sc = Vector2(1.03, 0.95)
			"happy":
				var hop := absf(sin(_t * 6.5))
				off.y = -hop * 16.0
				sc = Vector2(1.0 + 0.06 * (1.0 - hop), 1.0 - 0.06 * (1.0 - hop))
				rot = sin(_t * 6.5) * 0.06
		off.y += 28.0 * (1.0 - sc.y)
		draw_set_transform(off, rot, sc)
		var curl := mood == "scared"
		var spikes := PackedVector2Array()
		var start := -0.55 if not curl else 0.0
		var span := TAU - 1.45 if not curl else TAU
		var n := 22
		for i in n + 1:
			var a := start - float(i) / float(n) * span
			var r := 40.0 if i % 2 == 1 else 27.0
			spikes.append(Vector2(cos(a), sin(a)) * r)
		if not curl:
			spikes.append(Vector2.ZERO)
		_shape(spikes, MAIN)
		_disc(Vector2.ZERO, 26.0, DARK, 0.0)
		# folhinha presa nos espinhos
		var lc := Vector2(-16, -30)
		_oval(lc, Vector2(9, 5), Color("5cc46a"), 2.5, -0.6)
		draw_line(lc + Vector2(-6, 4), lc + Vector2(6, -4), Color("3f8f5a"), 2.0, true)
		if curl:
			# enrolado: só os olhinhos espiando
			_eye(Vector2(10, 2), 4.5)
			_eye(Vector2(20, 1), 4.0)
		else:
			_oval(Vector2(-6, 24), Vector2(7, 5), LIGHT)
			_oval(Vector2(12, 25), Vector2(7, 5), LIGHT)
			_oval(Vector2(11, 4), Vector2(20, 18), LIGHT)
			_disc(Vector2(30, 3), 4.5, Color("5a3a4a"), 2.0)
			draw_circle(Vector2(6, 10), 4.5, BLUSH, true, -1.0, true)
			_eye(Vector2(11, -4), 5.0)
			_eye(Vector2(22, -5), 4.5)
			_mouth(Vector2(22, 11), 7.0)
		draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in BRAND.length():
		_squash.append(0.0)
	_pingo = Pingo.new()
	_pingo.visible = false
	add_child(_pingo)


func start() -> void:
	_t = 0.0
	_done = false
	_hops_done = 0
	_uncurled = false
	_ball_squash = 0.0
	_pingo.mood = "scared"
	_pingo.visible = false
	visible = true


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	for i in _squash.size():
		_squash[i] = maxf(_squash[i] - delta * 3.5, 0.0)
	_ball_squash = maxf(_ball_squash - delta * 5.0, 0.0)
	_update_layout()
	_update_pingo()
	queue_redraw()
	if _t >= DURATION:
		finish()


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if tap and _t > 0.4:
		finish()
		accept_event()


func finish() -> void:
	if _done:
		return
	_done = true
	done.emit()


# ------------------------------------------------------------------ layout das letras
func _update_layout() -> void:
	var w := size.x
	var fs := int(minf(w * 0.135, 130.0))
	var center := Vector2(w * 0.5, size.y * 0.46)
	var total_w := FONT_BOLD.get_string_size(BRAND, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var xs: Array[float] = []
	var ws: Array[float] = []
	for i in BRAND.length():
		xs.append((w - total_w) * 0.5 + FONT_BOLD.get_string_size(BRAND.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		ws.append(FONT_BOLD.get_string_size(BRAND[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	_layout = {"fs": fs, "center": center, "base": center.y + fs * 0.36, "xs": xs, "ws": ws,
		"xh": fs * 0.55, "cap": fs * 0.73, "r": fs * 0.29}


## Ponto onde o Pingo pousa: em cima da letra i (ou dentro do "o" quando i == SLOT).
func _perch(i: int) -> Vector2:
	var xs: Array = _layout["xs"]
	var ws: Array = _layout["ws"]
	var x: float = xs[i] + ws[i] * 0.5
	var base: float = _layout["base"]
	var r: float = _layout["r"]
	if i == SLOT:
		return Vector2(x, base - _layout["xh"] * 0.5)
	var tall := "RtNh".contains(BRAND[i])
	return Vector2(x, base - (_layout["cap"] if tall else _layout["xh"]) - r * 0.95)


# ------------------------------------------------------------------ o Pingo
func _update_pingo() -> void:
	if _layout.is_empty():
		return
	var r: float = _layout["r"]
	var sc := r / 34.0
	_pingo.visible = _t >= T_ENTER
	var pos := _perch(SLOT)
	var rot := 0.0
	if _t < T_LAND:
		var k := maxi(int((_t - T_ENTER) / HOP), 0)
		var f := fmod(maxf(_t - T_ENTER, 0.0), HOP) / HOP
		var from := Vector2(-r * 3.0, _perch(0).y - 220.0) if k == 0 else _perch(HOP_LETTERS[k - 1])
		var to := _perch(HOP_LETTERS[k]) if k < HOP_LETTERS.size() else _perch(SLOT)
		var arc := 110.0 if k >= HOP_LETTERS.size() else 70.0
		pos = from.lerp(to, f) + Vector2(0, -arc * 4.0 * f * (1.0 - f))
		rot = (_t - T_ENTER) * 9.0
		if k > _hops_done:
			_bounce_on(HOP_LETTERS[k - 1], k)
	elif _hops_done <= HOP_LETTERS.size():
		_bounce_on(SLOT, HOP_LETTERS.size() + 1)
	else:
		# pulinhos que vão diminuindo dentro do "o"
		var tt := _t - T_LAND
		for s in SETTLE:
			if tt < s[0]:
				var f: float = tt / float(s[0])
				pos.y -= float(s[1]) * 4.0 * f * (1.0 - f)
				break
			tt -= float(s[0])
	if _t >= T_UNCURL and not _uncurled:
		_uncurled = true
		_pingo.mood = "idle"
		_pingo.look = Vector2(-0.2, 0.3)
		_ball_squash = 1.0
		Audio.sfx("pop", 0.0, 0.0, 1.5)
		Audio.sfx("retro_jingle", -2.0, 0.0)
	if _uncurled and _t > T_UNCURL + 0.55 and _t < T_UNCURL + 1.4:
		_pingo.mood = "happy"
	elif _uncurled and _t >= T_UNCURL + 1.4:
		_pingo.mood = "idle"
	var squ := Vector2(1.0 + 0.25 * _ball_squash, 1.0 - 0.25 * _ball_squash)
	_pingo.scale = squ * sc * (0.9 if _uncurled else 1.0)
	_pingo.rotation = 0.0 if _uncurled else rot
	_pingo.position = pos + Vector2(0, r * 0.25 * _ball_squash)


func _bounce_on(letter: int, count: int) -> void:
	_hops_done = count
	_ball_squash = 1.0
	if letter != SLOT:
		_squash[letter] = 1.0
		Audio.sfx("pop", -4.0, 0.0, 0.9 + letter * 0.12)
	else:
		Audio.sfx("bonk", -2.0, 0.0, 1.4)


# ------------------------------------------------------------------ desenho
func _draw() -> void:
	if _layout.is_empty():
		return
	var w := size.x
	var h := size.y
	var fade_out := clampf((DURATION - _t) / 0.4, 0.0, 1.0)
	draw_rect(Rect2(0, 0, w, h), INDIGO, true)
	var center: Vector2 = _layout["center"]
	for i in 16:
		var rr := minf(w, h) * (0.64 - i * 0.032)
		draw_circle(center, rr, Color(INDIGO_LIGHT, 0.04 * clampf(_t / 0.8, 0.0, 1.0)), true, -1.0, true)
	var fs: int = _layout["fs"]
	var base: float = _layout["base"]
	var xs: Array = _layout["xs"]
	var ws: Array = _layout["ws"]
	# letras (menos o "o", que é o Pingo); amassam quando ele pula em cima
	for i in BRAND.length():
		if i == SLOT:
			continue
		var k := clampf((_t - 0.2 - i * 0.05) / 0.35, 0.0, 1.0)
		if k <= 0.0:
			continue
		var e := 1.0 - pow(1.0 - k, 3.0)
		var sq: float = _squash[i]
		var wob := sin(sq * PI * 2.0) * 0.08
		var scale_l := Vector2(1.0 + 0.2 * sq + wob, 1.0 - 0.32 * sq - wob)
		var pivot := Vector2(float(xs[i]) + float(ws[i]) * 0.5, base + (1.0 - e) * 30.0)
		draw_set_transform(pivot, 0.0, scale_l)
		draw_string(FONT_BOLD, Vector2(-float(ws[i]) * 0.5, 0), BRAND[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, k * fade_out))
	draw_set_transform(Vector2.ZERO)
	# sombrinha do Pingo no chão das letras
	if _pingo.visible:
		var px := _pingo.position.x
		var dist := clampf((base - _pingo.position.y) / 300.0, 0.0, 1.0)
		var shadow := Pingo._ellipse(Vector2(px, base + 6.0), Vector2(float(_layout["r"]) * (1.0 - dist * 0.5), 5.0))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.18 * (1.0 - dist)))
	_pingo.modulate.a = fade_out
	# "desenvolvido por" em cima, site embaixo (o site chega quando o Pingo vira a letra)
	var a_top := clampf((_t - 0.1) / 0.4, 0.0, 1.0) * fade_out
	draw_string(FONT_MEDIUM, Vector2(0, center.y - fs * 0.72), "desenvolvido por", HORIZONTAL_ALIGNMENT_CENTER, w, int(fs * 0.24), Color(SOFT, 0.8 * a_top))
	var a_site := clampf((_t - T_UNCURL - 0.2) / 0.45, 0.0, 1.0) * fade_out
	draw_string(FONT_MEDIUM, Vector2(0, base + fs * 0.78 + (1.0 - a_site) * 10.0), SITE, HORIZONTAL_ALIGNMENT_CENTER, w, int(fs * 0.36), Color(SOFT, a_site))
	draw_string(FONT_MEDIUM, Vector2(0, h - 60), "toque para continuar", HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(1, 1, 1, 0.4 * a_site))
