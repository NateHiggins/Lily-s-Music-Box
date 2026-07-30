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
var evidence_nodes: Array[CaseInteractable] = []
var insight_nodes: Array[CaseInteractable] = []
var _choice_indices: Dictionary = {}
var _feedback := ""


func setup(objective_tracker: ObjectiveTracker) -> void:
	tracker = objective_tracker


func _ready() -> void:
	_build_terminal()
	_build_apartment_targets()
	RealityCases.case_changed.connect(_on_case_changed)
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
	_add_insight("FACTS ARE NOT ASSUMPTIONS",
			"Talk honestly about assumptions",
			"assumptions_are_not_facts", [-10.65, -4.8, 4.35])
	_add_insight("SILENCE CAN BE BLANK",
			"Leave silence uncaptained",
			"silence_can_be_blank", [-10.05, -4.8, 4.35])


func _add_insight(title: String, prompt: String, flag: String,
		at: Array) -> void:
	var card := CaseInteractable.new()
	card.setup(title, prompt,
			func(): _record_insight(flag), Color(0.36, 0.23, 0.29),
			Vector3(0.42, 0.025, 0.24))
	card.position = GameBoot.b2g(at)
	add_child(card)
	insight_nodes.append(card)


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
	terminal.set_enabled(stage == "unseen")
	var inspecting := stage in ["active", "reopened", "recognized", "resistant"]
	for item in evidence_nodes:
		item.set_enabled(inspecting)
	for index in range(evidence_nodes.size()):
		var spec: Dictionary = EVIDENCE[index]
		var selected := _selected_caption(state, spec.id)
		evidence_nodes[index].set_title("%s\n[%s]" % [spec.name, selected])
	console.set_enabled(inspecting or stage == "integration_ready")
	var insight_time := repairs >= 2 \
			and stage in ["stabilized", "recognized", "integration_ready"]
	for item in insight_nodes:
		item.set_enabled(insight_time)
	if stage == "unseen":
		tracker.show_objective("REALTY MAINTENANCE",
				"Check the lobby work-order terminal.")
	elif stage in ["active", "reopened", "recognized", "resistant"]:
		tracker.show_objective("2A — CAPTION CRISIS",
				"Assign strictly factual captions (%d/%d), then run the calibrator.%s"
				% [inspected, EVIDENCE.size(),
				"\n" + _feedback if _feedback != "" else ""])
	elif stage == "stabilized" and repairs == 1:
		tracker.show_objective("2A — TEMPORARILY STABLE",
				"Speak with Mina. The underlying problem has not been resolved.")
	elif stage == "stabilized":
		tracker.show_objective("2A — REAL TALK",
				"Discuss assumptions and allow one meaningful silence.")
	elif stage == "integration_ready":
		tracker.show_objective("2A — INTEGRATION",
				"Use the calibrator once more. Leave silence uncaptained.")
	elif stage == "resolved":
		tracker.show_objective("CASE CLOSED — MINA VALE",
				"Silence does not require annotation.")
