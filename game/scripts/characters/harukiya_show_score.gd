extends RefCounted
## The shipped recording and the approved trio's cues share one time origin.
const SONG := preload("res://assets/audio/music/title/pull_up_a_chair.ogg")
const SCORE := "res://data/orison_v2/harukiya_show_score.json"
const VOICE_IDS := ["adela_voss", "lily"]
const INSTRUMENTS := ["piano", "snare", "kick", "hihat"]

var duration := 0.0
var voices: Dictionary = {}
var attacks: Array = []
var bass_notes: Array = []
var anchors: Dictionary = {}
var routes: Dictionary = {}


func load_score() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCORE))
	if data is not Dictionary or data.get("schema_version", 0) != 1:
		return false
	var seconds: Variant = data.get("duration")
	if not _number(seconds) or absf(float(seconds) - SONG.get_length()) > 0.02:
		return false
	var mouth: Variant = data.get("voices")
	var beats: Variant = data.get("attacks")
	var notes: Variant = data.get("bass_notes")
	if mouth is not Dictionary or mouth.size() != VOICE_IDS.size() \
			or beats is not Array or beats.is_empty() or notes is not Array or notes.is_empty():
		return false
	for person: String in VOICE_IDS:
		if not _validate_mouth(mouth.get(person), float(seconds)):
			return false
	if not _validate_attacks(beats, float(seconds)) or not _validate_bass(notes, float(seconds)):
		return false
	var layout: Variant = data.get("anchors")
	if layout is not Dictionary:
		return false
	var positions := {}
	for id: String in ["bass_endpin", "audience_eyeline", "music_source"]:
		var point: Variant = layout.get(id)
		if point is not Array or point.size() != 3 or not point.all(_number):
			return false
		positions[id] = GameBoot.b2g(point)
	var authored: Variant = data.get("routes")
	if authored is not Dictionary:
		return false
	var paths := {}
	for id: String in ["adela_voss", "lily", "stacy"]:
		var points: Variant = authored.get(id)
		if points is not Array or points.is_empty():
			return false
		var path := PackedVector3Array()
		for point: Variant in points:
			if point is not Array or point.size() != 3 or not point.all(_number):
				return false
			path.append(GameBoot.b2g(point))
		paths[id] = path
	duration = float(seconds)
	voices = mouth
	attacks = beats
	bass_notes = notes
	anchors = positions
	routes = paths
	return true


static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _unit(value: Variant) -> bool:
	return _number(value) and float(value) >= 0.0 and float(value) <= 1.0


static func _validate_mouth(rows: Variant, duration_seconds: float) -> bool:
	if rows is not Array or rows.is_empty():
		return false
	var previous_end := 0.0
	for row: Variant in rows:
		if row is not Dictionary or not _number(row.get("start")) or not _number(row.get("end")) \
				or not _unit(row.get("strength")) or str(row.get("value", "")) not in ["A", "B", "C", "D", "E", "F", "G", "H", "X"]:
			return false
		var start := float(row.start)
		var end := float(row.end)
		if start < previous_end or end <= start or end > duration_seconds:
			return false
		previous_end = end
	return true


static func _validate_attacks(rows: Array, duration_seconds: float) -> bool:
	var previous := 0.0
	for row: Variant in rows:
		if row is not Dictionary or not _number(row.get("time")) or not _unit(row.get("strength")):
			return false
		var instrument := str(row.get("instrument", ""))
		var side := str(row.get("side", ""))
		if instrument not in INSTRUMENTS or (instrument != "kick" and side not in ["left", "right"]):
			return false
		var at := float(row.time)
		if at < previous or at >= duration_seconds:
			return false
		previous = at
	return true


static func _validate_bass(rows: Array, duration_seconds: float) -> bool:
	var previous := -1.0
	for row: Variant in rows:
		if row is not Dictionary or not _number(row.get("seconds")) or not _number(row.get("duration")) \
				or not _unit(row.get("velocity")) or not _number(row.get("midi")):
			return false
		var at := float(row.seconds)
		var held := float(row.duration)
		var pitch := float(row.midi)
		# Four strings given by the original instrument, in first position through octave.
		if at < 0.0 or at <= previous or held <= 0.0 or at + held > duration_seconds \
				or pitch < 28.0 or pitch > 55.0 or pitch != floorf(pitch):
			return false
		previous = at
	return true
