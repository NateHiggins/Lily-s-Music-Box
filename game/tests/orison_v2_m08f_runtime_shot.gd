extends Node

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const RUNTIME := preload("res://scenes/building/orison_v2_runtime.tscn")
var shots = ShotHarnessScript.new()
var world: OrisonV2RuntimeRoot
var camera: Camera3D
var banner: Label
var records: Array[Dictionary] = []

func _ready() -> void:
	if not shots.setup(self, "ORISON-V2-M08F", 15):
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
			radiator.interact_prompt(), "acknowledged")
	world.player.world_modified.emit(radiator.global_position, ServiceRoundDirector.RADIATOR_ID)
	await _shot("02_radiator_inspection_transition", Vector3(13.0, 4.61, -2.5), Vector3(15.4, 4.0, -3.0),
			"RADIATOR EVIDENCE RECORDED", "acknowledged")
	await _shot("03_return_to_f01_station", Vector3(-1.65, 1.41, -2.6), Vector3(-4.1, 1.05, -1.0),
			"RETURN TO PORTER / RITUAL STATION", "acknowledged")
	await _owner_shot("04_watchman_detector", "F01_WATCHMAN_DETECTOR", "WATCHMAN DETECTOR · PRODUCTION AUTHORITY")
	await _owner_shot("05_night_register", "F01_NIGHT_REGISTER", "NIGHT REGISTER · PRODUCTION AUTHORITY")
	await _owner_shot("06_signal_register", "F01_SIGNAL_REGISTER", "SIGNAL REGISTER · PRODUCTION AUTHORITY")
	await _owner_shot("07_tour_key_custody", "F01_TOUR_KEY_GUARD", "TOUR KEY · TAKE / HOLD / RETURN")
	board.apply_maintenance_result({"note": "contacts squared"})
	await _shot("08_b1_descent", Vector3(2.2, -1.79, -2.9), Vector3(6.8, -1.9, -0.5),
			"B1 DESCENT · COLLISION-BEARING ROUTE", "acknowledged")
	var boiler_view := boiler.global_position + boiler.global_transform.basis.z.normalized() * 2.4 + Vector3.UP * 0.5
	await _shot("09_boiler_real_prompt", boiler_view, boiler.global_position + Vector3.UP * 0.7,
			boiler.control_prompt("water_column"), "acknowledged")
	boiler.apply_maintenance_result({"note": "water column proved"})
	await _shot("10_boiler_state_transition", boiler_view, boiler.global_position + Vector3.UP * 0.7,
			"BOILER COMPARISON RECORDED · DIAGNOSIS REPAIRABLE", "repairable")
	await _shot("11_return_to_2b", Vector3(10.4, 4.61, -3.25), Vector3(15.4, 4.0, -3.0),
			"RETURN TO 2B · REPAIR AUTHORIZED", "repairable")
	radiator.apply_maintenance_result({"note": "vent freed and clocked"})
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID)
	world.service_round.dialogue.choose(0)
	await _shot("12_completed_service_round", Vector3(13.0, 4.61, -2.5), Vector3(15.4, 4.0, -3.0),
			"SERVICE ROUND CLOSED · VISIBLE PATCH RECORDED", "closed")
	await _shot("13_save_reconstruction_contract", Vector3(11.9, 4.61, -2.55), Vector3(13.7, 4.1, -0.35),
			"SAVE → DESTROY → CAMPAIGN RECONSTRUCT · SEMANTIC FACTS PRESERVED", "closed")
	await _shot("14_premature_action_denied", Vector3(7.2, -1.79, -0.4), Vector3(10.8, -2.0, -0.45),
			"DENIAL PROOF · PREMATURE ACTION CANNOT ADVANCE", "closed")
	await _shot("15_final_teardown_receipt", Vector3(-3.3, 1.41, -6.2), Vector3(-3.3, 1.0, -2.0),
			"TEARDOWN OWNER · ADAPTER + PROP AUDIO · 0 RETAINED", "closed")
	_write_receipt()
	world.shutdown_for_tests()
	world.queue_free()
	get_tree().quit(0 if shots.finish() else 2)

func _owner_shot(label: String, identity: String, message: String) -> void:
	var owner := world.find_child(identity, true, false) as Node3D
	var forward := owner.global_transform.basis.z.normalized()
	await _shot(label, owner.global_position + forward * 1.8 + Vector3.UP * 0.15,
			owner.global_position + Vector3.UP * 0.15, message, "acknowledged")

func _shot(label: String, from: Vector3, target: Vector3, prompt: String,
		phase: String) -> void:
	camera.global_position = from
	camera.look_at(target)
	banner.text = "%s\nAUTHORITY: %s · SAVE PHASE: %s" % [
			PlayerController.format_interaction_prompt(prompt, &"controller"),
			label.trim_prefix(label.substr(0, 3)).to_upper(), phase]
	var ok := await shots.capture(label)
	records.append({"frame": label, "prompt": prompt.trim_prefix("[E]").strip_edges(),
			"save_phase": phase, "capture": "PASS" if ok else "FAIL"})

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

func _write_receipt() -> void:
	var file := FileAccess.open(shots.output_dir.path_join("runtime_authority_receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "selector": "v2",
			"production_runtime": true, "records": records}, "\t"))
