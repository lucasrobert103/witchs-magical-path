class_name BaseWorld
extends Node3D
## Shared machinery for every region: environment, terrain, solid forest, actors,
## interactions, magic, dialogue helpers, reactive flora, idle observation,
## time of day, checkpoints and death.

signal objective_changed(text: String)
signal dialogue_requested(lines: Array)
signal toast_requested(text: String, icon: String)
signal area_entered(title: String, subtitle: String)
signal prompt_changed(text: String, icon: String)
signal fade_requested(to_black: bool, duration: float)
signal chapter_completed(stats: Dictionary)
signal portal_crossed
signal hud_changed

var terrain: Terrain
var player: Player
var cam_rig: CameraRig
var guide: Guide
var dapple: NoiseTexture2D
var env: Environment
var sky_mat: ShaderMaterial
var mode := "title"            # title, play, cutscene
var interactables: Array = []
var shades: Array = []
var sparks: Array = []
var reactive: Array = []       # glowing plants that answer Asterion's presence
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
var _dialogue_open := false
var _idle_t := 0.0
var _light := Color(1, 1, 1)
var _light_tween: Tween

func _ready() -> void:
	_quality = int(Game.settings.get("quality", 1))
	# Phones have very dense screens: render 3D below native and let the UI stay sharp.
	var scale_3d := 1.0
	if OS.has_feature("mobile"):
		scale_3d = 0.8 if _quality > 0 else 0.6
	elif _quality == 0:
		scale_3d = 0.75
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale = scale_3d
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
	set_world_light(Color(1, 1, 1), 0.0)
	_build_environment()
	terrain = Terrain.new()
	add_child(terrain)
	_build_layout()
	terrain.build_mask()
	_build_ground()
	_build_scenery()
	_build_ambient_fx()
	_spawn_actors()
	apply_state()

# ---------------------------------------------------------------- overridables
func _build_layout() -> void:
	pass

func _build_scenery() -> void:
	pass

func _checkpoints() -> Dictionary:
	return {"start": [Vector2.ZERO, Vector2(0, -1)]}

func _zones() -> Array:
	return []

func stage() -> String:
	return ""

func _refresh_objective() -> void:
	pass

func _update_triggers(_delta: float) -> void:
	pass

func apply_state() -> void:
	place_at_checkpoint()
	_refresh_objective()

func begin_new_game() -> void:
	begin_play()

func _title_camera(delta: float) -> void:
	var center := player.global_position + Vector3(0, 1.4, 0)
	var a := 0.35 + sin(_title_t * 0.05) * 0.25
	cam_rig.cine_pos = center + Vector3(sin(a) * 5.5, 0.9, cos(a) * 5.5)
	cam_rig.cine_look = center + Vector3(-1.6, 0.6, -6.0)

# ---------------------------------------------------------------- environment
func _build_environment(fog_color := Color(0.56, 0.66, 0.6), fog_density := 0.03) -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.6)
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
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

## Global light multiplier for every painted material (time of day).
func set_world_light(c: Color, duration := 2.0) -> void:
	if _light_tween:
		_light_tween.kill()
	if duration <= 0.0:
		_apply_light(c)
		return
	_light_tween = create_tween()
	_light_tween.tween_method(_apply_light, _light, c, duration).set_trans(Tween.TRANS_SINE)

func _apply_light(c: Color) -> void:
	_light = c
	RenderingServer.global_shader_parameter_set("world_light", c)

func tween_environment(fog: Color, density: float, sky_top: Color, sky_horizon: Color, duration: float) -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(env, "fog_light_color", fog, duration)
	tw.tween_property(env, "fog_density", density, duration)
	tw.tween_property(sky_mat, "shader_parameter/top", sky_top, duration)
	tw.tween_property(sky_mat, "shader_parameter/horizon", sky_horizon, duration)

func _build_ground() -> void:
	var tex := {
		"grass_tex": Props.tex("res://assets/textures/ground_grass.png"),
		"moss_tex": Props.tex("res://assets/textures/ground_moss.png"),
		"dirt_tex": Props.tex("res://assets/textures/ground_dirt.png"),
		"path_tex": Props.tex("res://assets/textures/path_stones.png"),
	}
	terrain.build_ground(tex, dapple)

# ---------------------------------------------------------------- placement helpers
func _h(p: Vector2) -> float:
	return terrain.height(p.x, p.y)

func _at(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, _h(p) + lift, p.y)

func _place(node: Node3D, p: Vector2, lift := 0.0) -> Node3D:
	add_child(node)
	node.position = _at(p, lift)
	return node

func _deco(path: String, p: Vector2, height: float, soft := true, params := {}) -> MeshInstance3D:
	var s := Props.sprite(path, height, soft, params)
	_place(s, p)
	return s

func _block(p: Vector2, r: float) -> void:
	terrain.add_obstacle(p, p, r)

## Places a few hand-picked solid trees (with collision) — consistent with the forest.
func _hero_trees(list: Array) -> void:
	var items: Array = []
	for t in list:
		items.append([_at(t[0]), t[1], t[2]])
		_block(t[0], 0.55 * float(t[1]))
	Forest.build(self, items, 1.0)

