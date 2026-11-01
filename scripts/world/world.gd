class_name World
extends BaseWorld
## Chapter I — O Despertar (Bosque do Despertar). A chain of small discoveries:
## the forest answers her presence → the spring wakes her hands → light rekindles
## the lanterns → shadows dissolve in light → the flame joins the water → the two
## altars, together, open the portal.

const CHECKPOINTS := {
	"clearing": [Vector2(0, 51), Vector2(0, -1)],
	"pool": [Vector2(-5.5, 21.5), Vector2(0.3, -1)],
	"lanterns": [Vector2(0, 0.5), Vector2(0, -1)],
	"ruins": [Vector2(-3, -21), Vector2(0.3, -1)],
	"brazier": [Vector2(8, -37), Vector2(-0.4, -1)],
	"sanctuary": [Vector2(0, -49), Vector2(0, -1)],
}

const ZONES := [
	{"id": "clearing", "p": Vector2(0, 52), "r": 9.0, "title": "Clareira do Despertar", "sub": "Bosque do Despertar"},
	{"id": "glade", "p": Vector2(13, 39), "r": 5.0, "title": "Anel de Cogumelos", "sub": ""},
	{"id": "pool", "p": Vector2(-9, 21), "r": 5.5, "title": "Fonte da Lua", "sub": ""},
	{"id": "lanterns", "p": Vector2(0, 5), "r": 7.0, "title": "Trilha das Lanternas", "sub": ""},
	{"id": "ruins", "p": Vector2(-4, -23), "r": 8.0, "title": "Ruínas Esquecidas", "sub": ""},
	{"id": "brazier", "p": Vector2(9, -39), "r": 5.5, "title": "Chama Eterna", "sub": ""},
	{"id": "sanctuary", "p": Vector2(0, -55), "r": 10.0, "title": "Santuário dos Primeiros", "sub": ""},
]

var lanterns: Array = []
var pedestals: Array = []
var _roots: Node3D
var _veil: MeshInstance3D
var _veil_mat: ShaderMaterial
var _gate_glow: MeshInstance3D
var _ring_done := false

func _checkpoints() -> Dictionary:
	return CHECKPOINTS

func _zones() -> Array:
	return ZONES

# ---------------------------------------------------------------- layout
func _build_layout() -> void:
	var T := terrain
	T.add_circle_area(Vector2(0, 52), 12.0)
	T.add_path([Vector2(0, 52), Vector2(2.5, 42), Vector2(-0.5, 32), Vector2(-2.5, 22), Vector2(0, 12), Vector2(0, 5)], 4.2, 1.5)
	T.add_area(Vector2(0, 52), Vector2(-11, 58), 2.2)
	T.add_circle_area(Vector2(-11.5, 58.5), 2.6)
	# A side glade with a ring of mushrooms: the first place that answers her.
	T.add_area(Vector2(2.5, 42), Vector2(12, 39.5), 2.4)
	T.add_circle_area(Vector2(13, 39), 5.2)
	T.add_area(Vector2(-2.5, 22), Vector2(-8.5, 21), 4.0)
	T.add_circle_area(Vector2(-9, 21), 6.0)
	T.add_area(Vector2(-9, 21), Vector2(-15.5, 17.5), 2.2)
	T.add_circle_area(Vector2(-15.8, 17.2), 2.6)
	T.add_circle_area(Vector2(0, 5), 8.5)
	T.add_path([Vector2(0, 5), Vector2(0, -6), Vector2(-3, -14), Vector2(-4, -23)], 4.0, 1.4)
	T.add_circle_area(Vector2(-4, -23), 9.5)
	T.add_area(Vector2(-4, -23), Vector2(-15, -27), 2.6)
	T.add_circle_area(Vector2(-15.5, -27.5), 2.6)
	T.add_path([Vector2(-4, -23), Vector2(1, -31), Vector2(7, -37)], 3.8, 1.4)
	T.add_circle_area(Vector2(9, -39), 6.5)
	T.add_area(Vector2(9, -39), Vector2(16, -44), 2.0)
	T.add_circle_area(Vector2(16.4, -44.4), 2.6)
	T.add_path([Vector2(7, -37), Vector2(3, -44), Vector2(0, -49), Vector2(0, -55)], 3.8, 1.4)
	T.add_circle_area(Vector2(0, -55), 12.5)
	T.add_area(Vector2(0, -55), Vector2(-14, -61), 2.4)
	T.add_circle_area(Vector2(-14.5, -61.5), 2.6)
	T.add_path([Vector2(0, -55), Vector2(0, -74)], 2.6, 1.6)
	T.pools.append({"p": Vector2(-9.5, 21.5), "r": 3.2})
	T.add_obstacle(Vector2(-4.8, -2.5), Vector2(4.8, -2.5), 0.8, 99.0, "roots")
	T.add_obstacle(Vector2(-3.2, -67), Vector2(3.2, -67), 0.5, 99.0, "veil")
	T.add_obstacle(Vector2(-10.5, -28.8), Vector2(-10.5, -21.8), 0.45, 0.75, "log")
	for p in [Vector2(-3.7, -67), Vector2(3.7, -67)]:
		T.add_obstacle(p, p, 1.0)

