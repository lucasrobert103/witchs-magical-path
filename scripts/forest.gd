extends Node3D
## Procedural mobile-scale clearing. Scenery is a visual proposal, not canon.

var flower_position := Vector3(0, 0, -6)
var flower: Node3D
var flower_light: OmniLight3D
var awakened := false
var elapsed := 0.0
var motes: MultiMeshInstance3D
var mote_origins: Array[Vector3] = []
var petals: Array[MeshInstance3D] = []
var rng := RandomNumberGenerator.new()
var gold: StandardMaterial3D
var mint: StandardMaterial3D
var flower_tween: Tween
var chime: AudioStreamPlayer


func _ready() -> void:
	rng.seed = 731098
	_lighting()
	_ground()
	_vegetation()
	_flower()
	_fireflies()
	_prepare_chime()


func _material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.93
	if emission > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


func _mesh(mesh: Mesh, material: Material, at: Vector3, scale_value := Vector3.ONE, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.scale = scale_value
	parent.add_child(instance)
	return instance


func _ball(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 5
	return mesh


func _lighting() -> void:
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("191c37")
	sky_material.sky_horizon_color = Color("827c9a")
	sky_material.ground_bottom_color = Color("182e32")
	sky_material.ground_horizon_color = Color("827c9a")
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a7c7ce")
	environment.ambient_light_energy = 0.40
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("637c89")
	environment.fog_density = 0.008
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -32, 0)
	sun.light_color = Color("ffe3b4")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 35
	add_child(sun)
	gold = _material(Color("f3d7a0"), 1.8)
	mint = _material(Color("8ceac7"), 1.2)


func _ground() -> void:
	var ground := _material(Color("294b46"))
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	_mesh(plane, ground, Vector3.ZERO)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(90, 0.2, 90)
	collision.shape = box
	collision.position.y = -0.1
	body.add_child(collision)
	add_child(body)
	# Boundary collision keeps the explorable prototype contained in its clearing.
	for at: Vector3 in [Vector3(-25, 2, 0), Vector3(25, 2, 0), Vector3(0, 2, -25), Vector3(0, 2, 25)]:
		var wall := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(1, 5, 52) if absf(at.x) > 0 else Vector3(52, 5, 1)
		shape.shape = wall_box
		wall.position = at
		wall.add_child(shape)
		add_child(wall)
	var path_material := _material(Color("526458"))
	var patch := CylinderMesh.new()
	patch.top_radius = 1.7
	patch.bottom_radius = 1.7
	patch.height = 0.014
	patch.radial_segments = 16
	for i in range(15):
		var z := 10.0 - i * 1.25
		_mesh(patch, path_material, Vector3(sin(i * 0.3) * 0.65, 0.008, z), Vector3(0.9, 1, 0.62))
	# Low islands of moss interrupt a flat silhouette without expensive terrain.
	var moss := _material(Color("355b4c"))
	for i in range(65):
		var at := Vector3(rng.randf_range(-28, 28), -0.23, rng.randf_range(-28, 28))
		if absf(at.x) < 2.4 and at.z > -10 and at.z < 12:
			continue
		_mesh(_ball(1, 1), moss, at, Vector3(rng.randf_range(1, 3), rng.randf_range(0.6, 1.2), rng.randf_range(1, 3)))


func _batch(mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in range(transforms.size()):
		batch.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.material_override = material
	add_child(instance)


func _vegetation() -> void:
	var trunks: Array[Transform3D] = []
	var crowns_a: Array[Transform3D] = []
	var crowns_b: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	var grasses: Array[Transform3D] = []
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.38
	trunk.height = 1
	trunk.radial_segments = 7
	for i in range(155):
		var at := Vector3(rng.randf_range(-38, 38), 0, rng.randf_range(-38, 38))
		if Vector2(at.x, at.z + 1).length() < 12:
			continue
		var height := rng.randf_range(5.0, 10.0)
		trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, height, 1.0)), at + Vector3.UP * height * 0.5))
		for branch in range(3):
			var crown_at := at + Vector3(rng.randf_range(-1.2, 1.2), height - 0.4 + branch * 0.65, rng.randf_range(-1.2, 1.2))
			var size := Vector3(rng.randf_range(2.0, 3.1), rng.randf_range(1.8, 2.8), rng.randf_range(2.0, 3.1))
			var transform := Transform3D(Basis.IDENTITY.scaled(size), crown_at)
			if i % 3 == 0:
				crowns_b.append(transform)
			else:
				crowns_a.append(transform)
		# Only nearby trunks need physical collisions.
		if at.length() < 28:
			var tree_body := StaticBody3D.new()
			var tree_shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 0.39
			cylinder.height = height
			tree_shape.shape = cylinder
			tree_body.position = at + Vector3.UP * height * 0.5
			tree_body.add_child(tree_shape)
			add_child(tree_body)
	_batch(trunk, _material(Color("51434a")), trunks)
	_batch(_ball(1, 1.7), _material(Color("356b60")), crowns_a)
	_batch(_ball(1, 1.7), _material(Color("506a75")), crowns_b)
	for i in range(85):
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(11, 28)
		var at := Vector3(cos(angle) * distance, 0.25, sin(angle) * distance)
		var size := Vector3(rng.randf_range(0.4, 1.5), rng.randf_range(0.5, 1.4), rng.randf_range(0.5, 1.3))
		stones.append(Transform3D(Basis(Vector3.UP, angle).scaled(size), at))
	_batch(_ball(1, 1.5), _material(Color("647678")), stones)
	var blade := PrismMesh.new()
	blade.size = Vector3(0.19, 0.65, 0.11)
	for i in range(1100):
		var at := Vector3(rng.randf_range(-27, 27), 0.22, rng.randf_range(-27, 27))
		if absf(at.x) < 2.2 and at.z > -9 and at.z < 12:
			continue
		var size := rng.randf_range(0.6, 1.4)
		grasses.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), at))
	_batch(blade, _material(Color("649278")), grasses)
	# A few warm flowers frame the route; no specific fictional species is named.
	var flowers: Array[Transform3D] = []
	for i in range(95):
		var at := Vector3(rng.randf_range(-15, 15), 0.16, rng.randf_range(-17, 15))
		flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.05, 0.10)), at))
	_batch(_ball(1, 1.2), _material(Color("e8b4bf"), 0.4), flowers)


