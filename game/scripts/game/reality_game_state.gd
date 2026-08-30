extends Node
## Persistent campaign state for Reality Maintenance. Content systems mutate
## this through RealityCases so temporary repair and emotional resolution
## cannot accidentally collapse into the same boolean.

signal state_changed
signal waking_residue_applied(residue_id: String, facts: Dictionary)
signal player_notice_changed(notice: Dictionary)

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
	if persistence_enabled:
		save_game()
	state_changed.emit()


func save_game() -> bool:
	if save_write_blocked:
		push_warning("refusing to overwrite newer Reality Maintenance save version %d"
				% incompatible_save_version)
		_set_future_save_notice()
		return false
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("could not write Reality Maintenance save")
		_set_player_notice("save_write_failed", "PROGRESS COULD NOT BE SAVED",
				"The save file could not be written. Progress since the last " +
				"successful save may be lost. Check storage access and available " +
				"disk space.")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func load_game() -> void:
	data = _fresh_data()
	save_write_blocked = false
	incompatible_save_version = 0
	_player_notice = {}
	if not FileAccess.file_exists(save_path):
		_announce_loaded()
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_set_player_notice("save_read_failed", "SAVE COULD NOT BE READ",
				"The existing save file could not be opened. A new session has " +
				"started without changing that file.", false)
		_announce_loaded()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var loaded_version := int((parsed as Dictionary).get("version", 0))
		if loaded_version > SAVE_VERSION:
			save_write_blocked = true
			incompatible_save_version = loaded_version
			push_warning("save version %d is newer than supported version %d; running read-only"
					% [loaded_version, SAVE_VERSION])
			_set_future_save_notice(false)
			_announce_loaded()
			return
		data.merge(parsed, true)
		if not data.has("music_library"):
			data.music_library = []
		if not data.has("heard_music_anecdotes"):
			data.heard_music_anecdotes = []
		if not data.has("building_personality"):
			data.building_personality = {}
		if not data.has("work_orders"):
			data.work_orders = {}
		if not data.has("maintenance_jobs"):
			data.maintenance_jobs = {}
		if not data.has("maintenance_items"):
			data.maintenance_items = {}
		if not data.has("open_shift_situations"):
			data.open_shift_situations = {}
		if not data.has("shop_buckets"):
			data.shop_buckets = {}
		if not data.has("exterior_semantics"):
			data.exterior_semantics = {}
		if not data.has("campaign_clock"):
			data.campaign_clock = {}
		if not data.has("core_loop"):
			data.core_loop = {}
		if not data.has("dream_seed"):
			data.dream_seed = _new_dream_seed()
		# Additive key, backfilled like every other one here rather than
		# through a SAVE_VERSION bump. Zero is the honest default: a save from
		# before the fractal existed has no night count to recover, and
		# starting the building sharp is the reading that cannot surprise a
		# returning player with a world that has already rotted.
		if not data.has("dreams_had"):
			data.dreams_had = 0
		if not data.has("dream"):
			data.dream = {}
		if not data.has("sleep_pressure"):
			data.sleep_pressure = {}
		if not data.has("waking_residues"):
			data.waking_residues = {}
		if not data.has("last_waking_residue_id"):
			data.last_waking_residue_id = ""
		if int(data.get("version", 0)) < SAVE_VERSION:
			_migrate()
	_announce_loaded()


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
	if emit_now:
		player_notice_changed.emit(player_notice())


func start_new_campaign() -> void:
	save_write_blocked = false
	incompatible_save_version = 0
	_player_notice = {}
	data = _fresh_data()
	save_game()
	state_changed.emit()
	player_notice_changed.emit(player_notice())


func _migrate() -> void:
	data.version = SAVE_VERSION
	save_game()


func reset_campaign_for_tests() -> void:
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
