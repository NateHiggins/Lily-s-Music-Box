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


static func cast_model(id: String) -> String:
	return "%s/%s/%s.gltf" % [CAST_BASE, id, id]


## On the list, and the files are there to wear.
static func wears_cast_body(id: String) -> bool:
	_load()
	return id in _residents and ResourceLoader.exists(cast_model(id))


## The model a resident is built from: the rebuilt one when they wear it, else the old one.
static func model_for(id: String) -> String:
	return cast_model(id) if wears_cast_body(id) else old_model(id)


static func is_cast_path(path: String) -> bool:
	return path.begins_with(CAST_BASE + "/")


## A test names who wears a rebuilt body without touching the file; an empty call reads the file again.
static func set_for_test(residents: Variant = null) -> void:
	if residents is Array:
		_loaded = true
		_residents = (residents as Array).duplicate()
	else:
		_loaded = false
		_residents = []
