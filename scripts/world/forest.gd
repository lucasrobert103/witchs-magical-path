class_name Forest
## Solid 3D trees: procedural trunks with root flares and branches (one MultiMesh per
## variant) crowned by painterly leaf clumps. Trunks keep their shape from every angle.

const VARIANTS := 4
static var _meshes: Array = []      # Array of [ArrayMesh, Array[Vector3] crown points]
static var _bark_mats := {}

const PALETTES := {
	"autumn": {"bark": "brown", "clumps": ["env/clump_autumn.png", "env/clump_gold.png", "env/clump_autumn.png"]},
	"gold": {"bark": "brown", "clumps": ["env/clump_gold.png", "env/clump_autumn.png"]},
	"green": {"bark": "grey", "clumps": ["env/clump_green.png", "env/clump_teal.png", "env/clump_green.png"]},
	"teal": {"bark": "grey", "clumps": ["env/clump_teal.png", "env/clump_green.png"]},
}

static func _ring(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, center: Vector3, axis: Vector3, radius: float, sides: int, v: float, phase: float, root: float, t: float, urep: float) -> void:
	var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var other := axis.cross(side).normalized()
	for j in sides + 1:
		var a := TAU * j / sides
		var roots := 1.0 + root * pow(maxf(0.0, cos(a * 5.0 + phase)), 2.0) * exp(-t * 14.0)
		var wob := 1.0 + 0.07 * sin(a * 3.0 + t * 9.0 + phase * 2.0)
		var dir := side * cos(a) + other * sin(a)
		verts.append(center + dir * radius * roots * wob)
		normals.append((dir + axis * 0.12).normalized())
		uvs.append(Vector2(float(j) / sides * urep, v))

static func _tube(st: Array, points: Array, radii: Array, sides: int, phase: float, root: float, urep: float) -> void:
	var verts: PackedVector3Array = st[0]
	var normals: PackedVector3Array = st[1]
	var uvs: PackedVector2Array = st[2]
	var idx: PackedInt32Array = st[3]
	var base := verts.size()
	var v := 0.0
	for i in points.size():
		var axis: Vector3
		if i < points.size() - 1:
			axis = (points[i + 1] - points[i]).normalized()
		else:
			axis = (points[i] - points[i - 1]).normalized()
		if i > 0:
			v += points[i].distance_to(points[i - 1]) / 2.2
		_ring(verts, normals, uvs, points[i], axis, radii[i], sides, v, phase, root, float(i) / (points.size() - 1), urep)
	for i in points.size() - 1:
		for j in sides:
			var a := base + i * (sides + 1) + j
			var b := a + sides + 1
			idx.append_array([a, b, a + 1, a + 1, b, b + 1])

static func _build_variant(seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedInt32Array()]
	var height := rng.randf_range(5.5, 7.0)
	var r0 := 0.5
	var bend := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	var pts: Array = []
	var radii: Array = []
	var rings := 14
	for i in rings + 1:
		var t := float(i) / rings
		pts.append(Vector3(0, t * height, 0) + bend * t * t + Vector3(sin(t * 5.0 + seed), 0, cos(t * 4.0 + seed)) * 0.08)
		radii.append(r0 * lerpf(1.0, 0.5, t) * (1.0 + 0.9 * exp(-t * 10.0)))
	_tube(st, pts, radii, 14, rng.randf() * TAU, 0.55, 3.0)
	var crown: Array = []
	var top: Vector3 = pts[rings]
	crown.append(top + Vector3(0, 1.4, 0))
	var nb := rng.randi_range(4, 5)
	for b in nb:
		var t0 := rng.randf_range(0.55, 0.92)
		var start: Vector3 = Vector3(0, t0 * height, 0) + bend * t0 * t0
		var ang := TAU * b / nb + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(ang), 0, sin(ang))
		var length := rng.randf_range(2.0, 3.2)
		var mid := start + out * length * 0.5 + Vector3(0, length * 0.45, 0)
		var tip := start + out * length + Vector3(0, length * 0.75, 0)
		var br := r0 * lerpf(0.42, 0.3, t0)
		_tube(st, [start - out * 0.1, mid, tip], [br, br * 0.7, br * 0.35], 7, rng.randf() * TAU, 0.0, 1.0)
		crown.append(tip)
		crown.append((mid + tip) * 0.5 + Vector3(0, 0.6, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = st[0]
	arrays[Mesh.ARRAY_NORMAL] = st[1]
	arrays[Mesh.ARRAY_TEX_UV] = st[2]
	arrays[Mesh.ARRAY_INDEX] = st[3]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return [mesh, crown]

static func variants() -> Array:
	if _meshes.is_empty():
		for i in VARIANTS:
			_meshes.append(_build_variant(1000 + i * 17))
	return _meshes

static func bark_material(kind: String) -> ShaderMaterial:
	if not _bark_mats.has(kind):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/bark.gdshader")
		m.set_shader_parameter("bark", Props.tex("res://assets/textures/bark_%s.png" % kind))
		_bark_mats[kind] = m
	return _bark_mats[kind]

## trees: Array of [Vector3 position, float scale, String palette]
static func build(parent: Node3D, trees: Array, clump_density := 1.0) -> void:
	var vs := variants()
	var trunk_items := {}   # "variant|bark" -> Array[Transform3D]
	var clump_items := {}   # texture -> Array[[Vector3, float]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for tr in trees:
		var pos: Vector3 = tr[0]
		var s: float = tr[1]
		var pal: Dictionary = PALETTES.get(tr[2], PALETTES["autumn"])
		var vi := rng.randi() % vs.size()
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		var xf := Transform3D(basis, pos - Vector3(0, 0.25 * s, 0))
		var key := "%d|%s" % [vi, pal["bark"]]
		if not trunk_items.has(key):
			trunk_items[key] = []
		trunk_items[key].append(xf)
		var clumps: Array = pal["clumps"]
		for cp in vs[vi][1]:
			var n := 2 if rng.randf() < clump_density else 1
			for k in n:
				var off := Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.4, 0.7), rng.randf_range(-0.9, 0.9))
				var wp: Vector3 = xf * (cp + off)
				var tex: String = clumps[rng.randi() % clumps.size()]
				if not clump_items.has(tex):
					clump_items[tex] = []
				clump_items[tex].append([wp - Vector3(0, 1.6 * s, 0), s * rng.randf_range(0.85, 1.25)])
	for key in trunk_items.keys():
		var parts: PackedStringArray = key.split("|")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = vs[int(parts[0])][0]
		var list: Array = trunk_items[key]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = bark_material(parts[1])
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
	for tex in clump_items.keys():
		parent.add_child(Props.scatter(tex, 3.4, clump_items[tex], {"sway": 0.07, "sway_speed": 0.8, "ground_shade": 0.0, "top_light": 0.08}))
