extends "res://tests/carried_case_route_test.gd"
## A real player hand, case input and isolated primary generation. Since ruling
## held_books_reading_20261125 a click takes a closed copy into the case and the hand,
## a click with it in the glove brings it up to read, and a click on its shelf puts it
## back in the next free place.

const Book := preload("res://scripts/props/v2_readable_book.gd")

var checks: Array[Dictionary] = []
var route_completed := false


func _require(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	return super._require(ok, label)


func _prepare_campaign() -> bool:
	return _require(DisplayServer.get_name() != "headless",
		"the book route uses a rendered input viewport") and super._prepare_campaign()


func _run() -> void:
	var started := Time.get_ticks_msec()
	await super._run()
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		_write_contract(directory, started)
	get_tree().quit(0 if route_completed and failures.is_empty() else 1)


func _write_contract(directory: String, started: int) -> void:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array = []
	var digest: Array = []
	if not _require(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head) == 0
			and not head.is_empty(), "contract resolves the repository head"):
		return
	if not _require(OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root],
			digest) == 0 and not digest.is_empty(), "contract resolves the runtime input digest"):
		return
	var scene := get_tree().current_scene.scene_file_path
	var script: String = get_script().resource_path
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if not _require(file != null, "contract output opens"):
		return
	var passed := route_completed and failures.is_empty()
	file.store_string(JSON.stringify({
		"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2",
		"production_runtime": true,
		"scope": "Installed nook copy and player valise. Full capacity refusal, physical identity through disk reconstruction, glove reading, save during reading, Space close and next free shelf placement.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false,
			"elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": {"test_path": "game/" + script.trim_prefix("res://"),
			"test_sha256": FileAccess.get_sha256(script),
			"test_scene_path": "game/" + scene.trim_prefix("res://"),
			"test_scene_sha256": FileAccess.get_sha256(scene),
			"repository_head": str(head[0]).strip_edges(),
			"runtime_inputs_sha256": str(digest[0]).strip_edges()},
		"contracts": {"held_book_valise_read_shelve": {"executed": route_completed,
			"status": "PASS" if passed else "FAIL"}},
		"checks": checks, "failures": failures,
	}, "	"))
	file.flush()
	_require(file.get_error() == OK, "contract output was written")


func _init() -> void:
	route_label = "BOOK VALISE ROUTE"


