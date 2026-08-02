extends Node
## Drives Case 01 end-to-end through the authored dialogue tree: the earned
## path sets both resolution flags, the flattering path sets none, and
## silence resolves differently by depth — annotated early, the answer at
## the heart.

var failures := 0
var gameplay: MinaCaseGameplay
var panel: CaseDialoguePanel


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var tracker := ObjectiveTracker.new()
	add_child(tracker)
	gameplay = MinaCaseGameplay.new()
	gameplay.setup(tracker)
	add_child(gameplay)
	await get_tree().process_frame
	panel = gameplay.dialogue

	# --- visit one: practical repair ---------------------------------------
	gameplay._accept_work_order()
	_check(_state().stage == "active", "work-order terminal activates Mina")
	_repair_round(0)
	gameplay._use_calibrator()
	_check(_state().stage == "stabilized" and _state().repair_count == 1,
			"first completed inspection temporarily stabilizes case")

	# --- visit one: first talk; early silence is annotated, not rewarded ---
	_talk()
	_check(panel.current_node_id == "fs_open", "first-stable entry opens fs_open")
	panel.choose_silence()
	_check(panel.current_node_id == "fs_silence",
			"early silence gets annotated and the conversation continues")
	_check(_flags().is_empty(), "early silence sets no flags")
	panel.choose(0)
	_check(panel.current_node_id == "fs_push", "pressing on reaches fs_push")
	panel.choose(0)
	_check("first_silence_named" in _flags(),
			"naming the silence records the first insight")

	# --- visit two: second practical repair --------------------------------
	_check(not gameplay.letter.enabled,
			"no letter under the door before the case recurs")
	RealityCases.reopen_case("mina_caption_crisis")
	_check(gameplay.letter.enabled,
			"recurrence slides PROVISIONAL TESTIMONY under the player's door")
	gameplay._read_letter()
	_check("DRAFT 4" in panel._line.text,
			"the letter is her annotated draft while the case is open")
	panel.choose(0)
	_repair_round(1)
	gameplay._use_calibrator()
	_check(_state().stage == "stabilized" and _state().repair_count == 2,
			"recurrence requires a second practical repair")

	# --- real talk: the flattering path goes nowhere -----------------------
	var trust_before: int = _state().trust
	_talk()
	_check(panel.current_node_id == "rt_open", "real-talk entry opens rt_open")
	panel.choose(1)  # agree with her record — the trap
	_check(panel.current_node_id == "rt_agree", "agreement lands in the trap")
	panel.choose(0)
	panel.choose(2)  # validate her fear: a thin record is a failed record
	_check(panel.current_node_id == "rt_refill", "validating the fear retreats")
	_check("assumptions_are_not_facts" not in _flags()
			and "silence_can_be_blank" not in _flags(),
			"the flattering path sets no resolution flags")
	_check(_state().trust < trust_before, "wrong turns cost trust")
	_check(_state().stage != "integration_ready",
			"flattery does not unlock integration")

	# --- real talk: the earned path ----------------------------------------
	_talk()
	panel.choose(0)                    # two of those are guesses
	panel.choose(0)                    # assumptions are not facts
	_check("assumptions_are_not_facts" in _flags(),
			"the assumption insight is earned in conversation")
	panel.choose_silence()             # listening pulls the story open
	_check(panel.current_node_id == "rt_court_door",
			"silence after the insight opens the courtroom door")
	panel.choose(0)                    # what changed?
	panel.choose(0)                    # what did the record show?
	_check(panel.current_node_id == "rt_blank", "the wound is reachable")
	panel.choose(2)                    # defend her record at the wound
	_check(panel.current_node_id == "rt_armor",
			"validating the record at the wound re-armors her")
	panel.choose(0)                    # back one layer, recoverable
	_check(panel.current_node_id == "rt_open2", "failure retreats, never dead-ends")
	panel.choose(0)                    # back to observations
	panel.choose(0)                    # assumptions flag again — dedups
	panel.choose_silence()
	panel.choose(0)
	panel.choose(0)
	_check(panel.current_node_id == "rt_blank", "the wound is reachable again")
	panel.choose(0)                    # the blank never said that
	_check(panel.current_node_id == "rt_heart", "the heart question is asked")

	# --- silence by depth: saying "leave it empty" is not the answer -------
	panel.choose(1)
	_check(panel.current_node_id == "rt_told",
			"speaking the answer aloud gets it transcribed instead")
	_check("silence_can_be_blank" not in _flags(),
			"the spoken version does not earn the insight")
	panel.choose_silence()
	_check(panel.current_node_id == "rt_earned",
			"held silence at the heart is the answer")
	_check("silence_can_be_blank" in _flags(),
			"the silence insight is earned by the mechanic itself")
	_check(_state().stage == "integration_ready",
			"both earned flags unlock integration")

	# --- integration and resolution ----------------------------------------
	_talk()
	_check(panel.current_node_id == "int_open", "integration entry opens int_open")
	panel.choose_silence()
	_check(gameplay._feedback != "", "the quiet beat lands in the room")
	gameplay._use_calibrator()
	_check(_state().resolved, "final silent calibration resolves Mina")
	_check("Silence does not require annotation" in
			RealityState.data.portal_rules,
			"resolution leaves Mina's permanent portal rule")
	_talk()
	_check(panel.current_node_id == "res_open",
			"a resolved case still has one line left")
	_check(gameplay.letter.enabled, "the letter outlives the case")
	gameplay._read_letter()
	_check("DRAFT 5" in panel._line.text
			and "Nothing is written" in panel._line.text,
			"after resolution the letter's blank stays blank")
	panel.choose(0)

	print("MINA GAMEPLAY TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _talk() -> void:
	gameplay._on_resident_interaction("mina_caption_crisis", "mina_vale")


func _state() -> Dictionary:
	return RealityState.case_state("mina_caption_crisis")


func _flags() -> Array:
	return _state().get("conversation_flags", [])


func _repair_round(round: int) -> void:
	for evidence_id in ["caption_cards", "style_guide", "redaction_pencil"]:
		while not ("caption_%d_%s=%s" % [round, evidence_id,
				gameplay._evidence_spec(evidence_id).fact]) in \
				_state().apartment_changes:
			gameplay._inspect(evidence_id)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [mina ok] ", label)
	else:
		failures += 1
		printerr("  [MINA FAIL] ", label)
