class_name MinaCaseGameplay
extends Node3D
## Complete first-pass playable flow for Caption Crisis: accept, inspect,
## calibrate, recur, re-inspect, talk honestly, and integrate.

const CASE_ID := "mina_caption_crisis"
const EVIDENCE := [
	{"id": "caption_cards", "name": "Caption Cards",
	 "at": [-11.55, -4.55, 4.25], "fact": "CARDS",
	 "choices": ["WAITING", "CARDS", "FAILURE"]},
	{"id": "style_guide", "name": "Personal Style Guide",
	 "at": [-9.15, -2.45, 4.25], "fact": "BOOK",
	 "choices": ["DISAPPOINTED", "USEFUL", "BOOK"]},
	{"id": "redaction_pencil", "name": "Redaction Pencil",
	 "at": [-10.0, -5.35, 4.25], "fact": "PENCIL",
	 "choices": ["PENCIL", "JUDGMENT", "EXPLANATION"]},
]

var tracker: ObjectiveTracker
var terminal: CaseInteractable
var console: CaseInteractable
var shift_clock: CaseInteractable
var dialogue: CaseDialoguePanel
var evidence_nodes: Array[CaseInteractable] = []
var _choice_indices: Dictionary = {}
var _feedback := ""
var _visit_overlay: ColorRect
var _visit_label: Label


func setup(objective_tracker: ObjectiveTracker) -> void:
	tracker = objective_tracker


func _ready() -> void:
	_build_terminal()
	_build_apartment_targets()
	_build_dialogue()
	_build_visit_boundary()
	RealityCases.case_changed.connect(_on_case_changed)
	RealityCases.resident_interaction_requested.connect(
			_on_resident_interaction)
	_refresh()


func _build_terminal() -> void:
	terminal = CaseInteractable.new()
	terminal.setup("WORK ORDER 002-A", "Accept Caption Crisis work order",
			_accept_work_order, Color(0.20, 0.31, 0.27),
			Vector3(0.72, 0.62, 0.12))
	terminal.position = GameBoot.b2g([-2.6, -7.3, 0.95])
	add_child(terminal)


func _build_apartment_targets() -> void:
	for spec in EVIDENCE:
		var item := CaseInteractable.new()
		var evidence_id: String = spec.id
		item.setup(spec.name, "Change caption on " + spec.name,
				func(): _inspect(evidence_id),
				Color(0.32, 0.27, 0.20))
		item.position = GameBoot.b2g(spec.at)
		add_child(item)
		evidence_nodes.append(item)
	console = CaseInteractable.new()
	console.setup("CAPTION CALIBRATOR", "Run caption calibration",
			_use_calibrator, Color(0.16, 0.31, 0.36),
			Vector3(0.48, 0.42, 0.26))
	console.position = GameBoot.b2g([-9.35, -2.05, 4.20])
	add_child(console)


func _build_dialogue() -> void:
	dialogue = CaseDialoguePanel.new()
	add_child(dialogue)


func _build_visit_boundary() -> void:
	shift_clock = CaseInteractable.new()
	shift_clock.setup("TIME CLOCK", "Clock out and return for visit two",
			_advance_visit, Color(0.18, 0.21, 0.19),
			Vector3(0.38, 0.54, 0.16))
	shift_clock.position = GameBoot.b2g([-3.55, -7.35, 0.92])
	add_child(shift_clock)
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_visit_overlay = ColorRect.new()
	_visit_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visit_overlay.color = Color(0.008, 0.012, 0.018, 0.0)
	_visit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_visit_overlay)
	_visit_label = Label.new()
	_visit_label.set_anchors_preset(Control.PRESET_CENTER)
	_visit_label.position = Vector2(-230, -30)
	_visit_label.size = Vector2(460, 80)
	_visit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_visit_label.add_theme_font_size_override("font_size", 22)
	_visit_label.modulate = Color(0.72, 0.82, 0.78, 0.0)
	layer.add_child(_visit_label)


func _accept_work_order() -> void:
	RealityCases.activate_case(CASE_ID)


