extends Node3D
## Original staged exploration spaces; visual proposals, not additional mythology.
const WORLD_SHADER = preload("res://shaders/world_toon.gdshader")
const WATER_SHADER = preload("res://shaders/water.gdshader")
const GRASS_SHADER = preload("res://shaders/grass.gdshader")
const WEST := -44.0
const EAST := 44.0
const SOUTH := 43.0
const NORTH := -78.0

var flower_position := Vector3.ZERO
var inscription_position := Vector3.ZERO
var destination_position := Vector3.ZERO
var landmarks: Array[Dictionary] = []
var active_landmarks: Array[bool] = [false, false, false]
var gate_open := false
var awakened := false
var flower: Node3D
var flower_light: OmniLight3D
var petals: Array[MeshInstance3D] = []
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
var source_nodes: Array[Node3D] = []
var source_lights: Array[OmniLight3D] = []
var source_cores: Array[MeshInstance3D] = []
var source_materials: Array[StandardMaterial3D] = []
var source_tweens: Array[Tween] = []
var response_nodes: Array[Node3D] = []
var gate_slab: Node3D
var gate_collision: CollisionShape3D
var gate_tween: Tween
var floating_leaves: MultiMeshInstance3D
var leaf_origins: Array[Vector3] = []
var chime: AudioStreamPlayer
var gold: StandardMaterial3D
var mint: StandardMaterial3D
var clouds: Array[Node3D] = []
var trunk_sets: Array = [[], [], [], []]
var bark_material: ShaderMaterial
var stone_material: ShaderMaterial

func _ready() -> void:
	rng.seed = 731098
	_lighting()
	bark_material = _toon(Color("71574c"))
	stone_material = _toon(Color("71857e"))
	gold = _glow(Color("f5d48d"), 1.3)
	mint = _glow(Color("9eeed1"), 0.9)
	_ground()
	_horizon()
	_trees()
	_meadow_details()
	_lake()
	_gate()
	_sources()
	_inscription()
	_sanctuary()
	_floating_petals()
	_prepare_chime()

func ground_height(x: float, z: float) -> float:
	var height := 1.8 + sin(x * 0.065) * 1.8 + cos(z * 0.052) * 1.1
	height += sin((x + z) * 0.105) * 0.45
	height += 3.4 * smoothstep(4.0, 33.0, z)
	var lake_distance := Vector2((x + 22.0) / 11.5, (z + 8.0) / 9.0).length()
	height = lerpf(-0.30, height, smoothstep(0.72, 1.22, lake_distance))
	var pass_level := (1.0 - smoothstep(5.0, 12.0, absf(x))) * (1.0 - smoothstep(2.0, 9.0, absf(z + 34.0)))
	return lerpf(height, 2.1, pass_level)

