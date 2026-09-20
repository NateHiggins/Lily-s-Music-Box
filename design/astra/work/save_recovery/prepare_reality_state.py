"""Build the proposed source only; never write game/. Originals are immutable."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
source = (ROOT / 'originals/game/scripts/game/reality_game_state.gd').read_text(encoding='utf-8')
source = source.replace('const SAVE_VERSION := 4',
    'const SAVE_STORAGE = preload("res://scripts/game/reality_save_storage.gd")\nconst SAVE_VERSION := 4', 1)
source = source.replace('var save_path := SAVE_PATH', '''var save_path := SAVE_PATH
## Tests may inject file-operation failures and a creation-time sample. Neither
## callback is installed by production. The clock still owns sample validation.
var storage_operation_override: Callable
var new_campaign_time_provider: Callable
var _preparing_state := false
var _load_result := {"status": "missing", "reason": "", "has_saved_campaign": false}
var _last_save_result: Dictionary = {}''', 1)
start = source.index('func commit() -> void:')
end = source.index('## A mid-session load', start)
source = source[:start] + '''func commit() -> void:
	# Clock creation commits into a private candidate, not a half-adopted world.
	if _preparing_state:
		return
	if persistence_enabled:
		save_game()
	state_changed.emit()


func _storage() -> SAVE_STORAGE:
	var storage := SAVE_STORAGE.new()
	storage.path = save_path
	storage.validate_document = _validate_document
	storage.operation_override = storage_operation_override
	return storage


func save_game() -> bool:
	if _preparing_state:
		return false
	if save_write_blocked:
		_last_save_result = {"ok": false, "code": str(_player_notice.get("code", "save_recovery_required")),
				"stage": "write_latch", "recovered": false, "protection_required": true}
		return false
	_last_save_result = _storage().write_snapshot(JSON.stringify(data, "\\t").to_utf8_buffer())
	if not bool(_last_save_result.ok):
		if bool(_last_save_result.get("protection_required", false)):
			_block_save(str(_last_save_result.code), _last_save_result)
		else:
			_set_player_notice("save_write_failed", "PROGRESS COULD NOT BE SAVED",
					"The save file could not be written. Progress since the last " +
					"successful save may be lost. Check storage access and available " +
					"disk space.")
		return false
	_load_result = {"status": "loaded", "reason": "", "has_saved_campaign": true}
	if str(_player_notice.get("code", "")) == "save_write_failed":
		_player_notice = {}
		player_notice_changed.emit(player_notice())
	return true


func load_game() -> void:
	data = _fresh_data()
	save_write_blocked = false
	incompatible_save_version = 0
	_player_notice = {}
	_last_save_result = {}
	var loaded := _storage().load_snapshot()
	_load_result = {"status": loaded.status, "reason": loaded.get("reason", ""),
			"has_saved_campaign": loaded.status != "missing"}
	if loaded.status == "protected":
		_block_save(str(loaded.reason), loaded, false)
	elif loaded.status in ["loaded", "recovered"]:
		# Known shapes and the calendar have already passed validation. Unknown
		# compatible additive fields survive; omitted old fields receive defaults.
		data.merge(loaded.data, true)
		if loaded.status == "recovered":
			_set_player_notice("save_recovered", "PREVIOUS SAVE RECOVERED",
					"The previous complete save was recovered. Progress made after " +
					"that save may be missing.", false)
		if int(data.version) < SAVE_VERSION:
			_migrate()
	_announce_loaded()


func can_continue() -> bool:
	return not save_write_blocked and _load_result.status in ["loaded", "recovered"]


func load_status() -> Dictionary:
	return _load_result.duplicate(true)


func last_save_result() -> Dictionary:
	return _last_save_result.duplicate(true)


func _validate_document(candidate: Dictionary) -> Dictionary:
	var version: Variant = candidate.get("version", 0)
	if not _whole_number(version) or float(version) < 0.0:
		return {"ok": false, "code": "save_invalid_read_only", "detail": "Invalid save version."}
	if float(version) > SAVE_VERSION:
		return {"ok": false, "code": "future_save_read_only", "version": int(version)}
	for key in ["cases", "building_personality", "work_orders", "maintenance_jobs",
			"maintenance_items", "open_shift_situations", "shop_buckets", "exterior_semantics",
			"organism_incidents", "core_loop", "first_shift", "dream", "sleep_pressure", "waking_residues",
			"night_register", "npc_observations", "porter_actor"]:
		if candidate.has(key) and candidate[key] is not Dictionary:
			return _invalid_shape(key)
	for key in ["portal_rules", "discovered_documents", "music_library", "heard_music_anecdotes"]:
		if candidate.has(key) and candidate[key] is not Array:
			return _invalid_shape(key)
	for key in ["current_case_id", "dream_seed", "last_waking_residue_id"]:
		if candidate.has(key) and candidate[key] is not String:
			return _invalid_shape(key)
	if candidate.has("intro_complete") and candidate.intro_complete is not bool:
		return _invalid_shape("intro_complete")
	for key in ["building_stability", "reality_coherence"]:
		if candidate.has(key) and not _finite_number(candidate[key]):
			return _invalid_shape(key)
	if candidate.has("dreams_had") and (not _whole_number(candidate.dreams_had) or float(candidate.dreams_had) < 0.0):
		return _invalid_shape("dreams_had")
	# These are maps of durable records, not arbitrary nested dictionaries.
	# Domain owners still validate IDs, vocabulary, quantities and chronology.
	for key in ["cases", "work_orders", "maintenance_jobs", "maintenance_items",
			"open_shift_situations", "shop_buckets", "exterior_semantics",
			"organism_incidents", "waking_residues"]:
		for record in candidate.get(key, {}).values():
			if record is not Dictionary:
				return _invalid_shape(key + " entry")
	for beliefs in candidate.get("npc_observations", {}).values():
		if not _array_of_records(beliefs):
			return _invalid_shape("npc_observations entry")
	var register: Dictionary = candidate.get("night_register", {})
	if register.has("lines") and not _array_of_records(register.lines):
		return _invalid_shape("night_register.lines")
	# CampaignClock remains the sole calendar validator. Its error callback is
	# contained while inspecting a candidate; validation cannot emit or resample.
	var previous_data := data
	var previous_blocked := save_write_blocked
	var previous_version := incompatible_save_version
	var previous_notice := _player_notice
	var previous_preparing := _preparing_state
	_preparing_state = true
	data = candidate
	save_write_blocked = false
	incompatible_save_version = 0
	var clock := CampaignClock.new()
	var valid := clock.validate_saved_state()
	data = previous_data
	save_write_blocked = previous_blocked
	incompatible_save_version = previous_version
	_player_notice = previous_notice
	_preparing_state = previous_preparing
	return {"ok": true} if valid else {"ok": false, "code": "campaign_clock_read_only", "detail": clock.validation_error}


func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _array_of_records(value: Variant) -> bool:
	if value is not Array:
		return false
	for record in value:
		if record is not Dictionary:
			return false
	return true


func _whole_number(value: Variant) -> bool:
	return _finite_number(value) and float(value) == floor(float(value))


func _invalid_shape(key: String) -> Dictionary:
	return {"ok": false, "code": "save_invalid_read_only", "detail": "Invalid saved field: " + key + "."}


func _block_save(code: String, details: Dictionary = {}, emit_now := true) -> void:
	save_write_blocked = true
	_load_result = {"status": "protected", "reason": code, "has_saved_campaign": true}
	match code:
		"future_save_read_only":
			incompatible_save_version = int(details.get("version", 0))
			_set_future_save_notice(emit_now)
		"campaign_clock_read_only":
			_set_player_notice(code, "CAMPAIGN TIME COULD NOT BE READ",
					str(details.get("detail", "The saved campaign clock is invalid.")) +
					" The existing save is protected. Progress cannot be saved in this session.", emit_now)
		"save_read_failed":
			_set_player_notice(code, "SAVE COULD NOT BE READ",
					"The existing save could not be opened. It is protected, and progress " +
					"cannot be saved in this session. Check storage access before trying again.", emit_now)
		_:
			_set_player_notice(code, "SAVE NEEDS RECOVERY",
					"A complete supported save could not be read or recovered. Existing save " +
					"files are protected. Progress cannot be saved in this session. " +
					"Restore a known good save, or explicitly start a new campaign.", emit_now)


''' + source[end:]
source = source.replace('if emit_now:\n\t\tplayer_notice_changed.emit',
    'if emit_now and not _preparing_state:\n\t\tplayer_notice_changed.emit', 1)
start = source.index('func start_new_campaign() -> void:')
end = source.index('func _migrate()', start)
source = source[:start] + '''func start_new_campaign() -> bool:
	# Build privately: failure must not publish fresh facts or erase protection.
	var previous_data := data
	var previous_blocked := save_write_blocked
	var previous_version := incompatible_save_version
	var previous_notice := _player_notice
	_preparing_state = true
	data = _fresh_data()
	save_write_blocked = false
	incompatible_save_version = 0
	_player_notice = {}
	var clock := CampaignClock.new()
	clock.creation_time_provider = new_campaign_time_provider
	var prepared := clock.bind_state()
	var candidate := data
	data = previous_data
	save_write_blocked = previous_blocked
	incompatible_save_version = previous_version
	_player_notice = previous_notice
	_preparing_state = false
	if not prepared:
		_last_save_result = {"ok": false, "code": "campaign_clock_read_only",
				"stage": "prepare_new_clock", "detail": clock.validation_error,
				"recovered": false, "protection_required": previous_blocked}
		return false
	_last_save_result = _storage().write_snapshot(JSON.stringify(candidate, "\\t").to_utf8_buffer(), true)
	if not _last_save_result.ok:
		# A title consumer reads last_save_result; the prior notice/latch survive.
		# If rollback itself failed, even a formerly valid campaign is protected.
		if not previous_blocked and bool(_last_save_result.get("protection_required", false)):
			_block_save("save_recovery_required", _last_save_result)
		return false
	data = candidate
	save_write_blocked = false
	incompatible_save_version = 0
	_player_notice = {}
	_load_result = {"status": "loaded", "reason": "", "has_saved_campaign": true}
	_announce_loaded()
	return true


func block_invalid_campaign_clock(reason: String) -> void:
	# A later clock consumer cannot relabel an existing malformed/future/file
	# refusal; validation of a private candidate temporarily clears this latch.
	if save_write_blocked:
		return
	if _preparing_state:
		save_write_blocked = true
		_set_player_notice("campaign_clock_read_only", "CAMPAIGN TIME COULD NOT BE READ", reason, false)
		return
	_block_save("campaign_clock_read_only", {"detail": reason})


''' + source[end:]
source = source.replace('func reset_campaign_for_tests() -> void:\n',
    'func reset_campaign_for_tests() -> void:\n\t_load_result = {"status": "missing", "reason": "", "has_saved_campaign": false}\n\t_last_save_result = {}\n', 1)
destination = ROOT / 'proposed/game/scripts/game/reality_game_state.gd'
destination.write_text(source, encoding='utf-8', newline='\n')
print(destination)
