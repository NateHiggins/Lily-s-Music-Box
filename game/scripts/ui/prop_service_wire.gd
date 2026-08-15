class_name PropServiceWire
extends RefCounted
## Read-only adapter for the researched service-wire copy book. Mechanism
## owners supply public state tokens after they act; this class only formats a
## card. It never keeps prop state and it never invents a generic fallback.

const BOOK_PATH := "res://data/prop_service_wire.json"

static var _book: Dictionary = {}
static var _load_error := ""


static func is_valid() -> bool:
	_load()
	return _load_error.is_empty()


static func load_error() -> String:
	_load()
	return _load_error


static func card_record(card_id: String) -> Dictionary:
	_load()
	if not _load_error.is_empty():
		return {}
	var cards: Dictionary = _book.get("cards", {})
	var record: Variant = cards.get(card_id)
	return (record as Dictionary).duplicate(true) \
			if record is Dictionary else {}


static func card(card_id: String, values: Dictionary,
		condition_key := "default") -> Dictionary:
	var record := card_record(card_id)
	if record.is_empty() or not bool(record.get("presentable", true)):
		return {}
	var conditions: Variant = record.get("conditions", {})
	if conditions is not Dictionary:
		return {}
	var template := str((conditions as Dictionary).get(condition_key,
			(conditions as Dictionary).get("default", "")))
	var title := _fill(str(record.get("title", "")), values)
	var body := _fill(str(record.get("body", "")), values)
	var condition := _fill(template, values)
	if title.is_empty() or body.is_empty() or condition.is_empty():
		return {}
	return {
		"title": title,
		"body": body,
		"condition": condition,
		"stamp": "SERVICE NOTE",
		"card_id": card_id,
		"source_ids": (record.get("source_ids", []) as Array).duplicate(),
	}


static func clear_cache_for_tests() -> void:
	_book.clear()
	_load_error = ""


static func _load() -> void:
	if not _book.is_empty() or not _load_error.is_empty():
		return
	var file := FileAccess.open(BOOK_PATH, FileAccess.READ)
	if file == null:
		_load_error = "service-wire book missing: %s" % BOOK_PATH
		push_warning(_load_error)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		_load_error = "service-wire book root is not a dictionary"
		push_warning(_load_error)
		return
	if int((parsed as Dictionary).get("schema", 0)) != 1:
		_load_error = "service-wire book schema is not 1"
		push_warning(_load_error)
		return
	var cards: Variant = (parsed as Dictionary).get("cards")
	var rows: Variant = (parsed as Dictionary).get("matrix_rows")
	if cards is not Dictionary or (cards as Dictionary).is_empty():
		_load_error = "service-wire book has no cards"
	elif rows is not Array or (rows as Array).is_empty():
		_load_error = "service-wire book has no matrix registry"
	if not _load_error.is_empty():
		push_warning(_load_error)
		return
	_book = (parsed as Dictionary).duplicate(true)


static func _fill(template: String, values: Dictionary) -> String:
	var resolved := template
	for key in values:
		resolved = resolved.replace("{%s}" % str(key), str(values[key]))
	# Braces are reserved for owner tokens. An unresolved one means the owner
	# has not supplied enough truth to print this card.
	if resolved.contains("{") or resolved.contains("}"):
		return ""
	return resolved.strip_edges()
