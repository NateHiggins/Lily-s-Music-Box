extends "res://tests/orison_v2_city_sweep.gd"
## One production world, independent detailed validators, changed-area captures.
## This is visual/static-fit QA, not a runtime_contract or ledger promotion.
const MODULES := {
	"laundry_trade": preload("res://tests/orison_v2_laundry_trade_test.gd"),
	"laundry_fittings": preload("res://tests/orison_v2_laundry_fittings_test.gd"),
	"laundry_apparatus": preload("res://tests/orison_v2_laundry_apparatus_test.gd"),
	"pawn_fittings": preload("res://tests/orison_v2_pawn_fittings_test.gd"),
	"pawn_clocks": preload("res://tests/orison_v2_pawn_clocks_test.gd"),
	"pawn_display": preload("res://tests/orison_v2_pawn_display_test.gd"),
}

func _run() -> void:
	var selected := _selection(OS.get_environment("ORISON_FABRICATION_MODULES"), MODULES.keys())
	var captures := _selection(OS.get_environment("ORISON_FABRICATION_CAPTURES"), selected)
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): directory = "user://fabrication_batch"
	DirAccess.make_dir_recursive_absolute(directory)
	for id: String in selected:
		check(MODULES.has(id), "registered fabrication validator: " + id)
	for id: String in captures:
		check(id in selected, "capture must belong to this batch: " + id)
	check(not selected.is_empty(), "batch must select at least one validator")
	check(captures.is_empty() or DisplayServer.get_name() != "headless", "captures require the windowed lane")
	if not failures.is_empty(): get_tree().quit(1); return
	var started := Time.get_ticks_msec()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 20 * 60)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed, "batch world initialized")
	if world.startup_failed or world.passage_region.startup_failed:
		world.shutdown_for_tests(); world.free(); get_tree().quit(1); return
	world.player.set_physics_process(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*", "CanvasLayer", true, false): layer.hide()
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"): driver.set_frozen_for_tests(true)
	world.shop_simulation.set_process(false)
	var vestibule: Dictionary = world.layout.spaces.filter(func(row): return row.id == "F01_VESTIBULE")[0]
	var rect: Array = vestibule.rect
	world.player.global_position = world.adapter.root.to_global(Vector3((rect[0]+rect[2])*.5, 0., (rect[1]+rect[3])*.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	for frame in 600:
		if world.passage_region.residency.state == "RESIDENT": break
		await get_tree().process_frame
	check(world.passage_region.residency.state == "RESIDENT", "batch uses normal passage prefetch")
	if world.passage_region.residency.state != "RESIDENT":
		world.shutdown_for_tests(); world.free(); get_tree().quit(1); return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var results: Dictionary = {}
	var total := 0
	var previous_directory := OS.get_environment("SHOT_DIR")
	for id: String in selected:
		var module = MODULES[id].new()
		module.batch_mode = true
		module.capture_enabled = id in captures
		add_child(module)
		var destination := directory.path_join(id)
		DirAccess.make_dir_recursive_absolute(destination)
		OS.set_environment("SHOT_DIR", destination)
		var module_started := Time.get_ticks_msec()
		var result: Dictionary = await module.validate_in_world(world)
		result["elapsed_ms"] = Time.get_ticks_msec() - module_started
		result["captured"] = module.capture_enabled
		result["validator_sha256"] = FileAccess.get_sha256(MODULES[id].resource_path)
		result["fixture_sha256"] = FileAccess.get_sha256("res://tests/fixtures/orison_" + id + ".json")
		results[id] = result
		total += int(result.checks)
		for message: String in result.failures: failures.append(id + ": " + message)
		module.free()
	OS.set_environment("SHOT_DIR", previous_directory)
	world.shutdown_for_tests()
	world.free()
	await _retired_audio()
	var receipt := {"schema":"orison.fabrication-batch.v1", "evidence_class":"INERT", "world_loads":1,
		"modules":results, "module_checks":total, "batch_checks":checks, "failures":failures,
		"elapsed_ms":Time.get_ticks_msec()-started, "scope":"Detailed geometry/material/support QA; lifecycle and gameplay contracts remain separate."}
	FileAccess.open(directory.path_join("batch.json"), FileAccess.WRITE).store_string(JSON.stringify(receipt, "\t"))
	print("FABRICATION BATCH: worlds=1 modules=", results.size(), " module_checks=", total, " failures=", failures.size(), " elapsed_ms=", receipt.elapsed_ms)
	get_tree().quit(0 if failures.is_empty() else 1)

func _selection(value: String, defaults: Array) -> Array:
	if value.is_empty(): return defaults.duplicate()
	if value == "none": return []
	var result: Array = []
	for id: String in value.split(",", false):
		var key := id.strip_edges()
		if not key in result: result.append(key)
	return result
