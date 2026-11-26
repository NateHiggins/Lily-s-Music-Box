extends Node
## The four original physical traces, the Harukiya reader and a real disk generation.
## Isolated fixture. Source placement and walkability require the installed-world route.

const Trace := preload("res://scripts/songbook/found_trace_custody.gd")
const Forge := preload("res://scripts/songbook/phonautogram_forge.gd")
const Opening := preload("res://scripts/game/prologue_state.gd")
const Loop := preload("res://scripts/game/temporal_loop.gd")
const Economy := preload("res://scripts/game/caretaker_economy.gd")
const Terminal := preload("res://scripts/props/songbook_terminal_prop.gd")
const IDS := ["trace_room0", "trace_1610", "trace_two_voices", "trace_unlabelled"]
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var path: String
var refused_writes := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	if not ok:
		failures.append(label)
		push_error(label)
	return ok


func _run() -> void:
	var started := Time.get_ticks_msec()
	var old_data: Dictionary = RealityState.data
	var old_path: String = RealityState.save_path
	var old_persistence: bool = RealityState.persistence_enabled
	var old_mouse := Input.mouse_mode
	RealityState.flush_background_saves()
	path = "user://found_trace_%d_%d.save" % [OS.get_process_id(), Time.get_ticks_usec()]
	RealityState.save_path = path
	RealityState.persistence_enabled = true
	if _check(RealityState.start_new_campaign(), "new isolated campaign wrote its first generation"):
		_exercise()
	RealityState.flush_background_saves()
	RealityState.persistence_enabled = false
	RealityState.save_path = old_path
	RealityState.data = old_data
	RealityState.persistence_enabled = old_persistence
	Input.mouse_mode = old_mouse
	_write_contract(started)
	print("[FOUND TRACE CUSTODY] RESULT: %s (%d checks, %d failures)" % [
		"PASS" if failures.is_empty() else "FAIL", checks.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


func _exercise() -> void:
	var expected: Array = IDS.duplicate()
	var actual := Forge.found_ids()
	actual.sort()
	expected.sort()
	if not _check(actual == expected, "the four authored original identities are intact"):
		return
	var original_document := RealityState.data.duplicate(true)
	_check(Trace.held_ids().is_empty() and not Trace.is_packed(IDS[0])
			and RealityState.data == original_document, "an empty case lists no originals without mutating the campaign")
	_check(not Trace.take("unknown") and not Trace.return_to_source("unknown")
			and not Trace.is_packed("unknown"), "an unknown identity cannot be acquired or returned")
	_check(CarriedCase.form_size(CarriedCase.FOUND_TRACE_FORM) == Vector2i(5, 3)
			and CarriedCase.grid() == Vector2i(10, 6), "the measured sheet spans five by three case squares")
	for id: String in IDS:
		_check(Trace.item_id(id) == "found_trace:" + id, "the case key preserves " + id)
		if not _check(Trace.take(id) and Trace.is_packed(id), "take the unique original " + id):
			return
		_check(CarriedCase.place_of(Trace.item_id(id)).get("form") == CarriedCase.FOUND_TRACE_FORM,
				"a whole trace occupies its fitted footprint: " + id)
		_check(not Trace.take(id) and Trace.held_ids().count(id) == 1,
				"repeated pickup never duplicates " + id)
		_check(PersonInventory.goods_count(PersonInventory.PLAYER, Trace.item_id(id)) == 0,
				"the case owns the original without a separate goods stack: " + id)
	_check(Trace.held_ids().size() == IDS.size() and not CarriedCase.has_room("test_tin", "tin"),
			"four originals fill every square of an otherwise empty case")
	var corrupt := CarriedCase.book().duplicate(true)
	var key := Trace.item_id(IDS[0])
	corrupt.places[key].form = "tin"
	_check(not CarriedCase.valid(corrupt), "a trace cannot shrink into a forged one-square save record")
	corrupt = CarriedCase.book().duplicate(true)
	corrupt.places["found_trace:unknown"] = corrupt.places[key]
	corrupt.places.erase(key)
	_check(not CarriedCase.valid(corrupt), "an unknown trace identity is rejected during case validation")
	for id: String in IDS:
		if not _check(Trace.return_to_source(id) and not Trace.is_packed(id)
				and not Trace.return_to_source(id), "the source can recover its original exactly once: " + id):
			return
	if not _check(PersonInventory.carry_goods(PersonInventory.PLAYER, "trace_test_one_tin", "Test tin", "tin")
			and Trace.take(IDS[0]) and Trace.take(IDS[1]) and Trace.take(IDS[2]),
			"three sheets can fit alongside a single tin"):
		return
	_check(not Trace.take(IDS[3]) and Trace.held_ids().size() == 3,
			"even one occupied square leaves no room for the fourth original")
	for id: String in Trace.held_ids():
		if not _check(Trace.return_to_source(id), "clear the packed original after the capacity check: " + id):
			return
	PersonInventory.spend_goods(PersonInventory.PLAYER, "trace_test_one_tin", false)
	var filler: Array[String] = []
	for i in CarriedCase.grid().x * CarriedCase.grid().y:
		var item := "trace_test_tin_%d" % i
		if not PersonInventory.carry_goods(PersonInventory.PLAYER, item, "Test tin", "tin"):
			break
		filler.append(item)
	if not _check(not filler.is_empty() and not CarriedCase.has_room("test_sheet", CarriedCase.FOUND_TRACE_FORM)
			and RealityState.save_game(), "an ordinarily filled case has no contiguous sheet footprint"):
		return
	var full := FileAccess.get_file_as_bytes(path)
	_check(not Trace.take(IDS[0]) and Trace.held_ids().is_empty()
			and full == FileAccess.get_file_as_bytes(path), "the full case leaves the source and save intact")
	for item in filler:
		PersonInventory.spend_goods(PersonInventory.PLAYER, item, false)
	if not _check(RealityState.save_game(), "the normal case can save after making room"):
		return
	_refuse_transaction(IDS[0], false)
	if not _check(Trace.take(IDS[0]), "retry acquires the original after storage recovers"):
		return
	_refuse_transaction(IDS[0], true)
	RealityState.load_game()
	_check(RealityState.can_continue() and Trace.held_ids() == [IDS[0]],
			"normal Continue recovers only the original on the admitted primary")
	if not _reader_route(IDS[0]):
		return
	_temporal_route()


func _fail_write(stage: String, operation: String, args: Dictionary) -> Variant:
	if stage == "temp_write" and operation == "write" and args.get("path") == path + ".tmp":
		refused_writes += 1
		return {"ok": false, "error": ERR_FILE_CANT_WRITE}
	return null


func _refuse_transaction(id: String, packed: bool) -> void:
	RealityState.flush_background_saves()
	var bytes := FileAccess.get_file_as_bytes(path)
	var old_case: Dictionary = CarriedCase.book().duplicate(true)
	refused_writes = 0
	var original: Callable = RealityState.storage_operation_override
	RealityState.storage_operation_override = _fail_write
	var success: bool = Trace.return_to_source(id) if packed else Trace.take(id)
	RealityState.storage_operation_override = original
	_check(not success and refused_writes == 1 and Trace.is_packed(id) == packed
			and CarriedCase.book() == old_case and FileAccess.get_file_as_bytes(path) == bytes,
			"a refused %s rolls back the live case and primary" % ("return" if packed else "pickup"))


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_viewport().push_input(event, true)


func _reader_route(id: String) -> bool:
	var terminal := Terminal.new()
	add_child(terminal)
	terminal.interact(null)
	var panel := terminal._panel as SongbookPanel
	if not _check(is_instance_valid(panel), "operate the real Harukiya songbook terminal"):
		return false
	_key(KEY_4)
	if not _check(panel.mode == SongbookPanel.Mode.OLD, "the terminal's fourth key opens the trace list"):
		return false
	_key(KEY_2)
	_check(panel.mode == SongbookPanel.Mode.OLD and panel._reader == null,
			"a number with no carried trace cannot start playback")
	_key(KEY_1)
	if not _check(panel.mode == SongbookPanel.Mode.READING and panel._read_is_trace
			and panel._reader != null and panel._reader.playing,
			"the first key reads the single packed original through the found-trace reader"):
		return false
	_key(KEY_SPACE)
	if not _check(panel.mode == SongbookPanel.Mode.OLD and Trace.return_to_source(id),
			"lifting the stylus returns to the list and the original can be put back"):
		return false
	_key(KEY_1)
	_check(panel.mode == SongbookPanel.Mode.OLD and not panel._reader.playing and panel._take == null,
			"an old selection cannot replay a trace that has left the case")
	panel.close()
	_check(terminal._panel == null, "the songbook releases the terminal")
	return true


func _temporal_route() -> void:
	var clock := CampaignClock.new()
	if not _check(clock.configure_date(1928, 11, 10, 1380), "the campaign clock accepts the fixture date"):
		return
	var opening := Opening.request_skip(Opening.initial())
	for i in Opening.PHASES.size() - 1:
		var phase: String = Opening.PHASES[i]
		if phase == "companion_crossing":
			opening = Opening.applied(opening, "companion_materialized")
		if phase == "temporal_command":
			opening = Opening.with_target(opening, {
				"utc_unix_seconds": 1856345696, "local_bias_minutes": -300, "local_zone": "Test"})
		if phase == "temporal_synchronization":
			break
		opening = Opening.advance(opening, Opening.PHASES[i + 1])
	RealityState.data.prologue = opening
	if not _check(clock.apply_prologue_destination(), "the normal prologue opens the investigation calendar"):
		return
	var economy := Economy.new()
	add_child(economy)
	var loop := Loop.new()
	add_child(loop)
	var old_id: String = IDS[2]
	var new_id: String = IDS[3]
	if not _check(loop.setup(clock, economy) and Trace.take(old_id) and loop.jump("tea").ok,
			"enter the real tea visit carrying one trace"):
		return
	if not _check(Trace.return_to_source(old_id) and Trace.take(new_id)
			and PersonInventory.carry_goods("lily", "trace_test_pick", "Test pick", "tin")
			and PersonInventory.goods_count("lily", "trace_test_pick") == 1,
			"an original is returned, another is found and a resident gains ordinary goods on the visit"):
		return
	if not _check(loop.go_home().ok and not loop.in_visit(), "the time loop restores the present"):
		return
	_check(PersonInventory.goods_count("lily", "trace_test_pick") == 0,
			"the resident's ordinary holding rewinds")
	_check(not Trace.is_packed(old_id) and Trace.held_ids() == [new_id],
			"return and discovery keep their physical case state across the jump home")
	RealityState.load_game()
	_check(RealityState.can_continue() and Trace.held_ids() == [new_id]
			and PersonInventory.goods_count("lily", "trace_test_pick") == 0,
			"the settled visit and its trace both survive normal disk reconstruction")


func _write_contract(started: int) -> void:
	var folder := OS.get_environment("SHOT_DIR")
	if folder.is_empty():
		return
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array = []
	var digest: Array = []
	var scene := scene_file_path
	var script: String = get_script().resource_path
	if not _check(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head) == 0
			and not head.is_empty() and OS.execute("python", [root.path_join("tools/run_receipt.py"),
			"digest", "--root", root], digest) == 0 and not digest.is_empty(), "receipt binds source"):
		return
	var output := folder.path_join("runtime_contract.json")
	if not _check(DirAccess.make_dir_recursive_absolute(folder) == OK and not FileAccess.file_exists(output),
			"receipt has its own new output"):
		return
	var file := FileAccess.open(output, FileAccess.WRITE)
	if not _check(file != null, "receipt opens"):
		return
	file.store_string(JSON.stringify({
		"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": false,
		"scope": "Isolated case, Songbook terminal keyboard reader, disk save and real temporal visit. No installed-world pickup or walking claim.",
		"execution": {"completed": true, "exit_code": 0 if failures.is_empty() else 1, "timed_out": false,
			"elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": {"repository_head": str(head[0]).strip_edges(), "runtime_inputs_sha256": str(digest[0]).strip_edges(),
			"test_path": "game/" + script.trim_prefix("res://"), "test_sha256": FileAccess.get_sha256(script),
			"test_scene_path": "game/" + scene.trim_prefix("res://"), "test_scene_sha256": FileAccess.get_sha256(scene)},
		"contracts": {"found_trace_custody": {"executed": true, "status": "PASS" if failures.is_empty() else "FAIL"}},
		"checks": checks, "failures": failures}, "\t"))
	file.flush()
	_check(file.get_error() == OK, "receipt flushes")
