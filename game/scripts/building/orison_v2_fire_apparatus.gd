extends RefCounted
## The apparatus set in V2: the soda-acid extinguisher beside the fire cabinets
## (v1r_extinguisher_20261109) and the liquid door check on the roof stair door
## (v1r_door_closer_b_20261109). Placement is data
## (data/orison_v2/fire_apparatus_placements.json); both props keep their V1
## scripts as the behaviour authority.
##
## The runtime root calls, once the doors and the fire service are mounted:
##   preload("res://scripts/building/orison_v2_fire_apparatus.gd").mount(self, _blockout, _blockout.layout, adapter)
const PATH := "res://data/orison_v2/fire_apparatus_placements.json"
const Extinguisher := preload("res://scripts/building/orison_v2_extinguisher_prop.gd")
const DoorCheck := preload("res://scripts/building/orison_v2_door_check_prop.gd")
const HOLDER := "NativeFireApparatus"


## Returns {"extinguishers": [nodes], "door_check": node or null, "errors": [..]}.
## An empty "errors" is a complete mount.
static func mount(root: Node3D, blockout: Node3D, layout: Dictionary, adapter: Variant) -> Dictionary:
	var result := {"extinguishers": [], "door_check": null, "errors": []}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
		result.errors.append("fire apparatus placements missing")
		return result
	if blockout == null or blockout.get_node_or_null(HOLDER) != null:
		result.errors.append("fire apparatus already mounted, or no blockout")
		return result
	var levels: Dictionary = {}
	for level: Dictionary in layout.get("levels", []):
		levels[str(level.id)] = float(level.y)
	var holder := Node3D.new()
	holder.name = HOLDER
	blockout.add_child(holder)
	for row: Dictionary in parsed.extinguishers:
		# V1's own board table: one unit in the building is hung and inspectable.
		if str(row.get("condition", "working")) != "working":
			continue
		if not levels.has(str(row.level)) or adapter.resolve(str(row.beside)) == null:
			result.errors.append("extinguisher station unresolved: " + str(row.station_id))
			continue
		var unit := Extinguisher.new()
		unit.name = str(row.station_id)
		unit.prop_type = "soda_acid_extinguisher"
		unit.station_id = str(row.station_id)
		# Plan coordinates, in the blockout's own frame: the holder is its child,
		# so the building's turn in the world is never done by hand.
		unit.position = Vector3(float(row.position[0]), levels[str(row.level)] + float(row.position[1]),
				float(row.position[2]))
		unit.rotation.y = float(row.yaw)
		unit.set_meta("beside_fire_station", str(row.beside))
		holder.add_child(unit)
		if unit.stock == null:
			result.errors.append("extinguisher stock refused: " + str(row.station_id))
			continue
		result.extinguishers.append(unit)
	var door_id := str(parsed.door_check.door)
	var anchor := adapter.resolve(door_id) as Node3D
	var leaf: Node = anchor.get_node_or_null(door_id + "_Leaf") if anchor != null else null
	if leaf == null or not leaf.has_method("mechanism_snapshot"):
		result.errors.append("roof stair leaf unresolved: " + door_id)
	else:
		var check := DoorCheck.new()
		check.name = str(parsed.door_check.name)
		check.prop_type = "door_check_closer"
		# The leaf authority is this node's own parent, as in V1.
		check.door_path = NodePath("..")
		leaf.add_child(check)
		if not check.fits(leaf):
			result.errors.append("door check stock does not fit " + door_id)
			leaf.remove_child(check)
			check.free()
		else:
			result.door_check = check
	if root != null:
		root.set_meta("v2_fire_apparatus", result)
	return result
