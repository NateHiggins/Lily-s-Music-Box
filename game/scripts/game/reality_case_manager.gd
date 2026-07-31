extends Node
## Data-driven case lifecycle. A repair may stabilize a manifestation, but
## only accumulated recognition + resident participation can resolve it.

signal case_changed(case_id: String, state: Dictionary)
signal work_order_opened(case_id: String)
signal work_order_reopened(case_id: String, recurrence: int)
signal resident_interaction_requested(case_id: String, resident_id: String)
signal manifestation_broadcast(case_id: String, origin_node: String,
		intensity: float, recurrence: int)

const DEFINITIONS_PATH := "res://data/reality_cases.json"

var definitions: Dictionary = {}


func _ready() -> void:
	var file := FileAccess.open(DEFINITIONS_PATH, FileAccess.READ)
	if file == null:
		push_warning("reality case definitions missing")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		definitions = parsed
	for case_id in definitions:
		var definition: Dictionary = definitions[case_id]
		RealityState.ensure_case(case_id, definition.resident_id)


func definition(case_id: String) -> Dictionary:
	return definitions.get(case_id, {})


func case_for_resident(resident_id: String) -> String:
	for case_id in definitions:
		if definitions[case_id].resident_id == resident_id:
			return case_id
	return ""


func activate_case(case_id: String) -> bool:
	if not definitions.has(case_id):
		return false
	var state := RealityState.ensure_case(
			case_id, definitions[case_id].resident_id)
	if state.resolved:
		return false
	state.stage = "active"
	state.manifestation_intensity = maxf(
			float(state.manifestation_intensity), 0.35)
	state.recurrence_pending = false
	RealityState.data.current_case_id = case_id
	_commit_case(case_id)
	work_order_opened.emit(case_id)
	broadcast_case(case_id)
	return true


func stabilize_case(case_id: String) -> bool:
	var state := RealityState.case_state(case_id)
	if state.is_empty() or state.resolved:
		return false
	if state.stage not in ["active", "reopened", "recognized", "resistant"]:
		return false
	state.repair_count = int(state.repair_count) + 1
	state.stage = "stabilized"
	state.manifestation_intensity = 0.0
	state.recurrence_pending = true
	RealityState.data.building_stability = clampf(
			float(RealityState.data.building_stability) + 0.025, 0.0, 1.0)
	_commit_case(case_id)
	return true


func reopen_case(case_id: String) -> bool:
	var state := RealityState.case_state(case_id)
	if state.is_empty() or state.resolved or not state.recurrence_pending:
		return false
	state.recurrence_count = int(state.recurrence_count) + 1
	state.stage = "reopened"
	state.recurrence_pending = false
	state.manifestation_intensity = minf(
			1.0, 0.42 + float(state.recurrence_count) * 0.16)
	_commit_case(case_id)
	work_order_reopened.emit(case_id, state.recurrence_count)
	broadcast_case(case_id)
	return true


func record_conversation(case_id: String, flag: String,
		trust_delta := 1) -> bool:
	var state := RealityState.case_state(case_id)
	var def := definition(case_id)
	if state.is_empty() or def.is_empty() or state.resolved:
		return false
	if flag not in state.conversation_flags:
		state.conversation_flags.append(flag)
	state.trust = int(state.trust) + trust_delta
	var required: Array = def.get("resolution_flags", [])
	var all_present := true
	for required_flag in required:
		if required_flag not in state.conversation_flags:
			all_present = false
	if all_present:
		state.stage = "integration_ready"
	elif int(state.repair_count) > 0:
		state.stage = "recognized"
	_commit_case(case_id)
	return true


func resolve_case(case_id: String) -> bool:
	var state := RealityState.case_state(case_id)
	var def := definition(case_id)
	if state.is_empty() or def.is_empty() or state.resolved:
		return false
	if state.stage != "integration_ready":
		return false
	if int(state.repair_count) < int(def.get("repairs_required", 2)):
		return false
	state.stage = "resolved"
	state.resolved = true
	state.recurrence_pending = false
	state.manifestation_intensity = 0.0
	var rule: String = def.get("portal_rule", "")
	if rule != "" and rule not in RealityState.data.portal_rules:
		RealityState.data.portal_rules.append(rule)
	RealityState.data.reality_coherence = clampf(
			float(RealityState.data.reality_coherence) + 0.055, 0.0, 1.0)
	_commit_case(case_id)
	return true


func interact_with_resident(resident_id: String) -> void:
	var case_id := case_for_resident(resident_id)
	if case_id == "":
		return
	var state := RealityState.case_state(case_id)
	if state.stage == "unseen":
		activate_case(case_id)
	# Recurrence belongs to a visit/shift boundary, not to the act of
	# speaking with a resident. Case gameplay decides when time advances.
	resident_interaction_requested.emit(case_id, resident_id)


func broadcast_case(case_id: String) -> void:
	var state := RealityState.case_state(case_id)
	var def := definition(case_id)
	if state.is_empty() or def.is_empty() or state.resolved:
		return
	if state.stage in ["unseen", "stabilized"]:
		return
	var origin := _origin_for(def)
	var intensity := float(state.get("manifestation_intensity", 0.35))
	var recurrence := int(state.get("recurrence_count", 0))
	manifestation_broadcast.emit(case_id, origin, intensity, recurrence)
	AcousticGraphData.propagate_reality(
			origin, case_id, intensity, recurrence)


func _origin_for(def: Dictionary) -> String:
	var explicit: String = def.get("origin_node", "")
	if explicit != "":
		return explicit
	var unit: String = def.get("unit", "")
	if unit.length() < 2:
		return "B1_BOILER_01"
	return "F0%s_%s_RADIATOR_01" % [unit.left(1), unit.substr(1, 1)]


func debug_reset_case(case_id: String) -> void:
	if not definitions.has(case_id):
		return
	var rule: String = definitions[case_id].get("portal_rule", "")
	RealityState.data.cases.erase(case_id)
	RealityState.ensure_case(case_id, definitions[case_id].resident_id)
	RealityState.data.portal_rules.erase(rule)
	if RealityState.data.current_case_id == case_id:
		RealityState.data.current_case_id = ""
	_commit_case(case_id)


func _commit_case(case_id: String) -> void:
	RealityState.commit()
	case_changed.emit(case_id, RealityState.case_state(case_id).duplicate(true))