func _toon(color: Color, vertex_color := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WORLD_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("use_vertex_color", vertex_color)
	return material

func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _mesh(mesh: Mesh, material: Material, at: Vector3, scale_value := Vector3.ONE, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.scale = scale_value
	parent.add_child(instance)
	return instance

func _lighting() -> void:
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4c9fc4")
	sky_material.sky_horizon_color = Color("c7e3db")
	sky_material.ground_bottom_color = Color("799872")
	sky_material.ground_horizon_color = Color("c7e3db")
	sky_material.sky_curve = 0.20
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cad7e7")
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("bed6d2")
	environment.fog_density = 0.0012
	environment.fog_sky_affect = 0.10
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_color = Color("fff0ce")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55
	sun.shadow_bias = 0.06
	add_child(sun)

func _path_distance(x: float, z: float) -> float:
	var route: Array[Vector2] = [Vector2(0, 40), Vector2(0, 25), Vector2(-4, 14), Vector2(-10, 5), Vector2(-2, 0), Vector2(10, -6), Vector2(4, -13), Vector2(-4, -19), Vector2(0, -28), Vector2(0, -43), Vector2(0, -56)]
	var point := Vector2(x, z)
	var result := 1000.0
	for i in range(route.size() - 1):
		var delta := route[i + 1] - route[i]
		var weight := clampf((point - route[i]).dot(delta) / delta.length_squared(), 0, 1)
		result = minf(result, point.distance_to(route[i] + delta * weight))
	return result

func _ground_color(x: float, z: float) -> Color:
	var patch := sin(x * 0.16 + sin(z * 0.07)) * cos(z * 0.12) * 0.5 + 0.5
	var color := Color("779759").lerp(Color("9dab65"), patch * 0.63)
	var path := 1.0 - smoothstep(1.25, 2.65, _path_distance(x, z) + sin(x * 2.0 + z) * 0.17)
	color = color.lerp(Color("c5b78b"), path * 0.92)
	var lake_distance := Vector2((x + 22) / 11.5, (z + 8) / 9.0).length()
	if lake_distance < 1.25:
		color = color.lerp(Color("b8b68c"), 1.0 - smoothstep(0.95, 1.25, lake_distance))
	return color

func _ground() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var resolution := 1.5
	var width := int(ceil((EAST - WEST) / resolution))
	var depth := int(ceil((SOUTH - NORTH) / resolution))
	for iz in range(depth):
		for ix in range(width):
			var x := WEST + ix * resolution
			var z := NORTH + iz * resolution
			for offset: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var px := minf(x + offset.x * resolution, EAST)
				var pz := minf(z + offset.y * resolution, SOUTH)
				surface.set_color(_ground_color(px, pz).srgb_to_linear())
				surface.set_uv(Vector2(px, pz) * 0.1)
				surface.add_vertex(Vector3(px, ground_height(px, pz), pz))
	surface.generate_normals()
	var instance := _mesh(surface.commit(), _toon(Color.WHITE, true), Vector3.ZERO)
	instance.name = "SculptedValleyTerrain"
	instance.create_trimesh_collision()
	for at: Vector3 in [Vector3(WEST, 12, -18), Vector3(EAST, 12, -18), Vector3(0, 12, SOUTH), Vector3(0, 12, NORTH)]:
		_box_collider(at, Vector3(2, 28, 125) if absf(at.x) > 1 else Vector3(90, 28, 2))

func _box_collider(at: Vector3, size: Vector3) -> CollisionShape3D:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return collision

func _batch(mesh: Mesh, material: Material, transforms: Array[Transform3D], shadows := false) -> MultiMeshInstance3D:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in range(transforms.size()):
		batch.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func _organic_mesh(seed_number: int, rings := 7, sides := 13) -> ArrayMesh:
	var local := RandomNumberGenerator.new()
	local.seed = seed_number
	var factors: Array[float] = []
	for i in range(sides):
		factors.append(local.randf_range(0.86, 1.12))
	var points: Array[PackedVector3Array] = []
	for ring in range(rings + 1):
		var row := PackedVector3Array()
		var t := float(ring) / rings
		var latitude := PI * t
		for side in range(sides):
			var angle := TAU * side / sides
			var radius := sin(latitude) * factors[side] * (1.0 + sin(angle * 3.0 + t * 4.0) * 0.055)
			row.append(Vector3(cos(angle) * radius, cos(latitude) * (0.52 + 0.06 * sin(angle * 2)), sin(angle) * radius))
		points.append(row)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(rings):
		for side in range(sides):
			var next := (side + 1) % sides
			for v: Vector3 in [points[ring][side], points[ring + 1][side], points[ring][next], points[ring][next], points[ring + 1][side], points[ring + 1][next]]:
				surface.add_vertex(v)
	surface.generate_normals()
	return surface.commit()

func _tube(points: Array[Vector3], radii: Array[float], sides := 9) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var direction := (points[i + 1] - points[i]).normalized()
		var cross := direction.cross(Vector3.FORWARD).normalized()
		if cross.length_squared() < 0.01:
			cross = Vector3.RIGHT
		var other := direction.cross(cross).normalized()
		for side in range(sides):
			var angle := TAU * side / sides
			var next := TAU * (side + 1) / sides
			var a := cross * cos(angle) + other * sin(angle)
			var b := cross * cos(next) + other * sin(next)
			for vertex: Vector3 in [points[i] + a * radii[i], points[i + 1] + a * radii[i + 1], points[i] + b * radii[i], points[i] + b * radii[i], points[i + 1] + a * radii[i + 1], points[i + 1] + b * radii[i + 1]]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()

func _horizon() -> void:
	# Continuous rolling silhouettes, rather than isolated triangular mountains.
	for layer in range(3):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var z := -126.0 - layer * 35.0
		for i in range(110):
			var x := -250.0 + i * 5.0
			var next := x + 5.0
			var height_a := _ridge_height(x, layer)
			var height_b := _ridge_height(next, layer)
			for vertex: Vector3 in [Vector3(x, -12, z), Vector3(x, height_a, z), Vector3(next, height_b, z), Vector3(x, -12, z), Vector3(next, height_b, z), Vector3(next, -12, z)]:
				surface.add_vertex(vertex)
		surface.generate_normals()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("719997").lerp(Color("b6d0c8"), layer * 0.26)
		_mesh(surface.commit(), material, Vector3.ZERO)
	var cloud_material := StandardMaterial3D.new()
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_material.albedo_color = Color("f5efde")
	var cloud_mesh := _organic_mesh(113, 5, 16)
	for i in range(12):
		var cloud := Node3D.new()
		cloud.position = Vector3(rng.randf_range(-160, 160), rng.randf_range(47, 65), rng.randf_range(-155, 15))
		for j in range(3):
			_mesh(cloud_mesh, cloud_material, Vector3(j * 8.0, sin(j * 1.7) * 1.4, j * 0.3), Vector3(10 + j * 2.0, 3.0 + j, 7.0), cloud)
		add_child(cloud)
		clouds.append(cloud)

func _ridge_height(x: float, layer: int) -> float:
	return 23.0 + layer * 7.0 + sin(x * 0.025 + layer * 1.4) * 12.0 + sin(x * 0.057 + layer * 2.2) * 7.0 + cos(x * 0.11 + layer) * 2.8

func _foliage_mesh(seed_number: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lobe in range(4):
		var angle := lobe * TAU / 3.0
		var offset := Vector3(cos(angle) * 0.34, 0.05 if lobe < 3 else 0.35, sin(angle) * 0.32)
		var scale := Vector3(0.84, 0.86, 0.80) if lobe < 3 else Vector3(0.7, 0.75, 0.7)
		surface.append_from(_organic_mesh(seed_number + lobe * 17, 5, 11), 0, Transform3D(Basis.IDENTITY.scaled(scale), offset))
	return surface.commit()

func _tree_trunk_mesh(variant: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lean := Vector3(sin(variant * 1.2) * 0.25, 0, cos(variant) * 0.25)
	surface.append_from(_tube([Vector3.ZERO, Vector3(0.1, 2.0, 0), Vector3(0, 4.0, 0) + lean, Vector3(0.1, 6.6, 0) + lean], [0.43, 0.30, 0.22, 0.06]), 0, Transform3D.IDENTITY)
	for branch in range(3):
		var angle := branch * TAU / 3.0 + variant * 0.4
		var tip := Vector3(cos(angle) * 1.5, 4.8 + branch * 0.8, sin(angle) * 1.5)
		surface.append_from(_tube([Vector3(0, 3.2 + branch * 0.4, 0), tip * Vector3(0.65, 0.85, 0.65), tip], [0.16, 0.10, 0.025], 7), 0, Transform3D.IDENTITY)
	return surface.commit()

func _make_tree(at: Vector3, size: float, variant: int, crowns: Array[Transform3D]) -> void:
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
	trunk_sets[variant % 4].append(Transform3D(basis, at))
	for branch in range(3):
		var angle := branch * TAU / 3.0 + (variant % 4) * 0.4
		var tip := Vector3(cos(angle) * 1.5, 4.8 + branch * 0.8, sin(angle) * 1.5)
		var position := at + (basis * (tip + Vector3.UP * 0.55))
		var crown_basis := basis.scaled(Vector3(2.1, 2.8, 1.95))
		crowns.append(Transform3D(crown_basis, position))
	crowns.append(Transform3D(basis.scaled(Vector3(2.3, 3.1, 2.15)), at + basis * Vector3(0, 7.1, 0)))
	var body := StaticBody3D.new()
	body.position = at + Vector3.UP * size * 2.4
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = size * 0.43
	shape.height = size * 4.8
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _trees() -> void:
	var crown_sets: Array = [[], [], []]
	var locations: Array[Vector2] = []
	for i in range(78):
		var x := rng.randf_range(-41, 41)
		var z := rng.randf_range(-73, 37)
		if _path_distance(x, z) < 5.5 or absf(z + 34) < 5.5 or Vector2((x + 22) / 14.0, (z + 8) / 12.0).length() < 1.0:
			continue
		if absf(x) < 15 and z > 3:
			continue
		locations.append(Vector2(x, z))
	for edge in range(35):
		locations.append(Vector2(-42 + (edge % 2) * 84, 36 - edge * 3.2))
	for i in range(locations.size()):
		var position := locations[i]
		var set: Array[Transform3D] = []
		_make_tree(Vector3(position.x, ground_height(position.x, position.y), position.y), rng.randf_range(0.85, 1.35), i, set)
		crown_sets[i % 3].append_array(set)
	var tints: Array[Color] = [Color("729b4e"), Color("86a95c"), Color("547f55")]
	for index in range(3):
		var set: Array[Transform3D] = []
		set.assign(crown_sets[index])
		_batch(_foliage_mesh(560 + index), _toon(tints[index]), set, true)
	for index in range(4):
		var transforms: Array[Transform3D] = []
		transforms.assign(trunk_sets[index])
		_batch(_tree_trunk_mesh(index), bark_material, transforms, true)

func _grass_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(4):
		var angle := blade * PI * 0.25
		var axis := Vector3(cos(angle), 0, sin(angle))
		var base := Vector3(sin(blade * 1.8) * 0.12, 0, cos(blade * 1.8) * 0.12)
		var tip := base + Vector3(0.08 * sin(blade), 0.44 + blade * 0.06, 0.06)
		var points: Array[Vector3] = [base - axis * 0.055, base + axis * 0.055, tip]
		for side in range(2):
			for v in range(3):
				var index := v if side == 0 else 2 - v
				surface.set_uv(Vector2(float(index) * 0.5, 1 if index == 2 else 0))
				surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()

func _meadow_details() -> void:
	var grasses: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	for i in range(7000):
		var x := rng.randf_range(WEST + 1, EAST - 1)
		var z := rng.randf_range(NORTH + 2, SOUTH - 2)
		if _path_distance(x, z) < 2.3 or ground_height(x, z) < 0.4:
			continue
		var height := rng.randf_range(0.7, 1.4)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(height, height, height))
		grasses.append(Transform3D(basis, Vector3(x, ground_height(x, z) - 0.015, z)))
		if i % 17 == 0:
			flowers.append(Transform3D(basis.scaled(Vector3.ONE * 0.20), Vector3(x, ground_height(x, z) + 0.29, z)))
	var grass_material := ShaderMaterial.new()
	grass_material.shader = GRASS_SHADER
	grass_material.set_shader_parameter("base_color", Color("6b914e"))
	grass_material.set_shader_parameter("tip_color", Color("93ab64"))
	_batch(_grass_mesh(), grass_material, grasses)
	_batch(_organic_mesh(921, 3, 6), _toon(Color("eadac8")), flowers)
	for i in range(70):
		var x := rng.randf_range(-41, 41)
		var z := rng.randf_range(-73, 38)
		if _path_distance(x, z) < 3:
			continue
		var size := Vector3(rng.randf_range(0.5, 2.1), rng.randf_range(0.5, 1.8), rng.randf_range(0.5, 1.8))
		rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(size), Vector3(x, ground_height(x, z) + 0.15, z)))
	_batch(_organic_mesh(127, 4, 7), stone_material, rocks, true)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 9, ground_height(side * 9, 24), 24)
		_mesh(_organic_mesh(411, 4, 8), stone_material, at, Vector3(3.5, 4, 2))

