extends Node

const SAVE_PATH := "user://death_remnants.save"
var decay_minutes: float = 30.0
var remnants: Array[Dictionary] = []

func _ready() -> void:
	load_data()
	prune()

func add_remnant(room_id: String, room_seed: int, world_position: Vector2, profile: PlayerProfile) -> void:
	var styles := ["InkSplatter", "PorcelainCrack", "GlitterSpill", "GoldLeafFracture", "CherryPetals", "StaticGlitch"]
	var poses := ["Collapsed", "Kneeling", "Reaching"]
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_unix_time_from_system() + room_seed
	var remnant := {
		"room_id": room_id,
		"room_seed": room_seed,
		"position": {"x": world_position.x, "y": world_position.y},
		"aura_color": profile.hair_gradient,
		"texture_style": styles[rng.randi_range(0, styles.size() - 1)],
		"pose": poses[rng.randi_range(0, poses.size() - 1)],
		"timestamp": Time.get_unix_time_from_system(),
	}
	remnants.append(remnant)
	save_data()

func list_for_room(room_id: String, room_seed: int) -> Array[Dictionary]:
	prune()
	var out: Array[Dictionary] = []
	for rem in remnants:
		if rem.get("room_id") == room_id and int(rem.get("room_seed")) == room_seed:
			out.append(rem)
	return out

func prune() -> void:
	var now := Time.get_unix_time_from_system()
	var ttl := int(decay_minutes * 60.0)
	remnants = remnants.filter(func(rem: Dictionary) -> bool:
		return (now - int(rem.get("timestamp", now))) < ttl
	)
	save_data()

func set_debug_decay(minutes: float) -> void:
	decay_minutes = max(minutes, 0.05)
	prune()

func recent(limit: int = 5) -> Array[Dictionary]:
	prune()
	var copy := remnants.duplicate()
	copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["timestamp"]) > int(b["timestamp"])
	)
	return copy.slice(0, min(limit, copy.size()))

func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(remnants))

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var parsed := JSON.parse_string(file.get_as_text())
		if parsed is Array:
			remnants = parsed
