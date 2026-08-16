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
const VOCALS := "user://songbook/vocals"


static func _ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(VOCALS)


## An id that sorts chronologically and cannot collide within a session.
static func _new_id(base_song_id: String) -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%s_%04d%02d%02d_%02d%02d%02d_%03d" % [
			base_song_id, t.year, t.month, t.day, t.hour, t.minute,
			t.second, randi() % 1000]


## Saves a version and, if there is one, its dry vocal beside it.
## `publish` is PRIVATE / FRIENDS / COMMUNITY - an explicit choice the
## player makes at the review screen, never a default.
static func save_version(song: SongResource, lyrics: Dictionary,
		vocal: AudioStreamWAV, publish := "PRIVATE",
		parent := "", author := "you", strict_meter := false) -> Dictionary:
	_ensure_dirs()
	var vid := _new_id(song.id)
	var vocal_path := ""
	if vocal != null and not vocal.data.is_empty():
		vocal_path = "%s/%s.wav" % [VOCALS, vid]
		vocal.save_to_wav(vocal_path)
	var record := {
		"version_id": vid,
		"base_song_id": song.id,
		"parent_version_id": parent,
		"author_id": author,
		"display_author": author,
		"title": song.title,
		"lyrics": lyrics,
		"strict_meter": strict_meter,
		"created": Time.get_datetime_string_from_system(),
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
	var file := FileAccess.open("%s/%s.json" % [DIR, vid], FileAccess.WRITE)
	if file == null:
		push_error("songbook: could not write version " + vid)
		return {}
	file.store_string(JSON.stringify(record, "  "))
	file.close()
	return record


static func versions_of(base_song_id := "") -> Array:
	_ensure_dirs()
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
