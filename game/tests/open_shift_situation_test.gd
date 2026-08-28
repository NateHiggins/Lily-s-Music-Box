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
	print("OPEN SHIFT SITUATION TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