func _lake() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(-22, 0.43, -8)
	for i in range(80):
		var a := i * TAU / 80
		var b := (i + 1) * TAU / 80
		for point: Vector3 in [Vector3.ZERO, Vector3(cos(a) * 10.3, 0, sin(a) * 7.9), Vector3(cos(b) * 10.3, 0, sin(b) * 7.9)]:
			surface.set_uv(Vector2(point.x / 20.6 + 0.5, point.z / 15.8 + 0.5))
			surface.add_vertex(point)
	surface.generate_normals()
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	_mesh(surface.commit(), water, center)
	var reed := CylinderMesh.new()
	reed.top_radius = 0.018
	reed.bottom_radius = 0.028
	reed.height = 0.9
	reed.radial_segments = 5
	var reeds: Array[Transform3D] = []
	for i in range(120):
		var angle := rng.randf() * TAU
		var at := center + Vector3(cos(angle) * rng.randf_range(10.0, 11.1), 0, sin(angle) * rng.randf_range(7.8, 8.7))
		at.y = ground_height(at.x, at.z) + 0.4
		reeds.append(Transform3D(Basis.IDENTITY, at))
	_batch(reed, _toon(Color("909864")), reeds)
	for i in range(6):
		var at := Vector3(-15 - i * 1.25, 0.51, -5 + sin(i) * 0.8)
		_mesh(_organic_mesh(40 + i, 4, 8), stone_material, at, Vector3(1.0, 0.35, 0.8))
		_box_collider(at, Vector3(1.4, 0.35, 1.0))

