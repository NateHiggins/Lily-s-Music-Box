class_name SongbookStore
extends RefCounted
## Where versions live.
##
## Phase 1 only has to save one, but the record it saves is already the
## brief's `CommunitySongVersion` shape — version_id, base_song_id,
## parent_version_id, author, lyrics, publish state, counters — because
## the alternative is writing a smaller thing now and migrating every
## saved performance later. Phase 2's genealogy is then a reader over
## files that already have parents.
##
## Two rules from the brief, honoured here rather than remembered later:
## versions are NEVER overwritten (a new take is a new file with a
## parent), and the backing track is never stored with them. What lands
## on disk is metadata, the lyrics, and one dry vocal.

const DIR := "user://songbook"
const PERFORMED_SECONDS := "performed_seconds"
const VOCALS := "user://songbook/vocals"
const PENDING := "user://songbook/vocals/.pending"
## This optional metadata member marks every post-tray publication, including a
## completed local write awaiting a campaign save. Older files are left intact.
const PHYSICAL_EDITION_KEY := "physical_original_version"
## The earliest writer stored no speed. G1a first assigned this fixed reading
## to Last Train Home. Keep it independent of subsequent catalogue retuning.
const FIRST_READING_RATIOS := {"track_018": 1.335}


## Retain one handle while reviewing or retrying a take. Its directory reserves
## one version ID across processes; only the owning handle writes these paths.
class KeepAttempt extends RefCounted:
	var version_id: String:
		get: return _id
	var _id := ""
	var _song_id := ""
	var _dir := ""
	var _created := ""
	var _intent := ""
	var _receipt := {}
	var _mutex := Mutex.new()
	var _unpublished_voice := ""

	func _clean_files() -> bool:
		if not _remove_staged_files(_dir, _unpublished_voice):
			return false
		_unpublished_voice = ""
		return true

	static func _remove_staged_files(directory: String, unpublished_voice: String) -> bool:
		if directory.is_empty():
			return true
		for path in [directory.path_join("voice.wav"), directory.path_join("metadata.part"), unpublished_voice]:
			if not str(path).is_empty() and FileAccess.file_exists(path):
				if DirAccess.remove_absolute(path) != OK:
					return false
		return true

	func _release() -> void:
		if not _dir.is_empty() and _clean_files() and DirAccess.remove_absolute(_dir) == OK:
			_dir = ""

	func _notification(what: int) -> void:
		# At refcount zero the script can read its fields but cannot call another
		# method on itself. Pass the owned paths to the static cleanup directly.
		if what == NOTIFICATION_PREDELETE and not _dir.is_empty():
			if KeepAttempt._remove_staged_files(_dir, _unpublished_voice):
				DirAccess.remove_absolute(_dir)


## Preserve the original stem and JSON filename format. Exclusive directory
## creation handles equal timestamp/random suffixes without truncating a take.
static func _new_id(base_song_id: String) -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%s_%04d%02d%02d_%02d%02d%02d_%03d" % [
			base_song_id, t.year, t.month, t.day, t.hour, t.minute,
			t.second, randi() % 1000]


