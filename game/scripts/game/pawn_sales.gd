class_name PawnSales
extends ShopSales
## The Pawnbroker's counter. Shelf goods are single named objects, some of them a
## resident's dated pledge, which appear on their date and sell once. The player can
## pledge a carried good for about a third of its worth and redeem it within thirty
## days for a little more; after that it goes on the shelf at twice the loan. Money
## stays with CaretakerEconomy and goods with PersonInventory.

const KEY := "pawn_book"
const LOAN_SHARE := 3
const MIN_WORTH := 15
const TICKET_DAYS := 30
## An authored rate of 3 percent a month; no period rate was found.
const INTEREST_PERCENT := 3
const DAY := 1440.0
const REDEEM_PREFIX := "redeem_"
const RESALE_PREFIX := "resale_"

static var _clock := CampaignClock.new()
var economy: Node


func _init(shops: ShopCatalogue, levels: ShopStock, network: RefCounted, ledger: Node) -> void:
	super("pawnbroker", shops, levels, network)
	economy = ledger


static func book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"tickets": {}, "forfeit": {}, "sold": {}}
	return RealityState.data[KEY]


static func valid(value: Variant) -> bool:
	if value is not Dictionary:
		return false
	for key: String in ["tickets", "forfeit", "sold"]:
		if value.get(key) is not Dictionary:
			return false
	for item: Variant in value.tickets:
		var ticket: Variant = value.tickets[item]
		if item is not String or ticket is not Dictionary or ticket.get("name") is not String \
				or ticket.get("form") is not String \
				or typeof(ticket.get("lent")) not in [TYPE_INT, TYPE_FLOAT] \
				or typeof(ticket.get("at")) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	return true


static func _now() -> float:
	_clock.bind_state()
	return _clock.elapsed_minutes()


static func _today() -> String:
	if not _clock.bind_state():
		return ""
	var local := _clock.local_datetime()
	return "" if local.is_empty() else "%04d-%02d-%02d" % [int(local.year), int(local.month), int(local.day)]


## What a good fetches here, or 0 if the broker won't lend on it.
static func loan_for(worth: int) -> int:
	return 0 if worth < MIN_WORTH else maxi(5, worth / LOAN_SHARE)


static func redeem_price(ticket: Dictionary) -> int:
	var months := ceili(maxf(_now() - float(ticket.at), 1.0) / (DAY * 30.0))
	return int(ticket.lent) + maxi(1, ceili(float(ticket.lent) * INTEREST_PERCENT * months / 100.0))


## Uncommitted until the ledger's receive saves it with the cash.
func pledge(item: String, shown_name: String, form: String, worth: int) -> bool:
	var lent := loan_for(worth)
	if lent == 0 or book().tickets.has(item) or not PersonInventory.spend_goods(PersonInventory.PLAYER, item):
		return false
	book().tickets[item] = {"name": shown_name, "form": form, "lent": lent, "at": _now()}
	economy.receive("pawnbroker/pledge", lent)
	return true


## Tickets past their days go to the shelf.
func _settle_tickets() -> void:
	var tickets: Dictionary = book().tickets
	for item: String in tickets.keys():
		if _now() - float(tickets[item].at) > TICKET_DAYS * DAY:
			book().forfeit[item] = tickets[item]
			tickets.erase(item)


func listing() -> Array[String]:
	_settle_tickets()
	var out: Array[String] = []
	for item: String in book().tickets:
		out.append(REDEEM_PREFIX + item)
	for item: String in book().forfeit:
		out.append(RESALE_PREFIX + item)
	var today := _today()
	for record: Dictionary in catalogue.counter_items(shop_id):
		if book().sold.has(record.id) or (record.has("from") and today < str(record.from)):
			continue
		out.append(str(record.id))
	return out


func stock_record(item_id: String) -> Dictionary:
	if item_id.begins_with(REDEEM_PREFIX):
		var ticket: Dictionary = book().tickets.get(item_id.trim_prefix(REDEEM_PREFIX), {})
		if not ticket.is_empty():
			return {"id": item_id, "shop_id": shop_id, "display_name": "Redeem: " + str(ticket.name), "price_cents": redeem_price(ticket)}
		return {}
	if item_id.begins_with(RESALE_PREFIX):
		var lapsed: Dictionary = book().forfeit.get(item_id.trim_prefix(RESALE_PREFIX), {})
		if not lapsed.is_empty():
			return {"id": item_id, "shop_id": shop_id, "display_name": str(lapsed.name), "price_cents": int(lapsed.lent) * 2}
		return {}
	return super(item_id)


func transaction_status(item_id: String) -> String:
	var prefix := _prefix(item_id)
	if prefix == "":
		return super(item_id)
	var record := stock_record(item_id)
	if record.is_empty():
		return "invalid_quote"
	var ticket: Dictionary = _source(prefix)[item_id.trim_prefix(prefix)]
	if not PersonInventory.can_carry_goods(PersonInventory.PLAYER, item_id.trim_prefix(prefix), str(ticket.form)):
		return "case_full"
	return clearing.settlement_status(shop_id, int(record.price_cents))


func transact(item_id: String, shop: String) -> bool:
	var prefix := _prefix(item_id)
	if prefix == "":
		var sold: bool = super(item_id, shop)
		if sold:
			book().sold[item_id] = true
			RealityState.commit()
		return sold
	if shop != shop_id or transaction_status(item_id) != "available":
		return false
	var item := item_id.trim_prefix(prefix)
	var source := _source(prefix)
	var ticket: Dictionary = source[item]
	return clearing.settle_repeat(shop_id, item_id, int(stock_record(item_id).price_cents), func():
		if not PersonInventory.carry_goods(PersonInventory.PLAYER, item, str(ticket.name), str(ticket.form)):
			return false
		source.erase(item)
		return true)


func _prefix(item_id: String) -> String:
	for prefix: String in [REDEEM_PREFIX, RESALE_PREFIX]:
		if item_id.begins_with(prefix):
			return prefix
	return ""


func _source(prefix: String) -> Dictionary:
	return book().tickets if prefix == REDEEM_PREFIX else book().forfeit
