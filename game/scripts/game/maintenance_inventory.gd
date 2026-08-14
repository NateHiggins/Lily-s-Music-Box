class_name MaintenanceInventory
extends Node
## Owns the acquired/consumed facts for maintenance parts and tools. Nothing
## else: no stacking, no currency, no general item framework. An item id is
## granted at most once per campaign and consumed at most once — deterministic
## single use, so a duplicate signal or repeated interaction cannot mint a
## second part or spend the same one twice.
##
## State lives in `RealityState.data.maintenance_items` and is therefore
## saved on every commit; `serialize`/`restore` expose the same pure-fact
## contract WorkOrders offers for the K4 persistence wiring.

signal part_acquired(item_id: String, shop_id: String)
signal part_consumed(item_id: String)


func setup() -> void:
	if not RealityState.data.has("maintenance_items"):
		RealityState.data.maintenance_items = {}


func grant(item_id: String, shop_id: String) -> bool:
	if item_id.is_empty() or shop_id.is_empty():
		return false
	var items := _items()
	if items.has(item_id):
		return false
	items[item_id] = {
		"shop_id": shop_id, "consumed": false,
		"acquired_at": Time.get_unix_time_from_system(),
	}
	RealityState.commit()
	part_acquired.emit(item_id, shop_id)
	return true


func consume(item_id: String) -> bool:
	var items := _items()
	if not items.has(item_id) or bool(items[item_id].consumed):
		return false
	items[item_id].consumed = true
	items[item_id].consumed_at = Time.get_unix_time_from_system()
	RealityState.commit()
	part_consumed.emit(item_id)
	return true


func has_item(item_id: String) -> bool:
	var items := _items()
	return items.has(item_id) and not bool(items[item_id].consumed)


func is_consumed(item_id: String) -> bool:
	var items := _items()
	return items.has(item_id) and bool(items[item_id].consumed)


func item_state(item_id: String) -> Dictionary:
	return _items().get(item_id, {}).duplicate(true)


func serialize() -> Dictionary:
	return {"items": _items().duplicate(true)}


func restore(payload: Dictionary) -> bool:
	var incoming: Variant = payload.get("items")
	if incoming is not Dictionary:
		return false
	for item_id in incoming:
		var record: Variant = incoming[item_id]
		if str(item_id).is_empty() or record is not Dictionary:
			return false
		if str((record as Dictionary).get("shop_id", "")).is_empty():
			return false
		if (record as Dictionary).get("consumed") is not bool:
			return false
	RealityState.data.maintenance_items = (incoming as Dictionary).duplicate(true)
	RealityState.commit()
	return true


func _items() -> Dictionary:
	if not RealityState.data.has("maintenance_items"):
		RealityState.data.maintenance_items = {}
	return RealityState.data.maintenance_items