static func _occupied(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


static func _reserve(song_id: String, id: String) -> KeepAttempt:
	if not id.is_valid_filename() or not id.begins_with(song_id + "_"):
		return null
	var dir := PENDING.path_join(id)
	if DirAccess.make_dir_absolute(dir) != OK:
		return null
	if _occupied(DIR.path_join(id + ".json")) or _occupied(VOCALS.path_join(id + ".wav")):
		DirAccess.remove_absolute(dir)
		return null
	var attempt := KeepAttempt.new()
	attempt._id = id
	attempt._song_id = song_id
	attempt._dir = dir
	return attempt


static func begin_keep_attempt(song: SongResource) -> KeepAttempt:
	if song == null or song.id.is_empty() or not song.id.is_valid_filename():
		return null
	for directory in [VOCALS, PENDING]:
		if not DirAccess.dir_exists_absolute(directory) and DirAccess.make_dir_recursive_absolute(directory) != OK:
			if not DirAccess.dir_exists_absolute(directory):
				return null
	for trial in 64:
		var attempt := _reserve(song.id, _new_id(song.id))
		if attempt != null:
			attempt._created = CampaignClock.new().datetime_string()
			return attempt
	return null


## Saves a version and, if there is one, its dry vocal beside it.
## `publish` is PRIVATE / FRIENDS / COMMUNITY - an explicit choice the
## player makes at the review screen, never a default.
static func save_version(song: SongResource, lyrics: Dictionary,
		vocal: AudioStreamWAV, publish := "PRIVATE",
		parent := "", author := "you", strict_meter := false, attempt: KeepAttempt = null,
		performed_seconds := -1.0) -> Dictionary:
	if song == null or not is_finite(song.return_ratio) or song.return_ratio <= 1.0:
		return {}
	if performed_seconds != -1.0 and (not is_finite(performed_seconds) or performed_seconds < 0.0):
		return {}
	if publish not in ["PRIVATE", "FRIENDS", "COMMUNITY"]:
		return {}
	for key in lyrics:
		if typeof(key) != TYPE_STRING or typeof(lyrics[key]) != TYPE_STRING:
			return {}
	if attempt == null:
		attempt = begin_keep_attempt(song)
	if attempt == null or attempt._song_id != song.id or not attempt._mutex.try_lock():
		return {}
	var record := _save_locked(song, lyrics, vocal, publish, parent, author, strict_meter, attempt, performed_seconds)
	attempt._mutex.unlock()
	return record


static func _save_locked(song: SongResource, lyrics: Dictionary, vocal: AudioStreamWAV,
		publish: String, parent: String, author: String, strict_meter: bool, attempt: KeepAttempt, performed_seconds: float) -> Dictionary:
	var vid := attempt.version_id
	var vocal_path := VOCALS.path_join(vid + ".wav") if vocal != null else ""
	var record := {
		"version_id": vid,
		"base_song_id": song.id,
		"parent_version_id": parent,
		"author_id": author,
		"display_author": author,
		"title": song.title,
		"lyrics": lyrics,
		"strict_meter": strict_meter,
		"created": attempt._created,
		"vocal_stem": vocal_path,
		# TASKS.md G1a: the version's one immutable too-fast reconstruction.
		# Recipients hear base + vocal varisped together at exactly this
		# ratio, every listen, forever. Never route a published version
		# through PhonautogramReader.guess_speed() - the fresh-guess reader
		# is a found-trace instrument.
		"reconstruction_ratio": song.return_ratio,
		"publish": publish,
		# The brief scores culture, not pitch. These start at zero and
		# are moved by other people, which is the whole idea.
		"covers": 0, "mutations": 0, "singalong_count": 0,
		"performance_count": 1,
	}
	record[PHYSICAL_EDITION_KEY] = 1
	if performed_seconds >= 0.0:
		record[PERFORMED_SECONDS] = performed_seconds
	var arrangement := SongSynth.current_arrangement(song.id)
	if not arrangement.is_empty():
		record["backing_arrangement"] = arrangement
	var metadata := JSON.stringify(record, "  ", true, true).to_utf8_buffer()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(metadata)
	var pcm := PackedByteArray()
	if vocal != null:
		pcm = vocal.data
		if pcm.is_empty() or vocal.format not in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS]:
			return {}
		var sample_bytes := 1 if vocal.format == AudioStreamWAV.FORMAT_8_BITS else 2
		var channels := 2 if vocal.stereo else 1
		if vocal.mix_rate <= 0 or pcm.size() % (channels * sample_bytes) != 0:
			return {}
		hash.update(("%d/%d/%d/" % [channels, sample_bytes, vocal.mix_rate]).to_utf8_buffer())
		hash.update(pcm)
	var intent := hash.finish().hex_encode()
	if not attempt._intent.is_empty() and intent != attempt._intent:
		return {}
	var metadata_path := DIR.path_join(vid + ".json")
	if not attempt._receipt.is_empty():
		if not FileAccess.file_exists(metadata_path) or FileAccess.get_file_as_bytes(metadata_path) != metadata:
			return {}
		if vocal != null and not _valid_wav(vocal_path, vocal, pcm):
			return {}
		return attempt._receipt.duplicate(true)
	if attempt._dir.is_empty() or not attempt._clean_files():
		return {}
	attempt._intent = intent
	var part := attempt._dir.path_join("metadata.part")
	if not _write_and_verify(part, metadata):
		attempt._clean_files()
		return {}
	if vocal != null:
		var voice_part := attempt._dir.path_join("voice.wav")
		if vocal.save_to_wav(voice_part) != OK or not _valid_wav(voice_part, vocal, pcm):
			attempt._clean_files()
			return {}
		if not _promote(voice_part, vocal_path):
			attempt._clean_files()
			return {}
		attempt._unpublished_voice = vocal_path
	# A single same-volume rename to a previously absent name makes the
	# complete version visible. The per-ID reservation stays ours throughout.
	if not _promote(part, metadata_path):
		attempt._clean_files()
		return {}
	attempt._unpublished_voice = ""
	attempt._receipt = record.duplicate(true)
	attempt._release()
	return record


