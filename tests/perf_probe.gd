extends SceneTree
## Prints draw calls / objects at several spots (run under xvfb).

func _initialize() -> void:
	await process_frame
	root.get_node("Game").splash_shown = true
	root.get_node("Game").delete_save()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(2.0).timeout
	main._on_new_game()
	await create_timer(1.0).timeout
	main.ui.prologue.finish()
	await create_timer(5.0).timeout
	var w = main.world
	main.ui.dialogue.close()
	w.mode = "play"
	for p in [Vector2(0, 50), Vector2(-4, 23), Vector2(0, 8), Vector2(-3, -20), Vector2(0, -50)]:
		w.player.global_position = Vector3(p.x, w.terrain.height(p.x, p.y), p.y)
		await create_timer(1.0).timeout
		var t := Time.get_ticks_usec()
		for i in 30:
			await process_frame
		var ms := (Time.get_ticks_usec() - t) / 30000.0
		print("%s draws=%d objects=%d prims=%d frame_ms(llvmpipe)=%.1f" % [p, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), ms])
	quit()
