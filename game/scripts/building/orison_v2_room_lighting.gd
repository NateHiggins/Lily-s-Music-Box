extends RefCounted
const PATH := "res://data/orison_v2/room_lighting.json"
const Plate := preload("res://scripts/building/switch_plate.gd")
var errors: Array[String] = []

func mount(adapter: Variant, parent: Node3D) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not validate(source, adapter):
		return false
	var circuits: Dictionary = {}
	for record: Dictionary in source.fixtures:
		var prop: FunctionalProp = LampProp.new() if record.kind == "lamp" else LightFixtureProp.new()
		prop.prop_type = str(record.kind)
		for key: String in record.properties:
			prop.set(key, record.properties[key])
		if not adapter.mount_consumer(str(record.id), prop):
			prop.free()
			return false
		if record.kind != "lamp":
			if not circuits.has(record.room):
				circuits[record.room] = []
			circuits[record.room].append(str(record.id))
	var switches := SwitchSystem.new()
	switches.name = "V2RoomSwitches"
	parent.add_child(switches)
	for room: String in circuits:
		var identities: Array[String] = []
		identities.assign(circuits[room])
		if not switches.bind_semantic_room(room, identities):
			return false
	for record: Dictionary in source.switches:
		var plate := Plate.new()
		plate.system = switches
		plate.set_meta("room_id", str(record.room))
		plate.set_meta("bathroom_switch", str(record.room).ends_with("_BATH"))
		var shape := BoxShape3D.new()
		shape.size = SwitchSystem.PLATE
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.z = -0.045
		plate.add_child(collision)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.18, 0.024)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.position.z = -0.02
		visual.material_override = MatLib.get_mat("bakelite")
		plate.add_child(visual)
		var toggle := MeshInstance3D.new()
		var lever := BoxMesh.new()
		lever.size = Vector3(0.025, 0.055, 0.027)
		toggle.mesh = lever
		toggle.position.z = -0.044
		toggle.material_override = MatLib.get_mat("porcelain")
		plate.add_child(toggle)
		if not adapter.mount_consumer(str(record.id), plate):
			plate.free()
			return false
	return true

func validate(source: Variant, adapter: Variant) -> bool:
	errors.clear()
	if source is not Dictionary or source.get("fixtures") is not Array or source.get("switches") is not Array:
		errors.append("invalid lighting source")
		return false
	var seen: Dictionary = {}
	var rooms: Dictionary = {}
	for value: Variant in source.fixtures + source.switches:
		if value is not Dictionary or value.get("id") is not String or value.get("room") is not String:
			errors.append("invalid lighting identity")
			continue
		if seen.has(value.id) or adapter == null or not adapter.resolve(value.id) is Node3D:
			errors.append("duplicate or missing lighting anchor: " + str(value.id))
		seen[value.id] = true
	if not errors.is_empty():
		return false
	for record: Dictionary in source.fixtures:
		if record.get("kind") not in ["lamp", "pendant_shade", "kitchen_linear", "flush_dome", "sconce_globe"] or record.get("properties") is not Dictionary:
			errors.append("invalid fixture properties")
			continue
		if record.kind == "lamp":
			if record.properties != {"variant": "bench_friction"}:
				errors.append("invalid Omar lamp variant")
		else:
			rooms[record.room] = true
			if record.properties.size() != 2:
				errors.append("unexpected fixture setting")
			for key in ["energy_scale", "range_clamp"]:
				var value: Variant = record.properties.get(key)
				if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)) or float(value) <= 0.0:
					errors.append("invalid fixture setting: " + key)
	var controls: Dictionary = {}
	for record: Dictionary in source.switches:
		if not rooms.has(record.room):
			errors.append("switch has no room fixtures")
		if controls.has(record.room):
			errors.append("room has duplicate circuit controls")
		controls[record.room] = true
	for room: String in rooms:
		if not controls.has(room):
			errors.append("room fixture has no circuit control: " + room)
	return errors.is_empty()
