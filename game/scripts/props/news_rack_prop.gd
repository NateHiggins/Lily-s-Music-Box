class_name NewsRackProp
extends Node3D
## One `papers` control, two homes (design/ORISON_NEWSPAPERS_2026-10-23.md §6):
##
##   - "counter": the News & Cigars counter top. Interacting offers the two
##     papers for today and the few days the rack keeps; a paper taken is
##     collected at once and may be read there. A paper is settled at its price
##     over the set; with no credit or no carrier it goes on the desk account, so
##     being broke never keeps a player from the news.
##   - "shelf": the player's bookshelf in 4B. Interacting opens the kept
##     papers, newest first.
##
## The rack owns no newsprint: the catalogue answers what is on sale and what
## is kept; the panel reads.

const SALE_ITEMS := {"record": "the_borough_record", "speaker": "the_loud_speaker"}

var mode := "counter"
## The arcade's hours owner (PassageHoursDirector); the stand is shuttered
## with the grilles. Null on the shelf and in bare tests.
var hours: Node = null
## The counter's sales, when the world mounts one. Null on the shelf and in tests.
var sales: ShopSales = null
var _panel: NewspaperPanel
var _chooser: CaseDialoguePanel
var _reach := Vector3(0.9, 0.3, 0.6)


func setup(kind: String, reach := Vector3(0.9, 0.3, 0.6)) -> void:
	mode = kind
	_reach = reach


func _ready() -> void:
	add_to_group("news_racks")
	var control := PropControlArea.new()
	control.name = "PapersControl"
	control.configure("papers")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _reach
	shape.shape = box
	control.add_child(shape)
	add_child(control)
	_chooser = CaseDialoguePanel.new()
	_chooser.name = "PapersChooser"
	add_child(_chooser)


func shuttered() -> bool:
	return mode == "counter" and hours != null and is_instance_valid(hours) \
			and hours.has_method("is_after_hours") and bool(hours.call("is_after_hours"))


func _catalog() -> NewspaperCatalog:
	return get_tree().get_first_node_in_group("newspaper_catalog") as NewspaperCatalog


func control_prompt(control_id: String) -> String:
	if control_id != "papers" or _reading():
		return ""
	var catalog := _catalog()
	if catalog == null:
		return ""
	if mode == "shelf":
		var kept := catalog.collected().size()
		return "Your papers" if kept == 0 else "Your papers (%d)" % kept
	if shuttered():
		return ""
	var today := catalog.today()
	if today == "":
		return "Papers"
	return "Papers, %s" % catalog.short_date(today)


func interact_control(control_id: String, player: Node) -> Variant:
	if control_id != "papers" or _reading():
		return {}
	var catalog := _catalog()
	if catalog == null:
		return {}
	if mode == "shelf":
		_open_panel(player, catalog, "", "")  # reading the archive never empties the case (the stack's deposit does)
		return {}
	if shuttered():
		return {"title": "NEWS AND CIGARS", "body": "GRILLE DRAWN STOP OPENS SIX THIRTY STOP",
				"condition": "STALL SHUT", "stamp": "SERVICE NOTE"}
	var offers := offers_for(catalog, catalog.today(),true)
	if offers.is_empty():
		return {"title": "NEWS AND CIGARS", "body": "RACK EMPTY STOP NO PAPER TODAY STOP",
				"condition": "RACK BARE", "stamp": "SERVICE NOTE"}
	var options: Array = []
	for offer in offers:
		options.append({"text": str(offer.label), "evidence": bool(offer.kept),
				"action": func(): _take(player, catalog, str(offer.paper), str(offer.date))})
	# LILITH has its own entry beside every newspaper offer, so a full rack of papers never hides it.
	var issues := comic_offers(catalog.today())
	if not issues.is_empty():
		options.append({"text": "LILITH, the comic: %d on the rack." % issues.size(),
				"action": func(): _offer_comics(player, catalog)})
	options.append({"text": "Leave them.", "silent": true, "action": Callable()})
	if player != null and "call_locked" in player:
		player.call_locked = true
	_chooser.present("NEWS AND CIGARS", "The rack, %s. Both papers, and a few days back."
			% catalog.long_date(catalog.today()), options)
	return {}


