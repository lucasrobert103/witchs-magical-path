extends Node3D
## Original anime study for Asterion: silhouette, eyes, curls and tailored shapes.
## This temporary exploration outfit is NOT the unavailable approved costume.

const TOON = preload("res://shaders/character_toon.gdshader")
var left_arm: Node3D
var right_arm: Node3D
var left_forearm: Node3D
var right_forearm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_shin: Node3D
var right_shin: Node3D
var hair_root: Node3D
var skirt: Node3D
var mantle: Node3D
var magic: Node3D
var clock := 0.0
var gait := 0.0
var materials: Dictionary = {}
var outline: ShaderMaterial


func _ready() -> void:
	name = "AsterionAnimeStudy"
	_make_materials()
	_build_body()
	_build_face()
	_build_hair()
	_build_magic()


func _make_materials() -> void:
	var line_shader := Shader.new()
	line_shader.code = "shader_type spatial; render_mode unshaded, cull_front; void vertex(){VERTEX += NORMAL * 0.0045;} void fragment(){ALBEDO=vec3(0.052,0.039,0.052);}"
	outline = ShaderMaterial.new()
	outline.shader = line_shader
	for item: Array in [
		["skin", "ad7452"], ["skin_shadow", "80513d"], ["hair", "3d2924"], ["hair_light", "644532"],
		["cloth", "dcd6bb"], ["cloth_shadow", "a5bba2"], ["forest", "355e57"], ["forest_light", "588779"],
		["leather", "493b39"], ["gold", "c9a365"], ["black", "281d27"], ["white", "fff4df"],
		["amber", "e7ad43"], ["amber_dark", "815023"], ["lip", "713f3e"]
	]:
		var mat := ShaderMaterial.new()
		mat.shader = TOON
		mat.set_shader_parameter("base_color", Color(item[1]))
		if item[0] not in ["black", "white", "amber", "amber_dark", "lip", "gold", "hair_light"]:
			mat.next_pass = outline
		materials[item[0]] = mat


func _node(parent: Node3D, at := Vector3.ZERO) -> Node3D:
	var result := Node3D.new()
	result.position = at
	parent.add_child(result)
	return result


