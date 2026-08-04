extends Node
## Autoload "GameBoot": registers input actions in code so the project file
## stays free of hand-serialized InputEvent blobs.

const ACTIONS := {
	"move_forward": KEY_W, "move_back": KEY_S,
	"move_left": KEY_A, "move_right": KEY_D,
	"run": KEY_SHIFT, "crouch": KEY_C, "jump": KEY_SPACE,
	"interact": KEY_E, "flashlight": KEY_F,
	"music_player": KEY_M,
	"noclip": KEY_V, "debug_panel": KEY_F1,
	"intro": KEY_F2,
	"distort_map": KEY_F3,
	"chaos_mode": KEY_F4,
}

const SETTINGS_PATH := "user://orison_settings.cfg"
const GAME_SCENE := "res://scenes/building/orison_root.tscn"

enum LaunchMode { CINEMATIC, DEBUG }

var launch_mode := LaunchMode.CINEMATIC
var settings := {
	"quality": 0, # 0 cinematic, 1 balanced
	"fullscreen": false,
	"master_volume": 0.82,
}


func _ready() -> void:
	_load_settings()
	apply_user_settings()
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = ACTIONS[action]
			InputMap.action_add_event(action, ev)


func begin_game(mode: LaunchMode, new_campaign := false) -> void:
	launch_mode = mode
	if new_campaign:
		RealityState.start_new_campaign()
	apply_render_profile()
	get_tree().change_scene_to_file(GAME_SCENE)


func apply_render_profile() -> void:
	var cinematic := launch_mode == LaunchMode.CINEMATIC \
			and int(settings.get("quality", 0)) == 0
	var atlas_size := 8192 if cinematic else 4096
	ProjectSettings.set_setting(
			"rendering/lights_and_shadows/positional_shadow/atlas_size", atlas_size)
	ProjectSettings.set_setting(
			"rendering/lights_and_shadows/directional_shadow/size", atlas_size)
	ProjectSettings.set_setting(
			"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality",
			3 if cinematic else 2)
	ProjectSettings.set_setting(
			"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality",
			3 if cinematic else 2)
	var viewport := get_tree().root
	viewport.positional_shadow_atlas_size = atlas_size
	RenderingServer.directional_shadow_atlas_set_size(atlas_size, true)


func apply_user_settings() -> void:
	var fullscreen := bool(settings.get("fullscreen", false))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(
				maxf(0.001, float(settings.get("master_volume", 0.82)))))


func save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("display", key, settings[key])
	config.save(SETTINGS_PATH)
	apply_user_settings()


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for key in settings:
		settings[key] = config.get_value("display", key, settings[key])


## Blender (Z-up, Y-north) -> Godot (Y-up, -Z north) via the glTF convention.
static func b2g(p: Array) -> Vector3:
	return Vector3(p[0], p[2], -p[1])
