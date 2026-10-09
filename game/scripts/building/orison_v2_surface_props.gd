extends "res://scripts/building/orison_v2_domestic_furniture.gd"
## Small fixed objects belong to their supporting furniture/fixture. They add
## no collision or interaction owner and retire with that support.
const SURFACE_PATH := "res://data/orison_v2/domestic_surface_props.json"
const KINDS := ["mug", "dishrack", "papers", "headphones", "partstray", "jarrow", "bookpile", "cablecoil", "bottles", "sitemodel", "kettle", "tin", "board", "plate", "sheets", "volumes", "brasstray", "frame", "clock", "can", "parcel", "flask", "carton", "reelbox", "boxrow", "basket", "spectacles", "pencil", "booklet", "wallet", "foldrule", "case", "gloves", "hammer", "seedjars", "seedjarsgap", "covered", "foldedcloth", "fileboxes", "driptray", "driptraydry", "outtray", "torch", "batterycase", "cap", "lighttable", "memorialpot", "platebox", "loupe", "printrack", "ledger"]

func mount(adapter: Variant) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SURFACE_PATH))
	if not validate(source, adapter): return false
	var native := preload("res://scripts/building/orison_v2_surface_stock.gd").new()
	if not native.prepare(): return false
	for record: Dictionary in source.props:
		var support := adapter.resolve(record.support) as Node3D
		var prop := Node3D.new()
		prop.name = record.id
		prop.position = _vector(record.position)
		prop.rotation.y = float(record.yaw)
		prop.set_meta("v2_surface_prop", str(record.kind))
		prop.set_meta("support_id", str(record.support))
		if not native.mount_on(prop,str(record.id)):
			prop.free(); native.finish(); return false
		support.add_child(prop)
	native.finish()
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
				or record.get("unit") not in ["1A", "1D", "2A", "2B", "2C", "3A", "3B", "3D", "4A", "4B", "4C", "4D", "5A", "5B", "5C", "6A", "6B", "6C"]:
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
		# The preserved source bounds are the authority for the native actor
		# frame. Refuse drift between those bounds and its original triangles.
		if errors.is_empty():
			var low := Vector3.INF
			var high := -Vector3.INF
			for surface: Dictionary in record.surfaces:
				if str(surface.material).is_empty() or surface.normals.size() != surface.vertices.size(): errors.append("incomplete source surface")
				for offset in range(0,surface.vertices.size(),3):
					var point := Vector3(surface.vertices[offset],surface.vertices[offset+1],surface.vertices[offset+2])
					low = low.min(point); high = high.max(point)
			if low.distance_to(_vector(bounds[0])) > .00003 or high.distance_to(_vector(bounds[1])) > .00003: errors.append("source geometry differs from its retained native frame bounds")
	if seen.is_empty(): errors.append("empty surface prop source")
	return errors.is_empty()
