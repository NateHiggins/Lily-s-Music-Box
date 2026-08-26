extends Node
## Autoload "GameBoot": registers input actions in code so the project file
## stays free of hand-serialized InputEvent blobs.

const ACTIONS := {
	"move_forward": KEY_W, "move_back": KEY_S,
	"move_left": KEY_A, "move_right": KEY_D,
	"run": KEY_SHIFT, "crouch": KEY_C, "jump": KEY_SPACE,
	"interact": KEY_E, "shot_capture": KEY_F,
	"lamp_toggle": KEY_L, "radio_toggle": KEY_R,
	"music_player": KEY_M,
	"noclip": KEY_V, "debug_panel": KEY_F1,
	"intro": KEY_F2,
}

## Shoulder switches remain reachable while both thumbs steer and look. They
## feed the same named actions as keyboard and touch; PlayerController never
## branches on input device.
const JOYPAD_ACTIONS := {
	"interact": JOY_BUTTON_A,
	"jump": JOY_BUTTON_Y,
	"crouch": JOY_BUTTON_LEFT_STICK,
	"lamp_toggle": JOY_BUTTON_LEFT_SHOULDER,
	"radio_toggle": JOY_BUTTON_RIGHT_SHOULDER,
	"activity_adjust_left": JOY_BUTTON_DPAD_LEFT,
	"activity_adjust_right": JOY_BUTTON_DPAD_RIGHT,
	"activity_commit": JOY_BUTTON_A,
}

const JOYPAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0],
	"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"run": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}

const JOYPAD_EXTRA_BUTTONS := {
	"lamp_toggle": [JOY_BUTTON_X],
	"ui_cancel": [JOY_BUTTON_B, JOY_BUTTON_START],
}

## Maintenance panels consume meanings, never device keycodes. Keep commit
## separate from `interact`: PlayerController polls interact before call_locked
## can protect the newly opened panel, so sharing it can double-fire one press.
const ACTIVITY_KEY_ACTIONS := {
	"activity_adjust_left": [KEY_A, KEY_LEFT],
	"activity_adjust_right": [KEY_D, KEY_RIGHT],
	"activity_commit": [KEY_E, KEY_SPACE],
}

const SETTINGS_PATH := "user://orison_settings.cfg"
const BUILDING_SCENE := "res://scenes/building/orison_root.tscn"
const GAME_SCENE := "res://scenes/campaign/CampaignShell.tscn"

enum LaunchMode { CINEMATIC, DEBUG }

var launch_mode := LaunchMode.CINEMATIC
var settings := {
	"quality": 0, # 0 cinematic, 1 balanced
	"fullscreen": false,
	"master_volume": 0.82,
	"gameplay_volume": 1.0,
	"voice_volume": 1.0,
	"world_volume": 1.0,
	"music_volume": 1.0,
	"ui_volume": 1.0,
	"look_sensitivity": 1.0,
	"controller_look_sensitivity": 1.0,
	"controller_invert_y": false,
	"controller_look_deadzone": 0.18,
	"controller_look_curve": 1.65,
	"reduce_camera_roll": false,
	"reduce_flashing": false,
	# Privacy: off means only fixed Queens coordinates are sent for weather.
	# On means the player-authored city/postal text is geocoded by Open-Meteo.
	# No IP geolocation or device sensor is used behind this choice.
	"live_local_weather": false,
	"weather_location_query": "",
	# Accessibility: later case profiles may allow a sudden sleep attack, but
	# this forces the same legible gradual warning Mina teaches first.
	"always_warn_before_sleep": false,
	# Accessibility: writes each hazard tell on screen as its cue and one of
	# eight sectors relative to the player's facing. Never a distance or a
	# room name -- a caption player must get what the ear gets and no more,
	# or the light decision the dream is built on stops costing anything.
	# Off by default: the mix already carries this, and the dream's grammar
	# is listening.
	"dream_directional_captions": false,
	# Captions semantic gameplay cues with only the source class and relative
	# sector already available to a listener. No distance, room or case owner.
	"gameplay_sound_captions": false,
	# Measured once by the Songbook's clap check and kept for good.
	# _load_settings only reads keys that already exist here, so a
	# setting absent from this dict is a setting that never persists.
	"songbook_latency_ms": 0.0,
}


func _ready() -> void:
	_load_settings()
	apply_user_settings()
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = ACTIONS[action]
		_ensure_action_event(action, key_event)
	for action in JOYPAD_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = JOYPAD_ACTIONS[action]
		_ensure_action_event(action, button_event)
	for action in ACTIVITY_KEY_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in ACTIVITY_KEY_ACTIONS[action]:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			_ensure_action_event(action, key_event)
	for action in JOYPAD_AXES:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var axis_event := InputEventJoypadMotion.new()
		axis_event.axis = JOYPAD_AXES[action][0]
		axis_event.axis_value = JOYPAD_AXES[action][1]
		_ensure_action_event(action, axis_event)
	for action in JOYPAD_EXTRA_BUTTONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for button in JOYPAD_EXTRA_BUTTONS[action]:
			var button_event := InputEventJoypadButton.new()
			button_event.button_index = button
			_ensure_action_event(action, button_event)


func _ensure_action_event(action: StringName, event: InputEvent) -> void:
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


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
	apply_audio_settings()


func apply_audio_settings(reapply_policy := true) -> void:
	for record in [
		["Master", "master_volume", 0.82],
		["Gameplay", "gameplay_volume", 1.0],
		["Voice", "voice_volume", 1.0],
		["World", "world_volume", 1.0],
		["Music", "music_volume", 1.0],
		["UI", "ui_volume", 1.0],
	]:
		var bus := AudioServer.get_bus_index(str(record[0]))
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, audio_bus_db(str(record[0])))
	if reapply_policy:
		var policy := get_node_or_null("/root/AudioPolicy")
		if policy != null and policy.has_method("reapply_mix"):
			policy.call("reapply_mix")


func audio_bus_db(bus_name: String) -> float:
	var keys := {
		"Master":"master_volume", "Gameplay":"gameplay_volume",
		"Voice":"voice_volume", "World":"world_volume",
		"Music":"music_volume", "UI":"ui_volume",
	}
	var defaults := {"Master":0.82, "Gameplay":1.0, "Voice":1.0,
		"World":1.0, "Music":1.0, "UI":1.0}
	if not keys.has(bus_name):
		return 0.0
	return linear_to_db(maxf(0.001, float(settings.get(
			keys[bus_name], defaults[bus_name]))))


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
