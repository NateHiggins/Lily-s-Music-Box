class_name DreamIncarnationProfile
extends RefCounted
## INC-V1: the presentation-only profile seam. This class validates data and
## reduces it to one immutable bundle. It owns no resources, nodes, topology,
## gameplay or persistence.

const Lifecycle := preload("res://scripts/dream/dream_organelle_lifecycle.gd")

const IDS := ["mina", "peter", "juno", "mae", "cal", "omar"]
const PROFILE_IDS := {
	"mina": "mina_release_print",
	"peter": "peter_release_print",
	"juno": "juno_release_print",
	"mae": "mae_release_print",
	"cal": "cal_release_print",
	"omar": "omar_release_print",
}
const CASE_IDS := {
	"mina": "mina_caption_crisis",
	"peter": "peter_form_corridor",
	"juno": "juno_feedback_tetris",
	"mae": "mae_contradictory_antiques",
	"cal": "cal_memory_radio",
	"omar": "omar_unrepairable",
}
const FAMILIES := ["buttons", "tessellates", "anemones", "ribbonettes", "loupe"]
const SIGNATURES := ["blank_mercy", "decision_route", "standing_wave",
		"double_reflection", "completed_phrase", "honest_seam"]
## All six downstream presentation profiles are now authored. This empty gate
## does not manufacture or enable any waking case.
const PRODUCTION_GATED: Array[String] = []


static func default_bundle() -> Dictionary:
	var fauna: Array[Dictionary] = []
	for family in FAMILIES:
		fauna.append({"family": family, "pattern": 0.0, "jewel_token": 0.0,
				"substance_slot": 0.0, "response": 1.0})
	return {
		"incarnation_id": "",
		"incarnation_index": 0,
		"production_enabled": false,
		"palette": Vector4(0.0, 0.0, 0.0, 0.0),
		"pattern": Vector4(0.0, 1.0, 1.0, 1.0),
		"irradiance": Vector4(1.0, 1.0, 1.0, 1.0),
		"motion": Vector4(0.0, 0.0, 0.0, 0.0),
		"signature_id": 0,
		"signature": Vector2(1.0, 0.0),
		"substance_keys": PackedStringArray(),
		"reflected_world_key": "",
		"fauna": fauna,
	}