func _inspect(evidence_id: String) -> void:
	var state := RealityState.case_state(CASE_ID)
	if state.is_empty():
		return
	var round := int(state.get("recurrence_count", 0))
	var spec := _evidence_spec(evidence_id)
	if spec.is_empty():
		return
	var key := "%d_%s" % [round, evidence_id]
	var index: int = (int(_choice_indices.get(key, -1)) + 1) \
			% spec.choices.size()
	_choice_indices[key] = index
	var selected: String = spec.choices[index]
	var prefix := "caption_%d_%s=" % [round, evidence_id]
	for marker in state.apartment_changes.duplicate():
		if str(marker).begins_with(prefix):
			state.apartment_changes.erase(marker)
	state.apartment_changes.append(prefix + selected)
	_feedback = "%s now reads: %s" % [spec.name, selected]
	RealityState.commit()
	_refresh()


func _use_calibrator() -> void:
	var state := RealityState.case_state(CASE_ID)
	if state.is_empty():
		return
	if state.stage == "integration_ready":
		RealityCases.resolve_case(CASE_ID)
		return
	if state.stage not in ["active", "reopened", "recognized", "resistant"]:
		return
	if _inspection_count(state) < EVIDENCE.size():
		_feedback = "Calibration rejected: some captions claim more than is observable."
		_refresh()
		return
	_feedback = ""
	RealityCases.stabilize_case(CASE_ID)


func _record_insight(flag: String) -> void:
	RealityCases.record_conversation(CASE_ID, flag)


func _on_resident_interaction(case_id: String, resident_id: String) -> void:
	if case_id != CASE_ID or resident_id != "mina_vale":
		return
	var state := RealityState.case_state(CASE_ID)
	var repairs := int(state.get("repair_count", 0))
	var flags: Array = state.get("conversation_flags", [])
	if state.stage == "stabilized" and repairs == 1:
		dialogue.present("MINA VALE",
				"It stopped when you made the captions literal. But when someone "
				+ "goes quiet, I still hear a verdict forming.",
				[
					{"text": "Silence isn't evidence of what someone thinks.",
					 "action": func(): _record_insight("first_silence_named")},
					{"text": "Then we should caption the silence more carefully.",
					 "action": func(): _record_insight_with_delta(
							"first_silence_misread", -1)},
				])
	elif repairs >= 2 and "assumptions_are_not_facts" not in flags:
		dialogue.present("MINA VALE",
				"I caption the pause before anyone can use it against me. "
				+ "Disappointed. Annoyed. Leaving.",
				[
					{"text": "Those are assumptions, not observable facts.",
					 "action": func(): _record_insight(
							"assumptions_are_not_facts")},
					{"text": "Pick the most likely interpretation.",
					 "action": func(): _record_insight_with_delta(
							"interpretation_is_safety", -1)},
				])
	elif repairs >= 2 and "silence_can_be_blank" not in flags:
		dialogue.present("MINA VALE",
				"If I leave a silence blank, it feels like I failed to catch "
				+ "the important part.",
				[
					{"text": "Blank can be accurate. You don't have to invent it.",
					 "action": func(): _record_insight("silence_can_be_blank")},
					{"text": "Every pause must mean something.",
					 "action": func(): _record_insight_with_delta(
							"silence_requires_answer", -1)},
				])
	elif state.stage == "integration_ready":
		dialogue.present("MINA VALE",
				"Then let's leave one thing unexplained on purpose.",
				[{"text": "[Leave a quiet beat.]",
				  "action": _leave_quiet_beat}])
	else:
		dialogue.present("MINA VALE",
				"The captions are still getting ahead of what actually happened.",
				[{"text": "I'll keep the next pass strictly factual.",
				  "action": _no_op}])


func _leave_quiet_beat() -> void:
	_feedback = "The apartment waits without supplying an answer."
	_refresh()


func _no_op() -> void:
	pass


func _record_insight_with_delta(flag: String, trust_delta: int) -> void:
	RealityCases.record_conversation(CASE_ID, flag, trust_delta)


