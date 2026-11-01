extends SceneTree
## Plays through Chapter I by driving the real game systems (headless).

var main
var w
var game
var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok  ", msg)
	else:
		failures += 1
		push_error("FAIL " + msg)

func wait(t: float) -> void:
	await create_timer(t).timeout

func close_dialogue() -> void:
	for i in 40:
		if not main.ui.dialogue.active:
			break
		main.ui.dialogue._cooldown = 0.0
		main.ui.dialogue.advance()
		await process_frame
	await process_frame

func go(p: Vector2, face := Vector2(0, -1)) -> void:
	await close_dialogue()
	w.player.global_position = Vector3(p.x, w.terrain.height(p.x, p.y), p.y)
	w.player.facing = Vector3(face.x, 0, face.y).normalized()
	w.player.vel = Vector3.ZERO
	w.mode = "play"
	await wait(0.2)

func cast_at(target: Node3D) -> void:
	var to: Vector3 = target.global_position - w.player.global_position
	to.y = 0
	w.player.facing = to.normalized()
	w.player.mana = w.player.max_mana
	w.player._cast_timer = 0.0
	w.mode = "play"
	w.do_cast()
	await wait(1.2)

func _initialize() -> void:
	await process_frame
	game = root.get_node("Game")
	root.get_node("Game").splash_shown = true
	game.delete_save()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait(0.5)
	main._on_new_game()
	await wait(1.2)
	main.ui.prologue.finish()
	await wait(2.0)
	w = main.world
	await wait(4.0)
	await close_dialogue()
	check(game.flag("woke"), "woke up")
	# Walk with input for a moment: player should move forward.
	var start: Vector3 = w.player.global_position
	main.ui.touch.move = Vector2(0, 1)
	await wait(1.0)
	main.ui.touch.move = Vector2.ZERO
	check(w.player.global_position.distance_to(start) > 1.5, "walks with input")
	# Jump.
	w.do_jump()
	await wait(0.25)
	check(not w.player.on_ground, "jumps")
	await wait(1.0)
	check(w.player.on_ground, "lands")
	# Pool.
	await go(Vector2(-6.2, 21.5), Vector2(-1, 0))
	w.do_interact()
	await wait(0.3)
	check(game.flag("pool_done") and w.player.magic_unlocked, "pool grants magic")
	await close_dialogue()
	# Roots block the way before the lanterns.
	await go(Vector2(0, 0.5))
	main.ui.touch.move = Vector2(0, 1)
	await wait(1.5)
	main.ui.touch.move = Vector2.ZERO
	check(w.player.global_position.z > -2.0, "roots block the path")
	await close_dialogue()
	for l in w.lanterns:
		await go(Vector2(l.global_position.x, l.global_position.z + 4.0))
		await cast_at(l)
	await wait(4.0)
	await close_dialogue()
	check(game.flag("lanterns_done"), "lanterns open the roots")
	# Ruins wave.
	await go(Vector2(-3.5, -18))
	await wait(0.5)
	await close_dialogue()
	check(w.shades.size() == 3, "ruins shades appear")
	var guard := 0
	while w._alive_shades() > 0 and guard < 30:
		guard += 1
		var s = null
		for x in w.shades:
			if is_instance_valid(x) and not x.dying:
				s = x
				break
		if s == null:
			break
		w.player.hp = w.player.max_hp
		w.player.global_position = s.global_position + Vector3(0, 0, 4)
		w.player.global_position.y = w.terrain.height(w.player.global_position.x, w.player.global_position.z)
		await cast_at(s)
	await wait(0.6)
	await close_dialogue()
	check(game.flag("ruins_clear"), "ruins cleared")
	# Spark with a jump over the log.
	await go(Vector2(-8.5, -25.3), Vector2(-1, 0))
	main.ui.touch.move = Vector2(0, 1)
	w.cam_rig.snap_behind(Vector3(-1, 0, 0))
	w.player.cam_yaw = w.cam_rig.yaw
	await wait(1.0)
	check(w.player.global_position.x > -10.2, "log blocks without jumping")
	w.do_jump()
	await wait(1.6)
	main.ui.touch.move = Vector2.ZERO
	check(w.player.global_position.x < -10.9, "jumping clears the log")
	await go(Vector2(-16.2, -28))
	await wait(0.5)
	check(game.has_spark("s3"), "spark collected")
	await close_dialogue()
	# Brazier.
	await go(Vector2(8.6, -39), Vector2(1, -0.5))
	w.do_interact()
	await wait(0.3)
	check(game.flag("flame_done") and w.player.essence == "flame", "eternal flame gives fire essence")
	await close_dialogue()
	# Sanctuary wave.
	await go(Vector2(0, -50))
	await wait(0.5)
	await close_dialogue()
	check(w.shades.size() == 4, "sanctuary ambush")
	guard = 0
	while w._alive_shades() > 0 and guard < 40:
		guard += 1
		var s = null
		for x in w.shades:
			if is_instance_valid(x) and not x.dying:
				s = x
				break
		if s == null:
			break
		w.player.hp = w.player.max_hp
		w.player.global_position = s.global_position + Vector3(0, 0, 4)
		w.player.global_position.y = w.terrain.height(w.player.global_position.x, w.player.global_position.z)
		await cast_at(s)
	await wait(0.6)
	await close_dialogue()
	check(game.flag("sanctuary_clear"), "sanctuary cleared")
	# Altars: wrong essence first, then both in time.
	var moon = w.pedestals[0]
	var flame = w.pedestals[1]
	await go(Vector2(-5.5, -54.5))
	w.player.essence = "flame"
	await cast_at(moon)
	check(not moon.lit, "moon altar rejects flame")
	await close_dialogue()
	w.player.essence = "moon"
	await cast_at(moon)
	check(moon.lit, "moon altar lit")
	await go(Vector2(5.5, -54.5))
	w.player.essence = "flame"
	await cast_at(flame)
	await wait(1.5)
	check(game.flag("altars_done"), "both altars awaken the gate")
	await close_dialogue()
	await wait(3.5)
	# Walk through the gate: the memory plays, then the valley.
	var crossed := [false]
	w.portal_crossed.connect(func(): crossed[0] = true)
	await go(Vector2(0, -64))
	main.ui.touch.move = Vector2(0, 1)
	w.cam_rig.snap_behind(Vector3(0, 0, -1))
	await wait(2.5)
	main.ui.touch.move = Vector2.ZERO
	await close_dialogue()
	check(crossed[0], "crossing the portal")
	await wait(2.5)
	check(main.state == "memory" and main.ui.memory.visible, "memory plays")
	main.ui.memory.finish()
	await wait(3.0)
	w = main.world
	check(w.has_method("begin_arrival"), "arrives in the valley")
	for i in 40:
		await close_dialogue()
		await wait(0.5)
		if w.mode == "play":
			break
	check(game.flag("v_arrived") and w.mode == "play", "arrival scene finishes")
	# Explore: water, firm ground and light.
	for key in ["water", "ground", "light"]:
		var p: Vector2 = w.OBSERVE[key][0]
		await go(p)
		await wait(0.4)
		await close_dialogue()
	await wait(0.6)
	await close_dialogue()
	check(game.flag("v_clearing"), "finds the clearing")
	for b in w.branches.slice(0, 5):
		await go(Vector2(b.global_position.x, b.global_position.z) + Vector2(0.6, 0))
		w.do_interact()
		await wait(0.5)
		await close_dialogue()
	check(w.branch_count() == 5, "gathers five branches")
	await go(w.SHELTER + Vector2(0, -2.4))
	w.do_interact()
	for i in 20:
		await wait(0.5)
		await close_dialogue()
		if w.mode == "play":
			break
	check(game.flag("v_shelter"), "builds the shelter")
	await go(w.PLANT + Vector2(1.0, 0))
	w.do_interact()
	for i in 10:
		await wait(0.4)
		await close_dialogue()
	check(game.flag("v_seeds"), "gathers seeds")
	for step in ["v_tilled", "v_sown"]:
		await go(w.PLOT + Vector2(0, 1.6))
		w.do_interact()
		for i in 14:
			await wait(0.4)
			await close_dialogue()
		check(game.flag(step), step)
	await go(Vector2(8.8, -10.6))
	w.do_interact()
	for i in 14:
		await wait(0.4)
		await close_dialogue()
	check(w.player.carrying == "water" and game.flag("v_water_learned"), "water follows her hand")
	var completed := [false]
	w.chapter_completed.connect(func(_s): completed[0] = true)
	for r in 3:
		await go(w.PLOT + Vector2(0, 1.6))
		w.do_interact()
		for i in 10:
			await wait(0.4)
			await close_dialogue()
	check(game.flag("v_watered"), "waters all three rows")
	for i in 60:
		await close_dialogue()
		await wait(0.5)
		if completed[0]:
			break
	check(completed[0], "first night ends the chapter")
	check(game.has_save(), "progress saved")
	print("story_smoke: %d failures" % failures)
	quit(1 if failures else 0)
