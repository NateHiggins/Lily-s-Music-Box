class_name MaintenanceJobLibrary
extends RefCounted
## The narrow data boundary for data-authored maintenance jobs.
##
## Loads and validates `data/maintenance_jobs.json` once; everything the
## runtime knows about a job's authored shape comes through here. Validation
## is strict on shape and vocabulary so a typo in the data fails loudly at
## load rather than silently downstream. World existence of anchors stays the
## layout's business — this boundary checks ids are well-formed strings, not
## that the building contains them.

const DEFAULT_PATH := "res://data/maintenance_jobs.json"
const SCHEMA_VERSION := 1

## Vocabulary shared with WorkOrders. The stage list is the ruled M1
## lifecycle; the loader owns it so authored stage keys are validated in one
## place and WorkOrders reads it rather than repeating it.
const STAGES: Array[String] = ["issued", "acknowledged", "diagnosed",
		"awaiting_part", "repairable", "repaired", "closed"]
const ORIGINS: Array[String] = ["reported", "discovered"]
const REPAIR_QUALITIES: Array[String] = ["poor", "fair", "good"]

var jobs: Dictionary = {}
var errors: Array[String] = []


static func load_default() -> MaintenanceJobLibrary:
	return load_from(DEFAULT_PATH)


static func load_from(path: String) -> MaintenanceJobLibrary:
	var library := MaintenanceJobLibrary.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		library.errors.append("maintenance jobs file missing: %s" % path)
		return library
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		library.errors.append("maintenance jobs root is not a dictionary")
		return library
	library._validate(parsed)
	for err in library.errors:
		push_warning("maintenance_jobs.json: %s" % err)
	return library


func is_valid() -> bool:
	return errors.is_empty()


func has_job(job_id: String) -> bool:
	return jobs.has(job_id)


func job(job_id: String) -> Dictionary:
	return jobs.get(job_id, {})


func job_ids() -> Array[String]:
	var ids: Array[String] = []
	for job_id in jobs:
		ids.append(str(job_id))
	ids.sort()
	return ids


func requires_part(job_id: String) -> bool:
	return str(job(job_id).get("required_item_id", "")) != ""


func declares_evidence(job_id: String, flag: String) -> bool:
	return flag in job(job_id).get("evidence_flags", [])


func stage_objective(job_id: String, stage: String) -> String:
	return str(job(job_id).get("stage_objectives", {}).get(stage, ""))


func _validate(parsed: Dictionary) -> void:
	if int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("schema_version must be %d" % SCHEMA_VERSION)
		return
	var authored: Variant = parsed.get("jobs")
	if authored is not Dictionary:
		errors.append("jobs must be a dictionary keyed by job id")
		return
	for job_id in authored:
		var record: Variant = authored[job_id]
		if str(job_id).is_empty():
			errors.append("empty job id")
			continue
		if record is not Dictionary:
			errors.append("%s: job record is not a dictionary" % job_id)
			continue
		_validate_job(str(job_id), record)
	if (authored as Dictionary).is_empty():
		errors.append("no jobs authored")
	if not errors.is_empty():
		return
	# Install only a fully valid book: a half-loaded library would let a
	# runtime path depend on which sibling job happened to parse.
	for job_id in authored:
		jobs[str(job_id)] = (authored[job_id] as Dictionary).duplicate(true)


func _validate_job(job_id: String, record: Dictionary) -> void:
	for field in ["title", "summary", "repair_target_id"]:
		if str(record.get(field, "")).is_empty():
			errors.append("%s: %s must be a non-empty string" % [job_id, field])
	for field in ["case_id", "resident_id", "unit", "required_item_id"]:
		if record.get(field) is not String:
			errors.append("%s: %s must be a string" % [job_id, field])
	_validate_origins(job_id, record.get("origins"))
	_validate_string_array(job_id, "anchor_ids", record.get("anchor_ids"))
	_validate_string_array(job_id, "evidence_flags", record.get("evidence_flags"))
	_validate_dream_window(job_id, record.get("dream_window"))
	_validate_stage_objectives(job_id, record.get("stage_objectives"))


func _validate_origins(job_id: String, origins: Variant) -> void:
	if origins is not Dictionary or (origins as Dictionary).is_empty():
		errors.append("%s: origins must name at least one origin" % job_id)
		return
	for origin in origins:
		if str(origin) not in ORIGINS:
			errors.append("%s: unknown origin '%s'" % [job_id, origin])
		elif origins[origin] is not Dictionary \
				or str((origins[origin] as Dictionary).get("source", "")).is_empty():
			errors.append("%s: origin '%s' needs a source" % [job_id, origin])


func _validate_string_array(job_id: String, field: String, value: Variant) -> void:
	if value is not Array:
		errors.append("%s: %s must be an array" % [job_id, field])
		return
	var seen := {}
	for entry in value:
		if entry is not String or str(entry).is_empty():
			errors.append("%s: %s entries must be non-empty strings" % [job_id, field])
		elif seen.has(entry):
			errors.append("%s: %s repeats '%s'" % [job_id, field, entry])
		seen[entry] = true


func _validate_dream_window(job_id: String, window: Variant) -> void:
	if window is not Dictionary:
		errors.append("%s: dream_window must be a dictionary" % job_id)
		return
	if str((window as Dictionary).get("eligible_after_stage", "")) not in STAGES:
		errors.append("%s: dream_window.eligible_after_stage must be a stage" % job_id)
	_validate_string_array(job_id, "dream_window.protected_contexts",
			(window as Dictionary).get("protected_contexts"))


func _validate_stage_objectives(job_id: String, objectives: Variant) -> void:
	if objectives is not Dictionary:
		errors.append("%s: stage_objectives must be a dictionary" % job_id)
		return
	for stage in objectives:
		if str(stage) not in STAGES:
			errors.append("%s: stage_objectives names unknown stage '%s'"
					% [job_id, stage])
	for stage in STAGES:
		if str((objectives as Dictionary).get(stage, "")).is_empty():
			errors.append("%s: stage_objectives missing text for '%s'"
					% [job_id, stage])