static func _write_and_verify(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_buffer(bytes)
	file.flush()
	var ok := stored and file.get_error() == OK
	file.close()
	return ok and FileAccess.get_file_as_bytes(path) == bytes


static func _promote(source: String, target: String) -> bool:
	return not _occupied(target) and DirAccess.rename_absolute(source, target) == OK


## Read only the PCM layout written by the local recording store. Check the
## chunk sizes against the actual file before accepting any samples.
static func _read_pcm(path: String) -> AudioStreamWAV:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 44:
		return null
	var size := file.get_length() - 44
	var header := file.get_buffer(44)
	if header.size() != 44 or header.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or header.decode_u32(4) != 36 + size or header.slice(8, 16).get_string_from_ascii() != "WAVEfmt " \
			or header.decode_u32(16) != 16 or header.decode_u16(20) != 1 \
			or header.slice(36, 40).get_string_from_ascii() != "data" or header.decode_u32(40) != size:
		return null
	var channels := header.decode_u16(22)
	var rate := header.decode_u32(24)
	var bits := header.decode_u16(34)
	if channels not in [1, 2] or bits not in [8, 16] or rate <= 0 or rate > 2147483647:
		return null
	var alignment := channels * (bits >> 3)
	if size % alignment != 0 or header.decode_u16(32) != alignment or header.decode_u32(28) != rate * alignment:
		return null
	var samples := file.get_buffer(size)
	if samples.size() != size:
		return null
	if bits == 8:
		for i in samples.size():
			samples[i] = (samples[i] + 128) & 255
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_8_BITS if bits == 8 else AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = rate
	wave.stereo = channels == 2
	wave.data = samples
	return wave


static func _valid_wav(path: String, source: AudioStreamWAV, pcm: PackedByteArray) -> bool:
	var decoded := _read_pcm(path)
	return decoded != null and decoded.format == source.format and decoded.stereo == source.stereo \
			and decoded.mix_rate == source.mix_rate and decoded.data == pcm


## Look up a single carried edition. Never discover what someone else recorded
## by enumerating the profile, or follow a stem path supplied by metadata.
static func private_edition(id: String, backing: String) -> Dictionary:
	if backing.is_empty() or CarriedCase.recorded_song_id(id) != backing:
		return {}
	var profile := DirAccess.open("user://")
	var root := DirAccess.open(DIR)
	var name := id + ".json"
	if profile == null or profile.is_link("songbook") or root == null or root.is_link(name) or not root.file_exists(name):
		return {}
	var row: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(name)))
	if row is not Dictionary or row.get("publish") != "PRIVATE" or row.get("version_id") != id \
			or row.get("base_song_id") != backing or row.get("lyrics") is not Dictionary:
		return {}
	if _playback_ratio(row) <= 1.0:
		return {}
	if row.has(PERFORMED_SECONDS):
		var end: Variant = row[PERFORMED_SECONDS]
		if typeof(end) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(end)) or float(end) < 0.0:
			return {}
	var stem: Variant = row.get("vocal_stem")
	if stem is not String or (not stem.is_empty() and stem != VOCALS.path_join(id + ".wav")):
		return {}
	for key: Variant in row.lyrics:
		if key is not String or row.lyrics[key] is not String:
			return {}
	return row


