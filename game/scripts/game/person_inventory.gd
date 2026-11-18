class_name PersonInventory
extends RefCounted
## What each person in the house is carrying (design/ORISON_INVENTORIES_2026-10-25.md):
## the player, every resident and every staff member, keyed by holder id.
## One save domain, `RealityState.data.inventories`.
##
##   keys       "key:<unit>" is a resident's original; "key:<unit>:spare" is a
##              spare cut at Keys Cut, carried by the player, `from` the
##              resident who permitted it; "key:house" is the house-service
##              ring. DoorKeyring answers every door from these holdings.
##   groceries  "grocery:<item>" with a quantity: bought at a counter, carried
##              home, unpacked into the household larder (KitchenLarder).
##   goods      "goods:<item>" with a whole count: bought for the player's own
##              use, stacked and capped. The player's lie in CarriedCase.
##
## Maintenance parts are not held here: MaintenanceInventory remains their
## single-use authority. `holdings()` shows the player's unconsumed parts
## beside what they carry, read straight from it.

const KEY := "inventories"
const PLAYER := "player"
const HOUSE_KEY := "key:house"
const GOODS_STACK := 12
const BASS := "object:3C_bass"
const OBJECTS_VERSION := "objects_version"
static var _staff_ids: Array = []

static func _bass_record() -> Dictionary:
	return {"kind":"object","object":"3C_bass","name":"Upright bass","location":"inventory"}

static func _migrate_objects(value: Dictionary) -> void:
	if value.has(OBJECTS_VERSION):return
	if not value.holders.has("lily"):value.holders.lily={}
	value.holders.lily[BASS]=_bass_record()
	value[OBJECTS_VERSION]=1



## The domain, seeded on first use: every resident carries their original,
## the player the house ring and their own door's key, and any spare an older
## save recorded in `door_keys.copies` moves into the player's pocket.
static func book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = _seeded()
	var value: Variant = RealityState.data[KEY]
	if not valid(value):return {}
	_migrate_objects(value)
	_ensure_staff_holders(value.holders)
	return value


## Staff belong to the timetable but have no apartment keys. Fill their
## records on lookup for new and older saves, preserving any existing stock.
static func _ensure_staff_holders(holders: Dictionary) -> void:
	if _staff_ids.is_empty():
		var timetable: Variant = JSON.parse_string(FileAccess.get_file_as_string(ScheduleDirector.SCHEDULE_PATH))
		if timetable is not Dictionary or timetable.get("staff") is not Dictionary:
			return
		_staff_ids = timetable.staff.keys()
	for id: String in _staff_ids:
		if not holders.has(id):
			holders[id] = {}


static func _seeded() -> Dictionary:
	var holders := {PLAYER: {HOUSE_KEY: {"kind": "key", "unit": "", "cut": "house"}}}
	var own := DoorKeyring.player_unit()
	holders[PLAYER]["key:" + own] = {"kind": "key", "unit": own, "cut": "original"}
	for resident: String in DoorKeyring.residents():
		var unit := str(DoorKeyring.residents()[resident])
		holders[resident] = {"key:" + unit: {"kind": "key", "unit": unit, "cut": "original"}}
	var legacy: Variant = RealityState.data.get(DoorKeyring.KEY, {})
	if legacy is Dictionary and (legacy as Dictionary).get("copies") is Dictionary:
		for unit: String in legacy.copies:
			holders[PLAYER]["key:%s:spare" % unit] = {"kind": "key", "unit": unit, "cut": "spare",
					"from": str(legacy.copies[unit])}
	var seeded := {"version": 1, "holders": holders}
	_migrate_objects(seeded)
	return seeded


