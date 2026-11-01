class_name ValleyWorld
extends BaseWorld
## Capítulo II — Um lugar para ficar (Vale do Rio).
## Arrival on the ridge beyond the portal, the descent into the valley, and the first
## mission: find the clearing, gather branches for a shelter, plant the first seeds
## and discover that the river water follows her hand. Ends on the first night.

const RIVER := [Vector2(-70, -26), Vector2(-40, -21), Vector2(-14, -18), Vector2(4, -16), Vector2(16, -20), Vector2(30, -17), Vector2(52, -23), Vector2(80, -30)]
const HOME := Vector2(10, -3)
const SHELTER := Vector2(14.5, 0.5)
const PLOT := Vector2(7.0, -6.5)
const PLANT := Vector2(-3.5, 3.5)
const BRANCH_SPOTS := [Vector2(-9.5, 20.5), Vector2(-2.0, 7.5), Vector2(16.5, 7.0), Vector2(20.5, -8.0), Vector2(1.5, -10.0), Vector2(-4.5, -5.0), Vector2(11.5, 8.5)]
const OBSERVE := {
	"water": [Vector2(9.0, -12.0), ["O rio está bem aqui...", "Água limpa. Dá para ouvir de qualquer canto da clareira."]],
	"ground": [Vector2(15.5, -5.0), ["O chão é firme. Não se desfaz sob os pés."]],
	"light": [Vector2(9.5, -1.5), ["A luz ainda chega até aqui, mesmo com o sol baixando."]],
}

const CHECKPOINTS := {
	"arrival": [Vector2(-20, 46.5), Vector2(0.15, -1)],
	"valley": [Vector2(-2, 9), Vector2(0.5, -1)],
	"clearing": [Vector2(10, 2), Vector2(0, -1)],
}

const ZONES := [
	{"id": "ridge", "p": Vector2(-18, 40), "r": 6.0, "title": "Vale do Rio", "sub": "Primeiro Continente"},
	{"id": "home", "p": HOME, "r": 7.0, "title": "Clareira do Rio", "sub": ""},
]

var branches: Array = []
var _plot_strips: Array = []
var _plot_base: MeshInstance3D
var _shelter: Node3D
var _plant: Spot
var _plot: Spot
var _river_spots: Array = []
var _stars: MultiMeshInstance3D
var _moon: MeshInstance3D
var _night_flies: Array = []
var _arch_glow: MeshInstance3D
var _observed := {}

func _checkpoints() -> Dictionary:
	return CHECKPOINTS

func _zones() -> Array:
	return ZONES

func _relief(x: float, z: float) -> float:
	var ridge := 9.0 * smoothstep(10.0, 46.0, z)
	var sides := 5.0 * smoothstep(24.0, 56.0, absf(x - 4.0))
	var north := 4.0 * smoothstep(-24.0, -60.0, z) * (0.6 + 0.4 * sin(x * 0.07))
	return ridge + sides + north

func _build_environment(_fog := Color(), _density := 0.0) -> void:
	super._build_environment(Color(0.86, 0.78, 0.68), 0.008)
	sky_mat.set_shader_parameter("top", Color(0.32, 0.45, 0.62))
	sky_mat.set_shader_parameter("horizon", Color(0.96, 0.8, 0.6))
	sky_mat.set_shader_parameter("sun_dir", Vector3(-0.75, 0.18, -0.45))
	sky_mat.set_shader_parameter("sun_color", Color(1.0, 0.8, 0.5))
	set_world_light(Color(1.0, 0.93, 0.83), 0.0)

