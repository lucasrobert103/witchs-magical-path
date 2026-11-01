extends SceneTree
## Visual tour of the solid forest, the memory and the valley (needs a display / xvfb).

var main
var out := "res://build/shots2/"

func shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	img.save_png(ProjectSettings.globalize_path(out + name + ".png"))
	print("shot ", name)

func wait(t: float) -> void:
	await create_timer(t).timeout

func close_dialogue() -> void:
	for i in 30:
		if not main.ui.dialogue.active:
			break
		main.ui.dialogue._cooldown = 0.0
		main.ui.dialogue.advance()
		await process_frame

func put(w, p: Vector2, face: Vector2) -> void:
	await close_dialogue()
	w.player.global_position = Vector3(p.x, w.terrain.height(p.x, p.y), p.y)
	w.player.facing = Vector3(face.x, 0, face.y).normalized()
	w.cam_rig.snap_behind(w.player.facing)
	w.cam_rig._focus = Vector3.ZERO
	w.mode = "play"
	await wait(1.4)

func _initialize() -> void:
	await process_frame
	var game = root.get_node("Game")
	root.get_node("Game").splash_shown = true
	game.delete_save()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait(2.0)
	main._on_new_game()
	await wait(1.0)
	main.ui.prologue.finish()
	await wait(4.5)
	var w = main.world
	await close_dialogue()
	await put(w, Vector2(0, 47), Vector2(0, -1))
	await shot("a_clearing")
	await put(w, Vector2(9.5, 40.5), Vector2(1, -0.2))
	await shot("b_glade")
	await put(w, Vector2(-1, 30), Vector2(-0.3, -1))
	await shot("c_path")
	await put(w, Vector2(-2, -48), Vector2(0, -1))
	await shot("d_sanctuary")
	# Memory.
	main._on_portal_crossed()
	await wait(2.5)
	for i in [3, 5, 6, 9, 10, 14, 17]:
		main.ui.memory._set_beat(i)
		await wait(2.6)
		await shot("e_memory_%02d" % i)
	main.ui.memory.finish()
	await wait(3.5)
	w = main.world
	await wait(3.0)
	await shot("f_arrival")
	await close_dialogue()
	await wait(4.5)
	await shot("g_vista")
	for i in 30:
		await close_dialogue()
		await wait(0.4)
		if w.mode == "play":
			break
	await put(w, Vector2(-16, 37), Vector2(0.4, -1))
	await shot("h_ridge")
	await put(w, Vector2(3, 8), Vector2(0.3, -1))
	await shot("i_meadow")
	for f in ["v_arrived", "v_clearing", "v_shelter", "v_seeds", "v_tilled", "v_sown", "v_water_learned", "v_water_0"]:
		game.set_flag(f)
	w._build_shelter(true)
	w._plot_base.material_override.albedo_color.a = 1.0
	w._plot_strips[0].material_override.albedo_color.a = 1.0
	await put(w, Vector2(9.0, 0.5), Vector2(0.2, -1))
	await shot("j_home")
	await put(w, Vector2(12.0, 4.0), Vector2(0.3, -1))
	await shot("k_shelter")
	game.set_flag("v_water_1")
	w._water_row(w._at(w.PLOT, 1.0))
	await wait(1.0)
	await close_dialogue()
	await wait(22.0)
	await shot("l_night")
	await close_dialogue()
	await wait(8.0)
	await shot("m_night2")
	quit()
