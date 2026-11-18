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
## The clock is a tick count that a request may push before zero, so whether
## the broadcast has started is kept apart from it.
static var _started := false
static var _started_msec := 0
static var _on_air: Array[WeakRef] = []
## Card breaks (the programme director, v1r_broadcast_director_20261109): after
## every `break_every` records the station holds for `break_seconds` while a
## card is read. With either at zero the running order never breaks.
static var break_every := 0
static var break_seconds := 0.0
## The words of the card being read, set by the director while a break runs.
static var card := ""
static var _slot_cache: Array = []
static var _slot_rule: Array = []
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
	if not _started:
		_started = true
		_started_msec = Time.get_ticks_msec()
	return now_playing()


## The air time in order, as [record index, seconds] with -1 for a card break.
## Rebuilt only when the running order or the break rule changes.
static func _slots() -> Array:
	var order := records()
	if _slot_rule == [order.size(), break_every, break_seconds]:
		return _slot_cache
	_slot_rule = [order.size(), break_every, break_seconds]
	_slot_cache = []
	var breaks := break_every > 0 and break_seconds > 0.0
	for index in order.size():
		_slot_cache.append([index, float(order[index].length)])
		if breaks and (index + 1) % break_every == 0:
			_slot_cache.append([-1, break_seconds])
	return _slot_cache


## What is on the air now: the record and how far into it the broadcast is, or
## {"break": true, "remaining": seconds} while a card is read. Empty when the
## programme has not started or holds nothing playable.
static func now_playing() -> Dictionary:
	var order := records()
	if not _started or order.is_empty():
		return {}
	var slots := _slots()
	var total := 0.0
	for slot: Array in slots:
		total += float(slot[1])
	var at := fposmod((Time.get_ticks_msec() - _started_msec) / 1000.0, total)
	for slot: Array in slots:
		var length := float(slot[1])
		if at < length:
			if int(slot[0]) < 0:
				return {"break": true, "offset": at, "remaining": length - at}
			return _on_the_air(int(slot[0]), at)
		at -= length
	return _on_the_air(0, 0.0)


static func _on_the_air(index: int, offset: float) -> Dictionary:
	var record: Dictionary = records()[index]
	return {"index": index, "id": record.id, "title": record.title,
			"performers": record.performers, "year": record.year,
			"stream": record.stream, "offset": offset}


## Puts a switched-on receiver's emitter on the air at the live position. The
## emitter's own carrier stream (the old programme murmur) is kept aside and is
## what plays if the programme holds nothing playable. When a record ends the
## emitter rejoins, which is the next record from its first bar. During a card
## break the emitter plays its carrier and rejoins when the break is over.
static func join(player: AudioStreamPlayer3D, volume_db: float) -> Dictionary:
	if player == null:
		return {}
	var now := tune_in()
	var turn := int(player.get_meta("broadcast_turn", 0)) + 1
	player.set_meta("broadcast_turn", turn)
	if not player.has_meta("broadcast_carrier"):
		player.set_meta("broadcast_carrier", player.stream)
		player.set_meta("broadcast_carrier_db", player.volume_db)
		_on_air.append(weakref(player))
		player.finished.connect(func():
			if player.has_meta("broadcast_on"):
				join(player, volume_db))
	player.set_meta("broadcast_on", true)
	player.set_meta("broadcast_db", volume_db)
	if now.is_empty():
		restore_carrier(player)
		player.set_meta("broadcast_on", true)
		player.play()
		return now
	if bool(now.get("break", false)):
		player.stream = player.get_meta("broadcast_carrier")
		player.volume_db = float(player.get_meta("broadcast_carrier_db"))
		player.pitch_scale = 1.0
		player.play()
		player.remove_meta("broadcast_record")
		player.remove_meta("broadcast_title")
		player.set_meta("broadcast_break", true)
		if player.is_inside_tree():
			player.get_tree().create_timer(float(now.remaining) + 0.03).timeout.connect(func():
				if is_instance_valid(player) and player.has_meta("broadcast_on") \
						and int(player.get_meta("broadcast_turn", 0)) == turn:
					join(player, volume_db))
		return now
	player.remove_meta("broadcast_break")
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
	player.remove_meta("broadcast_break")
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
	player.remove_meta("broadcast_break")


static func on_air(player: AudioStreamPlayer3D) -> String:
	if player == null:
		return ""
	return str(player.get_meta("broadcast_title", ""))


## The card a set is carrying: the words being read while it is in a break.
static func card_on_air(player: AudioStreamPlayer3D) -> String:
	if player == null or not player.has_meta("broadcast_break"):
		return ""
	return card


## The sets on the air now. A set that has been freed or switched off is not one.
static func listeners() -> Array[AudioStreamPlayer3D]:
	var found: Array[AudioStreamPlayer3D] = []
	var kept: Array[WeakRef] = []
	for held in _on_air:
		var player := held.get_ref() as AudioStreamPlayer3D
		if player == null or not is_instance_valid(player):
			continue
		kept.append(held)
		if player.has_meta("broadcast_on"):
			found.append(player)
	_on_air = kept
	return found


## A request (the earned library, v1r_music_director_20261109): the named record
## goes on the air now from its first bar, on every set that is on, and the
## running order carries on from it. False when the programme has no such record.
static func request(record_id: String) -> bool:
	var order := records()
	var before := 0.0
	for slot: Array in _slots():
		if int(slot[0]) >= 0 and str(order[int(slot[0])].id) == record_id:
			_started = true
			_started_msec = Time.get_ticks_msec() - int(ceil(before * 1000.0)) - 1
			for player in listeners():
				join(player, float(player.get_meta("broadcast_db", player.volume_db)))
			return true
		before += float(slot[1])
	return false


## Tests only: forget the clock so the next tune_in starts from the first record.
static func reset_for_test() -> void:
	_started = false
	_started_msec = 0
	_loaded = false
	_on_air.clear()
	card = ""
	_slot_rule = []
