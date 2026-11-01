extends SceneTree
## Shots of the dialogue portrait and the touch controls (needs a display / xvfb).

var main
func shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots3/"))
	img.save_png(ProjectSettings.globalize_path("res://build/shots3/" + name + ".png"))

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
	await wait(1.0)
	main.ui.prologue.finish()
	await wait(7.0)
	main.ui.dialogue._cooldown = 0.0
	main.ui.dialogue.advance()
	main.ui.dialogue.advance()
	await wait(1.5)
	await shot("dialogue")
	main.ui.dialogue._portrait_frame.blink = 1.0
	main.ui.dialogue._portrait_frame._blink_t = 0.07
	await process_frame
	await shot("dialogue_blink")
	main.ui.dialogue.close()
	var w = main.world
	w.mode = "play"
	w.player.magic_unlocked = true
	main.ui.touch.move = Vector2(0.4, 1)
	main._on_touch_action("run")
	await wait(1.5)
	await shot("running")
	quit()
