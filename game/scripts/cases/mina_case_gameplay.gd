class_name MinaCaseGameplay
extends Node3D
## Mina's case-specific half of the golden shift. WorkOrders owns the one
## practical job; this owner translates its completed Vantry repair into the
## first temporary stabilization, then keeps Mina's existing recurrence,
## earned conversation and integration mechanics.

const CASE_ID := "mina_caption_crisis"
const JOB_ID := "vantry_chirp_2a"
const DIALOGUE_TREE_PATH := "res://data/case01_dialogue.json"
const VOICE_DIR := "res://assets/audio/voice/"
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
const CASE_OBJECT_COPY := {
	"caption_cards": {
		"title": "CAPTION INDEX CARDS",
		"body": "A 1912 VISIBLE INDEX OVERLAPPED CARDS WHILE LEAVING EACH PROJECTING EDGE READY TO READ STOP",
		"source_ids": ["R053"],
	},
	"style_guide": {
		"title": "PERSONAL STYLE GUIDE",
		"body": "A 1911 TUBULAR BINDING JOINED SHEETS TO COVERS WHILE LETTING THE BOOK OPEN SUBSTANTIALLY FLAT STOP",
		"source_ids": ["R054"],
	},
	"redaction_pencil": {
		"title": "MAGAZINE LEAD PENCIL",
		"body": "A 1915 LEAD PENCIL STORED SPARE LEADS IN ITS BODY AND FED THE POINT ALONG ITS CENTRE LINE STOP",
		"source_ids": ["R055"],
	},
	"calibrator": {
		"title": "CAPTION CALIBRATOR",
		"body": "CARBON TRANSMITTER PRESSURE CHANGES LINE RESISTANCE WHILE LAMPS AND ANNUNCIATORS REPORT A SEPARATE SIGNAL STOP",
		"source_ids": ["R023", "R034"],
	},
	"time_clock": {
		"title": "IN AND OUT CLOCK",
		"body": "A 1928 RECORDER TOOK ONE EMPLOYEE CARD AND MOVED EACH HANDLE-STAMPED ENTRY OR EXIT TO ITS NEXT POSITION STOP",
		"source_ids": ["R056"],
	},
	"letter": {
		"title": "FOLDED LETTER SHEET",
		"body": "A 1902 LETTER SHEET COULD BE WRITTEN FIRST THEN FOLDED INTO ITS OWN ENVELOPE FORM STOP",
		"source_ids": ["R057"],
	},
}

var tracker: ObjectiveTracker
var work_orders: WorkOrders
var dialogue_tree: Dictionary = {}
var letter: CaseInteractable
var console: CaseInteractable
var shift_clock: CaseInteractable
var dialogue: CaseDialoguePanel
var evidence_nodes: Array[CaseInteractable] = []
var _choice_indices: Dictionary = {}
var _feedback := ""
var _visit_overlay: ColorRect
var _visit_label: Label
var _voice: AudioStreamPlayer3D


func setup(objective_tracker: ObjectiveTracker,
		order_spine: WorkOrders = null) -> void:
	tracker = objective_tracker
	work_orders = order_spine
	if work_orders != null:
		work_orders.job_stage_changed.connect(_on_job_stage_changed)


func _ready() -> void:
	_build_apartment_targets()
	_build_dialogue()
	_build_visit_boundary()
	_build_letter()
	RealityCases.case_changed.connect(_on_case_changed)
	RealityCases.resident_interaction_requested.connect(
			_on_resident_interaction)
	RealityState.state_changed.connect(_on_reality_state_changed)
	_reconcile_physical_repair()
	_refresh()


func _build_apartment_targets() -> void:
	for spec in EVIDENCE:
		var item := CaseInteractable.new()
		var evidence_id: String = spec.id
		item.setup(spec.name, "Change caption on " + spec.name,
				func(): return _inspect(evidence_id),
				Color(0.32, 0.27, 0.20), Vector3(0.34, 0.16, 0.24),
				{"caption_cards": "cards", "style_guide": "book",
				"redaction_pencil": "pencil"}.get(evidence_id, "cards"))
		item.position = GameBoot.b2g(spec.at)
		add_child(item)
		evidence_nodes.append(item)
	console = CaseInteractable.new()
	console.setup("CAPTION CALIBRATOR", "Run caption calibration",
			_use_calibrator, Color(0.16, 0.31, 0.36),
			Vector3(0.48, 0.42, 0.26), "calibrator")
	console.position = GameBoot.b2g([-9.35, -2.05, 4.20])
	add_child(console)


