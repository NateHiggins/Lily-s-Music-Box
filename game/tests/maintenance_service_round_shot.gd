extends Node
## Paired production-building proof for the first Service Round apparatus.
##     SHOT_DIR=<abs> godot --path game res://tests/MaintenanceServiceRoundShot.tscn

var camera: Camera3D


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_build_review_stage()
	var radiator := RadiatorProp.new()
	radiator.name = "ProductionRadiator"
	radiator.unit = "4B"
	add_child(radiator)
	await get_tree().process_frame
	camera = Camera3D.new()
	camera.fov = 53.0
	add_child(camera)
	camera.make_current()
	camera.global_position = radiator.to_global(Vector3(0.72, 0.88, -1.42))
	camera.look_at(radiator.to_global(Vector3(0.0, 0.35, 0.0)))
	await _capture("01_radiator_control")

	var panel := MaintenanceActivityPanel.new()
	add_child(panel)
	if not panel.open(null, radiator, "radiator_vent_service"):
		push_error("Service Round shot could not open the activity")
		get_tree().quit(1)
		return
	# Reach the vent-clocking beat through the same director contract used by
	# play. Only the final hand position is set by the proof harness.
	panel._director.submit("turn", 0.0)
	panel._director.submit("hold_release", 0.5, 1.4)
	panel._adjust(0.22)
	await _capture("02_radiator_service_active")
	panel._director.abort()
	print("[SERVICE ROUND SHOT] paired production frames saved")
	get_tree().quit(0)


func _build_review_stage() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.055, 0.045, 0.038)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.30, 0.24, 0.18)
	settings.ambient_light_energy = 0.48
	environment.environment = settings
	add_child(environment)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(4.0, 4.0)
	floor.mesh = floor_mesh
	floor.material_override = _material(Color(0.15, 0.10, 0.065), 0.82)
	add_child(floor)
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(4.0, 2.5, 0.08)
	wall.mesh = wall_mesh
	wall.position = Vector3(0, 1.25, 0.30)
	wall.material_override = _material(Color(0.32, 0.24, 0.17), 0.90)
	add_child(wall)
	var key := SpotLight3D.new()
	key.position = Vector3(-1.2, 2.1, -1.5)
	key.look_at_from_position(key.position, Vector3(0, 0.4, 0))
	key.light_color = Color(1.0, 0.76, 0.48)
	key.light_energy = 5.0
	key.spot_range = 5.0
	key.shadow_enabled = true
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.2, 1.0, -0.8)
	fill.light_color = Color(0.42, 0.62, 0.72)
	fill.light_energy = 0.7
	fill.omni_range = 4.0
	add_child(fill)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _capture(label: String) -> void:
	for _frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out_dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if error != OK:
		push_error("Service Round shot failed: %s" % label)