func _route() -> void:
	var view: Node = world.carried_case_view
	var collections := get_tree().get_nodes_in_group("v2_library_collections")
	var copies: Array[Book] = []
	for collection: Node in collections:
		for copy: Book in collection._books.values():
			if copy.title_id == "missing" and copy.opening == 0.0:
				copies.append(copy)
	if not _require(copies.size() == 2 and copies[0].shelf == copies[1].shelf,
			"the installed nook supplies two closed copies of the thickest binding"):
		return
	var original := copies[0]
	var sibling := copies[1]
	var collection := str(original.shelf.name)
	var item := CarriedCase.library_item(collection, original.stock_id)
	var sibling_item := CarriedCase.library_item(collection, sibling.stock_id)
	var sibling_pose := sibling.transform
	var path := "user://book_valise_%d.save" % OS.get_process_id()
	RealityState.save_path = path
	RealityState.persistence_enabled = true
	var catalog := get_tree().get_first_node_in_group("newspaper_catalog") as NewspaperCatalog
	if not _require(catalog != null and not catalog.papers.is_empty() and not catalog.issues.is_empty(),
			"the original newspaper catalogue is available"):
		return
	var paper_id := str(catalog.papers.keys()[0])
	var date := str(catalog.issues.keys()[0])
	var news := NewspaperCatalog.key_of(paper_id, date)
	if not _require(PersonInventory.carry_goods(PersonInventory.PLAYER, "route_tin", "Pipe tobacco", "tin") \
			and catalog.collect_uncommitted(paper_id, date) and PaperPocket.tuck_news(news) \
			and PaperPocket.tuck_comic("lilith_01") and PaperPocket.file_evidence("case_route", "A note", "A note in the case.") \
			and RealityState.save_game(), "the isolated primary contains goods, a comic, a letter and a newspaper"):
		return

	# Use a clear station near the normal runtime spawn. Setup moves the
	# original stock, then the ordinary player ray and click pick it up.
	var camera_pose := player.camera.global_transform
	original.global_transform = Transform3D(camera_pose.basis,
		camera_pose * Vector3(0.0, 0.0, -0.62) - camera_pose.basis * original.pickup_centre())
	original.shelf_slot = -1
	await get_tree().physics_frame
	await get_tree().physics_frame
	RealityState.flush_background_saves()
	if not _full_valise_denies_book(original, item, path):
		return
	var before := FileAccess.get_file_as_bytes(path)
	var fault := {"hits": 0}
	var refuse_case_write := func(stage: String, operation: String, arguments: Dictionary) -> Variant:
		if stage != "temp_write" or operation != "write" or arguments.get("path") != path + ".tmp":
			return null
		var bytes: PackedByteArray = arguments.bytes
		var candidate: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if candidate is not Dictionary or not candidate.get(CarriedCase.KEY, {}).get("places", {}).has(item):
			return null
		fault.hits += 1
		return {"ok":false, "error":ERR_FILE_CANT_WRITE}
	RealityState.storage_operation_override = refuse_case_write
	player.use_primary_interaction()
	RealityState.storage_operation_override = Callable()
	if not _require(fault.hits == 1 and player.held_stock_body() == null and original.visible \
			and not original.valise_packed and CarriedCase.place_of(item).is_empty() and CarriedCase.hand().is_empty() \
			and FileAccess.get_file_as_bytes(path) == before, "a refused write leaves the copy where it lay and the primary unchanged"):
		return
	player.use_primary_interaction()
	if not _require(player.held_stock_body() == null and original.valise_packed and not original.visible \
			and CarriedCase.hand() == item and not CarriedCase.place_of(item).is_empty() \
			and sibling.visible and sibling.transform.is_equal_approx(sibling_pose) \
			and CarriedCase.place_of(sibling_item).is_empty(),
			"the ordinary click takes only the original copy into the case and the hand"):
		return
	await _glove_wears(item, true)
	await _capture_interaction("original_copy_in_glove")
	await _key(KEY_TAB)
	await get_tree().create_timer(0.65).timeout
	if not _require(view.opened and view.settled and view._stacks.has(item) and original.valise_packed \
			and not original.visible, "Tab opens the case on the packed copy"):
		return
	var cover: Label3D = view._stacks[item].find_child("CoverTitle", true, false)
	if not _require(cover != null and cover.text == str(original.entry.title) and cover.is_visible_in_tree(),
			"the case retains the original binding title"):
		return
	await _capture_interaction("original_copy_in_valise")
	var place := CarriedCase.place_of(item).duplicate()
	if not _require(int(place.x) > 0 and int(place.y) == 0 and not bool(place.turned) and view._papers.size() == 3,
			"the thick binding uses a square beside the occupied comic pocket"):
		return
	await _key(KEY_TAB)
	await _capture_interaction("occupied_valise_closing")
	await get_tree().create_timer(0.45).timeout
	await _key(KEY_TAB)
	await get_tree().create_timer(0.65).timeout
	var size := CarriedCase.form_size(str(place.form), bool(place.turned))
	await _press(_screen(view, float(place.x) + size.x * 0.5, float(place.y) + size.y * 0.5))
	var tin := CarriedCase.place_of("route_tin")
	await _press(_screen(view, float(tin.x) + 0.5, float(tin.y) + 0.5))
	if not _require(view.held_item == item and CarriedCase.place_of(item) == place,
			"ordinary goods refuse an occupied placement and keep the book in the case hand"):
		return
	await _press(_pointer_free(view), MOUSE_BUTTON_RIGHT)
	if not _require(view._held_turned != bool(place.turned), "ordinary turn input rotates the carried binding"):
		return
	var rotated_target := _pointer_free(view)
	RealityState.flush_background_saves()
	var before_move := FileAccess.get_file_as_bytes(path)
	fault.hits = 0
	RealityState.storage_operation_override = refuse_case_write
	await _press(rotated_target)
	RealityState.storage_operation_override = Callable()
	if not _require(fault.hits == 1 and view.held_item == item and CarriedCase.place_of(item) == place \
			and FileAccess.get_file_as_bytes(path) == before_move, "refused grid write keeps the prior square and case hand"):
		return
	await _press(rotated_target)
	if not _require(view.held_item.is_empty(), "the rotated book can settle on legal cells"):
		return
	place = CarriedCase.place_of(item).duplicate()
	await _key(KEY_TAB)
	await get_tree().create_timer(0.45).timeout
	RealityState.load_game()
	await get_tree().physics_frame
	# JSON numbers reopen as floats. Compare with the persisted form while
	# retaining exact checks for the collection, physical copy and turn.
	var persisted_place: Dictionary = JSON.parse_string(JSON.stringify(place))
	var reloaded := _require(RealityState.can_continue(), "the saved book campaign reopens normally")
	reloaded = _require(CarriedCase.place_of(item) == persisted_place,
		"disk reload restores the original collection, copy and grid cells") and reloaded
	reloaded = _require(original.valise_packed and not original.visible and sibling.visible,
		"disk reload hides only the packed original body") and reloaded
	reloaded = _require(PaperPocket.has_comic("lilith_01") and PaperPocket.transit_news() == news,
		"disk reload preserves comic and newspaper custody") and reloaded
	if not reloaded:
		return
	place = persisted_place
	var retired_copy: WeakRef = weakref(original)
	var retired_sibling: WeakRef = weakref(sibling)
	var copy_id := original.stock_id
	var sibling_id := sibling.stock_id
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	world = Runtime.instantiate()
	add_child(world)
	if not _require(not world.startup_failed and RealityState.can_continue(),
			"the packed campaign reconstructs in a fresh production world"):
		return
	player = world.player
	player.camera.make_current()
	view = world.carried_case_view
	original = world.household_state.packed_book(item)
	if not _require(is_instance_valid(original) and original.stock_id == copy_id,
			"the reconstructed case resolves the original physical copy identity"):
		return
	sibling = original.shelf.book_copy(sibling_id)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not _require(retired_copy.get_ref() == null and retired_sibling.get_ref() == null \
			and original.valise_packed and not original.visible and sibling.visible \
			and CarriedCase.place_of(item) == persisted_place,
			"fresh reconstruction retires the old bodies and retains one packed copy"):
		return

	if not _require(CarriedCase.hand() == item, "the hand still names the packed copy after reconstruction"):
		return
	await _glove_wears(item, true)
	# Aim at open air above the spawn: a click on nothing usable reads the held book.
	player.camera.rotation.x = 1.25
	for frame in 3:
		await get_tree().physics_frame
	var obstruction := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var block := BoxShape3D.new()
	block.size = Vector3(0.12, 0.12, 0.12)
	collider.shape = block
	obstruction.add_child(collider)
	world.add_child(obstruction)
	var eye := player.camera.global_transform
	obstruction.global_position = original._hold_target(eye, false) + eye.basis * original.pickup_centre()
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.use_primary_interaction()
	if not _require(not player.inspecting() and original.valise_packed and not original.visible \
			and CarriedCase.hand() == item and CarriedCase.place_of(item) == place,
			"a blocked hold leaves the book packed in the glove"):
		return
	obstruction.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.use_primary_interaction()
	if not _require(player.inspecting() and original.hand_reading and original.visible and not original.valise_packed \
			and CarriedCase.hand() == item and CarriedCase.place_of(item) == place,
			"a click with the book in the glove brings it up into the reading view"):
		return
	await RenderingServer.frame_post_draw
	var glove: Node = _avatar().get("glove_slot") if _avatar() != null else null
	_require(not is_instance_valid(glove) or glove.part() == null or not glove.part().visible,
		"the glove's copy is out of sight while the book is read")
	for frame in 100:
		await get_tree().physics_frame
	var leaf: Vector3 = original.left.to_global(Vector3(float(original.construction.width) * .7,
		float(original.construction.height) * .7, float(original.construction.thickness) * .5))
	var expected_pixel := player.camera.unproject_position(leaf).round()
	await _motion(expected_pixel)
	if not _require(get_viewport().get_mouse_position().distance_to(expected_pixel) < .6,
			"embedded cursor reaches the floating cover pixel"):
		return
	player.use_primary_interaction()
	if not _require(player._grab.active() and player._grab.target.part == original.left and player._grab.target.kind == "hinge",
			"the free cursor grabs the floating cover"):
		return
	_require(await _hinge(1.4), "mouse motion opens the cover past the reading angle")
	player.use_primary_interaction()
	if not _require(not player._grab.active() and original.opening >= Book.READ_OPENING,
			"a second click lets go of the opened cover"):
		return
	await _capture_interaction("original_copy_read_from_glove")
	RealityState.save_game()
	RealityState.flush_background_saves()
	var reading_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var record: Dictionary = reading_save.v2_household_controls.records[collection].value.books[original.stock_id]
	if not _require(reading_save[CarriedCase.KEY].places.has(item) and int(record.slot) == -1 \
			and float(record.opening) == 0.0, "a save while reading keeps the book packed and closed"):
		return
	await _key(KEY_SPACE)
	await get_tree().physics_frame
	if not _require(not player.inspecting() and not original.hand_reading and original.valise_packed \
			and not original.visible and original.opening == 0.0 and CarriedCase.hand() == item \
			and CarriedCase.place_of(item) == place, "closing the reading view packs the book back into the glove"):
		return
	await _glove_wears(item, true)

	# Approach from the installed nook route's known standing position.
	# Aim at the exposed stock faces and let the ordinary ray select the shelf.
	var shelf: Node3D = original.shelf
	player.camera.rotation.x = 0.0
	player.global_position = world.adapter.root.to_global(Vector3(-0.48, -3.159, 2.1))
	player.velocity = Vector3.ZERO
	for frame in 4:
		await get_tree().physics_frame
	var aimed: Dictionary = {}
	for book: Book in shelf._books.values():
		if not book.visible:
			continue
		var point := book.to_global(Vector3(-0.001, float(book.construction.height) * 0.65, 0.0))
		if player.camera.global_position.distance_to(point) > 2.1:
			continue
		player.camera.look_at(point)
		await get_tree().physics_frame
		aimed = player._grab.find_target()
		if str(aimed.get("put_back", "")) == original.stock_id:
			break
	if str(aimed.get("put_back", "")) != original.stock_id:
		var shelf_hit: Node = player._grab.last_hit.get("collider") as Node
		print("BOOK SHELVE RAY: eye=", player.camera.global_position, " shelf=", shelf.global_position,
			" hit=", str(shelf_hit.get_path()) if is_instance_valid(shelf_hit) else "",
			" descriptor=", aimed.keys())

	if not _require(str(aimed.get("put_back", "")) == original.stock_id, "aiming at the shelf offers the held book's place"):
		return
	player.use_primary_interaction()
	await get_tree().physics_frame
	if not _require(not original.valise_packed and original.visible and original.shelf_slot >= 0 \
			and CarriedCase.place_of(item).is_empty() and CarriedCase.hand().is_empty() \
			and original.transform.is_equal_approx(shelf.book_slots[original.shelf_slot]),
			"a click on the shelf puts the book in its next free place"):
		return
	await _glove_wears("", false)
	await _capture_interaction("original_copy_shelved")
	RealityState.flush_background_saves()
	var shelved_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	record = shelved_save.v2_household_controls.records[collection].value.books[original.stock_id]
	route_completed = _require(not shelved_save[CarriedCase.KEY].places.has(item)
			and int(record.slot) == original.shelf_slot, "the save records the shelved copy in its slot")