static func valid(value: Variant) -> bool:
	if value is not Dictionary or typeof((value as Dictionary).get("version")) not in [TYPE_INT, TYPE_FLOAT] \
			or float(value.version) != 1.0 \
			or (value as Dictionary).get("holders") is not Dictionary:
		return false
	var objects := 0
	if value.has(OBJECTS_VERSION) and (typeof(value[OBJECTS_VERSION]) not in [TYPE_INT,TYPE_FLOAT] or float(value[OBJECTS_VERSION])!=1.0):return false
	for holder: Variant in value.holders:
		if holder is not String or str(holder).is_empty() or value.holders[holder] is not Dictionary:
			return false
		for id: Variant in value.holders[holder]:
			var item: Variant = value.holders[holder][id]
			if id is not String or item is not Dictionary or str(item.get("kind", "")) not in ["key", "grocery", "goods", "object"]:
				return false
			if id==BASS and item.kind!="object":return false
			if item.kind == "object":
				if not value.has(OBJECTS_VERSION) or id!=BASS or item.size()!=4 or item.get("object")!="3C_bass" or item.get("name")!="Upright bass" or item.get("location") not in ["inventory","home"]:return false
				objects+=1
			if item.kind == "key" and (item.get("unit") is not String or str(item.get("cut", "")) not in ["original", "spare", "house"]):
				return false
			if item.kind == "grocery" and (typeof(item.get("qty")) not in [TYPE_INT, TYPE_FLOAT] or float(item.qty) <= 0.0):
				return false
			if item.kind == "goods" and (typeof(item.get("qty")) not in [TYPE_INT, TYPE_FLOAT] \
					or float(item.qty) < 1.0 or float(item.qty) > GOODS_STACK or float(item.qty) != floor(float(item.qty)) \
					or item.get("item") is not String or item.get("name") is not String):
				return false
	if value.has(OBJECTS_VERSION) and objects!=1:return false
	# Nobody has lost their own key.
	var residents := DoorKeyring.residents()
	for resident: String in residents:
		if not value.holders.get(resident, {}).has("key:" + str(residents[resident])):
			return false
	return true


## Every spare the player carries was permitted, by the resident it names.
static func consistent(value: Dictionary, keys: Dictionary) -> bool:
	var permissions: Dictionary = keys.get("permissions", {})
	var pocket: Dictionary = value.get("holders", {}).get(PLAYER, {})
	for id: String in pocket:
		if str(pocket[id].get("cut", "")) == "spare" \
				and str(permissions.get(str(pocket[id].unit), "")) != str(pocket[id].get("from", "-")):
			return false
	return true


## ---- holding --------------------------------------------------------

static func items(holder: String) -> Dictionary:
	var value := book()
	return value.get("holders", {}).get(holder, {})


static func holds(holder: String, id: String) -> bool:
	return items(holder).has(id)


## Does this person carry a key that opens `unit`: their original, or a spare.
static func has_key(holder: String, unit: String) -> bool:
	var held := items(holder)
	return held.has("key:" + unit) or held.has("key:%s:spare" % unit)


static func give(holder: String, id: String, record: Dictionary) -> bool:
	var value := book()
	if value.is_empty() or RealityState.save_write_blocked or holder.is_empty() or id==BASS or record.get("kind")=="object":
		return false
	if not value.holders.has(holder):
		value.holders[holder] = {}
	if value.holders[holder].has(id):
		return false
	value.holders[holder][id] = record.duplicate(true)
	RealityState.commit()
	return true


static func take(holder: String, id: String) -> Dictionary:
	var value := book()
	if value.is_empty() or RealityState.save_write_blocked or id==BASS or not items(holder).has(id):
		return {}
	var record: Dictionary = value.holders[holder][id]
	value.holders[holder].erase(id)
	RealityState.commit()
	return record


## Hand a carried thing from one person to another; refuses if the giver has
## no such thing or the taker already carries one.
static func hand_over(giver: String, taker: String, id: String) -> bool:
	if id==BASS:
		var value:=book()
		if value.is_empty() or RealityState.save_write_blocked or taker.is_empty() or not holds(giver,id) or holds(taker,id):return false
		var candidate: Dictionary=value.duplicate(true)
		var record: Dictionary=candidate.holders[giver][id]
		if record.location!="inventory":return false
		candidate.holders[giver].erase(id)
		if not candidate.holders.has(taker):candidate.holders[taker]={}
		candidate.holders[taker][id]=record
		if not valid(candidate):return false
		RealityState.data[KEY]=candidate
		RealityState.commit()
		return true
	if not holds(giver, id) or holds(taker, id):
		return false
	return give(taker, id, take(giver, id))


## ---- groceries -------------------------------------------------------

static func carry(holder: String, item: String, amount: float) -> void:
	var value := book()
	if value.is_empty() or RealityState.save_write_blocked or amount <= 0.0:
		return
	if not value.holders.has(holder):
		value.holders[holder] = {}
	var id := "grocery:" + item
	var record: Dictionary = value.holders[holder].get(id, {"kind": "grocery", "item": item, "qty": 0.0})
	record.qty = float(record.qty) + amount
	value.holders[holder][id] = record
	RealityState.commit()


## Taking groceries back out of a bag; a spent line leaves it.
static func lose(holder: String, item: String, amount: float) -> void:
	var value := book()
	var id := "grocery:" + item
	if value.is_empty() or RealityState.save_write_blocked or not items(holder).has(id):
		return
	var left := float(value.holders[holder][id].qty) - amount
	if left <= 0.0001:
		value.holders[holder].erase(id)
	else:
		value.holders[holder][id].qty = left
	RealityState.commit()


