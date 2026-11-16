class_name CastBodies
extends RefCounted
## Which residents wear the rebuilt bodies. One short list in data: a resident
## named there, whose rebuilt files are installed, is given the rebuilt body;
## everyone else keeps the old one. Taking a name off the list puts the old
## body back, and nothing else has to change. (Lily, 2026-11-12: one person at
## a time, Cal Dwyer first.)

const LIST_PATH := "res://data/characters/cast_bodies.json"
const CAST_BASE := "res://assets/characters/cast"

static var _residents: Array = []
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(LIST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIST_PATH))
	if parsed is Dictionary and int(parsed.get("schema_version", 0)) == 1 and parsed.get("residents") is Array:
		_residents = (parsed.residents as Array).duplicate()


static func old_model(id: String) -> String:
	return "res://assets/characters/%s/%s.gltf" % [id, id]


## The rebuilt person a resident wears. The transient guests are one resident on the route but two people in
## the cast (_a and _b); the resident wears the first, as the old single body did.
const CAST_PERSON := {"transient_guests": "transient_guests_a"}


static func cast_person(id: String) -> String:
	return str(CAST_PERSON.get(id, id))


static func cast_model(id: String) -> String:
	var who := cast_person(id)
	return "%s/%s/%s.gltf" % [CAST_BASE, who, who]


## On the list, and the files are there to wear.
static func wears_cast_body(id: String) -> bool:
	_load()
	return id in _residents and ResourceLoader.exists(cast_model(id))


## The model a resident is built from: the rebuilt one when they wear it, else the old one.
static func model_for(id: String) -> String:
	return cast_model(id) if wears_cast_body(id) else old_model(id)


static func is_cast_path(path: String) -> bool:
	return path.begins_with(CAST_BASE + "/")


const SEATED_PATH := "res://data/characters/seated_support.json"
static var _seated: Dictionary = {}
static var _seated_clip := ""
static var _seated_loaded := false


## How far above a resident's origin their body meets the seat on the seated clip, measured on the rebuilt body
## they wear: the lowest point under the buttocks and upper thighs across the clip's loop, so the body never
## sinks into the seat (C:/ov/reports/seat_heights_20261116, 2026-11-16; the old bodies measured 0.454-0.485
## against the 0.48 the luncheonette was set to). Anyone on an old body, unmeasured, or seated on another clip
## keeps `fallback`.
static func seated_support(id: String, clip: String, fallback: float) -> float:
	if not _seated_loaded:
		_seated_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEATED_PATH)) if FileAccess.file_exists(SEATED_PATH) else null
		if parsed is Dictionary and int(parsed.get("schema_version", 0)) == 1 and parsed.get("residents") is Dictionary:
			_seated = parsed.residents
			_seated_clip = str(parsed.get("clip", ""))
	if clip != _seated_clip or not wears_cast_body(id) or not _seated.has(id):
		return fallback
	return float(_seated[id])


## A test names who wears a rebuilt body without touching the file; an empty call reads the file again.
static func set_for_test(residents: Variant = null) -> void:
	if residents is Array:
		_loaded = true
		_residents = (residents as Array).duplicate()
	else:
		_loaded = false
		_residents = []
