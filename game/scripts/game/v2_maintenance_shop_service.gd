extends MaintenanceShopService
## Optional service supplies use the existing saved inventory. Unlike a part
## requisition, buying these does not fabricate or advance a work order.
const SUPPLIES_PATH := "res://data/orison_v2/fire_maintenance_stock.json"
const SUPPLY_KINDS := {"fire_hose_rubber_protectant":"tool","fire_hose_spare_gasket":"part"}
var _supplies: Dictionary = {}
var clearing: RefCounted

func setup(items: MaintenanceInventory, orders: WorkOrders,
		path := STOCK_PATH) -> void:
	_supplies.clear()
	super.setup(items, orders, path)
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(SUPPLIES_PATH))
	if decoded is not Dictionary or int(decoded.get("schema_version",0))!=SCHEMA_VERSION:
		errors.append("fire maintenance stock is not a dictionary")
		return
	var original: Dictionary = stock.duplicate(true)
	_validate(decoded)
	if not is_valid():
		stock = original
		return
	for item_id: String in decoded.stock:
		var record: Dictionary=decoded.stock[item_id]
		# This optional catalogue is deliberately narrower than requisitions.
		# Keep provenance, physical anchor and price on the authored item.
		if str(record.get("shop_id",""))!="hardware_paint" \
				or str(record.get("counter_anchor_id",""))!="storm_shop_hardware_paint_counter_top" \
				or not SUPPLY_KINDS.has(item_id) or record.get("kind")!=SUPPLY_KINDS.get(item_id) \
				or record.get("acquisition_verb")!="buy" \
				or str(record.get("display_name","")).is_empty() \
				or str(record.get("provenance","")).is_empty() \
				or not preload("res://scripts/game/caretaker_economy.gd").whole(record.get("price_cents"),1):
			errors.append("invalid optional supply: "+item_id)
			stock=original;_supplies.clear();return
		if original.has(item_id):
			errors.append("supply duplicates requisition stock: " + item_id)
			stock = original
			_supplies.clear()
			return
		_supplies[item_id] = true

func supply_ids() -> Array[String]:
	var ids: Array[String] = []
	for item_id: String in _supplies: ids.append(item_id)
	ids.sort()
	return ids

func can_purchase_supply(item_id: String, shop_id: String) -> bool:
	return is_valid() and inventory != null and _supplies.has(item_id) \
			and str(stock[item_id].shop_id) == shop_id \
			and inventory.item_state(item_id).is_empty()

func purchase_supply(item_id: String, shop_id: String) -> bool:
	if not can_purchase_supply(item_id, shop_id): return false
	if clearing==null:return false
	return clearing.settle("maintenance_supply:"+item_id,shop_id,item_id,int(stock[item_id].price_cents),
		func():return inventory.grant(item_id,shop_id))

func transact(item_id: String, shop_id: String) -> bool:
	return purchase_supply(item_id,shop_id) if _supplies.has(item_id) else acquire(item_id,shop_id)

func transaction_status(item_id: String) -> String:
	if inventory==null or not stock.has(item_id):return "invalid_quote"
	if not inventory.item_state(item_id).is_empty():return "owned"
	if not _supplies.has(item_id) and (work_orders==null or work_orders.jobs_awaiting_part(item_id).is_empty()):return "awaiting_order"
	if clearing==null:return "no_carrier"
	return clearing.settlement_status(str(stock[item_id].shop_id),int(stock[item_id].get("price_cents",0)))

func acquire(item_id: String, shop_id: String) -> bool:
	if clearing==null or inventory==null or work_orders==null \
			or _supplies.has(item_id) or not stock.has(item_id) \
			or str(stock[item_id].shop_id)!=shop_id \
			or work_orders.jobs_awaiting_part(item_id).is_empty() \
			or not inventory.item_state(item_id).is_empty():return false
	# An approved requisition is charged to the building account, not the
	# caretaker's pocket. Its zero-debit receipt still requires a live radio.
	return clearing.settle("requisition:"+item_id,shop_id,item_id,0,
		func():return _deliver_requisition(item_id,shop_id))

func _deliver_requisition(item_id: String, shop_id: String) -> bool:
	return super.acquire(item_id,shop_id)

func _new_semantic_counter(shop_id: String, physical_label: String) -> MaintenanceShopCounter:
	var point:=super._new_semantic_counter(shop_id,physical_label)
	# Keep its public identity/lifetime, while exact native terminal parts
	# replace the old counter-wide click volume in V2.
	point.collision_layer=0;point.collision_mask=0
	return point
