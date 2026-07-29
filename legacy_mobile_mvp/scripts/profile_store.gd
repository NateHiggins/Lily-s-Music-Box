extends Node

const SAVE_PATH := "user://profile.save"
var profile: PlayerProfile = PlayerProfile.new()

func _ready() -> void:
	load_profile()

func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile.to_dict()))

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var parsed := JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			profile.from_dict(parsed)