func _palette(p: Vector2, rng: RandomNumberGenerator) -> String:
	var region := sin(p.x * 0.09 + p.y * 0.05) + rng.randf_range(-0.6, 0.6)
	if region > 0.4:
		return "autumn"
	if region > -0.1:
		return "gold" if rng.randf() < 0.4 else "autumn"
	return "green" if rng.randf() < 0.6 else "teal"

func _build_scenery() -> void:
	# --- Clareira do Despertar: a few old trees stand inside the clearing.
	_hero_trees([[Vector2(8.5, 48.5), 1.5, "autumn"], [Vector2(-9.5, 46.5), 1.45, "green"], [Vector2(-7.5, 58.5), 1.4, "gold"]])
	_deco("env/bush_autumn.png", Vector2(-10.5, 55.5), 1.8)
	_deco("env/boulder_a.png", Vector2(7.5, 56), 1.5)
	_block(Vector2(7.5, 56), 1.0)
	_deco("env/log.png", Vector2(4.5, 61), 1.4)
	_block(Vector2(4.5, 61), 1.2)
	_add_reactive(Vector2(5.8, 54.2), Color(0.45, 0.95, 1.0))
	_add_reactive(Vector2(-3.5, 59.5), Color(0.45, 0.95, 1.0))
	_add_reactive(Vector2(3.6, 45.0), Color(0.5, 1.0, 0.85), 1.3)
	_add_reactive(Vector2(-2.4, 37.5), Color(0.45, 0.95, 1.0), 1.3)
	_add_lore("lore_clearing", Vector2(-4.2, 45.5), "star", [
		"Sulcos antigos cobrem a pedra. De algum modo, ela consegue lê-los.",
		"“No princípio, não havia céu ou terra.”",
		"“Havia apenas o Infinito.”",
	])
	_add_spark("s1", Vector2(-12, 59), "“Das lágrimas da Deusa surgiram os oceanos.”")
	# --- Anel de Cogumelos
	for i in 9:
		var a := TAU * i / 9.0
		_add_reactive(Vector2(13, 39) + Vector2(cos(a), sin(a)) * 2.6, Color(0.55, 0.95, 1.0), 1.2, "env/mushrooms_glow.png", 0.5)
	# --- Fonte da Lua
	var pool := MoonPool.new()
	pool.world = self
	pool.id = "pool"
	_place(pool, Vector2(-9.5, 21.5))
	interactables.append(pool)
	_deco("env/runestone_moon.png", Vector2(-13.8, 24), 2.4)
	_block(Vector2(-13.8, 24), 0.5)
	_add_reactive(Vector2(-5.5, 25.5), Color(0.45, 0.95, 1.0), 1.4, "env/mushrooms_glow.png", 0.7)
	_add_reactive(Vector2(-13.5, 18.5), Color(0.45, 0.95, 1.0), 1.4, "env/mushrooms_glow.png", 0.6)
	_deco("env/fern.png", Vector2(-12.5, 25.8), 1.3)
	_add_spark("s2", Vector2(-16.3, 16.6), "“De seu sopro nasceram os ventos.”")
	# --- Trilha das Lanternas
	for i in 3:
		var l := StoneLantern.new()
		l.world = self
		l.id = "lantern_%d" % i
		l.lit = Game.flag(l.id)
		_place(l, [Vector2(-6.5, 5.5), Vector2(6.5, 6.0), Vector2(4.0, 10.5)][i])
		_block(Vector2(l.position.x, l.position.z), 0.45)
		interactables.append(l)
		lanterns.append(l)
	_roots = Node3D.new()
	_place(_roots, Vector2(0, -2.5))
	for i in 7:
		var r := Props.sprite("env/roots_barrier.png", 3.2 + (i % 2) * 0.6, true, {"ground_shade": 0.3})
		r.position = Vector3(-4.5 + i * 1.5, 0, randf_range(-0.4, 0.4))
		_roots.add_child(r)
	var root_glow := Props.glow(Color(0.5, 0.9, 0.6), 7.0, 0.12)
	root_glow.position = Vector3(0, 1.5, 0)
	_roots.add_child(root_glow)
	_deco("env/pillar_broken.png", Vector2(-7.5, -1.5), 3.4)
	_block(Vector2(-7.5, -1.5), 0.6)
	_deco("env/pillar.png", Vector2(7.5, -1.0), 4.4)
	_block(Vector2(7.5, -1.0), 0.6)
	# --- Ruínas Esquecidas
	for p in [Vector2(-11.5, -19.5), Vector2(3.5, -20.5), Vector2(-7.5, -31.5), Vector2(2.5, -28.5)]:
		_deco("env/pillar.png" if int(p.x) % 2 == 0 else "env/pillar_broken.png", p, 4.6)
		_block(p, 0.6)
	_deco("env/wall_ruin.png", Vector2(-4, -34.5), 3.4)
	_deco("env/wall_ruin.png", Vector2(-14.5, -16.5), 3.0)
	_deco("env/wall_ruin.png", Vector2(8.5, -24), 2.8)
	_deco("env/log.png", Vector2(-10.5, -25.3), 1.5, true, {"ground_shade": 0.3})
	_deco("env/mushrooms_orange.png", Vector2(-12.2, -22.8), 0.6)
	_deco("env/boulder_a.png", Vector2(5.5, -17), 1.6)
	_block(Vector2(5.5, -17), 1.0)
	_add_lore("lore_ruins", Vector2(-0.8, -16.8), "spiral", [
		"Uma inscrição gasta pelo tempo:",
		"“Onde ela era o mistério que acolhe, ele era a força que transforma.”",
		"“Onde ela era o potencial adormecido, ele era o impulso que o despertava.”",
	])
	_add_spark("s3", Vector2(-16.2, -28), "“Dos gestos do Deus brotaram as montanhas.”")
	# --- Chama Eterna
	var br := Brazier.new()
	br.world = self
	br.id = "brazier"
	_place(br, Vector2(10.5, -40.5))
	_block(Vector2(10.5, -40.5), 0.7)
	interactables.append(br)
	_deco("env/pillar_broken.png", Vector2(14.5, -36.5), 3.6)
	_block(Vector2(14.5, -36.5), 0.6)
	_deco("env/pillar.png", Vector2(5.5, -44.5), 4.4)
	_block(Vector2(5.5, -44.5), 0.6)
	_deco("env/runestone_flame.png", Vector2(13.5, -42.8), 2.2)
	_block(Vector2(13.5, -42.8), 0.5)
	_add_spark("s4", Vector2(17.2, -45.2), "“E de sua chama acenderam-se as estrelas.”")
	# --- Santuário dos Primeiros: an ancient solid tree beside the arch.
	_hero_trees([[Vector2(12.0, -66.5), 2.3, "gold"]])
	var arch := Props.sprite("env/arch.png", 8.0, true, {"billboard": false, "ground_shade": 0.12})
	_place(arch, Vector2(0, -67))
	_veil = MeshInstance3D.new()
	var vq := QuadMesh.new()
	vq.size = Vector2(8.0 * 0.54, 8.0 * 0.81)
	vq.center_offset = Vector3(0, vq.size.y * 0.5, 0)
	_veil.mesh = vq
	_veil_mat = ShaderMaterial.new()
	_veil_mat.shader = load("res://shaders/veil.gdshader")
	_veil_mat.set_shader_parameter("noise_tex", dapple)
	_veil_mat.set_shader_parameter("strength", 1.0)
	_veil.material_override = _veil_mat
	_place(_veil, Vector2(0, -66.95))
	_gate_glow = Props.glow(Color(1.0, 0.9, 0.7), 9.0, 0.0)
	_place(_gate_glow, Vector2(0, -66.5), 3.5)
	for i in 8:
		var a := PI + PI * (i + 0.5) / 8.0
		var sp := Vector2(cos(a) * 13.5, -55 + sin(a) * 13.5)
		if absf(sp.x) < 3.0:
			continue
		var kinds := ["moon", "flame", "root", "star", "spiral"]
		_deco("env/runestone_%s.png" % kinds[i % 5], sp, 2.2)
	for i in 2:
		var pd := Pedestal.new()
		pd.world = self
		pd.kind = ["moon", "flame"][i]
		pd.id = "pedestal_" + pd.kind
		_place(pd, [Vector2(-5.5, -59), Vector2(5.5, -59)][i])
		_block(Vector2(pd.position.x, pd.position.z), 0.6)
		interactables.append(pd)
		pedestals.append(pd)
	_add_lore("lore_sanctuary", Vector2(-7.5, -50.5), "root", [
		"As palavras brilham fracamente sob o musgo:",
		"“Nenhum existia acima do outro.”",
		"“Que a Lua e a Chama despertem juntas — ou nenhuma permanecerá acesa.”",
	])
	_add_reactive(Vector2(-9.5, -61.5), Color(0.45, 0.95, 1.0), 1.4, "env/mushrooms_glow.png", 0.7)
	_add_reactive(Vector2(8.5, -52.0), Color(1.0, 0.75, 0.4), 1.4, "env/mushrooms_glow.png", 0.6)
	_add_spark("s5", Vector2(-15.2, -62.2), "“E, em cada coisa criada, depositaram uma centelha de sua essência.”")
	# The forest itself, grown last so it respects every landmark above.
	_grow_forest(Rect2(terrain.world_min, terrain.world_size), _palette)

