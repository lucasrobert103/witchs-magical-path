class_name Prologue
extends Control
## "Prólogo — O nascimento dos primeiros Deuses": the author's text, card by card,
## over animated scenes of the Infinite, the Goddess, her reflection and creation.

signal done

const CARDS := [
	{"scene": "title", "text": ""},
	{"scene": "void", "text": "No princípio, não havia céu ou terra. Não havia estrelas, não havia tempo, nem mesmo o silêncio, pois o silêncio ainda não conhecia a própria existência."},
	{"scene": "infinite", "text": "Havia apenas o Infinito."},
	{"scene": "goddess", "text": "E nele vagava a Deusa, a Primeira, aquela que existia antes de todas as coisas. Por eras que jamais poderiam ser contadas, ela percorreu a vastidão, solitária em sua eternidade."},
	{"scene": "reflection", "text": "Até que, em meio ao vazio, encontrou algo que jamais havia conhecido: seu próprio reflexo."},
	{"scene": "reflection", "text": "Ao contemplar sua imagem, a Deusa descobriu a beleza, o amor e o desejo de compartilhar sua existência. E apaixonou-se por aquilo que via."},
	{"scene": "touch", "text": "Aproximou-se de seu reflexo e estendeu-lhe as mãos. No instante em que seus dedos se tocaram, o Infinito estremeceu. Pela primeira vez, a existência reconheceu a si mesma."},
	{"scene": "love", "text": "E a Deusa amou seu reflexo com toda a força de sua essência.\n\nDaquela união sagrada, algo extraordinário aconteceu."},
	{"scene": "god_born", "text": "Seu reflexo deixou de ser apenas uma imagem. De dentro da luz que os envolvia, uma nova presença tomou forma: uma divindade masculina, nascida da essência da Deusa, mas dotada de vontade, consciência e espírito próprios."},
	{"scene": "pair", "text": "Assim nasceu o Deus, seu companheiro, sua contraparte e o primeiro ser a compartilhar com ela a vastidão da eternidade."},
	{"scene": "pair", "text": "Ele era diferente dela, mas carregava em si a mesma origem. Onde ela era o mistério que acolhe, ele era a força que transforma. Onde ela era o potencial adormecido, ele era o impulso que o despertava."},
	{"scene": "equal", "text": "Nenhum existia acima do outro. Eram duas expressões de uma mesma origem, distintos em suas naturezas, unidos pelo amor que os havia trazido à existência."},
	{"scene": "entwine", "text": "E, quando suas essências se entrelaçaram novamente, a união dos dois produziu a primeira grande manifestação de poder."},
	{"scene": "creation", "text": "O Infinito rompeu seu silêncio.\n\nDo encontro entre suas forças nasceu a criação."},
	{"scene": "elements", "text": "Das lágrimas da Deusa surgiram os oceanos. De seu sopro nasceram os ventos. Dos gestos do Deus brotaram as montanhas, e de sua chama acenderam-se as estrelas."},
	{"scene": "worlds", "text": "Juntos, deram forma aos mundos, teceram os céus e estabeleceram os ciclos que regeriam a existência."},
	{"scene": "sparks", "text": "E, em cada coisa criada, depositaram uma centelha de sua essência."},
	{"scene": "magic", "text": "A Deusa deixou sua magia nas raízes, nas águas, nos ciclos da Lua, nos sonhos e nos mistérios da vida. O Deus deixou sua força nas chamas, no movimento, na transformação, no crescimento e na energia que percorre todas as coisas."},
	{"scene": "balance", "text": "Mas nenhuma dessas forças pertencia exclusivamente a um deles. Pois toda criação carregava ambas: o poder de gerar e o poder de transformar, o mistério e o movimento, a noite e a chama."},
	{"scene": "balance", "text": "Assim, a magia tornou-se parte de tudo o que existia."},
	{"scene": "humanity", "text": "E, muito tempo depois, quando a humanidade aprendeu a observar os astros, conhecer as ervas, interpretar os sonhos e escutar os segredos da natureza, algumas pessoas descobriram como tocar essa força primordial."},
	{"scene": "witches", "text": "Foram chamadas de bruxas e bruxos."},
	{"scene": "forgotten", "text": "Mas poucos se lembrariam de onde a magia realmente veio.\n\nE menos ainda conheceriam os nomes daqueles que a haviam criado."},
]

