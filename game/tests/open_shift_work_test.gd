extends Node

const Ecosystem := preload("res://scripts/game/open_shift_radiator_ecosystem.gd")

var failures := 0
var minute := 600.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var orders := WorkOrders.new()
	orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(orders)
	_check(_close_previous(orders), "prior work remains a durable fact")
	var radiator := RadiatorProp.new()
	radiator.name = ServiceRoundDirector.RADIATOR_ID
	radiator.prop_type = "radiator"
	add_child(radiator)
	var round := ServiceRoundDirector.new()
	add_child(round)
	round.setup(orders, self, null)
	var ecosystem := Ecosystem.new()
	add_child(ecosystem)
	ecosystem.setup(orders, radiator, round, func(): return minute)
	ecosystem._process(0.0)
	_check(round.answer_incoming_call(),
			"resident call offers work without assigning a goal")
	_check(orders.acknowledge_job(ServiceRoundDirector.JOB_ID),
			"player may acknowledge through WorkOrders authority")
	round.route_beat.emit("resident")
	for evidence: String in ["radiator_airbound", "lobby_contact_compared",
			"boiler_pressure_compared"]:
		_check(orders.record_job_evidence(ServiceRoundDirector.JOB_ID, evidence),
				"records concrete evidence: " + evidence)
	_check(orders.diagnose_job(ServiceRoundDirector.JOB_ID),
			"evidence permits diagnosis")
	round.route_beat.emit("diagnosis")
	_check(orders.mark_job_repairable(ServiceRoundDirector.JOB_ID),
			"no-part fault becomes repairable")
	radiator.apply_maintenance_result({
		"note": "vent seated; supply returned fully open",
		"mechanism_patch": {"vent_grade": 2, "supply_position": 1.0},
	})
	_check(orders.job_stage(ServiceRoundDirector.JOB_ID) == "repaired",
			"physical repair publishes once through the job authority")
	_check(orders.close_job(ServiceRoundDirector.JOB_ID),
			"resident return may close the work paper")
	round.route_beat.emit("resident_return")
	var state := ecosystem.situation.state()
	_check(state.resolution_kind == "player_repair"
			and state.residue.fault == "repaired",
			"competent work leaves authored physical and social residue")
	_check(orders.job_stage(ServiceRoundDirector.JOB_ID) == "closed",
			"exactly one authority owns completion")
	_check(not RealityState.data.has("building_selector"),
			"competent disposition remains root-agnostic")
	ecosystem.queue_free()
	round.queue_free()
	radiator.queue_free()
	orders.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("OPEN SHIFT WORK TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)


func _close_previous(orders: WorkOrders) -> bool:
	var job := ServiceRoundDirector.PREVIOUS_JOB_ID
	return orders.issue_job(job, "reported") \
			and orders.acknowledge_job(job) \
			and orders.diagnose_job(job) \
			and orders.mark_job_awaiting_part(job) \
			and orders.mark_job_repairable(job) \
			and orders.record_job_repair(job, {
				"quality": "good", "note": "closed fixture",
			}) and orders.close_job(job)
