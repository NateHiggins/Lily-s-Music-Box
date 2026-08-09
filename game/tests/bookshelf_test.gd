extends Node
## The shelf family as an authored system: three silhouettes, two book
## surfaces, retained lifting doors and one covenant object that randomness
## is not permitted to erase.

var failures := 0


func _ready() -> void:
	for spec in [
		{"style": "plain", "owner": "Iris Bell", "doors": 0},
		{"style": "repaired", "owner": "Mina Vale", "doors": 0},
		{"style": "sectional", "owner": "Mae Kessler", "doors": 3},
	]:
		var shelf := BookshelfProp.new()
		shelf.owner_name = spec.owner
		shelf.case_style = spec.style
		if spec.style == "sectional":
			shelf.canonical_book = "prospectus"
		add_child(shelf)
		await get_tree().process_frame
		var state := shelf.inspection_state()
		_check(state.style == spec.style, "%s derives its own silhouette" % spec.style)
		_check(int(state.book_mesh_count) == 2,
				"%s batches all covers and pages into two meshes" % spec.style)
		_check(int(state.door_count) == int(spec.doors),
				"%s retains one moving door per tier" % spec.style)
		_check(int(state.mesh_count) <= 10 + int(spec.doors),
				"%s meets static cap plus one mesh per door (%d)" %
				[spec.style, int(state.mesh_count)])
		_check(float(state.active_book_top) < 1.41,
				"%s active run stays below player eye line" % spec.style)
		if spec.style == "sectional":
			_check(bool(state.has_canonical_book),
					"Mae's 1912 prospectus survives the random deal")
			shelf._door_target = 1.0
			await get_tree().create_timer(0.6).timeout
			_check(shelf._doors[0].position.y > 0.20,
					"sectional glass lifts without a room-side swing")
		shelf.queue_free()
		await get_tree().process_frame
	print("BOOKSHELF TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [shelf ok] ", label)
	else:
		failures += 1
		printerr("  [SHELF FAIL] ", label)