func _add(mesh: Mesh, material: Material, parent: Node3D, at := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _loft(profile: Array[Vector4], sides := 24, pleats := 0.0) -> ArrayMesh:
	# Each ring: height, X radius, Z radius, Z centre; one continuous fitted surface.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(profile.size() - 1):
		for segment in range(sides):
			var angle0 := float(segment) / sides * TAU
			var angle1 := float(segment + 1) / sides * TAU
			var p0 := _ring_point(profile[row], angle0, pleats)
			var p1 := _ring_point(profile[row], angle1, pleats)
			var p2 := _ring_point(profile[row + 1], angle0, pleats)
			var p3 := _ring_point(profile[row + 1], angle1, pleats)
			for point: Vector3 in [p0, p2, p1, p1, p2, p3]:
				tool.set_smooth_group(0)
				tool.add_vertex(point)
	tool.generate_normals()
	tool.index()
	return tool.commit()


func _ring_point(ring: Vector4, angle: float, pleats: float) -> Vector3:
	var ripple := 1.0 + sin(angle * 10.0) * pleats
	return Vector3(sin(angle) * ring.y * ripple, ring.x, cos(angle) * ring.z * ripple + ring.w)


func _tube(points: Array[Vector3], radii: Array[float], sides := 8) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_tube(tool, points, radii, sides)
	tool.generate_normals()
	tool.index()
	return tool.commit()


func _append_tube(tool: SurfaceTool, points: Array[Vector3], radii: Array[float], sides := 8) -> void:
	for row in range(points.size() - 1):
		var tangent0 := (points[mini(row + 1, points.size() - 1)] - points[maxi(row - 1, 0)]).normalized()
		var tangent1 := (points[mini(row + 2, points.size() - 1)] - points[row]).normalized()
		var side0 := tangent0.cross(Vector3.FORWARD).normalized()
		var side1 := tangent1.cross(Vector3.FORWARD).normalized()
		if side0.length_squared() < 0.01:
			side0 = Vector3.RIGHT
		if side1.length_squared() < 0.01:
			side1 = Vector3.RIGHT
		var up0 := tangent0.cross(side0).normalized()
		var up1 := tangent1.cross(side1).normalized()
		for segment in range(sides):
			var a := float(segment) / sides * TAU
			var b := float(segment + 1) / sides * TAU
			var p0 := points[row] + (cos(a) * side0 + sin(a) * up0) * radii[row]
			var p1 := points[row] + (cos(b) * side0 + sin(b) * up0) * radii[row]
			var p2 := points[row + 1] + (cos(a) * side1 + sin(a) * up1) * radii[row + 1]
			var p3 := points[row + 1] + (cos(b) * side1 + sin(b) * up1) * radii[row + 1]
			for point: Vector3 in [p0, p1, p2, p1, p3, p2]:
				tool.set_smooth_group(0)
				tool.add_vertex(point)


func _build_body() -> void:
	# The fitted bodice is a single custom mesh, with a waist, shoulders and chest.
	_add(_loft([
		Vector4(0.95, .205, .143, .025), Vector4(1.05, .19, .13, .015),
		Vector4(1.20, .159, .116, 0), Vector4(1.33, .192, .153, -.014),
		Vector4(1.44, .225, .155, -.015), Vector4(1.50, .255, .121, .0),
		Vector4(1.545, .178, .104, 0), Vector4(1.57, .082, .077, .0)
	]), materials.cloth, self)
	_add(_loft([Vector4(1.52, .075, .068, 0), Vector4(1.64, .071, .064, 0)]), materials.skin, self)
	skirt = _node(self)
	_add(_loft([
		Vector4(.67, .345, .231, .025), Vector4(.78, .323, .219, .025),
		Vector4(.94, .268, .18, .015), Vector4(1.08, .183, .137, .0)
	], 40, .025), materials.forest, skirt)
	# Hem is a separate continuous embroidered band, not disconnected body spheres.
	_add(_loft([Vector4(.672, .35, .235, .025), Vector4(.707, .346, .233, .025)], 40, .025), materials.gold, skirt)
	_add(_loft([Vector4(1.052, .189, .142, .0), Vector4(1.106, .183, .138, .0)], 32), materials.leather, self)
	# Brass buckle and a small folded satchel provide a deliberate explorer silhouette.
	_add(_loft([Vector4(1.062, .041, .016, -.152), Vector4(1.096, .041, .016, -.152)]), materials.gold, self)
	var pouch := _node(self, Vector3(.235, 1.0, .015))
	pouch.rotation.z = -.1
	_add(_loft([Vector4(-.18, .08, .05, 0), Vector4(-.15, .105, .065, 0), Vector4(.01, .095, .06, 0), Vector4(.025, .07, .04, 0)]), materials.leather, pouch)
	_add(_loft([Vector4(-.025, .10, .065, -.01), Vector4(.015, .09, .064, -.01)]), materials.gold, pouch)
	# Fitted upper sleeves and jointed forearms. Local negative Y is the limb axis.
	left_arm = _arm(-1.0)
	right_arm = _arm(1.0)
	left_leg = _leg(-1.0)
	right_leg = _leg(1.0)
	# Shoulder mantle falls in two tailored panels, leaving the waist-length curls visible.
	mantle = _node(self)
	for side: float in [-1.0, 1.0]:
		var mantle_points: Array[Vector3] = [Vector3(side * .075, 1.55, .025), Vector3(side * .24, 1.53, .04), Vector3(side * .30, 1.39, .095), Vector3(side * .19, 1.34, .14), Vector3(side * .12, 1.46, .11)]
		_add(_panel(mantle_points), materials.forest_light, mantle)
		_add(_tube([mantle_points[0], mantle_points[1], mantle_points[2]], [.008, .008, .006], 5), materials.gold, mantle)
	# A small neck clasp draws the eye toward the face.
	_add(_loft([Vector4(1.475, .020, .012, -.117), Vector4(1.516, .028, .014, -.117), Vector4(1.54, .008, .008, -.117)], 10), materials.gold, self)


func _arm(side: float) -> Node3D:
	var arm := _node(self, Vector3(side * .252, 1.485, 0))
	_add(_loft([
		Vector4(-.295, .063, .065, 0), Vector4(-.20, .076, .081, 0),
		Vector4(-.07, .09, .09, 0), Vector4(.015, .071, .075, 0)
	], 20), materials.cloth, arm)
	_add(_loft([Vector4(-.292, .067, .069, 0), Vector4(-.26, .069, .072, 0)], 20), materials.forest_light, arm)
	var forearm := _node(arm, Vector3(0, -.28, 0))
	if side < 0:
		left_forearm = forearm
	else:
		right_forearm = forearm
	_add(_loft([Vector4(-.255, .039, .037, 0), Vector4(-.16, .05, .052, 0), Vector4(-.055, .059, .06, 0), Vector4(.015, .058, .057, 0)]), materials.skin, forearm)
	# Tapered wrist bracer with open skin hand and individually curved fingers.
	_add(_loft([Vector4(-.225, .047, .045, 0), Vector4(-.125, .052, .052, 0)], 16), materials.leather, forearm)
	_add(_loft([Vector4(-.219, .049, .047, 0), Vector4(-.207, .049, .047, 0)], 16), materials.gold, forearm)
	_add(_loft([Vector4(-.337, .033, .022, -.005), Vector4(-.285, .048, .025, -.005), Vector4(-.245, .035, .029, 0)], 16), materials.skin, forearm)
	for finger in range(4):
		var x := (float(finger) - 1.5) * .017
		var length := .061 if finger in [1, 2] else .048
		_add(_tube([Vector3(x, -.322, -.006), Vector3(x, -.344 - length * .4, -.012), Vector3(x, -.337 - length, -.027)], [.011, .010, .005], 6), materials.skin, forearm)
	_add(_tube([Vector3(-side * .037, -.286, -.006), Vector3(-side * .060, -.309, -.015), Vector3(-side * .060, -.33, -.032)], [.015, .013, .006], 6), materials.skin, forearm)
	return arm


func _leg(side: float) -> Node3D:
	var leg := _node(self, Vector3(side * .122, .97, .015))
	_add(_loft([Vector4(-.42, .075, .076, 0), Vector4(-.29, .093, .093, 0), Vector4(-.08, .114, .116, 0), Vector4(.015, .11, .105, 0)]), materials.skin, leg)
	var shin := _node(leg, Vector3(0, -.405, 0))
	if side < 0:
		left_shin = shin
	else:
		right_shin = shin
	# Boots have a tapered shaft, angled instep and toe volume built into their profile.
	_add(_loft([
		Vector4(-.485, .075, .143, -.045), Vector4(-.45, .081, .146, -.047),
		Vector4(-.38, .073, .11, -.025), Vector4(-.29, .063, .074, .012),
		Vector4(-.12, .077, .083, .015), Vector4(.022, .085, .085, 0)
	], 24), materials.leather, shin)
	_add(_loft([Vector4(.003, .091, .090, 0), Vector4(.04, .089, .088, 0)], 24), materials.forest_light, shin)
	_add(_loft([Vector4(-.487, .080, .147, -.045), Vector4(-.467, .084, .150, -.046)], 24), materials.black, shin)
	# Two slim laces, sewn into the front shaft.
	for i in range(3):
		var y := -.08 - float(i) * .05
		_add(_tube([Vector3(-.035, y, -.076), Vector3(.035, y - .025, -.078)], [.004, .004], 5), materials.gold, shin)
	return leg


func _build_face() -> void:
	_add(_loft([
		Vector4(1.59, .035, .055, -.015), Vector4(1.625, .10, .10, -.025),
		Vector4(1.685, .161, .139, -.020), Vector4(1.765, .192, .159, -.012),
		Vector4(1.85, .191, .165, -.002), Vector4(1.945, .158, .145, .010),
		Vector4(2.00, .10, .095, .02), Vector4(2.017, .004, .004, .02)
	], 40), materials.skin, self)
	for side: float in [-1.0, 1.0]:
		var eye := _node(self, Vector3(side * .090, 1.785, -.166))
		eye.rotation.y = -side * .28
		# Black almond underlay and warm white inside: a graphic anime eye, not spheres.
		var almond: Array[Vector2] = [Vector2(-.068, -.003), Vector2(-.043, .034), Vector2(-.008, .046), Vector2(.029, .041), Vector2(.066, .010), Vector2(.044, -.022), Vector2(.005, -.029), Vector2(-.036, -.022)]
		_add(_face_patch(almond, 1.09, 0), materials.black, eye)
		_add(_face_patch(almond, 0.94, -.002), materials.white, eye)
		_add(_ellipse(.029, .034, -.004, 24), materials.amber_dark, eye, Vector3(0, .003, 0))
		_add(_ellipse(.026, .031, -.006, 24), materials.amber, eye, Vector3(0, .002, 0))
		_add(_ellipse(.015, .021, -.008, 20), materials.black, eye, Vector3(0, .009, 0))
		_add(_ellipse(.009, .012, -.010, 14), materials.white, eye, Vector3(-.009, .022, 0))
		_add(_ellipse(.004, .005, -.011, 10), materials.white, eye, Vector3(.011, -.010, 0))
		# Winged outer lash and naturally arched eyebrow.
		var lash := _node(eye)
		lash.scale.x = side
		_add(_panel([Vector3(.039, .038, -.005), Vector3(.076, .037, -.004), Vector3(.092, .049, -.003), Vector3(.066, .010, -.005)]), materials.black, lash)
		_add(_tube([Vector3(-.053, .080, .003), Vector3(-.012, .087, -.006), Vector3(.042, .077, .002)], [.008, .010, .004], 6), materials.hair, eye)
		# Small ears sit behind curls; their interior is shaped with a narrow inset.
		var ear := _node(self, Vector3(side * .187, 1.752, .002))
		_add(_loft([Vector4(-.048, .015, .021, 0), Vector4(-.02, .034, .025, 0), Vector4(.035, .029, .023, 0), Vector4(.05, .01, .01, 0)], 16), materials.skin, ear)
	# Nose is a compact shaped wedge; the mouth is a fine curved lip line.
	_add(_panel([Vector3(-.015, 1.727, -.163), Vector3(.0, 1.731, -.201), Vector3(.016, 1.709, -.168), Vector3(0, 1.704, -.176)]), materials.skin, self)
	_add(_tube([Vector3(-.030, 1.674, -.154), Vector3(-.007, 1.670, -.161), Vector3(.012, 1.670, -.160), Vector3(.030, 1.675, -.154)], [.003, .0037, .0037, .002], 6), materials.lip, self)


func _ellipse(radius_x: float, radius_y: float, z: float, segments: int) -> ArrayMesh:
	var points: Array[Vector3] = []
	for i in range(segments):
		var angle := float(i) / segments * TAU
		points.append(Vector3(cos(angle) * radius_x, sin(angle) * radius_y, z))
	return _panel(points)


func _face_patch(points: Array[Vector2], size: float, z: float) -> ArrayMesh:
	var vertices: Array[Vector3] = []
	for point in points:
		vertices.append(Vector3(point.x * size, point.y * size, z))
	return _panel(vertices)


func _panel(points: Array[Vector3]) -> ArrayMesh:
	var centre := Vector3.ZERO
	for point in points:
		centre += point
	centre /= points.size()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()):
		# Front looks toward -Z; double-sided shapes use a second reverse triangle.
		var next := (i + 1) % points.size()
		for point: Vector3 in [centre, points[next], points[i], centre, points[i], points[next]]:
			tool.add_vertex(point)
	tool.generate_normals()
	return tool.commit()