# ---------------------------------------------------------------- layout
func _build_layout() -> void:
	var T := terrain
	T.world_min = Vector2(-62, -72)
	T.world_size = Vector2(124, 134)
	T.base_height = _relief
	T.bank_height = 2.0
	T.river = RIVER
	T.river_width = 2.8
	T.river_depth = 1.5
	# Ridge where the portal opens, and the trail down into the valley.
	T.add_circle_area(Vector2(-20, 46), 6.0)
	T.add_path([Vector2(-20, 46), Vector2(-17, 38), Vector2(-12, 28), Vector2(-7, 18), Vector2(-2, 9), Vector2(4, 2), HOME], 3.6, 1.3)
	# Valley meadow, the clearing by the river bend, and the river bank.
	T.add_circle_area(Vector2(4, 1), 13.0)
	T.add_circle_area(HOME, 8.5)
	T.add_area(Vector2(-10, -10), Vector2(24, -12), 3.4)
	# The river bed is part of the painted mask (no banks) but blocked for walking.
	for i in RIVER.size() - 1:
		T.add_area(RIVER[i], RIVER[i + 1], T.river_width)
		T.add_obstacle(RIVER[i], RIVER[i + 1], T.river_width - 0.2)

## Keeps the slope below the portal and the valley floor open, so the vista reads.
func _tree_density(p: Vector2) -> float:
	if p.y > 41.0 or p.y < -24.0:
		return 1.0
	if absf(p.x - 2.0) > 40.0:
		return 1.0
	# Leave the line of sight from the portal to the river completely clear.
	if p.y > -16.0 and absf(p.x - lerpf(-20.0, 8.0, clampf((46.0 - p.y) / 56.0, 0.0, 1.0))) < 22.0:
		return 0.0
	return 0.05

func _palette(p: Vector2, rng: RandomNumberGenerator) -> String:
	if p.y < -22.0:
		return "teal" if rng.randf() < 0.5 else "green"
	if p.y > 24.0:
		return "autumn" if rng.randf() < 0.6 else "gold"
	var r := rng.randf()
	return "gold" if r < 0.35 else ("autumn" if r < 0.7 else "green")

func _build_scenery() -> void:
	# --- The portal on the ridge, its light fading.
	var arch := Props.sprite("env/arch.png", 7.0, true, {"billboard": false, "ground_shade": 0.12})
	_place(arch, Vector2(-20, 50.5))
	_block(Vector2(-23.2, 50.5), 0.9)
	_block(Vector2(-16.8, 50.5), 0.9)
	_arch_glow = Props.glow(Color(1.0, 0.92, 0.75), 6.0, 0.0)
	_place(_arch_glow, Vector2(-20, 50.4), 2.8)
	_deco("env/boulder_a.png", Vector2(-24.5, 44), 1.4)
	_block(Vector2(-24.5, 44), 0.9)
	_deco("env/boulder_b.png", Vector2(-15.5, 43.5), 1.0)
	# --- Valley meadow life.
	_hero_trees([[Vector2(18.5, 2.5), 1.35, "gold"], [Vector2(4.0, 10.0), 1.2, "autumn"], [Vector2(-8.0, -1.0), 1.25, "green"]])
	_deco("env/boulder_a.png", Vector2(16.2, -5.6), 1.3)
	_block(Vector2(16.2, -5.6), 0.8)
	for p in [Vector2(-4, -12), Vector2(2.5, -13.2), Vector2(12.5, -14.5), Vector2(19, -14.5), Vector2(-9, -13)]:
		_deco("valley/reeds.png", p, 1.4, true, {"sway": 0.08, "ground_shade": 0.3})
	_deco("env/fern.png", Vector2(12.5, 5.5), 1.2)
	_deco("env/bush_autumn.png", Vector2(20.5, -2.0), 1.4)
	_deco("env/bush_green.png", Vector2(-7.0, 5.0), 1.4)
	# --- Mission objects.
	_plant = _spot("plant", PLANT, "Observar a planta", 2.4, Props.sprite("valley/seed_plant.png", 1.3, true, {"sway": 0.06}))
	_plot = _spot("plot", PLOT, "Preparar a terra", 2.6, null)
	_plot_base = _decal("valley/soil.png", PLOT, Vector2(3.0, 2.6), 0.0)
	for i in 3:
		var strip := _decal("valley/soil_wet.png", PLOT + Vector2(0, -0.75 + i * 0.75), Vector2(2.6, 0.75), 0.0)
		_plot_strips.append(strip)
	for i in BRANCH_SPOTS.size():
		var b := _spot("branch_%d" % i, BRANCH_SPOTS[i], "Recolher galhos", 1.8, Props.sprite("valley/branches.png", 0.45, true, {"ground_shade": 0.0}))
		b.tag = "branch"
		branches.append(b)
	for p in [Vector2(8.8, -11.8), Vector2(2.0, -11.4), Vector2(15.0, -13.4)]:
		var r := _spot("river_%d" % _river_spots.size(), p, "Tocar a água", 2.0, null)
		r.tag = "river"
		_river_spots.append(r)
	_shelter = Node3D.new()
	_place(_shelter, SHELTER)
	_shelter.rotation.y = deg_to_rad(-20)
	_block(SHELTER + Vector2(0, -0.6), 1.2)
	var site := _spot("shelter", SHELTER + Vector2(0, -2.2), "Montar o abrigo", 2.4, null)
	site.tag = "shelter"
	# --- The forest and the far landscape.
	_grow_forest(Rect2(terrain.world_min, terrain.world_size), _palette, 4.6, 22.0, 31, 0.9, _tree_density)
	_backdrop("valley/mountains.png", Vector3(10, -95, -230), 640.0, 0.15)
	_backdrop("valley/hills.png", Vector3(0, -42, -125), 380.0, 0.12)
	_backdrop("valley/hills.png", Vector3(-150, -4, 10), 300.0, 0.3, deg_to_rad(90))
	_backdrop("valley/hills.png", Vector3(160, -4, -10), 300.0, 0.3, deg_to_rad(-90))
	_build_river()
	_build_sky_night()

