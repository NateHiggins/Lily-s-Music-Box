extends Node

const Ecosystem := preload("res://scripts/game/open_shift_radiator_ecosystem.gd")

var failures := 0
var minute := 300.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var orders := WorkOrders.new()
	orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(orders)
	_check(_close_previous(orders), "prior route fact opens the situation")
	var radiator := RadiatorProp.new()
	radiator.prop_type = "radiator"
	radiator.unit = "2B"
	add_child(radiator)
	var ecosystem := Ecosystem.new()
	add_child(ecosystem)
	ecosystem.setup(orders, radiator, null, func(): return minute)
	ecosystem._process(0.0)
	_check(float(ecosystem.situation.state().offered_at) == 300.0,
			"2B exists without issuing an objective")
	minute = 305.0
	ecosystem.advance_autonomy()
	_check(radiator.open_shift_condition == "worsening_hammer",
			"neglect becomes an audible physical change")
	minute = 312.0
	ecosystem.advance_autonomy()
	_check(str(ecosystem.situation.state().compensator) == "porter",
			"the building dispatches a real compensator")
	minute = 320.0
	ecosystem.advance_autonomy()
	var ignored := ecosystem.situation.state()
	_check(ignored.resolution_kind == "porter_temporary_shutoff"
			and ignored.residue.fault == "unrepaired",
			"compensation solves heat pressure without counterfeiting repair")
	_check(orders.job_stage(ServiceRoundDirector.JOB_ID) == "missing",
			"autonomy never advances WorkOrders authority")
	var reconstructed_radiator := RadiatorProp.new()
	reconstructed_radiator.prop_type = "radiator"
	reconstructed_radiator.unit = "2B"
	add_child(reconstructed_radiator)
	var reconstructed := Ecosystem.new()
	add_child(reconstructed)
	reconstructed.setup(orders, reconstructed_radiator, null,
			func(): return minute)
	_check(reconstructed_radiator.open_shift_condition
			== "porter_temporary_shutoff",
			"saved consequence reconstructs as a world fact")
	_check(not RealityState.data.has("building_selector"),
			"the situation remains root-agnostic")
	reconstructed.queue_free()
	reconstructed_radiator.queue_free()
	ecosystem.queue_free()
	radiator.queue_free()
	orders.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("OPEN SHIFT IGNORE TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
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