const SCENES := {
	"title": ["motes", "nebula"],
	"void": ["motes"],
	"infinite": ["motes", "nebula"],
	"goddess": ["motes", "nebula", "goddess"],
	"reflection": ["motes", "nebula", "goddess", "reflection", "seam"],
	"touch": ["motes", "nebula", "goddess_reach", "reflection_reach", "seam", "ring"],
	"love": ["motes", "nebula", "goddess_reach", "reflection_reach", "warm"],
	"god_born": ["motes", "nebula", "goddess_reach", "god_reach", "warm"],
	"pair": ["motes", "nebula", "goddess", "god", "stars_dim"],
	"equal": ["motes", "nebula", "goddess", "god", "bond", "stars_dim"],
	"entwine": ["nebula", "spirals", "stars_dim"],
	"creation": ["burst", "stars", "spirals"],
	"elements": ["stars", "waves", "wind", "mountains"],
	"worlds": ["stars", "planets"],
	"sparks": ["stars", "rain", "mountains", "waves"],
	"magic": ["stars", "roots", "flames", "mountains"],
	"balance": ["stars", "yin"],
	"humanity": ["stars", "horizon", "people", "fire"],
	"witches": ["stars", "horizon", "people", "fire", "people_glow"],
	"forgotten": ["stars_dim", "horizon", "people"],
}