func _gate() -> void:
	var foundation_y := ground_height(0, -34)
	for side: float in [-1.0, 1.0]:
		_box_collider(Vector3(side * 25, foundation_y + 8.0, -34), Vector3(42, 19, 5))
		for i in range(8):
			var x := side * (7.0 + i * 5.2)
			var height := 9.0 + sin(i * 1.3) * 1.8
			_mesh(_organic_mesh(730 + i, 5, 8), stone_material, Vector3(x, foundation_y + height * 0.38, -34), Vector3(4.7, height, 4.2))
			_mesh(_organic_mesh(860 + i, 5, 10), _toon(Color("748b57")), Vector3(x, foundation_y + height * 0.91, -34), Vector3(4.0, 0.9, 3.4))
	for side: float in [-1.0, 1.0]:
		for tier in range(4):
			var block := BoxMesh.new()
			block.size = Vector3(1.55 - tier * 0.08, 1.42, 2.2)
			_mesh(block, _toon(Color("b3b6a0")), Vector3(side * 4.4, foundation_y + tier * 1.48 + 0.72, -34))
		_box_collider(Vector3(side * 4.4, foundation_y + 3.0, -34), Vector3(1.6, 6.0, 2.2))
	for i in range(9):
		var angle := PI - i * PI / 8.0
		var block := BoxMesh.new()
		block.size = Vector3(1.6, 1.6, 2.2)
		var wedge := _mesh(block, _toon(Color("b3b6a0")), Vector3(cos(angle) * 4.4, foundation_y + 5.3 + sin(angle) * 2.0, -34))
		wedge.rotation.z = angle - PI / 2
	gate_slab = Node3D.new()
	gate_slab.position = Vector3(0, foundation_y, -34)
	add_child(gate_slab)
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(7.3, 6.8, 0.85)
	_mesh(slab_mesh, _toon(Color("738580")), Vector3(0, 3.35, 0), Vector3.ONE, gate_slab)
	for i in range(3):
		var seal := TorusMesh.new()
		seal.inner_radius = 0.32
		seal.outer_radius = 0.39
		seal.rings = 20
		seal.ring_segments = 6
		var mark := _mesh(seal, _toon(Color("c9c6a1")), Vector3((i - 1) * 1.55, 3.65, 0.45), Vector3.ONE, gate_slab)
		mark.rotation.x = PI / 2
	gate_collision = _box_collider(Vector3(0, foundation_y + 3.35, -34), Vector3(7.5, 6.8, 1.0))