func _flower() -> void:
	flower = Node3D.new()
	flower.position = flower_position
	add_child(flower)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.045
	stem.bottom_radius = 0.07
	stem.height = 1.1
	stem.radial_segments = 7
	_mesh(stem, _material(Color("69ad91")), Vector3(0, 0.55, 0), Vector3.ONE, flower)
	for i in range(7):
		var angle := i * TAU / 7
		var petal := _mesh(_ball(0.34, 0.28), mint, Vector3(cos(angle) * 0.32, 1.12, sin(angle) * 0.32), Vector3(1, 1, 1.5), flower)
		petal.rotation.y = -angle
		petals.append(petal)
	_mesh(_ball(0.20, 0.30), gold, Vector3(0, 1.19, 0), Vector3.ONE, flower)
	for i in range(4):
		var leaf := _mesh(_ball(0.23, 0.10), _material(Color("7ebaa0")), Vector3(0.19 if i % 2 == 0 else -0.19, 0.25 + i * 0.15, 0), Vector3(1.4, 1, 0.7), flower)
		leaf.rotation.z = 0.4 if i % 2 == 0 else -0.4
	flower_light = OmniLight3D.new()
	flower_light.position = Vector3(0, 1.6, 0)
	flower_light.light_color = Color("b5ffdc")
	flower_light.light_energy = 1.5
	flower_light.omni_range = 5.5
	flower.add_child(flower_light)
	var ring_material := _material(Color("516b66"))
	for i in range(12):
		var angle := i * TAU / 12
		_mesh(_ball(0.23, 0.22), ring_material, flower_position + Vector3(cos(angle) * 1.7, 0.07, sin(angle) * 1.7))


func _fireflies() -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = _ball(0.028, 0.056)
	batch.instance_count = 75
	for i in range(batch.instance_count):
		var at := Vector3(rng.randf_range(-13, 13), rng.randf_range(0.5, 3.3), rng.randf_range(-16, 12))
		if i < 15:
			at = Vector3(sin(i * 1.8) * 0.9, 0.5 + (i % 3) * 0.15, 7.0 - i * 0.85)
		mote_origins.append(at)
		batch.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
	motes = MultiMeshInstance3D.new()
	motes.multimesh = batch
	motes.material_override = gold
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)


func _process(delta: float) -> void:
	elapsed += delta
	flower.rotation.y = sin(elapsed * 0.5) * 0.12
	flower_light.light_energy = (2.5 if awakened else 1.5) + sin(elapsed * 1.7) * 0.25
	for i in range(mote_origins.size()):
		var at := mote_origins[i] + Vector3(sin(elapsed * 0.6 + i) * 0.25, sin(elapsed + i * 0.6) * 0.15, cos(elapsed * 0.5 + i) * 0.2)
		motes.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))


func magic_wave(at: Vector3) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 0.94
	ring.rings = 24
	ring.ring_segments = 6
	var pulse := _mesh(ring, mint, Vector3(at.x, 0.10, at.z), Vector3.ONE * 0.15)
	pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tween := create_tween()
	tween.tween_property(pulse, "scale", Vector3(4, 0.15, 4), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(pulse.queue_free)


func awaken_flower() -> void:
	awakened = true
	flower_tween = create_tween().set_parallel(true)
	flower_tween.tween_property(flower, "scale", Vector3.ONE * 1.55, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for petal in petals:
		flower_tween.tween_property(petal, "position:y", 1.25, 0.9)
	magic_wave(flower_position)
	chime.play()


func reset_flower() -> void:
	if flower_tween and flower_tween.is_valid():
		flower_tween.kill()
	awakened = false
	flower.scale = Vector3.ONE
	for petal in petals:
		petal.position.y = 1.12


func _prepare_chime() -> void:
	# A short original synthesized chord provides feedback without external assets.
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
