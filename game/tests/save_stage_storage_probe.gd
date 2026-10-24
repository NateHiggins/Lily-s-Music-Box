extends "res://scripts/game/reality_save_storage.gd"
## INERT diagnostic: same storage operations, optional sparse UTF-8 candidate.
var fast_utf8 := false
var records: Array = []
func sparse_utf8(bytes: PackedByteArray) -> bool:
	return super._valid_utf8(bytes)

func _valid_utf8(bytes: PackedByteArray) -> bool:
	var started := Time.get_ticks_usec()
	var result := super._valid_utf8(bytes) if fast_utf8 else super._valid_utf8_full(bytes)
	records.append({"stage":"utf8", "usec":Time.get_ticks_usec()-started, "bytes":bytes.size()})
	return result

func _decode(bytes: PackedByteArray) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super._decode(bytes)
	records.append({"stage":"decode", "usec":Time.get_ticks_usec()-started, "bytes":bytes.size()})
	return result

func _op(stage: String, operation: String, arguments: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super._op(stage, operation, arguments)
	records.append({"stage":stage, "operation":operation, "usec":Time.get_ticks_usec()-started})
	return result

func _hash(bytes: PackedByteArray) -> String:
	var started := Time.get_ticks_usec()
	var result := super._hash(bytes)
	records.append({"stage":"hash", "usec":Time.get_ticks_usec()-started, "bytes":bytes.size()})
	return result
