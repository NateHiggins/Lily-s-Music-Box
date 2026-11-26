extends "res://tests/found_trace_route_test.gd"
## Run with a fresh APPDATA=<case>/profile and SHOT_DIR=<case>/shots. This
## driver's disk Continue invokes the production save loader in the mounted
## world. The actual title button / shell transition has a separate witness.
const Original := preload("res://scripts/songbook/player_original_custody.gd")
const Store := preload("res://scripts/songbook/songbook_store.gd")
const RecorderPanel := preload("res://scripts/ui/songbook_panel.gd")
const EquippedAvatar := preload("res://scripts/player/player_avatar_held_items.gd")
const TEST_WORDS := "low wire"

var _recorder: Node3D
var _output: Node3D
var _edition := ""
var _lyric_slot := ""
var _metadata_sha := ""


func _init() -> void:
	route_label = "PLAYER ORIGINAL ROUTE"


func _prepare_campaign() -> bool:
	var shots := OS.get_environment("SHOT_DIR").replace("\\", "/").simplify_path()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower()
	var expected_profile := shots.get_base_dir().path_join("profile").to_lower()
	if not _require(DisplayServer.get_name() != "headless" and shots.is_absolute_path()
			and shots.get_file() == "shots" and user_dir.begins_with(expected_profile + "/"),
			"rendered route uses a private sibling profile and shots directory"):
		return false
	var private_dir := ProjectSettings.globalize_path(Store.DIR)
	if not _require(RealityState.save_path == RealityState.SAVE_PATH
			and RealityState.load_status().get("status") == "missing"
			and not FileAccess.file_exists(RealityState.save_path)
			and not DirAccess.dir_exists_absolute(private_dir),
			"fresh profile contains neither a saved campaign nor an existing recording library"):
		return false
	RealityState.persistence_enabled = true
	return _require(RealityState.start_new_campaign() and RealityState.can_continue()
			and FileAccess.file_exists(RealityState.save_path),
			"normal new campaign writes its first primary in the isolated profile")


func _route() -> void:
	var actors: Node = world.bar_region.actors
	_recorder = actors.get_node_or_null("F01_BAR_SONGBOOK") as Node3D
	_output = actors.get_node_or_null("PlayerOriginalOutput/TopOriginal") as Node3D
	if not _require(_recorder != null and _output != null and not _recorder.is_ancestor_of(_output),
			"original recorder and its separate fitted output target are installed"):
		return
	if not _require(Original.top_id().is_empty() and Original.packed_ids().is_empty(), "fresh campaign has no recorded originals"):
		return
	if not await _walk_to_recorder() or not await _author_take():
		return
	if not await _walk_to_output() or not await _paper_stroke(true):
		return
	if not await _equip_and_continue():
		return
	if not await _walk_to_recorder() or not await _hear_own_edition():
		return
	if not await _walk_to_output() or not await _paper_stroke(false):
		return
	var grid := _disk_grid()
	var avatar := world.player_avatar as EquippedAvatar
	route_completed = _require(CarriedCase.valid(grid) and not Original.case_contains(grid, _edition)
			and grid.get(CarriedCase.RECORDED_ORIGINALS, {}).get("tray", []) == [_edition]
			and grid.get(CarriedCase.HAND, "") == "" and _displayed(_edition)
			and FileAccess.get_sha256(Store.DIR.path_join(_edition + ".json")) == _metadata_sha
			and is_instance_valid(avatar) and is_instance_valid(avatar.glove_slot) and avatar.glove_slot.worn.is_empty()
			and is_instance_valid(avatar.hand_slot) and avatar.hand_slot.worn.is_empty(),
			"return leaves the same original visible on the tray, absent from the case and both hands")


func _walk_to_recorder() -> bool:
	var bar := world.bar_region
	return await _walk_up(bar.to_global(GameBoot.b2g([-10.5, -34.15, -2.8])),
			bar.to_global(GameBoot.b2g([-10.5, -35.15, -2.8])), "Harukiya recorder")


