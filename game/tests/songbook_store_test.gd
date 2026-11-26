extends Node
## Use a fresh, private APPDATA=<case>/profile and SHOT_DIR=<case>/shots.
## No microphone is opened. Four deterministic PCM samples exercise real files.
const Store := preload("res://scripts/songbook/songbook_store.gd")
var checks: Array[Dictionary] = []
var failures: Array[String] = []


class ReservationRace extends RefCounted:
	func reserve(gate: Semaphore, song_id: String, version_id: String):
		gate.wait()
		return Store._reserve(song_id, version_id)


func _require(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	if not ok:
		failures.append(label)
		push_error(label)
	return ok


func _ready() -> void:
	var shots := OS.get_environment("SHOT_DIR").simplify_path().trim_suffix("/")
	var profile := OS.get_environment("APPDATA").replace("\\", "/").simplify_path().trim_suffix("/")
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path()
	if not _require(not shots.is_empty() and not profile.is_empty() and profile.get_file() == "profile"
			and profile.get_base_dir().to_lower() == shots.get_base_dir().to_lower()
			and user_root.to_lower().begins_with(profile.to_lower() + "/")
			and not DirAccess.dir_exists_absolute(Store.DIR), "this bench owns a fresh private profile"):
		get_tree().quit(1)
		return
	_run()
	if _require(DirAccess.make_dir_recursive_absolute(shots) == OK, "private result folder opens"):
		var output := FileAccess.open(shots.path_join("songbook-storage.json"), FileAccess.WRITE)
		if _require(output != null, "storage results open"):
			output.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
			output.flush()
			_require(output.get_error() == OK, "storage results flush")
	print("[SONGBOOK STORE] RESULT: %s (%d checks, %d failures)" % [
		"PASS" if failures.is_empty() else "FAIL", checks.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var song := SongResource.load_song("last_train_home")
	if not _require(song != null and Store.versions_of(song.id).is_empty(), "no versions in the fresh profile"):
		return
	var lyrics := {"s01": "A borrowed line."}
	var attempt := Store.begin_keep_attempt(song)
	if not _require(attempt != null and attempt.version_id.begins_with(song.id + "_"),
			"reserve one stable edition for the review"):
		return
	var version_id := attempt.version_id
	var metadata_path := Store.DIR.path_join(version_id + ".json")
	var vocal_path := Store.VOCALS.path_join(version_id + ".wav")
	var voice := AudioStreamWAV.new()
	voice.format = AudioStreamWAV.FORMAT_16_BITS
	voice.mix_rate = 16000
	voice.stereo = true
	voice.data = PackedByteArray([0, 16, 0, 32, 0, 48, 0, 64])
	# Occupy only this attempt's future metadata name. The actual stem can
	# be promoted, but metadata promotion must fail and roll that stem back.
	if not _require(DirAccess.make_dir_absolute(metadata_path) == OK, "inject a late metadata refusal"):
		return
	var failed := Store.save_version(song, lyrics, voice, "PRIVATE", "", "you", false, attempt)
	_require(failed.is_empty() and not FileAccess.file_exists(vocal_path)
			and DirAccess.dir_exists_absolute(metadata_path) and Store.versions_of(song.id).is_empty(),
			"metadata refusal hides the take, rolls back its own stem and preserves the obstruction")
	_require(Store._reserve(song.id, version_id) == null,
			"a second writer cannot take a failed live attempt's ID")
	DirAccess.remove_absolute(metadata_path)
	var result := Store.save_version(song, lyrics, voice, "PRIVATE", "", "you", false, attempt)
	if not _require(result.get("version_id") == version_id and result.get("vocal_stem") == vocal_path
			and result.get("publish") == "PRIVATE" and result.get("reconstruction_ratio") == song.return_ratio,
			"the original retry publishes its version, complete stem and originally chosen speed"):
		return
	var original_metadata := FileAccess.get_file_as_bytes(metadata_path)
	var original_voice := FileAccess.get_file_as_bytes(vocal_path)
	var decoded := AudioStreamWAV.load_from_file(vocal_path)
	_require(decoded != null and decoded.stereo and decoded.mix_rate == 16000 and decoded.data == voice.data,
			"the admitted file decodes to the exact stereo samples")
	_require(Store.save_version(song, lyrics, voice, "PRIVATE", "", "you", false, attempt) == result
			and Store.versions_of(song.id).size() == 1, "repeated KEEP returns the same receipt once")
	_require(Store.save_version(song, {"s01": "Other line"}, voice, "PRIVATE", "", "you", false, attempt).is_empty()
			and Store._reserve(song.id, version_id) == null and FileAccess.get_file_as_bytes(metadata_path) == original_metadata
			and FileAccess.get_file_as_bytes(vocal_path) == original_voice,
			"a conflicting retry or a fresh ID collision cannot alter published files")
	var other := Store.save_version(song, lyrics, null)
	_require(not other.is_empty() and other.version_id != version_id and other.publish == "PRIVATE"
			and other.vocal_stem == "" and Store.versions_of(song.id).size() == 2,
			"ordinary legacy call keeps a private words-only take without fabricating a WAV")
	var empty_voice := AudioStreamWAV.new()
	_require(Store.save_version(song, lyrics, empty_voice).is_empty() and Store.versions_of(song.id).size() == 2,
			"an explicitly supplied empty voice cannot become a successful words-only version")
	var blocked := Store.begin_keep_attempt(song)
	if not _require(blocked != null, "reserve an independent take for a vocal refusal"):
		return
	var unrelated := Store.VOCALS.path_join(blocked.version_id + ".wav")
	var fixture := "outside this attempt's write".to_utf8_buffer()
	_require(Store._write_and_verify(unrelated, fixture), "stage unrelated bytes at the vocal destination")
	_require(Store.save_version(song, lyrics, voice, "PRIVATE", "", "you", false, blocked).is_empty()
			and FileAccess.get_file_as_bytes(unrelated) == fixture
			and not FileAccess.file_exists(Store.DIR.path_join(blocked.version_id + ".json")),
			"a vocal collision leaves the earlier bytes intact and publishes no metadata")
	var abandoned_dir := Store.PENDING.path_join(blocked.version_id)
	_require(Store._write_and_verify(abandoned_dir.path_join("metadata.part"), fixture),
			"an interrupted private review still owns its scratch file")
	blocked = null
	_require(not DirAccess.dir_exists_absolute(abandoned_dir) and FileAccess.get_file_as_bytes(unrelated) == fixture,
			"dropping the last review handle releases its ID and keeps the unrelated vocal")
	_legacy(song)
	_race(song)


func _legacy(song: SongResource) -> void:
	var id := song.id + "_19290613_162000_123"
	var path := Store.DIR.path_join(id + ".json")
	var legacy := {"version_id": id, "base_song_id": song.id, "created": "1929-06-13",
		"author_id": "you", "lyrics": {"s01": "Old pencil"}, "vocal_stem": "", "reconstruction_ratio": 1.414}
	var bytes := JSON.stringify(legacy, "  ").to_utf8_buffer()
	_require(Store._write_and_verify(path, bytes), "install an existing private version without conversion")
	_require(Store.versions_of(song.id).any(func(row): return row.get("version_id") == id and row.reconstruction_ratio == 1.414)
			and Store._reserve(song.id, id) == null and FileAccess.get_file_as_bytes(path) == bytes,
			"an old record is listed by its original version ID, retains its original speed and cannot be overwritten")


func _race(song: SongResource) -> void:
	var shared_id := song.id + "_19290613_162000_023"
	var gate := Semaphore.new()
	var worker := ReservationRace.new()
	var threads: Array[Thread] = []
	for index in 2:
		var thread := Thread.new()
		if thread.start(worker.reserve.bind(gate, song.id, shared_id)) == OK:
			threads.append(thread)
	for thread in threads:
		gate.post()
	var winners := []
	for thread in threads:
		var result: Variant = thread.wait_to_finish()
		if result != null:
			winners.append(result)
	_require(threads.size() == 2 and winners.size() == 1 and Store._reserve(song.id, shared_id) == null,
			"two simultaneous writers contending for the same ID have exactly one owner")
