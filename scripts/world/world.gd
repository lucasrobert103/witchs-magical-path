class_name World
extends Node3D
## Chapter I — O Despertar. Builds the painted forest, runs the story beats,
## enemies, interactions, checkpoints and the guide light.

signal objective_changed(text: String)
signal dialogue_requested(lines: Array)
signal toast_requested(text: String, icon: String)
signal area_entered(title: String, subtitle: String)
signal prompt_changed(text: String, icon: String)
signal fade_requested(to_black: bool, duration: float)
signal chapter_completed(stats: Dictionary)
signal hud_changed

const AUTUMN_TREES := ["env/tree_autumn_a.png", "env/tree_autumn_b.png"]
const GREEN_TREES := ["env/tree_green_a.png", "env/tree_green_b.png", "env/tree_teal.png"]

const CHECKPOINTS := {
	"clearing": [Vector2(0, 51), Vector2(0, -1)],
	"pool": [Vector2(-5.5, 21.5), Vector2(0.3, -1)],
	"lanterns": [Vector2(0, 0.5), Vector2(0, -1)],
	"ruins": [Vector2(-3, -21), Vector2(0.3, -1)],
	"brazier": [Vector2(8, -37), Vector2(-0.4, -1)],
	"sanctuary": [Vector2(0, -49), Vector2(0, -1)],
}

const ZONES := [
	{"id": "clearing", "p": Vector2(0, 52), "r": 9.0, "title": "Clareira do Despertar", "sub": "Floresta de Asterion"},
	{"id": "pool", "p": Vector2(-9, 21), "r": 5.5, "title": "Fonte da Lua", "sub": "Onde a água guarda a luz"},
	{"id": "lanterns", "p": Vector2(0, 5), "r": 7.0, "title": "Trilha das Lanternas", "sub": ""},
	{"id": "ruins", "p": Vector2(-4, -23), "r": 8.0, "title": "Ruínas Esquecidas", "sub": "Pedras que ainda se lembram"},
	{"id": "brazier", "p": Vector2(9, -39), "r": 5.5, "title": "Chama Eterna", "sub": ""},
	{"id": "sanctuary", "p": Vector2(0, -55), "r": 10.0, "title": "Santuário dos Primeiros", "sub": "Lua e Chama"},
]

var terrain: Terrain
var player: Player
var cam_rig: CameraRig
var guide: Guide
var dapple: NoiseTexture2D
var env: Environment
var mode := "title"            # title, play, cutscene
var interactables: Array = []
var shades: Array = []
var lanterns: Array = []
var pedestals: Array = []
var sparks: Array = []
var _roots: Node3D
var _veil: MeshInstance3D
var _veil_mat: ShaderMaterial
var _gate_glow: MeshInstance3D
var _focus_target: Interactable
var _current_zone := ""
var _visited_zones := {}
var _said := {}
var _title_t := 0.0
var _shade_wave := ""
var _shade_total := 0
var _death_timer := -1.0
var _end_timer := -1.0
var _prompt_text := ""
var _leaves: CPUParticles3D
var _quality := 1

func _ready() -> void:
	_quality = int(Game.settings.get("quality", 1))
	dapple = NoiseTexture2D.new()
	dapple.width = 256
	dapple.height = 256
	dapple.seamless = true
	dapple.generate_mipmaps = true
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 3
	dapple.noise = n
	_build_environment()
	_build_layout()
	_build_ground()
	_build_forest()
	_build_landmarks()
	_build_ambient_fx()
	_spawn_actors()
	apply_state()