func _build_ambient_fx() -> void:
	_add_shafts([Vector2(2, 50), Vector2(-4, 54), Vector2(1, 38), Vector2(13, 39), Vector2(-7, 22), Vector2(-11, 19), Vector2(2, 6), Vector2(-3, -20), Vector2(-7, -26), Vector2(9, -39), Vector2(-2, -54), Vector2(4, -57), Vector2(0, -64)])
	_add_fireflies([[Vector2(0, 52), 9.0], [Vector2(13, 39), 4.0], [Vector2(-9, 21), 6.0], [Vector2(-4, -23), 8.0], [Vector2(0, -56), 11.0], [Vector2(0, 20), 6.0]])
	_add_mist([Vector2(0, 36), Vector2(-2, 14), Vector2(-2, -8), Vector2(2, -33), Vector2(0, -47), Vector2(0, -72)])
	super._build_ambient_fx()

# ---------------------------------------------------------------- state
func apply_state() -> void:
	player.max_mana = 60.0 + 8.0 * Game.spark_count()
	player.magic_unlocked = Game.flag("pool_done")
	player.essence = String(Game.state.get("essence", ""))
	for l in lanterns:
		l.set_lit(Game.flag(l.id), true)
	if Game.flag("lanterns_done"):
		_open_roots(true)
	if Game.flag("altars_done"):
		_open_gate(true)
		for pd in pedestals:
			pd.lit = true
			pd.locked = true
			pd.set_lit(true)
	place_at_checkpoint()
	_refresh_objective()

