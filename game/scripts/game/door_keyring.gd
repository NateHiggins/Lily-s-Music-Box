class_name DoorKeyring
extends RefCounted
## Residents retain originals. Permission permits one spare at Keys Cut.
## DoorProp owns bolts/motion; RealityState owns storage.
const KEY := "door_keys"
const POLICY := "res://data/door_key_policy.json"
static var _policy: Dictionary = {}
static var _residents: Dictionary = {}
static var _door_units: Dictionary = {}

static func _sources() -> void:
	if not _policy.is_empty(): return
	_policy = JSON.parse_string(FileAccess.get_file_as_string(POLICY))
	assert(_policy.schema_version == 1 and _policy.player_unit is String
			and _policy.copy_allowed_residents is Array and _policy.v2_initial_states is Array)
	var schedules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/resident_schedules.json"))
	for id: String in schedules.residents: _residents[id] = str(schedules.residents[id].unit)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json"))
	var spaces := {}
	for room: Dictionary in layout.spaces:
		var parts := str(room.id).split("_")
		var unit := str(room.get("unit", ""))
		if unit.is_empty() and parts.size() >= 3 and parts[0].begins_with("F0") and parts[1] in ["A","B","C","D"]:
			unit = parts[0].trim_prefix("F0") + parts[1]
		spaces[room.id] = unit
	for door: Dictionary in layout.doors:
		for room: String in door.connects:
			if not str(spaces.get(room, "")).is_empty(): _door_units[door.id] = spaces[room]
	for id in _policy.copy_allowed_residents: assert(_residents.has(id))
	for door: Dictionary in _policy.v2_initial_states:
		assert(door.door_id is String and door.leaf_state in ["closed","open","locked"])

static func valid(value: Variant) -> bool:
	_sources()
	if value is not Dictionary or value.get("version") != 1: return false
	for field in ["originals","permissions","copies","locks"]:
		if value.get(field) is not Dictionary: return false
	for field in ["originals","permissions","copies"]:
		for id in value[field]:
			if id is not String or id.is_empty() or value[field][id] is not String or value[field][id].is_empty(): return false
	for id in value.locks:
		if id is not String or id.is_empty() or value.locks[id] is not bool: return false
	if value.originals != _residents: return false
	for unit in value.permissions:
		if _residents.get(value.permissions[unit], "") != unit or value.permissions[unit] not in _policy.copy_allowed_residents: return false
	for unit in value.copies:
		if value.permissions.get(unit, "") != value.copies[unit]: return false
	return true

static func book() -> Dictionary:
	_sources()
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"version":1,"originals":_residents.duplicate(),"permissions":{},"copies":{},"locks":{}}
	var value: Variant = RealityState.data.get(KEY,{})
	if not valid(value): return {}
	return value

static func identity(door: Node) -> String:
	var id := str(door.get_meta("semantic_id", door.name)).trim_suffix("_Leaf")
	return "" if id.begins_with("@") else id

static func unit_for(door: Node) -> String:
	_sources()
	var unit := str(_door_units.get(identity(door),door.get("unit")))
	return unit if unit in _residents.values() or unit == _policy.player_unit else ""

static func resident_has_key(resident: String, door: Node) -> bool:
	var value := book()
	if value.is_empty() or not value.originals.has(resident): return false
	var unit := unit_for(door)
	return unit.is_empty() or value.originals[resident] == unit

static func player_has_key(door: Node) -> bool:
	var value := book()
	if value.is_empty(): return false
	var unit := unit_for(door)
	return unit.is_empty() or unit == _policy.player_unit or value.copies.has(unit)

static func copy_prompt(resident: String) -> String:
	var value := book()
	if value.is_empty() or resident not in _policy.copy_allowed_residents: return ""
	return "Key copy authorized" if value.permissions.has(_residents[resident]) else "Ask permission for a spare key"

static func request_copy(resident: String) -> Dictionary:
	var value := book()
	if value.is_empty() or resident not in _policy.copy_allowed_residents or RealityState.save_write_blocked: return {}
	var unit: String = _residents[resident]
	if not value.permissions.has(unit):
		value.permissions[unit] = resident
		RealityState.commit()
	return {"title":"KEY COPY PERMISSION", "body":"%s agrees to a spare for %s. Take the permission to Keys Cut. The original stays with the resident." % [resident.replace("_"," ").capitalize(),unit], "stamp":"RESIDENT PERMISSION"}

static func make_copy(unit: String) -> bool:
	var value := book()
	if value.is_empty() or not value.permissions.has(unit) or value.copies.has(unit) or RealityState.save_write_blocked: return false
	value.copies[unit] = value.permissions[unit]
	RealityState.commit()
	return true

static func initial_state(door: Node, authored: String) -> String:
	var value := book()
	var id := identity(door)
	if not value.is_empty() and value.locks.has(id): return "locked" if value.locks[id] else "closed"
	var ancestor := door.get_parent()
	while ancestor:
		if ancestor.is_in_group("orison_v2_runtime"):
			for door_state: Dictionary in _policy.v2_initial_states:
				if str(door_state.door_id) == id: return str(door_state.leaf_state)
			return authored
		ancestor = ancestor.get_parent()
	return authored

static func remember_lock(door: Node, locked: bool) -> void:
	var value := book()
	var id := identity(door)
	if value.is_empty() or id.is_empty() or RealityState.save_write_blocked: return
	value.locks[id] = locked
	RealityState.commit()

static func pocket_lines() -> Array[String]:
	var value := book()
	var lines: Array[String] = []
	if value.is_empty(): return lines
	lines.append("KEY RING: house service / "+str(_policy.player_unit))
	for unit: String in value.permissions:
		lines.append(unit+": spare held" if value.copies.has(unit) else unit+": copy authorized at Keys Cut")
	return lines
