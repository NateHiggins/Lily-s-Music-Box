class_name CorruptionLineageRegistry
extends RefCounted
## Element-indexed anomaly binding. Era jurisdiction and resident wound remain
## independent columns; there is intentionally no combined accessor.

const PATH := "res://data/corruption_lineages.json"
var _lineages: Dictionary = {}


func load_registry() -> bool:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary or parsed.get("lineages") is not Dictionary:
		return false
	for key in parsed.lineages:
		var row = parsed.lineages[key]
		if row is not Dictionary:
			return false
		var owner := str(row.get("ordinary_system", ""))
		if owner.is_empty() or not ResourceLoader.exists(owner):
			push_error("corruption lineage has no ordinary system: %s" % key)
			return false
	_lineages = parsed.lineages.duplicate(true)
	return true


func has_space(space_id: String) -> bool:
	return _lineages.has(space_id)


func ordinary_system(space_id: String) -> String:
	return str((_lineages.get(space_id, {}) as Dictionary).get("ordinary_system", ""))


func era_influence(space_id: String) -> String:
	return str((_lineages.get(space_id, {}) as Dictionary).get("era_influence", ""))


func resident_wound(space_id: String) -> String:
	return str((_lineages.get(space_id, {}) as Dictionary).get("resident_wound", ""))
