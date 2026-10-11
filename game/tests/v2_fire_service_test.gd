extends "res://tests/orison_v2_floor_surface_test.gd"
func _run() -> void:
	RealityState.persistence_enabled = false; RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot; add_child(world)
	await get_tree().physics_frame; await get_tree().physics_frame
	if world.startup_failed: get_tree().quit(1); return
	world.player.set_physics_process(false)
	var review := preload("res://tests/v2_fire_service_review.gd").new()
	await review.run(world,self)
	world.shutdown_for_tests();world.free()
	for frame in 3: await get_tree().process_frame
	review.after_teardown(self)
	print("FIRE SERVICE: ",batch_checks," checks; ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
