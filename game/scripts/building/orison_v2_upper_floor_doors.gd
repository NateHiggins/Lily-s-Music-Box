extends "res://scripts/building/orison_v2_domestic_doors.gd"
## The same physical leaf owner serves the new, explicitly programmed floors.
const PROGRAM_PATH := "res://data/orison_v2/upper_floor_programs.json"
const UNITS := ["5A", "5B", "5C", "5D", "6A", "6B", "6C", "6D"]
const RESIDENTS := {"5A":"nadia_quell", "5B":"cal_dwyer", "5C":"iris_bell",
		"6A":"sacha_reed", "6B":"jonah_price", "6C":"mae_kessler", "5D":"", "6D":""}

func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROGRAM_PATH))
	if not validate(source, layout): return false
	for identity: String in source.doors:
		var anchor := adapter.resolve(identity) as Node3D
		if anchor == null: return false
		for part: String in ["FrameLeft", "FrameRight", "FrameHead"]:
			var frame := anchor.get_node_or_null(part) as MeshInstance3D
			if frame == null or not frame.mesh is BoxMesh: return false
	if not mount_specs(adapter, layout, source.doors): return false
	for identity: String in source.doors:
		var anchor := adapter.resolve(identity) as Node3D
		for part: String in ["FrameLeft", "FrameRight", "FrameHead"]:
			var frame := anchor.get_node(part) as MeshInstance3D
			var mesh := frame.mesh as BoxMesh
			mesh.size.z = float(source.doors[identity].jamb_depth)
	return true

func validate(source: Variant, layout: Dictionary) -> bool:
	if source is not Dictionary or source.get("schema_version") != 1 \
			or source.get("programs") is not Array or source.get("doors") is not Dictionary:
		return false
	if typeof(source.schema_version) not in [TYPE_INT, TYPE_FLOAT]: return false
	var units := {}
	var entries := {}
	var rooms := {}
	var assigned := {}
	for room: Dictionary in layout.spaces: rooms[room.id] = room
	for program: Variant in source.programs:
		if program is not Dictionary or program.get("unit") not in UNITS or units.has(program.unit) \
				or program.get("rooms") is not Array or program.rooms.is_empty(): return false
		units[program.unit] = true
		if program.get("resident") != RESIDENTS[program.unit]: return false
		if program.get("entry") is not String or entries.has(program.entry): return false
		entries[program.entry] = program.unit
		for identity: Variant in program.rooms:
			if identity is not String or assigned.has(identity) or not rooms.has(identity) or rooms[identity].get("unit") != program.unit: return false
			assigned[identity] = true
		var restricted: bool = program.unit in ["5D", "6D"]
		var disposition := "fire_damaged" if program.unit == "5D" else "landlord_storage"
		if program.get("disposition") != (disposition if restricted else "occupied"): return false
		if restricted and program.get("resident") != "": return false
	if units.size() != 8 or source.programs.size() != 8: return false
	for identity: String in rooms:
		if rooms[identity].get("unit") in UNITS and not assigned.has(identity): return false
	var records := {}
	for record: Dictionary in layout.doors:
		if record.level in ["F05", "F06"]: records[record.id] = record
	if records.size() != source.doors.size() or records.is_empty(): return false
	for identity: Variant in source.doors:
		var spec: Variant = source.doors[identity]
		if not records.has(identity) or spec is not Dictionary or spec.size() != 6 \
				or spec.get("unit") not in UNITS or spec.get("swing_out") is not bool: return false
		if spec.get("mount_offset") != (.08 if spec.swing_out else -.08) or spec.get("jamb_depth") != .22: return false
		var entry: bool = entries.has(identity)
		if entry and entries[identity] != spec.unit: return false
		if spec.get("kind") != ("apartment_entry" if entry else "apartment_interior"): return false
		var locked: bool = entry and spec.unit in ["5D", "6D"]
		if spec.get("leaf_state") != ("locked" if locked else "closed"): return false
		var serves_unit := false
		for room: String in records[identity].connects:
			if rooms.get(room, {}).get("unit") == spec.unit: serves_unit = true
		if not serves_unit: return false
	for identity: String in entries:
		if not source.doors.has(identity): return false
	return true
