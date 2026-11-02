extends SceneTree
## Movement and idle-life checks: analog walk, run button, idle reactions, portrait moods.

var main
var failures := 0

func check(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "FAIL ") + msg)
	if not cond:
		failures += 1

func wait(t: float) -> void:
	await create_timer(t).timeout

func close_dialogue() -> void:
	for i in 30:
		if not main.ui.dialogue.active:
			break
		main.ui.dialogue._cooldown = 0.0
		main.ui.dialogue.advance()
		await process_frame

func _initialize() -> void:
	await process_frame
	root.get_node("Game").splash_shown = true
	root.get_node("Game").delete_save()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait(0.5)
	main._on_new_game()
	await wait(1.0)
	main.ui.prologue.finish()
	await wait(6.0)
	await close_dialogue()
	var w = main.world
	w.mode = "play"
	var p = w.player
	main.ui.touch.move = Vector2(0, 1)
	await wait(1.2)
	var walk := Vector2(p.vel.x, p.vel.z).length()
	check(walk > 1.7 and walk < 2.4, "walks at a natural pace (%.1f m/s)" % walk)
	main.ui.touch.move = Vector2(0, 0.3)
	await wait(1.0)
	var slow := Vector2(p.vel.x, p.vel.z).length()
	check(slow < walk * 0.75 and slow > 0.6, "joystick sets the pace (%.1f m/s)" % slow)
	main.ui.touch.move = Vector2(0, 1)
	main._on_touch_action("run")
	await wait(1.2)
	var run := Vector2(p.vel.x, p.vel.z).length()
	check(p.run_toggle and run > 5.0 and p.anim == "run", "run button makes her run (%.1f m/s)" % run)
	main.ui.touch.move = Vector2.ZERO
	await wait(2.4)
	check(not p.run_toggle, "run turns itself off after stopping")
	var seen := {}
	for i in 280:
		await wait(0.05)
		seen[p.anim] = true
	check(seen.has("sigh") or seen.has("wind") or seen.has("shift"), "reacts while standing still: %s" % str(seen.keys()))
	check(p.look_target != Vector3.INF or seen.size() > 1, "looks around")
	var pf = main.ui.dialogue._portrait_frame
	pf.mood("Por que sinto falta disso?")
	check(pf.tilt_target > 0.0, "portrait tilts on questions")
	pf.mood("Espera!")
	check(pf.pop > 0.5, "portrait reacts to exclamations")
	check(pf.eyes.size() == 2 and pf.skin.size() == 2, "portrait knows where to blink")
	print("motion_smoke: %d failures" % failures)
	quit(1 if failures else 0)
