extends "res://tests/orison_v2_city_sweep.gd"
## One production world, independent detailed validators, changed-area captures.
## This is visual/static-fit QA, not a runtime_contract or ledger promotion.
const MODULES := {
	"front_pavement": preload("res://tests/orison_v2_front_pavement_test.gd"),
	"street_paving_details": preload("res://tests/orison_v2_street_paving_details_test.gd"),
	"owner_building_finish": preload("res://tests/orison_v2_owner_building_finish_test.gd"),
	"owner_building_routes": preload("res://tests/orison_v2_owner_building_routes_test.gd"),
	"owner_shop_finish": preload("res://tests/orison_v2_owner_shop_finish_test.gd"),
	"druggist_carboys": preload("res://tests/orison_v2_druggist_carboys_test.gd"),
	"druggist_fountain": preload("res://tests/orison_v2_druggist_fountain_test.gd"),
	"druggist_mortar": preload("res://tests/orison_v2_druggist_mortar_test.gd"),
	"funeral_foliage": preload("res://tests/orison_v2_funeral_foliage_test.gd"),
	"funeral_drapes": preload("res://tests/orison_v2_funeral_drapes_test.gd"),
	"diner_apparatus": preload("res://tests/orison_v2_diner_apparatus_test.gd"),
	"diner_urns": preload("res://tests/orison_v2_diner_urns_test.gd"),
	"radio_battery": preload("res://tests/orison_v2_radio_battery_test.gd"),
	"wet_cloth": preload("res://tests/orison_v2_wet_cloth_test.gd"),
	"bedding": preload("res://tests/orison_v2_bedding_test.gd"),
	"owner_service_finish": preload("res://tests/orison_v2_owner_service_finish_test.gd"),
	"bodega_frontage": preload("res://tests/orison_v2_bodega_frontage_test.gd"),
	"signage": preload("res://tests/orison_v2_signage_test.gd"),
	"bar_receiving": preload("res://tests/orison_v2_bar_receiving_test.gd"),
	"bar_furniture": preload("res://tests/orison_v2_bar_furniture_test.gd"),
	"task_lamp_supply": preload("res://tests/orison_v2_task_lamp_supply_test.gd"),
	"bar_instruments": preload("res://tests/orison_v2_bar_instruments_test.gd"),
	"service_instruments": preload("res://tests/orison_v2_service_instruments_test.gd"),
	"household_stoves": preload("res://tests/orison_v2_household_stoves_test.gd"),
	"household_fridges": preload("res://tests/orison_v2_household_fridges_test.gd"),
	"fixed_lighting": preload("res://tests/orison_v2_fixed_lighting_test.gd"),
	"medicine_cabinets": preload("res://tests/orison_v2_medicine_cabinets_test.gd"),
	"household_toasters": preload("res://tests/orison_v2_household_toasters_test.gd"),
	"household_radios": preload("res://tests/orison_v2_household_radios_test.gd"),
	"domestic_objects": preload("res://tests/orison_v2_domestic_objects_test.gd"),
	"household_wardrobes": preload("res://tests/orison_v2_household_wardrobes_test.gd"),
	"domestic_storage": preload("res://tests/orison_v2_domestic_storage_test.gd"),
	"prep_cabinets": preload("res://tests/orison_v2_prep_cabinets_test.gd"),
	"domestic_seating": preload("res://tests/orison_v2_domestic_seating_test.gd"),
	"domestic_tables": preload("res://tests/orison_v2_domestic_tables_test.gd"),
	"signal_terminal": preload("res://tests/orison_v2_signal_terminal_test.gd"),
	"surface_stock": preload("res://tests/orison_v2_surface_stock_test.gd"),
	"work_tables": preload("res://tests/orison_v2_work_tables_test.gd"),
	"reading_nook": preload("res://tests/orison_v2_reading_nook_test.gd"),
	"task_lamps": preload("res://tests/orison_v2_task_lamps_test.gd"),
	"photo_radio_fittings": preload("res://tests/orison_v2_photo_radio_fittings_test.gd"),
	"radio_display": preload("res://tests/orison_v2_radio_display_test.gd"),
	"cobbler_fittings": preload("res://tests/orison_v2_cobbler_fittings_test.gd"),
	"druggist_cupboard": preload("res://tests/orison_v2_druggist_cupboard_test.gd"),
	"locksmith_fittings": preload("res://tests/orison_v2_locksmith_fittings_test.gd"),
	"news_fittings": preload("res://tests/orison_v2_news_fittings_test.gd"),
	"shop_clerestories": preload("res://tests/orison_v2_shop_clerestories_test.gd"),
	"shop_joinery": preload("res://tests/orison_v2_shop_joinery_test.gd"),
	"diner_counter": preload("res://tests/orison_v2_diner_counter_test.gd"),
	"diner_till": preload("res://tests/orison_v2_diner_till_test.gd"),
	"hardware_tools": preload("res://tests/orison_v2_hardware_tools_test.gd"),
	"photo_cameras": preload("res://tests/orison_v2_photo_cameras_test.gd"),
	"photo_counter": preload("res://tests/orison_v2_photo_counter_test.gd"),
	"photo_enlargers": preload("res://tests/orison_v2_photo_enlargers_test.gd"),
	"photo_portraits": preload("res://tests/orison_v2_photo_portraits_test.gd"),
	"photo_stock": preload("res://tests/orison_v2_photo_stock_test.gd"),
	"radio_wire": preload("res://tests/orison_v2_radio_wire_test.gd"),
	"laundry_trade": preload("res://tests/orison_v2_laundry_trade_test.gd"),
	"laundry_fittings": preload("res://tests/orison_v2_laundry_fittings_test.gd"),
	"laundry_apparatus": preload("res://tests/orison_v2_laundry_apparatus_test.gd"),
	"pawn_fittings": preload("res://tests/orison_v2_pawn_fittings_test.gd"),
	"pawn_clocks": preload("res://tests/orison_v2_pawn_clocks_test.gd"),
	"pawn_display": preload("res://tests/orison_v2_pawn_display_test.gd"),
	# This module exercises a real purchase after the other geometry validators.
	"hardware_stock": preload("res://tests/orison_v2_hardware_stock_test.gd"),
}

