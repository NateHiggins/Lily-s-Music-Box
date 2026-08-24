extends Node3D
## SR2 close proof: the real OtisProp and shared maintenance strip.

var board: OtisProp
var camera: Camera3D
var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://maintenance_annunciator_sr2"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_stage()
	call_deferred("_run")


func _build_stage() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.021, 0.018)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.24, 0.19, 0.14)
	environment.ambient_light_energy = 0.52
	world.environment = environment
	add_child(world)
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(2.7, 2.8, 0.10)
	wall.mesh = wall_mesh
	wall.position = Vector3(0.0, 1.4, -0.08)
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color(0.21, 0.16, 0.105)
	plaster.roughness = 0.92
	wall.material_override = plaster
	add_child(wall)
	board = OtisProp.new()
	board.name = "LobbyPorterBoard"
	board.prop_type = "otis"
	board.position = Vector3(0.0, 1.42, 0.0)
	add_child(board)
	var key := SpotLight3D.new()
	key.position = Vector3(-0.75, 2.25, 1.25)
	key.look_at_from_position(key.position, board.position)
	key.light_color = Color(1.0, 0.72, 0.42)
	key.light_energy = 5.2
	key.spot_range = 4.0
	key.shadow_enabled = true
	add_child(key)
	var edge := OmniLight3D.new()
	edge.position = Vector3(0.65, 1.3, 0.55)
	edge.light_color = Color(0.30, 0.52, 0.66)
	edge.light_energy = 0.75
	edge.omni_range = 3.0
	add_child(edge)
	camera = Camera3D.new()
	camera.fov = 43.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.42, 1.16),
			board.position, Vector3.UP)
	camera.make_current()


func _run() -> void:
	await get_tree().process_frame
	board.set_process(false)
	Engine.time_scale = 0.0
	await _capture("00_stuck_flag_control")
	await _capture("00b_stuck_flag_control")
	Engine.time_scale = 1.0
	if not board.interact_control("service", null):
		push_error("annunciator activity did not open")
		get_tree().quit(1)
		return
	board._service_panel._director.submit("hold_release", 0.44, 1.0)
	board._service_panel._adjust(0.13)
	await _capture("01_contacts_squared")
	board._service_panel._director.submit("align", 0.63)
	board._service_panel._adjust(-0.5)
	await _capture("02_common_reset")
	board._service_panel._director.abort()
	print("[ANNUNCIATOR SHOT] 4 frames saved")
	get_tree().quit(0)


func _capture(label: String) -> void:
	for _frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if error != OK:
		push_error("annunciator capture failed: %s" % label)