# ---------------------------------------------------------------- building
func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.6)
	env.fog_enabled = true
	env.fog_light_color = Color(0.56, 0.66, 0.6)
	env.fog_density = 0.03
	env.fog_sky_affect = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = _quality > 0
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _build_layout() -> void:
	terrain = Terrain.new()
	add_child(terrain)
	var T := terrain
	T.add_circle_area(Vector2(0, 52), 10.5)
	T.add_path([Vector2(0, 52), Vector2(2.5, 42), Vector2(-0.5, 32), Vector2(-2.5, 22), Vector2(0, 12), Vector2(0, 5)], 4.2, 1.5)
	T.add_area(Vector2(0, 52), Vector2(-11, 58), 2.2)
	T.add_circle_area(Vector2(-11.5, 58.5), 2.6)
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
	# Obstacles.
	T.add_obstacle(Vector2(-4.8, -2.5), Vector2(4.8, -2.5), 0.8, 99.0, "roots")
	T.add_obstacle(Vector2(-3.2, -67), Vector2(3.2, -67), 0.5, 99.0, "veil")
	T.add_obstacle(Vector2(-10.5, -28.8), Vector2(-10.5, -21.8), 0.45, 0.75, "log")
	for p in [Vector2(-3.7, -67), Vector2(3.7, -67)]:
		T.add_obstacle(p, p, 1.0)
	T.build_mask()

func _build_ground() -> void:
	var tex := {
		"grass_tex": Props.tex("res://assets/textures/ground_grass.png"),
		"moss_tex": Props.tex("res://assets/textures/ground_moss.png"),
		"dirt_tex": Props.tex("res://assets/textures/ground_dirt.png"),
		"path_tex": Props.tex("res://assets/textures/path_stones.png"),
	}
	terrain.build_ground(tex, dapple)

func _h(p: Vector2) -> float:
	return terrain.height(p.x, p.y)

func _at(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, _h(p) + lift, p.y)

func _place(node: Node3D, p: Vector2, lift := 0.0) -> Node3D:
	add_child(node)
	node.position = _at(p, lift)
	return node

func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tree_items := {}
	for t in AUTUMN_TREES + GREEN_TREES:
		tree_items[t] = []
	var far_items := {"env/far_tree_a.png": [], "env/far_tree_b.png": []}
	var spacing := 4.3 if _quality > 0 else 5.6
	var x := terrain.world_min.x
	while x < terrain.world_min.x + terrain.world_size.x:
		var z := terrain.world_min.y
		while z < terrain.world_min.y + terrain.world_size.y:
			var p := Vector2(x + rng.randf_range(-1.6, 1.6), z + rng.randf_range(-1.6, 1.6))
			var sd := terrain.walk_sd(p)
			if sd > 2.3 and sd < 24.0:
				var region := sin(p.x * 0.09 + p.y * 0.05) + rng.randf_range(-0.6, 0.6)
				var list: Array = AUTUMN_TREES if region > -0.1 else GREEN_TREES
				var tex: String = list[rng.randi() % list.size()]
				var s := rng.randf_range(0.85, 1.25) * (1.15 if sd < 6.0 else 1.0)
				tree_items[tex].append([_at(p, -0.15), s])
			elif sd >= 24.0 and sd < 40.0 and rng.randf() < 0.5:
				var ftex := "env/far_tree_a.png" if rng.randf() < 0.5 else "env/far_tree_b.png"
				far_items[ftex].append([_at(p, -0.5), rng.randf_range(1.6, 2.4)])
			z += spacing
		x += spacing
	for t in tree_items.keys():
		if tree_items[t].size() > 0:
			add_child(Props.scatter(t, 10.5, tree_items[t], {"sway": 0.16, "ground_shade": 0.12, "top_light": 0.12}))
	for t in far_items.keys():
		if far_items[t].size() > 0:
			add_child(Props.scatter(t, 9.0, far_items[t], {"tint": Color(0.2, 0.32, 0.3), "ground_shade": 0.0, "sway": 0.05}))
	# Undergrowth along the edges and grass inside the walkable space.
	var under := {"env/bush_green.png": [], "env/bush_autumn.png": [], "env/fern.png": [], "env/fern_autumn.png": [], "env/boulder_b.png": [], "env/mushrooms_orange.png": []}
	var grass := {"env/grass_a.png": [], "env/grass_b.png": [], "env/grass_c.png": []}
	var count := 2600 if _quality > 0 else 1100
	for i in count:
		var p := Vector2(rng.randf_range(-48, 48), rng.randf_range(-86, 74))
		var sd := terrain.walk_sd(p)
		if sd > -0.3 and sd < 5.0:
			var keys := under.keys()
			var k: String = keys[rng.randi() % keys.size()]
			if k == "env/boulder_b.png" and rng.randf() < 0.6:
				continue
			under[k].append([_at(p, -0.05), rng.randf_range(0.7, 1.3)])
		elif sd < -0.4 and terrain.path_dist(p) > 0.4:
			var gk: String = grass.keys()[0 if rng.randf() < 0.6 else (1 if rng.randf() < 0.6 else 2)]
			grass[gk].append([_at(p, -0.02), rng.randf_range(0.7, 1.25)])
	var heights := {"env/bush_green.png": 1.5, "env/bush_autumn.png": 1.4, "env/fern.png": 1.2, "env/fern_autumn.png": 1.1, "env/boulder_b.png": 1.0, "env/mushrooms_orange.png": 0.55}
	for k in under.keys():
		if under[k].size() > 0:
			add_child(Props.scatter(k, heights[k], under[k], {"sway": 0.06 if not k.contains("boulder") else 0.0, "ground_shade": 0.3}))
	for k in grass.keys():
		if grass[k].size() > 0:
			add_child(Props.scatter(k, 0.6, grass[k], {"sway": 0.08, "sway_speed": 2.0, "ground_shade": 0.5}))

