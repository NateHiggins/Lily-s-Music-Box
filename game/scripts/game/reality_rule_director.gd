extends Node
## Converts case lifecycle state into a small, composable vocabulary of
## physical rules. Consumers ask this autoload for a case's current effect
## rather than independently interpreting narrative stages.

signal rule_changed(case_id: String, effect: Dictionary)

const RULES_PATH := "res://data/reality_rules.json"
const LIVE_STAGES := [
	"active", "reopened", "recognized", "resistant", "integration_ready"
]

var definitions: Dictionary = {}
var effects: Dictionary = {}


func _ready() -> void:
	var file := FileAccess.open(RULES_PATH, FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			definitions = parsed
	RealityCases.case_changed.connect(_on_case_changed)
	for case_id in definitions:
		_refresh(case_id, RealityState.case_state(case_id))


func effect_for(case_id: String) -> Dictionary:
	return effects.get(case_id, _inactive_effect(case_id))


func prop_verbs_for(case_id: String) -> Array:
	return effect_for(case_id).get("prop_verbs", [])


func local_gravity(case_id: String) -> Vector3:
	var effect := effect_for(case_id)
	if not effect.get("active", false) or "gravity" not in effect.rule_types:
		return Vector3.DOWN
	var raw: Array = effect.get("gravity_direction", [0, -1, 0])
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2])).normalized()


func _on_case_changed(case_id: String, state: Dictionary) -> void:
	if definitions.has(case_id):
		_refresh(case_id, state)


func _refresh(case_id: String, state: Dictionary) -> void:
	var definition: Dictionary = definitions.get(case_id, {})
	var stage: String = state.get("stage", "unseen")
	var active := stage in LIVE_STAGES
	var intensity := float(state.get("manifestation_intensity", 0.0)) \
			if active else 0.0
	var recurrence := int(state.get("recurrence_count", 0))
	var effect := definition.duplicate(true)
	effect.case_id = case_id
	effect.stage = stage
	effect.active = active
	effect.intensity = clampf(intensity, 0.0, 1.0)
	effect.recurrence = recurrence
	effect.agitation = effect.intensity * (1.0 + recurrence * 0.35)
	effects[case_id] = effect
	rule_changed.emit(case_id, effect.duplicate(true))


func _inactive_effect(case_id: String) -> Dictionary:
	return {
		"case_id": case_id, "stage": "unseen", "active": false,
		"intensity": 0.0, "recurrence": 0, "agitation": 0.0,
		"rule_types": [], "prop_verbs": []
	}
