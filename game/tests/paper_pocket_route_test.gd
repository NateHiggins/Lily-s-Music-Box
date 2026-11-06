extends "res://tests/carried_case_route_test.gd"
## The case's papers in the production V2 root with real input: a comic in the comics pocket
## (in front of the newspaper pocket), a paper bought at the stand in the newspaper pocket and
## two letters taken from box 4B in the evidence folder; a
## click takes a paper's top edge, upward motion draws it out, and drawn far enough
## it is held up to read; the next click lets it go and it slides home. A part-way
## draw reads nothing. A newspaper opens as the paper itself and ESC hands it back
## to the case. The stand sells through one settlement: LILITH has its own entry past
## a full rack, short cash and duplicates change nothing, and the case carries one
## newspaper. At home the paper is slid onto the stack by hand, and a reload from
## disk keeps the paper in transport, the stack and the comic apart.

const LETTERS := ["welcome_note", "vantry_final_demand"]
const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")
const Stack := preload("res://scripts/props/news_stack_prop.gd")

func _init() -> void:
	route_label = "PAPER POCKET ROUTE"

func _settle_open(view: Node) -> void:
	await _key(KEY_TAB)
	for _step in 60:
		if view.settled:
			break
		await get_tree().process_frame

func _draw_out(view: Node, index: int, pixels: float) -> void:
	var at: Vector2 = view.paper_grip_point(index)
	await _press(at)
	_require(view.held_paper == index, "a click takes paper %d's top edge: held %d" % [index, view.held_paper])
	var travelled := 0.0
	while travelled < pixels:
		travelled = minf(travelled + 16.0, pixels)
		await _motion(at - Vector2(0, travelled))

func _money() -> int:
	return int(world.carried_case_view.economy.book().cash)

func _units(stand: Node) -> float:
	return stand.sales.stock.units("news_cigars", "papers")

func _stand_at(prop: Node3D, look_at: Vector3) -> void:
	var front: Vector3 = prop.global_position + prop.global_basis.z.normalized() * 0.95
	var hit := prop.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(front + Vector3.UP * 1.5, front + Vector3.DOWN * 2.0))
	player.global_position = hit.position + Vector3.UP * 0.05 if not hit.is_empty() else front
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.camera.look_at(look_at)
	await get_tree().physics_frame

