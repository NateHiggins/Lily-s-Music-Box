extends Node
## SR4 focused proof: a resident-filed call crosses apartment, lobby and
## basement owners, returns for a physical repair, and closes only in the
## resident conversation. No stand-in lifecycle exists in this harness.

var failures := 0
var orders: WorkOrders
var director: ServiceRoundDirector
var beats: Array[String] = []
var radiator: RadiatorProp
var board: OtisProp
var boiler: BoilerProp


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.ensure_case(ServiceRoundDirector.CASE_ID,
			ServiceRoundDirector.RESIDENT_ID)
	var tracker := ObjectiveTracker.new()
	add_child(tracker)
	orders = WorkOrders.new()
	orders.setup(tracker)
	orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(orders)
	_build_mechanisms()
	director = ServiceRoundDirector.new()
	add_child(director)
	director.route_beat.connect(func(beat: String): beats.append(beat))
	director.setup(orders, self, null)
	await get_tree().process_frame

	_check(not director.has_incoming_call(),
			"the second job cannot compete with Mina's opening loop")
	_close_previous_job()
	_check(director.has_incoming_call(),
			"closing the previous authored job queues exactly one resident call")
	_check(director.answer_incoming_call()
			and orders.job_stage(ServiceRoundDirector.JOB_ID) == "issued"
			and not director.answer_incoming_call(),
			"answering the physical line files one reported work order")
	director.dialogue.choose(0)

	# Props cannot diagnose or repair before the resident has spoken.
	board.maintenance_completed.emit({"note": "early board"})
	boiler.maintenance_completed.emit({"note": "early boiler"})
	radiator.maintenance_completed.emit({"note": "early radiator"})
	_check(orders.job_state(ServiceRoundDirector.JOB_ID).evidence.is_empty()
			and orders.job_stage(ServiceRoundDirector.JOB_ID) == "issued",
			"mechanism activity before the threshold conversation changes nothing")

	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID)
	_check(orders.job_stage(ServiceRoundDirector.JOB_ID) == "acknowledged"
			and director.dialogue.current_node_id == "",
			"Lena's real resident-interaction signal acknowledges the call")
	director.dialogue.choose(0)

	# Inspection is opening the actual target reach; it does not require a
	# successful repair and is harmless if repeated.
	boiler.maintenance_completed.emit({"note": "basement visited too early"})
	_check(orders.job_state(ServiceRoundDirector.JOB_ID).evidence.is_empty(),
			"the basement cannot replace the apartment-first diagnostic route")
	director._on_world_modified(Vector3.ZERO, ServiceRoundDirector.RADIATOR_ID)
	director._on_world_modified(Vector3.ZERO, ServiceRoundDirector.RADIATOR_ID)
	board.maintenance_completed.emit({"note": "contacts squared"})
	_check(orders.job_stage(ServiceRoundDirector.JOB_ID) == "acknowledged",
			"apartment plus lobby evidence cannot skip the basement comparison")
	boiler.maintenance_completed.emit({"note": "column proved"})
	_check(orders.job_stage(ServiceRoundDirector.JOB_ID) == "repairable"
			and orders.job_state(ServiceRoundDirector.JOB_ID).evidence == [
				"radiator_airbound", "lobby_contact_compared",
				"boiler_pressure_compared"],
			"three ordered places earn diagnosis and the no-part repairable stage")

	radiator.maintenance_completed.emit({
		"note": "vent seated; supply returned fully open"})
	_check(orders.job_stage(ServiceRoundDirector.JOB_ID) == "repaired",
			"only the 2B radiator completion records the repair")
	_check(not orders.close_job("missing_job"),
			"an unrelated close cannot affect the round")
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID)
	_check(orders.job_stage(ServiceRoundDirector.JOB_ID) == "repaired",
			"returning to Lena opens conversation but does not close by proximity")
	director.dialogue.choose(0)
	_check(orders.job_stage(ServiceRoundDirector.JOB_ID) == "closed"
			and "service_round_visible_patch" in RealityState.case_state(
					ServiceRoundDirector.CASE_ID).conversation_flags,
			"the deliberate resident reply closes and records an ordinary insight")
	_check(beats == ["call", "resident", "radiator_evidence",
			"lobby_comparison", "basement_comparison", "diagnosis", "repair",
			"resident_return"],
			"the trace proves call, conversation, travel/search, repair and return")

	print("MAINTENANCE SERVICE ROUND TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	for child: Node in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	PropAudio.clear_cache()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(failures)


func _build_mechanisms() -> void:
	radiator = RadiatorProp.new()
	radiator.name = ServiceRoundDirector.RADIATOR_ID
	radiator.unit = "2B"
	add_child(radiator)
	board = OtisProp.new()
	board.name = ServiceRoundDirector.BOARD_ID
	add_child(board)
	boiler = BoilerProp.new()
	boiler.name = ServiceRoundDirector.BOILER_ID
	add_child(boiler)


func _close_previous_job() -> void:
	const JOB := ServiceRoundDirector.PREVIOUS_JOB_ID
	orders.issue_job(JOB, "reported")
	orders.acknowledge_job(JOB)
	orders.diagnose_job(JOB)
	orders.mark_job_awaiting_part(JOB)
	orders.mark_job_repairable(JOB)
	orders.record_job_repair(JOB, {"quality": "good", "note": "test"})
	orders.close_job(JOB)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [round ok] ", label)
	else:
		failures += 1
		printerr("  [ROUND FAIL] ", label)
