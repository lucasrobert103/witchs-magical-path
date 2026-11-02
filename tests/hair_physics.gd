extends SceneTree
## Live hair physics check: the hair tips must swing when she runs, turns and stops,
## stay attached (no explosion) and settle again when she stands still.

var failures := 0

func check(ok: bool, msg: String) -> void:
	print(("  ok  " if ok else "FAIL ") + msg)
	if not ok:
		failures += 1

func wait(t: float) -> void:
	await create_timer(t).timeout

func _initialize() -> void:
	await process_frame
	var game = root.get_node("Game")
	game.splash_shown = true
	game.delete_save()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait(1.0)
	main._on_new_game()
	await wait(1.0)
	main.ui.prologue.finish()
	await wait(8.0)
	for i in 12:
		if main.ui.dialogue.visible:
			main.ui.dialogue.advance()
		await wait(0.3)
	var p = main.world.player
	var sk: Skeleton3D = p.skeleton
	check(p.hair_springs != null and p.hair_springs.setting_count >= 9, "hair spring chains: %d" % (p.hair_springs.setting_count if p.hair_springs else 0))
	var tip := sk.find_bone("HairBackC4")
	var head := sk.find_bone("Head")
	# Modifier results only exist while the skeleton reports its final pose.
	var last := [Vector3.ZERO]
	sk.skeleton_updated.connect(func():
		var ht: Transform3D = sk.get_bone_global_pose(head)
		var tt: Transform3D = sk.get_bone_global_pose(tip)
		last[0] = ht.basis.inverse() * (tt.origin - ht.origin))
	var rel := func() -> Vector3:
		return last[0]
	await wait(2.0)
	var rest: Vector3 = rel.call()
	p.run_toggle = true
	main.ui.touch.move = Vector2(0, 1)
	var max_d := 0.0
	for i in 40:
		await wait(0.05)
		max_d = maxf(max_d, (rel.call() - rest).length())
	main.ui.touch.move = Vector2(1, 0)       # sharp turn
	for i in 20:
		await wait(0.05)
		max_d = maxf(max_d, (rel.call() - rest).length())
	main.ui.touch.move = Vector2.ZERO        # sudden stop
	var after_stop := 0.0
	for i in 16:
		await wait(0.05)
		after_stop = maxf(after_stop, (rel.call() - rest).length())
	check(max_d > 0.04 and max_d < 0.35, "hair swings while running and turning (%.2f m)" % max_d)
	check(after_stop > 0.02, "hair keeps swinging after a sudden stop (%.2f m)" % after_stop)
	var dist: float = (rel.call() as Vector3).length()
	check(dist < 0.9, "hair stays attached (%.2f m from head)" % dist)
	await wait(3.0)
	var settle: float = (rel.call() - rest).length()
	check(settle < 0.12, "hair settles when she stands still (%.2f m)" % settle)
	print("hair_physics: %d failures" % failures)
	quit(1 if failures else 0)