func _deco(path: String, p: Vector2, height: float, soft := true, params := {}) -> MeshInstance3D:
	var s := Props.sprite(path, height, soft, params)
	_place(s, p)
	return s

func _block(p: Vector2, r: float) -> void:
	terrain.add_obstacle(p, p, r)

func _build_landmarks() -> void:
	# --- Clareira do Despertar
	_deco("env/tree_autumn_a.png", Vector2(7.5, 48.5), 12.0, false, {"sway": 0.12, "top_light": 0.15})
	_block(Vector2(7.5, 48.5), 1.0)
	_deco("env/tree_green_a.png", Vector2(-8.5, 47), 11.0, false, {"sway": 0.12})
	_block(Vector2(-8.5, 47), 1.0)
	_deco("env/tree_autumn_b.png", Vector2(-6.5, 57.5), 11.5, false, {"sway": 0.12})
	_block(Vector2(-6.5, 57.5), 0.9)
	_deco("env/bush_autumn.png", Vector2(-9.5, 55.5), 1.8)
	_deco("env/boulder_a.png", Vector2(6.5, 56), 1.5)
	_block(Vector2(6.5, 56), 1.0)
	_deco("env/mushrooms_glow.png", Vector2(5.3, 54.7), 0.6)
	_deco("env/mushrooms_orange.png", Vector2(-3.5, 59.5), 0.6)
	_deco("env/log.png", Vector2(4.5, 60), 1.4)
	_block(Vector2(4.5, 60), 1.2)
	_add_lore("lore_clearing", Vector2(-4.2, 45.5), "star", [
		"Sulcos antigos cobrem a pedra. De algum modo, você consegue lê-los.",
		"“No princípio, não havia céu ou terra.”",
		"“Havia apenas o Infinito.”",
	])
	_add_spark("s1", Vector2(-12, 59), "“Das lágrimas da Deusa surgiram os oceanos.”")
	# --- Fonte da Lua
	var pool := MoonPool.new()
	pool.world = self
	pool.id = "pool"
	_place(pool, Vector2(-9.5, 21.5))
	interactables.append(pool)
	_deco("env/runestone_moon.png", Vector2(-13.8, 24), 2.4)
	_block(Vector2(-13.8, 24), 0.5)
	_deco("env/mushrooms_glow.png", Vector2(-5.5, 25.5), 0.7)
	_deco("env/mushrooms_glow.png", Vector2(-13.5, 18.5), 0.6)
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
	# --- Santuário dos Primeiros
	_deco("env/tree_ancient.png", Vector2(11.5, -66.5), 15.0, false, {"sway": 0.06, "top_light": 0.2})
	_block(Vector2(11.5, -66.5), 2.6)
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
	_deco("env/mushrooms_glow.png", Vector2(-9.5, -61.5), 0.7)
	_deco("env/mushrooms_glow.png", Vector2(8.5, -52.0), 0.6)
	_add_spark("s5", Vector2(-15.2, -62.2), "“E, em cada coisa criada, depositaram uma centelha de sua essência.”")

