extends Node

const Ecosystem := preload("res://scripts/game/open_shift_radiator_ecosystem.gd")

const BOUNDARIES := ["inspected", "named_part", "took_part", "returned",
		"opened_uncommitted"]

var failures := 0
var minute := 410.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	var evidence: Array[String] = []
	for boundary: String in BOUNDARIES:
		RealityState.reset_campaign_for_tests()
		var radiator := RadiatorProp.new()
		var ecosystem := Ecosystem.new()
		add_child(radiator)
		add_child(ecosystem)
		ecosystem.setup(null, radiator, null, func(): return minute)
		ecosystem.situation.offer(ServiceRoundDirector.RESIDENT_ID)
		_check(ecosystem.abandon_after(boundary),
				"%s is an authored abandonment boundary" % boundary)
		var state := ecosystem.situation.state()
		evidence.append(str(state.residue.get("evidence", "")))
		_check(state.resolution_kind.is_empty()
				and state.recoverable_next_state == "return_to_finish_or_explain",
				"%s continues without false completion" % boundary)
		if boundary == "took_part":
			_check(state.part_custody == "player_has_radiator_packing",
					"taken service material remains in player custody")
		if boundary == "opened_uncommitted":
			_check(radiator.open_shift_condition == "opened_uncommitted",
					"uncommitted opening leaves a physical fault")
		ecosystem.queue_free()
		radiator.queue_free()
	var unique_evidence := {}
	for value: String in evidence:
		unique_evidence[value] = true
	_check(unique_evidence.size() == BOUNDARIES.size()
			and evidence.all(func(value): return not value.is_empty()),
			"all abandonment boundaries leave concrete evidence")
	await get_tree().process_frame
	await get_tree().process_frame
	print("OPEN SHIFT ABANDON TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
