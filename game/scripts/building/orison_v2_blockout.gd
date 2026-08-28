extends Node3D
## Development-only Orison v2 gray-box. One semantic JSON record owns spaces,
## doors, stairs, risers and anchors; every visible/collision node derives from it.

@export_file("*.json") var layout_path := "res://data/orison_v2_blockout.json"
@export var show_ceilings := true
@export var show_clearance_anchors := true
@export var hold_route_doors_open := true

var layout: Dictionary = {}
var level_y: Dictionary = {}
var materials: Dictionary = {}
var failures: Array[String] = []

func _ready() -> void:
	layout = _load_layout(layout_path)
	if layout.is_empty():
		return
	_validate_layout()
	if not failures.is_empty():
		for failure in failures:
			push_error("ORISON V2: " + failure)
		return
	_build_palette()
	_build_spaces()
	_build_doors()
	_build_stairs()
	_build_risers()
	_build_anchors()
	add_to_group("orison_v2_blockout")
	print("ORISON V2 BLOCKOUT: %d spaces / %d doors / %d anchors" % [
		layout.spaces.size(), layout.doors.size(), layout.anchors.size()])

func _load_layout(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("ORISON V2 layout missing: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("ORISON V2 layout is not a JSON object")
		return {}
	return parsed

func _validate_layout() -> void:
	if int(layout.get("schema_version", 0)) != 1:
		failures.append("unsupported schema_version")
	if bool(layout.get("production_default", true)):
		failures.append("development blockout may not be production_default")
	var ids := {}
	for level: Dictionary in layout.get("levels", []):
		var ident := str(level.get("id", ""))
		if ident.is_empty() or level_y.has(ident):
			failures.append("invalid or duplicate level id: " + ident)
		level_y[ident] = float(level.get("y", 0.0))
	for table in ["spaces", "doors", "anchors", "stairs", "risers"]:
		for record: Dictionary in layout.get(table, []):
			var ident := str(record.get("id", ""))
			if ident.is_empty() or ids.has(ident):
				failures.append("invalid or duplicate id: " + ident)
			ids[ident] = table
			if record.has("level") and not level_y.has(str(record.level)):
				failures.append("%s references missing level %s" % [ident, record.level])
	for space: Dictionary in layout.get("spaces", []):
		if not _valid_rect(space.get("rect", [])):
			failures.append("invalid space rect: " + str(space.get("id", "?")))
	for riser: Dictionary in layout.get("risers", []):
		if not _valid_rect(riser.get("rect", [])):
			failures.append("invalid riser rect: " + str(riser.get("id", "?")))
	for required in ["F01_DOOR_06", "F02_DOOR_02", "F04_DOOR_03",
			"F02_A_MAIN_VANTRY_POINT", "F04_B_MONITOR_01", "F04_B_BED"]:
		if not ids.has(required):
			failures.append("required compatibility id missing: " + required)

func _valid_rect(value: Variant) -> bool:
	return value is Array and value.size() == 4 \
			and float(value[0]) < float(value[2]) and float(value[1]) < float(value[3])

func _build_palette() -> void:
	for key: String in layout.get("palette", {}):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.html(str(layout.palette[key]))
		mat.roughness = 0.9
		materials[key] = mat

func _build_spaces() -> void:
	var dims: Dictionary = layout.dimensions
	var clear_h := float(dims.clear_height)
	var slab_t := float(dims.slab_thickness)
	for space: Dictionary in layout.spaces:
		var rect: Array = space.rect
		var y := float(level_y[space.level])
		var cls := str(space.get("class", "unresolved"))
		var parent := Node3D.new()
		parent.name = str(space.id)
		parent.set_meta("purpose", str(space.get("purpose", "")))
		parent.set_meta("room_id", str(space.id))
		add_child(parent)
		_box(parent, "Floor", _rect_center(rect, y - slab_t * 0.5),
				Vector3(_rect_w(rect), slab_t, _rect_d(rect)), cls, true)
		if show_ceilings:
			_box(parent, "Ceiling", _rect_center(rect, y + clear_h + slab_t * 0.5),
					Vector3(_rect_w(rect), slab_t, _rect_d(rect)), cls, false)
		_build_space_outline(parent, str(space.id), rect, y, clear_h, cls)

func _build_space_outline(parent: Node3D, space_id: String, rect: Array, y: float,
		height: float, cls: String) -> void:
	var t := float(layout.dimensions.partition_wall)
	_wall_with_openings(parent, space_id, "South", "x", float(rect[1]),
			float(rect[0]), float(rect[2]), y, height, t, cls)
	_wall_with_openings(parent, space_id, "North", "x", float(rect[3]),
			float(rect[0]), float(rect[2]), y, height, t, cls)
	_wall_with_openings(parent, space_id, "West", "z", float(rect[0]),
			float(rect[1]), float(rect[3]), y, height, t, cls)
	_wall_with_openings(parent, space_id, "East", "z", float(rect[2]),
			float(rect[1]), float(rect[3]), y, height, t, cls)

func _wall_with_openings(parent: Node3D, space_id: String, label: String,
		axis: String, fixed: float, start: float, finish: float, y: float,
		height: float, thickness: float, cls: String) -> void:
	var openings: Array[Dictionary] = []
	for door: Dictionary in layout.doors:
		if not space_id in door.connects:
			continue
		var on_wall := (is_equal_approx(float(door.center[1]), fixed) if axis == "x"
				else is_equal_approx(float(door.center[0]), fixed))
		if on_wall:
			openings.append({"center": float(door.center[0] if axis == "x" else door.center[1]),
					"width": float(door.width), "height": float(door.height)})
	openings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.center) < float(b.center))
	var cursor := start
	var part := 0
	for opening: Dictionary in openings:
		var lo := maxf(start, float(opening.center) - float(opening.width) * 0.5)
		var hi := minf(finish, float(opening.center) + float(opening.width) * 0.5)
		if lo > cursor + 0.001:
			_wall_segment(parent, "Wall%s_%02d" % [label, part], axis, fixed,
					cursor, lo, y, height, thickness, cls)
			part += 1
		var head_h := height - float(opening.height)
		if head_h > 0.001:
			_wall_segment(parent, "Wall%s_Head%02d" % [label, part], axis, fixed,
					lo, hi, y + float(opening.height), head_h, thickness, cls)
			part += 1
		cursor = maxf(cursor, hi)
	if cursor < finish - 0.001:
		_wall_segment(parent, "Wall%s_%02d" % [label, part], axis, fixed,
				cursor, finish, y, height, thickness, cls)