func _build_hair() -> void:
	hair_root = _node(self)
	# A smooth crown cap leaves the forehead and both anime eyes exposed.
	_add(_loft([Vector4(1.90, .193, .169, .025), Vector4(1.97, .17, .158, .026), Vector4(2.035, .09, .09, .025), Vector4(2.046, .002, .002, .025)], 36), materials.hair, hair_root)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Large spring-shaped ringlets are swept continuous tubes, merged into one mesh.
	for strand in range(22):
		var t := float(strand) / 21.0
		var angle := lerpf(-1.72, 1.72, t)
		var points: Array[Vector3] = []
		var radii: Array[float] = []
		var length := .89 + .06 * sin(strand * 1.4)
		for step in range(38):
			var p := float(step) / 37.0
			var curl := p * TAU * 3.3 + strand * .9
			var spread := 1.0 + p * .14
			var amplitude := .025 + sin(p * PI) * .015
			var x := sin(angle) * .197 * spread + cos(curl) * amplitude
			var z := .077 + cos(angle) * .138 + sin(curl) * amplitude + p * .035
			points.append(Vector3(x, 1.96 - length * p, z))
			radii.append(lerpf(.044, .012, pow(p, 2.8)))
		_append_tube(tool, points, radii, 7)
	# Two face-framing side curls keep the forehead legible.
	for side: float in [-1.0, 1.0]:
		var points: Array[Vector3] = []
		var radii: Array[float] = []
		for i in range(25):
			var p := float(i) / 24.0
			points.append(Vector3(side * (.159 + p * .06 + sin(p * TAU * 2.0) * .023), 1.965 - p * .50, -.077 + p * .03 + cos(p * TAU * 2.0) * .026))
			radii.append(lerpf(.051, .006, p))
		_append_tube(tool, points, radii, 8)
	# Side-swept fringe, cut above the eyes instead of covering the entire face.
	for strand in range(6):
		var x := -.145 + strand * .052
		var points: Array[Vector3] = [Vector3(x * .72, 2.01, -.059), Vector3(x, 1.955, -.15), Vector3(x + .033, 1.88 + absf(x) * .15, -.168)]
		_append_tube(tool, points, [.042, .040, .003], 7)
	tool.generate_normals()
	tool.index()
	_add(tool.commit(), materials.hair, hair_root)
	# A few broad warm streaks express the curls under flat anime lighting.
	for strand in range(5):
		var angle := -.9 + strand * .45
		var points: Array[Vector3] = []
		var radii: Array[float] = []
		for i in range(22):
			var p := float(i) / 21.0
			points.append(Vector3(sin(angle) * .20 + cos(p * TAU * 2.8) * .035, 1.91 - p * .72, .10 + cos(angle) * .16 + sin(p * TAU * 2.8) * .035))
			radii.append(.007 * (1.0 - p * .7))
		_add(_tube(points, radii, 5), materials.hair_light, hair_root)
	# Motion pivots at the crown. Rotating a feet-origin hair node would uncover
	# the scalp during locomotion and detach the silhouette from the head.
	hair_root.position.y = 1.96
	for instance: Node3D in hair_root.get_children():
		instance.position.y -= 1.96


