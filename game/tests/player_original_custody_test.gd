extends Node
## Save authority in an isolated campaign. This fixture supplies identified editions
## at admission. It never creates a microphone, opens media, or enumerates the profile.
const Originals := preload("res://scripts/songbook/player_original_custody.gd")
const Case := preload("res://scripts/game/carried_case.gd")
const Found := preload("res://scripts/songbook/found_trace_custody.gd")
const Opening := preload("res://scripts/game/prologue_state.gd")
const Loop := preload("res://scripts/game/temporal_loop.gd")
const Economy := preload("res://scripts/game/caretaker_economy.gd")
const SONG := "last_train_home"
const A := "last_train_home_19290613_162000_001"
const B := "last_train_home_19290613_162000_002"
const C := "last_train_home_19290613_162000_003"
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


func _edition(id: String) -> Dictionary:
	return {"version_id": id, "base_song_id": SONG, "publish": "PRIVATE"}


func _run() -> void:
	var started := Time.get_ticks_msec()
	RealityState.flush_background_saves()
	var previous_path: String = RealityState.save_path
	var previous_live: Dictionary = RealityState.data
	var previous_persistence: bool = RealityState.persistence_enabled
	path = "user://player_original_custody_" + Crypto.new().generate_random_bytes(12).hex_encode() + ".save"
	RealityState.save_path = path
	RealityState.persistence_enabled = true
	if _check(RealityState.start_new_campaign(), "first isolated campaign writes a generation"):
		_exercise()
	RealityState.flush_background_saves()
	RealityState.persistence_enabled = false
	RealityState.save_path = previous_path
	RealityState.data = previous_live
	RealityState.persistence_enabled = previous_persistence
	_write_contract(started)
	print("[PLAYER ORIGINAL CUSTODY] RESULT: %s (%d checks, %d failures)" % [
		"PASS" if failures.is_empty() else "FAIL", checks.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


func _exercise() -> void:
	var old := RealityState.data.duplicate(true)
	_check(Case.valid({"version": 1, "places": {}}) and Originals.tray_ids().is_empty()
			and Originals.packed_ids().is_empty() and Originals.song_id(A).is_empty()
			and RealityState.data == old, "older campaigns need no edition index to be opened or inspected")
	_check(not Originals.admit({"version_id": A, "base_song_id": SONG, "publish": "COMMUNITY"})
			and not Originals.admit(_edition("../" + A)) and not Originals.admit(_edition("wrong_19290613_162000_001"))
			and not Originals.take(A) and not Originals.return_to_tray(A) and RealityState.data == old,
			"public, mismatched, path-like and unadmitted rows cannot grant an original")
	_refuse(Originals.admit.bind(_edition(A)), "first admission", true)
	if not _check(Originals.admit(_edition(A)) and Originals.admit(_edition(B))
			and Originals.tray_ids() == [A, B] and Originals.top_id() == B, "private editions arrive newest on top"):
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	_check(Originals.admit(_edition(A)) and Originals.top_id() == B and Originals.tray_ids() == [A, B]
			and not Originals.take(A) and bytes == FileAccess.get_file_as_bytes(path),
			"retry after admission preserves tray order; a covered original cannot be taken")
	_refuse(Originals.take.bind(B), "taking the top")
	if not _check(Originals.take(B) and Originals.take(A) and Originals.packed_ids().size() == 2
			and Originals.tray_ids().is_empty() and Case.form_size(Case.place_of(Originals.item_id(B)).form) == Vector2i(5, 3),
			"real printed originals fill distinct 5 by 3 footprints"):
		return
	bytes = FileAccess.get_file_as_bytes(path)
	_check(Originals.admit(_edition(B)) and not Originals.take(B) and Originals.is_packed(B)
			and Originals.tray_ids().is_empty() and FileAccess.get_file_as_bytes(path) == bytes,
			"repeated KEEP and pickup do not duplicate the packed edition or create a generation")
	_check(Originals.id_from_item("found_trace:trace_1610").is_empty()
			and Originals.id_from_item(Originals.item_id(B)) == B
			and PersonInventory.goods_count(PersonInventory.PLAYER, Originals.item_id(B)) == 0,
			"recording identity is separate from historical sheets and ordinary goods")
	_invalid_cases()
	# Both sheets went into the bottom half. The first five squares of row zero are empty.
	_refuse(Case.move.bind(Originals.item_id(B), 0, 0, false), "rearranging a sheet")
	if not _check(Case.move(Originals.item_id(B), 0, 0, false) and Originals.is_packed(B), "the fitted sheet can be rearranged"):
		return
	if not _check(_select(A) and not Originals.return_to_tray(B), "return refuses the wrong held item"):
		return
	_refuse(Originals.return_to_tray.bind(A), "returning a selected sheet")
	RealityState.load_game()
	if not _check(RealityState.can_continue() and Case.hand() == Originals.item_id(A)
			and Originals.is_packed(A) and Originals.is_packed(B), "Continue rebinds both originals and their exact selected hand"):
		return
	if not _check(Originals.return_to_tray(A) and Case.hand().is_empty() and not Originals.return_to_tray(A)
			and Originals.top_id() == A and not Originals.is_packed(A),
			"successful deposit clears only the selected sheet and exposes it once"):
		return
	_full_case()
	if not _check(Originals.tray_ids() == [A, C] and Originals.packed_ids() == [B], "full-case check returns its fixtures"):
		return
	if not _temporal_route():
		return
	_other_campaign()


## This isolated fixture selects a hand through the normal save transaction. The
## installed route exercises the player, case UI and paper gesture.
func _select(id: String) -> bool:
	return RealityState.commit_case_and_household(func(document: Dictionary) -> bool:
		var case_book: Dictionary = document[Case.KEY]
		if not Originals.case_contains(case_book, id):
			return false
		case_book[Case.HAND] = Originals.item_id(id)
		return true)


func _invalid_cases() -> void:
	var good: Dictionary = Case.book().duplicate(true)
	var item := Originals.item_id(A)
	var forged := good.duplicate(true)
	forged.places[item].form = "tin"
	_check(not Case.valid(forged) and not Originals.case_contains(forged, A) and Originals.is_packed(A),
			"incoming wrong-form hand projection rejects a sheet even when the live original is packed")
	forged = good.duplicate(true)
	forged[Case.RECORDED_ORIGINALS].tray.append(A)
	_check(not Case.valid(forged) and not Originals.case_contains(forged, A), "one edition cannot be simultaneously in tray and case")
	forged.places.erase(item)
	forged[Case.RECORDED_ORIGINALS].tray.append(A)
	_check(not Case.valid(forged), "the same sheet cannot occupy two tray ranks")
	forged[Case.RECORDED_ORIGINALS].tray.clear()
	_check(not Case.valid(forged) and not Originals.case_contains(forged, A), "missing edition location is rejected against the incoming book")
	forged = good.duplicate(true)
	forged.erase(Case.RECORDED_ORIGINALS)
	_check(not Case.valid(forged), "a packed player edition without campaign admission is refused")
	forged = good.duplicate(true)
	forged[Case.RECORDED_ORIGINALS].editions[A] = "someone_elses_song"
	_check(not Case.valid(forged), "an admitted ID cannot be rebound to a different song")
	forged = good.duplicate(true)
	forged.places[item].x += 0.5
	_check(not Case.valid(forged), "a printed sheet cannot occupy fractional squares")


func _fail_write(stage: String, operation: String, args: Dictionary) -> Variant:
	if stage == "temp_write" and operation == "write" and args.get("path") == path + ".tmp":
		refused_writes += 1
		return {"ok": false, "error": ERR_FILE_CANT_WRITE}
	return null


func _refuse(action: Callable, label: String, may_be_absent := false) -> void:
	RealityState.flush_background_saves()
	var old := RealityState.data.duplicate(true)
	var primary := FileAccess.get_file_as_bytes(path)
	var backup_path := path + ".bak"
	var had_backup := FileAccess.file_exists(backup_path)
	var backup := FileAccess.get_file_as_bytes(backup_path) if had_backup else PackedByteArray()
	var previous: Callable = RealityState.storage_operation_override
	refused_writes = 0
	RealityState.storage_operation_override = _fail_write
	var ok: bool = action.call()
	RealityState.storage_operation_override = previous
	_check(not ok and refused_writes == 1 and RealityState.data == old and FileAccess.get_file_as_bytes(path) == primary
			and FileAccess.file_exists(backup_path) == had_backup
			and (not had_backup or FileAccess.get_file_as_bytes(backup_path) == backup),
			"a refused " + label + " preserves the live state, primary and backup")
	if may_be_absent:
		_check(RealityState.data.has(Case.KEY) == old.has(Case.KEY) and Originals.tray_ids().is_empty(),
				"failure cannot initialize the live tray")


func _full_case() -> void:
	for id: String in ["trace_room0", "trace_1610", "trace_two_voices"]:
		if not _check(Found.take(id), "an ordinary historical sheet occupies a remaining footprint: " + id):
			return
	if not _check(Originals.admit(_edition(C)) and Originals.tray_ids() == [A, C],
			"recording succeeds into the tray while every square of the case is occupied"):
		return
	var full := FileAccess.get_file_as_bytes(path)
	_check(not Originals.take(C) and not Originals.take(A) and Originals.top_id() == C
			and FileAccess.get_file_as_bytes(path) == full, "full case leaves the exposed sheet in place")
	for id: String in Found.held_ids():
		if not _check(Found.return_to_source(id), "return only the historical fixture: " + id):
			return


func _temporal_route() -> bool:
	var clock := CampaignClock.new()
	if not _check(clock.configure_date(1928, 11, 10, 1380), "fixture calendar opens"):
		return false
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
	if not _check(clock.apply_prologue_destination(), "normal prologue opens the investigation calendar"):
		return false
	var economy := Economy.new()
	add_child(economy)
	var loop := Loop.new()
	add_child(loop)
	if not _check(loop.setup(clock, economy) and loop.jump("tea").ok and Originals.take(C)
			and _select(B) and Originals.return_to_tray(B)
			and PersonInventory.carry_goods("lily", "custody_test_pick", "Test pick", "tin"),
			"a real visit exchanges two originals and adds ordinary rewindable goods"):
		return false
	if not _check(loop.go_home().ok and not loop.in_visit() and Originals.tray_ids() == [A, B]
			and Originals.packed_ids() == [C] and PersonInventory.goods_count("lily", "custody_test_pick") == 0,
			"return home keeps the moved original sheets as ordinary resident goods rewind"):
		return false
	RealityState.load_game()
	return _check(RealityState.can_continue() and Originals.tray_ids() == [A, B] and Originals.packed_ids() == [C],
			"Continue reconstructs the settled visit's exact tray order and packed identity")


func _other_campaign() -> void:
	RealityState.flush_background_saves()
	var first := FileAccess.get_file_as_bytes(path)
	RealityState.save_path = path + ".other"
	if not _check(RealityState.start_new_campaign() and Originals.packed_ids().is_empty()
			and Originals.tray_ids().is_empty() and Originals.song_id(B).is_empty() and not Originals.take(B),
			"a second campaign in the same profile inherits no recording"):
		return
	if not _check(Originals.admit(_edition(B)) and Originals.tray_ids() == [B] and Originals.packed_ids().is_empty(),
			"only explicit receipt admission grants this specific edition to the second campaign"):
		return
	RealityState.save_path = path
	RealityState.load_game()
	_check(RealityState.can_continue() and Originals.tray_ids() == [A, B] and Originals.packed_ids() == [C]
			and FileAccess.get_file_as_bytes(path) == first, "reopening the first campaign preserves its independent physical history")


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
		"scope": "Isolated campaign custody, case validation, save refusal, Continue and temporal visit using identified fixture editions.",
		"execution": {"completed": true, "exit_code": 0 if failures.is_empty() else 1, "timed_out": false,
			"elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": {"repository_head": str(head[0]).strip_edges(), "runtime_inputs_sha256": str(digest[0]).strip_edges(),
			"test_path": "game/" + script.trim_prefix("res://"), "test_sha256": FileAccess.get_sha256(script),
			"test_scene_path": "game/" + scene.trim_prefix("res://"), "test_scene_sha256": FileAccess.get_sha256(scene)},
		"contracts": {"player_original_custody": {"executed": true, "status": "PASS" if failures.is_empty() else "FAIL"}},
		"checks": checks, "failures": failures}, "\t"))
	file.flush()
	_check(file.get_error() == OK, "receipt flushes")
