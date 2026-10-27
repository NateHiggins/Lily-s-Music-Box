extends SceneTree
## Test-only host for rendered interaction on a noninteractive OS window station.
## Launch through the shared lane with --script and the original test scene.
## This does not isolate native input itself: the launcher must do that first.
const SOURCE := "res://tests/isolated_input_host.gd"

class InputRelay extends Node:
	var destination: SubViewport
	func _input(event: InputEvent) -> void:
		destination.push_input(event, true)


func _initialize() -> void:
	var scene := current_scene
	if scene == null or not scene.scene_file_path.begins_with("res://tests/"):
		push_error("Isolated input host requires an explicit test scene")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.name = "IsolatedTestViewport"
	# The native Window still has its bootstrap 100x100 size at this point.
	viewport.size = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
	viewport.own_world_3d = true
	viewport.handle_input_locally = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.audio_listener_enable_3d = true
	for property: StringName in [&"msaa_2d", &"msaa_3d", &"use_taa", &"use_debanding",
			&"screen_space_aa", &"scaling_3d_scale", &"scaling_3d_mode",
			&"positional_shadow_atlas_size", &"positional_shadow_atlas_16_bits"]:
		viewport.set(property, root.get(property))
	viewport.set_meta("isolated_input_host_sha256", FileAccess.get_sha256(SOURCE))
	root.add_child(viewport)
	# MainLoop initialization precedes the root entering the tree. Reparent now,
	# before test _ready/deferred runs create cameras, physics and GUI owners.
	scene.reparent(viewport, false)
	var relay := InputRelay.new()
	relay.destination = viewport
	root.add_child(relay)
	var display := TextureRect.new()
	display.name = "IsolatedTestImage"
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.texture = viewport.get_texture()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(display)
	viewport.notify_mouse_entered()
	print("ISOLATED INPUT HOST: scene=", scene.scene_file_path,
		" size=", viewport.size, " sha256=", FileAccess.get_sha256(SOURCE),
		" evidence=engine-dispatched input, not native OS input or human acceptance")
