extends Node

const SAVE_PATH := "user://mansion_state.save"
var state := {
	"rewire_count": 0,
	"last_rewire_timestamp": 0,
	"template_weights": {"cup_choir": 1.0, "laundry_orbit": 1.0},
	"chime_message": "Welcome back, Lily.",
}

func _ready() -> void:
	load_state()

func apply_rewire() -> void:
	state["rewire_count"] = int(state["rewire_count"]) + 1
	state["last_rewire_timestamp"] = Time.get_unix_time_from_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state["last_rewire_timestamp"])
	state["template_weights"] = {
		"cup_choir": snappedf(rng.randf_range(0.6, 1.8), 0.1),
		"laundry_orbit": snappedf(rng.randf_range(0.6, 1.8), 0.1),
	}
	state["chime_message"] = "The mansion has rewired… corridors hum in a new key."
	save_state()

func save_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state))

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var parsed := JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			state.merge(parsed, true)
