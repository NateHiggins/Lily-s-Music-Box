class_name RealitySaveStorage
extends RefCounted
## Single-process, crash-recoverable file replacement. Godot's Windows rename
## can delete its destination before moving the source. A verified backup is
## therefore retained throughout promotion. This is NOT native atomic replace
## or a power-loss durability guarantee (flush/close expose no checked fsync).

var path := ""
var validate_document: Callable
## Test-only seam: (stage, operation, arguments) -> null for the real operation,
## or its result Dictionary to inject a failure/short read/write. No production
## consumer installs it. Tests can exit a separate process at these boundaries.
var operation_override: Callable


func load_snapshot() -> Dictionary:
	var primary := _read(path, "load_primary")
	if primary.kind == "unreadable":
		return _protected("save_read_failed", "load_primary")
	if primary.kind == "bytes":
		var checked := _decode(primary.bytes)
		if checked.ok:
			return {"status": "loaded", "data": checked.data, "reason": ""}
		# These refusals always outrank an older backup. In particular, an
		# unsupported calendar must never be silently replaced or resampled.
		if checked.code in ["future_save_read_only", "campaign_clock_read_only"]:
			return _protected(checked.code, "load_primary", checked)
	var backup := _read(path + ".bak", "load_backup")
	var journal := _read(path + ".txn", "load_journal")
	var temporary := _read(path + ".tmp", "load_temporary")
	if primary.kind == "missing" and backup.kind == "missing" \
			and journal.kind == "missing" and temporary.kind == "missing":
		return {"status": "missing", "reason": "", "data": {}}
	if backup.kind != "bytes":
		return _protected("save_recovery_required", "load_backup")
	var previous := _decode(backup.bytes)
	if not previous.ok:
		return _protected("save_recovery_required", "validate_backup", previous)
	if journal.kind != "missing":
		if journal.kind != "bytes" or not _journal_matches(journal.bytes, backup.bytes):
			return _protected("save_recovery_required", "validate_journal")
	if primary.kind == "bytes" and not _archive(primary.bytes, ".corrupt", "archive_corrupt").ok:
		return _protected("save_recovery_required", "archive_corrupt")
	# Preserve the only verified old generation; recovery never renames .bak.
	var repaired := _write_verified(path + ".tmp", backup.bytes, "recovery_temp")
	if not repaired.ok:
		return _protected("save_recovery_required", repaired.stage)
	var recovery_journal := _journal_bytes(backup.bytes, backup.bytes)
	repaired = _write_verified(path + ".txn", recovery_journal, "recovery_journal")
	if not repaired.ok:
		return _protected("save_recovery_required", repaired.stage)
	var rechecked := _read(path, "pre_recovery_primary")
	if rechecked.kind != primary.kind \
			or (rechecked.kind == "bytes" and rechecked.bytes != primary.bytes):
		return _protected("save_recovery_required", "recovery_primary_changed")
	repaired = _op("recovery_promote", "rename", {"from": path + ".tmp", "to": path})
	if not repaired.ok or not _matches(path, backup.bytes, "recovery_verify"):
		return _protected("save_recovery_required", "recovery_promote")
	_cleanup()
	return {"status": "recovered", "data": previous.data,
			"reason": "The previous complete save was recovered."}


func write_snapshot(bytes: PackedByteArray, replace_protected := false) -> Dictionary:
	var candidate := _decode(bytes)
	if not candidate.ok:
		return _failure(candidate.code, "validate_candidate")
	var primary := _read(path, "write_primary")
	if primary.kind == "unreadable":
		return _failure("save_read_failed", "write_primary", true)
	if primary.kind == "bytes" and not replace_protected:
		var current := _decode(primary.bytes)
		if not current.ok:
			var refusal := _failure(current.code, "validate_primary", true)
			refusal.merge(current, false)
			return refusal
	var previous: PackedByteArray = primary.get("bytes", PackedByteArray())
	if replace_protected and primary.kind == "bytes" \
			and not _archive(previous, ".replaced", "archive_primary").ok:
		return _failure("save_write_failed", "archive_primary")
	# A missing primary with sidecars is a recovery decision, never an implicit
	# fresh save. Explicit New preserves all raw artifacts before reusing slots.
	for suffix in [".bak", ".txn", ".tmp"]:
		var artifact := _read(path + suffix, "inspect" + suffix)
		if artifact.kind == "unreadable":
			return _failure("save_recovery_required", "inspect" + suffix, true)
		if artifact.kind == "bytes":
			if primary.kind == "missing" and not replace_protected:
				return _failure("save_recovery_required", "missing_primary_artifacts", true)
			if replace_protected and not _archive(artifact.bytes, ".replaced", "archive" + suffix).ok:
				return _failure("save_write_failed", "archive" + suffix)
	var result := _write_verified(path + ".tmp", bytes, "temp")
	if not result.ok:
		return result
	if primary.kind == "bytes":
		result = _write_verified(path + ".bak", previous, "backup")
		if not result.ok:
			return result
	# A journal is checked metadata, not a second source of world facts. Paths
	# are derived from `path`; nothing read from JSON can redirect a file action.
	result = _write_verified(path + ".txn", _journal_bytes(previous, bytes), "journal")
	if not result.ok:
		return result
	var rechecked := _read(path, "pre_promote_primary")
	if rechecked.kind != primary.kind \
			or (rechecked.kind == "bytes" and rechecked.bytes != previous):
		return _failure("save_recovery_required", "primary_changed", true)
	result = _op("promote", "rename", {"from": path + ".tmp", "to": path})
	if not result.ok or not _matches(path, bytes, "primary_verify"):
		var restored := _restore_previous(primary, bytes)
		var failed := _failure("save_write_failed" if restored else "save_recovery_required",
				"promote_or_verify", not restored)
		failed.recovered = restored and primary.kind == "bytes"
		return failed
	_cleanup()
	return {"ok": true, "code": "", "stage": "complete",
			"recovered": false, "protection_required": false}


