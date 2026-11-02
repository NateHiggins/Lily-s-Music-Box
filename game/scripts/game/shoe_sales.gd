class_name ShoeSales
extends ShopSales
## The Shoe Rebuilding counter. Half soles are work, not goods: paying takes your boots off
## and sets them on the bench, where the hand sends them to the finisher. Nothing is carried,
## and there's no second pair of boots to resole while one is in the shop.

const KEY := "shoe_book"
const WORN := ["", "leather", "rubber"]
const SOLES := {"half_soles_leather": "leather", "half_soles_rubber": "rubber"}


static func book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"sole": "", "paid": "", "away": "", "ready": 0}
	return RealityState.data[KEY]


static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size() != 4:
		return false
	for key: String in ["sole", "paid", "away"]:
		if value.get(key) is not String or value[key] not in WORN:
			return false
	return typeof(value.get("ready")) in [TYPE_INT, TYPE_FLOAT]


## What is on your feet: your boots, or the borrowed slippers while they're in the shop.
static func footwear() -> String:
	var left := book()
	if str(left.paid) != "" or str(left.away) != "":
		return "slippers"
	return str(left.sole) if str(left.sole) != "" else "worn"


func transaction_status(item_id: String) -> String:
	if not SOLES.has(item_id):
		return super(item_id)
	if str(book().paid) != "" or str(book().away) != "":
		return "out_of_stock"
	var record := catalogue.item(shop_id, item_id)
	if record.is_empty():
		return "invalid_quote"
	return clearing.settlement_status(shop_id, int(record.cents))


func transact(item_id: String, shop: String) -> bool:
	if not SOLES.has(item_id):
		return super(item_id, shop)
	if shop != shop_id or transaction_status(item_id) != "available":
		return false
	var record := catalogue.item(shop_id, item_id)
	return clearing.settle_repeat(shop_id, item_id, int(record.cents), func():
		book().paid = SOLES[item_id]
		return true)


func listing() -> Array[String]:
	var out: Array[String] = []
	if only_groups.has("bench"):
		for item_id: String in SOLES:
			out.append(item_id)
	out.append_array(super())
	return out
