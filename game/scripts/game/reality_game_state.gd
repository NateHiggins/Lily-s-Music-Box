extends Node
## Persistent campaign state for Reality Maintenance. Content systems mutate
## this through RealityCases so temporary repair and emotional resolution
## cannot accidentally collapse into the same boolean.

signal state_changed
signal snapshot_preparing
signal waking_residue_applied(residue_id: String, facts: Dictionary)
signal player_notice_changed(notice: Dictionary)

const SAVE_STORAGE = preload("res://scripts/game/reality_save_storage.gd")
const SAVE_VERSION := 4
const SAVE_PATH := "user://reality_maintenance_save.json"

var data: Dictionary = {}:
	set(value):
		if not is_same(data,value):flush_background_saves()
		data=value
var persistence_enabled := true:
	set(value):
		if persistence_enabled==value:return
		flush_background_saves()
		persistence_enabled=value
## A rollback may encounter a save written by a newer build. That file is not
## ours to migrate or overwrite. Runtime state remains fresh and commits stay
## read-only until the player explicitly starts a new campaign.
var save_write_blocked := false
var incompatible_save_version := 0
var _player_notice: Dictionary = {}
## Injectable so a harness can exercise the real save/load path against its
## own file under user://tests/ without touching the player's save.
## Production never changes it.
var save_path := SAVE_PATH:
	set(value):
		if save_path==value:return
		flush_background_saves()
		save_path=value
## Tests may inject file-operation failures and a creation-time sample. Neither
## callback is installed by production. The clock still owns sample validation.
var storage_operation_override: Callable
var new_campaign_time_provider: Callable
var _preparing_state := false
var _load_result := {"status": "missing", "reason": "", "has_saved_campaign": false}
var _last_save_result: Dictionary = {}
var _save_queue: RefCounted
var background_save_records: Array[Dictionary]=[]
var background_save_profiling:=false
var _background_requested:=0
var _background_completed:=0
var _background_discarded:=0


func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	load_game()


func _process(_delta: float) -> void:
	_poll_background_saves()


func _exit_tree() -> void:
	flush_background_saves()