func _restore_previous(primary: Dictionary, candidate: PackedByteArray) -> bool:
	var current := _read(path, "rollback_primary")
	if current.kind == "unreadable":
		return false
	if primary.kind == "bytes" and current.kind == "bytes" and current.bytes == primary.bytes:
		_cleanup()
		return true
	# Never erase unexpected bytes written by another process. No cross-process
	# locking is claimed; a changed primary is preserved and requires recovery.
	if current.kind == "bytes" and current.bytes != candidate:
		return false
	if primary.kind == "missing":
		# A first-ever write has no committed generation to restore. Its artifacts
		# remain protected instead of laundering a failed creation into Continue.
		return false
	if not _matches(path + ".bak", primary.bytes, "rollback_backup_verify"):
		return false
	var result := _write_verified(path + ".tmp", primary.bytes, "rollback_temp")
	if not result.ok:
		return false
	result = _op("rollback_promote", "rename", {"from": path + ".tmp", "to": path})
	if not result.ok or not _matches(path, primary.bytes, "rollback_verify"):
		return false
	_cleanup()
	return true


func _decode(bytes: PackedByteArray) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or parser.data is not Dictionary:
		return {"ok": false, "code": "save_invalid_read_only"}
	if not validate_document.is_valid():
		return {"ok": false, "code": "save_invalid_read_only"}
	var result: Dictionary = validate_document.call(parser.data)
	if result.ok:
		result.data = parser.data
	return result


func _journal_bytes(previous: PackedByteArray, candidate: PackedByteArray) -> PackedByteArray:
	return JSON.stringify({"schema_version": 1, "old_sha256": _hash(previous),
			"new_sha256": _hash(candidate)}).to_utf8_buffer()


func _journal_matches(bytes: PackedByteArray, backup: PackedByteArray) -> bool:
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if parsed is not Dictionary or parsed.get("schema_version") != 1:
		return false
	return parsed.get("old_sha256") == _hash(backup) \
			and parsed.get("new_sha256") is String \
			and str(parsed.new_sha256).length() == 64 \
			and str(parsed.new_sha256).is_valid_hex_number(false)


func _archive(bytes: PackedByteArray, suffix: String, stage: String) -> Dictionary:
	var destination := path + suffix + "." + _hash(bytes)
	var existing := _read(destination, stage + "_existing")
	if existing.kind == "bytes":
		return {"ok": existing.bytes == bytes, "stage": stage}
	if existing.kind != "missing":
		return _failure("save_write_failed", stage)
	return _write_verified(destination, bytes, stage)


func _write_verified(destination: String, bytes: PackedByteArray, stage: String) -> Dictionary:
	var result := _op(stage + "_write", "write", {"path": destination, "bytes": bytes})
	if not result.ok:
		return _failure("save_write_failed", stage + "_write")
	if not _matches(destination, bytes, stage + "_verify"):
		return _failure("save_write_failed", stage + "_verify")
	return {"ok": true, "stage": stage}


func _matches(destination: String, bytes: PackedByteArray, stage: String) -> bool:
	var checked := _read(destination, stage)
	return checked.kind == "bytes" and checked.bytes == bytes


func _read(destination: String, stage: String) -> Dictionary:
	return _op(stage, "read", {"path": destination})


func _cleanup() -> void:
	# Once primary readback succeeded, cleanup failure cannot undo that fact.
	_op("cleanup_journal", "remove", {"path": path + ".txn"})
	_op("cleanup_temp", "remove", {"path": path + ".tmp"})


func _op(stage: String, operation: String, arguments: Dictionary) -> Dictionary:
	if operation_override.is_valid():
		var override: Variant = operation_override.call(stage, operation, arguments)
		if override is Dictionary:
			return override
	match operation:
		"read":
			var file := FileAccess.open(str(arguments.path), FileAccess.READ)
			if file == null:
				var error := FileAccess.get_open_error()
				return {"kind": "missing" if error == ERR_FILE_NOT_FOUND else "unreadable",
						"error": error}
			var length := file.get_length()
			var bytes := file.get_buffer(length)
			var error := file.get_error()
			file.close()
			if bytes.size() != length or error not in [OK, ERR_FILE_EOF]:
				return {"kind": "unreadable", "error": error}
			return {"kind": "bytes", "bytes": bytes, "error": OK}
		"write":
			var destination := str(arguments.path)
			var directory_error := DirAccess.make_dir_recursive_absolute(
					ProjectSettings.globalize_path(destination.get_base_dir()))
			if directory_error != OK:
				return {"ok": false, "error": directory_error}
			var file := FileAccess.open(destination, FileAccess.WRITE)
			if file == null:
				return {"ok": false, "error": FileAccess.get_open_error()}
			var stored := file.store_buffer(arguments.bytes)
			file.flush()
			var error := file.get_error()
			file.close()
			return {"ok": stored and error == OK, "error": error}
		"rename":
			var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(str(arguments.from)),
					ProjectSettings.globalize_path(str(arguments.to)))
			return {"ok": error == OK, "error": error}
		"remove":
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(str(arguments.path)))
			return {"ok": error == OK, "error": error}
	return {"ok": false, "error": ERR_INVALID_PARAMETER}


func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _failure(code: String, stage: String, protection_required := false) -> Dictionary:
	return {"ok": false, "code": code, "stage": stage, "recovered": false,
			"protection_required": protection_required}


func _protected(code: String, stage: String, details: Dictionary = {}) -> Dictionary:
	return {"status": "protected", "reason": code, "stage": stage,
			"version": details.get("version", 0), "detail": details.get("detail", "")}