func _sources() -> void:
	var locations: Array[Vector2] = [Vector2(-10, 5), Vector2(10, -6), Vector2(-4, -19)]
	var titles: Array[String] = ["Água", "Raiz", "Luz"]
	var colors: Array[Color] = [Color("86d6d9"), Color("9bc478"), Color("e6c57d")]
	for index in range(3):
		var spot := locations[index]
		var position := Vector3(spot.x, ground_height(spot.x, spot.y), spot.y)
		landmarks.append({"id": "source_%d" % index, "title": titles[index], "description": "Uma presença discreta responde à magia.", "position": position, "kind": "magic"})
		var root := Node3D.new()
		root.position = position
		add_child(root)
		source_nodes.append(root)
		var response := Node3D.new()
		response.name = "EnvironmentalResponse"
		response.visible = false
		response.scale = Vector3.ONE * 0.001
		root.add_child(response)
		response_nodes.append(response)
		var material := _glow(colors[index].darkened(0.25), 0.20)
		source_materials.append(material)
		_mesh(_organic_mesh(30 + index, 4, 9), stone_material, Vector3(0, 0.15, 0), Vector3(1.7, 0.55, 1.4), root)
		if index == 0:
			var bowl := TorusMesh.new()
			bowl.inner_radius = 0.5
			bowl.outer_radius = 0.66
			bowl.rings = 24
			bowl.ring_segments = 7
			_mesh(bowl, stone_material, Vector3(0, 0.52, 0), Vector3(1, 0.7, 1), root)
			var water := CylinderMesh.new()
			water.top_radius = 0.53
			water.bottom_radius = 0.53
			water.height = 0.08
			_mesh(water, material, Vector3(0, 0.56, 0), Vector3.ONE, root)
			for jet in range(4):
				var angle := jet * TAU / 4
				var end := Vector3(cos(angle) * 0.8, 0.7, sin(angle) * 0.8)
				_mesh(_tube([Vector3(0, 0.65, 0), Vector3(0, 1.4, 0), end * Vector3(0.4, 0.9, 0.4) + Vector3.UP * 1.0, end], [0.07, 0.06, 0.045, 0.02], 6), _glow(Color("91e6e3"), 0.35), Vector3.ZERO, Vector3.ONE, response)
		elif index == 1:
			for branch in range(5):
				var angle := branch * TAU / 5
				_mesh(_tube([Vector3(cos(angle) * 0.9, 0.3, sin(angle) * 0.9), Vector3(cos(angle) * 0.35, 0.8, sin(angle) * 0.35), Vector3(0, 1.15, 0)], [0.13, 0.09, 0.04], 7), _toon(Color("7f9260")), Vector3.ZERO, Vector3.ONE, root)
			for branch in range(7):
				var angle := branch * TAU / 7
				var tip := Vector3(cos(angle) * 2.5, 0.16, sin(angle) * 2.5)
				_mesh(_tube([Vector3(0, 0.25, 0), tip * 0.45 + Vector3.UP * 0.25, tip], [0.19, 0.12, 0.015], 7), _toon(Color("6e9951")), Vector3.ZERO, Vector3.ONE, response)
				_mesh(_organic_mesh(700 + branch, 4, 7), _toon(Color("a5bd69")), tip + Vector3.UP * 0.18, Vector3(0.35, 0.25, 0.85), response)
		else:
			var stem := CylinderMesh.new()
			stem.top_radius = 0.04
			stem.bottom_radius = 0.09
			stem.height = 1.15
			stem.radial_segments = 7
			_mesh(stem, _toon(Color("5e8e66")), Vector3(0, 0.78, 0), Vector3.ONE, root)
			for i in range(8):
				var angle := i * TAU / 8.0
				var leaf := _mesh(_organic_mesh(90 + i, 4, 8), material, Vector3(cos(angle) * 0.38, 1.25, sin(angle) * 0.38), Vector3(0.38, 0.25, 0.72), root)
				leaf.rotation.y = -angle
			for ray in range(9):
				var angle := ray * TAU / 9
				var beam := _mesh(_organic_mesh(810, 4, 7), _glow(Color("f6dc9c"), 0.65), Vector3(cos(angle) * 0.72, 1.43, sin(angle) * 0.72), Vector3(0.19, 0.12, 0.85), response)
				beam.rotation.y = -angle
		var gem := _mesh(_organic_mesh(520, 4, 6), material, Vector3(0, 1.5, 0), Vector3(0.27, 0.45, 0.27), root)
		source_cores.append(gem)
		var light := OmniLight3D.new()
		light.position = Vector3(0, 1.5, 0)
		light.light_color = colors[index]
		light.light_energy = 0.35
		light.omni_range = 4.0
		root.add_child(light)
		source_lights.append(light)
		for step in range(index + 1):
			var circle := TorusMesh.new()
			circle.inner_radius = 0.22
			circle.outer_radius = 0.26
			circle.rings = 16
			circle.ring_segments = 5
			var mark := _mesh(circle, _toon(Color("e5dbb5")), Vector3((step - index * 0.5) * 0.65, 0.43, 0.60), Vector3.ONE, root)
			mark.rotation.x = PI / 2.5
	flower = source_nodes[0]
	flower_position = landmarks[0]["position"]
	flower_light = source_lights[0]
	destination_position = Vector3(0, ground_height(0, -55), -55)

