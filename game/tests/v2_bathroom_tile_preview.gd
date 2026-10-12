extends "res://tests/orison_v2_floor_surface_test.gd"

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	var selector := preload("res://scripts/building/building_root_selector.gd")
	selector.reset_for_tests("v2")
	var world := (load(selector.scene_path()) as PackedScene).instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().create_timer(.5).timeout
	check(not world.startup_failed,"production world starts")
	await preload("res://tests/v2_bathroom_tile_review.gd").new().run(world,self)
	world.shutdown_for_tests()
	world.free()
	print("BATHROOM TILE PREVIEW: ","PASS" if failures.is_empty() else "FAIL", "; failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
