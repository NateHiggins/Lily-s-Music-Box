extends Node

var failures := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var case_id := "mina_caption_crisis"
	var plan: Array = AcousticGraphData._plan_for("F02_A_MONITOR_01")
	var reached_floors := {}
	for entry in plan:
		var node_id: String = entry.id
		if node_id.begins_with("F") or node_id.begins_with("B1"):
			reached_floors[node_id.get_slice("_", 0)] = true
	_check(reached_floors.size() >= 3,
			"Mina's manifestation can radiate across the building")
	_check(RealityCases.activate_case(case_id), "Mina work order activates")
	_check(RealityCases.stabilize_case(case_id), "first repair stabilizes")
	var state := RealityState.case_state(case_id)
	_check(state.stage == "stabilized" and state.recurrence_pending,
			"stabilization is explicitly temporary")
	_check(not RealityCases.resolve_case(case_id),
			"repair alone cannot resolve trauma")
	_check(RealityCases.reopen_case(case_id), "unresolved manifestation recurs")
	state = RealityState.case_state(case_id)
	_check(state.stage == "reopened" and state.recurrence_count == 1,
			"recurrence returns at a higher case stage")
	_check(RealityCases.stabilize_case(case_id), "second repair stabilizes")
	RealityCases.record_conversation(
			case_id, "assumptions_are_not_facts")
	RealityCases.record_conversation(case_id, "silence_can_be_blank")
	_check(RealityState.case_state(case_id).stage == "integration_ready",
			"required recognition unlocks integration")
	_check(RealityCases.resolve_case(case_id),
			"repeated repair plus recognition resolves case")
	state = RealityState.case_state(case_id)
	_check(state.resolved and not state.recurrence_pending,
			"resolved case cannot recur")
	_check("Silence does not require annotation" in
			RealityState.data.portal_rules,
			"resolution contributes its storage-portal rule")
	print("REALITY CASE TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [case ok] ", label)
	else:
		failures += 1
		printerr("  [CASE FAIL] ", label)
