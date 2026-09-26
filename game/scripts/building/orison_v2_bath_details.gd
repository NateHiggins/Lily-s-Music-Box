extends "res://scripts/building/orison_v2_domestic_furniture.gd"
## Fixed dressing follows its physical support; it owns no input, save or light.
const TOWEL_MODEL := "res://assets/props/bath_towel.glb"
const PAPER_MODEL := "res://assets/props/bath_paper_holder.glb"
const DETAIL_PATH := "res://data/orison_v2/bath_details.json"
const UNITS := ["2A", "2B", "3A", "3B", "4A", "4B", "5A", "5B", "5C", "6A", "6B", "6C"]
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
		if record.kind in ["hand_towel", "toilet_roll"]:
			var model := (load(str(record.model)) as PackedScene).instantiate() as Node3D
			_skin_model(model)
			detail.add_child(model)
		elif not shared.has(record.kind):
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
	var model_points := {}
	for model_path in [TOWEL_MODEL, PAPER_MODEL]:
		var points: Array[Vector3] = []
		var model := (load(model_path) as PackedScene).instantiate() as Node3D
		_model_points(model, Transform3D.IDENTITY, points)
		model_points[model_path] = points
		model.free()
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
		# JSON numbers are floats; Array equality also compares element types.
		# Validate numeric values so a serialized zero origin is accepted.
		if not _numbers(record.get("position"), 3) \
				or float(record.position[0]) != 0.0 or float(record.position[1]) != 0.0 \
				or float(record.position[2]) != 0.0 \
				or not _numbers([record.get("yaw")], 1) or float(record.yaw) != 0.0:
			errors.append("bath detail must use its support-local contact")
		var before := errors.size()
		if record.kind in ["hand_towel", "toilet_roll"]:
			if record.get("model") != (TOWEL_MODEL if record.kind == "hand_towel" else PAPER_MODEL) or record.has("surfaces"):
				errors.append("bath dressing must use the approved Blender model")
		else:
			_validate_surfaces(record.get("surfaces"))
		if errors.size() != before: continue
		var bounds: Variant = record.get("bounds")
		if bounds is not Array or bounds.size() != 2 or not _numbers(bounds[0],3) or not _numbers(bounds[1],3):
			errors.append("invalid bath detail bounds")
			continue
		var low := Vector3(-.38,0,-.4) if record.kind == "toilet_roll" else Vector3(-.33,0,-.285)
		var high := Vector3(.27,.84,.36) if record.kind == "toilet_roll" else Vector3(.33,1.2,.24)
		for axis in 3:
			if bounds[0][axis] < low[axis] or bounds[1][axis] > high[axis] or bounds[0][axis] >= bounds[1][axis]:
				errors.append("bath detail exceeds supported clearance")
		for surface: Dictionary in record.get("surfaces", []):
			for i in range(0, surface.vertices.size(), 3):
				for axis in 3:
					var coordinate: float = surface.vertices[i+axis]
					if coordinate < float(bounds[0][axis])-.000001 or coordinate > float(bounds[1][axis])+.000001:
						errors.append("bath surface exceeds declared bounds")
		if record.kind in ["hand_towel", "toilet_roll"]:
			for point in model_points[record.model]:
				for axis in 3:
					if point[axis] < float(bounds[0][axis])-.00001 or point[axis] > float(bounds[1][axis])+.00001:
						errors.append("Blender bath dressing exceeds declared bounds")
		if record.kind not in ["hand_towel", "toilet_roll"] and shared.has(record.kind) and shared[record.kind] != record.get("surfaces"):
			errors.append("shared bath geometry disagrees between homes")
		shared[record.kind] = record.get("surfaces")
	if seen.size() != UNITS.size() * KINDS.size() or source.props.size() != UNITS.size() * KINDS.size():
		errors.append("incomplete developed-home bath detail roster")
	return errors.is_empty()


func _skin_model(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(surface)
			if material != null:
				node.set_surface_override_material(surface, MatLib.get_mat(material.resource_name))
	for child in node.get_children(): _skin_model(child)


func _model_points(node: Node3D, parent_pose: Transform3D, points: Array[Vector3]) -> void:
	var pose := parent_pose * node.transform
	if node is MeshInstance3D:
		for vertex in node.mesh.get_faces(): points.append(pose * vertex)
	for child in node.get_children():
		if child is Node3D: _model_points(child, pose, points)
