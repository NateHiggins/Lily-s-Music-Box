extends Node

var failures := 0
var minute := 210.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var situation := OpenShiftSituation.new()
	add_child(situation)
	situation.setup("radiator_2b", func(): return minute)
	_check(situation.offer("lena_ortiz"), "offer records domain owner")
	minute = 214.0
	_check(situation.notice("radiator_sound"), "notice records house time")
	situation.attend("inspect_radiator")
	situation.observe_interference("wrong_valve", "porter")
	situation.set_pressure(0.4, 0.5, 0.3)
	minute = 225.0
	_check(situation.begin_compensation("porter"), "compensation is timed")
	minute = 231.0
	_check(situation.resolve("temporary_porter_bypass", {"heat": "reduced"}),
			"resolution retains residue")
	var saved := situation.state()
	_check(saved.offered_at == 210.0 and saved.closed_at == 231.0,
			"all timestamps use injected house clock")
	_check(saved.attempted_actions == ["inspect_radiator"],
			"concrete attempts persist")
	_check(not RealityState.data.has("building_selector"),
			"situation serializes no selector")
	_check(RealityState.data.get("maintenance_jobs", {}).is_empty(),
			"observer counterfeits no work authority")
	_check(not situation.record_fact("npc_knowledge", {"x": "y"}) and
			not situation.record_fact("relationship_consequence", "z") and
			not situation.record_fact("part_custody", "player"),
			"beliefs, relationships and custody are unrecordable here")
	situation.merge_residue({"sound": "tagged_valve"})
	_check(situation.state().residue.sound == "tagged_valve" and
			situation.state().residue.heat == "reduced",
			"owners report residue through the merge API only")
	var unclocked := OpenShiftSituation.new()
	add_child(unclocked)
	unclocked.setup("radiator_2b_unclocked", Callable())
	unclocked.offer("lena_ortiz")
	unclocked.advance_simulation_minutes(7.0)
	unclocked.notice("late_notice")
	var un := unclocked.state()
	_check(un.offered_at == 180.0 and un.noticed_at == 187.0,
			"without a clock, durable simulation minutes ARE the clock")
	print("OPEN SHIFT SITUATION TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