static func _playback_ratio(row: Dictionary) -> float:
	if not row.has("reconstruction_ratio") and not row.has(PHYSICAL_EDITION_KEY):
		return FIRST_READING_RATIOS.get(row.get("base_song_id"), 0.0)
	var ratio: Variant = row.get("reconstruction_ratio")
	if typeof(ratio) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(PackedFloat32Array([float(ratio)])[0]):
		return 0.0
	return float(ratio)


## Only the explicit recovery prompt may browse pre-tray recordings. An
## immutable edition published by the new recorder is ineligible even if its
## subsequent campaign save failed or it belongs to another campaign.
static func legacy_ids(backing: String) -> Array[String]:
	var ids: Array[String] = []
	var profile := DirAccess.open("user://")
	if profile == null or profile.is_link("songbook") or not profile.dir_exists("songbook"):
		return ids
	var root := DirAccess.open(DIR)
	if root == null:
		return ids
	for name: String in root.get_files():
		if not name.ends_with(".json"):
			continue
		var id := name.trim_suffix(".json")
		var row := private_edition(id, backing)
		if not row.is_empty() and not row.has(PHYSICAL_EDITION_KEY):
			ids.append(id)
	ids.sort()
	ids.reverse()
	return ids


## Always reopen the chosen edition. A promised but missing/corrupt vocal
## returns null while its retained lyrics remain available on the sleeve.
static func private_playback(id: String, backing: String, legacy_only := false) -> Dictionary:
	var row := private_edition(id, backing)
	if legacy_only and row.has(PHYSICAL_EDITION_KEY):
		return {}
	if not row.is_empty():
		row["playback_ratio"] = _playback_ratio(row)
		row["vocal"] = null if row.vocal_stem.is_empty() else _local_vocal(id)
	return row


static func _local_vocal(id: String) -> AudioStreamWAV:
	var profile := DirAccess.open("user://")
	var root := DirAccess.open(DIR)
	var voices := DirAccess.open(VOCALS)
	var name := id + ".wav"
	if profile == null or profile.is_link("songbook") or root == null or root.is_link("vocals") \
			or voices == null or voices.is_link(name) or not voices.file_exists(name):
		return null
	return _read_pcm(VOCALS.path_join(name))


static func versions_of(base_song_id := "") -> Array:
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if not str(f).ends_with(".json"):
			continue
		var file := FileAccess.open("%s/%s" % [DIR, f], FileAccess.READ)
		if file == null:
			continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		if typeof(data) != TYPE_DICTIONARY:
			continue
		if base_song_id != "" \
				and str(data.get("base_song_id", "")) != base_song_id:
			continue
		out.append(data)
	out.sort_custom(func(a, b): return str(a.get("created", "")) \
			> str(b.get("created", "")))
	return out


## The Songbook's own shelf labels. Phase 1 can answer three of them
## honestly; the rest need other people's versions to mean anything.
static func shelves(base_song_id := "") -> Dictionary:
	var all := versions_of(base_song_id)
	var mine: Array = []
	var unfinished: Array = []
	for v in all:
		if str(v.get("author_id", "")) == "you":
			mine.append(v)
		var lyrics: Dictionary = v.get("lyrics", {})
		var written := 0
		for k in lyrics:
			if str(lyrics[k]).strip_edges() != "":
				written += 1
		if written < lyrics.size():
			unfinished.append(v)
	return {"recently_written": all, "my_songs": mine,
			"nobody_has_finished": unfinished}
