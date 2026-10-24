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
