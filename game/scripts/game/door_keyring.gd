class_name DoorKeyring
extends RefCounted
## Residents retain originals. Permission permits one spare at Keys Cut.
## DoorProp owns bolts/motion; RealityState owns storage. Who carries which
## key is PersonInventory's (design/ORISON_INVENTORIES_2026-10-25.md); this
## book keeps the permissions and the remembered locks, and answers doors from
## what people actually hold. `originals` and `copies` in book() are read from
## those holdings; saves from before carried keys (version 1) migrate on load.
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

## The player's own apartment, from the policy. Public so doors can tell the
## tenant's door from a neighbour's without hardcoding "4B".
static func player_unit() -> String:
	_sources()
	return str(_policy.player_unit)


## Resident id -> home unit, from the timetable.
static func residents() -> Dictionary:
	_sources()
	return _residents


static func valid(value: Variant) -> bool:
	_sources()
	if value is not Dictionary: return false
	var version: Variant = value.get("version")
	if typeof(version) not in [TYPE_INT,TYPE_FLOAT] or (version != 1 and version != 2): return false
	var fields := ["originals","permissions","copies","locks"] if version == 1 else ["permissions","locks"]
	for field in fields:
		if value.get(field) is not Dictionary: return false
	for field in fields.slice(0, fields.size() - 1):
		for id in value[field]:
			if id is not String or id.is_empty() or value[field][id] is not String or value[field][id].is_empty(): return false
	for id in value.locks:
		if id is not String or id.is_empty() or value.locks[id] is not bool: return false
	if version == 1 and value.originals != _residents: return false
	for unit in value.permissions:
		if _residents.get(value.permissions[unit], "") != unit or value.permissions[unit] not in _policy.copy_allowed_residents: return false
	if version == 1:
		for unit in value.copies:
			if value.permissions.get(unit, "") != value.copies[unit]: return false
	return true

static func book() -> Dictionary:
	_sources()
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"version":2,"permissions":{},"locks":{}}
	var stored: Variant = RealityState.data.get(KEY,{})
	if not valid(stored): return {}
	if int(stored.version) == 1:
		# Seed the holdings while the old spares are still readable, then keep
		# only what this book still owns.
		if PersonInventory.book().is_empty(): return {}
		stored = {"version":2,"permissions":stored.permissions,"locks":stored.locks}
		RealityState.data[KEY] = stored
	var originals := {}
	for resident: String in _residents:
		if PersonInventory.holds(resident, "key:" + str(_residents[resident])): originals[resident] = _residents[resident]
	var copies := {}
	var pocket := PersonInventory.items(PersonInventory.PLAYER)
	for id: String in pocket:
		if str(pocket[id].get("cut", "")) == "spare": copies[str(pocket[id].unit)] = str(pocket[id].get("from", ""))
	return {"version":2,"originals":originals,"permissions":stored.permissions,"copies":copies,"locks":stored.locks}

static func identity(door: Node) -> String:
	var id := str(door.get_meta("semantic_id", door.name)).trim_suffix("_Leaf")
	return "" if id.begins_with("@") else id

static func unit_for(door: Node) -> String:
	_sources()
	var unit := str(_door_units.get(identity(door),door.get("unit")))
	return unit if unit in _residents.values() or unit == _policy.player_unit else ""

static func resident_has_key(resident: String, door: Node) -> bool:
	if book().is_empty() or not _residents.has(resident): return false
	var unit := unit_for(door)
	return unit.is_empty() or PersonInventory.has_key(resident, unit)

static func player_has_key(door: Node) -> bool:
	if book().is_empty(): return false
	var unit := unit_for(door)
	return unit.is_empty() or PersonInventory.has_key(PersonInventory.PLAYER, unit)

## Two months behind, a tenant stops signing. A tenant whose case is enabled still signs,
## because rent must never close a case or anything the mystery needs. Every resident has a
## case definition, so it's the enabled flag that matters.
const RENT_MONTHS_BEHIND := 2
const RENT_REFUSAL := "Ask again when the rent is paid"

static func _behind_on_rent(resident: String) -> bool:
	var case_id := RealityCases.case_for_resident(resident)
	if case_id != "" and bool(RealityCases.definition(case_id).get("enabled", false)):
		return false
	var ledger: Variant = RealityState.data.get("caretaker_economy")
	if ledger is not Dictionary:
		return false
	var elapsed := CampaignClock.new().elapsed_minutes()
	var cycles := int((elapsed - float(ledger.started)) / 43200.0) - int(ledger.rent_paid)
	return cycles >= RENT_MONTHS_BEHIND

static func copy_prompt(resident: String) -> String:
	var value := book()
	if value.is_empty() or resident not in _policy.copy_allowed_residents: return ""
	if not value.permissions.has(_residents[resident]) and _behind_on_rent(resident): return RENT_REFUSAL
	return "Key copy authorized" if value.permissions.has(_residents[resident]) else "Ask permission for a spare key"

static func request_copy(resident: String) -> Dictionary:
	var value := book()
	if value.is_empty() or resident not in _policy.copy_allowed_residents or RealityState.save_write_blocked: return {}
	var unit: String = _residents[resident]
	if not value.permissions.has(unit) and _behind_on_rent(resident):
		return {"title":"KEY COPY REFUSED", "body":"%s WILL NOT SIGN WHILE THE RENT IS OWING." % resident.replace("_"," ").to_upper(), "condition":"RENT OWING", "stamp":"SERVICE NOTE"}
	if not value.permissions.has(unit):
		value.permissions[unit] = resident
		RealityState.commit()
	return {"title":"KEY COPY PERMISSION", "body":"%s agrees to a spare for %s. Take the permission to Keys Cut. The original stays with the resident." % [resident.replace("_"," ").capitalize(),unit], "stamp":"RESIDENT PERMISSION"}

static func make_copy(unit: String) -> bool:
	var value := book()
	if value.is_empty() or not value.permissions.has(unit) or value.copies.has(unit) or RealityState.save_write_blocked: return false
	return PersonInventory.give(PersonInventory.PLAYER, "key:%s:spare" % unit,
			{"kind":"key","unit":unit,"cut":"spare","from":value.permissions[unit]})


## Hand a spare back and withdraw the permission for it.
static func revoke_copy(unit: String) -> void:
	var value := book()
	if value.is_empty() or RealityState.save_write_blocked: return
	PersonInventory.take(PersonInventory.PLAYER, "key:%s:spare" % unit)
	value.permissions.erase(unit)
	RealityState.commit()

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
	lines.append_array(PersonInventory.pocket_lines())
	for unit: String in value.permissions:
		if not value.copies.has(unit): lines.append(unit+": copy authorized at Keys Cut")
	return lines
