extends Node
## Persistent campaign state for Reality Maintenance. Content systems mutate
## this through RealityCases so temporary repair and emotional resolution
## cannot accidentally collapse into the same boolean.

signal state_changed

const SAVE_VERSION := 4
const SAVE_PATH := "user://reality_maintenance_save.json"

var data: Dictionary = {}
var persistence_enabled := true


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
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("could not write Reality Maintenance save")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func load_game() -> void:
	data = _fresh_data()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
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
		if int(data.get("version", 0)) < SAVE_VERSION:
			_migrate()


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