func _full_valise_denies_book(book: Book, item: String, path: String) -> bool:
	var fillers: Array[String] = []
	var grid := CarriedCase.grid()
	for index in grid.x * grid.y:
		var filler := "book_route_filler_%d" % index
		if not PersonInventory.carry_goods(PersonInventory.PLAYER, filler, "Test packet"):
			break
		fillers.append(filler)
	var full := CarriedCase.library_fit(str(book.shelf.name), book.stock_id).is_empty()
	var before := FileAccess.get_file_as_bytes(path)
	var pose := book.transform
	var target: Dictionary = player._grab.find_target()
	player.use_primary_interaction()
	var stayed: bool = (bool(target.get("blocked", false)) and not player._grab.active() and book.visible
		and not book.valise_packed and book.transform == pose and CarriedCase.hand().is_empty()
		and CarriedCase.place_of(item).is_empty() and FileAccess.get_file_as_bytes(path) == before)
	for filler in fillers:
		PersonInventory.spend_goods(PersonInventory.PLAYER, filler, false)
	return _require(full and stayed, "a full valise leaves the closed book in place with no carry or save write")


# A hidden Windows desktop cannot reliably deliver native free-cursor
# coordinates. The embedded viewport owns its input pointer, while the
# player still resolves selections and interaction through the real ray.
func _motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)
	await get_tree().process_frame


