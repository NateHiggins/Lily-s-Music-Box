class_name KeysSales
extends ShopSales
## The Keys Cut counter. A tenant's permission puts a spare on the list; paying for it
## readies a blank at the cutter, where the hand cuts it. DoorKeyring still owns every
## permission and copy. This owns only which blanks are paid for and waiting.

const KEY := "keys_book"
const SPARE_PREFIX := "spare_"
const SPARE_CENTS := 25


static func book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"paid": {}}
	return RealityState.data[KEY]


static func valid(value: Variant) -> bool:
	return value is Dictionary and value.get("paid") is Dictionary


## The units paid for and not yet cut, sorted so the cutter takes them in order.
static func waiting() -> Array:
	var units: Array = book().paid.keys()
	units.sort()
	return units


func listing() -> Array[String]:
	var out: Array[String] = []
	var keys := DoorKeyring.book()
	var units: Array = keys.get("permissions", {}).keys()
	units.sort()
	for unit: String in units:
		if not keys.copies.has(unit) and not book().paid.has(unit):
			out.append(SPARE_PREFIX + unit)
	out.append_array(super())
	return out


func stock_record(item_id: String) -> Dictionary:
	if item_id.begins_with(SPARE_PREFIX):
		return {"id": item_id, "shop_id": shop_id, "display_name": "Spare for " + item_id.trim_prefix(SPARE_PREFIX),
			"price_cents": SPARE_CENTS}
	return super(item_id)


func transaction_status(item_id: String) -> String:
	if item_id.begins_with(SPARE_PREFIX):
		var unit := item_id.trim_prefix(SPARE_PREFIX)
		var keys := DoorKeyring.book()
		if not keys.get("permissions", {}).has(unit) or keys.get("copies", {}).has(unit) or book().paid.has(unit):
			return "invalid_quote"
		return clearing.settlement_status(shop_id, SPARE_CENTS)
	return super(item_id)


func transact(item_id: String, shop: String) -> bool:
	if not item_id.begins_with(SPARE_PREFIX):
		return super(item_id, shop)
	if shop != shop_id or transaction_status(item_id) != "available":
		return false
	var unit := item_id.trim_prefix(SPARE_PREFIX)
	return clearing.settle_repeat(shop_id, item_id, SPARE_CENTS, func():
		book().paid[unit] = true
		return true)