func _add_lore(id: String, p: Vector2, rune: String, lines: Array) -> void:
	var s := LoreStone.new()
	s.world = self
	s.id = id
	s.rune = rune
	s.lines = lines
	_place(s, p)
	_block(p, 0.5)
	interactables.append(s)

func _add_spark(id: String, p: Vector2, echo: String) -> void:
	if Game.has_spark(id):
		return
	var s := Spark.new()
	s.world = self
	s.id = id
	s.echo = echo
	_place(s, p, 1.1)
	interactables.append(s)
	sparks.append(s)

func _build_ambient_fx() -> void:
	# Light shafts through the canopy.
	var shaft_tex := Props.tex("fx/light_shaft.png")
	var shaft_shader := load("res://shaders/light_shaft.gdshader")
	var spots := [Vector2(2, 50), Vector2(-4, 54), Vector2(1, 38), Vector2(-7, 22), Vector2(-11, 19), Vector2(2, 6), Vector2(-3, -20), Vector2(-7, -26), Vector2(9, -39), Vector2(-2, -54), Vector2(4, -57), Vector2(0, -64)]
	for i in spots.size():
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(randf_range(2.0, 3.6), 16.0)
		q.center_offset = Vector3(0, 8.0, 0)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = shaft_shader
		m.set_shader_parameter("tex", shaft_tex)
		m.set_shader_parameter("energy", randf_range(0.1, 0.2))
		m.set_shader_parameter("slant", 0.32)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_place(mi, spots[i], -0.5)
	# Fireflies and drifting pollen in key places.
	for zone in [[Vector2(0, 52), 9.0], [Vector2(-9, 21), 6.0], [Vector2(-4, -23), 8.0], [Vector2(0, -56), 11.0], [Vector2(0, 20), 6.0]]:
		var ff := Props.particles("fx/soft_dot.png", 26 if _quality > 0 else 12, 6.0, 0.14, Color(1.0, 0.9, 0.55))
		ff.emitting = true
		ff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		ff.emission_box_extents = Vector3(zone[1], 1.5, zone[1])
		ff.spread = 180.0
		ff.initial_velocity_min = 0.1
		ff.initial_velocity_max = 0.35
		ff.gravity = Vector3(0, 0.05, 0)
		ff.preprocess = 6.0
		_place(ff, zone[0], 1.6)
	# Luminous mist patches along the route.
	for p in [Vector2(0, 36), Vector2(-2, 14), Vector2(-2, -8), Vector2(2, -33), Vector2(0, -47), Vector2(0, -72)]:
		var mist := Props.glow(Color(0.75, 0.85, 0.75), 16.0, 0.07)
		mist.material_override.set_shader_parameter("near_fade", 9.0)
		_place(mist, p, 1.5)
	# Falling leaves around the camera.
	_leaves = Props.particles("fx/leaf_orange.png", 36 if _quality > 0 else 14, 7.0, 0.16, Color(1, 1, 1), false)
	_leaves.emitting = true
	_leaves.local_coords = false
	_leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_leaves.emission_box_extents = Vector3(14, 1, 14)
	_leaves.gravity = Vector3(0.25, -0.55, 0)
	_leaves.initial_velocity_min = 0.0
	_leaves.initial_velocity_max = 0.3
	_leaves.angular_velocity_min = -90
	_leaves.angular_velocity_max = 90
	_leaves.angle_min = 0
	_leaves.angle_max = 360
	_leaves.preprocess = 7.0
	add_child(_leaves)

func _spawn_actors() -> void:
	player = Player.new()
	player.world = self
	add_child(player)
	player.cast_requested.connect(_on_cast)
	player.died.connect(_on_player_died)
	cam_rig = CameraRig.new()
	add_child(cam_rig)
	guide = Guide.new()
	add_child(guide)

# ---------------------------------------------------------------- state
## Rebuilds puzzle state from Game.state (new game or continue).
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