func stage() -> String:
	if not Game.flag("woke"):
		return "wake"
	if not Game.flag("pool_done"):
		return "pool"
	if not Game.flag("lanterns_done"):
		return "lanterns"
	if not Game.flag("ruins_clear"):
		return "ruins"
	if not Game.flag("flame_done"):
		return "brazier"
	if not Game.flag("sanctuary_clear"):
		return "sanctuary"
	if not Game.flag("altars_done"):
		return "altars"
	return "gate"

## Objectives are Asterion's own impressions, not instructions.
func _refresh_objective() -> void:
	var text := ""
	var route: Array = []
	match stage():
		"wake", "pool":
			text = "Uma luz se afasta entre as árvores..."
			route = [Vector2(0, 46), Vector2(1.8, 40), Vector2(-1, 32), Vector2(-4.5, 24), Vector2(-7.5, 22.5)]
		"lanterns":
			text = "Raízes fecham a trilha. As lanternas estão frias."
			route = [Vector2(-3, 18), Vector2(-0.5, 12), Vector2(0, 7)]
		"ruins":
			if _shade_wave == "ruins":
				text = "Sombras entre as pedras."
			else:
				text = "A trilha segue entre ruínas."
				route = [Vector2(0, -1), Vector2(-0.5, -7), Vector2(-3, -14), Vector2(-4, -20)]
		"brazier":
			text = "Um calor vem do leste."
			route = [Vector2(-1.5, -26), Vector2(1, -31), Vector2(5, -35), Vector2(8.5, -38.5)]
		"sanctuary":
			if _shade_wave == "sanctuary":
				text = "Sombras cercam o santuário."
			else:
				text = "Algo antigo espera adiante."
				route = [Vector2(5, -41), Vector2(2.5, -45), Vector2(0, -50)]
		"altars":
			text = "A Lua e a Chama."
		"gate":
			text = "O portal está aberto."
			route = [Vector2(0, -60), Vector2(0, -66), Vector2(0, -71)]
	objective_changed.emit(text)
	if route.is_empty():
		guide.clear()
	else:
		guide.set_route(route, terrain, player.global_position)
	hud_changed.emit()

