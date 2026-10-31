extends Node3D
## Production-world optical review. Posed roof camera, not a walked route.
const Runtime = preload("res://scenes/building/orison_v2_runtime.tscn")
const Ephemeris = preload("res://scripts/building/celestial_ephemeris.gd")
var failures: Array[String] = []
var camera: Camera3D
var output := ""
var record := {"evidence_class": "INERT", "scope": "installed city window optics and posed rooftop photograph", "views": []}

func _process(_delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled = false
	OS.set_environment("DAYNIGHT_FORCE", "")
	get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	get_window().size = DisplayServer.screen_get_size()
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty(): get_tree().quit(64); return
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func run() -> void:
	var clock := CampaignClock.new()
	# Select a real authored clear evening with a low, substantially lit Moon.
	# No weather, phase or celestial-direction override is used for the photo.
	var calendar: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CampaignWeather.PATH))
	var best := -INF
	var selected := {}
	for day: Dictionary in calendar.days:
		var date := Time.get_datetime_dict_from_datetime_string(str(day.date) + "T00:00:00", false)
		for minute in [1110, 1170, 1230, 1290]:
			if not clock.configure_date(date.year, date.month, date.day, minute): continue
			var utc := clock.utc_datetime()
			var moon: Vector3 = Ephemeris.moon_direction(utc, 40.75, -73.92)
			var sun: Vector3 = Ephemeris.sun_direction(utc, 40.75, -73.92)
			var illumination: float = Ephemeris.moon_illuminated_fraction(utc, 40.75, -73.92)
			if moon.y < 0.15 or moon.y > 0.55 or sun.y > -0.16 or illumination < 0.65: continue
			var weather := CampaignWeather.snapshot(clock.local_datetime())
			var score := illumination - float(weather.get("cloud_total", 1)) * 2.0 - absf(moon.y - 0.3)
			if score > best:
				best = score; selected = {"year": date.year, "month": date.month, "day": date.day, "minute": minute, "moon": moon, "weather": weather, "illumination": illumination}
	check(not selected.is_empty(), "authored clear evening and moon selected")
	if selected.is_empty(): finish(); return
	clock.configure_date(selected.year, selected.month, selected.day, selected.minute)
	record["selection"] = selected
	var world = Runtime.instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0: await get_tree().process_frame
	check(not world.startup_failed and world.player != null, "production world started")
	if world.startup_failed or world.player == null:
		world.shutdown_for_tests(); world.free(); finish(); return
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	world.player.set_lamp_enabled(false)
	if world.player.carried_device is ServiceSetCarrier: world.player.carried_device.set_capture_hidden(true)
	camera = Camera3D.new()
	camera.cull_mask = world.player.camera.cull_mask
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 100.0
	camera.far = 5000.0
	add_child(camera)
	camera.global_position = world.adapter.root.to_global(Vector3(14, 22.8, -9))
	camera.make_current()
	var downward: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - Vector3.UP * 8.0, 1))
	check(not downward.is_empty(), "posed camera has actual Orison roof beneath it")
	var horizon: Node3D = world.get_node("CityShells/CityHorizon") if world.has_node("CityShells/CityHorizon") else world.find_child("CityHorizon", true, false)
	check(horizon != null, "production horizon mounted")
	var bindings := 0
	if horizon != null:
		for draw: MeshInstance3D in horizon.find_children("*", "MeshInstance3D", true, false):
			if not str(draw.name).ends_with("__mirror_aged"): continue
			check(draw.material_override is ShaderMaterial and draw.material_override.shader.resource_path.ends_with("v2_background_window_interior.gdshader"), "installed optical binding " + str(draw.name))
			var source: Mesh = draw.get_meta("v2_window_source_mesh", null)
			check(source != null, "original physical pane retained")
			if source != null:
				var before := source.surface_get_arrays(0)
				var after := draw.mesh.surface_get_arrays(0)
				for channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
					check(before[channel] == after[channel], "physical array retained %d" % channel)
				check(RenderingServer.mesh_get_surface(source.get_rid(), 0).get("lods", []) == RenderingServer.mesh_get_surface(draw.mesh.get_rid(), 0).get("lods", []), "LOD index bytes retained")
			bindings += 1
	check(bindings > 50, "background windows installed across the city")
	record["window_draw_bindings"] = bindings
	var sky: ShaderMaterial = world.get_node("WakingAtmosphere").sky_material
	check(sky.get_shader_parameter("moon_relief_enabled") == true, "production relief Moon enabled")
	var moon: Vector3 = selected.moon
	var bearing := Vector3(moon.x, 0, moon.z).normalized()
	camera.look_at(camera.global_position + bearing * 100.0 + Vector3.UP * 3.0)
	for frame in 100: await RenderingServer.frame_post_draw
	await capture("orison_starlit_city_moon", world, clock)
	# Same composed city, narrower optical detail; never replace the requested wide shot.
	camera.fov = 65.0
	for frame in 30: await RenderingServer.frame_post_draw
	await capture("orison_starlit_city_detail", world, clock)
	world.shutdown_for_tests()
	world.free()
	await get_tree().physics_frame
	finish()

func capture(label: String, world: Node, clock: CampaignClock) -> void:
	var path := output.path_join(label + ".png")
	check(get_viewport().get_texture().get_image().save_png(path) == OK, "actual rooftop image saved")
	record.views.append({"file": path, "campaign_local": clock.local_datetime(), "camera": str(camera.global_position), "horizontal_fov": camera.fov, "weather": world.weather_conditions()})

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)

func finish() -> void:
	record["failures"] = failures
	record["completed"] = true
	FileAccess.open(output.path_join("night_review.json"), FileAccess.WRITE).store_string(JSON.stringify(record, "\t"))
	print("WINDOW CITY NIGHT REVIEW ", JSON.stringify(record))
	get_tree().quit(0 if failures.is_empty() else 1)