func place_at_checkpoint() -> void:
	var cp: Array = CHECKPOINTS.get(String(Game.state.get("checkpoint", "clearing")), CHECKPOINTS["clearing"])
	var p: Vector2 = cp[0]
	var f: Vector2 = cp[1]
	player.global_position = _at(p)
	player.facing = Vector3(f.x, 0, f.y).normalized()
	player.reset_state()
	cam_rig.snap_behind(player.facing)
	_clear_shades()

func checkpoint(id: String) -> void:
	Game.state["checkpoint"] = id
	Game.state["essence"] = player.essence
	Game.save_game()

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

func _refresh_objective() -> void:
	var text := ""
	var route: Array = []
	match stage():
		"wake", "pool":
			text = "Siga a luz até a fonte"
			route = [Vector2(0, 46), Vector2(1.8, 40), Vector2(-1, 32), Vector2(-4.5, 24), Vector2(-7.5, 22.5)]
		"lanterns":
			var lit := lanterns.filter(func(l): return l.lit).size()
			text = "Acenda as lanternas de pedra com magia (%d/3)" % lit
			route = [Vector2(-3, 18), Vector2(-0.5, 12), Vector2(0, 7)]
		"ruins":
			if _shade_wave == "ruins":
				text = "Dissipe as sombras (%d/%d)" % [_shade_total - _alive_shades(), _shade_total]
			else:
				text = "Atravesse as Ruínas Esquecidas"
				route = [Vector2(0, -1), Vector2(-0.5, -7), Vector2(-3, -14), Vector2(-4, -20)]
		"brazier":
			text = "Siga o calor até a Chama Eterna"
			route = [Vector2(-1.5, -26), Vector2(1, -31), Vector2(5, -35), Vector2(8.5, -38.5)]
		"sanctuary":
			if _shade_wave == "sanctuary":
				text = "Dissipe as sombras (%d/%d)" % [_shade_total - _alive_shades(), _shade_total]
			else:
				text = "Siga até o Santuário dos Primeiros"
				route = [Vector2(5, -41), Vector2(2.5, -45), Vector2(0, -50)]
		"altars":
			text = "Desperte juntos os altares da Lua e da Chama"
		"gate":
			text = "Atravesse o portal"
			route = [Vector2(0, -60), Vector2(0, -66), Vector2(0, -71)]
	objective_changed.emit(text)
	if route.is_empty():
		guide.clear()
	else:
		guide.set_route(route, terrain, player.global_position)
	hud_changed.emit()

# ---------------------------------------------------------------- frame update
func _process(delta: float) -> void:
	if mode == "title":
		_title_t += delta
		cam_rig.cinematic = true
		var center := player.global_position + Vector3(0, 1.4, 0)
		var a := 0.35 + sin(_title_t * 0.05) * 0.25
		cam_rig.cine_pos = center + Vector3(sin(a) * 5.5, 0.9, cos(a) * 5.5)
		cam_rig.cine_look = center + Vector3(-1.6, 0.6, -6.0)
		cam_rig.update(delta, player, terrain)
		player.cam_yaw = cam_rig.yaw
		player.control_enabled = false
		player.move_input = Vector2.ZERO
		player.tick(delta)
		guide.tick(delta, player.global_position)
		_update_leaves()
		return
	if mode == "play":
		Game.state["time"] = float(Game.state.get("time", 0.0)) + delta
	player.control_enabled = mode == "play"
	player.cam_yaw = cam_rig.yaw
	player.tick(delta)
	cam_rig.update(delta, player, terrain)
	guide.tick(delta, player.global_position)
	for it in interactables.duplicate():
		if is_instance_valid(it):
			it.tick(delta, player)
	for s in shades.duplicate():
		if is_instance_valid(s):
			s.tick(delta, player)
	_update_leaves()
	if mode == "play":
		_update_focus()
		_update_zones()
		_update_triggers()
	if _death_timer >= 0.0:
		_death_timer -= delta
		if _death_timer < 0.0:
			_respawn()
	if _end_timer >= 0.0:
		_end_timer -= delta
		if _end_timer < 0.0:
			_finish_chapter()

func _update_leaves() -> void:
	_leaves.global_position = cam_rig.cam.global_position + Vector3(0, 6, 0) - cam_rig.cam.global_transform.basis.z * 6.0

