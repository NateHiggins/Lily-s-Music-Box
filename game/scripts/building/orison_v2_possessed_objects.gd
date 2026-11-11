extends RefCounted
## The possessed household objects V2 had no counterpart for (retirement plan,
## section B; Lily, v1r_witness_tells_20261109).
##
## V1 stood a stand-in object in each case flat and three in 4B. Six of those
## tells already ride V2's own furniture (orison_v2_domestic_witnesses.gd).
## This mounts the other thirteen: twelve period objects built in Blender
## (build_possessed_objects.py), each placed in its owner's flat by data, and
## one hand on an object V2 already has, 4B's medicine-cabinet mirror.
##
## Every one is named `DomesticAnomaly_<id>`, the node its row in
## possessed_objects.json names, so the witnesses' own table finds it. Mount
## this BEFORE the domestic witnesses.
const TELLS := "res://data/orison_v2/possessed_objects.json"
const PLACEMENTS := "res://data/orison_v2/possessed_object_placements.json"
const Native := preload("res://scripts/building/orison_v2_native_possessed_objects.gd")
const PossessedObject := preload("res://scripts/building/orison_v2_possessed_object.gd")
const HOLDER := "PossessedObjects"
const PREFIX := "DomesticAnomaly_"


## The tell on a V2 object that moves by a mechanism of its own: the cabinet
## mirror in 4B's bath is found standing the other way from how it was left.
class CabinetHand extends Node3D:
	var cabinet: Node
	var possessed := false
	var _left_open := false

	func set_possessed(on: bool) -> void:
		if possessed == on or not is_instance_valid(cabinet):
			return
		possessed = on
		if on:
			_left_open = bool(cabinet.is_door_open())
			cabinet.set_door_open(not _left_open, 0.0)
		else:
			cabinet.set_door_open(_left_open, 0.0)

	func tell_signature() -> Array:
		return [bool(cabinet.is_door_open())] if is_instance_valid(cabinet) else []


## Returns {"objects": {id: node}, "node": the holder under the blockout,
## "errors": [String]}.
static func mount(root: Node3D, blockout: Node3D, layout: Dictionary, adapter: Variant) -> Dictionary:
	var result := {"objects": {}, "node": null, "errors": []}
	var errors: Array = result.errors
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(TELLS))
	var placed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACEMENTS))
	if not (table is Dictionary) or not (table.get("tells") is Array) or not (placed is Dictionary) \
			or int(placed.get("schema_version", 0)) != 1:
		errors.append("possessed object table or placements missing")
		return result
	if root == null or blockout == null or adapter == null or blockout.get_node_or_null(HOLDER) != null:
		errors.append("possessed objects need a blockout and mount once")
		return result
	var native := Native.new()
	if not native.prepare():
		errors.append_array(native.errors)
		return result
	var spaces: Dictionary = {}
	for space: Dictionary in layout.get("spaces", []):
		spaces[str(space.id)] = true
	# V1's rows: whose object it is, what kind, which tell, which cases.
	var rows: Dictionary = {}
	for row: Dictionary in table.tells:
		if str(row.get("node", "")) == PREFIX + str(row.get("id", "")):
			rows[str(row.id)] = {"id": str(row.id), "unit": str(row.get("unit", "")), "kind": str(row.get("kind", "")),
				"tell": str(row.get("tell", "")), "cases": row.get("cases", []),
				"relay_all": bool(row.get("relay_all", false))}
	var holder := Node3D.new()
	holder.name = HOLDER
	blockout.add_child(holder)
	result.node = holder
	for place: Dictionary in placed.get("objects", []):
		var id := str(place.id)
		var row: Dictionary = rows.get(id, {})
		if row.is_empty() or str(row.unit) != str(place.unit):
			errors.append("%s: no tell row for this object in %s" % [id, place.unit])
			continue
		if not spaces.has(str(place.space)):
			errors.append("%s: unknown V2 space %s" % [id, place.space])
			continue
		var support := str(place.support)
		if not support.is_empty() and adapter.resolve(support) == null:
			errors.append("%s: support %s is not in the building" % [id, support])
			continue
		if native.mounting(str(place.stock)) != ("wall" if support.is_empty() else "table"):
			errors.append("%s: %s does not mount that way" % [id, place.stock])
			continue
		var prop := PossessedObject.new()
		prop.native = native
		prop.stock = str(place.stock)
		prop.unit = str(place.unit)
		prop.configure(row)
		prop.position = Native.vec(place.position)
		prop.rotation.y = deg_to_rad(float(place.yaw_deg))
		holder.add_child(prop)
		result.objects[id] = prop
	for bind: Dictionary in placed.get("bound", []):
		var id := str(bind.id)
		var target := adapter.resolve(str(bind.target)) as Node3D
		var row: Dictionary = rows.get(id, {})
		if row.is_empty() or str(row.unit) != str(bind.unit) or target == null \
				or not target.has_method("set_door_open") or not target.has_method("is_door_open"):
			errors.append("%s: %s cannot take this tell" % [id, bind.target])
			continue
		var hand := CabinetHand.new()
		hand.name = PREFIX + id
		hand.cabinet = target
		target.add_child(hand)
		# Stand the hand in front of the glass, so "watched" means the mirror.
		if target.has_method("mirror_center") and target.has_method("mirror_normal"):
			hand.global_position = target.mirror_center() + target.mirror_normal() * 0.06
		result.objects[id] = hand
	print("[V2 POSSESSED OBJECTS] %d household objects stand ready for their tells (errors: %s)" % [
			result.objects.size(), errors])
	return result