func _build_magic() -> void:
	magic = _node(right_forearm, Vector3(0, -.38, -.10))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("c5f9dd")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var torus := TorusMesh.new()
	torus.inner_radius = .11
	torus.outer_radius = .125
	torus.rings = 24
	torus.ring_segments = 6
	_add(torus, mat, magic)
	magic.hide()


func animate(delta: float, horizontal_speed: float, vertical_speed: float, _gliding: bool, climbing: bool, casting: bool) -> void:
	clock += delta
	gait += delta * horizontal_speed * 2.0
	var amount := clampf(horizontal_speed / 5.0, 0, 1)
	var swing := sin(gait) * .58 * amount
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_shin.rotation.x = -maxf(0, -sin(gait)) * .7 * amount
	right_shin.rotation.x = -maxf(0, sin(gait)) * .7 * amount
	left_arm.rotation = Vector3(-swing * .68, 0, .075)
	right_arm.rotation = Vector3(swing * .68, 0, -.075)
	left_forearm.rotation.x = -.18 - amount * .15
	right_forearm.rotation.x = -.18 - amount * .15
	skirt.rotation.x = sin(gait) * .035 * amount
	hair_root.rotation.x = -.025 - amount * .07 + sin(clock * 1.7) * .012
	hair_root.rotation.z = sin(gait * .5) * .025 * amount
	mantle.rotation.x = -amount * .035 + sin(clock * 2) * .015
	if absf(vertical_speed) > .6 and not climbing:
		left_leg.rotation.x = -.25
		right_leg.rotation.x = .2
		left_shin.rotation.x = -.5
		right_shin.rotation.x = -.3
	if climbing:
		left_arm.rotation.x = -2.6 + sin(clock * 6) * .35
		right_arm.rotation.x = -2.6 - sin(clock * 6) * .35
		left_leg.rotation.x = -.6 + sin(clock * 6) * .4
		right_leg.rotation.x = -.6 - sin(clock * 6) * .4
	magic.visible = casting
	if casting:
		right_arm.rotation.x = -1.35
		right_forearm.rotation.x = -.45
		magic.rotation.y += delta * 4.0
