extends "res://scripts/building/orison_v2_domestic_furniture.gd"
## Fixed dressing follows its physical support; it owns no input, save or light.
const DETAIL_PATH := "res://data/orison_v2/bath_details.json"
const UNITS := ["2A", "2B", "3A", "3B", "4A", "4B"]
const KINDS := ["soap_dish", "hand_towel", "toilet_roll"]

func mount(adapter: Variant) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(DETAIL_PATH))
	if not validate(source, adapter): return false
	var shared: Dictionary = {}
	for record: Dictionary in source.props:
		var detail := Node3D.new()
		detail.name = str(record.id)
		detail.set_meta("v2_bath_detail", str(record.kind))
		detail.set_meta("support_id", str(record.support))
		# Geometry is identical across homes. Each physical owner gets its own
		# instances while immutable meshes and existing MatLib materials share.
		if not shared.has(record.kind):
			_add_surfaces(detail, record.surfaces)
			shared[record.kind] = detail.get_children()
		else:
			for template: MeshInstance3D in shared[record.kind]:
				var visual := MeshInstance3D.new()
				visual.mesh = template.mesh
				visual.material_override = template.material_override
				detail.add_child(visual)
		adapter.resolve(str(record.support)).add_child(detail)
	return true

func validate(source: Variant, adapter: Variant) -> bool:
	errors.clear()
	if source is not Dictionary or source.size() != 2 or source.get("schema_version") != 1 \
			or source.get("props") is not Array or adapter == null:
		errors.append("malformed bath detail source")
		return false
	var seen := {}
	var shared := {}
	for record: Variant in source.props:
		if record is not Dictionary or record.get("unit") not in UNITS or record.get("kind") not in KINDS:
			errors.append("invalid bath detail household or kind")
			continue
		var unit_id := str(record.unit)
		var identity := unit_id + "_" + str(record.kind)
		var support := unit_id + "_wc" if record.kind == "toilet_roll" else "F0"+unit_id[0]+"_"+unit_id+"_SINK_01"
		if record.get("id") != identity or record.get("support") != support or seen.has(identity):
			errors.append("duplicate or incorrect bath detail identity/support")
		seen[identity] = true
		var owner: Node = adapter.resolve(support)
		if (record.kind == "toilet_roll" and not owner is BakedFurnitureInteraction) \
				or (record.kind != "toilet_roll" and (not owner is TapProp or owner.get("fixture") != "bath_sink")) \
				or adapter.resolve(identity) != null:
			errors.append("missing bath support or occupied detail identity")
		if not _numbers(record.get("position"), 3) or record.position != [0,0,0] \
				or not _numbers([record.get("yaw")], 1) or record.yaw != 0:
			errors.append("bath detail must use its support-local contact")
		var before := errors.size()
		_validate_surfaces(record.get("surfaces"))
		if errors.size() != before: continue
		var bounds: Variant = record.get("bounds")
		if bounds is not Array or bounds.size() != 2 or not _numbers(bounds[0],3) or not _numbers(bounds[1],3):
			errors.append("invalid bath detail bounds")
			continue
		var low := Vector3(-.27,0,-.4) if record.kind == "toilet_roll" else Vector3(-.33,0,-.285)
		var high := Vector3(.27,.84,.36) if record.kind == "toilet_roll" else Vector3(.33,1.2,.24)
		for axis in 3:
			if bounds[0][axis] < low[axis] or bounds[1][axis] > high[axis] or bounds[0][axis] >= bounds[1][axis]:
				errors.append("bath detail exceeds supported clearance")
		for surface: Dictionary in record.surfaces:
			for i in range(0, surface.vertices.size(), 3):
				for axis in 3:
					var coordinate: float = surface.vertices[i+axis]
					if coordinate < float(bounds[0][axis])-.000001 or coordinate > float(bounds[1][axis])+.000001:
						errors.append("bath surface exceeds declared bounds")
		if shared.has(record.kind) and shared[record.kind] != record.get("surfaces"):
			errors.append("shared bath geometry disagrees between homes")
		shared[record.kind] = record.get("surfaces")
	if seen.size() != 18 or source.props.size() != 18:
		errors.append("incomplete six-home bath detail roster")
	return errors.is_empty()