## The rack's offers for a date: both papers for it and each day the rack
## keeps before it, newest first; at most eight so the replies stay on the
## number keys with "Leave them" ninth.
static func offers_for(catalog: NewspaperCatalog, date: String, published_only := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for day in catalog.on_sale(date):
		for paper_id in NewspaperCatalog.PAPER_IDS:
			if published_only and not catalog.published_now(paper_id,day): continue
			if out.size() >= 8:
				return out
			var kept := catalog.is_collected(paper_id, day)
			out.append({"paper": paper_id, "date": day, "kept": kept,
					"label": "%s, %s%s" % [str(catalog.paper(paper_id).get("name", paper_id)),
							catalog.short_date(day), " (kept)" if kept else ""]})
	return out


## A kept paper is read at the rack for nothing. A new one goes into the case's transport slot inside its sale: a
## full slot refuses before any charge, stock or collection, and a refused sale (no money, no stock) changes nothing.
func _take(player: Node, catalog: NewspaperCatalog, paper_id: String, date: String) -> bool:
	if not catalog.published_now(paper_id,date): return false
	if catalog.is_collected(paper_id, date):
		_open_panel(player, catalog, paper_id, date)
		return true
	if not PaperPocket.has_room_for_news():
		_refuse(player, "THE CASE HAS A PAPER IN IT STOP LEAVE IT ON THE STACK AT HOME FIRST STOP", "ONE PAPER")
		return false
	var key := NewspaperCatalog.key_of(paper_id, date)
	var hand_over := func(): return catalog.collect_uncommitted(paper_id, date) and PaperPocket.tuck_news(key)
	var item_id := SALE_ITEMS.get(paper_id, "") as String
	var sold := sales.transact_delivering(item_id, sales.shop_id, hand_over) if sales != null and item_id != "" else bool(hand_over.call())
	if not sold:
		_refuse(player, "NOT SOLD STOP %s STOP" % _why(item_id), "NO SALE")
		return false
	if sales == null:
		RealityState.commit()
	_open_panel(player, catalog, paper_id, date)
	return true


## The LILITH issues on the rack by a date that she hasn't bought, newest first.
static func comic_offers(date: String) -> Array:
	var out: Array = PaperPocket.comics_on_sale(date).filter(func(found): return not PaperPocket.has_comic(str(found.id)))
	out.reverse()
	return out


func _offer_comics(player: Node, catalog: NewspaperCatalog) -> void:
	var options: Array = []
	for found: Variant in comic_offers(catalog.today()).slice(0, 8):
		options.append({"text": "LILITH No. %d, %s. Five cents." % [int(found.number), str(found.title)],
				"action": func(): _take_comic(player, str(found.id))})
	options.append({"text": "Not today.", "silent": true, "action": Callable()})
	if player != null and "call_locked" in player:
		player.call_locked = true
	_chooser.present("NEWS AND CIGARS", "LILITH, THE SILK WIDOW. Told at the Harukiya, with interruptions.", options)


## A comic goes into the case's comics pocket inside its sale: stock, the five cents and custody together.
func _take_comic(player: Node, id: String) -> bool:
	if PaperPocket.has_comic(id) or PaperPocket.issue(id).is_empty():
		return false
	var hand_over := func(): return PaperPocket.tuck_comic(id)
	var sold := sales.transact_delivering(PaperPocket.comic_item(), sales.shop_id, hand_over) if sales != null else bool(hand_over.call())
	if not sold:
		_refuse(player, "NOT SOLD STOP %s STOP" % _why(PaperPocket.comic_item()), "NO SALE")
		return false
	if sales == null:
		RealityState.commit()
	return true


func _why(item_id: String) -> String:
	var status := sales.transaction_status(item_id) if sales != null and item_id != "" else ""
	return {"insufficient_funds": "NOT ENOUGH CASH", "out_of_stock": "NONE LEFT", "no_carrier": "NO RADIO CARRIER"}.get(status, "THE STAND CANT TAKE IT")


func _refuse(player: Node, body: String, condition: String) -> void:
	if player != null and player.has_method("present_service_note"):
		player.present_service_note(self, {"title": "NEWS AND CIGARS", "body": body, "condition": condition, "stamp": "SERVICE NOTE"})


func _open_panel(player: Node, catalog: NewspaperCatalog, paper_id: String, date: String) -> void:
	if _reading():
		return
	_panel = NewspaperPanel.new()
	_panel.name = "NewspaperPanel"
	get_tree().current_scene.add_child(_panel)
	if paper_id == "":
		_panel.open_shelf(player, catalog, _on_panel_closed)
	else:
		_panel.open(player, catalog, paper_id, date, _on_panel_closed)


func _reading() -> bool:
	return _panel != null and is_instance_valid(_panel)


func _on_panel_closed() -> void:
	_panel = null