func _update_triggers(_delta: float) -> void:
	var pp := Vector2(player.global_position.x, player.global_position.z)
	var st := stage()
	if not _ring_done and pp.distance_to(Vector2(13, 39)) < 2.2:
		_ring_done = true
		Audio.sfx("essence_moon", -6.0)
		Props.burst(self, _at(Vector2(13, 39), 0.4), Color(0.6, 1.0, 1.0), 60, 3.0, 0.35, 2.0)
		_say_once("ring", ["Elas... acendem quando eu chego perto.", "É como se a floresta soubesse que estou aqui."])
	if st == "lanterns" and pp.distance_to(Vector2(0, 5)) < 7.5:
		_say_once("roots", ["Raízes fecham o caminho...", "E essas lanternas — frias, como se esperassem alguma coisa."])
	if st == "ruins" and _shade_wave == "" and pp.distance_to(Vector2(-4, -23)) < 7.0:
		_spawn_wave("ruins", [Vector2(-7, -26), Vector2(0, -27), Vector2(-4, -30)])
		say(["Sombras... elas recuam da luz das minhas mãos."])
	if st == "sanctuary" and _shade_wave == "" and pp.distance_to(Vector2(0, -55)) < 8.5:
		say(["Que lugar é este? Parece mais antigo que a própria floresta."])
		_spawn_wave("sanctuary", [Vector2(-6, -57), Vector2(6, -56), Vector2(0, -61), Vector2(-2, -52)])
	if st == "altars":
		_say_once("altars", ["Um altar traz o sinal da Lua. O outro, o da Chama.", "As mesmas duas forças que sinto em mim."])
	if st == "gate" and _end_timer < 0.0 and pp.y < -69.0:
		_end_timer = 0.0
		_cross_portal()

# ---------------------------------------------------------------- story beats
func begin_new_game() -> void:
	mode = "cutscene"
	_scripted = true
	cam_rig.cinematic = false
	player.start_kneeling(2.6)
	Audio.sfx("wake", -6.0)
	await wait(4.0)
	Game.set_flag("woke")
	checkpoint("clearing")
	await speak(["...", "Onde... estou?", "Não me lembro de nada. Nem de como cheguei aqui.", "Aquela luz entre as árvores... parece me chamar."])
	_scripted = false
	mode = "play"
	_refresh_objective()

func on_pool_touched(pool: MoonPool) -> void:
	Audio.sfx("pool", -3.0)
	Props.burst(self, pool.global_position + Vector3(0, 0.6, 0), Color(0.5, 0.95, 1.0), 50, 4.0, 0.4, 1.4)
	if not Game.flag("pool_done"):
		Game.set_flag("pool_done")
		player.magic_unlocked = true
		player.essence = "moon"
		player.mana = player.max_mana
		mode = "cutscene"
		say(["A água está morna... e brilha como se tivesse luz própria.", "Minhas mãos... estão brilhando.", "Essa luz... parece querer sair de mim."])
		checkpoint("pool")
		_refresh_objective()
	else:
		player.essence = "moon" if not Game.flag("flame_done") else player.essence
		player.heal(100)
		player.restore_mana(100)
	hud_changed.emit()

