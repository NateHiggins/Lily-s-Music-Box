extends RefCounted
## Registers the construction's local frame at an exterior public surface.
## Standalone review geometry remains intact; only the composed copy opens.

const CONFIG_PATH := "res://data/orison_v2/world_connection.json"

static func read_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

static func unique_record(records: Array, identity: String) -> Dictionary:
	var found: Dictionary = {}
	for record: Dictionary in records:
		if str(record.get("id", "")) == identity:
			if not found.is_empty():
				return {}
			found = record
	return found

static func prepare(source: Dictionary, geometry: Dictionary, resolver: Variant,
		config: Dictionary) -> Dictionary:
	if int(config.get("schema_version", 0)) != 1 or not resolver.is_valid():
		return {}
	for key: String in ["door_id", "inside_space_id", "outside_space_id", "instance_id",
			"surface_id", "arrival_placement_id", "template_id"]:
		if not config.get(key) is String or str(config[key]).is_empty():
			return {}
	var instance: Dictionary = resolver.instance_record(str(config.instance_id))
	if str(instance.get("template_id", "")) != str(config.template_id) \
			or not (resolver.instance_world_transform(str(config.instance_id)) as Transform3D).is_equal_approx(Transform3D.IDENTITY):
		return {}
	var door := unique_record(source.get("doors", []), str(config.get("door_id", "")))
	var inside := unique_record(source.get("spaces", []), str(config.get("inside_space_id", "")))
	var outside := unique_record(source.get("spaces", []), str(config.get("outside_space_id", "")))
	if door.is_empty() or inside.is_empty() or outside.is_empty():
		return {}
	if door.get("connects", []).size() != 2 or inside.id not in door.connects \
			or outside.id not in door.connects or inside.level != door.level \
			or outside.level != door.level or not bool(outside.get("open_shell", false)):
		return {}
	var level := unique_record(source.get("levels", []), str(door.level))
	var surface: Dictionary = resolver.resolve_surface(str(config.instance_id), str(config.surface_id))
	var arrival: Dictionary = resolver.resolve_placement(str(config.instance_id), str(config.arrival_placement_id))
	if level.is_empty() or surface.is_empty() or arrival.is_empty():
		return {}
	var center: Array = door.get("center", [])
	var rect: Array = inside.get("rect", [])
	if center.size() != 2 or rect.size() != 4:
		return {}
	var threshold := Vector3(float(center[0]), float(level.y), float(center[1]))
	var outward := threshold - Vector3((float(rect[0]) + float(rect[2])) * 0.5,
			float(level.y), (float(rect[1]) + float(rect[3])) * 0.5)
	var normal: Vector3 = surface.normal
	var point: Vector3 = surface.point
	var arrival_position: Vector3 = arrival.get("position", Vector3.INF)
	if not threshold.is_finite() or not outward.is_finite() or outward.length_squared() < 0.000001 \
			or not normal.is_finite() or absf(normal.y) > 0.0001 or not point.is_finite() \
			or not arrival_position.is_finite() \
			or float(door.width) <= 0.0 or float(door.width) > float(surface.size_m[0]) \
			or float(door.height) > float(surface.size_m[1]):
		return {}
	var basis := Basis(Vector3.UP, atan2(normal.x, normal.z) - atan2(outward.x, outward.z))
	var registered := Transform3D(basis, point - basis * threshold)
	var opened := open_geometry(geometry, config, surface)
	if opened.is_empty():
		return {}
	# Arrival faces the building from its named exterior placement.
	arrival = arrival.duplicate(true)
	arrival.facing = -normal
	return {"interior_transform": registered, "excluded_space": str(outside.id),
		"geometry": opened, "arrival": arrival}

static func open_geometry(source: Dictionary, config: Dictionary, surface: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var template := unique_record(result.get("templates", []), str(config.get("template_id", "")))
	if template.is_empty():
		return {}
	var removals: Array = config.get("remove_boxes", [])
	var splits: Array = config.get("split_boxes", [])
	var requested: Dictionary = {}
	for identity: Variant in removals + splits:
		if requested.has(identity) or unique_record(template.boxes, str(identity)).is_empty():
			return {}
		requested[identity] = true
	# This variant cuts axis-aligned trim at the root template's public portal.
	if not (surface.u_axis as Vector3).is_equal_approx(Vector3.RIGHT):
		return {}
	var point: Vector3 = surface.point
	var half_width := float(surface.size_m[0]) * 0.5
	var boxes: Array = []
	for box: Dictionary in template.boxes:
		if box.id in removals:
			continue
		if box.id not in splits:
			boxes.append(box)
			continue
		if not is_zero_approx(float(box.yaw_degrees)):
			return {}
		var left := float(box.position_m[0]) - float(box.size_m[0]) * 0.5
		var right := float(box.position_m[0]) + float(box.size_m[0]) * 0.5
		if left >= point.x - half_width or right <= point.x + half_width:
			return {}
		for segment: Array in [[left, point.x - half_width, "left"], [point.x + half_width, right, "right"]]:
			var piece := box.duplicate(true)
			piece.id = str(box.id) + "_" + str(segment[2])
			if not unique_record(template.boxes, piece.id).is_empty():
				return {}
			piece.position_m[0] = (float(segment[0]) + float(segment[1])) * 0.5
			piece.size_m[0] = float(segment[1]) - float(segment[0])
			boxes.append(piece)
	template.boxes = boxes
	return result
