extends Node

const Ecosystem := preload("res://scripts/game/open_shift_radiator_ecosystem.gd")

var failures := 0
var minute := 515.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var radiator := RadiatorProp.new()
	add_child(radiator)
	var ecosystem := Ecosystem.new()
	add_child(ecosystem)
	ecosystem.setup(null, radiator, null, func(): return minute)
	ecosystem.situation.offer(ServiceRoundDirector.RESIDENT_ID)
	_check(ecosystem.meddle_wrong_valve(),
			"wrong-valve intervention is physically possible")
	var state := ecosystem.situation.state()
	_check(radiator.get_heat_state().supply_partial
			and radiator.open_shift_condition == "wrong_valve_partial",
			"meddling changes heat and pipe sound")
	_check("wrong_valve" in state.observed_interference
			and state.npc_knowledge.has("2c_neighbor"),
			"another inhabitant notices through the riser")
	_check(state.resolution_kind.is_empty()
			and state.recoverable_next_state
			== "restore_supply_balance_then_diagnose",
			"the worsened condition remains recoverable, not failed")
	var restored_radiator := RadiatorProp.new()
	add_child(restored_radiator)
	var restored := Ecosystem.new()
	add_child(restored)
	restored.setup(null, restored_radiator, null, func(): return minute)
	_check(restored_radiator.open_shift_condition == "wrong_valve_partial",
			"meddling reconstructs from concrete saved facts")
	_check(RealityState.data.get("maintenance_jobs", {}).is_empty(),
			"wrong intervention never counterfeits job completion")
	restored.queue_free()
	restored_radiator.queue_free()
	ecosystem.queue_free()
	radiator.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("OPEN SHIFT MEDDLE TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
