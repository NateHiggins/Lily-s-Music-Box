extends Node
## Persistent campaign state for Reality Maintenance. Content systems mutate
## this through RealityCases so temporary repair and emotional resolution
## cannot accidentally collapse into the same boolean.

signal state_changed
signal waking_residue_applied(residue_id: String, facts: Dictionary)

const SAVE_VERSION := 4
const SAVE_PATH := "user://reality_maintenance_save.json"

var data: Dictionary = {}
var persistence_enabled := true
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
		"core_loop": {},
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


func case_state(case_id: String) -> Dictionary:
	return data.cases.get(case_id, {})


func commit() -> void:
	if persistence_enabled:
		save_game()
	state_changed.emit()


func save_game() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("could not write Reality Maintenance save")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func load_game() -> void:
	data = _fresh_data()
	if not FileAccess.file_exists(save_path):
		_announce_loaded()
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_announce_loaded()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
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


func start_new_campaign() -> void:
	data = _fresh_data()
	save_game()
	state_changed.emit()


func _migrate() -> void:
	data.version = SAVE_VERSION
	save_game()


func reset_campaign_for_tests() -> void:
	data = _fresh_data()
	state_changed.emit()


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