var _card := 0
var _t := 0.0
var _card_t := 0.0
var _alpha := {}
var _stars: Array = []
var _motes: Array = []
var _text: Label
var _title: VBoxContainer
var _skip: Button
var _hint: Label
var _tex := {}
var _finished := false
var _flash := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for n in ["goddess", "goddess_reach", "god", "god_reach"]:
		_tex[n] = load("res://assets/sprites/prologue/%s.png" % n)
	_tex["dot"] = load("res://assets/sprites/fx/soft_dot.png")
	_tex["spark"] = load("res://assets/sprites/fx/sparkle.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 220:
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.8), rng.randf_range(0.6, 2.4), rng.randf() * TAU, rng.randf()])
	for i in 60:
		_motes.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(0.004, 0.012), rng.randf() * TAU])
	_text = UIKit.label("", UIKit.serif, 36, Color("efe4cb"), HORIZONTAL_ALIGNMENT_CENTER)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_text.custom_minimum_size = Vector2(1060, 230)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_text.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_text.position = Vector2(-530, -70)
	_text.add_theme_constant_override("line_spacing", 4)
	add_child(_text)
	_title = VBoxContainer.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.alignment = BoxContainer.ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_title.add_child(UIKit.label("Prólogo", UIKit.title_regular, 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var orn := UIKit.ornament(360)
	orn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title.add_child(orn)
	_title.add_child(UIKit.label("O nascimento dos primeiros Deuses", UIKit.title_font, 46, UIKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	_skip = UIKit.button("Pular  ›", false, 150)
	_skip.custom_minimum_size = Vector2(150, 48)
	_skip.add_theme_font_size_override("font_size", 18)
	UIKit.pin(_skip, 1.0, 0.0, -28.0, 26.0)
	_skip.pressed.connect(finish)
	add_child(_skip)
	_hint = UIKit.label("toque para continuar", UIKit.sans, 16, Color(0.86, 0.76, 0.54, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	_hint.custom_minimum_size = Vector2(200, 0)
	UIKit.pin(_hint, 0.5, 1.0, 0.0, -24.0)
	add_child(_hint)
	_set_card(0)

func start() -> void:
	_card = 0
	_finished = false
	_set_card(0)
	Audio.play_music("res://assets/audio/music_prologue.ogg", 3.0, -3.0)

func _set_card(i: int) -> void:
	_card = i
	_card_t = 0.0
	var c: Dictionary = CARDS[i]
	_text.text = c["text"]
	_text.visible_ratio = 0.0
	UIKit.pin(_text, 0.5, 1.0, 0.0, -60.0)
	_title.visible = c["scene"] == "title"
	_title.modulate.a = 0.0
	if c["scene"] in ["touch", "creation", "god_born"]:
		_flash = 1.0
		if c["scene"] == "creation":
			Audio.sfx("gate", -4.0)
		else:
			Audio.sfx("rune", -6.0)

func _duration(i: int) -> float:
	var txt: String = CARDS[i]["text"]
	return 5.0 if txt == "" else 3.5 + txt.length() / 15.0

func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if tap:
		advance()
		accept_event()

func advance() -> void:
	if _finished:
		return
	if _text.visible_ratio < 1.0 and CARDS[_card]["text"] != "":
		_text.visible_ratio = 1.0
		_card_t = maxf(_card_t, 1.5)
		return
	if _card < CARDS.size() - 1:
		_set_card(_card + 1)
	else:
		finish()

func finish() -> void:
	if _finished:
		return
	_finished = true
	done.emit()

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_card_t += delta
	_flash = maxf(0.0, _flash - delta * 0.8)
	var c: Dictionary = CARDS[_card]
	var txt: String = c["text"]
	if txt != "":
		var reveal := clampf((_card_t - 0.6) * 30.0 / maxf(1.0, txt.length()), 0.0, 1.0)
		_text.visible_ratio = maxf(_text.visible_ratio, reveal)
	if c["scene"] == "title":
		_title.modulate.a = clampf(_card_t / 2.0, 0.0, 1.0) * clampf((_duration(_card) - _card_t) / 1.0, 0.0, 1.0)
	_hint.modulate.a = (0.4 + 0.3 * sin(_t * 3.0)) if _text.visible_ratio >= 1.0 else 0.0
	if not _finished and _card_t > _duration(_card):
		if _card < CARDS.size() - 1:
			_set_card(_card + 1)
		else:
			finish()
	var want: Array = SCENES[c["scene"]]
	for k in ["motes", "nebula", "stars", "stars_dim", "goddess", "goddess_reach", "reflection", "reflection_reach", "seam", "ring", "warm", "god", "god_reach", "bond", "spirals", "burst", "waves", "wind", "mountains", "planets", "rain", "roots", "flames", "yin", "horizon", "people", "fire", "people_glow"]:
		var target := 1.0 if want.has(k) else 0.0
		_alpha[k] = move_toward(_alpha.get(k, 0.0), target, delta * (0.55 if target > 0 else 0.8))
	queue_redraw()

func _a(k: String) -> float:
	return _alpha.get(k, 0.0)

func _glow(p: Vector2, r: float, col: Color) -> void:
	draw_texture_rect(_tex["dot"], Rect2(p - Vector2.ONE * r, Vector2.ONE * r * 2.0), false, col)

func _figure(name: String, center: Vector2, h: float, col: Color, flip := false) -> void:
	var t: Texture2D = _tex[name]
	var w := h * 0.5
	var rect := Rect2(center - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
	if flip:
		rect = Rect2(rect.position + Vector2(w, 0), Vector2(-w, h))
	draw_texture_rect(t, rect, false, col)

func _draw() -> void:
	var s := size
	var c := s * 0.5
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.012, 0.014, 0.03))
	var fig_h := s.y * 0.78
	var fig_y := s.y * 0.42
	# Nebula.
	var na := _a("nebula")
	if na > 0.0:
		for i in 5:
			var p := c + Vector2(sin(_t * 0.05 + i * 1.7) * s.x * 0.3, cos(_t * 0.04 + i * 2.1) * s.y * 0.2)
			var col: Color = [Color(0.35, 0.2, 0.55), Color(0.15, 0.35, 0.5), Color(0.5, 0.25, 0.4), Color(0.2, 0.3, 0.6), Color(0.3, 0.45, 0.5)][i]
			col.a = 0.16 * na
			_glow(p, s.y * 0.65, col)
	# Stars.
	var sa := maxf(_a("stars"), _a("stars_dim") * 0.35)
	if sa > 0.0:
		for st in _stars:
			var tw := 0.55 + 0.45 * sin(_t * 1.5 + st[2])
			var p: Vector2 = st[0] * s
			var r: float = st[1]
			draw_circle(p, r, Color(1, 0.97, 0.9, sa * tw * (0.5 + st[3] * 0.5)))
			if st[3] > 0.9:
				_glow(p, r * 7.0, Color(1, 0.9, 0.7, 0.25 * sa * tw))
	# Dust motes.
	var ma := _a("motes")
	if ma > 0.0:
		for m in _motes:
			var p := Vector2(fposmod(m[0].x + _t * m[1], 1.0), fposmod(m[0].y + sin(_t * 0.3 + m[2]) * 0.02, 1.0)) * s
			_glow(p, 6.0, Color(0.7, 0.75, 0.9, 0.25 * ma))
	# The Goddess and her reflection.
	var silver := Color(0.82, 0.9, 1.0)
	var gold := Color(1.0, 0.82, 0.5)
	var bob := sin(_t * 0.8) * 8.0
	var drift := sin(_t * 0.12) * 30.0
	var ga := _a("goddess")
	if ga > 0.0:
		var x := lerpf(c.x + drift, c.x - s.x * 0.17, maxf(_a("reflection"), _a("god")))
		_glow(Vector2(x, fig_y), fig_h * 0.45, Color(0.5, 0.65, 1.0, 0.25 * ga))
		_figure("goddess", Vector2(x, fig_y + bob), fig_h, Color(silver, ga))
	var gra := _a("goddess_reach")
	if gra > 0.0:
		var x := c.x - s.x * 0.125
		_glow(Vector2(x, fig_y), fig_h * 0.45, Color(0.5, 0.65, 1.0, 0.25 * gra))
		_figure("goddess_reach", Vector2(x, fig_y + bob * 0.5), fig_h, Color(silver, gra))
	var ra := _a("reflection")
	if ra > 0.0:
		var x := c.x + s.x * 0.17
		var shimmer := 0.55 + 0.15 * sin(_t * 4.0)
		_figure("goddess", Vector2(x, fig_y - bob), fig_h, Color(0.7, 0.8, 1.0, ra * shimmer), true)
	var rra := _a("reflection_reach")
	if rra > 0.0:
		var x := c.x + s.x * 0.125
		_figure("goddess_reach", Vector2(x, fig_y - bob * 0.5), fig_h, Color(0.75, 0.82, 1.0, rra * 0.75), true)
	var sea := _a("seam")
	if sea > 0.0:
		for i in 6:
			_glow(Vector2(c.x, s.y * (0.1 + i * 0.15)), 60.0, Color(0.7, 0.85, 1.0, 0.18 * sea))
		draw_line(Vector2(c.x, s.y * 0.05), Vector2(c.x, s.y * 0.85), Color(0.8, 0.9, 1.0, 0.25 * sea), 1.5, true)
	var gda := _a("god_reach")
	if gda > 0.0:
		var x := c.x + s.x * 0.125
		_glow(Vector2(x, fig_y), fig_h * 0.45, Color(1.0, 0.7, 0.3, 0.3 * gda))
		_figure("god_reach", Vector2(x, fig_y - bob * 0.5), fig_h, Color(gold, gda), true)
	var goa := _a("god")
	if goa > 0.0:
		var x := c.x + s.x * 0.17
		_glow(Vector2(x, fig_y), fig_h * 0.45, Color(1.0, 0.7, 0.3, 0.25 * goa))
		_figure("god", Vector2(x, fig_y - bob), fig_h, Color(gold, goa), true)
	var wa := _a("warm")
	if wa > 0.0:
		_glow(Vector2(c.x, fig_y - fig_h * 0.1), s.y * 0.55, Color(1.0, 0.85, 0.6, 0.35 * wa * (0.8 + 0.2 * sin(_t * 2.0))))
	var ba := _a("bond")
	if ba > 0.0:
		var r := s.y * 0.38
		draw_arc(Vector2(c.x, fig_y), r, 0, TAU, 96, Color(1, 0.95, 0.85, 0.35 * ba), 2.0, true)
		draw_arc(Vector2(c.x, fig_y), r * 1.06, _t * 0.2, _t * 0.2 + PI, 64, Color(0.6, 0.85, 1.0, 0.5 * ba), 2.0, true)
		draw_arc(Vector2(c.x, fig_y), r * 1.06, _t * 0.2 + PI, _t * 0.2 + TAU, 64, Color(1.0, 0.75, 0.4, 0.5 * ba), 2.0, true)
	var rga := _a("ring")
	if rga > 0.0 and _card_t < 4.0:
		var rr := _card_t * s.y * 0.35
		draw_arc(Vector2(c.x, fig_y - fig_h * 0.12), rr, 0, TAU, 96, Color(1, 1, 1, rga * clampf(1.0 - _card_t / 4.0, 0.0, 1.0)), 3.0, true)
	# Entwined essences.
	var spa := _a("spirals")
	if spa > 0.0:
		for k in 2:
			var col := Color(0.55, 0.85, 1.0) if k == 0 else Color(1.0, 0.72, 0.35)
			var prev := Vector2.ZERO
			for i in 90:
				var u := i / 90.0
				var a := _t * 1.2 + u * TAU * 2.5 + k * PI
				var rad := u * s.y * 0.38
				var p := c + Vector2(cos(a), sin(a) * 0.55) * rad + Vector2(0, -s.y * 0.06)
				if i > 0:
					draw_line(prev, p, Color(col, spa * (1.0 - u) * 0.9), 3.0 * (1.0 - u) + 0.5, true)
				prev = p
				if i % 12 == 0:
					_glow(p, 18.0 * (1.0 - u) + 4.0, Color(col, spa * 0.6))
		_glow(c + Vector2(0, -s.y * 0.06), 90.0, Color(1, 0.95, 0.85, spa * 0.7))
	var bua := _a("burst")
	if bua > 0.0:
		for i in 48:
			var a := i * TAU / 48.0 + sin(i * 7.3)
			var rr := (_card_t * 0.5 + fposmod(i * 0.37, 1.0)) * s.x * 0.35
			var p := c + Vector2(cos(a), sin(a) * 0.6) * rr
			draw_texture_rect(_tex["spark"], Rect2(p - Vector2.ONE * 14, Vector2.ONE * 28), false, Color(1, 0.9, 0.7, bua * clampf(1.0 - rr / (s.x * 0.6), 0.0, 1.0)))
	# Elements: ocean, wind, mountains.
	var mo := _a("mountains")
	if mo > 0.0:
		var rise := clampf(_card_t / 4.0, 0.0, 1.0) if CARDS[_card]["scene"] == "elements" else 1.0
		for layer in 2:
			var pts := PackedVector2Array()
			pts.append(Vector2(0, s.y))
			for i in 13:
				var x := i / 12.0 * s.x
				var hgt := (0.25 + 0.18 * sin(i * 1.7 + layer * 2.0) + 0.1 * sin(i * 3.1)) * s.y * (0.9 - layer * 0.25) * rise
				pts.append(Vector2(x, s.y * 0.86 - hgt))
			pts.append(Vector2(s.x, s.y))
			draw_colored_polygon(pts, Color(0.08 + layer * 0.04, 0.09 + layer * 0.05, 0.16 + layer * 0.04, mo))
	var wv := _a("waves")
	if wv > 0.0:
		draw_rect(Rect2(0, s.y * 0.86, s.x, s.y * 0.14), Color(0.05, 0.14, 0.24, wv))
		for row in 4:
			var prev := Vector2.ZERO
			for i in 64:
				var x := i / 63.0 * s.x
				var p := Vector2(x, s.y * (0.87 + row * 0.03) + sin(x * 0.02 + _t * (1.2 + row * 0.3)) * 5.0)
				if i > 0:
					draw_line(prev, p, Color(0.5, 0.8, 1.0, wv * (0.5 - row * 0.1)), 2.0, true)
				prev = p
	var wi := _a("wind")
	if wi > 0.0:
		for i in 7:
			var y := s.y * (0.18 + i * 0.07)
			var x0 := fposmod(_t * 160.0 + i * 230.0, s.x * 1.4) - s.x * 0.2
			var prev := Vector2(x0, y)
			for k in 20:
				var p := Vector2(x0 + k * 14.0, y + sin(k * 0.4 + _t * 2.0 + i) * 10.0)
				draw_line(prev, p, Color(0.9, 0.95, 1.0, wi * 0.35 * sin(k / 20.0 * PI)), 2.0, true)
				prev = p
	var pl := _a("planets")
	if pl > 0.0:
		var sun := Vector2(c.x, s.y * 0.4)
		_glow(sun, 120.0, Color(1.0, 0.8, 0.5, 0.8 * pl))
		for i in 4:
			var rad := 90.0 + i * 70.0
			draw_arc(sun, rad, 0, TAU, 96, Color(1, 1, 1, 0.12 * pl), 1.0, true)
			var a := _t * (0.5 - i * 0.09) + i * 1.9
			var p := sun + Vector2(cos(a), sin(a) * 0.45) * rad
			var col: Color = [Color(0.6, 0.85, 1.0), Color(0.9, 0.6, 0.4), Color(0.6, 0.9, 0.6), Color(0.85, 0.8, 1.0)][i]
			draw_circle(p, 8.0 + i * 3.0, Color(col, pl))
			_glow(p, 26.0 + i * 6.0, Color(col, 0.4 * pl))
		# Moon phases cycle.
		for i in 8:
			var mp := Vector2(c.x - 280 + i * 80, s.y * 0.1)
			draw_circle(mp, 14, Color(0.9, 0.92, 1.0, pl * 0.8))
			var ph := fposmod(i / 8.0 + _t * 0.05, 1.0)
			draw_circle(mp + Vector2((ph - 0.5) * 56.0, 0), 14, Color(0.012, 0.014, 0.03, pl))
	var rn := _a("rain")
	if rn > 0.0:
		for i in 40:
			var x := fposmod(i * 97.3, s.x)
			var y := fposmod(_t * (60.0 + fposmod(i * 13.0, 50.0)) + i * 41.0, s.y * 0.85)
			var col := Color(0.6, 0.88, 1.0) if i % 2 == 0 else Color(1.0, 0.78, 0.4)
			draw_texture_rect(_tex["spark"], Rect2(Vector2(x, y) - Vector2.ONE * 10, Vector2.ONE * 20), false, Color(col, rn * 0.9))
	var ro := _a("roots")
	if ro > 0.0:
		for i in 9:
			var x0 := s.x * (0.05 + i * 0.05)
			var p := Vector2(x0, s.y)
			for k in 12:
				var np := p + Vector2(sin(i * 3.0 + k * 0.9) * 14.0, -s.y * 0.035)
				draw_line(p, np, Color(0.5, 0.88, 1.0, ro * (1.0 - k / 12.0) * (0.6 + 0.4 * sin(_t * 2.0 + i))), 3.0 - k * 0.2, true)
				p = np
	var fl := _a("flames")
	if fl > 0.0:
		for i in 9:
			var x := s.x * (0.55 + i * 0.05)
			for k in 5:
				var y := s.y * 0.95 - fposmod(_t * 90.0 + k * 40.0 + i * 13.0, 200.0)
				var life := 1.0 - (s.y * 0.95 - y) / 200.0
				_glow(Vector2(x + sin(_t * 3.0 + k + i) * 8.0, y), 26.0 * life + 6.0, Color(1.0, 0.6 + 0.2 * life, 0.25, fl * life * 0.8))
	var yi := _a("yin")
	if yi > 0.0:
		var cc := c + Vector2(0, -s.y * 0.08)
		var r := s.y * 0.26
		var rot := _t * 0.25
		var cols := [Color(0.55, 0.85, 1.0), Color(1.0, 0.7, 0.35)]
		var axis := Vector2(cos(rot), sin(rot))
		for k in 2:
			var pts := PackedVector2Array()
			for i in 49:
				var a := rot + k * PI + i / 48.0 * PI
				pts.append(cc + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color(cols[k], 0.55 * yi))
		# Classic construction: two half-size discs swap the halves, with small dots.
		draw_circle(cc + axis * r * 0.5, r * 0.5, Color(cols[0], 0.55 * yi))
		draw_circle(cc - axis * r * 0.5, r * 0.5, Color(cols[1], 0.55 * yi))
		_glow(cc + axis * r * 0.5, 30.0, Color(cols[1], yi))
		_glow(cc - axis * r * 0.5, 30.0, Color(cols[0], yi))
		_glow(cc, r * 1.9, Color(1, 0.95, 0.85, 0.2 * yi))
	var ho := _a("horizon")
	if ho > 0.0:
		var pts := PackedVector2Array([Vector2(0, s.y), Vector2(0, s.y * 0.8)])
		for i in 21:
			pts.append(Vector2(i / 20.0 * s.x, s.y * 0.8 - sin(i * 0.7) * 18.0 - sin(i * 1.9) * 8.0))
		pts.append(Vector2(s.x, s.y))
		draw_colored_polygon(pts, Color(0.03, 0.04, 0.06, ho))
	var pe := _a("people")
	if pe > 0.0:
		for i in 6:
			var x := s.x * (0.32 + i * 0.075) + (25.0 if i > 2 else 0.0)
			var base := s.y * 0.81
			var h := 70.0 + (i % 3) * 12.0
			var col := Color(0.02, 0.03, 0.05, pe)
			draw_circle(Vector2(x, base - h), h * 0.13, col)
			var body := PackedVector2Array([Vector2(x - h * 0.17, base), Vector2(x - h * 0.12, base - h * 0.85), Vector2(x + h * 0.12, base - h * 0.85), Vector2(x + h * 0.17, base)])
			draw_colored_polygon(body, col)
			var pg := _a("people_glow")
			if pg > 0.0 and i % 2 == 0:
				var hand := Vector2(x + h * 0.25, base - h * 1.05)
				draw_line(Vector2(x + h * 0.1, base - h * 0.75), hand, col, 6.0, true)
				_glow(hand, 22.0 + 4.0 * sin(_t * 3.0 + i), Color(0.6, 0.9, 1.0, pg) if i % 4 == 0 else Color(1.0, 0.75, 0.4, pg))
	var fi := _a("fire")
	if fi > 0.0:
		var fp := Vector2(s.x * 0.5 + 10, s.y * 0.8)
		_glow(fp, 70.0 + 6.0 * sin(_t * 9.0), Color(1.0, 0.6, 0.25, 0.7 * fi))
		_glow(fp + Vector2(0, -8), 22.0, Color(1.0, 0.85, 0.5, fi))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 0.97, 0.9, _flash * 0.55))
	# Soft vignette for the text.
	var grad_h := s.y * 0.45
	for i in 12:
		var y := s.y - grad_h * (i + 1) / 12.0
		draw_rect(Rect2(0, y, s.x, grad_h / 12.0 + 1), Color(0, 0, 0, 0.05 * (12 - i) / 12.0 * 4.0))