func _press(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	await _motion(at)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = button
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
		await get_tree().process_frame


func _avatar() -> Node:
	return world.find_child("ReflectedPlayer", true, false)


## The mirror hand and the hose arm's glove both show what the hand holds.
func _glove_wears(item: String, shown: bool) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var avatar := _avatar()
	var glove: Node = avatar.get("glove_slot") if avatar != null else null
	if not is_instance_valid(glove):
		_require(false, "the hose arm's glove has a held slot")
		return
	var part: Node3D = glove.part()
	_require(glove.worn == item and avatar.hand_slot.worn == item and (part != null) == shown \
		and (not shown or part.visible), "the glove and the mirror hand show " + (item if shown else "nothing"))


func _hinge(goal: float) -> bool:
	var stalled := 0
	for frame in 160:
		if not player._grab.active():
			return false
		var target: Dictionary = player._grab.target
		var before: float = target.read.call()
		if absf(goal - before) < .00001 or (goal > before and before >= goal - .02):
			return true
		var point: Vector3 = target.part.to_global(player._grab.contact)
		var axis: Vector3 = target.frame.global_basis * (target.axis.call() if target.axis is Callable else target.axis)
		var tangent: Vector3 = axis.cross(point - target.part.global_position)
		if tangent.length() < float(target.get("minimum_lever", .025)):
			tangent = axis.cross(player.camera.global_basis.x) * .06
		var screen: Vector2 = (player.camera.unproject_position(point + tangent * .01) - player.camera.unproject_position(point)) / .01
		if screen.length() < 24. and absf(tangent.dot(player.camera.global_basis.z)) > tangent.length() * .5:
			screen = Vector2(0, tangent.dot(player.camera.global_basis.z) * 180.)
		var event := InputEventMouseMotion.new()
		event.relative = screen * clampf(goal - before, -.12, .12)
		player._unhandled_input(event)
		await get_tree().physics_frame
		stalled = stalled + 1 if is_equal_approx(before, float(target.read.call())) else 0
		if stalled > 8:
			print("BOOK HINGE STOP: wanted=", goal, " actual=", target.read.call())
			return before >= goal * .5
	return false