func _run() -> void:
	var selected := _selection(OS.get_environment("ORISON_FABRICATION_MODULES"), MODULES.keys())
	var captures := _selection(OS.get_environment("ORISON_FABRICATION_CAPTURES"), selected)
	var directory := OS.get_environment("SHOT_DIR")
	var actor_options := OS.get_environment("ORISON_FABRICATION_ACTORS_BY_MODULE")
	var module_actors: Variant = {} if actor_options.is_empty() else JSON.parse_string(actor_options)
	check(module_actors is Dictionary,"per-module capture actors must be a JSON object")
	if module_actors is not Dictionary: get_tree().quit(1); return
	for id: String in module_actors:
		check(id in selected and module_actors[id] is Array,"per-module capture selection belongs to this batch: "+id)
	if directory.is_empty(): directory = "user://fabrication_batch"
	DirAccess.make_dir_recursive_absolute(directory)
	for id: String in selected:
		check(MODULES.has(id), "registered fabrication validator: " + id)
		if MODULES.has(id): check(MODULES[id].can_instantiate(), "validator compiled before world loading: " + id)
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
	var teardown_validators := {}
	var total := 0
	var previous_directory := OS.get_environment("SHOT_DIR")
	var previous_actors := OS.get_environment("ORISON_FABRICATION_ACTORS")
	for id: String in selected:
		var module = MODULES[id].new()
		module.batch_mode = true
		module.capture_enabled = id in captures
		add_child(module)
		var destination := directory.path_join(id)
		DirAccess.make_dir_recursive_absolute(destination)
		OS.set_environment("SHOT_DIR", destination)
		OS.set_environment("ORISON_FABRICATION_ACTORS",",".join(module_actors[id]) if module_actors.has(id) else previous_actors)
		var module_started := Time.get_ticks_msec()
		var result: Dictionary = await module.validate_in_world(world)
		if not result.has_all(["checks", "failures"]):
			# A script error can unwind a validator with an empty dictionary.
			# Record that failure and finish the batch instead of hanging until
			# the serial lane's timeout with no final diagnostic packet.
			module.failures.append("validator returned no complete result; inspect engine errors")
			var incomplete: Array = module.failures.duplicate()
			result = {"checks":int(module.checks), "failures":incomplete}
		result["elapsed_ms"] = Time.get_ticks_msec() - module_started
		result["captured"] = module.capture_enabled
		result["validator_sha256"] = FileAccess.get_sha256(MODULES[id].resource_path)
		var fixture_id: String = "front_pavement_construction" if id == "front_pavement" else id
		result["fixture_sha256"] = FileAccess.get_sha256("res://tests/fixtures/orison_" + fixture_id + ".json")
		results[id] = result
		total += int(result.checks)
		for message: String in result.failures: failures.append(id + ": " + message)
		if module.has_method("validate_after_teardown"): teardown_validators[id] = module
		else: module.free()
	OS.set_environment("SHOT_DIR", previous_directory)
	OS.set_environment("ORISON_FABRICATION_ACTORS", previous_actors)
	world.shutdown_for_tests()
	world.free()
	await _retired_audio()
	var world_loads := 1
	for id: String in teardown_validators:
		var module: Node = teardown_validators[id]
		var before: int = int(results[id].checks)
		var post: Dictionary = await module.validate_after_teardown()
		world_loads += int(post.get("additional_world_loads",0))
		results[id]["additional_world_loads"] = int(post.get("additional_world_loads",0))
		results[id].checks = post.checks
		results[id].failures = post.failures
		total += int(post.checks)-before
		for message: String in post.failures:
			if not (id+": "+message) in failures: failures.append(id+": "+message)
		module.free()
	# Validators retain native meshes/materials until their retirement checks.
	# Allow the rendering queue to retire those final references before exit.
	await get_tree().process_frame
	await get_tree().process_frame
	var receipt := {"schema":"orison.fabrication-batch.v1", "evidence_class":"INERT", "world_loads":world_loads,
		"modules":results, "module_checks":total, "batch_checks":checks, "failures":failures,
		"elapsed_ms":Time.get_ticks_msec()-started, "scope":"Detailed geometry/material/support QA; lifecycle and gameplay contracts remain separate."}
	FileAccess.open(directory.path_join("batch.json"), FileAccess.WRITE).store_string(JSON.stringify(receipt, "\t"))
	# Name the modules this run selected (they come from the environment) and print
	# one FAIL line per failure, so the run receipt counts what failed.
	print("FABRICATION MODULES: ", ", ".join(PackedStringArray(results.keys())))
	for message: String in failures: print("FABRICATION FAIL: ", message)
	print("FABRICATION BATCH: worlds=",world_loads," modules=", results.size(), " module_checks=", total, " failures=", failures.size(), " elapsed_ms=", receipt.elapsed_ms)
	get_tree().quit(0 if failures.is_empty() else 1)

func _selection(value: String, defaults: Array) -> Array:
	if value.is_empty(): return defaults.duplicate()
	if value == "none": return []
	var result: Array = []
	for id: String in value.split(",", false):
		var key := id.strip_edges()
		if not key in result: result.append(key)
	return result
