extends Node3D
## SR3 close proof: the real BoilerProp water column and shared service strip.

var boiler: BoilerProp
var camera: Camera3D
var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://maintenance_boiler_sr3"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_stage()
	call_deferred("_run")


func _build_stage() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.014, 0.016)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.13, 0.16, 0.17)
	environment.ambient_light_energy = 0.42
	world.environment = environment
	add_child(world)
	_stage_box(Vector3(4.8, 0.10, 4.2), Vector3(0, -0.05, 0),
			Color(0.085, 0.075, 0.065))
	_stage_box(Vector3(4.8, 2.8, 0.10), Vector3(0, 1.4, 0.85),
			Color(0.105, 0.095, 0.082))
	boiler = BoilerProp.new()
	boiler.name = "BasementCoalPlant"
	boiler.prop_type = "boiler"
	boiler.position = Vector3(0.0, 0.0, 0.0)
	add_child(boiler)
	var key := SpotLight3D.new()
	key.position = Vector3(1.8, 2.35, -2.1)
	key.look_at_from_position(key.position, Vector3(0.20, 1.0, -0.35))
	key.light_color = Color(1.0, 0.63, 0.32)
	key.light_energy = 7.0
	key.spot_range = 6.0
	key.shadow_enabled = true
	add_child(key)
	var glass_light := OmniLight3D.new()
	glass_light.position = Vector3(0.85, 1.05, -0.75)
	glass_light.light_color = Color(0.30, 0.67, 0.74)
	glass_light.light_energy = 1.7
	glass_light.omni_range = 2.2
	add_child(glass_light)
	camera = Camera3D.new()
	camera.fov = 47.0
	add_child(camera)
	camera.look_at_from_position(Vector3(1.85, 1.28, -2.45),
			Vector3(0.12, 1.0, -0.30), Vector3.UP)
	camera.make_current()


func _stage_box(size: Vector3, at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	node.material_override = material
	add_child(node)


func _run() -> void:
	await get_tree().process_frame
	boiler.set_process(false)
	Engine.time_scale = 0.0
	await _capture("00_service_control")
	await _capture("00b_service_control")
	Engine.time_scale = 1.0
	if not boiler.interact_control("water_column", null):
		push_error("boiler activity did not open")
		get_tree().quit(1)
		return
	boiler._service_panel._adjust(-0.5)
	await _capture("01_column_isolated")
	boiler._service_panel._director.submit("turn", 0.0)
	boiler.preview_maintenance_hold(
			boiler._service_panel._director.active_run.current_step(), 1.0, 0.5)
	await _capture("02_false_column_empty")
	boiler._service_panel._director.submit("hold_release", 0.5, 1.8)
	boiler._service_panel._adjust(0.12)
	await _capture("03_level_witnessed")
	boiler._service_panel._director.submit("align", 0.62)
	boiler._service_panel._adjust(0.5)
	await _capture("04_guarded_service")
	boiler._service_panel._director.abort()
	await get_tree().process_frame
	await get_tree().process_frame
	boiler._draft_bed.stop()
	boiler.queue_free()
	await get_tree().process_frame
	print("[BOILER SHOT] 6 frames saved")
	get_tree().quit(0)


func _capture(label: String) -> void:
	for _frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if error != OK:
		push_error("boiler capture failed: %s" % label)
