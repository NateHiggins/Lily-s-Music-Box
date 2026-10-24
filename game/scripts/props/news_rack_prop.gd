class_name NewsRackProp
extends Node3D
## One `papers` control, two homes (design/ORISON_NEWSPAPERS_2026-10-23.md §6):
##
##   - "counter": the News & Cigars counter top. Interacting offers the two
##     papers for today and the few days the rack keeps; a paper taken is
##     collected at once and may be read there. Papers go on the desk account
##     like the mail: no coin changes hands.
##   - "desk": the player's desk in 4B. Interacting opens the shelf of kept
##     papers, newest first.
##
## The rack owns no newsprint: the catalogue answers what is on sale and what
## is kept; the panel reads.

var mode := "counter"
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


func _catalog() -> NewspaperCatalog:
	return get_tree().get_first_node_in_group("newspaper_catalog") as NewspaperCatalog


func control_prompt(control_id: String) -> String:
	if control_id != "papers" or _reading():
		return ""
	var catalog := _catalog()
	if catalog == null:
		return ""
	if mode == "desk":
		var kept := catalog.collected().size()
		return "Your papers" if kept == 0 else "Your papers (%d)" % kept
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
	if mode == "desk":
		_open_panel(player, catalog, "", "")
		return {}
	var offers := offers_for(catalog, catalog.today())
	if offers.is_empty():
		return {"title": "NEWS AND CIGARS", "body": "RACK EMPTY STOP NO PAPER TODAY STOP",
				"condition": "RACK BARE", "stamp": "SERVICE NOTE"}
	var options: Array = []
	for offer in offers:
		options.append({"text": str(offer.label), "evidence": bool(offer.kept),
				"action": func(): _take(player, catalog, str(offer.paper), str(offer.date))})
	options.append({"text": "Leave them.", "silent": true, "action": Callable()})
	if player != null and "call_locked" in player:
		player.call_locked = true
	_chooser.present("NEWS AND CIGARS", "The rack, %s. Both papers, and a few days back."
			% catalog.long_date(catalog.today()), options)
	return {}


## The rack's offers for a date: both papers for it and each day the rack
## keeps before it, newest first; at most eight so the replies stay on the
## number keys with "Leave them" ninth.
static func offers_for(catalog: NewspaperCatalog, date: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for day in catalog.on_sale(date):
		for paper_id in NewspaperCatalog.PAPER_IDS:
			if out.size() >= 8:
				return out
			var kept := catalog.is_collected(paper_id, day)
			out.append({"paper": paper_id, "date": day, "kept": kept,
					"label": "%s, %s%s" % [str(catalog.paper(paper_id).get("name", paper_id)),
							catalog.short_date(day), " (kept)" if kept else ""]})
	return out


func _take(player: Node, catalog: NewspaperCatalog, paper_id: String, date: String) -> void:
	catalog.collect(paper_id, date)
	_open_panel(player, catalog, paper_id, date)


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
