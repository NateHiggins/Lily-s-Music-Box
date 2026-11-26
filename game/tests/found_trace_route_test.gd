extends "res://tests/carried_case_route_test.gd"
## The four rooms are separate staging marks. Each measured last approach runs the
## ordinary controller, gravity, live collision and reticle in the installed world.
const Custody := preload("res://scripts/songbook/found_trace_custody.gd")
const Forge := preload("res://scripts/songbook/phonautogram_forge.gd")
const TRACE_IDS := ["trace_room0", "trace_two_voices", "trace_1610", "trace_unlabelled"]
var route_completed := false


func _init() -> void:
	route_label = "FOUND TRACE ROUTE"


func _prepare_campaign() -> bool:
	return _require(DisplayServer.get_name() != "headless", "mounted deposits use a rendered input viewport") and super._prepare_campaign()


func _run() -> void:
	var started := Time.get_ticks_msec()
	await super._run()
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		_write_contract(directory, started)
	get_tree().quit(0 if route_completed and failures.is_empty() else 1)


func _route() -> void:
	RealityState.save_path = "user://found_trace_route_%d.save" % OS.get_process_id()
	RealityState.persistence_enabled = true
	if not _require(RealityState.save_game(), "isolated campaign primary is writable"):
		return
	var deposits := {}
	for source: Node3D in get_tree().get_nodes_in_group("found_trace_sources"):
		if world.is_ancestor_of(source):
			if not _require(not deposits.has(str(source.name)), "unique mounted deposit " + str(source.name)):
				return
			deposits[str(source.name)] = source
	if not _require(deposits.size() == Forge.FOUND.size() and deposits.has_all(TRACE_IDS) and Custody.held_ids().is_empty(),
		"all four original traces start at separate mounted sources"):
		return
	for trace_id: String in TRACE_IDS:
		var source: Node3D = deposits[trace_id]
		# Each room has its own approach. Retain all four observations even
		# if a previous hand was interrupted or a support was unreachable.
		if player._grab.active():
			player._grab.release()
		if not await _approach_source(source):
			continue
		if not await _stroke(source, true):
			continue
		if trace_id == "trace_room0":
			if not await _select_in_case(trace_id) or not await _stroke(source, false) or not await _stroke(source, true):
				continue
	var snapshot: Variant = JSON.parse_string(FileAccess.get_file_as_string(RealityState.save_path))
	if not _require(snapshot is Dictionary and Custody.held_ids().size() == 4 and CarriedCase.valid(snapshot.get(CarriedCase.KEY)),
		"verified primary contains a valid case after the four source visits"):
		return
	for trace_id: String in TRACE_IDS:
		if not _require(snapshot[CarriedCase.KEY].places.has(Custody.item_id(trace_id)), "primary contains the actual " + trace_id):
			return
	route_completed = await _reader()


func _approach_source(source: Node3D) -> bool:
	# Stance pairs are ground points surveyed against the actual native support.
	var marks := _source_marks(str(source.name))
	if not _require(marks.size() == 2, "two surveyed floor marks exist for " + str(source.name)):
		return false
	return await _walk_up(marks[0], marks[1], str(source.name))


func _source_marks(id: String) -> Array[Vector3]:
	var frame: Node3D = world.adapter.root
	match id:
		"trace_room0":
			return [frame.to_global(Vector3(12.75, -3.2, 2.25)), frame.to_global(Vector3(12.75, -3.2, 1.32))]
		"trace_1610":
			return [frame.to_global(Vector3(-7.40, -3.2, .05)), frame.to_global(Vector3(-8.30, -3.2, .05))]
		"trace_two_voices":
			var desk := world.find_child("DeadLettersDesk", true, false) as Node3D
			if desk == null:
				return []
			return [desk.to_global(Vector3(.10, 0, 2.25)), desk.to_global(Vector3(.10, 0, 1.28))]
		"trace_unlabelled":
			var bar := world.bar_region
			return [bar.to_global(Vector3(5.03, .02, 28.30)), bar.to_global(Vector3(5.03, .02, 29.29))]
	return []


func _walk_up(start: Vector3, goal: Vector3, label: String) -> bool:
	player.global_position = start + Vector3.UP * .035
	player.velocity = Vector3.ZERO
	for frame in 3:
		await get_tree().physics_frame
	var from := player.global_position
	if not await _walk_world(goal):
		return false
	return _require(from.distance_to(player.global_position) > .60 and player.is_on_floor() and not player.noclip,
		"controller walks the final approach to " + label)


func _aim(at: Vector3) -> void:
	var heading := at - player.camera.global_position
	player.rotation.y = atan2(-heading.x, -heading.z)
	player.camera.look_at(at)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.camera.look_at(at)


func _click_world() -> void:
	var centre := get_viewport().get_visible_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = centre
		event.global_position = centre
		get_viewport().push_input(event, true)
		await get_tree().physics_frame