## Missing presentation is the backwards-compatible current look. A present
## but malformed block is rejected; silently borrowing another case's look
## would make presentation an alternate source of case identity.
static func resolve(raw: Variant, profile_id: String, case_id: String) -> Dictionary:
	if raw == null:
		return {"ok": true, "bundle": default_bundle(), "errors": []}
	var errors: Array[String] = []
	if raw is not Dictionary:
		return {"ok": false, "bundle": {},
				"errors": ["presentation must be a dictionary"]}
	var data := raw as Dictionary
	var incarnation_id := str(data.get("incarnation_id", ""))
	if incarnation_id not in IDS:
		errors.append("incarnation_id must be one of %s" % str(IDS))
	var index := IDS.find(incarnation_id) + 1
	if index > 0:
		if profile_id != str(PROFILE_IDS[incarnation_id]):
			errors.append("%s cannot bind profile %s" % [incarnation_id, profile_id])
		if case_id != str(CASE_IDS[incarnation_id]):
			errors.append("%s cannot bind case %s" % [incarnation_id, case_id])
	var enabled_value: Variant = data.get("production_enabled", null)
	if enabled_value is not bool:
		errors.append("production_enabled must be boolean")
	var enabled := enabled_value as bool if enabled_value is bool else false
	if enabled and incarnation_id in PRODUCTION_GATED:
		errors.append("%s remains production gated" % incarnation_id)

	var palette_data := _number_array(data, "palette", 4, errors)
	var pattern_data := _number_array(data, "pattern", 4, errors)
	var irradiance_data := _number_array(data, "irradiance", 4, errors)
	var motion_data := _number_array(data, "motion", 4, errors)
	_check_ranges(palette_data, [Vector2(0.0, 2.0), Vector2(-0.2, 0.2),
			Vector2(-0.2, 0.2), Vector2(0.0, 1.0)], "palette", errors)
	_check_ranges(pattern_data, [Vector2(0.0, 7.0), Vector2(0.5, 2.0),
			Vector2(0.5, 2.0), Vector2(0.5, 2.0)], "pattern", errors)
	_check_ranges(irradiance_data, [Vector2(0.5, 1.5), Vector2(0.5, 1.5),
			Vector2(0.5, 1.5), Vector2(0.25, 2.0)], "irradiance", errors)
	_check_ranges(motion_data, [Vector2(0.0, 0.99), Vector2(0.0, 1.0),
			Vector2(0.0, 1.0), Vector2(0.0, 1.0)], "motion", errors)

	var signature_data: Variant = data.get("signature", {})
	if signature_data is not Dictionary:
		errors.append("signature must be a dictionary")
		signature_data = {}
	var signature_dict := signature_data as Dictionary
	var signature_name := str(signature_dict.get("id", ""))
	var expected_signature: String = str(SIGNATURES[index - 1]) if index > 0 else ""
	if signature_name != expected_signature:
		errors.append("signature id must be %s" % expected_signature)
	var threshold := _bounded_number(signature_dict, "threshold", 0.0, 1.0,
			"signature", errors)
	var strength := _bounded_number(signature_dict, "strength", 0.0, 1.0,
			"signature", errors)

	var keys_value: Variant = data.get("substance_keys", null)
	var substance_keys := PackedStringArray()
	if keys_value is not Array or (keys_value as Array).size() != 4:
		errors.append("substance_keys must contain exactly four keys")
	else:
		for value in keys_value as Array:
			var key := str(value)
			if not key.begins_with("T_ai_dream_%s_" % incarnation_id):
				errors.append("substance key has wrong namespace: %s" % key)
			substance_keys.append(key)
	var reflected_world_key := str(data.get("reflected_world_key", ""))
	if not reflected_world_key.begins_with(
			"T_ai_dream_%s_reflected_world" % incarnation_id):
		errors.append("reflected_world_key has wrong namespace")

	var fauna := _fauna(data.get("fauna", null), errors)
	if not errors.is_empty():
		return {"ok": false, "bundle": {}, "errors": errors}
	return {"ok": true, "bundle": {
		"incarnation_id": incarnation_id,
		"incarnation_index": index,
		"production_enabled": enabled,
		"palette": _vector4(palette_data),
		"pattern": _vector4(pattern_data),
		"irradiance": _vector4(irradiance_data),
		"motion": _vector4(motion_data),
		"signature_id": index,
		"signature": Vector2(threshold, strength),
		"substance_keys": substance_keys,
		"reflected_world_key": reflected_world_key,
		"fauna": fauna,
	}, "errors": []}


static func fauna_uniform(bundle: Dictionary, family_index: int) -> Vector4:
	var records: Array = bundle.get("fauna", [])
	if family_index < 0 or family_index >= records.size():
		return Vector4(0.0, 0.0, 0.0, 1.0)
	var record: Dictionary = records[family_index]
	return Vector4(float(record.pattern), float(record.jewel_token),
			float(record.substance_slot), float(record.response))


static func apply_to_material(material: ShaderMaterial, bundle: Dictionary,
		family_index := -1) -> void:
	material.set_shader_parameter("incarnation_id",
			float(bundle.get("incarnation_index", 0)))
	material.set_shader_parameter("incarnation_palette",
			bundle.get("palette", Vector4.ZERO))
	material.set_shader_parameter("incarnation_pattern",
			bundle.get("pattern", Vector4(0.0, 1.0, 1.0, 1.0)))
	material.set_shader_parameter("incarnation_irradiance",
			bundle.get("irradiance", Vector4.ONE))
	material.set_shader_parameter("incarnation_motion",
			bundle.get("motion", Vector4.ZERO))
	material.set_shader_parameter("incarnation_signature",
			bundle.get("signature", Vector2(1.0, 0.0)))
	material.set_shader_parameter("incarnation_fauna",
			fauna_uniform(bundle, family_index))