func _advance_visit() -> void:
	shift_clock.set_enabled(false)
	_visit_label.text = "VISIT TWO  ·  11:43 PM\nSAME COMPLAINT, DIFFERENT WORDING"
	var player := get_tree().get_first_node_in_group(
			"player_controller") as PlayerController
	if player:
		player.call_locked = true
	var tween := create_tween()
	tween.tween_property(_visit_overlay, "color:a", 1.0, 0.45)
	tween.parallel().tween_property(_visit_label, "modulate:a", 1.0, 0.45)
	tween.tween_interval(1.15)
	tween.tween_callback(func(): RealityCases.reopen_case(CASE_ID))
	tween.tween_property(_visit_overlay, "color:a", 0.0, 0.65)
	tween.parallel().tween_property(_visit_label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func():
		if player:
			player.call_locked = false)


func _inspection_count(state: Dictionary) -> int:
	var count := 0
	var round := int(state.get("recurrence_count", 0))
	for spec in EVIDENCE:
		var expected := "caption_%d_%s=%s" % [
				round, spec.id, spec.fact]
		if expected in state.get("apartment_changes", []):
			count += 1
	return count


func _evidence_spec(evidence_id: String) -> Dictionary:
	for spec in EVIDENCE:
		if spec.id == evidence_id:
			return spec
	return {}


func _selected_caption(state: Dictionary, evidence_id: String) -> String:
	var prefix := "caption_%d_%s=" % [
			int(state.get("recurrence_count", 0)), evidence_id]
	for marker in state.get("apartment_changes", []):
		if str(marker).begins_with(prefix):
			return str(marker).trim_prefix(prefix)
	return "?"


func _on_case_changed(changed_case: String, _state: Dictionary) -> void:
	if changed_case == CASE_ID:
		_refresh()


func _refresh() -> void:
	var state := RealityState.case_state(CASE_ID)
	if state.is_empty():
		return
	var stage: String = state.get("stage", "unseen")
	var repairs := int(state.get("repair_count", 0))
	var inspected := _inspection_count(state)
	var awaiting_shift := repairs == 1 \
			and bool(state.get("recurrence_pending", false))
	terminal.set_enabled(stage == "unseen")
	var inspecting := stage in ["active", "reopened", "recognized", "resistant"] \
			and not awaiting_shift
	for item in evidence_nodes:
		item.set_enabled(inspecting)
	for index in range(evidence_nodes.size()):
		var spec: Dictionary = EVIDENCE[index]
		var selected := _selected_caption(state, spec.id)
		evidence_nodes[index].set_title("%s\n[%s]" % [spec.name, selected])
	console.set_enabled(inspecting or stage == "integration_ready")
	var flags: Array = state.get("conversation_flags", [])
	shift_clock.set_enabled(awaiting_shift
			and ("first_silence_named" in flags
			or "first_silence_misread" in flags))
	if stage == "unseen":
		tracker.show_objective("REALTY MAINTENANCE",
				"Check the lobby work-order terminal.")
	elif awaiting_shift:
		tracker.show_objective("2A — TEMPORARILY STABLE",
				("Speak with Mina. The underlying problem has not been resolved."
				if not shift_clock.enabled else
				"Clock out in the lobby. Return for a second visit."))
	elif stage in ["active", "reopened", "recognized", "resistant"]:
		tracker.show_objective("2A — CAPTION CRISIS",
				"Assign strictly factual captions (%d/%d), then run the calibrator.%s"
				% [inspected, EVIDENCE.size(),
				"\n" + _feedback if _feedback != "" else ""])
	elif stage == "stabilized":
		tracker.show_objective("2A — REAL TALK",
				"Discuss assumptions and allow one meaningful silence.")
	elif stage == "integration_ready":
		tracker.show_objective("2A — INTEGRATION",
				"Use the calibrator once more. Leave silence uncaptained.")
	elif stage == "resolved":
		tracker.show_objective("CASE CLOSED — MINA VALE",
				"Silence does not require annotation.")
