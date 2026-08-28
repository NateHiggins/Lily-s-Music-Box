extends Node
## M08F: the accepted v2 route carries the existing production authorities.

const Selector := preload("res://scripts/building/building_root_selector.gd")
const REQUIRED := ["F01_WATCHMAN_DETECTOR", "F01_NIGHT_REGISTER",
		"F01_SIGNAL_REGISTER", "F01_TOUR_KEY_GUARD",
		"F02_B_RADIATOR_01", "B1_BOILER_01"]

var failures := 0
var passes := 0
var beats: Array[String] = []

func _ready() -> void:
	var saved_persistence := RealityState.persistence_enabled
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityCases._ready()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE}
	Selector.reset_for_tests("v2")
	var started := Time.get_ticks_usec()
	var packed := load(Selector.scene_path()) as PackedScene
	var world := packed.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	var cold_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_check(not world.startup_failed, "production-composed v2 root starts")
	for identity in REQUIRED:
		_check(world.find_children(identity, "", true, false).size() == 1,
				"one production gameplay authority: " + identity)
		_check(world.find_children(identity + "_Semantic", "", true, false).size() == 1,
				"one preserved spatial owner: " + identity)
	_check(world.find_children("FirstShiftDirector", "", true, false).size() == 1
			and world.find_children("ServiceRoundDirector", "", true, false).size() == 1
			and world.find_children("WorkOrders", "", true, false).size() == 1,
			"one lifecycle and save authority per contract")
	_check(world.find_children("*", "OrisonV2M08ESpatialCues", true, false).is_empty(),
			"review-only cues are absent from production runtime")

	var detector := world.find_child("F01_WATCHMAN_DETECTOR", true, false) as WatchmanClockProp
	var register := world.find_child("F01_NIGHT_REGISTER", true, false) as NightRegisterProp
	var signal_register := world.find_child("F01_SIGNAL_REGISTER", true, false) as WatchRegisterProp
	var guard := world.find_child("F01_TOUR_KEY_GUARD", true, false) as TourKeyGuardProp
	var radiator := world.find_child("F02_B_RADIATOR_01", true, false) as RadiatorProp
	var board := world.find_child("LobbyPorterBoard", true, false) as OtisProp
	var boiler := world.find_child("B1_BOILER_01", true, false) as BoilerProp
	_check(PlayerController.format_interaction_prompt(
			detector.control_prompt("detector"), &"controller").begins_with("[A]")
			and PlayerController.format_interaction_prompt(
					radiator.interact_prompt(), &"touch").begins_with("[TAP]"),
			"central formatter produces carrier-neutral prompts")
	_check(not guard.return_key() and not signal_register.receive_signal({
			"station_number": 9}), "ritual denial states refuse invented acts")

	_close_previous_job(world.work_orders)
	world.service_round.route_beat.connect(func(beat: String): beats.append(beat))
	_check(world.service_round.has_incoming_call()
			and world.service_round.answer_incoming_call()
			and not world.service_round.answer_incoming_call(),
			"service-set call issues exactly one authored radiator obligation")
	world.service_round.dialogue.choose(0)
	boiler.apply_maintenance_result({"note": "premature boiler"})
	radiator.apply_maintenance_result({"note": "premature radiator"})
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID) == "issued"
			and world.work_orders.job_state(ServiceRoundDirector.JOB_ID).evidence.is_empty(),
			"premature mechanisms cannot counterfeit progress")
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID)
	world.service_round.dialogue.choose(0)
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID) == "acknowledged",
			"resident threshold acknowledges the production work order")
	world.player.world_modified.emit(radiator.global_position,
			ServiceRoundDirector.RADIATOR_ID)
	world.player.world_modified.emit(radiator.global_position,
			ServiceRoundDirector.RADIATOR_ID)
	board.apply_maintenance_result({"note": "contacts squared"})
	boiler.apply_maintenance_result({"note": "water column proved"})
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID) == "repairable",
			"radiator, porter board, and boiler evidence earns repairability")
	var before_duplicate := world.work_orders.job_state(ServiceRoundDirector.JOB_ID).duplicate(true)
	boiler.apply_maintenance_result({"note": "duplicate"})
	_check(world.work_orders.job_state(ServiceRoundDirector.JOB_ID) == before_duplicate,
			"duplicate interaction cannot double-advance")
	radiator.apply_maintenance_result({
			"note": "vent freed and clocked; supply returned fully open"})
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID) == "repaired",
			"real 2B radiator authority records the repair")
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID)
	world.service_round.dialogue.choose(0)
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID) == "closed",
			"resident return closes the authored service round")
	_check(beats == ["call", "resident", "radiator_evidence", "lobby_comparison",
			"basement_comparison", "diagnosis", "repair", "resident_return"],
			"production event trace preserves the complete round")

	var save_path := "user://tests/m08f_runtime.json"
	var old_path := RealityState.save_path
	RealityState.save_path = save_path
	RealityState.persistence_enabled = true
	var save_started := Time.get_ticks_usec()
	var saved := RealityState.save_game()
	var save_ms := float(Time.get_ticks_usec() - save_started) / 1000.0
	var expected := world.work_orders.job_state(ServiceRoundDirector.JOB_ID).duplicate(true)
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	packed = null
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	# No composed world remains; release the process-wide warm cache so the
	# harness can distinguish retired-scene retention from intentional caching.
	PropAudio.clear_cache()
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	var loaded := not RealityState.data.is_empty()
	Selector.reset_for_tests("v2")
	var reconstruct_started := Time.get_ticks_usec()
	var shell := CampaignShell.new()
	add_child(shell)
	await get_tree().process_frame
	var reconstruct_ms := float(Time.get_ticks_usec() - reconstruct_started) / 1000.0
	var reconstructed := shell.active_world as OrisonV2RuntimeRoot
	_check(saved and loaded and reconstructed != null
			and reconstructed.work_orders.job_state(ServiceRoundDirector.JOB_ID) == expected,
			"save, destroy, CampaignShell reconstruct, and load preserve round facts")
	_check(str(reconstructed.core_loop.resolve_return_anchor().get("id", ""))
			== "F04_B_BED", "v2 wake uses explicit bedside-return contract")
	print("[M08F PERF] cold_ms=%.3f compose_ms=%.3f save_ms=%.3f reconstruct_ms=%.3f nodes=%d collisions=%d cpu_ms=%.3f physics_ms=%.3f" % [
			cold_ms, reconstructed.startup_ms, save_ms, reconstruct_ms,
			_count_nodes(reconstructed), reconstructed.find_children(
					"*", "CollisionObject3D", true, false).size(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	reconstructed.shutdown_for_tests()
	remove_child(shell)
	shell.free()
	await get_tree().process_frame
	await get_tree().process_frame
	# The owners above detach every stream synchronously. Give the audio server
	# one bounded mix interval to retire the already-detached decoder playback
	# before this process-level retention assertion exits.
	await get_tree().create_timer(0.1).timeout
	PropAudio.clear_cache()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	RealityState.save_path = old_path
	RealityState.persistence_enabled = saved_persistence
	RealityState.reset_campaign_for_tests()
	Selector.reset_for_tests()
	_check(FileAccess.get_sha256("res://data/building_layout.json")
			== "68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d",
			"production layout remains byte-stable")
	_check(Selector.DEFAULT_ID == "v1", "committed selector remains v1")
	print("ORISON V2 M08F RUNTIME: %s checks=%d" % [
			"PASS" if failures == 0 else "FAIL (%d)" % failures, passes + failures])
	get_tree().quit(failures)

func _close_previous_job(orders: WorkOrders) -> void:
	var job := ServiceRoundDirector.PREVIOUS_JOB_ID
	orders.issue_job(job, "reported")
	orders.acknowledge_job(job)
	orders.diagnose_job(job)
	orders.mark_job_awaiting_part(job)
	orders.mark_job_repairable(job)
	orders.record_job_repair(job, {"quality": "good", "note": "M08F prerequisite"})
	orders.close_job(job)

func _count_nodes(root: Node) -> int:
	var total := 1
	for child: Node in root.get_children():
		total += _count_nodes(child)
	return total

func _check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