func _spot(id: String, p: Vector2, prompt: String, radius: float, visual: Node3D) -> Spot:
	var s := Spot.new()
	s.world = self
	s.id = id
	s.tag = id
	s.prompt = prompt
	s.radius = radius
	s.visual = visual
	_place(s, p)
	interactables.append(s)
	return s

func _decal(path: String, p: Vector2, size: Vector2, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Props.tex(path)
	m.albedo_color = Color(1, 1, 1, alpha)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = m
	_place(mi, p, 0.06)
	return mi

func _backdrop(path: String, pos: Vector3, width: float, haze: float, yaw := 0.0) -> void:
	var t := Props.tex(path)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, width * float(t.get_height()) / float(t.get_width()))
	q.center_offset = Vector3(0, q.size.y * 0.5, 0)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/backdrop.gdshader")
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("haze", Color(0.88, 0.8, 0.72))
	m.set_shader_parameter("haze_amount", haze)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.y = yaw
	add_child(mi)
	mi.position = pos

func _build_river() -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var along := 0.0
	var pts: Array = []
	for i in RIVER.size() - 1:
		var a: Vector2 = RIVER[i]
		var b: Vector2 = RIVER[i + 1]
		var n := int(a.distance_to(b) / 1.5) + 1
		for k in n:
			pts.append(a.lerp(b, float(k) / n))
	pts.append(RIVER[RIVER.size() - 1])
	var half := terrain.river_width * 0.95
	for i in pts.size():
		var p: Vector2 = pts[i]
		var d: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-d.y, d.x)
		if i > 0:
			along += p.distance_to(pts[i - 1])
		var y := terrain.height(p.x, p.y) + terrain.river_depth * 0.62
		for s in [-1.0, 1.0]:
			var q: Vector2 = p + side * half * s
			verts.append(Vector3(q.x, y, q.y))
			uvs.append(Vector2(along / 6.0, 0.5 + 0.5 * s))
	for i in pts.size() - 1:
		var a := i * 2
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/river.gdshader")
	m.set_shader_parameter("noise_tex", dapple)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_sky_night() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	mm.mesh = q
	mm.instance_count = 140
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in mm.instance_count:
		var az := rng.randf() * TAU
		var el := rng.randf_range(0.12, 1.3)
		var dir := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		var s := rng.randf_range(0.5, 1.4)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), dir * 300.0))
	_stars = MultiMeshInstance3D.new()
	_stars.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = Props.SHADER_GLOW
	m.set_shader_parameter("tex", Props.tex("fx/soft_core.png"))
	m.set_shader_parameter("color", Color(1.0, 0.97, 0.9))
	m.set_shader_parameter("energy", 0.0)
	m.set_shader_parameter("pulse", 0.25)
	_stars.material_override = m
	add_child(_stars)
	_moon = Props.glow(Color(0.85, 0.9, 1.0), 40.0, 0.0, "fx/soft_dot.png")
	add_child(_moon)
	_moon.position = Vector3(90, 120, -230)
	var core := Props.glow(Color(1, 1, 1), 12.0, 1.0, "fx/soft_core.png")
	_moon.add_child(core)

