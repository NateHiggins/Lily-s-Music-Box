extends Node
## The Fremont Street notice (Bible VIII.5.q): the Borough Record of Friday 24 May 1929 carries a
## mixed-cast film notice and a company photograph on its back. It is out of circulation before
## 06:00 that day, reads through the ordinary panel, is put away and found again on the shelf,
## and sets nothing on the campaign document except the kept paper itself.

const PAPER := "record"
const DAY := "1929-05-24"
const NOTICE_HEAD := "Ditmars Photoplay adds a Saturday matinee for the Fremont Street picture"
const CAPTION := "FREMONT STREET, 1929. Company photograph. The camera crew asked the tall one to step back."

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("FREMONT NOTICE: ", label, " = ", ok)
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	await _run()
	print("FREMONT NOTICE TEST: %d failures" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


static func _texts(node: Node) -> Array:
	var out := []
	for child in node.find_children("*", "Label", true, false):
		out.append(str(child.text))
	for child in node.find_children("*", "RichTextLabel", true, false):
		out.append(str(child.text))
	return out


static func _set_in(texts: Array, wanted: String) -> bool:
	var page := " ".join(texts.map(func(t): return str(t).replace("\n", " ")))
	return page.replace("  ", " ").contains(wanted)


## Every key of the campaign document except the kept-paper list.
static func _rest_of_document() -> Dictionary:
	var copy: Dictionary = RealityState.data.duplicate(true)
	copy.erase(NewspaperCatalog.STATE_KEY)
	return copy


func _run() -> void:
	var catalog := NewspaperCatalog.new()
	add_child(catalog)
	await get_tree().process_frame
	_check("the year loads without an error", catalog.errors.is_empty())
	var back: Dictionary = catalog.issue(PAPER, DAY).get("back", {})
	var columns: Array = back.get("columns", [])
	_check("the Record of 24 May has a back page whose notices column is the film notice",
			columns.size() == 4 and columns[0].kind == "notices" and columns[0].headline == NOTICE_HEAD
			and str(columns[0].body).contains("Mr. Bramble billed above Miss Ruth Calder"))
	var feature := catalog.feature_for(PAPER, DAY)
	_check("its back carries the company photograph as a halftone with its caption",
			feature.get("treatment") == "halftone" and feature.get("caption") == CAPTION
			and ResourceLoader.exists(str(feature.get("image", ""))))

	# --- out of circulation before its day ------------------------------------------------
	CampaignClock.new().configure_date(1929, 5, 23, 22 * 60)
	_check("the evening before, it is not published", not catalog.published_now(PAPER, DAY))
	_check("the evening before, the rack does not offer it", not (DAY in catalog.on_sale("1929-05-23")))
	CampaignClock.new().configure_date(1929, 5, 24, 5 * 60)
	_check("at 05:00 on the day, it is still not published", not catalog.published_now(PAPER, DAY))
	var early := NewspaperPanel.new()
	add_child(early)
	early.open(null, catalog, PAPER, DAY)
	await get_tree().process_frame
	_check("the panel refuses to print it early", _texts(early).has("This edition has not been published.")
			and not _set_in(_texts(early), CAPTION))
	early.close()
	await get_tree().process_frame
	CampaignClock.new().configure_date(1929, 5, 24, 9 * 60)
	_check("at 09:00 it is published and on the rack", catalog.published_now(PAPER, DAY) and DAY in catalog.on_sale())
	_check("four days on, the rack has let it go", not (DAY in catalog.on_sale("1929-05-28")))

	# --- read, put away, found again --------------------------------------------------------
	var before := _rest_of_document()
	var panel := NewspaperPanel.new()
	add_child(panel)
	panel.open(null, catalog, PAPER, DAY)
	await get_tree().process_frame
	_check("it opens on its front", panel.side == "front" and _texts(panel).has("The Borough Record"))
	panel._show(PAPER, DAY, "back")
	await get_tree().process_frame
	var texts := _texts(panel)
	_check("the back prints the notice's head and every word of its body",
			texts.has(NOTICE_HEAD.to_upper()) and _set_in(texts, str(columns[0].body)))
	_check("the back prints the photograph and its caption", texts.has(CAPTION)
			and panel._page.find_children("*", "TextureRect", true, false).any(
				func(cut): return cut.material is ShaderMaterial and cut.material.shader == NewspaperTypesetter.PRINT_SHADER))
	var shots := OS.get_environment("SHOT_DIR")
	if not shots.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(shots)
		await RenderingServer.frame_post_draw
		_check("the back page capture saves",
				get_viewport().get_texture().get_image().save_png(shots.path_join("fremont_notice_back.png")) == OK)
	panel.close()
	await get_tree().process_frame
	_check("taking the paper keeps it once", catalog.collect(PAPER, DAY) and not catalog.collect(PAPER, DAY))
	var shelf := NewspaperPanel.new()
	add_child(shelf)
	shelf.open_shelf(null, catalog)
	await get_tree().process_frame
	_check("the shelf lists it and opens it", shelf._shelf.item_count == 1 and shelf.paper_id == PAPER and shelf.date == DAY)
	shelf._show(PAPER, DAY, "back")
	await get_tree().process_frame
	_check("read again from the shelf, the notice and photograph are still there",
			_texts(shelf).has(NOTICE_HEAD.to_upper()) and _texts(shelf).has(CAPTION))
	shelf.close()
	await get_tree().process_frame
	_check("reading, putting away and rereading set nothing but the kept paper",
			_rest_of_document() == before
			and NewspaperCatalog.key_of(PAPER, DAY) in RealityState.data[NewspaperCatalog.STATE_KEY])