func _update_focus() -> void:
	var best: Interactable = null
	var best_d := 1e9
	for it in interactables:
		if not is_instance_valid(it) or not it.can_interact():
			continue
		var d := Vector2(it.global_position.x - player.global_position.x, it.global_position.z - player.global_position.z).length()
		if d < it.radius and d < best_d:
			best = it
			best_d = d
	_focus_target = best
	var text := best.prompt if best else ""
	if text != _prompt_text:
		_prompt_text = text
		prompt_changed.emit(text, best.icon if best else "")

func _update_zones() -> void:
	var pp := Vector2(player.global_position.x, player.global_position.z)
	var zone := ""
	for z in ZONES:
		if pp.distance_to(z["p"]) < z["r"]:
			zone = z["id"]
			if zone != _current_zone and not _visited_zones.has(zone):
				_visited_zones[zone] = true
				area_entered.emit(z["title"], z["sub"])
	_current_zone = zone

func _say_once(key: String, lines: Array) -> void:
	if _said.has(key) or Game.flag("said_" + key):
		return
	_said[key] = true
	Game.set_flag("said_" + key)
	say(lines)

func say(lines: Array) -> void:
	var out: Array = []
	for l in lines:
		if l is Dictionary:
			out.append(l)
		else:
			out.append({"speaker": "Asterion", "text": l, "portrait": true})
	dialogue_requested.emit(out)

func narrate(lines: Array) -> void:
	var out: Array = []
	for l in lines:
		out.append({"speaker": "", "text": l, "portrait": false})
	dialogue_requested.emit(out)

func _update_triggers() -> void:
	var pp := Vector2(player.global_position.x, player.global_position.z)
	var st := stage()
	if st == "lanterns" and pp.distance_to(Vector2(0, 5)) < 7.5:
		_say_once("roots", ["Raízes fecham o caminho...", "Essas lanternas de pedra... Talvez a luz possa despertá-las."])
	if st == "ruins" and _shade_wave == "" and pp.distance_to(Vector2(-4, -23)) < 7.0:
		_spawn_wave("ruins", [Vector2(-7, -26), Vector2(0, -27), Vector2(-4, -30)])
		say(["Sombras! Elas não pertencem a este lugar."])
	if st == "sanctuary" and _shade_wave == "" and pp.distance_to(Vector2(0, -55)) < 8.5:
		say(["Que lugar é este? Parece mais antigo que a própria floresta."])
		_spawn_wave("sanctuary", [Vector2(-6, -57), Vector2(6, -56), Vector2(0, -61), Vector2(-2, -52)])
	if st == "gate" and _end_timer < 0.0 and pp.y < -69.0:
		_end_timer = 0.1
		mode = "cutscene"

# ---------------------------------------------------------------- input from UI
func do_interact() -> void:
	if mode != "play" or not is_instance_valid(_focus_target):
		return
	_focus_target.interact()

func do_cast() -> void:
	if mode != "play":
		return
	if player.request_cast():
		Audio.sfx("cast", -5.0)

func do_jump() -> void:
	if mode == "play":
		player.request_jump()

func do_swap_essence() -> void:
	if mode != "play" or not Game.flag("flame_done"):
		return
	player.essence = "flame" if player.essence == "moon" else "moon"
	Game.state["essence"] = player.essence
	Audio.sfx("essence_" + player.essence, -8.0)
	Props.burst(self, player.global_position + Vector3(0, 1.2, 0), player.essence_color(), 18, 2.0, 0.3)
	hud_changed.emit()

