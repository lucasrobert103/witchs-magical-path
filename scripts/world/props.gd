class_name Props
## Factory helpers for painted sprites, glows and particles in the 3D world.

const SHADER_CUT := preload("res://shaders/billboard_cut.gdshader")
const SHADER_SOFT := preload("res://shaders/billboard_soft.gdshader")
const SHADER_GLOW := preload("res://shaders/glow.gdshader")
const SPR := "res://assets/sprites/"

static var _tex := {}
static var _mats := {}

static func tex(path: String) -> Texture2D:
	if not path.begins_with("res://"):
		path = SPR + path
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]

static func aspect(path: String) -> float:
	var t := tex(path)
	return float(t.get_width()) / float(t.get_height())

static func sprite_material(path: String, soft := false, params := {}) -> ShaderMaterial:
	var key := path + str(soft) + str(params)
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER_SOFT if soft else SHADER_CUT
	m.set_shader_parameter("tex", tex(path))
	for k in params.keys():
		m.set_shader_parameter(k, params[k])
	_mats[key] = m
	return m

static func quad(width: float, height: float, bottom := true) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(width, height)
	if bottom:
		q.center_offset = Vector3(0, height * 0.5, 0)
	return q

## A single upright painted sprite whose bottom edge sits on the node origin.
static func sprite(path: String, height: float, soft := false, params := {}, unique := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = quad(height * aspect(path), height)
	var mat := sprite_material(path, soft, params)
	if unique:
		mat = mat.duplicate()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Many copies of one sprite in a single draw call. items: Array of [Vector3 pos, float height_scale].
static func scatter(path: String, height: float, items: Array, params := {}, soft := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad(height * aspect(path), height)
	mm.instance_count = items.size()
	for i in items.size():
		var it: Array = items[i]
		var s: float = it[1]
		var flip := -1.0 if (i % 2) == 1 else 1.0
		var b := Basis().scaled(Vector3(s * flip, s, s))
		mm.set_instance_transform(i, Transform3D(b, it[0]))
		mm.set_instance_custom_data(i, Color(randf(), randf(), 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = sprite_material(path, soft, params)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

## Additive light sprite.
static func glow(color: Color, size: float, energy := 1.0, texture := "fx/soft_dot.png", pulse := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = SHADER_GLOW
	m.set_shader_parameter("tex", tex(texture))
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("pulse", pulse)
	m.set_shader_parameter("pulse_speed", randf_range(1.5, 2.5))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Soft dark ellipse on the ground under actors and props.
static func blob_shadow(size: float, alpha := 0.55) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(size, size * 0.8)
	mi.mesh = p
	var key := "shadow" + str(alpha)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = tex("fx/blob_shadow.png")
		m.albedo_color = Color(0.02, 0.05, 0.03, alpha)
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_mats[key] = m
	mi.material_override = _mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.03
	return mi

static func particle_material(texture: String, additive := true) -> StandardMaterial3D:
	var key := "pm" + texture + str(additive)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_fog = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex(texture)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m

## Generic CPU particle emitter (reliable on every GLES3 device).
static func particles(texture: String, amount: int, lifetime: float, size: float, color: Color, additive := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = particle_material(texture, additive)
	p.mesh = q
	p.amount = amount
	p.lifetime = lifetime
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.75, Color(1, 1, 1, 0.8))
	p.color_ramp = ramp
	p.gravity = Vector3.ZERO
	return p

## One-shot burst of light motes.
static func burst(parent: Node, pos: Vector3, color: Color, amount := 26, speed := 3.0, size := 0.35, life := 0.9) -> void:
	var p := particles("fx/sparkle.png", amount, life, size, color)
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.2
	p.gravity = Vector3(0, -1.0, 0)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)

static func label3d(text: String, size := 64) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/Nunito-ExtraBold.woff")
	l.font_size = size
	l.outline_size = 14
	l.outline_modulate = Color(0.04, 0.07, 0.05, 0.85)
	l.modulate = Color(0.98, 0.94, 0.82)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0009
	l.render_priority = 10
	l.outline_render_priority = 9
	return l
