extends Node
## The two daily papers: the year loads whole and valid, today's
## date comes off the campaign clock, the rack offers the right days, a paper
## taken is kept on the campaign document, the shelf lists it, and the panel
## builds a front page without a scene. Run windowed for the actual page-turn
## input checks; headless viewport geometry is not a playable pointer surface.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("NEWSPAPERS: ", label, " = ", ok)
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 9 * 60)
	await _run()
	print("NEWSPAPER TEST: %d failures" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _run() -> void:
	var catalog := NewspaperCatalog.new()
	add_child(catalog)
	await get_tree().process_frame
	for line in catalog.errors.slice(0, 12):
		print("  catalogue error: ", line)
	_check("the year loads without an error", catalog.errors.is_empty())
	_check("both mastheads are authored", catalog.paper("record").get("name") == "The Borough Record"
			and catalog.paper("speaker").get("name") == "The Loud Speaker")
	_check("every day of the year is printed", catalog.dates.size() == 365
			and catalog.dates[0] == NewspaperCatalog.FIRST_DATE
			and catalog.dates[-1] == NewspaperCatalog.LAST_DATE)
	var sample := catalog.issue("record", "1928-11-10")
	_check("the house sample is the first Record",
			str(sample.get("lead", {}).get("headline", "")).begins_with("Count of Tuesday's returns"))
	_check("the Speaker answers it the same evening",
			str(catalog.issue("speaker", "1928-11-10").get("lead", {}).get("headline", "")) == "Hoover wins by a hair, loses by a wire")
	_check("dates print long and short", catalog.long_date("1928-11-10") == "Saturday 10 November 1928"
			and catalog.short_date("1929-02-14") == "Thu 14 Feb")

	# --- the clock and the rack ------------------------------------------------------
	_check("today is the campaign's first morning", catalog.today() == "1928-11-10")
	_check("the rack on day one holds only day one", catalog.on_sale() == ["1928-11-10"])
	_check("a week in, the rack keeps four days",
			catalog.on_sale("1928-11-17") == ["1928-11-17", "1928-11-16", "1928-11-15", "1928-11-14"])
	var offers := NewsRackProp.offers_for(catalog, "1928-11-17")
	_check("the counter offers eight papers, newest first", offers.size() == 8
			and offers[0].paper == "record" and offers[0].date == "1928-11-17"
			and offers[1].paper == "speaker" and offers[7].date == "1928-11-14")
	_check("an unknown day offers nothing", NewsRackProp.offers_for(catalog, "1930-01-01").is_empty())

	# --- keeping ------------------------------------------------------------------------
	_check("nothing is kept at the start", catalog.collected().is_empty()
			and not catalog.is_collected("record", "1928-11-10"))
	_check("taking a paper keeps it once", catalog.collect("record", "1928-11-10")
			and not catalog.collect("record", "1928-11-10")
			and catalog.is_collected("record", "1928-11-10"))
	_check("a paper that was never printed cannot be kept", not catalog.collect("speaker", "1930-01-01")
			and not catalog.collect("gazette", "1928-11-10"))
	catalog.collect("speaker", "1928-11-12")
	catalog.collect("speaker", "1928-11-10")
	var kept := catalog.collected()
	_check("the shelf lists the collection newest first, Record before Speaker on a day",
			kept.size() == 3 and kept[0].date == "1928-11-12"
			and kept[1].paper == "record" and kept[2].paper == "speaker")
	var snapshot: Dictionary = RealityState.data.duplicate(true)
	_check("the collection is on the campaign document and the shape validates",
			"record:1928-11-10" in snapshot.newspapers_collected
			and RealityState._validate_document(snapshot).ok)
	_check("a marked offer shows what is already kept",
			NewsRackProp.offers_for(catalog, "1928-11-12")[1].kept
			and str(NewsRackProp.offers_for(catalog, "1928-11-12")[1].label).ends_with("(kept)"))

	# --- the panel ------------------------------------------------------------------------
	# This programme renders the evening edition; its release is17:00.
	# The earlier09:00 catalogue checks do not authorize displaying it yet.
	CampaignClock.new().configure_date(1928, 11, 10, 17 * 60)
	var panel := NewspaperPanel.new()
	add_child(panel)
	panel.open(null, catalog, "speaker", "1928-11-10")
	await get_tree().process_frame
	var texts := _texts(panel)
	_check("the panel prints masthead, lead and wire",
			_set_in(texts, "THE LOUD SPEAKER") and texts.has("HOOVER WINS BY A HAIR, LOSES BY A WIRE")
			and texts.any(func(t): return str(t).begins_with("LATE WIRE:")))
	_check("the panel prints three column heads",
			texts.count("TWO MINUTES' SILENCE: QUEENS TO HOLD ITS BREATH, THEN PLAY IT BACK") == 1
			and texts.has("ASK THE OPERATOR: 'IS MY HUSBAND AT THE ARCADE?'"))
	_check("Saturday's Speaker carries the Editor's Chair on Lilith",
			texts.has("THE EDITOR'S CHAIR") and texts.has("A lady on the line? A menace on the wire!")
			and texts.has("Barnaby Grail, Editor"))
	var saturdays := 0
	for day in catalog.dates:
		var speaker := catalog.issue("speaker", day)
		if speaker.has("editorial"):
			saturdays += 1
		if catalog.issue("record", day).has("editorial"):
			saturdays = -1000
	_check("fifty-three Saturdays of the Speaker carry the editorial, and the Record none", saturdays == 53)
	panel.close()
	await get_tree().process_frame
	await _back_page(catalog)
	var shelf := NewspaperPanel.new()
	add_child(shelf)
	shelf.open_shelf(null, catalog)
	await get_tree().process_frame
	_check("the shelf lists the three kept papers and opens the newest",
			shelf._shelf.item_count == 3 and shelf.date == "1928-11-12" and shelf.paper_id == "speaker")
	shelf.close()

	# --- the rack prop ---------------------------------------------------------------------
	var rack := NewsRackProp.new()
	rack.setup("counter")
	add_child(rack)
	await get_tree().process_frame
	_check("the counter's prompt carries the date", rack.control_prompt("papers") == "Papers, Sat 10 Nov")
	var desk := NewsRackProp.new()
	desk.setup("shelf")
	add_child(desk)
	await get_tree().process_frame
	_check("the shelf's prompt counts the collection", desk.control_prompt("papers") == "Your papers (3)")
	_check("an unknown control answers nothing", rack.control_prompt("knock") == ""
			and (rack.interact_control("knock", null) as Dictionary).is_empty())

	await _input_ownership(catalog)
	await _pictures(catalog)


## The new pages: pictures are optional, and turning reaches a Sunday's third side.
func _pictures(catalog: NewspaperCatalog) -> void:
	CampaignClock.new().configure_date(1929, 11, 9, 20 * 60)
	var printed := func(panel: NewspaperPanel) -> Array:
		return panel._page.find_children("*", "TextureRect", true, false).filter(
				func(cut): return cut.material is ShaderMaterial and cut.material.shader == NewspaperTypesetter.PRINT_SHADER)
	var panel := NewspaperPanel.new()
	add_child(panel)
	panel.open(null, catalog, "speaker", "1929-09-21")
	await get_tree().process_frame
	var texts := _texts(panel)
	var front_picture := catalog.front_picture("speaker", "1929-09-21")
	_check("a Speaker front prints its picture and caption", printed.call(panel).size() >= 2 and texts.has(str(front_picture.caption)))
	_check("every word of the lead is still on the page", _set_in(texts, str(catalog.issue("speaker", "1929-09-21").lead.body)))
	panel._show("record", "1929-04-21")
	await get_tree().process_frame
	texts = _texts(panel)
	_check("the Record sets its name in full and a portrait with its lead", texts.has("The Borough Record")
			and texts.has(str(catalog.front_picture("record", "1929-04-21").caption)))
	_check("a lead cut into two columns keeps its words", _set_in(texts, str(catalog.issue("record", "1929-04-21").lead.body)))
	panel._show("record", "1928-11-10")
	await get_tree().process_frame
	_check("a day with no picture still sets a whole page", catalog.front_picture("record", "1928-11-10").is_empty()
			and _set_in(_texts(panel), str(catalog.issue("record", "1928-11-10").lead.body)))
	_check("an ear's forecast finds its woodcut", catalog.weather_block("Rain. High 44.").ends_with("weather_rain.webp")
			and catalog.weather_block("Fair and cold.").ends_with("weather_cold.webp")
			and catalog.weather_block("Nothing to report.").ends_with("weather_cloud.webp"))
	panel._show("speaker", "1929-08-24", "back")
	await get_tree().process_frame
	_check("a Saturday's back runs the photo drama over the advertising", panel._page.find_child("PhotoDrama", true, false) != null
			and panel._page.find_child("Advertising", true, false) != null)
	var sunday := "1929-08-25"
	panel._show("speaker", sunday)
	await get_tree().process_frame
	_check("a Sunday Speaker has three sides, a weekday two", panel._sides() == ["front", "back", "pictures"])
	var corner: Vector2 = panel._corner.get_global_rect().get_center()
	for wanted in ["back", "pictures", "front"]:
		await _press(corner)
		await _drag(Vector2(-320, 0))
		await _press(corner)
		await get_tree().process_frame
		_check("turning the Sunday sheet reaches its %s" % wanted, panel.side == wanted)
		if wanted == "pictures":
			var section := catalog.brown_for("speaker", sunday)
			_check("the Brown Section prints four pictures and their captions",
					panel._page.find_child("BrownSection", true, false) != null and printed.call(panel).size() == NewspaperCatalog.BROWN_PICTURES
					and _texts(panel).has(str(section.pictures[3].caption)))
	panel.close()
	await get_tree().process_frame
	var errors_before := catalog.errors.size()
	_check("a picture that does not exist is refused", not catalog._valid_picture(
			{"paper": "record", "date": "1929-01-01", "treatment": "ink", "image": "res://nothing.webp", "caption": "x"}, "test"))
	catalog.errors.resize(errors_before)


## The back of the sheet: optional, validated, and turned by hand (RUL-013).
func _back_page(catalog: NewspaperCatalog) -> void:
	var column := func(kind: String) -> Dictionary:
		return {"kind": kind, "headline": "A %s headline" % kind, "body": "A %s body." % kind}
	var good := {"columns": [column.call("news"), column.call("sport"), column.call("pun_derby"),
			column.call("classified")], "foot": "One line at the foot."}
	_check("an issue without a back page is valid", catalog._valid_back(null, "speaker", "test"))
	_check("four typed columns and a foot are valid", catalog._valid_back(good, "speaker", "test"))
	var errors_before := catalog.errors.size()
	var short := good.duplicate(true)
	short.columns.pop_back()
	_check("three columns are refused", not catalog._valid_back(short, "speaker", "test"))
	_check("a kind from the other paper is refused", not catalog._valid_back(good, "record", "test"))
	var long_foot := good.duplicate(true)
	long_foot.foot = "Two\nlines"
	_check("a two-line foot is refused", not catalog._valid_back(long_foot, "speaker", "test"))
	catalog.errors.resize(errors_before)
	var boxes := catalog.ads_for("speaker", "1928-11-10")
	_check("the back carries six advertisements, the same ones each time the day is read",
			boxes.size() == NewspaperCatalog.ADS_PER_PAGE and boxes == catalog.ads_for("speaker", "1928-11-10"))
	_check("no advertisement runs in the wrong paper", catalog.ads_for("record", "1928-11-10").all(
			func(ad): return str(ad.paper) in ["record", "both"]))
	_check("only the Speaker runs the cartoon", catalog.cartoon_for("record", "1928-11-11").is_empty())
	_check("the first Sunday has its drawn cartoon", ResourceLoader.exists(str(catalog.cartoon_for("speaker", "1928-11-11").get("image", ""))))
	var panel := NewspaperPanel.new()
	add_child(panel)
	panel.open(null, catalog, "speaker", "1928-11-10")
	await get_tree().process_frame
	var plain_corner: Vector2 = panel._corner.get_global_rect().get_center()
	_check("every published sheet curls its corner", panel._corner.visible)
	await _press(plain_corner)
	await _drag(Vector2(-220, 0))
	await _press(plain_corner)
	await get_tree().process_frame
	var plain_back := _texts(panel)
	_check("a back with no columns of its own still carries the advertising", panel.side == "back"
			and _set_in(plain_back, str(boxes[0].headline)) and _set_in(plain_back, str(boxes[0].body)))
	var set_firm := catalog.firm_for(boxes[0])
	_check("each advertisement names its firm and says how to reach it",
			_set_in(plain_back, str(set_firm.name)) and _set_in(plain_back, str(set_firm.address))
			and _set_in(plain_back, str(set_firm.telephone)))
	_check("every style the book uses can be set", _every_style_sets(catalog))
	panel.close()
	await get_tree().process_frame
	catalog.issues["1928-11-10"].speaker.back = good
	catalog._cartoons["1928-11-10"] = {"image": "res://assets/ui/telegram/telegram_paper_stock_v1.png",
			"caption": "A sample caption under the drawing."}
	panel = NewspaperPanel.new()
	add_child(panel)
	panel.open(null, catalog, "speaker", "1928-11-10")
	await get_tree().process_frame
	_check("a sheet opens on its front", panel._corner.visible and panel.side == "front")
	var corner: Vector2 = panel._corner.get_global_rect().get_center()
	print("NEWSPAPER INPUT GEOMETRY ",JSON.stringify({"viewport":str(get_viewport().get_visible_rect()),"corner":str(panel._corner.get_global_rect()),"outside_click":str(Vector2(40,40))}))
	_check("outside click and corner are distinct visible targets",not panel._corner.get_global_rect().has_point(Vector2(40,40)) and get_viewport().get_visible_rect().has_point(corner))
	await _press(Vector2(40, 40))
	_check("a click away from the corner takes nothing", not panel._gripped)
	await _press(corner)
	_check("a click takes the corner", panel._gripped)
	await _drag(Vector2(-100, 0))
	_check("a short drag stays on the front", panel.side == "front" and panel._gripped)
	await _press(corner)
	_check("the next click lets go short of halfway, on the front", not panel._gripped and panel.side == "front")
	await _press(corner)
	await _drag(Vector2(-220, 0))
	_check("past halfway the back comes round", panel.side == "back")
	await _press(corner)
	await get_tree().process_frame
	var texts := _texts(panel)
	_check("the back prints its kinds, heads, bodies and foot", texts.has("PUN DERBY")
			and texts.has("A NEWS HEADLINE") and texts.has("A classified body.")
			and texts.has("One line at the foot."))
	_check("the front has gone from the sheet", not texts.has("HOOVER WINS BY A HAIR, LOSES BY A WIRE"))
	_check("the week's cartoon hangs over its caption", panel._page.find_child("Cartoon", true, false) is TextureRect
			and texts.has("A sample caption under the drawing."))
	_check("the advertising is boxed on the back", panel._page.find_child("Advertising", true, false) != null
			and _set_in(texts, str(boxes[0].headline)))
	var shots:=OS.get_environment("SHOT_DIR")
	if not shots.is_empty() and DisplayServer.get_name()!="headless":
		DirAccess.make_dir_recursive_absolute(shots)
		await RenderingServer.frame_post_draw
		_check("turned back page capture saves",get_viewport().get_texture().get_image().save_png(shots.path_join("newspaper_turned_back.png"))==OK)
	await _press(corner)
	await _drag(Vector2(-320, 0))
	await _press(corner)
	await get_tree().process_frame
	_check("the sheet turns back to the front", panel.side == "front"
			and _texts(panel).has("HOOVER WINS BY A HAIR, LOSES BY A WIRE"))
	panel.close()
	catalog.issues["1928-11-10"].speaker.erase("back")
	catalog._cartoons.erase("1928-11-10")
	await get_tree().process_frame


func _press(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var up: InputEventMouseButton = event.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _drag(by: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = by
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


static func _texts(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		out.append_array(_texts(child))
	return out


func _input_ownership(catalog: NewspaperCatalog) -> void:
	var before := Input.mouse_mode
	var callbacks := [0]
	var on_closed := func():callbacks[0]+=1
	var panel := NewspaperPanel.new();add_child(panel)
	panel.open(null,catalog,"speaker","1928-11-10",on_closed)
	# Refreshing the same reader keeps the original input lease.
	panel.open(null,catalog,"speaker","1928-11-10",on_closed)
	panel.close();panel.close()
	_check("a pointer-mode reader returns its original cursor without capture",Input.mouse_mode==before)
	_check("duplicate close cannot repeat the reading callback",callbacks[0]==1)
	await get_tree().process_frame
	var reader := PlayerController.new()
	reader.call_locked=true
	panel=NewspaperPanel.new();add_child(panel);panel.open(reader,catalog,"speaker","1928-11-10");panel.close()
	_check("closing a reader preserves an existing protected conversation",reader.protected_input_active())
	reader.free()
	await get_tree().process_frame
	reader=PlayerController.new()
	var text_owner:=Node.new();reader.text_input_owner=text_owner
	panel=NewspaperPanel.new();add_child(panel);panel.open(reader,catalog,"speaker","1928-11-10");panel.close()
	_check("a companion text lease does not become a sticky protected lock",reader.call_locked and not reader.protected_input_active())
	text_owner.free();reader.text_input_owner=null
	_check("ending the original text lease leaves no newspaper lock",not reader.call_locked)
	reader.free()
	await get_tree().process_frame
	reader=PlayerController.new()
	panel=NewspaperPanel.new();add_child(panel);panel.open(reader,catalog,"speaker","1928-11-10")
	reader.free();panel.close()
	_check("a retired reading owner can close without taking the pointer",Input.mouse_mode==before)
	await get_tree().process_frame
	panel=NewspaperPanel.new();add_child(panel);panel.open(null,catalog,"speaker","1928-11-10")
	get_tree().paused=true;panel.close()
	_check("closing during pause leaves the pointer available",Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	get_tree().paused=false
	await get_tree().process_frame

	reader=PlayerController.new()
	panel=NewspaperPanel.new();add_child(panel);panel.open(reader,catalog,"speaker","1928-11-10")
	panel.queue_free();await get_tree().process_frame
	_check("external reader retirement releases only its own input lock",not reader.call_locked and Input.mouse_mode==before)
	reader.free()


## Typesetting may change a line's case or join it to another; the words stay.
func _set_in(texts: Array, wanted: String) -> bool:
	var plain := " ".join(PackedStringArray(texts)).to_lower()
	return plain.contains(wanted.to_lower())


func _every_style_sets(catalog: NewspaperCatalog) -> bool:
	for ad: Dictionary in catalog._ads:
		var set_ad: Control = NewspaperAd.build(ad, catalog.firm_for(ad))
		if set_ad == null or set_ad.get_child_count() == 0:
			return false
		set_ad.free()
	return true