func _build_ambient_fx() -> void:
	_add_shafts([Vector2(9.5, -1.5), Vector2(-14, 32), Vector2(2, 4)], Vector2(0.12, 0.2))
	_add_mist([Vector2(-6, -20), Vector2(20, -24), Vector2(40, -30), Vector2(-30, -26)], Color(0.95, 0.85, 0.75), 0.06)
	super._build_ambient_fx()
	_leaves.amount = 18

func _spawn_actors() -> void:
	super._spawn_actors()
	cam_rig.cam.far = 420.0

# ---------------------------------------------------------------- state
func apply_state() -> void:
	player.magic_unlocked = true
	player.max_mana = 60.0 + 8.0 * Game.spark_count()
	player.essence = String(Game.state.get("essence", "moon"))
	if player.essence == "":
		player.essence = "moon"
	for b in branches:
		if Game.flag("v_" + b.id):
			b.enabled = false
			b.visible = false
	if Game.flag("v_shelter"):
		_build_shelter(true)
	if Game.flag("v_tilled"):
		_plot_base.material_override.albedo_color.a = 1.0
	for i in 3:
		if Game.flag("v_water_%d" % i):
			_plot_strips[i].material_override.albedo_color.a = 1.0
	if Game.flag("v_seeds"):
		_plant.prompt = "Planta"
		_plant.enabled = false
	place_at_checkpoint()
	_refresh_spots()
	_refresh_objective()

func branch_count() -> int:
	var n := 0
	for b in branches:
		if Game.flag("v_" + b.id):
			n += 1
	return n

func stage() -> String:
	if not Game.flag("v_arrived"):
		return "arrive"
	if not Game.flag("v_clearing"):
		return "explore"
	if not Game.flag("v_shelter"):
		return "branches" if branch_count() < 5 else "build"
	if not Game.flag("v_seeds"):
		return "seeds"
	if not Game.flag("v_tilled"):
		return "till"
	if not Game.flag("v_sown"):
		return "sow"
	if not Game.flag("v_watered"):
		return "water"
	return "night"

func _refresh_objective() -> void:
	var text := ""
	match stage():
		"arrive", "explore":
			text = "Um lugar para passar a noite."
		"branches":
			text = "Galhos caídos para um abrigo  %d/5" % branch_count()
		"build":
			text = "Montar o abrigo na clareira."
		"seeds":
			text = "Se eu ficar, vou precisar de comida."
		"till":
			text = "Um pedaço de terra perto do rio."
		"sow":
			text = "Semear."
		"water":
			var n := 0
			for i in 3:
				if Game.flag("v_water_%d" % i):
					n += 1
			text = "A terra precisa de água  %d/3" % n
		"night":
			text = ""
	objective_changed.emit(text)
	guide.clear()
	_refresh_spots()
	hud_changed.emit()

func _refresh_spots() -> void:
	var st := stage()
	for b in branches:
		b.enabled = st == "branches" and not Game.flag("v_" + b.id)
	for s in interactables:
		if s is Spot and s.tag == "shelter":
			s.enabled = st == "build"
	_plant.enabled = st == "seeds"
	_plant.prompt = "Observar a planta"
	_plot.enabled = st in ["till", "sow", "water"]
	match st:
		"till":
			_plot.prompt = "Preparar a terra"
		"sow":
			_plot.prompt = "Semear"
		"water":
			if player.carrying == "water":
				_plot.prompt = "Regar"
			elif Game.flag("v_water_learned"):
				_plot.prompt = "Chamar a água"
			else:
				_plot.prompt = "Regar"
	for r in _river_spots:
		r.enabled = st == "water" and player.carrying == "" and not Game.flag("v_water_learned")

