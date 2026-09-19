extends Node
## Persistent campaign state for Reality Maintenance. Content systems mutate
## this through RealityCases so temporary repair and emotional resolution
## cannot accidentally collapse into the same boolean.

signal state_changed
signal waking_residue_applied(residue_id: String, facts: Dictionary)
signal player_notice_changed(notice: Dictionary)

const SAVE_STORAGE = preload("res://scripts/game/reality_save_storage.gd")
const SAVE_VERSION := 4
const SAVE_PATH := "user://reality_maintenance_save.json"

var data: Dictionary = {}
var persistence_enabled := true
## A rollback may encounter a save written by a newer build. That file is not
## ours to migrate or overwrite. Runtime state remains fresh and commits stay
## read-only until the player explicitly starts a new campaign.
var save_write_blocked := false
var incompatible_save_version := 0
var _player_notice: Dictionary = {}
## Injectable so a harness can exercise the real save/load path against its
## own file under user://tests/ without touching the player's save.
## Production never changes it.
var save_path := SAVE_PATH
## Tests may inject file-operation failures and a creation-time sample. Neither
## callback is installed by production. The clock still owns sample validation.
var storage_operation_override: Callable
var new_campaign_time_provider: Callable
var _preparing_state := false
var _load_result := {"status": "missing", "reason": "", "has_saved_campaign": false}
var _last_save_result: Dictionary = {}


func _ready() -> void:
	load_game()


func _fresh_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"intro_complete": false,
		"current_case_id": "",
		"cases": {},
		"building_stability": 0.0,
		"reality_coherence": 0.0,
		"portal_rules": [],
		"discovered_documents": [],
		"music_library": [],
		"heard_music_anecdotes": [],
		"building_personality": {},
		"work_orders": {},
		"maintenance_jobs": {},
		"maintenance_items": {},
		"open_shift_situations": {},
		# Exterior simulation owners seed their own authored defaults into this
		# durable container. RealityState owns persistence, never shop behavior.
		"shop_buckets": {},
		# Exterior reconstruction stores semantic route/threshold identities only.
		# Current world transforms remain owned by the v2 exterior resolver.
		"exterior_semantics": {},
		"campaign_clock": {},
		"organism_incidents": {},
		"core_loop": {},
		# The opening ritual only: which desk action the player has physically
		# reached. WorkOrders and RealityCases continue to own every job/case fact.
		"first_shift": {},
		"dream_seed": _new_dream_seed(),
		# HOW MANY NIGHTS THIS CAMPAIGN HAS HAD. The fractal Orison decays as
		# a pure function of (seed, room, nights) and stores no map, so this
		# single integer is the whole of its persistence -- without it the
		# building cannot be reconstructed on a reload, and DreamAtlas
		# .spawn_path(night) cannot put the player back where they woke.
		# Stamped per passage by DreamDirector.enter_armed_dream().
		"dreams_had": 0,
		"dream": {},
		"sleep_pressure": {},
		"waking_residues": {},
		"last_waking_residue_id": "",
	}


func ensure_case(case_id: String, resident_id: String) -> Dictionary:
	if not data.cases.has(case_id):
		data.cases[case_id] = {
			"resident_id": resident_id,
			"stage": "unseen",
			"repair_count": 0,
			"recurrence_count": 0,
			"manifestation_intensity": 0.0,
			"trust": 0,
			"conversation_flags": [],
			"apartment_changes": [],
			"recurrence_pending": false,
			"resolved": false,
		}
	return data.cases[case_id]


## HOW MANY CASES THIS CAMPAIGN HAS PUT DOWN. Owner ruling 2026-08-18: the
## place the player wakes in the dream holds still until a case is solved, and
## then moves. So this is the dream's spawn anchor, and it is DERIVED rather
## than counted into a key of its own -- `resolved` is already set in exactly
## one place (RealityCaseManager._resolve), and a parallel counter would be
## free to drift away from it with no error and no way to notice.
func cases_resolved() -> int:
	var n := 0
	for case_id in (data.get("cases", {}) as Dictionary):
		if bool((data.cases[case_id] as Dictionary).get("resolved", false)):
			n += 1
	return n