func _inscription() -> void:
	inscription_position = Vector3(0, ground_height(0, 14), 14)
	_mesh(_organic_mesh(210, 4, 8), stone_material, inscription_position + Vector3(0, 0.4, 0), Vector3(1.1, 1.5, 0.8))
	# Three simple seals communicate a puzzle without assigning religious meaning.
	for i in range(3):
		var circle := TorusMesh.new()
		circle.inner_radius = 0.10
		circle.outer_radius = 0.15
		circle.rings = 16
		circle.ring_segments = 5
		var mark := _mesh(circle, gold, inscription_position + Vector3((i - 1) * 0.37, 0.96, 0.40))
		mark.rotation.x = PI / 2

func _sanctuary() -> void:
	var at := Vector3(0, ground_height(0, -63), -63)
	var tree := Node3D.new()
	tree.position = at
	add_child(tree)
	_mesh(_tube([Vector3.ZERO, Vector3(-0.8, 3, 0.3), Vector3(-0.2, 7, 0.5), Vector3(0.4, 10.5, 0)], [1.8, 1.45, 0.85, 0.35], 13), bark_material, Vector3.ZERO, Vector3.ONE, tree)
	for root in range(7):
		var angle := root * TAU / 7.0
		var end := Vector3(cos(angle) * 4.2, 0.05, sin(angle) * 4.2)
		_mesh(_tube([Vector3(0, 1.6, 0), end * 0.55 + Vector3.UP * 0.25, end], [0.65, 0.4, 0.02], 8), bark_material, Vector3.ZERO, Vector3.ONE, tree)
	var crowns: Array[Transform3D] = []
	for branch in range(6):
		var angle := branch * TAU / 6.0
		var end := Vector3(cos(angle) * 5.0, 10.0 + sin(angle * 2.0), sin(angle) * 4.1)
		_mesh(_tube([Vector3(0, 6.5, 0), end * Vector3(0.55, 0.86, 0.55), end], [0.65, 0.36, 0.12], 10), bark_material, Vector3.ZERO, Vector3.ONE, tree)
		crowns.append(Transform3D(Basis.IDENTITY.scaled(Vector3(4.8, 3.3, 4.1)), at + end + Vector3.UP * 1.4))
	crowns.append(Transform3D(Basis.IDENTITY.scaled(Vector3(6.0, 3.4, 5.6)), at + Vector3(0, 13, 0)))
	_batch(_organic_mesh(881), _toon(Color("b2b76e")), crowns, true)
	_box_collider(at + Vector3.UP * 4, Vector3(2.8, 8, 2.5))
	for i in range(7):
		var angle := i * TAU / 7
		_mesh(_organic_mesh(165 + i, 4, 9), _toon(Color("b8b9a1")), destination_position + Vector3(cos(angle) * 4.2, 0.15, sin(angle) * 3.4), Vector3(0.9, 0.5, 0.7))

