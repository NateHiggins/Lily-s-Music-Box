extends Node
## Production storage and RealityState APIs, private disk files. Faults use the
## same file boundary as production, with real byte writes and Windows rename.
## These in-process tests do not claim interruption/restart or human-route proof.

const STORAGE = preload("res://scripts/game/reality_save_storage.gd")
const ROOT := "user://tests/save_recovery_transaction"
const PATH := ROOT + "/campaign.json"
var passed := 0
var failed := 0
var faults: Dictionary = {}
var samples := 0
var announcements := 0


func _ready() -> void:
	CampaignTime.set_frozen_for_tests(true)
	var previous_path := RealityState.save_path
	var previous_persistence := RealityState.persistence_enabled
	RealityState.save_path = PATH
	RealityState.persistence_enabled = true
	RealityState.new_campaign_time_provider = _sample
	RealityState.state_changed.connect(_announced)
	_test_write_boundaries()
	_test_load_selection()
	_test_load_latches()
	_test_new_campaign()
	RealityState.state_changed.disconnect(_announced)
	RealityState.storage_operation_override = Callable()
	RealityState.new_campaign_time_provider = Callable()
	RealityState.save_path = previous_path
	RealityState.persistence_enabled = previous_persistence
	RealityState.reset_campaign_for_tests()
	_clear_fixture()
	await get_tree().process_frame
	print("[SAVE RECOVERY] %s %d/%d" % ["PASS" if failed == 0 else "FAIL", passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _test_write_boundaries() -> void:
	_check(_storage()._hash(PackedByteArray()) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
			"first-creation journal uses the exact SHA256 of an absent prior generation")
	var old := _bytes(_facts(false))
	var next := _bytes(_facts(true))
	for stage in ["temp_write", "temp_verify", "backup_write", "backup_verify",
			"journal_write", "journal_verify", "promote", "primary_verify"]:
		_seed(old)
		faults = {stage: "fail"}
		var result := _storage(true).write_snapshot(next)
		_check(not result.ok, stage + " returns false")
		_check(_read(PATH) == old, stage + " retains the previous primary bytes")
		_check(_storage().load_snapshot().data == _facts(false),
				stage + " fresh storage reader reconstructs previous facts")
	for stage in ["temp_write", "backup_write", "journal_write"]:
		_seed(old)
		faults = {stage: "short_write"}
		var result := _storage(true).write_snapshot(next)
		_check(not result.ok, stage + " short write is rejected despite claimed operation success")
		_check(_read(PATH) == old, stage + " short write does not truncate primary")
	_seed(old)
	faults = {"promote": "delete_gap"}
	var result := _storage(true).write_snapshot(next)
	_check(not result.ok and result.recovered and not result.protection_required,
			"Windows deletion gap failure reports failure and verified restoration")
	_check(_read(PATH) == old and _read(PATH + ".bak") == old,
			"restoration copies the previous generation without consuming backup")
	for rollback_stage in ["rollback_temp_write", "rollback_promote", "rollback_verify"]:
		_seed(old)
		faults = {"promote": "delete_gap", rollback_stage: "fail"}
		result = _storage(true).write_snapshot(next)
		_check(not result.ok and result.protection_required, rollback_stage + " holds writes")
		_check(_read(PATH + ".bak") == old, rollback_stage + " keeps backup bytes")
		var loaded := _storage().load_snapshot()
		_check(loaded.status in ["loaded", "recovered"] and loaded.data == _facts(false),
				rollback_stage + " a fresh reader obtains old complete facts")
	_seed(old)
	faults = {"cleanup_journal": "fail", "cleanup_temp": "fail"}
	result = _storage(true).write_snapshot(next)
	_check(result.ok and _read(PATH) == next, "cleanup failures do not deny a verified save")
	_check(_storage().load_snapshot().data == _facts(true), "valid primary wins stale cleanup debris")
	_seed(old)
	faults = {"pre_promote_primary": "future_arrives"}
	result = _storage(true).write_snapshot(next)
	_check(not result.ok and result.protection_required, "changed primary stops promotion")
	_check(_read(PATH) == '{"version":99,"future_fact":"arrived"}'.to_utf8_buffer(),
			"future bytes arriving before promotion remain untouched")
	_clear_fixture()
	var nested := _storage()
	nested.path = ROOT + "/new_parent/nested/campaign.json"
	_check(nested.write_snapshot(old).ok, "writer creates a missing parent directory")
	_check(nested.load_snapshot().data == _facts(false), "nested path reads complete facts")
	# Only these exact owned nested paths are removed; no recursive user-dir wipe.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(nested.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROOT + "/new_parent/nested"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROOT + "/new_parent"))


func _test_load_selection() -> void:
	var old := _bytes(_facts(false))
	var next := _bytes(_facts(true))
	_seed(old)
	_write(PATH + ".tmp", next)
	_write(PATH + ".txn", "broken journal".to_utf8_buffer())
	_check(_storage().load_snapshot().data == _facts(false), "valid primary wins uncommitted temp and bad journal")
	_clear_fixture()
	_write(PATH + ".tmp", next)
	_check(_storage().load_snapshot().status == "protected", "temp alone never becomes Continue")
	_seed(old)
	_check(_storage().write_snapshot(next).ok, "second complete generation creates backup")
	var damaged := '{"version":4,"maintenance_jobs":'.to_utf8_buffer()
	_write(PATH, damaged)
	var restored := _storage().load_snapshot()
	_check(restored.status == "recovered" and restored.data == _facts(false),
			"damaged primary recovers previous work, item, dream and clock facts")
	_check(_read(PATH + ".corrupt." + _storage()._hash(damaged)) == damaged,
			"damaged primary bytes survive recovery under their content hash")
	_seed(old)
	_check(_storage().write_snapshot(next).ok, "prepare backup for future refusal")
	var future := '{"version":99,"cases":[],"future_fact":"preserve"}'.to_utf8_buffer()
	_write(PATH, future)
	var loaded := _storage().load_snapshot()
	_check(loaded.status == "protected" and loaded.reason == "future_save_read_only",
			"future primary refuses before known-field validation or older backup selection")
	_check(_read(PATH) == future and _read(PATH + ".bak") == old, "future refusal preserves both generations")
	_seed(old)
	_write(PATH + ".bak", old)
	var bad_clock := _facts(true)
	bad_clock.campaign_clock.schema_version = 99
	_write(PATH, _bytes(bad_clock))
	loaded = _storage().load_snapshot()
	_check(loaded.status == "protected" and loaded.reason == "campaign_clock_read_only",
			"unsupported primary clock refuses before older backup fallback")
	_seed(old)
	_write(PATH + ".bak", old)
	faults = {"load_primary": "fail"}
	loaded = _storage(true).load_snapshot()
	_check(loaded.status == "protected" and loaded.reason == "save_read_failed",
			"unreadable primary is protected instead of treated as absent")
	_clear_fixture()
	_write(PATH + ".bak", old)
	_write(PATH + ".txn", '{"schema_version":1,"old_sha256":"wrong"}'.to_utf8_buffer())
	_check(_storage().load_snapshot().status == "protected", "ambiguous journal cannot authorize backup promotion")
	_clear_fixture()
	_check(_storage().load_snapshot().status == "missing", "only absent primary and all absent sidecars are fresh")


func _test_load_latches() -> void:
	var invalid := ["{", "null", "[]", '{"version":4.5}', '{"version":"4"}',
			'{"version":4,"maintenance_jobs":[]}', '{"version":4,"cases":{"a":17}}',
			'{"version":4,"dreams_had":-1}', '{"version":4,"intro_complete":"true"}',
			'{"version":4,"campaign_clock":[]}', '{"version":99}']
	for text in invalid:
		var bytes := str(text).to_utf8_buffer()
		_seed(bytes)
		RealityState.load_game()
		var notice := RealityState.player_notice()
		_check(RealityState.save_write_blocked and not RealityState.can_continue(),
				"invalid load blocks writing and Continue: " + str(text))
		RealityState.data.intro_complete = true
		RealityState.commit()
		SaveStatusNotice._dismiss()
		_check(_read(PATH) == bytes and RealityState.player_notice() == notice
				and not RealityState.save_game(), "commit and notice dismissal preserve invalid bytes and reason")
		samples = 0
		var clock := CampaignClock.new()
		clock.creation_time_provider = _sample
		_check(not clock.bind_state() and samples == 0,
				"protected clock cannot initialize or sample even if a debug consumer binds")
		RealityState.load_game()
		_check(RealityState.save_write_blocked and RealityState.player_notice() == notice,
				"second load retains protection and reason")
	# Compatible additive fields are preserved; omitted old fields are defaulted.
	_seed('{"version":4,"unknown_additive":{"keep":true}}'.to_utf8_buffer())
	RealityState.load_game()
	_check(RealityState.can_continue() and RealityState.data.unknown_additive.keep
			and RealityState.data.maintenance_jobs is Dictionary,
			"compatible unknown fields survive alongside additive known defaults")


func _test_new_campaign() -> void:
	var future := '{"version":99,"future_fact":"keep raw"}'.to_utf8_buffer()
	_seed(future)
	RealityState.load_game()
	var old_data := RealityState.data.duplicate(true)
	var old_notice := RealityState.player_notice()
	faults = {"temp_write": "short_write"}
	RealityState.storage_operation_override = _fault
	samples = 0
	announcements = 0
	_check(not RealityState.start_new_campaign(), "failed New returns false for GameBoot")
	_check(samples == 1 and announcements == 0, "failed New samples once but publishes no candidate facts")
	_check(RealityState.data == old_data and RealityState.player_notice() == old_notice
			and RealityState.save_write_blocked and _read(PATH) == future,
			"failed New preserves prior runtime data, future notice, latch and original primary")
	_check(not RealityState.last_save_result().ok, "failed New exposes a separate operation result")
	RealityState.storage_operation_override = Callable()
	samples = 0
	announcements = 0
	_check(RealityState.start_new_campaign(), "explicit successful New commits replacement")
	_check(samples == 1 and announcements == 1, "successful New samples once and publishes once")
	_check(RealityState.can_continue() and RealityState.player_notice().is_empty(),
			"successful New enables Continue and releases old protection")
	_check(_read(PATH + ".replaced." + _storage()._hash(future)) == future,
			"original future bytes remain archived even when backup rotates later")
	_check(RealityState.data.campaign_clock.start_minute_of_day == 13 * 60 + 27
			and RealityState.data.campaign_clock.epoch_date == "1928-11-10",
			"New uses the authored date and injected time of day")
	var committed := _read(PATH)
	samples = 0
	RealityState.load_game()
	_check(samples == 0 and _read(PATH) == committed and RealityState.can_continue(),
			"ordinary Continue data load preserves clock bytes and does not sample")


func _facts(next: bool) -> Dictionary:
	var clock := CampaignClock._civil_record({"year": 1928, "month": 11, "day_of_month": 10}, 807)
	clock.elapsed_minutes = 3.0 if next else 0.0
	var facts := {"version": 4, "intro_complete": true,
			"maintenance_jobs": {"vantry_chirp_2a": {"stage": "closed" if next else "repaired",
					"origin": "reported", "evidence": ["carbon_capsule_failed"],
					"repair_result": {"quality": "good"}, "issued_at_basis": "fixture_basis_preserved"}},
			"maintenance_items": {"carbon_transmitter_capsule": {"shop_id": "hardware", "consumed": true}},
			"dream_seed": "1928000019280000",
			"dream": {"phase": "return_pending" if next else "armed", "active": false,
					"case_id": "mina_caption_crisis", "profile_id": "mina_release_print", "window": {},
					"seed_hex": "1928000019280000", "night_index": 0},
			"campaign_clock": clock,
			"unknown_additive": {"retain": "new" if next else "old"}}
	# The file contract is JSON: its numbers reload as floats in Godot. Compare
	# complete facts in that representation, rather than failing on int/float
	# Variant identity inside an otherwise equal nested Dictionary.
	return JSON.parse_string(JSON.stringify(facts))


func _storage(with_fault := false) -> STORAGE:
	var storage := STORAGE.new()
	storage.path = PATH
	storage.validate_document = RealityState._validate_document
	if with_fault:
		storage.operation_override = _fault
	return storage


func _fault(stage: String, operation: String, arguments: Dictionary) -> Variant:
	if not faults.has(stage):
		return null
	match str(faults[stage]):
		"short_write":
			var bytes: PackedByteArray = arguments.bytes
			_write(str(arguments.path), bytes.slice(0, maxi(1, bytes.size() / 2)))
			return {"ok": true}
		"delete_gap":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(str(arguments.to)))
			return {"ok": false, "error": ERR_FILE_CANT_WRITE}
		"future_arrives":
			_write(PATH, '{"version":99,"future_fact":"arrived"}'.to_utf8_buffer())
			return null
	return {"kind": "unreadable", "error": ERR_FILE_CANT_READ} if operation == "read" \
			else {"ok": false, "error": ERR_FILE_CANT_WRITE}


func _sample() -> Dictionary:
	samples += 1
	return {"hour": 13, "minute": 27}


func _announced() -> void:
	announcements += 1


func _seed(bytes: PackedByteArray) -> void:
	_clear_fixture()
	faults = {}
	RealityState.storage_operation_override = Callable()
	_write(PATH, bytes)


func _clear_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var directory := DirAccess.open(ROOT)
	for file in directory.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ROOT.path_join(file)))


func _bytes(facts: Dictionary) -> PackedByteArray:
	return JSON.stringify(facts).to_utf8_buffer()


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null and file.store_buffer(bytes), "fixture write failed")
	file.close()


func _read(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("  PASS ", label)
	else:
		failed += 1
		print("  FAIL ", label)