func _title_camera(_delta: float) -> void:
	var center := player.global_position + Vector3(0, 1.4, 0)
	var a := 0.25 + sin(_title_t * 0.05) * 0.2
	cam_rig.cine_pos = center + Vector3(sin(a) * 5.5 - 2.0, 1.4, cos(a) * 5.5)
	cam_rig.cine_look = center + Vector3(2.0, -1.0, -12.0)

func _update_triggers(_delta: float) -> void:
	var pp := Vector2(player.global_position.x, player.global_position.z)
	if stage() == "explore":
		for key in OBSERVE.keys():
			if _observed.has(key) or Game.flag("v_seen_" + key):
				continue
			if pp.distance_to(OBSERVE[key][0]) < 3.2:
				_observed[key] = true
				Game.set_flag("v_seen_" + key)
				say(OBSERVE[key][1])
				break
		if Game.flag("v_seen_water") and Game.flag("v_seen_ground") and Game.flag("v_seen_light") and not _dialogue_open:
			Game.set_flag("v_clearing")
			checkpoint("clearing")
			say(["Água por perto, chão firme, luz...", "Aqui. Acho que posso ficar aqui.", "Primeiro, um abrigo. Há galhos caídos pelo vale."])
			_refresh_objective()

# ---------------------------------------------------------------- arrival (after the memory)
func begin_arrival() -> void:
	mode = "cutscene"
	_scripted = true
	cam_rig.cinematic = true
	player.global_position = _at(Vector2(-20, 47.0))
	player.facing = Vector3(0, 0, -1)
	player.start_kneeling(999.0)
	var pp := player.global_position
	cam_rig.cam.global_position = pp + Vector3(1.2, 1.5, 3.6)
	cam_rig.cine_pos = pp + Vector3(0.9, 1.3, 3.0)
	cam_rig.cine_look = pp + Vector3(0, 0.5, 0)
	_arch_glow.material_override.set_shader_parameter("energy", 1.4)
	create_tween().tween_property(_arch_glow.material_override, "shader_parameter/energy", 0.25, 9.0)
	Audio.sfx("wake", -8.0)
	await wait(2.2)
	await speak(["Por que sinto falta disso?"])
	# A leaf drifts past her hand and she follows it with her eyes.
	var leaf := Props.particles("fx/leaf_orange.png", 1, 3.2, 0.22, Color(1, 1, 1), false)
	leaf.one_shot = true
	leaf.gravity = Vector3(-0.6, -0.35, -0.9)
	leaf.angular_velocity_min = 120
	leaf.angular_velocity_max = 160
	_place(leaf, Vector2(-19.3, 47.2), 1.6)
	leaf.emitting = true
	await wait(1.4)
	cam_rig.cine_pos = pp + Vector3(2.4, 2.6, -2.5)
	cam_rig.cine_look = pp + Vector3(10.0, 3.0, -60.0)
	await wait(2.2)
	await speak(["A floresta terminava numa encosta. Lá embaixo, um rio atravessava um vale amplo.", "Bosques cobriam as colinas. Montanhas se erguiam na distância, e o horizonte desaparecia sob faixas de névoa.", "Havia muito mais mundo do que ela imaginara."], true)
	player.stand_up()
	await wait(1.6)
	create_tween().tween_property(_arch_glow.material_override, "shader_parameter/energy", 0.0, 2.5)
	Audio.sfx("rune", -14.0)
	set_world_light(Color(1.0, 0.86, 0.72), 6.0)
	await speak(["O portal se apagou atrás dela.", "O sol começava a baixar."], true)
	await speak(["Preciso encontrar um lugar para passar a noite."])
	Game.set_flag("v_arrived")
	checkpoint("arrival")
	cam_rig.cinematic = false
	cam_rig.snap_behind(player.facing)
	_scripted = false
	mode = "play"
	_refresh_objective()

