extends RefCounted
## Runtime projection of the authored street report. Build hashes stay in art/data.
const PATH := "res://data/orison_v2/exterior/street_frame.json"

static func valid_source_header(source: Variant) -> bool:
	if source is not Dictionary or source.get("schema") != "orison.v2.street-frame.v1" \
			or source.get("frame") != "ORISON_FRONT_DOOR_THRESHOLD":
		return false
	for key: String in ["source_threshold_z", "arcade_building_line_z"]:
		var value: Variant = source.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	return true

static func load_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return source if valid_source_header(source) else {}

static func load_default() -> Dictionary:
	return load_from(PATH)
