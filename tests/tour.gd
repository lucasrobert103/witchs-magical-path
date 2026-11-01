extends SceneTree
## Visual tour: renders key moments to build/shots/*.png (run under a display / xvfb).

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
	var which := OS.get_environment("TOUR")
	await process_frame
	root.get_node("Game").splash_shown = true
	root.get_node("Game").delete_save()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait(2.5)
	await shot("01_title")
	if which == "" or which.contains("prologue"):
		main._on_new_game()
		await wait(2.5)
		await shot("02_prologue_title")
		for i in [3, 6, 8, 11, 14, 17, 18, 20]:
			main.ui.prologue._set_card(i)
			await wait(3.0)
			await shot("03_prologue_%02d" % i)
		main.ui.prologue.finish()
		await wait(3.0)
		await shot("04_wake")
		await wait(4.0)
		await shot("05_wake_dialogue")
	else:
		main._on_new_game()
		await wait(1.5)
		main.ui.prologue.finish()
		await wait(5.0)
	var w = main.world
	main.ui.dialogue.close()
	w.mode = "play"
	# Walk forward a little.
	w.player.move_input = Vector2(0, 1)
	await wait(1.2)
	await shot("06_walk")
	var spots := [["07_path", Vector2(-1, 33), Vector2(0, -1)], ["08_pool", Vector2(-4, 23), Vector2(-1, -0.2)], ["09_lanterns", Vector2(0, 13), Vector2(0, -1)], ["10_ruins", Vector2(-2, -15), Vector2(-0.2, -1)], ["11_brazier", Vector2(5, -34), Vector2(0.5, -1)], ["12_sanctuary", Vector2(0, -46), Vector2(0, -1)]]
	for s in spots:
		w.player.move_input = Vector2.ZERO
		w.player.global_position = Vector3(s[1].x, w.terrain.height(s[1].x, s[1].y), s[1].y)
		w.player.facing = Vector3(s[2].x, 0, s[2].y).normalized()
		w.cam_rig.snap_behind(w.player.facing)
		w.cam_rig._focus = Vector3.ZERO
		main.ui.dialogue.close()
		w.mode = "play"
		await wait(1.6)
		await shot(s[0])
	# Magic and HUD with touch controls.
	w.player.magic_unlocked = true
	w.player.essence = "moon"
	w.player.global_position = Vector3(-4, w.terrain.height(-4, -19), -19)
	w.cam_rig.snap_behind(Vector3(0, 0, -1))
	w._spawn_wave("ruins", [Vector2(-5, -25), Vector2(-1, -26)])
	await wait(1.0)
	w.do_cast()
	await wait(0.35)
	await shot("13_cast")
	quit()
