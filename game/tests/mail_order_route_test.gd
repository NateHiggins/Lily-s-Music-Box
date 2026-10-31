extends "res://tests/carried_case_route_test.gd"
## A back-page order from end to end in the V2 root: a real click and drag tears the
## coupon off the page, the counter refuses until there is a coupon, a real hand on the
## News lever posts it once, and after its days the parcel is in the 4B box and in the
## case. A short pull lets the coupon go again. Nothing here is seeded but the date.

const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")
const ORDER := "felt_bedpost_pads"

func _init() -> void:
	route_label = "MAIL ORDER ROUTE"

func _find_issue(catalog: NewspaperCatalog) -> Dictionary:
	var dates: Array = catalog.issues.keys()
	dates.sort()
	for date: String in dates:
		for paper: String in NewspaperCatalog.PAPER_IDS:
			if not catalog.published_now(paper, date):
				continue
			for ad: Dictionary in catalog.ads_for(paper, date):
				if str(ad.get("order", "")) == ORDER:
					return {"paper": paper, "date": date}
	return {}

func _pull(panel: NewspaperPanel, coupon: Control, pixels: float) -> void:
	var at := coupon.get_global_rect().get_center()
	await _press(at)
	var moved := 0.0
	while moved < pixels and panel._coupon != null:
		var event := InputEventMouseMotion.new()
		event.position = at
		event.global_position = at
		event.relative = Vector2(14, 0)
		Input.parse_input_event(event)
		await get_tree().process_frame
		moved += 14.0

func _route() -> void:
	CampaignClock.new().configure_date(1929, 10, 1, 12 * 60)
	var stand: Node = world.passage_region.transaction_actor_root().get_node("NewsStand")
	var catalog: NewspaperCatalog = stand._catalog()
	var issue := _find_issue(catalog)
	if not _require(not issue.is_empty(), "some issue carries the coupon"): return
	var post_id := "post_" + ORDER
	var news: Node3D = world.shop_counters.news_cigars
	if not _require(news.item_ids.has(post_id), "the counter lists the posting"): return
	var economy: Node = world.get_node("CaretakerEconomy")
	economy.book().cash = 500

	stand._open_panel(player, catalog, str(issue.paper), str(issue.date))
	await get_tree().process_frame
	var panel: NewspaperPanel = stand._panel
	panel._show(str(issue.paper), str(issue.date), "back")
	await get_tree().process_frame
	await get_tree().process_frame
	var coupon: Control = null
	for found: Node in panel._page.find_children(NewspaperAd.COUPON_NODE, "PanelContainer", true, false):
		if str(found.get_meta("order", "")) == ORDER:
			coupon = found
	if not _require(coupon != null, "the page sets the coupon"): return
	panel._scroll.ensure_control_visible(coupon)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture_interaction("mail_coupon_page")
	await _pull(panel, coupon, 42.0)
	_require(panel._coupon == coupon and not MailOrders.torn(ORDER), "a short pull has not torn it")
	await _capture_interaction("mail_coupon_pulling")
	await _press(coupon.get_global_rect().get_center())
	_require(panel._coupon == null and coupon.rotation == 0.0, "a click lets it go again")
	await _pull(panel, coupon, 200.0)
	_require(MailOrders.torn(ORDER), "a full pull tears it off")
	_require(not coupon.visible, "and leaves a hole in the page")
	panel.close()
	await get_tree().create_timer(0.3).timeout

	# The counter: a real hand on the lever.
	var hand: Node = Hands.new()
	hand.set_meta("shared_world_validation", true)
	add_child(hand)
	hand.player = player
	var forward: Vector3 = -news.global_basis.z
	player.global_position = news.global_position + forward * 0.95 + Vector3.DOWN * 1.1
	await get_tree().physics_frame
	news.select(news.item_ids.find("post_party_line_manners"))
	await get_tree().physics_frame
	_require(await hand._stroke(news.terminal, news.terminal.TRAVEL), "the lever works")
	_require(news.flag.text == "NO COUPON", "no coupon, no posting: " + news.flag.text)
	news.select(news.item_ids.find(post_id))
	await _capture_interaction("mail_post_selected")
	var cash := int(economy.book().cash)
	_require(await hand._stroke(news.terminal, news.terminal.TRAVEL), "the real hand posts it")
	_require(news.flag.text == "SETTLED", "the posting settles: " + news.flag.text)
	_require(MailOrders.posted(ORDER) and int(economy.book().cash) == cash - 27, "and is charged, stamp included")
	_require(await hand._stroke(news.terminal, news.terminal.TRAVEL), "the lever works again")
	_require(news.flag.text == "ALREADY POSTED", "and only once: " + news.flag.text)

	# The box.
	var bank: MailBankProp = null
	for found: Node in get_tree().get_nodes_in_group("mail_banks"):
		bank = found
	if bank == null:
		for found: Node in world.find_children("*", "Node3D", true, false):
			if found is MailBankProp:
				bank = found
				break
	if not _require(bank != null, "the mail bank is in the world"): return
	var is_due := func() -> bool:
		return bank.pending().any(func(item): return str(item.id) == "order_" + ORDER)
	_require(not is_due.call(), "the parcel takes its days")
	# A minute's margin: with the clock still, exactly the wait can round to just short.
	RealityState.data[MailOrders.KEY].posted[ORDER] -= 3.0 * MailOrders.DAY + 1.0
	_require(is_due.call(), "and then is due in the box")
	for item: Dictionary in bank.pending():
		if str(item.id) == "order_" + ORDER:
			bank._take(item, true)
	_require(PersonInventory.goods_count("player", ORDER) == 1, "the parcel lands in the case")
	_require(CarriedCase.place_of(ORDER).size() > 0, "on a square")
	_require(not is_due.call(), "and is not delivered twice")
	_require(MailOrders.valid(RealityState.data[MailOrders.KEY]), "orders stay valid")