## Fills everything around the walkable space with solid trees, undergrowth and grass.
func _grow_forest(bounds: Rect2, palette: Callable, spacing := 4.4, max_sd := 24.0, seed := 7, density := 1.0, keep := Callable()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var trees: Array = []
	var far_items := {"env/far_tree_a.png": [], "env/far_tree_b.png": []}
	if _quality == 0:
		spacing *= 1.3
	var x := bounds.position.x
	while x < bounds.end.x:
		var z := bounds.position.y
		while z < bounds.end.y:
			var p := Vector2(x + rng.randf_range(-1.6, 1.6), z + rng.randf_range(-1.6, 1.6))
			var sd := terrain.walk_sd(p)
			var wet := not terrain.river.is_empty() and terrain.river_dist(p) < terrain.river_width + 2.0
			var dens := density * (float(keep.call(p)) if keep.is_valid() else 1.0)
			if sd > 2.6 and sd < max_sd and not wet and terrain.obstacle_clear(p, 1.5) and rng.randf() < dens:
				var s := rng.randf_range(0.85, 1.25) * (1.15 if sd < 6.0 else 1.0)
				trees.append([_at(p, -0.1), s, palette.call(p, rng)])
			elif sd >= max_sd and sd < max_sd + 16.0 and rng.randf() < 0.5:
				var ftex := "env/far_tree_a.png" if rng.randf() < 0.5 else "env/far_tree_b.png"
				far_items[ftex].append([_at(p, -0.5), rng.randf_range(1.6, 2.4)])
			z += spacing
		x += spacing
	Forest.build(self, trees, 1.0 if _quality > 0 else 0.4)
	for t in far_items.keys():
		if far_items[t].size() > 0:
			add_child(Props.scatter(t, 9.0, far_items[t], {"tint": Color(0.2, 0.32, 0.3), "ground_shade": 0.0, "sway": 0.05}))
	var under := {"env/bush_green.png": [], "env/bush_autumn.png": [], "env/fern.png": [], "env/fern_autumn.png": [], "env/boulder_b.png": [], "env/mushrooms_orange.png": []}
	var grass := {"env/grass_a.png": [], "env/grass_b.png": [], "env/grass_c.png": []}
	var count := int((3000 if _quality > 0 else 1200) * bounds.get_area() / 17000.0)
	for i in count:
		var p := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		var sd := terrain.walk_sd(p)
		if not terrain.obstacle_clear(p, 0.6):
			continue
		if not terrain.river.is_empty() and terrain.river_dist(p) < terrain.river_width + 0.6:
			continue
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

## A plant whose light grows when Asterion is near: the forest answering her.
func _add_reactive(p: Vector2, color: Color, size := 1.6, sprite := "env/mushrooms_glow.png", sprite_h := 0.65) -> void:
	if sprite != "":
		_deco(sprite, p, sprite_h)
	var g := Props.glow(color, size, 0.15, "fx/soft_dot.png", 0.1)
	_place(g, p, 0.35)
	reactive.append({"node": g, "p": p, "e": 0.15, "rang": false})

func _add_shafts(spots: Array, energy := Vector2(0.1, 0.2)) -> void:
	var shaft_tex := Props.tex("fx/light_shaft.png")
	var shaft_shader := load("res://shaders/light_shaft.gdshader")
	for p in spots:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(randf_range(2.0, 3.6), 16.0)
		q.center_offset = Vector3(0, 8.0, 0)
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = shaft_shader
		m.set_shader_parameter("tex", shaft_tex)
		m.set_shader_parameter("energy", randf_range(energy.x, energy.y))
		m.set_shader_parameter("slant", 0.32)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_place(mi, p, -0.5)

func _add_fireflies(zones: Array, color := Color(1.0, 0.9, 0.55)) -> Array:
	var out: Array = []
	for zone in zones:
		var ff := Props.particles("fx/soft_dot.png", 26 if _quality > 0 else 12, 6.0, 0.14, color)
		ff.emitting = true
		ff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		ff.emission_box_extents = Vector3(zone[1], 1.5, zone[1])
		ff.spread = 180.0
		ff.initial_velocity_min = 0.1
		ff.initial_velocity_max = 0.35
		ff.gravity = Vector3(0, 0.05, 0)
		ff.preprocess = 6.0
		_place(ff, zone[0], 1.6)
		out.append(ff)
	return out

func _add_mist(points: Array, color := Color(0.75, 0.85, 0.75), energy := 0.07) -> void:
	for p in points:
		var mist := Props.glow(color, 16.0, energy)
		mist.material_override.set_shader_parameter("near_fade", 9.0)
		_place(mist, p, 1.5)

func _build_ambient_fx() -> void:
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

# ---------------------------------------------------------------- checkpoints
func place_at_checkpoint() -> void:
	var cps := _checkpoints()
	var key := String(Game.state.get("checkpoint", ""))
	var cp: Array = cps.get(key, cps.values()[0])
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

# ---------------------------------------------------------------- frame update
func _process(delta: float) -> void:
	if mode == "title":
		_title_t += delta
		cam_rig.cinematic = true
		_title_camera(delta)
		cam_rig.update(delta, player, terrain)
		player.cam_yaw = cam_rig.yaw
		player.control_enabled = false
		player.move_input = Vector2.ZERO
		player.tick(delta)
		guide.tick(delta, player.global_position)
		_update_leaves()
		_update_reactive(delta)
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
	if mode == "play":
		for s in shades.duplicate():
			if is_instance_valid(s):
				s.tick(delta, player)
	_update_leaves()
	_update_reactive(delta)
	if mode == "play":
		_update_focus()
		_update_zones()
		_update_idle(delta)
		_update_triggers(delta)
	if _death_timer >= 0.0:
		_death_timer -= delta
		if _death_timer < 0.0:
			_respawn()

func _update_leaves() -> void:
	if _leaves:
		_leaves.global_position = cam_rig.cam.global_position + Vector3(0, 6, 0) - cam_rig.cam.global_transform.basis.z * 6.0

func _update_reactive(delta: float) -> void:
	var pp := Vector2(player.global_position.x, player.global_position.z)
	for r in reactive:
		var d: float = pp.distance_to(r["p"])
		var target := 0.15 + 1.1 * (1.0 - smoothstep(0.8, 5.0, d))
		r["e"] = lerpf(r["e"], target, clampf(delta * 3.0, 0.0, 1.0))
		r["node"].material_override.set_shader_parameter("energy", r["e"])
		if d < 2.2 and not r["rang"] and mode == "play":
			r["rang"] = true
			Audio.sfx("essence_moon", -20.0, 0.15)
		elif d > 6.0:
			r["rang"] = false

## Small pauses: when Asterion stands still, she turns to watch something nearby.
func _update_idle(delta: float) -> void:
	var moving := player.move_input.length() > 0.05 or Vector2(player.vel.x, player.vel.z).length() > 0.2
	if moving or player.anim == "cast" or not player.on_ground:
		_idle_t = 0.0
		player.look_target = Vector3.INF
		return
	_idle_t += delta
	if _idle_t > 4.5 and player.look_target == Vector3.INF:
		var best := Vector3.INF
		var best_d := 1e9
		var candidates: Array = []
		for r in reactive:
			candidates.append(_at(r["p"]))
		for it in interactables:
			if is_instance_valid(it):
				candidates.append(it.global_position)
		for c in candidates:
			var d: float = c.distance_to(player.global_position)
			if d > 2.0 and d < 14.0 and d < best_d:
				best_d = d
				best = c
		if best == Vector3.INF:
			var a := randf() * TAU
			best = player.global_position + Vector3(cos(a), 0, sin(a)) * 6.0
		player.look_target = best
	if _idle_t > 9.5:
		_idle_t = 0.0
		player.look_target = Vector3.INF

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
	for z in _zones():
		if pp.distance_to(z["p"]) < z["r"]:
			zone = z["id"]
			if zone != _current_zone and not _visited_zones.has(zone):
				_visited_zones[zone] = true
				area_entered.emit(z["title"], z["sub"])
	_current_zone = zone

# ---------------------------------------------------------------- dialogue helpers
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

## Says lines and waits until the player has read them.
func speak(lines: Array, narration := false) -> void:
	if narration:
		narrate(lines)
	else:
		say(lines)
	await dialogue_closed_or_timeout(120.0)

func set_dialogue_open(v: bool) -> void:
	_dialogue_open = v

func dialogue_closed_or_timeout(t: float) -> void:
	await get_tree().process_frame
	while _dialogue_open and t > 0.0:
		await get_tree().process_frame
		t -= get_process_delta_time()

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func begin_play() -> void:
	mode = "play"
	cam_rig.cinematic = false
	_refresh_objective()

func on_dialogue_finished() -> void:
	if mode == "cutscene" and _end_timer < 0.0 and _death_timer < 0.0 and not _scripted:
		mode = "play"

var _scripted := false   # true while a cutscene coroutine owns the mode

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

# ---------------------------------------------------------------- enemies
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
	_refresh_objective()

# ---------------------------------------------------------------- shared interactions
func on_spark_collected(s: Spark) -> void:
	Game.add_spark(s.id)
	sparks.erase(s)
	interactables.erase(s)
	player.max_mana = 60.0 + 8.0 * Game.spark_count()
	player.mana = player.max_mana
	player.heal(100)
	Audio.sfx("pickup", -2.0)
	toast_requested.emit("%d/%d" % [Game.spark_count(), Game.TOTAL_SPARKS], "spark")
	narrate([s.echo])
	Game.save_game()
	hud_changed.emit()

func show_lore(stone: LoreStone) -> void:
	Audio.sfx("open", -6.0)
	narrate(stone.lines)

func on_spot(_spot: Spot) -> void:
	pass

# ---------------------------------------------------------------- death
func _on_player_died() -> void:
	mode = "cutscene"
	_death_timer = 1.6
	fade_requested.emit(true, 1.2)

func _respawn() -> void:
	place_at_checkpoint()
	mode = "play"
	fade_requested.emit(false, 1.0)
	_refresh_objective()