func _build_dialogue() -> void:
	dialogue_tree = JSON.parse_string(
			FileAccess.get_file_as_string(DIALOGUE_TREE_PATH))
	dialogue = CaseDialoguePanel.new()
	add_child(dialogue)
	dialogue.node_shown.connect(_on_dialogue_node)
	dialogue.tree_ended.connect(func():
		var actor := _mina_actor()
		if actor:
			actor.play_case_role("idle"))
	# Voice takes play from Mina's living room; subtitles are the panel
	# itself, sourced from the same JSON, so text and voice cannot drift.
	_voice = AudioStreamPlayer3D.new()
	_voice.position = GameBoot.b2g([-9.6, -3.35, 4.7])
	_voice.unit_size = 6.0
	add_child(_voice)


func _on_dialogue_node(node_id: String) -> void:
	_play_voice_line(node_id)
	# Deeper layers borrow her body: the tree names the animation role, the
	# actor plays it if the clip has shipped from the prompt sheet.
	var node: Dictionary = dialogue_tree.get("nodes", {}).get(node_id, {})
	if node.has("role"):
		var actor := _mina_actor()
		if actor:
			actor.play_case_role(str(node.role))


func _mina_actor() -> AnimatedResident:
	for actor in get_tree().get_nodes_in_group("animated_residents"):
		if actor.resident_id == "mina_vale":
			return actor
	return null


## Node ids are take ids: mina_c01_<node>.ogg. Missing takes are silent —
## the tree ships before the voice does.
func _play_voice_line(node_id: String) -> void:
	var prefix := str(dialogue_tree.get("meta", {}).get(
			"voice_prefix", "mina_c01_"))
	var path := "%s%s%s.ogg" % [VOICE_DIR, prefix, node_id]
	if not ResourceLoader.exists(path):
		_voice.stop()
		return
	_voice.stream = load(path)
	_voice.play()


func _build_visit_boundary() -> void:
	shift_clock = CaseInteractable.new()
	shift_clock.setup("TIME CLOCK", "Clock out and return for visit two",
			_advance_visit, Color(0.18, 0.21, 0.19),
			Vector3(0.38, 0.54, 0.16), "time_clock")
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


## Mail as a system, first letter. When the case recurs, Mina escalates to
## paper: PROVISIONAL TESTIMONY, slid under the player's own door in the 4B
## vestibule while they were out clocking back in. It stays after
## resolution — the drafts are retained; only what they do with the blank
## changes.
func _build_letter() -> void:
	letter = CaseInteractable.new()
	letter.setup("PROVISIONAL TESTIMONY",
			"Read the letter slid under your door", _read_letter,
			Color(0.86, 0.84, 0.78), Vector3(0.24, 0.012, 0.32),
			"letter")
	letter.position = GameBoot.b2g([-5.95, 3.90, 9.6])
	letter.rotation.y = 0.22
	add_child(letter)
	letter.set_enabled(false)


func _read_letter() -> Dictionary:
	var state := RealityState.case_state(CASE_ID)
	var text: String
	if bool(state.get("resolved", false)):
		text = "PROVISIONAL TESTIMONY — DRAFT 5. (DRAFTS 1–4 SHREDDED.)\n" \
				+ "RE: Work order 002-A, closed.\n" \
				+ "The captions are quiet. That is a fact, and it needs no witness.\n" \
				+ "The last four seconds of this page are blank. — M.V.\n" \
				+ "(They are. Nothing is written beside them.)"
	else:
		text = "PROVISIONAL TESTIMONY — DRAFT 4. (DRAFTS 1–3 RETAINED.)\n" \
				+ "RE: Work order 002-A. The captions returned at 11:41 PM. [FACT]\n" \
				+ "You will come back. [ASSUMPTION — RETAINED ANYWAY.]\n" \
				+ "The last four seconds of this letter are blank. I have\n" \
				+ "annotated them in the margin. Draft five will not. — M.V."
	dialogue.present("A LETTER, SLID UNDER THE DOOR", text,
			[{"text": "[Fold it back up.]", "action": Callable()}])
	return _case_object_card("letter", "DRAFT %d OPEN / CASE TEXT PRESENTED" %
			(5 if bool(state.get("resolved", false)) else 4))


func _on_job_stage_changed(job_id: String, _from: String, to_stage: String,
		_job: Dictionary) -> void:
	if job_id == JOB_ID and to_stage == "repaired":
		_reconcile_physical_repair()


## The carbon-capsule repair is the first practical intervention in Mina's
## case. This is case translation, not a second lifecycle: WorkOrders remains
## the only owner of the repair and RealityCases remains the only owner of
## stabilization. A restored repaired job is reconciled idempotently.
func _reconcile_physical_repair() -> void:
	if work_orders == null \
			or work_orders.job_stage(JOB_ID) not in ["repaired", "closed"]:
		return
	var state := RealityState.case_state(CASE_ID)
	if state.is_empty():
		state = RealityState.ensure_case(CASE_ID, "mina_vale")
	if bool(state.get("resolved", false)) or int(state.get("repair_count", 0)) > 0:
		return
	if str(state.get("stage", "unseen")) == "unseen":
		RealityCases.activate_case(CASE_ID)
	RealityCases.stabilize_case(CASE_ID)