func _walk_to_output() -> bool:
	var from := player.global_position
	var target := world.bar_region.to_global(GameBoot.b2g([-10.5, -34.65, -2.8]))
	if not await _walk_world(target):
		return false
	return _require(player.is_on_floor() and not player.noclip and from.distance_to(player.global_position) > .2
			and player.global_position.distance_to(target) < .28, "walks from the reader to the adjacent tray on the WC bypass")


func _open_recorder() -> RecorderPanel:
	var primary := _recorder.get_node_or_null("PrimaryInteraction") as Area3D
	var shapes := primary.find_children("*", "CollisionShape3D", false, false) if primary != null else []
	if not _require(shapes.size() == 1, "recorder retains its original primary input surface"):
		return null
	await _aim((shapes[0] as CollisionShape3D).global_position)
	await _click_world()
	var panel := _recorder.get("_panel") as RecorderPanel
	if not _require(is_instance_valid(panel) and panel.mode == RecorderPanel.Mode.MENU and player.call_locked,
			"clicking the original recorder opens the normal songbook menu"):
		return null
	return panel


func _author_take() -> bool:
	var panel := await _open_recorder()
	if panel == null:
		return false
	await _panel_key(panel, KEY_1)
	if not _require(panel.mode == RecorderPanel.Mode.EDIT and panel._edit.has_focus() and panel._edit.is_editing(), "the first written phrase accepts keyboard input"):
		return false
	_lyric_slot = str(panel.song.slots[0].id)
	for i in TEST_WORDS.length():
		var ch := TEST_WORDS.substr(i, 1)
		var code := KEY_SPACE if ch == " " else OS.find_keycode_from_string(ch.to_upper())
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = code
			event.physical_keycode = code
			event.unicode = TEST_WORDS.unicode_at(i) if pressed else 0
			event.pressed = pressed
			panel.get_viewport().push_input(event, true)
	for frame in 4:
		if panel.lyrics.get(_lyric_slot) == TEST_WORDS:
			break
		await get_tree().process_frame
	if not _require(panel._edit.text == TEST_WORDS and panel.lyrics.get(_lyric_slot) == TEST_WORDS,
			"ordinary text input reaches both the editor (%s) and the authored phrase (%s)" % [panel._edit.text, panel.lyrics.get(_lyric_slot)]):
		return false
	await _panel_key(panel, KEY_ESCAPE)
	if panel.mode == RecorderPanel.Mode.EDIT:
		# A focused LineEdit can consume the first Escape to finish editing.
		await _panel_key(panel, KEY_ESCAPE)
	if not _require(panel.mode == RecorderPanel.Mode.MENU, "the lyric editor returns to the recorder menu"):
		return false
	await _panel_key(panel, KEY_2)
	if not _require(panel.mode == RecorderPanel.Mode.MIC_CONSENT and panel._mic == null, "the recorder asks before starting a microphone"):
		return false
	await _panel_key(panel, KEY_2)
	if not _require(panel.mode == RecorderPanel.Mode.PERFORM and panel._mic == null and panel._take == null
			and panel._backing.playing, "words-only performance starts its backing with no microphone"):
		return false
	# Perform through the first written phrase. A cut in the instrumental
	# intro contains no part of that phrase to show in the later audition.
	var phrase_start := float(panel.song.slots[0].start_time)
	var deadline := Time.get_ticks_msec() + 25000
	while panel.mode == RecorderPanel.Mode.PERFORM and panel._backing.get_playback_position() < phrase_start + .5 and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.10).timeout
	if not _require(panel.mode == RecorderPanel.Mode.PERFORM and panel._backing.get_playback_position() >= phrase_start,
			"the performed excerpt includes the player's first written phrase"):
		return false
	await _panel_key(panel, KEY_ESCAPE)
	if not _require(panel.mode == RecorderPanel.Mode.REVIEW and panel._take == null, "stopping the performance offers its words-only take for review"):
		return false
	await _panel_key(panel, KEY_1)
	_edition = Original.top_id()
	if not _require(panel.mode == RecorderPanel.Mode.MENU and not _edition.is_empty()
			and Original.tray_ids() == [_edition] and Original.packed_ids().is_empty(),
			"private KEEP creates exactly one exposed edition before the case owns it"):
		return false
	var record := Store.private_edition(_edition, panel.song.id)
	if not _require(record.get("version_id") == _edition and record.get("publish") == "PRIVATE"
			and record.get("lyrics", {}).get(_lyric_slot) == TEST_WORDS and record.get("vocal_stem") == ""
			and not FileAccess.file_exists(Store.VOCALS.path_join(_edition + ".wav")) and _displayed(_edition),
			"the kept metadata names this private no-vocal phrase and its matching physical paper"):
		return false
	_metadata_sha = FileAccess.get_sha256(Store.DIR.path_join(_edition + ".json"))
	await _panel_key(panel, KEY_ESCAPE)
	return _require(_metadata_sha.length() == 64 and not player.call_locked, "leaving the recorder releases movement after durable publication")


