extends Node

signal run_failed(reason: String)
signal run_completed

var current_run: Array[Dictionary] = []
var current_index := 0
var last_failed_room: Dictionary = {}

func create_run(room_count: int = 5) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_unix_time_from_system()
	var choices := ["cup_choir", "laundry_orbit"]
	current_run.clear()
	if not last_failed_room.is_empty():
		current_run.append(last_failed_room.duplicate())
		last_failed_room.clear()
	for i in room_count:
		var room_id: String = choices[rng.randi_range(0, choices.size() - 1)]
		var seed := int(rng.randi())
		current_run.append({"room_id": room_id, "seed": seed})
	current_run = current_run.slice(0, room_count)
	current_index = 0
	return current_run

func get_current_room() -> Dictionary:
	if current_index >= current_run.size():
		return {}
	return current_run[current_index]

func advance_room() -> bool:
	current_index += 1
	if current_index >= current_run.size():
		run_completed.emit()
		return false
	return true

func fail_run(room_data: Dictionary, death_pos: Vector2) -> void:
	last_failed_room = room_data.duplicate()
	DeathRemnantStore.add_remnant(
		room_data.get("room_id", "unknown"),
		int(room_data.get("seed", 0)),
		death_pos,
		ProfileStore.profile
	)
	run_failed.emit("trap_triggered")
