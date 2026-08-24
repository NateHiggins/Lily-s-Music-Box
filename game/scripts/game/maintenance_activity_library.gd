class_name MaintenanceActivityLibrary
extends RefCounted
## Strict data boundary for the short, physical maintenance interactions.
##
## This book describes presentation and hand-work only. It deliberately has
## no job stages, case ids, resident ids or Dream-owner state: those facts
## remain with WorkOrders, RealityCases and the shared Dream owners.

const DEFAULT_PATH := "res://data/maintenance_activities.json"
const SCHEMA_VERSION := 2
const VERBS: Array[String] = ["turn", "align", "hold_release"]
const TRANSFERABLE_VERBS: Array[String] = [
	"pressure", "continuity", "timing", "regulation", "contact", "flow",
]

var activities: Dictionary = {}
var errors: Array[String] = []


static func load_default() -> MaintenanceActivityLibrary:
	return load_from(DEFAULT_PATH)


static func load_from(path: String) -> MaintenanceActivityLibrary:
	var library := MaintenanceActivityLibrary.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		library.errors.append("maintenance activity file missing: %s" % path)
		return library
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		library.errors.append("maintenance activity root is not a dictionary")
		return library
	library._validate(parsed)
	for error in library.errors:
		push_warning("maintenance_activities.json: %s" % error)
	return library


func is_valid() -> bool:
	return errors.is_empty()


func has_activity(activity_id: String) -> bool:
	return activities.has(activity_id)


func activity(activity_id: String) -> Dictionary:
	return activities.get(activity_id, {}).duplicate(true)


func activity_ids() -> Array[String]:
	var ids: Array[String] = []
	for activity_id in activities:
		ids.append(str(activity_id))
	ids.sort()
	return ids


func _validate(parsed: Dictionary) -> void:
	if int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("schema_version must be %d" % SCHEMA_VERSION)
		return
	var authored: Variant = parsed.get("activities")
	if authored is not Dictionary or (authored as Dictionary).is_empty():
		errors.append("activities must be a non-empty dictionary")
		return
	for activity_id in authored:
		var record: Variant = authored[activity_id]
		if str(activity_id).is_empty():
			errors.append("empty activity id")
		elif record is not Dictionary:
			errors.append("%s: activity is not a dictionary" % activity_id)
		else:
			_validate_activity(str(activity_id), record)
	if not errors.is_empty():
		return
	for activity_id in authored:
		activities[str(activity_id)] = (authored[activity_id] \
				as Dictionary).duplicate(true)


func _validate_activity(activity_id: String, record: Dictionary) -> void:
	for field in ["title", "apparatus", "location_lane", "historical_source"]:
		if str(record.get(field, "")).strip_edges().is_empty():
			errors.append("%s: %s must be a non-empty string" % [activity_id, field])
	var transferable_verb := str(record.get("transferable_verb", ""))
	if transferable_verb not in TRANSFERABLE_VERBS:
		errors.append("%s: transferable_verb must be one of %s"
				% [activity_id, ", ".join(TRANSFERABLE_VERBS)])
	var story: Variant = record.get("story")
	if story is not Dictionary:
		errors.append("%s: story must be a dictionary" % activity_id)
	else:
		for layer in ["material", "human", "orison"]:
			if str((story as Dictionary).get(layer, "")).strip_edges().is_empty():
				errors.append("%s: story.%s must be non-empty" % [activity_id, layer])
	var completion: Variant = record.get("completion")
	if completion is not Dictionary:
		errors.append("%s: completion must be a dictionary" % activity_id)
	else:
		if str((completion as Dictionary).get("note", "")).strip_edges().is_empty():
			errors.append("%s: completion.note must be non-empty" % activity_id)
		if (completion as Dictionary).get("mechanism_patch") is not Dictionary:
			errors.append("%s: completion.mechanism_patch must be a dictionary"
					% activity_id)
	var steps: Variant = record.get("steps")
	if steps is not Array or (steps as Array).size() < 3:
		errors.append("%s: steps must contain at least three micro-verbs" % activity_id)
		return
	var seen := {}
	for value in steps:
		if value is not Dictionary:
			errors.append("%s: every step must be a dictionary" % activity_id)
			continue
		var step := value as Dictionary
		var step_id := str(step.get("id", ""))
		if step_id.is_empty() or seen.has(step_id):
			errors.append("%s: step ids must be non-empty and unique" % activity_id)
		seen[step_id] = true
		var verb := str(step.get("verb", ""))
		if verb not in VERBS:
			errors.append("%s.%s: unknown verb '%s'" % [activity_id, step_id, verb])
		for field in ["cue", "confirmation"]:
			if str(step.get(field, "")).strip_edges().is_empty():
				errors.append("%s.%s: %s must be non-empty"
						% [activity_id, step_id, field])
		var target := float(step.get("target", -1.0))
		var tolerance := float(step.get("tolerance", 0.0))
		var expected_seconds := float(step.get("expected_seconds", 0.0))
		if target < 0.0 or target > 1.0:
			errors.append("%s.%s: target must be within 0..1" % [activity_id, step_id])
		if tolerance <= 0.0 or tolerance > 0.5:
			errors.append("%s.%s: tolerance must be within 0..0.5"
					% [activity_id, step_id])
		if expected_seconds < 3.0 or expected_seconds > 12.0:
			errors.append("%s.%s: expected_seconds must be within 3..12"
					% [activity_id, step_id])
		var hold_min := float(step.get("hold_min_seconds", 0.0))
		if verb == "hold_release" and (hold_min <= 0.0 or hold_min > 12.0):
			errors.append("%s.%s: hold/release needs a 0..12 second hold"
					% [activity_id, step_id])