func _floating_petals() -> void:
	var origins: Array[Transform3D] = []
	for i in range(75):
		var at := Vector3(rng.randf_range(-25, 25), rng.randf_range(2.0, 5.5), rng.randf_range(-64, 30))
		at.y += ground_height(at.x, at.z)
		leaf_origins.append(at)
		origins.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.08, 0.04, 0.14)), at))
	floating_leaves = _batch(_organic_mesh(37, 3, 5), _toon(Color("e6c78d")), origins)

func _process(delta: float) -> void:
	elapsed += delta
	for i in range(source_cores.size()):
		source_cores[i].rotation.y = elapsed * 0.35 + i
		source_cores[i].position.y = 1.5 + sin(elapsed * 1.5 + i) * 0.09
		source_lights[i].light_energy = (1.3 if active_landmarks[i] else 0.35) + sin(elapsed * 1.3 + i) * 0.08
	for i in range(leaf_origins.size()):
		var at := leaf_origins[i] + Vector3(sin(elapsed * 0.18 + i) * 1.4, sin(elapsed * 0.6 + i) * 0.2, cos(elapsed * 0.15 + i) * 0.8)
		var basis := Basis(Vector3.UP, elapsed * 0.3 + i).scaled(Vector3(0.08, 0.04, 0.14))
		floating_leaves.multimesh.set_instance_transform(i, Transform3D(basis, at))
	for cloud in clouds:
		cloud.position.x += delta * 0.15

