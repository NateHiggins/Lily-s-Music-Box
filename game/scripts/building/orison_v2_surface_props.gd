extends "res://scripts/building/orison_v2_domestic_furniture.gd"
## Small fixed objects belong to their supporting furniture/fixture. They add
## no collision or interaction owner and retire with that support.
const SURFACE_PATH := "res://data/orison_v2/domestic_surface_props.json"
const KINDS := ["mug", "dishrack", "papers", "headphones", "partstray", "jarrow", "bookpile", "cablecoil"]

func mount(adapter: Variant) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SURFACE_PATH))
	if not validate(source, adapter): return false
	for record: Dictionary in source.props:
		var support := adapter.resolve(record.support) as Node3D
		var prop := Node3D.new()
		prop.name = record.id
		prop.position = _vector(record.position)
		prop.rotation.y = float(record.yaw)
		prop.set_meta("v2_surface_prop", str(record.kind))
		prop.set_meta("support_id", str(record.support))
		_add_surfaces(prop, record.surfaces)
		support.add_child(prop)
	return true

func validate(source: Variant, adapter: Variant) -> bool:
	errors.clear()
	if source is not Dictionary or source.get("schema_version") != 1 or source.get("props") is not Array:
		errors.append("malformed surface prop source")
		return false
	var seen: Dictionary = {}
	for record: Variant in source.props:
		if record is not Dictionary or record.get("id") is not String or record.id.is_empty() \
				or record.get("kind") not in KINDS or record.get("support") is not String \
				or record.get("unit") not in ["2A", "2B", "3B", "4B"]:
			errors.append("invalid surface prop identity")
			continue
		if seen.has(record.id) or adapter == null:
			errors.append("duplicate surface prop or missing adapter")
			continue
		seen[record.id] = true
		var support := adapter.resolve(record.support) as Node3D
		if support == null or adapter.resolve(record.id) != null:
			errors.append("missing support or occupied identity: " + str(record.id))
		if not _numbers(record.get("position"), 3) or not _numbers([record.get("yaw")], 1):
			errors.append("invalid surface prop placement")
		var bounds: Variant = record.get("bounds")
		if bounds is not Array or bounds.size() != 2 or not _numbers(bounds[0], 3) or not _numbers(bounds[1], 3):
			errors.append("invalid surface prop bounds")
		else:
			for axis in 3:
				if bounds[0][axis] >= bounds[1][axis]: errors.append("inverted surface prop bounds")
		_validate_surfaces(record.get("surfaces"))
	if seen.is_empty(): errors.append("empty surface prop source")
	return errors.is_empty()
