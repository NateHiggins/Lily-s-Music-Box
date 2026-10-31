class_name ShopCatalogue
extends RefCounted
## What each shop sells, its stock groups and its dated pressures
## (design/V2_SHOP_OVERHAUL_PROPOSAL_2026-10-30.md). Read-only authored data:
## money stays with CaretakerEconomy, carried goods with PersonInventory, and
## levels with ShopStock. A grocery link keeps a price the residents already pay.

## Literal paths, not a directory scan, so the reader gate can see each file.
const PATHS: Array[String] = [
	"res://data/shops/bodega.json",
	"res://data/shops/funeral_parlour.json",
	"res://data/shops/hardware_paint.json",
	"res://data/shops/harukiya.json",
	"res://data/shops/keys_cut.json",
	"res://data/shops/luncheonette.json",
	"res://data/shops/model_laundry.json",
	"res://data/shops/news_cigars.json",
	"res://data/shops/otis_son.json",
	"res://data/shops/pawnbroker.json",
	"res://data/shops/photo_supplies.json",
	"res://data/shops/radio_service.json",
	"res://data/shops/shoe_rebuilding.json",
]
const GROCERIES_PATH := "res://data/kitchen/groceries.json"
const KINDS := ["goods", "consumed", "part", "service", "upgrade", "loan", "wager", "grocery"]
const COUNTER_KINDS := ["goods", "consumed", "part", "grocery"]
const SOURCES := ["live", "ad", "authored"]

var shops: Dictionary = {}
var errors: Array[String] = []


func load_all() -> bool:
	shops.clear()
	errors.clear()
	var groceries: Variant = JSON.parse_string(FileAccess.get_file_as_string(GROCERIES_PATH))
	var ingredients: Dictionary = groceries.get("ingredients", {}) if groceries is Dictionary else {}
	for path in PATHS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is not Dictionary or int(parsed.get("schema_version", 0)) != 1:
			errors.append("shop catalogue unreadable: %s" % path)
			continue
		if _valid(parsed, path, ingredients):
			shops[str(parsed.shop_id)] = parsed
			if bool(parsed.get("sells_groceries", false)):
				_add_groceries(parsed, ingredients)
	return errors.is_empty()


## A shop that sells groceries sells the residents' own list, at their prices,
## filed by how each is kept.
func _add_groceries(shop: Dictionary, ingredients: Dictionary) -> void:
	var linked := {}
	for record: Dictionary in shop.items:
		if record.has("grocery"):
			linked[str(record.grocery)] = true
	var ids := ingredients.keys()
	ids.sort()
	for grocery: String in ids:
		var row: Dictionary = ingredients[grocery]
		if str(row.shop) != str(shop.shop_id) or linked.has(grocery):
			continue
		if not shop.groups.has(str(row.storage)):
			errors.append("%s has no stock group for %s" % [shop.shop_id, row.storage])
			continue
		shop.items.append({"id": grocery, "name": str(row.name), "cents": int(row.cents), "kind": "grocery",
			"source": "live", "group": str(row.storage), "grocery": grocery, "pack": float(row.pack)})


## What the counter itself sells, in catalogue order. The news rack sells papers.
func counter_items(shop_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for record: Dictionary in shops.get(shop_id, {}).get("items", []):
		if str(record.kind) in COUNTER_KINDS and str(record.get("sold_by", "counter")) == "counter":
			out.append(record)
	return out


func shop_ids() -> Array:
	var ids := shops.keys()
	ids.sort()
	return ids


func item(shop_id: String, item_id: String) -> Dictionary:
	for record: Dictionary in shops.get(shop_id, {}).get("items", []):
		if str(record.id) == item_id:
			return record
	return {}


## Whether the shop keeps a counter open at this minute of the day.
func open_at(shop_id: String, minute_of_day: int) -> bool:
	var shop: Dictionary = shops.get(shop_id, {})
	if shop.is_empty():
		return false
	var closed: Array = shop.closed
	return closed.is_empty() or minute_of_day < int(closed[0]) or minute_of_day >= int(closed[1])


func _valid(doc: Dictionary, path: String, ingredients: Dictionary) -> bool:
	var before := errors.size()
	var fail := func(message: String) -> void:
		errors.append("%s: %s" % [path, message])
	if str(doc.get("shop_id", "")) == "" or str(doc.get("name", "")) == "":
		fail.call("no shop_id or name")
	if doc.get("closed") is not Array or doc.closed.size() not in [0, 2]:
		fail.call("closed is not empty or a pair")
	var groups: Variant = doc.get("groups")
	if groups is not Dictionary:
		fail.call("groups is not a dictionary")
		return false
	for group_id: String in groups:
		var group: Dictionary = groups[group_id]
		var delivery: Variant = group.get("delivery")
		if float(group.get("capacity", 0)) <= 0.0 or float(group.get("per_day", -1)) < 0.0 \
				or delivery is not Dictionary or float(delivery.get("every_days", 0)) <= 0.0 \
				or float(delivery.get("units", 0)) <= 0.0 \
				or int(delivery.get("at_minute", -1)) not in range(0, 1440):
			fail.call("group %s has bad capacity, demand or delivery" % group_id)
	for event: Variant in doc.get("events", []):
		if event is not Dictionary or not groups.has(str(event.get("group", ""))) \
				or str(event.get("from", "")) == "" or str(event.get("from", "")) > str(event.get("until", "")) \
				or float(event.get("factor", -1)) < 0.0 or str(event.get("why", "")) == "":
			fail.call("a dated event is malformed")
	var seen := {}
	for record: Variant in doc.get("items", []):
		if record is not Dictionary or str(record.get("id", "")) == "" or seen.has(record.id):
			fail.call("an item has no id, or repeats one")
			continue
		seen[record.id] = true
		var id := str(record.id)
		if str(record.get("name", "")) == "" or typeof(record.get("cents")) not in [TYPE_INT, TYPE_FLOAT] \
				or float(record.cents) < 0.0 or float(record.cents) != floor(float(record.cents)):
			fail.call("item %s has no name or whole price" % id)
		if str(record.get("kind", "")) not in KINDS or str(record.get("source", "")) not in SOURCES:
			fail.call("item %s has an unknown kind or source" % id)
		if record.has("group") and not groups.has(str(record.group)):
			fail.call("item %s names an unknown group" % id)
		if record.has("form") and not CarriedCase.has_form(str(record.form)):
			fail.call("item %s has an unknown form" % id)
		if record.has("note") and str(record.note) == "":
			fail.call("item %s has an empty note" % id)
		if record.has("grocery"):
			var grocery: Dictionary = ingredients.get(str(record.grocery), {})
			if grocery.is_empty() or int(grocery.get("cents", -1)) != int(record.cents):
				fail.call("item %s disagrees with the grocery price it links" % id)
	return errors.size() == before
