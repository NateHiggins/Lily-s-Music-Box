extends Node
## Windowed proof for N3's intentionally disposable corridor. The only figure
## in the pack is SHADOWS_ONLY; these frames must show its consequence without
## ever showing a beauty-pass body.

var _harness: DreamLightControlHarness
var _camera: Camera3D
var _caption: Label
var _output_dir := ""


func _ready() -> void:
	_output_dir = OS.get_environment("SHOT_DIR")
	if _output_dir == "":
		_output_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_build_world()
	await get_tree().physics_frame
	await _capture("01_lamp_on_shadow_only", true,
			"N3 CONTROL // LAMP ON // BODY: SHADOWS ONLY")
	await _capture("02_lamp_off_navigation_black", false,
			"N3 CONTROL // LAMP OFF // DARKNESS DELAYS, NEVER HIDES")
	print("[DREAM LIGHT N3 SHOT] RESULT: PASS")
	get_tree().quit(0)


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("05070d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("1d2740")
	environment.ambient_light_energy = 0.18
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	_harness = DreamLightControlHarness.new()
	_harness.name = "N3DisposableControl"
	add_child(_harness)
	_harness.set_shot_state(true)
	# The ruled light-off state is navigable darkness, not a black video file:
	# one unreachable receding practical preserves the far floor/end silhouette.
	var receding_practical := OmniLight3D.new()
	receding_practical.name = "RecedingOrientationControl"
	receding_practical.position = Vector3(0, 1.65, 38.5)
	receding_practical.light_color = Color("71809c")
	receding_practical.light_energy = 0.72
	receding_practical.omni_range = 9.5
	receding_practical.shadow_enabled = false
	add_child(receding_practical)
	var black_level_floor := OmniLight3D.new()
	black_level_floor.name = "NearestFloorBlackLevelControl"
	black_level_floor.position = Vector3(0, 0.28, 12.0)
	black_level_floor.light_color = Color("35415c")
	black_level_floor.light_energy = 0.48
	black_level_floor.omni_range = 9.0
	black_level_floor.shadow_enabled = false
	add_child(black_level_floor)

	_camera = Camera3D.new()
	_camera.name = "ProofCamera"
	_camera.position = Vector3(1.10, 1.36, 11.5)
	_camera.fov = 68.0
	_camera.near = 0.04
	add_child(_camera)
	_camera.look_at(Vector3(0, 0.86, 22.0))
	_camera.make_current()

	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	_caption = Label.new()
	_caption.position = Vector2(24, 22)
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_color", Color("d9c996"))
	canvas.add_child(_caption)


func _capture(file_name: String, lamp_on: bool, caption: String) -> void:
	_harness.set_shot_state(lamp_on)
	_caption.text = caption
	for _frame in 24:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _output_dir.path_join(file_name + ".png")
	var error := image.save_png(path)
	if error != OK:
		push_error("N3 shot failed to write %s" % path)
		get_tree().quit(1)
		return
	print("[DREAM LIGHT N3 SHOT] saved %s" % path)