func _route() -> void:
	var view: Node = world.carried_case_view
	var catalog := get_tree().get_first_node_in_group("newspaper_catalog") as NewspaperCatalog
	if not _require(view != null and catalog != null, "the view and the catalogue are mounted"): return
	RealityState.data["mail_taken"] = LETTERS.duplicate()
	var stand: Node = null
	for rack in get_tree().get_nodes_in_group("news_racks"):
		if rack.mode == "counter" and rack.sales != null:
			stand = rack
	if not _require(stand != null, "the News & Cigars stand is mounted with its sales"): return
	CampaignClock.new().configure_date(1929, 2, 16, 18 * 60)
	await get_tree().process_frame
	var offers := NewsRackProp.offers_for(catalog, catalog.today(), true)
	if not _require(offers.size() == 8, "a full rack: eight papers on offer (%d)" % offers.size()): return
	_require(not stand.shuttered(), "the stand is open at six")

	# LILITH has its own entry after all eight papers, before Leave.
	view.economy.book().cash = 3
	stand.interact_control("papers", player)
	await get_tree().process_frame
	var labels: Array = stand._chooser.offered_labels()
	_require(labels.size() == 10 and str(labels[8]).strip_edges().begins_with("LILITH, the comic") and str(labels[9]).strip_edges() == "Leave them.",
			"eight papers, then LILITH, then Leave: %s" % str(labels))
	stand._chooser.choose(8)
	await get_tree().process_frame
	var issues: Array = stand._chooser.offered_labels()
	_require(str(issues[0]).begins_with("LILITH No. 2") and str(issues[1]).begins_with("LILITH No. 1"), "both issues out, newest first: %s" % str(issues))
	var units := _units(stand)
	stand._chooser.choose(1)
	await get_tree().process_frame
	_require(not PaperPocket.has_comic("lilith_01") and _money() == 3 and _units(stand) == units, "three cents can't buy it: nothing changes")

	view.economy.book().cash = 100
	stand.interact_control("papers", player)
	await get_tree().process_frame
	stand._chooser.choose(8)
	await get_tree().process_frame
	stand._chooser.choose(1)
	await get_tree().process_frame
	_require(PaperPocket.has_comic("lilith_01") and _money() == 95 and _units(stand) == units - 1.0,
			"five cents, one off the rack, one comic in the case: %d cents, %s" % [_money(), str(_units(stand))])
	stand.interact_control("papers", player)
	await get_tree().process_frame
	stand._chooser.choose(8)
	await get_tree().process_frame
	_require(not stand._chooser.offered_labels().any(func(label): return str(label).begins_with("LILITH No. 1")), "No. 1 isn't offered twice")
	stand._chooser.choose(stand._chooser.offered_labels().size() - 1)
	await get_tree().process_frame
	_require(not stand._take_comic(player, "lilith_01") and _money() == 95 and _units(stand) == units - 1.0, "a duplicate sale is refused")

	# A paper into the case's one transport slot, inside its sale.
	var bought: Dictionary = offers[0]
	var key := NewspaperCatalog.key_of(str(bought.paper), str(bought.date))
	var price := int(stand.sales.catalogue.item("news_cigars", NewsRackProp.SALE_ITEMS[str(bought.paper)]).cents)
	# Every save made during the sale is whole: never the debit or the kept issue without the paper in the case.
	var commits: Array = []
	var observe := func():
		commits.append({"kept": catalog.is_collected(str(bought.paper), str(bought.date)), "carried": PaperPocket.transit_news() == key,
				"cash": _money(), "sold": int(view.economy.book().get("sales", {}).get("news_cigars/" + NewsRackProp.SALE_ITEMS[str(bought.paper)], {}).get("count", 0))})
	var sold_before := int(view.economy.book().get("sales", {}).get("news_cigars/" + NewsRackProp.SALE_ITEMS[str(bought.paper)], {}).get("count", 0))
	RealityState.state_changed.connect(observe)
	stand.interact_control("papers", player)
	await get_tree().process_frame
	stand._chooser.choose(0)
	await get_tree().process_frame
	RealityState.state_changed.disconnect(observe)
	_require(not commits.is_empty(), "the sale saved")
	_require(commits.all(func(c): return c.kept == c.carried and (c.cash == 95) == (not c.kept) and (c.sold == sold_before) == (not c.kept)),
			"every save in the sale holds all of debit, sale row, kept issue and custody, or none: %s" % str(commits))
	_require(PaperPocket.transit_news() == key and catalog.is_collected(str(bought.paper), str(bought.date)), "the paper is kept and rides in the case")
	_require(_money() == 95 - price and _units(stand) == units - 2.0, "at its masthead price")
	if is_instance_valid(stand._panel):
		stand._panel.close()
	await get_tree().process_frame
	var second: Dictionary = offers[1]
	var money_before := _money()
	stand.interact_control("papers", player)
	await get_tree().process_frame
	stand._chooser.choose(1)
	await get_tree().process_frame
	_require(PaperPocket.transit_news() == key and not catalog.is_collected(str(second.paper), str(second.date)), "a second paper is refused: the case holds one")
	_require(_money() == money_before and _units(stand) == units - 2.0, "before any charge or stock")
	if is_instance_valid(stand._panel):
		stand._panel.close()
	await get_tree().process_frame

	await _settle_open(view)
	if not _require(view.opened and view.settled, "the case opens"): return
	var kinds: Array = view._papers.map(func(paper): return str(paper.kind))
	var ids: Array = view._papers.map(func(paper): return str(paper.get("id", paper.get("paper", ""))))
	_require(kinds == ["comic", "letter", "letter", "news"], "comics, the folder's letters, then the paper: %s" % str(kinds))
	_require(ids.slice(1, 3) == ["vantry_final_demand", "welcome_note"], "the latest letter stands in front: %s" % str(ids))
	_require(view._sheets.size() == 4, "each paper has a sheet")
	var comic_top: float = view._sheets[0].global_position.y + view._sheets[0].global_basis.y.y * 0.05
	var news_top: float = view._sheets[3].global_position.y + view._sheets[3].global_basis.y.y * 0.065
	_require(news_top > comic_top + 0.02, "the comics pocket sits in front of and below the newspapers, both showing")
	_require(view._sheets[0].get_meta("depth") > view._sheets[3].get_meta("depth"), "and nearer the reader")
	await _capture_interaction("valise_pocket")

	# A letter, drawn all the way out, is held up to read.
	await _draw_out(view, 1, view.DRAW_PIXELS)
	await get_tree().process_frame
	var letter: Node = view._reading
	if not _require(letter is PocketPaperPanel, "drawn out, the letter is held up to read"): return
	_require(str(letter.entry.get("id", "")) == "vantry_final_demand", "it is the letter that was taken")
	_require(player.call_locked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the case keeps the pointer while reading")
	await _capture_interaction("valise_pocket_letter")
	await _press(view.paper_grip_point(1))
	await get_tree().create_timer(0.4).timeout
	_require(not is_instance_valid(view._reading), "the next click lets it go")
	_require(view.held_paper == -1 and view.opened, "it slides home and the case stays open")

	# The comic's cover, held up to read.
	await _draw_out(view, 0, view.DRAW_PIXELS)
	await get_tree().process_frame
	var comic: Node = view._reading
	if not _require(comic is PocketPaperPanel and str(comic.entry.get("kind", "")) == "comic", "drawn out, the comic is held up"): return
	_require(str(comic.entry.get("title", "")).begins_with("No. 1"), "LILITH No. 1: %s" % str(comic.entry.get("title", "")))
	await _capture_interaction("valise_pocket_comic")
	await _press(view.paper_grip_point(0))
	await get_tree().create_timer(0.4).timeout

	# Part of the way out and let go: nothing is read.
	await _draw_out(view, 2, view.DRAW_PIXELS * 0.4)
	_require(not is_instance_valid(view._reading), "a part-way draw reads nothing")
	await _press(view.paper_grip_point(2))
	await get_tree().create_timer(0.4).timeout
	_require(view.held_paper == -1 and view._draw == 0.0, "let go, it goes back")

	# The newspaper opens as itself; ESC hands it back to the case.
	await _draw_out(view, 3, view.DRAW_PIXELS)
	await get_tree().process_frame
	var news: Node = view._reading
	if not _require(news is NewspaperPanel, "the newspaper opens as the paper"): return
	_require(news.paper_id == str(bought.paper) and news.date == str(bought.date), "the one that was bought")
	await _capture_interaction("valise_pocket_news")
	await _key(KEY_ESCAPE)
	await get_tree().create_timer(0.4).timeout
	_require(not is_instance_valid(view._reading) and view.opened, "ESC puts the paper back, the case stays open")
	_require(player.call_locked, "and keeps the player")
	await _key(KEY_TAB)
	await get_tree().create_timer(0.6).timeout
	_require(not view.opened and not player.call_locked, "the key closes the case")

	# Home: reading the archive never empties the case; the paper is laid on the stack by hand.
	var shelf: Node = null
	for rack in get_tree().get_nodes_in_group("news_racks"):
		if rack.mode == "shelf":
			shelf = rack
	if not _require(shelf != null, "the 4B shelf is mounted"): return
	shelf.interact_control("papers", player)
	await get_tree().process_frame
	_require(PaperPocket.transit_news() == key, "opening the archive leaves the paper in the case")
	if is_instance_valid(shelf._panel):
		shelf._panel.close()
	await get_tree().process_frame
	var stack: Node3D = get_tree().get_first_node_in_group("news_stacks") as Node3D
	if not _require(stack != null, "the newspaper stack stands by the 4B shelf"): return
	await get_tree().create_timer(0.7).timeout
	var on_stack: int = stack.count()
	var height: float = stack.top_height()
	_require(stack.arriving.visible, "the carried paper waits on the stack's edge")
	await _stand_at(stack, stack.arriving.global_position)
	await _capture_interaction("news_stack_before")
	var hand: Node = Hands.new()
	hand.set_meta("shared_world_validation", true)
	add_child(hand)
	hand.player = player
	await hand.aim(stack.arriving.global_position)
	hand.click()
	_require(player._grab.active(), "the hand takes the paper")
	await hand._gesture_to(Stack.SLIDE)
	await get_tree().create_timer(0.3).timeout
	_require(PaperPocket.transit_news() == "" and stack.count() == on_stack + 1, "squared on the pile, it leaves the case for the stack (%d -> %d)" % [on_stack, stack.count()])
	_require(stack.top_height() > height or stack.piles.size() > 1, "and the stack grows")
	_require(catalog.is_collected(str(bought.paper), str(bought.date)), "the issue is kept, once")
	await hand._gesture_to(0.0)
	await get_tree().process_frame
	_require(player._grab.active() and PaperPocket.transit_news() == "" and stack.count() == on_stack + 1,
			"the hand still holds the squared paper and more motion changes nothing")
	hand.click()
	await get_tree().create_timer(0.3).timeout
	_require(not player._grab.active() and not stack.arriving.visible, "the next click lets go, and the paper is part of the pile")
	await _capture_interaction("news_stack_after")

	# The next paper can be bought and carried.
	stand.interact_control("papers", player)
	await get_tree().process_frame
	stand._chooser.choose(1)
	await get_tree().process_frame
	var key2 := NewspaperCatalog.key_of(str(second.paper), str(second.date))
	_require(PaperPocket.transit_news() == key2, "with the slot empty, the next paper rides home")
	if is_instance_valid(stand._panel):
		stand._panel.close()
	await get_tree().process_frame

	# Readers fill the screen and keep their text legible, from a small window up to 3440x1440.
	var small := NewspaperPanel.fit_scale(Vector2(1280, 720))
	var wide := NewspaperPanel.fit_scale(Vector2(3440, 1440))
	_require(small >= 0.8 and wide > 1.5 and wide <= 2.0, "the newspaper grows with the screen: %.2f at 1280x720, %.2f at 3440x1440" % [small, wide])
	_require(PocketPaperPanel.fit_scale(Vector2(3440, 1440)) > 1.5, "and so does a letter or a cover")

	# From disk: the paper in transport, the stack, and the comic each keep their custody.
	var directory := OS.get_environment("SHOT_DIR")
	if _require(not directory.is_empty(), "an isolated directory for the reload"):
		DirAccess.make_dir_recursive_absolute(directory)
		var original_path: String = RealityState.save_path
		RealityState.save_path = directory.path_join("paper_pocket_campaign.json")
		if _require(RealityState.save_game(), "the campaign saves"):
			RealityState.load_game()
			_require(PaperPocket.transit_news() == key2, "after reload the second paper is still in the case")
			_require(stack.count() == on_stack + 1, "and the stack still holds the first")
			_require(PaperPocket.has_comic("lilith_01") and catalog.is_collected(str(bought.paper), str(bought.date)), "and the comic and the kept issue survive")
		RealityState.save_path = original_path
	await _settle_open(view)
	_require(view._papers.filter(func(paper): return paper.kind == "news").size() == 1, "the case shows the one paper it carries")
	await _key(KEY_TAB)
	await get_tree().create_timer(0.6).timeout
	_require(PaperPocket.valid(RealityState.data.get(PaperPocket.KEY)), "the pocket's record is valid")
	var broken := {"version": 1, "news": ["no date"]}
	_require(not PaperPocket.valid(broken), "a malformed record is refused")
	# A written find is kept in the evidence folder, once, after the letters.
	_require(PaperPocket.file_evidence("m_test_find", "TEST, A FIND", "A NOTE THAT WAS FOUND."), "a find is filed")
	_require(not PaperPocket.file_evidence("m_test_find", "TEST, A FIND", "A NOTE THAT WAS FOUND."), "and only once")
	var finds: Array = PaperPocket.contents(catalog).filter(func(paper): return str(paper.get("id", "")) == "m_test_find")
	_require(finds.size() == 1 and finds[0].kind == "letter", "it stands in the evidence folder")
	_require(PaperPocket.valid(RealityState.data.get(PaperPocket.KEY)), "the record stays valid with a find")
