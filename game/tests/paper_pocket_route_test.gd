extends "res://tests/carried_case_route_test.gd"
## The case's papers in the production V2 root with real input: a comic in the comics pocket
## (in front of the newspaper pocket), a paper bought at the stand in the newspaper pocket and
## two letters taken from box 4B in the evidence folder; a
## click takes a paper's top edge, upward motion draws it out, and drawn far enough
## it is held up to read; the next click lets it go and it slides home. A part-way
## draw reads nothing. A newspaper opens as the paper itself and ESC hands it back
## to the case. Opening the papers on the 4B shelf files the pocket's newspapers.

const LETTERS := ["welcome_note", "vantry_final_demand"]

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

func _route() -> void:
	var view: Node = world.carried_case_view
	var catalog := get_tree().get_first_node_in_group("newspaper_catalog") as NewspaperCatalog
	if not _require(view != null and catalog != null, "the view and the catalogue are mounted"): return
	RealityState.data["mail_taken"] = LETTERS.duplicate()
	var offers := NewsRackProp.offers_for(catalog, catalog.today(), true)
	if not _require(not offers.is_empty(), "the stand has a paper today"): return
	var bought: Dictionary = offers[0]
	_require(catalog.collect(str(bought.paper), str(bought.date)), "a paper is kept")
	var key := NewspaperCatalog.key_of(str(bought.paper), str(bought.date))
	_require(key in PaperPocket.book().news, "and goes into the pocket")
	var on_sale: Array = PaperPocket.comics_on_sale("1929-02-16").map(func(found): return str(found.id))
	_require(on_sale == ["lilith_01", "lilith_02"], "the stand has the LILITH issues out by that Saturday: %s" % str(on_sale))
	_require(PaperPocket.tuck_comic("lilith_01") and not PaperPocket.tuck_comic("lilith_01"), "a comic is kept once")

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

	# The 4B shelf files the pocket's papers; nothing is lost.
	var shelf: Node = null
	for rack in get_tree().get_nodes_in_group("news_racks"):
		if rack.mode == "shelf":
			shelf = rack
	if not _require(shelf != null, "the 4B shelf is mounted"): return
	shelf.interact_control("papers", player)
	await get_tree().process_frame
	_require(PaperPocket.book().news.is_empty(), "the shelf takes the pocket's papers")
	_require(catalog.is_collected(str(bought.paper), str(bought.date)), "and keeps them")
	if is_instance_valid(shelf._panel):
		shelf._panel.close()
	await get_tree().process_frame
	await _settle_open(view)
	_require(view._papers.size() == 3, "the comic and the letters stay: %d" % view._papers.size())
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
