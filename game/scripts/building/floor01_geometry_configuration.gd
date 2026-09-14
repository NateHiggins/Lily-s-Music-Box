class_name Floor01GeometryConfiguration
extends RefCounted
## Session-only choice between the production owner-first F01 cells and the
## retained byte-identical rollback monolith. This is geometry composition,
## never gameplay or save authority.

const OWNER_FIRST_CELLS := "owner_first_cells"
const LEGACY_MONOLITH := "legacy_monolith"
const DEFAULT_MODE := OWNER_FIRST_CELLS
const VALID_MODES := [OWNER_FIRST_CELLS, LEGACY_MONOLITH]

static var _session_override := ""


static func selected_mode() -> String:
	return _session_override if not _session_override.is_empty() else DEFAULT_MODE


## Tests and bounded diagnostic sessions inject before BuildingRoot enters the
## tree. Refuse invalid values instead of silently changing production mode.
static func set_for_tests(mode: String) -> bool:
	var normalized := mode.strip_edges().to_lower()
	if normalized not in VALID_MODES:
		return false
	_session_override = normalized
	return true


static func reset_for_tests() -> void:
	_session_override = ""


static func is_valid_mode(mode: String) -> bool:
	return mode in VALID_MODES


static func session_receipt() -> Dictionary:
	return {
		"mode": selected_mode(),
		"default_mode": DEFAULT_MODE,
		"override_active": not _session_override.is_empty(),
		"persistent": false,
		"save_authority": false,
	}