func _displayed(id: String) -> bool:
	var stock := _output.get_node_or_null("Sheet/ExposedStock") as Node3D
	if stock == null or not stock.is_visible_in_tree() or stock.get_child_count() != 1:
		return false
	var mark := stock.find_child("EditionMark", true, false) as Label3D
	return mark != null and mark.text == id.right(19)


func _paper_stroke(lift: bool) -> bool:
	var shape := _output.get_node_or_null("Sheet/Operable/CollisionShape3D") as CollisionShape3D
	if not _require(shape != null, "finished-sheet pickup has an exact physical contact"):
		return false
	await _aim(shape.global_position)
	if not _require(player._grab.find_target().get("owner") == _output, "reticle reaches the output paper separately from the recorder"):
		return false
	if lift:
		await _capture_interaction("finished_original_on_tray")
	await _click_world()
	if not _require(player._grab.active() and player._grab.target.get("owner") == _output
			and _displayed(_edition) and Original.is_packed(_edition) != lift, "gripping the sheet preserves its real owner"):
		return false
	var initial := float(player._grab.target.read.call())
	for step in 6:
		var motion := InputEventMouseMotion.new()
		motion.position = get_viewport().get_visible_rect().get_center()
		motion.relative = Vector2(0, -20 if lift else 20)
		motion.screen_relative = motion.relative
		get_viewport().push_input(motion, true)
		await get_tree().physics_frame
	if not _require(player._grab.active(), "the physical hand remains latched throughout the stroke"):
		return false
	var stroke := float(player._grab.target.read.call()) - initial
	if not _require((stroke if lift else -stroke) >= .10 and Original.is_packed(_edition) != lift,
			"a full directed stroke moves the actual sheet before custody changes"):
		return false
	await _click_world()
	return _require(not player._grab.active() and Original.is_packed(_edition) == lift
			and (Original.top_id().is_empty() if lift else Original.top_id() == _edition),
			"the second primary click commits the single edition transfer")


func _disk_grid() -> Dictionary:
	RealityState.flush_background_saves()
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(RealityState.save_path))
	return document.get(CarriedCase.KEY, {}) if document is Dictionary else {}