# ---------------------------------------------------------------- mission
func on_spot(s: Spot) -> void:
	match s.tag:
		"branch":
			_take_branch(s)
		"shelter":
			_raise_shelter()
		"plant":
			_gather_seeds()
		"plot":
			_work_plot()
		"river":
			_touch_river(s)

func _take_branch(s: Spot) -> void:
	Game.set_flag("v_" + s.id)
	s.enabled = false
	Audio.sfx("step2", -4.0)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(func(): s.visible = false)
	var n := branch_count()
	if n == 1:
		say(["Secos, mas resistentes. Servem."])
	elif n == 5:
		say(["Acho que já tenho o bastante."])
	_refresh_objective()

func _raise_shelter() -> void:
	mode = "cutscene"
	_scripted = true
	fade_requested.emit(true, 0.8)
	await wait(1.0)
	Audio.sfx("land", -4.0)
	Game.set_flag("v_shelter")
	_build_shelter(false)
	player.global_position = _at(SHELTER + Vector2(-1.5, -3.6))
	player.facing = Vector3(0.4, 0, 1).normalized()
	cam_rig.snap_behind(Vector3(0.3, 0, 1))
	await wait(0.6)
	fade_requested.emit(false, 1.2)
	await wait(1.0)
	await speak(["Galhos encostados, folhas por cima...", "É pequeno. Mas é um canto protegido."])
	checkpoint("clearing")
	await speak(["Se eu ficar... vou precisar de comida."])
	_scripted = false
	mode = "play"
	_refresh_objective()

## A small lean-to built from real 3D poles, thatched with leaf clumps.
func _build_shelter(_instant: bool) -> void:
	for c in _shelter.get_children():
		c.queue_free()
	var bark := Forest.bark_material("brown")
	var pole := func(a: Vector3, b: Vector3, r: float):
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r * 0.8
		cm.bottom_radius = r
		cm.height = a.distance_to(b)
		cm.radial_segments = 8
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = bark
		_shelter.add_child(mi)
		var mid := (a + b) * 0.5
		var up := (b - a).normalized()
		var basis := Basis()
		basis.y = up
		basis.x = up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		basis.z = basis.x.cross(up).normalized()
		mi.transform = Transform3D(basis, mid)
	var w := 1.6
	pole.call(Vector3(-w, 0, 0), Vector3(-w, 1.7, 0.1), 0.07)
	pole.call(Vector3(w, 0, 0), Vector3(w, 1.7, 0.1), 0.07)
	pole.call(Vector3(-w - 0.3, 1.62, 0.1), Vector3(w + 0.3, 1.62, 0.1), 0.06)
	for i in 11:
		var x := lerpf(-w + 0.1, w - 0.1, i / 10.0)
		pole.call(Vector3(x, 1.7, 0.15), Vector3(x + randf_range(-0.08, 0.08), 0.0, 1.9), 0.045)
	# Leaf thatch laid along the slanted poles.
	var roof := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(w * 2.25, 2.5)
	roof.mesh = rq
	roof.material_override = Props.sprite_material("valley/thatch.png", true, {"billboard": false, "ground_shade": 0.0})
	roof.rotation.x = deg_to_rad(-45.8)
	roof.position = Vector3(0, 0.86, 1.04) + Vector3(0, 0.717, 0.697) * 0.06
	_shelter.add_child(roof)
	var bed := Props.blob_shadow(3.4, 0.7)
	bed.position = Vector3(0, 0.03, 0.8)
	_shelter.add_child(bed)
	for i in 4:
		var s := Props.sprite("env/fern_autumn.png", 0.6, false, {"ground_shade": 0.3})
		s.position = Vector3(-1.2 + i * 0.8, 0, 0.7)
		_shelter.add_child(s)

