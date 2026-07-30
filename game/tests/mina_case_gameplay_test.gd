extends Node

var failures := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var tracker := ObjectiveTracker.new()
	add_child(tracker)
	var gameplay := MinaCaseGameplay.new()
	gameplay.setup(tracker)
	add_child(gameplay)
	await get_tree().process_frame

	gameplay._accept_work_order()
	_check(RealityState.case_state("mina_caption_crisis").stage == "active",
			"work-order terminal activates Mina")
	for evidence_id in ["caption_cards", "style_guide", "redaction_pencil"]:
		while gameplay._inspection_count(RealityState.case_state(
				"mina_caption_crisis")) < (
				["caption_cards", "style_guide", "redaction_pencil"].find(
				evidence_id) + 1):
			gameplay._inspect(evidence_id)
	gameplay._use_calibrator()
	var state := RealityState.case_state("mina_caption_crisis")
	_check(state.stage == "stabilized" and state.repair_count == 1,
			"first completed inspection temporarily stabilizes case")
	RealityCases.reopen_case("mina_caption_crisis")
	for evidence_id in ["caption_cards", "style_guide", "redaction_pencil"]:
		while not ("caption_1_%s=%s" % [evidence_id,
				gameplay._evidence_spec(evidence_id).fact]) in \
				RealityState.case_state(
				"mina_caption_crisis").apartment_changes:
			gameplay._inspect(evidence_id)
	gameplay._use_calibrator()
	state = RealityState.case_state("mina_caption_crisis")
	_check(state.stage == "stabilized" and state.repair_count == 2,
			"recurrence requires a second practical repair")
	gameplay._record_insight("assumptions_are_not_facts")
	gameplay._record_insight("silence_can_be_blank")
	_check(RealityState.case_state("mina_caption_crisis").stage ==
			"integration_ready", "real-talk insights unlock integration")
	gameplay._use_calibrator()
	state = RealityState.case_state("mina_caption_crisis")
	_check(state.resolved, "final silent calibration resolves Mina")
	_check("Silence does not require annotation" in
			RealityState.data.portal_rules,
			"resolution leaves Mina's permanent portal rule")

	print("MINA GAMEPLAY TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [mina ok] ", label)
	else:
		failures += 1
		printerr("  [MINA FAIL] ", label)
