extends Node
## LC-6F focused contract: one bounded clock names every co-present danger,
## while classification cannot advance pursuit, arm a tell or contact a body.

const EXPECTED_CHECKS := 24
const CAP := 100.0
var checks := 0
var failures := 0


func _ready() -> void:
	print("[LC-6F] START")
	_test_vocabulary()
	_test_shared_owners()
	_test_invariants()
	if checks != EXPECTED_CHECKS:
		failures += 1
		print("[LC-6F] FAIL check count %d/%d" % [checks, EXPECTED_CHECKS])
	if failures == 0:
		print("[LC-6F] PASS %d/%d" % [checks, EXPECTED_CHECKS])
	else:
		print("[LC-6F] FAIL %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _test_vocabulary() -> void:
	var samples := [0.0, 4.0, 14.0, 28.0, 62.0, 75.0, 88.0, 96.0]
	var names := ["folded", "bud", "juvenile", "mature", "exchange",
			"senescent", "shed", "stain"]
	for i in samples.size():
		_check(DreamOrganelleLifecycle.stage_name(
				DreamOrganelleLifecycle.bounded_run_stage(samples[i], CAP)) == names[i],
				"stage %s" % names[i])
	_check(DreamOrganelleLifecycle.bounded_run_stage(50.0, 0.0)
			== DreamOrganelleLifecycle.Stage.MATURE, "unbounded is mature")
	_check(DreamIncarnationProfile.lifecycle_stage_at(75.0, CAP)
			== DreamOrganelleLifecycle.Stage.SENESCENT,
			"incarnation delegates to shared boundary")


func _test_shared_owners() -> void:
	var pursuer := DreamPursuer.new()
	var field := DreamHazardField.new()
	var hazard := DreamHazard.new()
	field.hazards.append(hazard)
	for elapsed in [2.0, 20.0, 68.0, 98.0]:
		var pstage := pursuer.classify_lifecycle(elapsed, CAP)
		var hstage := field.classify_lifecycle(elapsed, CAP)
		_check(pstage == hstage, "pursuer and field agree at %.0f" % elapsed)
		_check(hazard.lifecycle_stage == hstage,
				"hazard shares field stage at %.0f" % elapsed)
	pursuer.free()


func _test_invariants() -> void:
	var pursuer := DreamPursuer.new()
	pursuer.elapsed_s = 7.25
	pursuer.position = Vector3(2.0, 0.0, -3.0)
	var field := DreamHazardField.new()
	var hazard := DreamHazard.new()
	hazard.tell_started_s = -1.0
	hazard.contacted = false
	field.hazards.append(hazard)
	var before_position := pursuer.position
	var before_elapsed := pursuer.elapsed_s
	var before_perception := field.perception_log.duplicate(true)
	var before_impacts := field.impact_log.duplicate(true)
	pursuer.classify_lifecycle(80.0, CAP)
	field.classify_lifecycle(80.0, CAP)
	_check(pursuer.position == before_position, "classification does not move pursuer")
	_check(is_equal_approx(pursuer.elapsed_s, before_elapsed),
			"classification does not advance pursuer clock")
	_check(hazard.tell_started_s < 0.0, "classification does not start tell")
	_check(not hazard.contacted, "classification does not contact hazard")
	_check(field.perception_log == before_perception,
			"classification does not write perception")
	_check(field.impact_log == before_impacts,
			"classification does not write impact")
	pursuer.free()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("[LC-6F] FAIL %s" % label)