# ---------------------------------------------------------------- magic
func find_magic_target(origin: Vector3, facing: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score := 1e9
	var candidates: Array = []
	for s in shades:
		if is_instance_valid(s) and not s.dying:
			candidates.append(s)
	for it in interactables:
		if is_instance_valid(it) and it.accepts_magic():
			candidates.append(it)
	for c in candidates:
		var to: Vector3 = c.global_position - origin
		to.y = 0
		var d := to.length()
		if d > 15.0 or d < 0.2:
			continue
		var ang := facing.angle_to(to / d)
		if ang > deg_to_rad(65.0) and d > 3.0:
			continue
		var score := d + ang * 6.0 - (4.0 if c is Shade else 0.0)
		if score < best_score:
			best_score = score
			best = c
	return best

func _on_cast(origin: Vector3, dir: Vector3) -> void:
	var b := Bolt.new()
	b.setup(self, origin, dir, find_magic_target(player.global_position, dir), player.essence, player.essence_color())
	add_child(b)

func bolt_probe(pos: Vector3) -> Node3D:
	for s in shades:
		if is_instance_valid(s) and not s.dying and s.global_position.distance_to(pos - Vector3(0, 1.0, 0)) < 0.9:
			return s
	return null

func on_bolt_hit(node: Node3D, essence: String, pos: Vector3) -> void:
	if not is_instance_valid(node):
		return
	if node is Shade:
		node.on_magic(essence, player.global_position)
	elif node is Interactable:
		node.on_magic(essence, pos)

# ---------------------------------------------------------------- story beats
func begin_new_game() -> void:
	mode = "cutscene"
	cam_rig.cinematic = false
	player.start_kneeling(2.0)
	Audio.sfx("wake", -6.0)
	await get_tree().create_timer(3.4).timeout
	Game.set_flag("woke")
	checkpoint("clearing")
	say(["...", "Onde... estou?", "Não me lembro de nada. Nem do meu próprio passado.", "Aquela luz... parece estar me chamando."])
	_refresh_objective()

func begin_play() -> void:
	mode = "play"
	cam_rig.cinematic = false
	_refresh_objective()

func on_dialogue_finished() -> void:
	if mode == "cutscene" and _end_timer < 0.0 and _death_timer < 0.0:
		mode = "play"

func on_pool_touched(pool: MoonPool) -> void:
	Audio.sfx("pool", -3.0)
	Props.burst(self, pool.global_position + Vector3(0, 0.6, 0), Color(0.5, 0.95, 1.0), 50, 4.0, 0.4, 1.4)
	if not Game.flag("pool_done"):
		Game.set_flag("pool_done")
		player.magic_unlocked = true
		player.essence = "moon"
		player.mana = player.max_mana
		mode = "cutscene"
		say(["A água está morna... e brilha como se tivesse luz própria.", "Minhas mãos... estão brilhando.", "Que força é essa? Parece... antiga. E, ao mesmo tempo, minha."])
		toast_requested.emit("Nova habilidade: Magia — toque ✦ para lançar", "magic")
		checkpoint("pool")
		_refresh_objective()
	else:
		player.essence = "moon" if not Game.flag("flame_done") else player.essence
		player.heal(100)
		player.restore_mana(100)
		toast_requested.emit("A água renova suas forças", "moon")
	hud_changed.emit()

func on_lantern_lit(l: StoneLantern) -> void:
	Game.set_flag(l.id)
	var lit := lanterns.filter(func(x): return x.lit).size()
	if lit >= 3 and not Game.flag("lanterns_done"):
		Game.set_flag("lanterns_done")
		mode = "cutscene"
		cam_rig.shake(0.5)
		Audio.sfx("gate", -6.0)
		await get_tree().create_timer(0.6).timeout
		_open_roots(false)
		await get_tree().create_timer(1.6).timeout
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

func _spawn_wave(wave: String, homes: Array) -> void:
	_shade_wave = wave
	_shade_total = homes.size()
	for h in homes:
		var s := Shade.new()
		s.world = self
		add_child(s)
		s.global_position = _at(h, 0.15)
		s.home = s.global_position
		s.defeated.connect(_on_shade_defeated)
		shades.append(s)
		Props.burst(self, s.global_position + Vector3(0, 1, 0), Color(0.5, 0.3, 0.8), 20, 2.0, 0.4)
	Audio.play_music("res://assets/audio/music_forest.ogg", 1.0, -2.0)
	_refresh_objective()

func _alive_shades() -> int:
	return shades.filter(func(s): return is_instance_valid(s) and not s.dying).size()

func _clear_shades() -> void:
	for s in shades:
		if is_instance_valid(s):
			s.queue_free()
	shades.clear()
	_shade_wave = ""

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
		say(["Elas se desfizeram na luz.", "Há um calor vindo do leste... Uma chama?"])
	elif wave == "sanctuary" and not Game.flag("sanctuary_clear"):
		Game.set_flag("sanctuary_clear")
		checkpoint("sanctuary")
		say(["Os altares... Um traz o sinal da Lua. O outro, o da Chama."])
	_refresh_objective()

func on_brazier_touched(b: Brazier) -> void:
	Audio.sfx("essence_flame", -2.0)
	Props.burst(self, b.global_position + Vector3(0, 1.6, 0), Color(1.0, 0.7, 0.3), 50, 4.0, 0.45, 1.4)
	if not Game.flag("flame_done"):
		Game.set_flag("flame_done")
		player.essence = "flame"
		player.mana = player.max_mana
		mode = "cutscene"
		say(["A chama não queima. Ela... dança comigo.", "Sinto duas forças agora. Uma serena, como a água sob a Lua.", "A outra é viva, inquieta, como o fogo."])
		toast_requested.emit("Nova habilidade: trocar essência — Lua ↔ Chama", "flame")
		checkpoint("brazier")
		_refresh_objective()
	else:
		player.essence = "flame"
		player.restore_mana(100)
	hud_changed.emit()

func on_pedestal_lit(p: Pedestal) -> void:
	var all_lit := pedestals.all(func(x): return x.lit)
	if all_lit and not Game.flag("altars_done"):
		Game.set_flag("altars_done")
		for x in pedestals:
			x.locked = true
		mode = "cutscene"
		await get_tree().create_timer(0.8).timeout
		say(["Lua e Chama... juntas.", "O portal... está se abrindo."])
		_open_gate(false)
		checkpoint("sanctuary")
		_refresh_objective()
	elif not all_lit:
		toast_requested.emit("O altar %s despertou... por enquanto" % ("da Lua" if p.kind == "moon" else "da Chama"), p.kind)

func on_pedestal_rejected(_p: Pedestal, essence: String) -> void:
	if essence == "":
		return
	_say_once("reject", ["Não respondeu. Talvez precise de outra essência."])
	if Game.flag("said_reject"):
		toast_requested.emit("Use a essência do símbolo do altar", "interact")

func on_pedestal_faded(_p: Pedestal) -> void:
	toast_requested.emit("A luz do altar se apagou — os dois precisam despertar juntos", "spark")

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

func on_spark_collected(s: Spark) -> void:
	Game.add_spark(s.id)
	sparks.erase(s)
	interactables.erase(s)
	player.max_mana = 60.0 + 8.0 * Game.spark_count()
	player.mana = player.max_mana
	player.heal(100)
	Audio.sfx("pickup", -2.0)
	toast_requested.emit("Centelha encontrada  %d/%d" % [Game.spark_count(), Game.TOTAL_SPARKS], "spark")
	narrate([s.echo])
	Game.save_game()
	hud_changed.emit()

func show_lore(stone: LoreStone) -> void:
	Audio.sfx("open", -6.0)
	narrate(stone.lines)

# ---------------------------------------------------------------- death & ending
func _on_player_died() -> void:
	mode = "cutscene"
	_death_timer = 1.6
	fade_requested.emit(true, 1.2)

func _respawn() -> void:
	place_at_checkpoint()
	mode = "play"
	fade_requested.emit(false, 1.0)
	toast_requested.emit("Asterion se reergue...", "moon")
	_refresh_objective()

func _finish_chapter() -> void:
	Game.set_flag("chapter_done")
	Game.save_game()
	say(["Eu ainda não sei quem sou, nem de onde vim.", "Mas, pela primeira vez, sinto que este caminho é meu."])
	await dialogue_closed_or_timeout(14.0)
	Audio.sfx("victory", -2.0)
	chapter_completed.emit({"sparks": Game.spark_count(), "time": float(Game.state.get("time", 0.0))})

var _dialogue_open := false
func set_dialogue_open(v: bool) -> void:
	_dialogue_open = v

func dialogue_closed_or_timeout(t: float) -> void:
	await get_tree().process_frame
	while _dialogue_open and t > 0.0:
		await get_tree().process_frame
		t -= get_process_delta_time()
