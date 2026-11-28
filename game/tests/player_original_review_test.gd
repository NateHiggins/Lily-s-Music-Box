extends Node
## Run in an isolated app profile. The synthetic vocal and consent/cancel test
## use no OS input stream. The recording and the verified private JSON remain
## in that profile after the test for inspection.
const RecorderPanel := preload("res://scripts/ui/songbook_panel.gd")
const Store := preload("res://scripts/songbook/songbook_store.gd")
const Song := preload("res://scripts/songbook/song_resource.gd")

class OfflineRecorder extends MicRecorder:
	func _ready() -> void:
		pass
	func stop_input() -> void:
		pass
	func stop_recording() -> AudioStreamWAV:
		return null

var panel: RecorderPanel
var checks: Array[Dictionary] = []
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	print("PLAYER ORIGINAL REVIEW: ", label, " = ", ok)
	if not ok:
		failures.append(label)
		push_error(label)
	return ok


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		panel.get_viewport().push_input(event, true)


func _sine() -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 8000
	var pcm := PackedByteArray()
	pcm.resize(wave.mix_rate * 2)
	for i in wave.mix_rate:
		pcm.encode_s16(i * 2, roundi(600.0 * sin(TAU * 220.0 * i / wave.mix_rate)))
	wave.data = pcm
	return wave


