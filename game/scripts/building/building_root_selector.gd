class_name BuildingRootSelector
extends RefCounted
## One non-persistent authority for waking-building scene selection.

const DEFAULT_ID := "v1" # Future cutover and rollback change this value only.
const ENVIRONMENT_KEY := "ORISON_BUILDING_ROOT"
const PATHS := {
	"v1": "res://scenes/building/orison_root.tscn",
	"v2": "res://scenes/building/orison_v2_runtime.tscn",
}
static var _session_id := ""
static var _reported_value := ""

static func selected_id() -> String:
	if not _session_id.is_empty(): return _session_id
	var requested := OS.get_environment(ENVIRONMENT_KEY).strip_edges().to_lower()
	if requested.is_empty():
		_session_id = DEFAULT_ID
	elif PATHS.has(requested):
		_session_id = requested
	else:
		_session_id = DEFAULT_ID
		_report_invalid(requested)
	return _session_id

static func scene_path() -> String:
	return str(PATHS[selected_id()])

static func path_for(identity: String) -> String:
	var key := identity.strip_edges().to_lower()
	if PATHS.has(key): return str(PATHS[key])
	_report_invalid(identity)
	return str(PATHS[DEFAULT_ID])

static func reset_for_tests(explicit_id := "") -> void:
	_session_id = explicit_id if PATHS.has(explicit_id) else ""
	_reported_value = ""

static func _report_invalid(value: String) -> void:
	if value == _reported_value: return
	_reported_value = value
	push_warning("invalid %s='%s'; using committed %s default" % [
		ENVIRONMENT_KEY, value, DEFAULT_ID])
