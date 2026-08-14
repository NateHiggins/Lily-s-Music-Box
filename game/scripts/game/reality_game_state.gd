extends Node
## Persistent campaign state for Reality Maintenance. Content systems mutate
## this through RealityCases so temporary repair and emotional resolution
## cannot accidentally collapse into the same boolean.

signal state_changed

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