func case_state(case_id: String) -> Dictionary:
	return data.cases.get(case_id, {})


func commit() -> void:
	# Clock creation commits into a private candidate, not a half-adopted world.
	if _preparing_state:
		return
	if persistence_enabled:
		save_game()
	state_changed.emit()


func _storage() -> RealitySaveStorage:
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
	_last_save_result = _storage().write_snapshot(JSON.stringify(data, "\t").to_utf8_buffer())
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
			"organism_incidents", "core_loop", "first_shift", "dream", "sleep_pressure", "waking_residues"]:
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
	for state in candidate.get("cases", {}).values():
		if state is not Dictionary:
			return _invalid_shape("cases entry")
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


## A mid-session load must tell live listeners the world's facts changed;
## the boot-time load fires before anything connects and is inert.
func _announce_loaded() -> void:
	state_changed.emit()
	player_notice_changed.emit(player_notice())


func player_notice() -> Dictionary:
	return _player_notice.duplicate(true)


func _set_future_save_notice(emit_now := true) -> void:
	_set_player_notice("future_save_read_only",
			"SAVE CREATED BY A NEWER VERSION",
			"This build cannot safely read save version %d. Progress will not " %
					incompatible_save_version +
			"be saved. Update the game, or start a new campaign to replace " +
			"that save.", emit_now)


func _set_player_notice(code: String, title: String, message: String,
		emit_now := true) -> void:
	_player_notice = {"code":code, "title":title, "message":message}
	if emit_now and not _preparing_state:
		player_notice_changed.emit(player_notice())


func start_new_campaign() -> bool:
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
	_last_save_result = _storage().write_snapshot(JSON.stringify(candidate, "\t").to_utf8_buffer(), true)
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


func _migrate() -> void:
	data.version = SAVE_VERSION
	save_game()


func reset_campaign_for_tests() -> void:
	_load_result = {"status": "missing", "reason": "", "has_saved_campaign": false}
	_last_save_result = {}
	save_write_blocked = false
	incompatible_save_version = 0
	_player_notice = {}
	data = _fresh_data()
	state_changed.emit()
	player_notice_changed.emit(player_notice())


## One exact 64-bit seed per campaign, stored as sixteen hexadecimal digits.
## JSON numbers cannot preserve every 64-bit integer; a string can. Runtime
## owners pass these same bits through without numeric conversion.
func _new_dream_seed() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system() * 1000000.0) \
			^ Time.get_ticks_usec()
	var high := int(rng.randi())
	var low := int(rng.randi())
	var encoded := "%08x%08x" % [high, low]
	return "0000000000000001" if encoded == "0000000000000000" else encoded


## Waking residues are committed campaign facts, not presentation state. The
## visual owner reconstructs its label/prop from this record after boot or
## load. Applying the same residue twice is rejected without mutation.
func apply_waking_residue(residue_id: String, facts: Dictionary) -> bool:
	if residue_id.is_empty() or facts.is_empty():
		return false
	if not data.has("waking_residues") or data.waking_residues is not Dictionary:
		data.waking_residues = {}
	if data.waking_residues.has(residue_id):
		return false
	data.waking_residues[residue_id] = facts.duplicate(true)
	data.last_waking_residue_id = residue_id
	commit()
	waking_residue_applied.emit(residue_id,
			data.waking_residues[residue_id].duplicate(true))
	return true


func has_waking_residue(residue_id: String) -> bool:
	return data.get("waking_residues", {}) is Dictionary \
			and data.get("waking_residues", {}).has(residue_id)


func waking_residue(residue_id: String) -> Dictionary:
	var residues: Variant = data.get("waking_residues", {})
	if residues is not Dictionary:
		return {}
	return (residues as Dictionary).get(residue_id, {}).duplicate(true)
