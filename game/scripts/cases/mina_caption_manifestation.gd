class_name MinaCaptionManifestation
extends Node3D
## First case scaffold: visible captions prove that stabilization and
## recurrence are separate persistent states before the full minigame lands.

const CASE_ID := "mina_caption_crisis"
const CAPTIONS := [
	{"pos": [-11.8, -4.8, 4.45], "noun": "SOFA",
		"claim": "MINA IS WAITING CORRECTLY"},
	{"pos": [-9.0, -2.2, 4.25], "noun": "DESK",
		"claim": "THE PLAYER IS DISAPPOINTED"},
	{"pos": [-6.3, -5.1, 4.55], "noun": "WINDOW",
		"claim": "THIS SILENCE MEANS FAILURE"},
	{"pos": [-10.1, -5.7, 5.0], "noun": "MINA",
		"claim": "[UNINTELLIGIBLE]"},
]

var _labels: Array[Label3D] = []
var _remote_labels: Dictionary = {}
var _building: Node3D
var _resolved_residue: Label3D


func setup(building: Node3D) -> void:
	_building = building


func _ready() -> void:
	for entry in CAPTIONS:
		var label := Label3D.new()
		label.position = GameBoot.b2g(entry.pos)
		label.font_size = 38
		label.pixel_size = 0.0025
		label.modulate = Color(0.82, 0.96, 0.88)
		label.outline_modulate = Color(0.015, 0.025, 0.025, 0.95)
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		label.no_depth_test = false
		add_child(label)
		_labels.append(label)
	_resolved_residue = Label3D.new()
	_resolved_residue.text = "REFRIGERATOR"
	_resolved_residue.position = AcousticGraphData.node_pos(
			"F02_A_FRIDGE_01") + Vector3.UP * 0.75
	_resolved_residue.font_size = 30
	_resolved_residue.pixel_size = 0.0022
	_resolved_residue.modulate = Color(0.68, 0.86, 0.76, 0.72)
	_resolved_residue.outline_size = 9
	_resolved_residue.outline_modulate = Color(0.01, 0.02, 0.02, 0.95)
	_resolved_residue.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(_resolved_residue)
	RealityCases.case_changed.connect(_on_case_changed)
	AcousticGraphData.reality_event.connect(_on_reality_event)
	_apply_state(RealityState.case_state(CASE_ID))


func _on_case_changed(case_id: String, state: Dictionary) -> void:
	if case_id == CASE_ID:
		_apply_state(state)


func _apply_state(state: Dictionary) -> void:
	var stage: String = state.get("stage", "unseen")
	var recurrence := int(state.get("recurrence_count", 0))
	_resolved_residue.visible = stage == "resolved"
	for index in range(_labels.size()):
		var label := _labels[index]
		label.visible = stage not in ["unseen", "stabilized", "resolved"]
		if not label.visible:
			continue
		if recurrence == 0:
			label.text = CAPTIONS[index].noun
			label.modulate = Color(0.82, 0.96, 0.88)
		else:
			label.text = CAPTIONS[index].claim
			label.modulate = Color(1.0, 0.62, 0.42)
	if stage in ["unseen", "stabilized", "resolved"]:
		_clear_remote()


func _on_reality_event(case_id: String, node_id: String, strength: float,
		recurrence: int) -> void:
	if case_id != CASE_ID or strength < 0.10:
		return
	if _remote_labels.has(node_id) or _remote_labels.size() >= 48:
		return
	# Keep the field readable: all strong arrivals show; weaker distant
	# arrivals select a stable subset rather than filling every pipe joint.
	if strength < 0.24 and abs(hash(node_id)) % 4 != 0:
		return
	var label := Label3D.new()
	label.name = "Caption_" + node_id
	label.global_position = AcousticGraphData.node_pos(node_id) \
			+ Vector3.UP * 0.72
	label.font_size = 30
	label.pixel_size = 0.0022
	label.outline_size = 9
	label.outline_modulate = Color(0.01, 0.02, 0.02, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.no_depth_test = false
	if recurrence == 0:
		label.text = _noun_for(node_id)
		label.modulate = Color(0.72, 0.9, 0.82, clampf(strength + 0.3, 0.4, 1.0))
	else:
		var claims := [
			"THIS ROOM EXPECTED MORE",
			"SOMEONE IS DISAPPOINTED",
			"THE SILENCE IS AN ANSWER",
			"YOU SHOULD EXPLAIN YOURSELF",
		]
		label.text = claims[abs(hash(node_id)) % claims.size()]
		label.modulate = Color(1.0, 0.55, 0.38,
				clampf(strength + 0.35, 0.45, 1.0))
	add_child(label)
	_remote_labels[node_id] = label


func _noun_for(node_id: String) -> String:
	for token in ["RADIATOR", "MONITOR", "LAMP", "SPEAKER", "TOASTER",
			"LIGHT", "BOILER", "FAN", "CLOCK", "KETTLE", "DOOR"]:
		if token in node_id:
			return token
	return "BUILDING"


func _clear_remote() -> void:
	for node_id in _remote_labels:
		var label: Label3D = _remote_labels[node_id]
		if is_instance_valid(label):
			label.queue_free()
	_remote_labels.clear()
