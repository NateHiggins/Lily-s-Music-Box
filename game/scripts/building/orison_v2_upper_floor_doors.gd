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
	for program: Dictionary in source.programs:
		if program.disposition != "landlord_storage": continue
		var record: Dictionary = {}
		for candidate: Dictionary in layout.doors:
			if candidate.id == program.entry: record = candidate
		var anchor := adapter.resolve(str(program.entry)) as Node3D
		if anchor == null or record.is_empty(): return false
		var door := anchor.get_node_or_null(str(program.entry) + "_Leaf") as OrisonV2FittedDoor
		if door == null: return false
		_add_storage_hasp(door, _hall_side(door, record, layout), layout)
	return true

## Dossier slice 66 (F06_D_RESTRICTED-002): the landlord's storage is padlocked. A galvanised hasp (1928)
## across the latch stile and the casing at 1.2 m, its staple on the casing and a black padlock through it;
## the 1912 brass escutcheon plate above at 1.5 m. Passive, no collision: the lock state stays the leaf's.
func _add_storage_hasp(door: OrisonV2FittedDoor, hall_side: float, layout: Dictionary) -> void:
	var leaf := door.get_node_or_null("HingedLeaf") as Node3D
	if leaf == null: return
	var anchor := door.get_parent_node_3d()
	var slab_z: float = float(door.get("_hinge_offset"))
	var stile_z := slab_z + hall_side * 0.040
	# The casing face on the hall side, carried into the leaf's frame (the casing mounts later, on that plane).
	var into_anchor := anchor.to_local(leaf.to_global(Vector3(door.width, 1.2, slab_z + hall_side))) \
			- anchor.to_local(leaf.to_global(Vector3(door.width, 1.2, slab_z)))
	var partition := float(layout.dimensions.partition_wall)
	var span: Vector2 = preload("res://scripts/generated/v2_exterior_masonry.gd").DOOR_SPANS.get(
			str(door.get_meta("semantic_id", "")), Vector2(-partition * .5, partition * .5))
	var face := (span.y + .018) if into_anchor.z > 0.0 else (span.x - .018)
	var at := anchor.to_local(leaf.to_global(Vector3(door.width, 1.2, stile_z)))
	var casing_z := leaf.to_local(anchor.to_global(Vector3(at.x, at.y, face))).z
	var proud := stile_z if absf(stile_z - slab_z) > absf(casing_z - slab_z) else casing_z
	var strap_z := proud + hall_side * .003
	var lock_z := strap_z + hall_side * .009
	var galvanised := MatLib.get_mat("zinc_quiet", Color(.80, .80, .76))
	var brass := MatLib.get_mat("brass_dull", Color(.80, .70, .50))
	var black := MatLib.get_mat("iron_blackened")
	var hasp := Node3D.new()
	hasp.name = "StorageHasp"
	leaf.add_child(hasp)
	var x := door.width
	for piece: Array in [
			["HaspPlate", "box", Vector3(.10, .042, .003), Vector3(x - .125, 1.2, stile_z + hall_side * .0015), galvanised, Vector3.ZERO],
			["HaspKnuckle", "cylinder", Vector3(.006, .044, 0), Vector3(x - .072, 1.2, stile_z + hall_side * .006), galvanised, Vector3.ZERO],
			["HaspStrap", "box", Vector3(.15, .038, .004), Vector3(x + .003, 1.2, strap_z), galvanised, Vector3.ZERO],
			["StaplePlate", "box", Vector3(.034, .075, .003), Vector3(x + .05, 1.2, casing_z + hall_side * .0015), galvanised, Vector3.ZERO],
			["Staple", "torus", Vector3(.004, .0085, 0), Vector3(x + .05, 1.2, lock_z), galvanised, Vector3(0, 0, PI * .5)],
			["Shackle", "torus", Vector3(.011, .015, 0), Vector3(x + .05, 1.2 - .013, lock_z), MatLib.get_mat("metal"), Vector3(PI * .5, 0, 0)],
			["PadlockBody", "box", Vector3(.042, .048, .017), Vector3(x + .05, 1.2 - .013 - .026, lock_z), black, Vector3.ZERO],
			["Escutcheon", "box", Vector3(.045, .11, .003), Vector3(x - .07, 1.5, stile_z + hall_side * .0015), brass, Vector3.ZERO],
			["Keyhole", "box", Vector3(.008, .022, .001), Vector3(x - .07, 1.49, stile_z + hall_side * .0035), black, Vector3.ZERO]]:
		var mesh: PrimitiveMesh
		var size: Vector3 = piece[2]
		match str(piece[1]):
			"box":
				var box := BoxMesh.new()
				box.size = size
				mesh = box
			"cylinder":
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = size.x
				cylinder.bottom_radius = size.x
				cylinder.height = size.y
				cylinder.radial_segments = 10
				mesh = cylinder
			_:
				var torus := TorusMesh.new()
				torus.inner_radius = size.x
				torus.outer_radius = size.y
				torus.rings = 12
				torus.ring_segments = 8
				mesh = torus
		mesh.material = piece[4]
		var part := MeshInstance3D.new()
		part.name = piece[0]
		part.mesh = mesh
		part.position = piece[3]
		part.rotation = piece[5]
		hasp.add_child(part)

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