func _wall_segment(parent: Node3D, node_name: String, axis: String, fixed: float,
		start: float, finish: float, y: float, height: float, thickness: float,
		cls: String) -> void:
	var center := (start + finish) * 0.5
	if axis == "x":
		_box(parent, node_name, Vector3(center, y + height * 0.5, fixed),
				Vector3(finish - start, height, thickness), cls, true)
	else:
		_box(parent, node_name, Vector3(fixed, y + height * 0.5, center),
				Vector3(thickness, height, finish - start), cls, true)

func _build_doors() -> void:
	for door: Dictionary in layout.doors:
		var parent := Node3D.new()
		parent.name = str(door.id)
		parent.set_meta("connects", door.connects)
		parent.set_meta("hinge", str(door.hinge))
		parent.set_meta("swing", str(door.swing))
		var y := float(level_y[door.level])
		parent.position = Vector3(float(door.center[0]), y, float(door.center[1]))
		parent.rotation.y = float(door.yaw)
		add_child(parent)
		var width := float(door.width)
		var height := float(door.height)
		var hinge := Node3D.new()
		hinge.name = "Hinge"
		var hinge_sign := -1.0 if str(door.hinge) == "left" else 1.0
		hinge.position.x = hinge_sign * width * 0.5
		if hold_route_doors_open:
			hinge.rotation.y = hinge_sign * PI * 0.5
		parent.add_child(hinge)
		_box(hinge, "Leaf", Vector3(-hinge_sign * width * 0.5, height * 0.5, 0.0),
				Vector3(width, height, 0.045), "opening", true)
		_box(parent, "FrameLeft", Vector3(-width * 0.5 - 0.045, height * 0.5, 0.0),
				Vector3(0.09, height, 0.10), "core", false)
		_box(parent, "FrameRight", Vector3(width * 0.5 + 0.045, height * 0.5, 0.0),
				Vector3(0.09, height, 0.10), "core", false)
		_box(parent, "FrameHead", Vector3(0.0, height + 0.045, 0.0),
				Vector3(width + 0.18, 0.09, 0.10), "core", false)

func _build_stairs() -> void:
	for stair: Dictionary in layout.stairs:
		var parent := Node3D.new()
		parent.name = str(stair.id)
		add_child(parent)
		var base_y := float(level_y[stair.from])
		var sign_z := 1.0 if str(stair.direction) == "north" else -1.0
		for i in int(stair.steps):
			var rise := float(stair.rise)
			var tread := float(stair.tread)
			var position := Vector3(float(stair.origin[0]), base_y + rise * (i + 1) * 0.5,
					float(stair.origin[1]) + sign_z * tread * (i + 0.5))
			_box(parent, "Step%02d" % i, position,
					Vector3(float(stair.width), rise * (i + 1), tread), "core", true)

func _build_risers() -> void:
	for riser: Dictionary in layout.risers:
		var rect: Array = riser.rect
		var y0 := float(riser.from_y)
		var y1 := float(riser.to_y)
		_box(self, str(riser.id), _rect_center(rect, (y0 + y1) * 0.5),
				Vector3(_rect_w(rect), y1 - y0, _rect_d(rect)),
				str(riser.get("class", "service")), true)

func _build_anchors() -> void:
	for anchor: Dictionary in layout.anchors:
		var node := Marker3D.new()
		node.name = str(anchor.id)
		var p: Array = anchor.position
		node.position = Vector3(float(p[0]), float(level_y[anchor.level]) + float(p[1]),
				float(p[2]))
		node.rotation.y = float(anchor.get("yaw", 0.0))
		node.set_meta("anchor_kind", str(anchor.kind))
		add_child(node)
		if show_clearance_anchors and str(anchor.kind) in ["interaction", "clearance"]:
			_box(node, "Envelope", Vector3(0.0, 0.01, 0.0), Vector3(0.9, 0.02, 0.9),
					"interaction" if str(anchor.kind) == "interaction" else "clearance", false)

func _box(parent: Node, node_name: String, at: Vector3, size: Vector3,
		material_key: String, collision: bool) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = materials.get(material_key, materials.get("unresolved"))
	mesh_node.mesh = mesh
	mesh_node.position = at
	parent.add_child(mesh_node)
	if collision:
		var body := StaticBody3D.new()
		body.name = "Collision"
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		mesh_node.add_child(body)
	return mesh_node

func _rect_center(rect: Array, y: float) -> Vector3:
	return Vector3((float(rect[0]) + float(rect[2])) * 0.5, y,
			(float(rect[1]) + float(rect[3])) * 0.5)

func _rect_w(rect: Array) -> float:
	return float(rect[2]) - float(rect[0])

func _rect_d(rect: Array) -> float:
	return float(rect[3]) - float(rect[1])