## Household autosave only. Explicit saves/ordinary commits remain barriers.
## The returned world notification does not assert that pending bytes are durable.
func commit_background() -> void:
	if _preparing_state:return
	if not persistence_enabled or storage_operation_override.is_valid():
		commit();return
	_poll_background_saves()
	if save_write_blocked:
		save_game();state_changed.emit();return
	if _save_queue==null:
		# This immutable authored lookup is otherwise lazy. Never initialize its
		# shared static dictionaries while another thread is reading them.
		DoorKeyring._sources()
		_save_queue=preload("res://scripts/game/reality_save_queue.gd").new()
	if _save_queue.pending_count()>=8:
		flush_background_saves()
		if save_write_blocked:state_changed.emit();return
	var started:=Time.get_ticks_usec()
	snapshot_preparing.emit()
	var bytes:=JSON.stringify(data,"\t",true,true).to_utf8_buffer()
	_background_requested=_save_queue.submit(save_path,bytes,SAVE_VERSION)
	_save_queue.start_next()
	if background_save_profiling:
		# Profiling ticks are ephemeral metadata, never campaign-clock facts.
		var finished_at:=Time.get_ticks_usec()
		background_save_records.append({"stage":"enqueue","started_usec":started,"finished_usec":finished_at,"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"id":_background_requested,"main_usec":finished_at-started,"bytes":bytes.size(),"pending":_save_queue.pending_count()})
		if background_save_records.size()>256:background_save_records.pop_front()
	state_changed.emit()


func background_save_status() -> Dictionary:
	return {"pending":_save_queue.pending_count() if _save_queue!=null else 0,
		"requested":_background_requested,"completed":_background_completed,"discarded":_background_discarded}


func _poll_background_saves() -> void:
	if _save_queue==null:return
	for job: Dictionary in _save_queue.take_completed():_adopt_background_result(job)
	if save_write_blocked:_background_discarded+=_save_queue.discard_pending()
	else:_save_queue.start_next()


func flush_background_saves() -> void:
	if _save_queue==null:return
	while _save_queue.pending_count()>0:
		if save_write_blocked:_background_discarded+=_save_queue.discard_pending()
		_save_queue.start_next()
		for job: Dictionary in _save_queue.take_completed(true):_adopt_background_result(job)


func _adopt_background_result(job: Dictionary) -> void:
	_background_completed=int(job.id)
	var result: Dictionary=job.result
	if background_save_profiling:
		var adopted_at:=Time.get_ticks_usec()
		background_save_records.append({"stage":"completed","adopted_usec":adopted_at,"id":job.id,"result":result.duplicate(true)})
		if background_save_records.size()>256:background_save_records.pop_front()
	# A live clock/domain owner may have protected the campaign while this
	# older valid snapshot was writing. Its success cannot clear that refusal.
	if not (save_write_blocked and bool(result.get("ok",false))):_finish_save(result)


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
		# WHAT THE PLAYER HAS COME TO KNOW, campaign-wide. Resident conversations
		# grant these (design/ORISON_DIALOGUE_DRAFTS_2026-10-22.md): a flag earned
		# in one flat unlocks an inference in another. Flat list of strings, no
		# owner but the player; never a case resolution flag.
		"knowledge_flags": [],
		# The daily papers kept on the desk (design/ORISON_NEWSPAPERS_2026-10-23.md):
		# "<paper>:<YYYY-MM-DD>" strings, read by NewspaperCatalog.
		"newspapers_collected": [],
		# Per-resident trust for threshold conversations that have no case, and
		# how many times each resident has been spoken to. Case residents keep
		# their trust on the case record as before.
		"resident_trust": {},
		"conversation_visits": {},
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


## --- what the player knows -------------------------------------------------

func has_knowledge(flag: String) -> bool:
	return flag != "" and flag in data.get("knowledge_flags", [])


## Grants a campaign-wide knowledge flag. Returns true only when it is new,
## so callers can tell a first recognition from a repeat.
func grant_knowledge(flag: String) -> bool:
	if flag == "":
		return false
	if not data.has("knowledge_flags") or data.knowledge_flags is not Array:
		data.knowledge_flags = []
	if flag in data.knowledge_flags:
		return false
	data.knowledge_flags.append(flag)
	return true


func resident_trust(resident_id: String) -> int:
	return int(data.get("resident_trust", {}).get(resident_id, 0))


func add_resident_trust(resident_id: String, delta: int) -> int:
	if not data.has("resident_trust") or data.resident_trust is not Dictionary:
		data.resident_trust = {}
	data.resident_trust[resident_id] = resident_trust(resident_id) + delta
	return int(data.resident_trust[resident_id])


func conversation_visits(resident_id: String) -> int:
	return int(data.get("conversation_visits", {}).get(resident_id, 0))


func record_conversation_visit(resident_id: String) -> int:
	if not data.has("conversation_visits") or data.conversation_visits is not Dictionary:
		data.conversation_visits = {}
	data.conversation_visits[resident_id] = conversation_visits(resident_id) + 1
	return int(data.conversation_visits[resident_id])


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


func _storage() -> SAVE_STORAGE:
	var storage := SAVE_STORAGE.new()
	storage.path = save_path
	storage.validate_document = _validate_document
	storage.operation_override = storage_operation_override
	return storage


func save_game() -> bool:
	if _preparing_state:
		return false
	flush_background_saves()
	if save_write_blocked:
		_last_save_result = {"ok": false, "code": str(_player_notice.get("code", "save_recovery_required")),
				"stage": "write_latch", "recovered": false, "protection_required": true}
		return false
	snapshot_preparing.emit()
	return _finish_save(_storage().write_snapshot(JSON.stringify(data, "\t", true, true).to_utf8_buffer()))


func _finish_save(result: Dictionary) -> bool:
	_last_save_result=result
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
	flush_background_saves()
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
	return preload("res://scripts/game/reality_save_document.gd").validate(candidate, SAVE_VERSION)


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
	flush_background_saves()
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
	_last_save_result = _storage().write_snapshot(JSON.stringify(candidate, "\t", true, true).to_utf8_buffer(), true)
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
	flush_background_saves()
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