func _gather_seeds() -> void:
	mode = "cutscene"
	await speak(["Algumas sementes caíram perto da planta...", "Se caíram aqui e ela cresceu, talvez outras também possam crescer."])
	Game.set_flag("v_seeds")
	Audio.sfx("pickup", -10.0)
	Props.burst(self, _plant.global_position + Vector3(0, 0.4, 0), Color(1.0, 0.85, 0.45), 16, 1.2, 0.18)
	await speak(["Vou guardar algumas. Preciso de um pedaço de terra perto da água."])
	mode = "play"
	_refresh_objective()

func _work_plot() -> void:
	match stage():
		"till":
			mode = "cutscene"
			_scripted = true
			player.start_kneeling(1.4)
			Audio.sfx("land", -6.0)
			var tw := create_tween()
			tw.tween_property(_plot_base.material_override, "albedo_color:a", 1.0, 1.6)
			await wait(2.6)
			Game.set_flag("v_tilled")
			await speak(["Tirar as raízes, soltar a terra com as mãos...", "Assim parece certo."])
			_scripted = false
			mode = "play"
		"sow":
			mode = "cutscene"
			_scripted = true
			player.start_kneeling(1.2)
			Props.burst(self, _at(PLOT, 0.2), Color(1.0, 0.85, 0.45), 20, 1.0, 0.16)
			await wait(2.4)
			Game.set_flag("v_sown")
			checkpoint("clearing")
			await speak(["Pronto. Agora... água."])
			_scripted = false
			mode = "play"
		"water":
			if player.carrying == "water":
				_water_row(_at(PLOT, 1.0) + player.facing * 0.2)
				player.carrying = ""
			elif Game.flag("v_water_learned"):
				# She repeats the gesture, carefully, calling the river from where she stands.
				var from := terrain.river_closest(Vector2(player.global_position.x, player.global_position.z))
				var src := _at(from, terrain.river_depth * 0.62)
				src.y = terrain.height(from.x, from.y) + terrain.river_depth * 0.62
				_water_arc(src, player.global_position + Vector3(0, 1.2, 0), true)
			else:
				say(["Não tenho onde carregar água...", "O rio está logo ali."])
	_refresh_objective()

func _touch_river(_s: Spot) -> void:
	mode = "cutscene"
	_scripted = true
	player.start_kneeling(1.0)
	Audio.sfx("pool", -4.0)
	await wait(1.6)
	await speak(["Se ao menos eu conseguisse levar um pouco...", "...!"])
	# The water rises and follows the movement of her hand.
	var src := player.global_position + player.facing * 1.6 + Vector3(0, 0.2, 0)
	_water_arc(src, player.global_position + Vector3(0, 1.2, 0), false)
	await wait(1.2)
	player.carrying = "water"
	Game.set_flag("v_water_learned")
	await speak(["A água... seguiu a minha mão.", "Devagar. Com cuidado."])
	_scripted = false
	mode = "play"
	_refresh_objective()

func _water_arc(from: Vector3, to: Vector3, then_water: bool) -> void:
	var orb := Node3D.new()
	add_child(orb)
	orb.global_position = from
	orb.add_child(Props.glow(Color(0.45, 0.85, 1.0), 1.0, 1.1))
	var trail := Props.particles("fx/soft_dot.png", 30, 0.6, 0.18, Color(0.6, 0.9, 1.0))
	trail.local_coords = false
	trail.emitting = true
	trail.gravity = Vector3(0, -2.5, 0)
	orb.add_child(trail)
	Audio.sfx("essence_moon", -6.0)
	var mid := (from + to) * 0.5 + Vector3(0, 2.2, 0)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var a := from.lerp(mid, t)
		var b := mid.lerp(to, t)
		orb.global_position = a.lerp(b, t), 0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	if then_water:
		mode = "cutscene"
		_scripted = true
		await tw.finished
		orb.queue_free()
		_water_row(_at(PLOT, 1.0))
		_scripted = false
		mode = "play"
		_refresh_objective()
	else:
		tw.tween_callback(orb.queue_free)

