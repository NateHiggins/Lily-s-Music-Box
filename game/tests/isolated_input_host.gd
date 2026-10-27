extends SceneTree
## Test-only host for rendered interaction on a noninteractive OS window station.
## Launch through the shared lane with --script and the original test scene.
## This does not isolate native input itself: the launcher must do that first.
const SOURCE := "res://tests/isolated_input_host.gd"
const RENDER_PROPERTIES: Array[StringName] = [
	&"msaa_2d", &"msaa_3d", &"use_taa", &"use_debanding", &"screen_space_aa",
	&"scaling_3d_scale", &"scaling_3d_mode", &"fsr_sharpness",
	&"texture_mipmap_bias", &"anisotropic_filtering_level",
	&"use_occlusion_culling", &"mesh_lod_threshold", &"use_hdr_2d",
	&"snap_2d_transforms_to_pixel", &"snap_2d_vertices_to_pixel",
	&"canvas_item_default_texture_filter", &"canvas_item_default_texture_repeat",
	&"positional_shadow_atlas_size", &"positional_shadow_atlas_16_bits",
	&"positional_shadow_atlas_quad_0", &"positional_shadow_atlas_quad_1",
	&"positional_shadow_atlas_quad_2", &"positional_shadow_atlas_quad_3",
	&"vrs_mode", &"vrs_update_mode", &"vrs_texture",
]

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
	_copy_render_settings(viewport)
	# Autoloads can apply user settings in _ready. The supported fixtures defer
	# their programmes, so synchronize again before those programmes start.
	scene.ready.connect(_copy_render_settings.bind(viewport), CONNECT_ONE_SHOT)
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


func _copy_render_settings(viewport: SubViewport) -> void:
	var snapshot := {}
	for property: StringName in RENDER_PROPERTIES:
		var expected: Variant = root.get(property)
		viewport.set(property, expected)
		if viewport.get(property) != expected:
			push_error("Isolated viewport failed to retain root setting: " + str(property))
			quit(1)
			return
		snapshot[str(property)] = expected
	print("ISOLATED VIEWPORT ROOT SETTINGS: ", JSON.stringify(snapshot))
