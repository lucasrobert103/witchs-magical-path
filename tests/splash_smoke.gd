extends SceneTree
## The RetroNexa opening plays first, then hands over to the title screen.

func _initialize() -> void:
	await process_frame
	var game = root.get_node("Game")
	game.splash_shown = false
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	var ok1: bool = main.state == "splash" and main.ui.splash.visible
	print(("  ok  " if ok1 else "FAIL ") + "opening plays first")
	await create_timer(7.5).timeout
	var ok2: bool = main.state == "title" and not main.ui.splash.visible and main.ui.title.visible
	print(("  ok  " if ok2 else "FAIL ") + "then the title screen")
	print("splash_smoke: %d failures" % (int(not ok1) + int(not ok2)))
	quit(0 if ok1 and ok2 else 1)