func _inspect(evidence_id: String) -> Dictionary:
	var state := RealityState.case_state(CASE_ID)
	if state.is_empty():
		return _case_object_card(evidence_id, "CASE INACTIVE / NO CHANGE")
	var round := int(state.get("recurrence_count", 0))
	var spec := _evidence_spec(evidence_id)
	if spec.is_empty():
		return {}
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
	return _case_object_card(evidence_id,
			"CAPTION %s / CASE OWNER COMMITTED" % selected)


func _use_calibrator() -> Dictionary:
	var state := RealityState.case_state(CASE_ID)
	if state.is_empty():
		return _case_object_card("calibrator", "LINE IDLE / NO CASE CHANGE")
	if state.stage == "integration_ready":
		RealityCases.resolve_case(CASE_ID)
		return _case_object_card("calibrator",
				"CALIBRATION ACCEPTED / CASE OWNER RESOLVED")
	if state.stage not in ["active", "reopened", "recognized", "resistant"]:
		return _case_object_card("calibrator",
				"CONTROL GUARDED / CURRENT STAGE REFUSED")
	if _inspection_count(state) < EVIDENCE.size():
		_feedback = "Calibration rejected: some captions claim more than is observable."
		_refresh()
		return _case_object_card("calibrator",
				"CALIBRATION REJECTED / %d OF %d FACTUAL" % [
						_inspection_count(state), EVIDENCE.size()])
	_feedback = ""
	RealityCases.stabilize_case(CASE_ID)
	return _case_object_card("calibrator",
			"CALIBRATION ACCEPTED / CASE OWNER STABILIZED")


func _on_resident_interaction(case_id: String, resident_id: String) -> void:
	if case_id != CASE_ID or resident_id != "mina_vale":
		return
	var state := RealityState.case_state(CASE_ID)
	dialogue.run_tree(dialogue_tree, _entry_for(state), _apply_flag,
			_apply_dialogue_action)


func _entry_for(state: Dictionary) -> String:
	var entries: Dictionary = dialogue_tree.get("entries", {})
	var repairs := int(state.get("repair_count", 0))
	var key := "fallback"
	if bool(state.get("resolved", false)):
		key = "resolved"
	elif state.stage == "integration_ready":
		key = "integration"
	elif repairs >= 2:
		key = "real_talk"
	elif repairs == 1 and bool(state.get("recurrence_pending", false)):
		key = "first_stable"
	return str(entries.get(key, entries.get("fallback", "")))


func _apply_flag(flag: String, trust_delta: int) -> void:
	RealityCases.record_conversation(CASE_ID, flag, trust_delta)


func _apply_dialogue_action(action: String) -> void:
	if action == "quiet_beat":
		_leave_quiet_beat()


func _leave_quiet_beat() -> void:
	_feedback = "The apartment waits without supplying an answer."
	_refresh()


func _advance_visit() -> Dictionary:
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
	return _case_object_card("time_clock",
			"CARD STAMPED / VISIT BOUNDARY ACCEPTED")


func _case_object_card(object_id: String, condition: String) -> Dictionary:
	var copy: Dictionary = CASE_OBJECT_COPY.get(object_id, {})
	if copy.is_empty() or condition.is_empty():
		return {}
	var sources: Array = copy.get("source_ids", [])
	return {
		"title": str(copy.get("title", "")),
		"body": str(copy.get("body", "")),
		"condition": condition,
		"stamp": "SERVICE NOTE",
		"card_id": "case_object",
		"source_ids": sources.duplicate(),
	}


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


func _on_reality_state_changed() -> void:
	_reconcile_physical_repair()
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
	var inspecting := stage in ["active", "reopened", "recognized", "resistant"] \
			and not awaiting_shift
	for item in evidence_nodes:
		item.set_enabled(inspecting)
	for index in range(evidence_nodes.size()):
		var spec: Dictionary = EVIDENCE[index]
		var selected := _selected_caption(state, spec.id)
		evidence_nodes[index].set_title("%s\n[%s]" % [spec.name, selected])
	console.set_enabled(inspecting or stage == "integration_ready")
	if letter:
		letter.set_enabled(int(state.get("recurrence_count", 0)) >= 1)
	var flags: Array = state.get("conversation_flags", [])
	shift_clock.set_enabled(awaiting_shift
			and ("first_silence_named" in flags
			or "first_silence_misread" in flags))
	if stage == "unseen":
		tracker.show_objective("REALTY MAINTENANCE",
				"Listen for a fault or speak with the resident who reported it.")
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
