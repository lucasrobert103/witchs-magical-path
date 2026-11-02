extends SceneTree
## Close-up renders of Asterion in the real game (run under xvfb): build/shots/char_*.png

var main: Node
var out := "res://build/shots/"

func shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	img.save_png(ProjectSettings.globalize_path(out + name + ".png"))
	print("shot ", name)

func wait(t: float) -> void:
	await create_timer(t).timeout

func _initialize() -> void:
	await process_frame
	root.get_node("Game").splash_shown = true
	root.get_node("Game").delete_save()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait(1.5)
	main._on_new_game()
	await wait(1.5)
	main.ui.prologue.finish()
	await wait(9.0)
	for i in 12:
		if main.ui.dialogue.visible:
			main.ui.dialogue.advance()
		await wait(0.4)
	var w = main.world
	var p = w.player
	main.ui.set_gameplay_visible(false)
	var cam = w.cam_rig
	cam.cinematic = true
	var base: Vector3 = p.global_position
	p.facing = Vector3(0, 0, 1)
	await wait(0.6)
	var views := {
		"char_front": [Vector3(0, 1.1, 2.6), Vector3(0, 0.9, 0)],
		"char_34": [Vector3(1.8, 1.3, 2.0), Vector3(0, 0.95, 0)],
		"char_back": [Vector3(-0.6, 1.4, -2.7), Vector3(0, 1.0, 0)],
		"char_face": [Vector3(0.12, 1.52, 0.95), Vector3(0, 1.47, 0)],
		"char_face34": [Vector3(0.6, 1.52, 0.8), Vector3(0, 1.45, 0)],
		"char_side": [Vector3(2.6, 1.1, 0.2), Vector3(0, 0.9, 0)],
	}
	for k in views.keys():
		var rot := Basis(Vector3.UP, p._yaw)
		base = p.global_position
		cam.cine_pos = base + rot * views[k][0]
		cam.cine_look = base + rot * views[k][1]
		cam.cam.global_position = cam.cine_pos
		await wait(0.3)
		await shot(k)
	# Walking and running seen from the usual game camera.
	cam.cinematic = false
	main.ui.touch.move = Vector2(0.6, 0.6)
	await wait(1.2)
	await shot("char_walk")
	p.run_toggle = true
	main.ui.touch.move = Vector2(0.7, 0.7)
	await wait(1.2)
	await shot("char_run")
	main.ui.touch.move = Vector2.ZERO
	quit()
