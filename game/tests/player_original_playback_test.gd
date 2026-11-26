extends Node
## Run with sibling SHOT_DIR=<case>/shots and APPDATA=<case>/profile. All generated
## recordings and campaign writes belong to this fresh profile. No microphone opens.
const RecorderPanel := preload("res://scripts/ui/songbook_panel.gd")
const Store := preload("res://scripts/songbook/songbook_store.gd")
const Originals := preload("res://scripts/songbook/player_original_custody.gd")
const Case := preload("res://scripts/game/carried_case.gd")
const WORDS := "The last seat on the train."
var panel: RecorderPanel
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var refused := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	if not ok:
		failures.append(label)
		push_error(label)
	return ok


func _run() -> void:
	var shots := OS.get_environment("SHOT_DIR").replace("\\", "/").simplify_path().trim_suffix("/")
	var profile := OS.get_environment("APPDATA").replace("\\", "/").simplify_path().trim_suffix("/")
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path()
	if not _check(not shots.is_empty() and not profile.is_empty() and profile.get_file() == "profile"
			and profile.get_base_dir().to_lower() == shots.get_base_dir().to_lower()
			and user_root.to_lower().begins_with(profile.to_lower() + "/")
			and not DirAccess.dir_exists_absolute(Store.DIR), "isolated profile contains no other recordings"):
		get_tree().quit(1)
		return
	var mouse := Input.mouse_mode
	RealityState.flush_background_saves()
	RealityState.persistence_enabled = true
	RealityState.save_path = "user://playback_" + Crypto.new().generate_random_bytes(12).hex_encode() + ".save"
	if _check(RealityState.start_new_campaign(), "start the isolated campaign"):
		var song := SongResource.load_song("last_train_home")
		if _check(song != null and song.id == "track_018", "load the actual backing by its catalogue filename"):
			_exercise(song)
			if failures.is_empty():
				await _partial_performances(song)
	if is_instance_valid(panel):
		panel.close()
		await get_tree().process_frame
	Input.mouse_mode = mouse
	RealityState.flush_background_saves()
	if _check(DirAccess.make_dir_recursive_absolute(shots) == OK, "open this test's result directory"):
		var output := FileAccess.open(shots.path_join("songbook-playback.json"), FileAccess.WRITE)
		if _check(output != null, "open playback results"):
			output.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
			output.flush()
			_check(output.get_error() == OK, "flush playback results")
	print("[PLAYER ORIGINAL PLAYBACK] RESULT: %s (%d checks, %d failures)" % [
			"PASS" if failures.is_empty() else "FAIL", checks.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


func _wave(amplitude: int, rate := 8000, stereo := false, seconds := 1) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = stereo
	var channels := 2 if stereo else 1
	var pcm := PackedByteArray()
	pcm.resize(rate * seconds * 2 * channels)
	for frame in rate * seconds:
		for channel in channels:
			var value := roundi(amplitude * sin(TAU * (180.0 + channel * 40.0) * frame / rate))
			pcm.encode_s16(2 * (frame * channels + channel), value)
	stream.data = pcm
	return stream


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		panel.get_viewport().push_input(event, true)


func _choose(id: String) -> bool:
	var index := panel._original_rows.find(id)
	if not _check(index >= 0 and index < 9, "selected identity has a numbered row"):
		return false
	_key((KEY_1 + index) as Key)
	return true


func _fail_save(stage: String, operation: String, args: Dictionary) -> Variant:
	if stage == "temp_write" and operation == "write" and args.get("path") == RealityState.save_path + ".tmp":
		refused += 1
		return {"ok": false, "error": ERR_FILE_CANT_WRITE}
	return null


func _exercise(song: SongResource) -> void:
	var backing := _wave(240)
	var voice := _wave(780)
	var stored_ratio := 1.414
	song.return_ratio = stored_ratio
	panel = RecorderPanel.new()
	add_child(panel)
	panel.open(song, null, null)
	panel._rendered = {"backing": backing, "guide": backing}
	panel.lyrics[song.slots[0].id] = WORDS
	panel._take = voice
	panel._show_review()
	var old_override: Callable = RealityState.storage_operation_override
	RealityState.storage_operation_override = _fail_save
	_key(KEY_1)
	RealityState.storage_operation_override = old_override
	var attempt := panel._keep_attempt
	if not _check(refused == 1 and attempt != null and panel.mode == RecorderPanel.Mode.REVIEW
			and panel._status.text.contains("try again") and panel._take == voice
			and Originals.tray_ids().is_empty(), "real campaign save refusal keeps the recorded review and its attempt"):
		return
	var id: String = attempt.version_id
	var metadata := Store.DIR.path_join(id + ".json")
	var wave_path := Store.VOCALS.path_join(id + ".wav")
	var original := FileAccess.get_file_as_bytes(metadata)
	var voice_bytes := FileAccess.get_file_as_bytes(wave_path)
	_key(KEY_1)
	if not _check(panel.mode == RecorderPanel.Mode.MENU and Originals.tray_ids() == [id]
			and original.size() > 0 and voice_bytes.size() > 44 and FileAccess.get_file_as_bytes(metadata) == original
			and FileAccess.get_file_as_bytes(wave_path) == voice_bytes and Store.versions_of(song.id).size() == 1,
			"retry admits exactly the same immutable edition into the tray"):
		return
	_key(KEY_3)
	_check(panel.mode == RecorderPanel.Mode.ORIGINALS and panel._original_rows.is_empty(), "tray ownership alone gives no shelf entry")
	_key(KEY_ESCAPE)
	var hidden := Store.save_version(song, {"v1a": "Never admitted"}, null)
	if not _check(not hidden.is_empty() and Originals.take(id), "unadmitted global file exists alongside the carried sheet"):
		return
	song.return_ratio = 1.8
	_key(KEY_3)
	if not _check(panel._original_rows == [id] and not panel._original_rows.has(hidden.version_id),
			"menu 3 enumerates only real case entries for this backing"):
		return
	for read_no in 2:
		if not _choose(id):
			return
		var mix := panel._reader.stream as AudioStreamSynchronized if panel._reader != null else null
		if not _check(panel.mode == RecorderPanel.Mode.READING and panel._reader.playing and panel._read_original_id == id
				and not panel._read_is_trace and not panel._read_from_old and panel._mic == null and mix != null
				and mix.stream_count == 2 and mix.get_sync_stream(0) == backing
				and mix.get_sync_stream(1) is AudioStreamWAV and (mix.get_sync_stream(1) as AudioStreamWAV).data == voice.data
				and is_equal_approx(panel._reader.pitch_scale, stored_ratio) and panel._saved_phrase.text == WORDS,
				"audition %d starts backed and voiced at one saved speed with retained words" % (read_no + 1)):
			return
		if read_no == 0:
			_key(KEY_ESCAPE)
		else:
			panel._reader.stop()
			panel._process(0.0)
		_check(panel.mode == RecorderPanel.Mode.ORIGINALS and not panel._reader.playing and panel._reader.stream == null,
				"lifting or reaching the end returns to the same list and releases the voice")
	var bound: Dictionary = JSON.parse_string(original.get_string_from_utf8())
	_check(bound.get("backing_arrangement") == SongSynth.ARRANGEMENT_V1, "KEEP pins the arrangement that was performed")
	bound.backing_arrangement = "unavailable-test-arrangement"
	var altered := FileAccess.open(metadata, FileAccess.WRITE)
	altered.store_string(JSON.stringify(bound))
	altered.close()
	if _choose(id):
		_check(panel.mode == RecorderPanel.Mode.SLEEVE and not panel._reader.playing,
				"an unknown arrangement shows the sleeve instead of playing different music")
		_key(KEY_ESCAPE)
	var reset := FileAccess.open(metadata, FileAccess.WRITE)
	reset.store_buffer(original)
	reset.close()
	if not _missing_media(id, metadata, original, wave_path):
		return
	_key(KEY_ESCAPE)
	var silent := Store.save_version(song, {"v1a": "Words stay on this sheet."}, null)
	if not _check(not silent.is_empty() and Originals.admit(silent) and Originals.take(silent.version_id),
			"pack an explicitly stemless second take"):
		return
	_key(KEY_3)
	if not _choose(silent.version_id):
		return
	var silent_mix := panel._reader.stream as AudioStreamSynchronized
	_check(panel.mode == RecorderPanel.Mode.READING and silent_mix != null and silent_mix.stream_count == 1
			and silent_mix.get_sync_stream(0) == backing and panel._saved_phrase.text == "Words stay on this sheet."
			and is_equal_approx(panel._reader.pitch_scale, 1.8), "words-only playback starts only the backing and its own lyrics")
	_key(KEY_ESCAPE)
	_stale_pick(id, silent.version_id)
	_key(KEY_ESCAPE)
	song.id = "unavailable_arrangement"
	_key(KEY_3)
	panel._read_original(id)
	_check(panel.mode == RecorderPanel.Mode.ORIGINALS and panel._original_rows.is_empty()
			and not panel._reader.playing, "an unsupported arrangement cannot substitute the installed backing")
	song.id = "track_018"
	_legacy_recovery(song, voice, id)



func _missing_media(id: String, metadata: String, original: PackedByteArray, wave_path: String) -> bool:
	var guard := wave_path + ".held_by_playback_test"
	if not _check(DirAccess.rename_absolute(wave_path, guard) == OK, "hide only this fixture's original vocal"):
		return false
	if not _choose(id):
		return false
	_check(panel.mode == RecorderPanel.Mode.SLEEVE and panel._status.text.contains("sleeve") and panel._reader.stream == null
			and panel._saved_lyrics.get("v1a") == WORDS and Originals.is_packed(id),
			"a missing promised vocal leaves words and custody intact without starting a substitute")
	if not _check(_return_sheet(id), "put the open written sleeve back on its tray"):
		return false
	panel._process(0.0)
	if not _check(panel.mode == RecorderPanel.Mode.ORIGINALS and panel._read_original_id.is_empty()
			and panel._saved_lyrics.is_empty() and panel._original_rows.is_empty() and panel._reader.stream == null,
			"loss of the selected sleeve removes its private lyrics and clears the stale selection"):
		return false
	if not _check(Originals.take(id), "reacquire the fixture sheet normally for the damaged-voice check"):
		return false
	panel._show_originals()
	if not _check(Store._write_and_verify(wave_path, "truncated fixture".to_utf8_buffer()), "install malformed fixture voice"):
		return false
	if not _choose(id):
		return false
	_check(panel.mode == RecorderPanel.Mode.SLEEVE and panel._reader.stream == null, "malformed voice is also unavailable")
	_key(KEY_ESCAPE)
	if not _check(DirAccess.remove_absolute(wave_path) == OK and DirAccess.rename_absolute(guard, wave_path) == OK,
			"restore the untouched fixture voice"):
		return false
	var source: Dictionary = JSON.parse_string(original.get_string_from_utf8())
	for fields: Dictionary in [
		{"vocal_stem": "user://other.wav"}, {"vocal_stem": Store.VOCALS.path_join("../" + id + ".wav")},
		{"publish": "COMMUNITY"}, {"base_song_id": "different"}, {"version_id": "../" + id},
		{"reconstruction_ratio": "1.41"}, {"reconstruction_ratio": 1.0}, {"lyrics": {"v1a": 22}},
		{Store.PERFORMED_SECONDS: -2.0}, {Store.PERFORMED_SECONDS: "0.5"}]:
		var changed := source.duplicate(true)
		changed.merge(fields, true)
		if not _check(Store._write_and_verify(metadata, JSON.stringify(changed).to_utf8_buffer()),
				"install invalid private metadata fixture"):
			return false
		_check(Store.private_playback(id, panel.song.id).is_empty(), "reject a changed " + str(fields.keys()[0]))
	_check(Store.private_playback("../" + id, panel.song.id).is_empty(), "reject path-like selected ID before file lookup")
	if not _choose(id):
		return false
	_check(panel.mode == RecorderPanel.Mode.ORIGINALS and panel._original_rows.is_empty() and not panel._reader.playing,
			"recheck metadata on keypress and remove the unreadable row")
	return _check(Store._write_and_verify(metadata, original), "restore the fixture's exact original metadata")


func _return_sheet(id: String) -> bool:
	var selected := RealityState.commit_case_and_household(func(book: Dictionary) -> bool:
		if not Originals.case_contains(book[Case.KEY], id):
			return false
		book[Case.KEY][Case.HAND] = Originals.item_id(id)
		return true)
	return selected and Originals.return_to_tray(id)


func _stale_pick(id: String, other: String) -> void:
	var index := panel._original_rows.find(id)
	if not _check(index >= 0 and panel._original_rows.has(other), "two independently numbered sheets are displayed"):
		return
	if not _check(_return_sheet(id), "return a displayed original before pressing its key"):
		return
	_key((KEY_1 + index) as Key)
	_check(panel.mode == RecorderPanel.Mode.ORIGINALS and panel._original_rows == [other]
			and not panel._reader.playing and Originals.top_id() == id, "a stale row never plays the sheet that moved into its number")

## Write genuine old-style immutable files in our private fixture profile. The
## application itself only reads them; each selected sheet changes the campaign.
func _legacy_recovery(song: SongResource, voice: AudioStreamWAV, modern_id: String) -> void:
	var ids: Array[String] = []
	var originals := {}
	var saved_path: String = RealityState.save_path
	var previous_save := FileAccess.get_file_as_bytes(saved_path)
	var wave_path := ""
	for i in 8:
		var id := "track_018_19291110_153000_%03d" % i
		ids.append(id)
		var row := {"version_id": id, "base_song_id": song.id, "publish": "PRIVATE",
				"parent_version_id": "", "author_id": "you", "display_author": "you", "title": song.title,
				"lyrics": {"v1a": "Old line %d." % i}, "vocal_stem": "", "created": "1929-11-10T15:30:00",
				"strict_meter": false, "covers": 0, "mutations": 0, "singalong_count": 0, "performance_count": 1}
		if i != 0:
			row["reconstruction_ratio"] = 1.414
		if i in [6, 7]:
			row.vocal_stem = Store.VOCALS.path_join(id + ".wav")
		if i == 7:
			wave_path = row.vocal_stem
			if not _check(voice.save_to_wav(wave_path) == OK, "install old immutable fixture voice"):
				return
		var bytes := JSON.stringify(row, "  ").to_utf8_buffer()
		originals[id] = bytes
		if not _check(Store._write_and_verify(Store.DIR.path_join(id + ".json"), bytes), "install legacy fixture metadata"):
			return
	for i in 2:
		var id := "track_018_19291110_153000_%03d" % (i + 8)
		var invalid: Dictionary = JSON.parse_string(originals[ids[0]].get_string_from_utf8())
		invalid.version_id = id
		if i == 0:
			invalid.publish = "COMMUNITY"
		else:
			invalid.vocal_stem = "user://other_household/voice.wav"
		if not _check(Store._write_and_verify(Store.DIR.path_join(id + ".json"), JSON.stringify(invalid).to_utf8_buffer()),
				"install an ineligible legacy fixture"):
			return
	var original_voice := FileAccess.get_file_as_bytes(wave_path)
	RealityState.save_path = saved_path + ".legacy"
	if not _check(RealityState.start_new_campaign() and Originals.tray_ids().is_empty() and Originals.packed_ids().is_empty(),
			"a new campaign with preexisting recordings receives no sheet"):
		return
	var fresh := FileAccess.get_file_as_bytes(RealityState.save_path)
	panel._show_menu()
	_key(KEY_3)
	_key(KEY_R)
	var expected := ids.duplicate()
	expected.reverse()
	if not _check(panel.mode == RecorderPanel.Mode.RECOVERY and panel._legacy_page == 0 and panel._legacy_ids == expected
			and not Store.private_edition(modern_id, song.id).is_empty()
			and Store.private_playback(modern_id, song.id, true).is_empty()
			and FileAccess.get_file_as_bytes(RealityState.save_path) == fresh,
			"explicit lookup includes eight legacy identities and excludes all post-upgrade takes without saving"):
		return
	_key(KEY_RIGHT)
	var before_refusals := refused
	var old_override: Callable = RealityState.storage_operation_override
	RealityState.storage_operation_override = _fail_save
	_key(KEY_2)
	RealityState.storage_operation_override = old_override
	if not _check(panel.mode == RecorderPanel.Mode.RECOVERY and panel._legacy_page == 1 and refused == before_refusals + 1
			and Originals.tray_ids().is_empty() and FileAccess.get_file_as_bytes(RealityState.save_path) == fresh,
			"refused recovery preserves the selected page, empty tray and save generation"):
		return
	_key(KEY_2)
	if not _check(panel.mode == RecorderPanel.Mode.ORIGINALS and Originals.tray_ids() == [ids[0]] and Originals.take(ids[0]),
			"only the explicitly numbered edition on page two reaches the tray and case"):
		return
	panel._show_originals()
	_key(KEY_1)
	if not _check(panel.mode == RecorderPanel.Mode.READING and is_equal_approx(panel._reader.pitch_scale, 1.335)
			and panel._saved_phrase.text == "Old line 0." and not Store.private_edition(ids[0], song.id).has("reconstruction_ratio"),
			"an unmarked early edition retains its words and uses the fixed first reader setting"):
		return
	_key(KEY_ESCAPE)
	_key(KEY_R)
	if not _check(not panel._legacy_ids.has(ids[0]), "a packed legacy edition cannot be recovered twice"):
		return
	_key(KEY_2)
	if not _check(panel.mode == RecorderPanel.Mode.RECOVERY_SLEEVE and Originals.tray_ids().is_empty(),
			"a missing promised voice requests separate sleeve recovery"):
		return
	_key(KEY_ESCAPE)
	_check(panel.mode == RecorderPanel.Mode.RECOVERY and Originals.tray_ids().is_empty(), "cancel leaves the old sleeve unclaimed")
	_key(KEY_2)
	_key(KEY_ENTER)
	_key(KEY_R)
	if not _check(Originals.tray_ids() == [ids[6]] and not panel._legacy_ids.has(ids[6]), "confirmed written sleeve occupies one tray place"):
		return
	_key(KEY_1)
	var voiced := Store.private_playback(ids[7], song.id)
	if not _check(Originals.tray_ids() == [ids[6], ids[7]] and voiced.vocal is AudioStreamWAV
			and voiced.vocal.data == voice.data and is_equal_approx(voiced.playback_ratio, 1.414),
			"recovery preserves the voiced edition's exact PCM and stored ratio"):
		return
	RealityState.load_game()
	_check(RealityState.can_continue() and Originals.is_packed(ids[0]) and Originals.tray_ids() == [ids[6], ids[7]],
			"Continue restores each recovered location exactly once")
	_key(KEY_R)
	RealityState.save_path += ".another"
	if not _check(RealityState.start_new_campaign(), "start a different household while the old list is open"):
		return
	_key(KEY_1)
	_check(panel.mode == RecorderPanel.Mode.ORIGINALS and Originals.tray_ids().is_empty(),
			"an open recovery number cannot grant an edition after a campaign switch")
	_key(KEY_R)
	_check(panel._legacy_ids == expected and Originals.tray_ids().is_empty(), "another campaign may explicitly recover old media and inherits no admissions")
	for id: String in originals:
		_check(FileAccess.get_file_as_bytes(Store.DIR.path_join(id + ".json")) == originals[id], "legacy metadata remains byte-identical")
	_check(FileAccess.get_file_as_bytes(wave_path) == original_voice and FileAccess.get_file_as_bytes(saved_path) == previous_save,
			"recovery leaves the original vocal and unrelated campaign save byte-identical")



## No input device. Drive a genuine performance stop and use a synthetic dry
## stem only for the voiced half, at a different rate and channel count.
func _partial_performances(song: SongResource) -> void:
	var backing := _wave(300, 8000, false, 2)
	var voice := _wave(1100, 12000, true, 2)
	var original_backing := backing.data
	var original_voice := voice.data
	panel._rendered = {"backing": backing, "guide": backing}
	panel.lyrics[song.slots[0].id] = WORDS
	for voiced: bool in [true, false]:
		panel._show_menu()
		_key(KEY_2)
		_key(KEY_2)
		if not _check(panel.mode == RecorderPanel.Mode.PERFORM and panel._mic == null, "start the bounded no-microphone take"):
			return
		var deadline := Time.get_ticks_msec() + 2500
		while panel.mode == RecorderPanel.Mode.PERFORM and panel._backing.get_playback_position() < 0.16 and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_key(KEY_ESCAPE)
		var endpoint: float = panel._take_end_seconds
		if not _check(panel.mode == RecorderPanel.Mode.REVIEW and endpoint >= 0.16 and endpoint < backing.get_length(),
				"manual stop retained the current source cursor before the backing finished"):
			return
		if voiced:
			panel._take = voice
			panel._show_review()
		_key(KEY_4)
		if not _check(_matches_excerpt(backing, voice if voiced else null, endpoint) and panel._mic == null,
				"review auditions only the stopped section at each native sample rate"):
			return
		_key(KEY_ESCAPE)
		_key(KEY_1)
		var id := Originals.top_id()
		var record := Store.private_edition(id, song.id)
		if not _check(panel.mode == RecorderPanel.Mode.MENU and record.has(Store.PERFORMED_SECONDS)
				and roundi(float(record[Store.PERFORMED_SECONDS]) * backing.mix_rate) == roundi(endpoint * backing.mix_rate)
				and Originals.take(id),
				"KEEP persists the original source endpoint in the edition"):
			return
		var altered := Store.save_version(song, panel.lyrics, voice if voiced else null, "PRIVATE", "", "you", false,
				panel._keep_attempt, endpoint + 1.0 / backing.mix_rate)
		if not _check(altered.is_empty(), "retry cannot change even one frame of an admitted performance"):
			return
		_key(KEY_3)
		if not _choose(id):
			return
		if not _check(_matches_excerpt(backing, voice if voiced else null, endpoint) and panel._saved_phrase.text.is_empty(),
				"saved playback ends both stems at the kept cut and omits lyrics beyond it"):
			return
		_key(KEY_ESCAPE)
		_key(KEY_ESCAPE)
		if voiced:
			var retained: Dictionary = Store.private_playback(id, song.id)
			if not _check(retained.vocal != null and retained.vocal.data == original_voice,
					"the dry recording is still full-length and byte-identical"):
				return
	_check(backing.data == original_backing and voice.data == original_voice, "auditions preserve the original PCM streams")
	var before_music := Store.save_version(song, panel.lyrics, null, "PRIVATE", "", "you", false, null, 0.0)
	if not _check(not before_music.is_empty() and Originals.admit(before_music) and Originals.take(before_music.version_id),
			"a version stopped before the first backing frame still keeps its written sleeve"):
		return
	panel._show_originals()
	if not _choose(before_music.version_id):
		return
	if not _check(panel.mode == RecorderPanel.Mode.SLEEVE and panel._reader.stream == null and panel._saved_lyrics.get("v1a") == WORDS,
			"a zero-frame version shows the words and starts no substitute audio"):
		return
	_key(KEY_ESCAPE)
	# A completed player has no cursor left. The finished signal must preserve
	# the real stream length even when it differs from the catalogue duration.
	var short := panel._performed_prefix(backing, 0.125)
	panel._rendered = {"backing": short, "guide": short}
	panel._show_menu()
	_key(KEY_2)
	_key(KEY_2)
	var finish_by := Time.get_ticks_msec() + 2500
	while panel.mode == RecorderPanel.Mode.PERFORM and Time.get_ticks_msec() < finish_by:
		await get_tree().process_frame
	_check(panel.mode == RecorderPanel.Mode.REVIEW and panel._take_end_seconds == short.get_length(),
			"natural completion retains the full stream rather than a cleared cursor")


func _matches_excerpt(backing: AudioStreamWAV, voice: AudioStreamWAV, endpoint: float) -> bool:
	var mix := panel._reader.stream as AudioStreamSynchronized
	if mix == null or panel.mode != RecorderPanel.Mode.READING or mix.stream_count != (1 if voice == null else 2):
		return false
	var expected: Array[AudioStreamWAV] = [backing]
	if voice != null:
		expected.append(voice)
	for i in expected.size():
		var original := expected[i]
		var actual := mix.get_sync_stream(i) as AudioStreamWAV
		var bytes := roundi(endpoint * original.mix_rate) * (4 if original.stereo else 2)
		if actual == null or actual.mix_rate != original.mix_rate or actual.stereo != original.stereo \
				or actual.format != original.format or actual.data != original.data.slice(0, bytes):
			return false
	return true