static func carried(holder: String, item: String) -> float:
	return float(items(holder).get("grocery:" + item, {}).get("qty", 0.0))


## Everything bought and not yet put away: item -> amount. Empties the bag.
static func unpack(holder: String) -> Dictionary:
	var value := book()
	var out := {}
	if value.is_empty() or RealityState.save_write_blocked:
		return out
	for id: String in items(holder).keys():
		var record: Dictionary = value.holders[holder][id]
		if str(record.kind) == "grocery":
			out[str(record.item)] = float(record.qty)
			value.holders[holder].erase(id)
	if not out.is_empty():
		RealityState.commit()
	return out


## ---- goods -----------------------------------------------------------

static func goods_count(holder: String, item: String) -> int:
	return int(items(holder).get("goods:" + item, {}).get("qty", 0))


static func can_carry_goods(holder: String, item: String, form := "packet") -> bool:
	var count := goods_count(holder, item)
	if count > 0:
		return count < GOODS_STACK
	return holder != PLAYER or CarriedCase.has_room(item, form)


## Uncommitted: a sale's settlement saves the debit and the goods together.
static func carry_goods(holder: String, item: String, shown_name: String, form := "packet") -> bool:
	var value := book()
	if value.is_empty() or RealityState.save_write_blocked or not can_carry_goods(holder, item, form):
		return false
	if holder == PLAYER and not CarriedCase.place_new(item, form):
		return false
	if not value.holders.has(holder):
		value.holders[holder] = {}
	var id := "goods:" + item
	var record: Dictionary = value.holders[holder].get(id, {"kind": "goods", "item": item, "name": shown_name, "form": form, "qty": 0})
	record.qty = int(record.qty) + 1
	value.holders[holder][id] = record
	return true


static func spend_goods(holder: String, item: String) -> bool:
	var value := book()
	var count := goods_count(holder, item)
	if value.is_empty() or RealityState.save_write_blocked or count <= 0:
		return false
	if count == 1:
		value.holders[holder].erase("goods:" + item)
		if holder == PLAYER:
			CarriedCase.remove(item)
	else:
		value.holders[holder]["goods:" + item].qty = count - 1
	RealityState.commit()
	return true


## ---- the player's pocket --------------------------------------------

## The player's holdings as lines: the house ring, their own key, spares
## and whose they are, what is being carried, and unconsumed parts.
static func pocket_lines(holder: String = PLAYER) -> Array[String]:
	var lines: Array[String] = []
	var held := items(holder)
	var keys: Array[String] = []
	if held.has(HOUSE_KEY):
		keys.append("house service")
	var ids := held.keys()
	ids.sort()
	for id: String in ids:
		var record: Dictionary = held[id]
		if str(record.kind) != "key" or id == HOUSE_KEY:
			continue
		keys.append(str(record.unit) if str(record.cut) == "original"
				else "%s spare (%s's)" % [record.unit, str(record.get("from", "")).replace("_", " ").capitalize()])
	if not keys.is_empty():
		lines.append("KEY RING: " + " / ".join(keys))
	for id: String in ids:
		var record: Dictionary = held[id]
		if str(record.kind) == "grocery":
			lines.append("CARRYING: %s %s" % [str(snappedf(float(record.qty), 0.01)), str(record.item).replace("_", " ")])
		elif str(record.kind) == "goods":
			lines.append("POCKET: %d %s" % [int(record.qty), str(record.name)])
	if holder != PLAYER:
		return lines
	var parts: Dictionary = RealityState.data.get("maintenance_items", {})
	var names := parts.keys()
	names.sort()
	for part: String in names:
		if parts[part] is Dictionary and not bool(parts[part].get("consumed", true)):
			lines.append("PART: " + part.replace("_", " "))
	return lines

## Unique personal objects use the same inventory/save authority, without bodies in transit.
static func object_holder(id: String=BASS) -> String:
	if id!=BASS:return ""
	var value:=book()
	for holder: String in value.get("holders",{}):
		if value.holders[holder].has(id):return holder
	return ""

static func object_location(id: String=BASS) -> String:
	return str(items(object_holder(id)).get(id,{}).get("location",""))

static func set_object_location(holder: String, location: String, id: String=BASS) -> bool:
	if id!=BASS or location not in ["inventory","home"] or RealityState.save_write_blocked or not holds(holder,id):return false
	items(holder)[id].location=location
	RealityState.commit()
	return true

static func object_lines(holder: String) -> Array[String]:
	var lines: Array[String]=[]
	var held := items(holder)
	for id: String in held:
		var row: Dictionary = held[id]
		if row.kind=="object":lines.append(str(row.name)+(" (put away at home)" if row.location=="home" else ""))
	return lines
