class_name Terrain
extends Node3D
## Walkable layout, ground mesh, painted layout mask and collision queries.
## Shapes are 2D on the XZ plane: circles and capsules (segment + radius).

const SHADER := preload("res://shaders/ground.gdshader")
const RES := 0.5          # meters per mask pixel
const BANK := 5.0         # meters of falloff outside walkable shapes

var world_min := Vector2(-56, -96)
var world_size := Vector2(112, 180)
var areas: Array = []     # {a, b, r}
var paths: Array = []     # {a, b, r}
var pools: Array = []     # {p, r}
var obstacles: Array = [] # {a, b, r, h, id}
var _w := 0
var _h := 0
var _walk := PackedFloat32Array()
var mask: Image
var ground: MeshInstance3D
var base_height: Callable    # optional large-scale relief (valleys, ridges)
var bank_height := 2.6
var river: Array = []        # polyline of Vector2 for carved river beds
var river_depth := 1.6
var river_width := 3.0

func add_area(a: Vector2, b: Vector2, r: float) -> void:
	areas.append({"a": a, "b": b, "r": r})

func add_circle_area(p: Vector2, r: float) -> void:
	add_area(p, p, r)

func add_path(points: Array, area_r: float, path_r: float) -> void:
	for i in points.size() - 1:
		add_area(points[i], points[i + 1], area_r)
		paths.append({"a": points[i], "b": points[i + 1], "r": path_r})

func add_obstacle(a: Vector2, b: Vector2, r: float, h := 99.0, id := "") -> void:
	obstacles.append({"a": a, "b": b, "r": r, "h": h, "id": id})

func remove_obstacles(id: String) -> void:
	obstacles = obstacles.filter(func(o): return o["id"] != id)

