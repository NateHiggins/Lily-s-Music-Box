extends Node

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const RUNTIME := preload("res://scenes/building/orison_v2_runtime.tscn")
var shots = ShotHarnessScript.new()
var world: OrisonV2RuntimeRoot
var camera: Camera3D
var banner: Label
var records: Array[Dictionary] = []

func _ready() -> void:
	if not shots.setup(self, "ORISON-V2-M08F", 12):
		get_tree().quit(2)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityCases._ready()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE}
	world = RUNTIME.instantiate()
	add_child(world)
	world.player.camera.current = false
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	_build_banner()
	await shots.settle(0.8, "runtime_ready")
	var radiator := world.find_child("F02_B_RADIATOR_01", true, false) as RadiatorProp
	var board := world.find_child("LobbyPorterBoard", true, false) as OtisProp
	var boiler := world.find_child("B1_BOILER_01", true, false) as BoilerProp
	_close_previous_job()
	world.service_round.answer_incoming_call()
	world.service_round.dialogue.choose(0)
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID)
	world.service_round.dialogue.choose(0)
	await _shot("01_2b_radiator_real_prompt", Vector3(13.0, 4.61, -2.5), Vector3(15.4, 4.0, -3.0),
			radiator.interact_prompt())
	world.player.world_modified.emit(radiator.global_position, ServiceRoundDirector.RADIATOR_ID)
	await _shot("02_radiator_inspection_transition", Vector3(13.0, 4.61, -2.5), Vector3(15.4, 4.0, -3.0),
			"RADIATOR VIEW AFTER INSPECTION SIGNAL")
	await _shot("03_f01_station_inspection", Vector3(-1.65, 1.41, -2.6), Vector3(-4.1, 1.05, -1.0),
			"PORTER / RITUAL STATION · INSPECTION VIEW")
	await _owner_shot("04_watchman_detector", "F01_WATCHMAN_DETECTOR", "WATCHMAN DETECTOR · PRODUCTION AUTHORITY")
	await _owner_shot("05_night_register", "F01_NIGHT_REGISTER", "NIGHT REGISTER · PRODUCTION AUTHORITY")
	await _owner_shot("06_signal_register", "F01_SIGNAL_REGISTER", "SIGNAL REGISTER · PRODUCTION AUTHORITY")
	await _owner_shot("07_tour_key_guard", "F01_TOUR_KEY_GUARD", "TOUR KEY GUARD · COMPOSED PROP")
	board.apply_maintenance_result({"note": "contacts squared"})
	await _shot("08_b1_inspection", Vector3(2.2, -1.79, -2.9), Vector3(6.8, -1.9, -0.5),
			"B1 · TELEPORTED INSPECTION VIEW")
	var boiler_view := boiler.global_position + boiler.global_transform.basis.z.normalized() * 2.4 + Vector3.UP * 0.5
	await _shot("09_boiler_real_prompt", boiler_view, boiler.global_position + Vector3.UP * 0.7,
			boiler.control_prompt("water_column"))
	boiler.apply_maintenance_result({"note": "water column proved"})
	await _shot("10_boiler_state_transition", boiler_view, boiler.global_position + Vector3.UP * 0.7,
			"BOILER VIEW AFTER MAINTENANCE CALL")
	await _shot("11_2b_inspection", Vector3(10.4, 4.61, -3.25), Vector3(15.4, 4.0, -3.0),
			"2B · TELEPORTED INSPECTION VIEW")
	radiator.apply_maintenance_result({"note": "vent freed and clocked"})
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID)
	world.service_round.dialogue.choose(0)
	await _shot("12_service_round_inspection", Vector3(13.0, 4.61, -2.5), Vector3(15.4, 4.0, -3.0),
			"2B VIEW AFTER MAINTENANCE AND DIALOGUE CALLS")
	var captures_ok: bool = shots.finish()
	world.shutdown_for_tests()
	world.queue_free()
	world = null
	await get_tree().process_frame
	await get_tree().process_frame
	var receipt_ok := _write_receipt(captures_ok)
	get_tree().quit(0 if captures_ok and receipt_ok else 2)

func _owner_shot(label: String, identity: String, message: String) -> void:
	var owner := world.find_child(identity, true, false) as Node3D
	var forward := owner.global_transform.basis.z.normalized()
	await _shot(label, owner.global_position + forward * 1.8 + Vector3.UP * 0.15,
			owner.global_position + Vector3.UP * 0.15, message)

func _shot(label: String, from: Vector3, target: Vector3, prompt: String) -> void:
	camera.global_position = from
	camera.look_at(target)
	var observed_stage := world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)
	banner.text = "%s\nINSPECTION: %s · OBSERVED JOB STAGE: %s" % [
			PlayerController.format_interaction_prompt(prompt, &"controller"),
			label.trim_prefix(label.substr(0, 3)).to_upper(), observed_stage]
	var ok := await shots.capture(label)
	records.append({"frame": label, "prompt": prompt.trim_prefix("[E]").strip_edges(),
			"observed_job_stage": observed_stage, "capture": "PASS" if ok else "FAIL"})

func _build_banner() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(28, 142)
	panel.size = Vector2(1050, 92)
	panel.color = Color(0.015, 0.02, 0.025, 0.90)
	layer.add_child(panel)
	banner = Label.new()
	banner.position = Vector2(48, 154)
	banner.add_theme_font_size_override("font_size", 26)
	banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56))
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	banner.add_theme_constant_override("shadow_offset_x", 3)
	banner.add_theme_constant_override("shadow_offset_y", 3)
	layer.add_child(banner)

func _close_previous_job() -> void:
	var job := ServiceRoundDirector.PREVIOUS_JOB_ID
	world.work_orders.issue_job(job, "reported")
	world.work_orders.acknowledge_job(job)
	world.work_orders.diagnose_job(job)
	world.work_orders.mark_job_awaiting_part(job)
	world.work_orders.mark_job_repairable(job)
	world.work_orders.record_job_repair(job, {"quality": "good", "note": "evidence precondition"})
	world.work_orders.close_job(job)

func _write_receipt(captures_ok: bool) -> bool:
	var path: String = shots.output_dir.path_join("composition_capture_receipt.json")
	if FileAccess.file_exists(path):
		push_error("Composition capture receipt already exists: " + path)
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write composition capture receipt: " + path)
		return false
	file.store_string(JSON.stringify({"schema_version": 1, "selector": "v2",
			"evidence_kind": "production_composition_inspection",
			"runtime_scene": "res://scenes/building/orison_v2_runtime.tscn",
			"camera_mode": "teleported_inspection", "actions": "direct_test_calls",
			"persistence_enabled": false, "cleanup_requested": true,
			"capture_result": "PASS" if captures_ok else "FAIL",
			"contracts_not_tested": ["save_reconstruction", "premature_action_denial",
				"player_traversal", "teardown_retention"], "records": records}, "\t"))
	var write_ok := file.get_error() == OK
	file.close()
	return write_ok