func _stroke(source: Node3D, packing: bool) -> bool:
	var trace_id := str(source.name)
	var target_area := source.find_child("Operable", true, false) as Area3D
	var shape := target_area.find_children("*", "CollisionShape3D", true, false) if target_area != null else []
	if not _require(shape.size() == 1, "one operable face at " + trace_id):
		return false
	var contact := (shape[0] as CollisionShape3D).global_position
	await _aim(contact)
	var grip: Dictionary = player._grab.find_target()
	if grip.get("owner") != source and not player.crouched:
		Input.action_press("crouch")
		await get_tree().process_frame
		await get_tree().process_frame
		Input.action_release("crouch")
		await _aim(contact)
		grip = player._grab.find_target()
	var collider: Node = player._grab.last_hit.get("collider")
	if not _require(grip.get("owner") == source, "the unobstructed reticle reaches %s from %s, hit %s" % [trace_id, player.global_position, collider.get_path() if collider != null else "none"]):
		return false
	if packing:
		await _capture_interaction("source_" + trace_id)
	await _click_world()
	if not _require(player._grab.active() and player._grab.target.get("owner") == source and Custody.is_packed(trace_id) != packing,
		"taking hold does not transfer " + trace_id):
		return false
	var before: float = player._grab.target.read.call()
	# The physical hand limits speed per event. Six successive mouse deltas form one stroke.
	for step in 6:
		var motion := InputEventMouseMotion.new()
		motion.position = get_viewport().get_visible_rect().get_center()
		motion.relative = Vector2(0, -20 if packing else 20)
		motion.screen_relative = motion.relative
		get_viewport().push_input(motion, true)
		await get_tree().physics_frame
	var after := float(player._grab.target.read.call()) if player._grab.active() else float(source.sheet.position.y)
	if not _require(player._grab.active() and absf(after - before) >= .10 and Custody.is_packed(trace_id) != packing,
		"%s hand stroke on %s before release (%.3f to %.3f m, latched %s)" % ["lift" if packing else "return", trace_id, before, after, player._grab.active()]):
		return false
	await _click_world()
	return _require(not player._grab.active() and Custody.is_packed(trace_id) == packing, "explicit release %s %s" % ["packs" if packing else "returns", trace_id])


func _select_in_case(trace_id: String) -> bool:
	var item := Custody.item_id(trace_id)
	var view: Node = world.carried_case_view
	await _key(KEY_TAB)
	await get_tree().create_timer(.7).timeout
	if not _require(view.opened and view.settled and view._stacks.has(item), "Tab opens the valise on the original sheet"):
		return false
	var place := CarriedCase.place_of(item)
	var size := CarriedCase.form_size(place.form, place.turned)
	var centre := Vector2(float(place.x), float(place.y)) + Vector2(size) * .5
	await _press(_screen(view, centre.x, centre.y))
	if not _require(view.held_item == item, "clicking the packed original selects its actual stack"):
		return false
	await _capture_interaction("selected_trace_in_valise")
	await _press(_screen(view, centre.x, CarriedCase.grid().y + 2.5))
	await get_tree().create_timer(.7).timeout
	return _require(not view.opened and not player.call_locked and CarriedCase.hand() == item and Custody.is_packed(trace_id), "bringing the selected trace out leaves its identity in the glove and case")


func _reader() -> bool:
	var bar := world.bar_region
	var terminal: Node3D = bar.actors.get_node_or_null("F01_BAR_SONGBOOK")
	if not _require(terminal != null, "the Harukiya has its songbook terminal"):
		return false
	if not await _walk_up(bar.to_global(GameBoot.b2g([-10.5,-34.15,-2.8])), bar.to_global(GameBoot.b2g([-10.5,-35.15,-2.8])), "Songbook"):
		return false
	var shapes := terminal.find_children("*", "CollisionShape3D", true, false)
	if not _require(not shapes.is_empty(), "the songbook has an input target"):
		return false
	await _aim((shapes[0] as CollisionShape3D).global_position)
	await _capture_interaction("harukiya_reader")
	await _click_world()
	var panel: Node = terminal.get("_panel")
	if not _require(is_instance_valid(panel) and player.call_locked, "the player's click opened the installed songbook"):
		return false
	await _panel_key(panel, KEY_4)
	if not _require(panel._trace_rows == Custody.held_ids() and panel._trace_rows.size() == 4, "the reader lists the four originals now in the valise"):
		return false
	await _panel_key(panel, KEY_1)
	if not _require(panel._read_from_old and panel._reader != null and panel._reader.playing, "the selected original plays through the historical trace reader"):
		return false
	await _panel_key(panel, KEY_SPACE)
	await _panel_key(panel, KEY_ESCAPE)
	await _panel_key(panel, KEY_ESCAPE)
	return _require(not player.call_locked, "leaving the reader returns normal control")


func _panel_key(panel: Node, key: Key) -> void:
	var viewport := panel.get_viewport()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		viewport.push_input(event, true)
		await get_tree().process_frame


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
		"scope": "Four fixed original trace deposits in the production V2 world. Each approach begins near its room, walks the last metres and uses the player hand. Case selection, return, reacquisition and Songbook playback use their installed interfaces.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false,
			"elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": {"test_path": "game/" + script.trim_prefix("res://"),
			"test_sha256": FileAccess.get_sha256(script),
			"test_scene_path": "game/" + scene.trim_prefix("res://"),
			"test_scene_sha256": FileAccess.get_sha256(scene),
			"repository_head": str(head[0]).strip_edges(),
			"runtime_inputs_sha256": str(digest[0]).strip_edges()},
		"contracts": {"found_trace_deposits_valise_and_reader": {"executed": route_completed,
			"status": "PASS" if passed else "FAIL"}},
		"checks": interaction_checks, "walks": trace, "failures": failures,
	}, "	"))
	file.flush()
	_require(file.get_error() == OK, "contract output was written")