func _water_row(at: Vector3) -> void:
	player.request_cast_visual()
	Audio.sfx("pool", -6.0)
	var rain := Props.particles("fx/soft_dot.png", 50, 0.8, 0.14, Color(0.6, 0.9, 1.0))
	rain.one_shot = true
	rain.explosiveness = 0.6
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(1.2, 0.1, 0.3)
	rain.gravity = Vector3(0, -6, 0)
	add_child(rain)
	rain.global_position = at
	rain.emitting = true
	rain.finished.connect(rain.queue_free)
	var row := -1
	for i in 3:
		if not Game.flag("v_water_%d" % i):
			row = i
			break
	if row < 0:
		return
	Game.set_flag("v_water_%d" % row)
	create_tween().tween_property(_plot_strips[row].material_override, "albedo_color:a", 1.0, 1.0)
	if row == 0:
		say(["Funcionou...", "Mais uma vez. Com cuidado."])
	elif row == 2:
		Game.set_flag("v_watered")
		checkpoint("clearing")
		_first_night()

# ---------------------------------------------------------------- the first night
func _first_night() -> void:
	mode = "cutscene"
	_scripted = true
	await dialogue_closed_or_timeout(20.0)
	objective_changed.emit("")
	set_world_light(Color(0.92, 0.66, 0.58), 4.0)
	tween_environment(Color(0.6, 0.45, 0.45), 0.014, Color(0.25, 0.25, 0.42), Color(0.85, 0.5, 0.4), 4.0)
	await wait(4.2)
	set_world_light(Color(0.36, 0.43, 0.66), 6.0)
	tween_environment(Color(0.1, 0.13, 0.22), 0.02, Color(0.02, 0.04, 0.1), Color(0.1, 0.14, 0.26), 6.0)
	create_tween().tween_property(_stars.material_override, "shader_parameter/energy", 1.2, 7.0)
	create_tween().tween_property(_moon.material_override, "shader_parameter/energy", 0.7, 7.0)
	_night_flies = _add_fireflies([[HOME, 7.0], [PLOT, 3.0]], Color(0.85, 1.0, 0.6))
	fade_requested.emit(true, 2.0)
	await wait(2.2)
	# She sits at the entrance of the shelter, listening to the river.
	var seat := SHELTER + Vector2(-0.6, -2.0)
	player.global_position = _at(seat)
	player.facing = Vector3(PLOT.x - seat.x, 0, PLOT.y - seat.y).normalized()
	player.start_kneeling(999.0)
	cam_rig.cinematic = true
	cam_rig.cam.global_position = _at(seat + Vector2(-3.8, 4.5), 2.2)
	cam_rig.cine_pos = cam_rig.cam.global_position
	cam_rig.cine_look = _at(PLOT, 0.4)
	fade_requested.emit(false, 2.5)
	await wait(3.0)
	await speak(["Na primeira noite, Asterion se sentou à entrada do abrigo.", "Escutou o rio e observou a terra recém-regada.", "Ainda pensava nas luzes que tinha visto."], true)
	# She gets up, kneels by the plot and brings her hand close to the soil.
	player.stand_up()
	await wait(1.8)
	var by := PLOT + Vector2(0.4, 1.8)
	var tw := create_tween()
	tw.tween_method(func(t: float): player.global_position = _at(seat.lerp(by, t)), 0.0, 1.0, 2.2)
	cam_rig.cine_pos = _at(by + Vector2(2.2, 2.6), 1.6)
	cam_rig.cine_look = _at(PLOT, 0.2)
	await wait(2.4)
	player.facing = Vector3(0, 0, -1)
	player.start_kneeling(999.0)
	Props.burst(self, _at(PLOT, 0.3), Color(0.6, 1.0, 0.7), 18, 0.8, 0.16, 1.6)
	await wait(1.2)
	await speak(["Amanhã eu continuo."])
	await wait(1.0)
	Game.set_flag("v_night")
	Game.set_flag("chapter2_done")
	Game.save_game()
	Audio.sfx("victory", -4.0)
	chapter_completed.emit({"chapter": 2, "sparks": Game.spark_count(), "time": float(Game.state.get("time", 0.0))})