func _run() -> void:
	var shots := OS.get_environment("SHOT_DIR").replace("\\", "/").simplify_path().trim_suffix("/")
	var profile := OS.get_environment("APPDATA").replace("\\", "/").simplify_path().trim_suffix("/")
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path()
	if not _check(not shots.is_empty() and profile.get_file() == "profile"
			and profile.get_base_dir().to_lower() == shots.get_base_dir().to_lower()
			and actual.to_lower().begins_with(profile.to_lower() + "/")
			and not DirAccess.dir_exists_absolute(Store.DIR), "review uses a fresh private test profile"):
		get_tree().quit(1)
		return
	RealityState.flush_background_saves()
	RealityState.persistence_enabled = true
	RealityState.save_path = "user://review_" + Crypto.new().generate_random_bytes(12).hex_encode() + ".save"
	if not _check(RealityState.start_new_campaign(), "review starts an isolated writable campaign"):
		get_tree().quit(1)
		return
	var song := Song.load_song("last_train_home")
	var original_mouse := Input.mouse_mode
	if _check(song != null, "uses the installed song"):
		panel = RecorderPanel.new()
		add_child(panel)
		panel.open(song, null, null)
		var vocal := _sine()
		panel._rendered = {"backing": vocal, "guide": vocal}
		var phrase := "One porch light left on."
		Input.action_press("ui_up")
		_key(KEY_1)
		Input.action_release("ui_up")
		_check(panel._edit != null and panel._edit.has_focus() and panel._edit.is_editing(),
				"selecting the lyric editor while moving immediately accepts text")
		for letter in phrase:
			var keypress := InputEventKey.new()
			keypress.keycode = letter.to_upper().unicode_at(0)
			keypress.unicode = letter.unicode_at(0)
			keypress.pressed = true
			panel.get_viewport().push_input(keypress, true)
			var release := keypress.duplicate() as InputEventKey
			release.pressed = false
			release.unicode = 0
			panel.get_viewport().push_input(release, true)
		_check(panel._edit.text == phrase, "the first phrase accepts every typed character (%s)" % panel._edit.text)
		_key(KEY_ESCAPE)
		if panel.mode == RecorderPanel.Mode.EDIT:
			_key(KEY_ESCAPE)
		await get_tree().process_frame
		_check(panel.mode == RecorderPanel.Mode.MENU and panel.lyrics[song.slots[0].id] == phrase,
				"leaving before the deferred signal retains the whole phrase (%s)" % panel.lyrics[song.slots[0].id])
		await _cancelled_calibration()
		if _refusal_and_retry(song, vocal):
			await _silent_retake(song)
		panel.close()
		await get_tree().process_frame
	Input.mouse_mode = original_mouse
	RealityState.flush_background_saves()
	var result := FileAccess.open(shots.path_join("songbook-review.json"), FileAccess.WRITE)
	if _check(result != null, "open the review result"):
		result.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
		result.flush()
		_check(result.get_error() == OK, "flush the review result")
	print("PLAYER ORIGINAL REVIEW RESULT: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	get_tree().quit(0 if failures.is_empty() else 1)


func _cancelled_calibration() -> void:
	# Drive both the delayed success callback and a second clap session. The
	# fake has no audio bus, capture effect or AudioStreamMicrophone instance.
	var cancelled := OfflineRecorder.new()
	panel.add_child(cancelled)
	panel._mic = cancelled
	panel.mode = RecorderPanel.Mode.CLAP
	panel._on_calibrated(23, cancelled)
	_check(not panel._clap_start.is_stopped(), "calibration schedules the performance")
	_key(KEY_ESCAPE)
	_check(panel.mode == RecorderPanel.Mode.MENU and panel._clap_start.is_stopped(), "Escape cancels the scheduled performance")
	var current := OfflineRecorder.new()
	panel.add_child(current)
	panel._mic = current
	panel.mode = RecorderPanel.Mode.CLAP
	panel._on_calibrated(30, cancelled)
	await get_tree().create_timer(1.0).timeout
	_check(panel.mode == RecorderPanel.Mode.CLAP and panel._mic == current and panel._backing == null,
		"a cancelled recorder cannot start another calibration's performance")
	_key(KEY_ESCAPE)


func _refusal_and_retry(song: SongResource, vocal: AudioStreamWAV) -> bool:
	panel._take = vocal
	panel._show_review()
	var attempt := Store.begin_keep_attempt(song)
	if not _check(attempt != null, "a reviewed synthetic take has an identity"):
		return false
	panel._keep_attempt = attempt
	var before := Store.versions_of(song.id).size()
	var metadata := Store.DIR.path_join(attempt.version_id + ".json")
	var pathname := ProjectSettings.globalize_path(metadata)
	# This exclusively created empty directory refuses actual file promotion.
	if not _check(DirAccess.make_dir_absolute(pathname) == OK, "only this fresh version's final path is obstructed"):
		return false
	_key(KEY_1)
	var refused: bool = panel.mode == RecorderPanel.Mode.REVIEW and not panel._status.text.is_empty() \
		and panel._status.text.contains("try again") and panel._take == vocal and panel._keep_attempt == attempt \
		and Store.versions_of(song.id).size() == before and panel.lyrics[song.slots[0].id] == "One porch light left on."
	var removed := DirAccess.remove_absolute(pathname) == OK
	if not _check(refused and removed, "a genuine write failure keeps the same take and permits a retry"):
		return false
	_key(KEY_1)
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata))
	if not _check(panel.mode == RecorderPanel.Mode.MENU and record is Dictionary and record.get("version_id") == attempt.version_id
		and record.get("publish") == "PRIVATE" and FileAccess.file_exists(record.get("vocal_stem", "")),
		"retry keeps the original version id, private metadata and vocal"):
		return false
	panel._keep()
	return _check(Store.versions_of(song.id).size() == before + 1, "a subsequent KEEP cannot publish another copy of the take")


func _silent_retake(song: SongResource) -> void:
	var first_id: String = panel._keep_attempt.version_id
	panel._show_review()
	_key(KEY_2)
	if not _check(panel.mode == RecorderPanel.Mode.MIC_CONSENT and panel._mic == null, "singing again offers a fresh microphone choice"):
		return
	_key(KEY_2)
	if not _check(panel.mode == RecorderPanel.Mode.PERFORM and panel._mic == null and panel._take == null and panel._keep_attempt == null,
		"declining the mic starts a new performance with no previous vocal or attempt id"):
		return
	_key(KEY_ESCAPE)
	if not _check(panel.mode == RecorderPanel.Mode.REVIEW and panel._take == null, "the no-mic take remains stemless at review"):
		return
	_key(KEY_1)
	if not _check(panel.mode == RecorderPanel.Mode.MENU and panel._keep_attempt != null and panel._keep_attempt.version_id != first_id,
		"a different performance gets a new version id"):
		return
	var kept := Store.versions_of(song.id).filter(func(row): return row.version_id == panel._keep_attempt.version_id)
	_check(kept.size() == 1 and kept[0].vocal_stem == "" and kept[0].publish == "PRIVATE", "the new private version contains no stale vocal")