## LC-6E: classify the existing bounded encounter clock. The incarnation does
## not gain a second life or change the run ceiling; it gives the already-lived
## passage eight anatomical names. Large case organs are allowed to hold the
## functional middle of the life for encounter fairness.
static func lifecycle_stage_at(elapsed_s: float, run_cap_s: float) -> int:
	if run_cap_s <= 0.0:
		return Lifecycle.Stage.MATURE
	var phase := clampf(elapsed_s / run_cap_s, 0.0, 1.0)
	if phase < 0.04:
		return Lifecycle.Stage.FOLDED
	if phase < 0.14:
		return Lifecycle.Stage.BUD
	if phase < 0.28:
		return Lifecycle.Stage.JUVENILE
	if phase < 0.62:
		return Lifecycle.Stage.MATURE
	if phase < 0.75:
		return Lifecycle.Stage.EXCHANGE
	if phase < 0.88:
		return Lifecycle.Stage.SENESCENT
	if phase < 0.96:
		return Lifecycle.Stage.SHED
	return Lifecycle.Stage.STAIN


static func lifecycle_stage_name_at(elapsed_s: float, run_cap_s: float) -> String:
	return Lifecycle.stage_name(lifecycle_stage_at(elapsed_s, run_cap_s))


static func _number_array(data: Dictionary, key: String, size: int,
		errors: Array[String]) -> Array[float]:
	var value: Variant = data.get(key, null)
	var result: Array[float] = []
	if value is not Array or (value as Array).size() != size:
		errors.append("%s must contain %d numbers" % [key, size])
		return result
	for item in value as Array:
		if item is not float and item is not int:
			errors.append("%s contains a non-number" % key)
			return []
		result.append(float(item))
	return result


static func _check_ranges(values: Array[float], ranges: Array[Vector2],
		label: String, errors: Array[String]) -> void:
	if values.size() != ranges.size():
		return
	for i in values.size():
		if values[i] < ranges[i].x or values[i] > ranges[i].y:
			errors.append("%s[%d] is outside %s" % [label, i, ranges[i]])


static func _bounded_number(data: Dictionary, key: String, low: float,
		high: float, label: String, errors: Array[String]) -> float:
	var value: Variant = data.get(key, null)
	if value is not float and value is not int:
		errors.append("%s.%s must be numeric" % [label, key])
		return low
	var number := float(value)
	if number < low or number > high:
		errors.append("%s.%s is outside %.2f..%.2f" % [label, key, low, high])
	return number


static func _fauna(value: Variant, errors: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is not Array or (value as Array).size() != FAMILIES.size():
		errors.append("fauna must contain the five ordered families")
		return result
	for i in FAMILIES.size():
		var raw: Variant = (value as Array)[i]
		if raw is not Dictionary:
			errors.append("fauna[%d] must be a dictionary" % i)
			continue
		var record := raw as Dictionary
		if str(record.get("family", "")) != FAMILIES[i]:
			errors.append("fauna[%d] must be %s" % [i, FAMILIES[i]])
		var pattern := _bounded_number(record, "pattern", 0.0, 7.0,
				"fauna[%d]" % i, errors)
		var jewel := _bounded_number(record, "jewel_token", 0.0, 2.0,
				"fauna[%d]" % i, errors)
		var slot := _bounded_number(record, "substance_slot", 0.0, 3.0,
				"fauna[%d]" % i, errors)
		var response := _bounded_number(record, "response", 0.5, 1.5,
				"fauna[%d]" % i, errors)
		result.append({"family": FAMILIES[i], "pattern": pattern,
				"jewel_token": jewel, "substance_slot": slot,
				"response": response})
	return result


static func _vector4(values: Array[float]) -> Vector4:
	return Vector4(values[0], values[1], values[2], values[3])