func _equip_and_continue() -> bool:
	var item := Original.item_id(_edition)
	var view: Node = world.carried_case_view
	await _key(KEY_TAB)
	await get_tree().create_timer(.7).timeout
	if not _require(view.opened and view.settled and view._stacks.has(item), "Tab opens the valise with this edition in its own stack"):
		return false
	var place := CarriedCase.place_of(item)
	var centre := Vector2(float(place.x), float(place.y)) + Vector2(CarriedCase.form_size(place.form, place.turned)) * .5
	await _press(_screen(view, centre.x, centre.y))
	if not _require(view.held_item == item, "primary selects this edition in the normal valise"):
		return false
	await _press(_screen(view, centre.x, CarriedCase.grid().y + 2.5))
	await get_tree().create_timer(.7).timeout
	var grid := _disk_grid()
	if not _require(not view.opened and not player.call_locked and CarriedCase.valid(grid)
			and Original.case_contains(grid, _edition) and grid.get(CarriedCase.HAND) == item,
			"bringing the item out leaves the exact recorded original selected on disk"):
		return false
	RealityState.load_game()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var avatar := world.player_avatar as EquippedAvatar
	if not _require(RealityState.can_continue() and RealityState.load_status().get("status") == "loaded"
			and CarriedCase.hand() == item and Original.packed_ids() == [_edition] and Original.top_id().is_empty()
			and not world.household_state._blocked and world.household_state.errors.is_empty()
			and is_instance_valid(avatar) and is_instance_valid(avatar.glove_slot) and avatar.glove_slot.worn == item
			and is_instance_valid(avatar.hand_slot) and avatar.hand_slot.worn == item,
			"production Continue reads the primary and restores its selection in first-person and reflected hands"):
		return false
	await _capture_interaction("continued_original_in_glove")
	return true


func _hear_own_edition() -> bool:
	var panel := await _open_recorder()
	if panel == null:
		return false
	await _panel_key(panel, KEY_3)
	if not _require(panel.mode == RecorderPanel.Mode.ORIGINALS and panel._original_rows == [_edition],
			"the normal shelf lists only the carried edition of the installed arrangement"):
		return false
	await _panel_key(panel, KEY_1)
	var stream := panel._reader.stream as AudioStreamSynchronized if panel._reader != null else null
	var record := Store.private_edition(_edition, panel.song.id)
	if not _require(panel.mode == RecorderPanel.Mode.READING and panel._read_original_id == _edition
			and panel._reader != null and panel._reader.playing and stream != null and stream.stream_count == 1
			and stream.get_sync_stream(0) != null and panel._saved_lyrics.get(_lyric_slot) == TEST_WORDS
			and is_equal_approx(panel._reader.pitch_scale, float(record.get("reconstruction_ratio", 0)))
			and panel._mic == null, "recorded-edition reader plays the stored words and backing at its saved reconstruction ratio"):
		return false
	# The recorder is a root overlay; the route subviewport contains the world only.
	await RenderingServer.frame_post_draw
	var shelf_image := panel.get_viewport().get_texture().get_image()
	if not _require(shelf_image != null and not shelf_image.is_empty() and shelf_image.save_png(
			OS.get_environment("SHOT_DIR").path_join("private_shelf_playback.png")) == OK,
			"records a rendered frame from the private playback screen"):
		return false
	await _panel_key(panel, KEY_SPACE)
	if not _require(panel.mode == RecorderPanel.Mode.ORIGINALS and not panel._reader.playing, "lifting the stylus returns to the private shelf"):
		return false
	await _panel_key(panel, KEY_ESCAPE)
	await _panel_key(panel, KEY_ESCAPE)
	return _require(not player.call_locked, "stepping away releases normal control for the return stroke")


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
		"scope": "One private words-only recording in a fresh test campaign. Installed recorder, exposed tray, walking, case selection, disk Continue through the live save authority, both equipped hands, private shelf backing and return. The title button, full shell transition, real microphone and voiced synchronization are separate tests.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false,
			"elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": {"test_path": "game/" + script.trim_prefix("res://"),
			"test_sha256": FileAccess.get_sha256(script),
			"test_scene_path": "game/" + scene.trim_prefix("res://"),
			"test_scene_sha256": FileAccess.get_sha256(scene),
			"repository_head": str(head[0]).strip_edges(),
			"runtime_inputs_sha256": str(digest[0]).strip_edges()},
		"contracts": {"player_original_words_keep_tray_case_continue_shelf_return": {"executed": route_completed,
			"status": "PASS" if passed else "FAIL"}},
		"edition": _edition, "metadata_sha256": _metadata_sha,
		"checks": interaction_checks, "walks": trace, "failures": failures,
	}, "	"))
	file.flush()
	_require(file.get_error() == OK, "contract output was written")