func magic_wave(at: Vector3) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.90
	ring.outer_radius = 0.96
	ring.rings = 32
	ring.ring_segments = 5
	var pulse := _mesh(ring, mint, Vector3(at.x, ground_height(at.x, at.z) + 0.15, at.z), Vector3.ONE * 0.2)
	pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := create_tween()
	tween.tween_property(pulse, "scale", Vector3(4, 0.2, 4), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(pulse.queue_free)

func activate_landmark(index: int) -> void:
	if index < 0 or index >= source_nodes.size() or active_landmarks[index]:
		return
	active_landmarks[index] = true
	if index == 0:
		awakened = true
	source_materials[index].emission_energy_multiplier = 1.8
	source_materials[index].albedo_color = source_materials[index].albedo_color.lightened(0.3)
	response_nodes[index].visible = true
	var tween := create_tween().set_parallel(true)
	source_tweens.append(tween)
	tween.tween_property(response_nodes[index], "scale", Vector3.ONE, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(source_nodes[index], "scale", Vector3.ONE * 1.18, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	magic_wave(source_nodes[index].global_position)
	chime.pitch_scale = 1.0 + index * 0.125
	if DisplayServer.get_name() != "headless":
		chime.play()

func reset_landmarks() -> void:
	for tween in source_tweens:
		if tween and tween.is_valid():
			tween.kill()
	source_tweens.clear()
	active_landmarks = [false, false, false]
	awakened = false
	var colors: Array[Color] = [Color("86d6d9"), Color("9bc478"), Color("e6c57d")]
	for i in range(source_nodes.size()):
		source_nodes[i].scale = Vector3.ONE
		response_nodes[i].visible = false
		response_nodes[i].scale = Vector3.ONE * 0.001
		source_materials[i].emission_energy_multiplier = 0.20
		source_materials[i].albedo_color = colors[i].darkened(0.25)
	set_gate_open(false)

func set_gate_open(value: bool) -> void:
	gate_open = value
	if gate_tween and gate_tween.is_valid():
		gate_tween.kill()
	gate_collision.set_deferred("disabled", value)
	if value:
		gate_tween = create_tween()
		gate_tween.tween_property(gate_slab, "position:y", ground_height(0, -34) + 7.5, 2.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		gate_slab.position.y = ground_height(0, -34)

func awaken_flower() -> void:
	activate_landmark(0)

func reset_flower() -> void:
	reset_landmarks()

func _prepare_chime() -> void:
	var samples := 26460
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var seconds := float(i) / 22050.0
		var envelope := minf(seconds * 30.0, 1.0) * exp(-seconds * 4.0)
		var wave := sin(TAU * 523.25 * seconds) + sin(TAU * 659.25 * seconds) * 0.5 + sin(TAU * 783.99 * seconds) * 0.3
		bytes.encode_s16(i * 2, int(wave * envelope * 5000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	chime = AudioStreamPlayer.new()
	chime.stream = stream
	chime.volume_db = -8.0
	add_child(chime)