func on_lantern_lit(_l: StoneLantern) -> void:
	Game.set_flag(_l.id)
	var lit := lanterns.filter(func(x): return x.lit).size()
	if lit == 1:
		_say_once("first_lantern", ["Ela acendeu... com a luz das minhas mãos."])
	if lit >= 3 and not Game.flag("lanterns_done"):
		Game.set_flag("lanterns_done")
		mode = "cutscene"
		cam_rig.shake(0.5)
		Audio.sfx("gate", -6.0)
		await wait(0.6)
		_open_roots(false)
		await wait(1.6)
		say(["As raízes recuaram... como se tivessem me ouvido."])
		checkpoint("lanterns")
	_refresh_objective()

func _open_roots(instant: bool) -> void:
	terrain.remove_obstacles("roots")
	if instant:
		_roots.visible = false
		return
	Props.burst(self, _roots.global_position + Vector3(0, 1.5, 0), Color(0.6, 1.0, 0.6), 60, 5.0, 0.45, 1.5)
	var tw := create_tween()
	tw.tween_property(_roots, "scale", Vector3(1.2, 0.02, 1.2), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _roots.visible = false)

func _on_shade_defeated(_s: Shade) -> void:
	var alive := _alive_shades()
	_refresh_objective()
	if alive > 0:
		return
	var wave := _shade_wave
	_shade_wave = ""
	shades.clear()
	if wave == "ruins" and not Game.flag("ruins_clear"):
		Game.set_flag("ruins_clear")
		checkpoint("ruins")
		say(["Elas se desfizeram na luz.", "Há um calor vindo do leste... uma chama?"])
	elif wave == "sanctuary" and not Game.flag("sanctuary_clear"):
		Game.set_flag("sanctuary_clear")
		checkpoint("sanctuary")
	_refresh_objective()

func on_brazier_touched(b: Brazier) -> void:
	Audio.sfx("essence_flame", -2.0)
	Props.burst(self, b.global_position + Vector3(0, 1.6, 0), Color(1.0, 0.7, 0.3), 50, 4.0, 0.45, 1.4)
	if not Game.flag("flame_done"):
		Game.set_flag("flame_done")
		player.essence = "flame"
		player.mana = player.max_mana
		mode = "cutscene"
		say(["A chama não queima. Ela... dança comigo.", "Agora sinto duas forças. Uma serena, como a água sob a Lua.", "A outra é viva, inquieta, como o fogo."])
		checkpoint("brazier")
		_refresh_objective()
	else:
		player.essence = "flame"
		player.restore_mana(100)
	hud_changed.emit()

func on_pedestal_lit(_p: Pedestal) -> void:
	var all_lit := pedestals.all(func(x): return x.lit)
	if all_lit and not Game.flag("altars_done"):
		Game.set_flag("altars_done")
		for x in pedestals:
			x.locked = true
		mode = "cutscene"
		await wait(0.8)
		say(["Lua e Chama... juntas.", "O portal... está se abrindo."])
		_open_gate(false)
		checkpoint("sanctuary")
		_refresh_objective()

func on_pedestal_rejected(_p: Pedestal, essence: String) -> void:
	if essence == "":
		return
	_say_once("reject", ["Não respondeu.", "O sinal na pedra... tem a cor de outra força."])

func on_pedestal_faded(_p: Pedestal) -> void:
	_say_once("faded", ["A luz se apagou...", "Sozinha, uma não permanece."])

func _open_gate(instant: bool) -> void:
	terrain.remove_obstacles("veil")
	if instant:
		_veil.visible = false
		_gate_glow.material_override.set_shader_parameter("energy", 0.35)
		return
	Audio.sfx("gate", 0.0)
	cam_rig.shake(1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_veil_mat, "shader_parameter/strength", 3.0, 0.8)
	tw.tween_property(_gate_glow.material_override, "shader_parameter/energy", 0.9, 1.2)
	tw.chain().tween_property(_veil_mat, "shader_parameter/strength", 0.0, 2.0)
	tw.chain().tween_callback(func(): _veil.visible = false)
	Props.burst(self, _veil.global_position + Vector3(0, 3, 0), Color(1.0, 0.9, 0.7), 80, 6.0, 0.5, 1.8)

## Crossing the arch ends the chapter; the memory plays before the valley.
func _cross_portal() -> void:
	mode = "cutscene"
	_scripted = true
	Audio.sfx("gate", -4.0)
	Props.burst(self, player.global_position + Vector3(0, 1.2, 0), Color(1.0, 0.95, 0.85), 60, 4.0, 0.4, 1.5)
	Game.set_flag("chapter_done")
	Game.save_game()
	portal_crossed.emit()
