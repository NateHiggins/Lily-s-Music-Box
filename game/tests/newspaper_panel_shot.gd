extends Node
## Visual proof for the front page: masthead, date line and ears, the lead in
## capitals, three columns, the late wire, on the telegram paper. Saves one
## frame of each paper's first issue and the desk shelf, then exits 0.

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 9 * 60)
	var catalog := NewspaperCatalog.new()
	add_child(catalog)
	await get_tree().process_frame
	var out_dir := OS.get_environment("SHOT_DIR")
	if out_dir == "":
		out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ok := catalog.errors.is_empty()
	for paper_id in ["record", "speaker"]:
		var panel := NewspaperPanel.new()
		add_child(panel)
		panel.open(null, catalog, paper_id, "1928-11-10")
		for _frame in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := out_dir.path_join("newspaper_%s.png" % paper_id)
		var error := get_viewport().get_texture().get_image().save_png(path)
		print("[NEWSPAPER SHOT] %s %s" % ["saved" if error == OK else "FAIL", path])
		ok = ok and error == OK
		panel.close()
		await get_tree().process_frame
	catalog.collect("record", "1928-11-10")
	catalog.collect("speaker", "1928-11-10")
	catalog.collect("speaker", "1928-11-12")
	var shelf := NewspaperPanel.new()
	add_child(shelf)
	shelf.open_shelf(null, catalog)
	for _frame in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shelf_path := out_dir.path_join("newspaper_shelf.png")
	var shelf_error := get_viewport().get_texture().get_image().save_png(shelf_path)
	print("[NEWSPAPER SHOT] %s %s" % ["saved" if shelf_error == OK else "FAIL", shelf_path])
	shelf.close()
	get_tree().quit(0 if ok and shelf_error == OK else 1)