static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func seg_closest(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return a
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return a + ab * t

## Signed distance to the walkable union (negative inside).
func walk_sd(p: Vector2) -> float:
	var best := 1e9
	for s in areas:
		best = minf(best, seg_dist(p, s["a"], s["b"]) - s["r"])
	return best

func path_dist(p: Vector2) -> float:
	var best := 1e9
	for s in paths:
		best = minf(best, seg_dist(p, s["a"], s["b"]) - s["r"])
	return best

## Keep a point inside the walkable union with the given margin.
func clamp_walkable(p: Vector2, margin: float) -> Vector2:
	var best := 1e9
	var best_s = null
	for s in areas:
		var d: float = seg_dist(p, s["a"], s["b"]) - s["r"]
		if d < best:
			best = d
			best_s = s
	if best_s == null or best <= -margin:
		return p
	var c := seg_closest(p, best_s["a"], best_s["b"])
	var dir := p - c
	if dir.length() < 0.001:
		return p
	return c + dir.normalized() * (float(best_s["r"]) - margin)

## Push a circle (actor) out of blocking obstacles; feet_y lets actors jump over low ones.
func resolve(p: Vector2, radius: float, feet_y: float) -> Vector2:
	for _i in 2:
		for o in obstacles:
			if feet_y - height_at(p) > float(o["h"]) - 0.05:
				continue
			var c := seg_closest(p, o["a"], o["b"])
			var d := p - c
			var min_d: float = float(o["r"]) + radius
			var l := d.length()
			if l < min_d:
				if l < 0.0001:
					d = Vector2(0, 1)
					l = 1.0
				p = c + d / l * min_d
	return p

func walk_value(x: float, z: float) -> float:
	if _w == 0:
		return 1.0
	var fx := (x - world_min.x) / RES
	var fz := (z - world_min.y) / RES
	var ix := clampi(int(fx), 0, _w - 2)
	var iz := clampi(int(fz), 0, _h - 2)
	var tx := clampf(fx - ix, 0.0, 1.0)
	var tz := clampf(fz - iz, 0.0, 1.0)
	var a := _walk[iz * _w + ix]
	var b := _walk[iz * _w + ix + 1]
	var c := _walk[(iz + 1) * _w + ix]
	var d := _walk[(iz + 1) * _w + ix + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)

func height_at(p: Vector2) -> float:
	return height(p.x, p.y)

func height(x: float, z: float) -> float:
	var undulate := 0.18 * sin(x * 0.23 + z * 0.11) + 0.12 * sin(z * 0.31 - x * 0.07)
	var w := walk_value(x, z)
	var bank := (1.0 - w)
	var h := undulate + bank * bank * bank_height
	if base_height.is_valid():
		h += float(base_height.call(x, z))
	if not river.is_empty():
		var d := river_dist(Vector2(x, z))
		h -= river_depth * (1.0 - smoothstep(river_width * 0.6, river_width * 1.9, d))
	return h

func river_dist(p: Vector2) -> float:
	var best := 1e9
	for i in river.size() - 1:
		best = minf(best, seg_dist(p, river[i], river[i + 1]))
	return best

func river_closest(p: Vector2) -> Vector2:
	var best := 1e9
	var out := p
	for i in river.size() - 1:
		var c := seg_closest(p, river[i], river[i + 1])
		var d := c.distance_to(p)
		if d < best:
			best = d
			out = c
	return out

## True when no blocking obstacle is within r of p.
func obstacle_clear(p: Vector2, r: float) -> bool:
	for o in obstacles:
		if seg_dist(p, o["a"], o["b"]) < float(o["r"]) + r:
			return false
	return true

## Paints the layout mask: R walkable softness, G stone path, B dirt fringe, A pool glow.
func build_mask() -> void:
	_w = int(world_size.x / RES) + 1
	_h = int(world_size.y / RES) + 1
	var r := PackedFloat32Array(); r.resize(_w * _h)
	var g := PackedFloat32Array(); g.resize(_w * _h)
	var b := PackedFloat32Array(); b.resize(_w * _h)
	var a := PackedFloat32Array(); a.resize(_w * _h)
	for s in areas:
		_paint(r, s["a"], s["b"], s["r"], BANK, false)
	for s in paths:
		_paint(g, s["a"], s["b"], s["r"], 0.7, false)
		_paint(b, s["a"], s["b"], s["r"] + 0.6, 1.8, true)
	for p in pools:
		_paint(a, p["p"], p["p"], p["r"], 3.5, false)
	_walk = r
	mask = Image.create(_w, _h, false, Image.FORMAT_RGBA8)
	for i in _w * _h:
		mask.set_pixel(i % _w, i / _w, Color(r[i], g[i], b[i] * 0.65, a[i]))

func _paint(buf: PackedFloat32Array, pa: Vector2, pb: Vector2, rad: float, soft: float, half: bool) -> void:
	var lo := Vector2(minf(pa.x, pb.x), minf(pa.y, pb.y)) - Vector2.ONE * (rad + soft)
	var hi := Vector2(maxf(pa.x, pb.x), maxf(pa.y, pb.y)) + Vector2.ONE * (rad + soft)
	var x0 := clampi(int((lo.x - world_min.x) / RES), 0, _w - 1)
	var x1 := clampi(int((hi.x - world_min.x) / RES) + 1, 0, _w - 1)
	var z0 := clampi(int((lo.y - world_min.y) / RES), 0, _h - 1)
	var z1 := clampi(int((hi.y - world_min.y) / RES) + 1, 0, _h - 1)
	for iz in range(z0, z1 + 1):
		var wz := world_min.y + iz * RES
		for ix in range(x0, x1 + 1):
			var p := Vector2(world_min.x + ix * RES, wz)
			var d := seg_dist(p, pa, pb) - rad
			var v := 1.0 - smoothstep(0.0, soft, d)
			if half:
				v *= smoothstep(-1.4, 0.2, d)
			var i := iz * _w + ix
			if v > buf[i]:
				buf[i] = v

func build_ground(textures: Dictionary, dapple: Texture2D) -> void:
	var step := 1.0
	var nx := int(world_size.x / step)
	var nz := int(world_size.y / step)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize((nx + 1) * (nz + 1))
	uvs.resize(verts.size())
	for iz in nz + 1:
		for ix in nx + 1:
			var x := world_min.x + ix * step
			var z := world_min.y + iz * step
			verts[iz * (nx + 1) + ix] = Vector3(x, height(x, z), z)
			uvs[iz * (nx + 1) + ix] = Vector2(x, z)
	for iz in nz:
		for ix in nx:
			var i := iz * (nx + 1) + ix
			idx.append_array([i, i + 1, i + nx + 1, i + 1, i + nx + 2, i + nx + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	ground = MeshInstance3D.new()
	ground.mesh = mesh
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = SHADER
	for k in textures.keys():
		m.set_shader_parameter(k, textures[k])
	m.set_shader_parameter("mask_tex", ImageTexture.create_from_image(mask))
	m.set_shader_parameter("dapple_tex", dapple)
	m.set_shader_parameter("world_min", world_min)
	m.set_shader_parameter("world_size", Vector2(_w - 1, _h - 1) * RES)
	ground.material_override = m
	add_child(ground)
