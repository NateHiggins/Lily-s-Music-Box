class_name OrisonV2Broadcast
extends RefCounted
## The one programme every V2 household receiver hears. A receiver never picks
## its own song: it asks what the house is broadcasting now and joins it at the
## live position, so two sets in neighbouring rooms play the same bar.
##
## The programme starts the first time anyone switches a set on, so the first
## listener hears the running order from its first record. It then runs on a
## wall clock whether or not anyone is listening, and wraps after the last
## record. Nothing is persisted: a new runtime starts a new broadcast.

const PATH := "res://data/orison_v2/broadcast_programme.json"
const CATALOG := "res://data/music_catalog.json"

static var _records: Array[Dictionary] = []
static var _loaded := false
static var _started_msec := -1
static var errors: Array[String] = []


## The running order, each record resolved to {id, title, performers, year,
## stream, length}. Records whose stream is missing are refused and reported.
static func records() -> Array[Dictionary]:
	if not _loaded:
		_load()
	return _records


static func _load() -> void:
	_loaded = true
	_records.clear()
	errors.clear()
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if source is not Dictionary or source.get("schema_version") != 1 \
			or source.get("running_order") is not Array:
		errors.append("malformed broadcast programme")
		return
	var library: Dictionary = catalog.get("tracks", {}) if catalog is Dictionary else {}
	for entry: Variant in source.running_order:
		if entry is not Dictionary or entry.get("id") is not String:
			errors.append("broadcast record without an id")
			continue
		var record := {"id": str(entry.id)}
		var from := str(entry.get("catalog_track", ""))
		if not from.is_empty():
			# A V1 library record: the catalogue stays its single authority.
			if not library.has(from):
				errors.append("broadcast record names a missing catalogue track: " + from)
				continue
			var track: Dictionary = library[from]
			record.title = str(track.get("title", from))
			record.performers = str(track.get("artist", ""))
			record.year = int(track.get("year", 0))
			record.path = str(track.get("path", ""))
		else:
			record.title = str(entry.get("title", ""))
			record.performers = str(entry.get("performers", ""))
			record.year = int(entry.get("year", 0))
			record.path = str(entry.get("path", ""))
		var stream := load(record.path) as AudioStream if ResourceLoader.exists(record.path) else null
		if stream == null or stream.get_length() <= 0.0:
			errors.append("broadcast record has no playable stream: " + record.id)
			continue
		record.stream = stream
		record.length = stream.get_length()
		_records.append(record)
	if _records.is_empty():
		errors.append("broadcast programme has no playable record")


## Starts the broadcast clock if nobody has yet. Called when a set is switched on.
static func tune_in() -> Dictionary:
	if _started_msec < 0:
		_started_msec = Time.get_ticks_msec()
	return now_playing()


## What is on the air now: the record and how far into it the broadcast is.
## Empty when the programme has not started or holds nothing playable.
static func now_playing() -> Dictionary:
	var order := records()
	if _started_msec < 0 or order.is_empty():
		return {}
	var total := 0.0
	for record in order:
		total += float(record.length)
	var at := fposmod((Time.get_ticks_msec() - _started_msec) / 1000.0, total)
	for index in order.size():
		var record: Dictionary = order[index]
		if at < float(record.length):
			return {"index": index, "id": record.id, "title": record.title,
					"performers": record.performers, "year": record.year,
					"stream": record.stream, "offset": at}
		at -= float(record.length)
	return {"index": 0, "id": order[0].id, "title": order[0].title,
			"performers": order[0].performers, "year": order[0].year,
			"stream": order[0].stream, "offset": 0.0}


## Puts a switched-on receiver's emitter on the air at the live position. The
## emitter's own carrier stream (the old programme murmur) is kept aside and is
## what plays if the programme holds nothing playable. When a record ends the
## emitter rejoins, which is the next record from its first bar.
static func join(player: AudioStreamPlayer3D, volume_db: float) -> Dictionary:
	if player == null:
		return {}
	var now := tune_in()
	if not player.has_meta("broadcast_carrier"):
		player.set_meta("broadcast_carrier", player.stream)
		player.set_meta("broadcast_carrier_db", player.volume_db)
		player.finished.connect(func():
			if player.has_meta("broadcast_on"):
				join(player, volume_db))
	player.set_meta("broadcast_on", true)
	if now.is_empty():
		restore_carrier(player)
		player.set_meta("broadcast_on", true)
		player.play()
		return now
	player.stream = now.stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0
	player.play(float(now.offset))
	player.set_meta("broadcast_record", now.id)
	player.set_meta("broadcast_title", now.title)
	return now


static func leave(player: AudioStreamPlayer3D) -> void:
	if player == null:
		return
	player.remove_meta("broadcast_on")
	player.remove_meta("broadcast_record")
	player.remove_meta("broadcast_title")
	player.stop()


## Hands the emitter its carrier back, so the prop's own audio cleanup releases
## the stream it borrowed rather than a broadcast record.
static func restore_carrier(player: AudioStreamPlayer3D) -> void:
	if player == null or not player.has_meta("broadcast_carrier"):
		return
	player.stop()
	player.stream = player.get_meta("broadcast_carrier")
	player.volume_db = float(player.get_meta("broadcast_carrier_db"))
	player.remove_meta("broadcast_on")


static func on_air(player: AudioStreamPlayer3D) -> String:
	if player == null:
		return ""
	return str(player.get_meta("broadcast_title", ""))


## Tests only: forget the clock so the next tune_in starts from the first record.
static func reset_for_test() -> void:
	_started_msec = -1
	_loaded = false
