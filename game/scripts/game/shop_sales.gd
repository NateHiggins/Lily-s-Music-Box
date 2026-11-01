class_name ShopSales
extends RefCounted
## One shop's counter: answers a radio_sale_terminal the way the maintenance
## service does. It holds no money, stock or goods of its own. The radio network
## authorizes, CaretakerEconomy debits, ShopStock counts and PersonInventory
## carries, and a failed delivery undoes all of them together.

var shop_id := ""
var catalogue: ShopCatalogue
var stock: ShopStock
var clearing: RefCounted
## A shop with two points of sale keeps these groups off this one's list, or only these.
var skip_groups: Array[String] = []
var only_groups: Array[String] = []


func _init(shop: String, shops: ShopCatalogue, levels: ShopStock, network: RefCounted) -> void:
	shop_id = shop
	catalogue = shops
	stock = levels
	clearing = network


## What the counter's selector walks, in order.
func listing() -> Array[String]:
	var out: Array[String] = []
	for record: Dictionary in catalogue.counter_items(shop_id):
		var group := str(record.get("group", ""))
		if group in skip_groups or (not only_groups.is_empty() and group not in only_groups):
			continue
		out.append(str(record.id))
	return out


func stock_record(item_id: String) -> Dictionary:
	var record: Dictionary = catalogue.item(shop_id, item_id).duplicate()
	if record.is_empty():
		return {}
	record["shop_id"] = shop_id
	record["display_name"] = str(record.name)
	record["price_cents"] = int(record.cents)
	return record


## Nothing locks a repeatable sale at the grip; refusals come from the stroke.
func sale_locked(_item_id: String) -> bool:
	return false


func transaction_status(item_id: String) -> String:
	var record := catalogue.item(shop_id, item_id)
	if record.is_empty() or str(record.kind) not in ShopCatalogue.COUNTER_KINDS:
		return "invalid_quote"
	if str(record.kind) == "post":
		if MailOrders.posted(str(record.order)):
			return "already_posted"
		if not MailOrders.torn(str(record.order)):
			return "no_coupon"
		return clearing.settlement_status(shop_id, int(record.cents))
	if record.has("group") and stock.units(shop_id, str(record.group)) < 1.0:
		return "out_of_stock"
	if str(record.kind) not in ["consumed", "grocery"] and str(record.get("sold_by", "")) != "rack" and not PersonInventory.can_carry_goods(PersonInventory.PLAYER, item_id, str(record.get("form", "packet"))):
		return "case_full"
	return clearing.settlement_status(shop_id, int(record.cents))


func transact(item_id: String, shop: String) -> bool:
	if shop != shop_id or transaction_status(item_id) != "available":
		return false
	var record := catalogue.item(shop_id, item_id)
	return clearing.settle_repeat(shop_id, item_id, int(record.cents), func(): return _deliver(record))


func _deliver(record: Dictionary) -> bool:
	if str(record.kind) == "post":
		return MailOrders.post(str(record.order))
	var group := str(record.get("group", ""))
	if group != "" and not stock.take(shop_id, group):
		return false
	if str(record.kind) == "grocery":
		PersonInventory.carry(PersonInventory.PLAYER, str(record.grocery), float(record.pack))
		return true
	if str(record.kind) == "consumed" or str(record.get("sold_by", "")) == "rack" or PersonInventory.carry_goods(PersonInventory.PLAYER, str(record.id), str(record.name), str(record.get("form", "packet"))):
		return true
	if group != "":
		stock.put_back(shop_id, group)
	return false
