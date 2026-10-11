extends RefCounted
const PATH := "res://data/orison_v2/room_lighting.json"
const Plate := preload("res://scripts/building/switch_plate.gd")
const NativeLamp := preload("res://scripts/props/native_task_lamp.gd")
var errors: Array[String] = []

func mount(adapter: Variant, parent: Node3D) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return mount_source(adapter, parent, source)

func mount_completion(adapter: Variant, parent: Node3D) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/completion_interiors.json"))
	if source is not Dictionary or source.get("lighting") is not Dictionary: return false
	return mount_source(adapter, parent, source.lighting)

func mount_source(adapter: Variant, parent: Node3D, source: Variant) -> bool:
	if not validate(source, adapter):
		return false
	var circuits: Dictionary = {}
	for record: Dictionary in source.fixtures:
		var prop: FunctionalProp = NativeLamp.new() if record.kind == "lamp" else LightFixtureProp.new()
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
	var switches := parent.get_node_or_null("V2RoomSwitches") as SwitchSystem
	if switches == null:
		switches = SwitchSystem.new()
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
		var room := str(record.room)
		var floor_number := room.get_slice("_",0).trim_prefix("F").to_int()
		var dwelling := room.get_slice("_",1)
		plate.unit = str(floor_number)+dwelling if floor_number in range(1,7) and dwelling in ["A","B","C","D"] else room
		plate.set_meta("room_id", str(record.room))
		plate.set_meta("bathroom_switch", str(record.room).ends_with("_BATH"))
		var shape := BoxShape3D.new()
		shape.size = SwitchSystem.PLATE
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.z = -0.045
		plate.add_child(collision)
		if not adapter.mount_consumer(str(record.id), plate):
			plate.free()
			return false
		plate.mount_model()
		_add_signal_outlet(plate, adapter, str(record.room))
	return true

## Dossier BW-013: a brass signal-outlet plate (70 x 115 mm, 6 mm proud) beside
## every switch, on the side with wall, toward the room centre. A passive draw
## under the plate: no collision, no owner, no lead stub until a device connects.
func _add_signal_outlet(plate: Node3D, adapter: Variant, room: String) -> void:
	var root := adapter.root as Node3D
	var side := 1.0
	if root != null and root.get("layout") is Dictionary:
		for space: Dictionary in root.layout.get("spaces", []):
			if str(space.get("id", "")) != room or not space.has("rect"): continue
			var rect: Array = space.rect
			var centre := root.to_global(Vector3((float(rect[0]) + float(rect[2])) * 0.5, 0.0, (float(rect[1]) + float(rect[3])) * 0.5))
			var right := plate.to_global(Vector3(0.115, 0.0, 0.0))
			var left := plate.to_global(Vector3(-0.115, 0.0, 0.0))
			centre.y = 0.0; right.y = 0.0; left.y = 0.0
			side = 1.0 if right.distance_to(centre) <= left.distance_to(centre) else -1.0
			break
	var outlet := MeshInstance3D.new()
	outlet.name = "SignalOutlet"
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.115, 0.006)
	box.material = MatLib.get_mat("brass_dull", Color(0.78, 0.70, 0.52))
	outlet.mesh = box
	outlet.position = Vector3(side * 0.115, 0.0, -0.003)
	plate.add_child(outlet)

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
		if record.get("kind") not in ["lamp", "pendant_shade", "kitchen_linear", "flush_dome", "sconce_globe", "cage_bulb"] or record.get("properties") is not Dictionary:
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
