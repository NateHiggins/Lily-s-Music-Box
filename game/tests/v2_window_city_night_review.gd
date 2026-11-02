extends Node3D
## Production-world optical review. Posed roof camera, not a walked route.
const Runtime = preload("res://scenes/building/orison_v2_runtime.tscn")
const Ephemeris = preload("res://scripts/building/celestial_ephemeris.gd")
var failures: Array[String] = []
var camera: Camera3D
var output := ""
var externally_managed := false
var external_host: Node
var record := {"evidence_class": "INERT", "scope": "installed city window optics and posed rooftop photograph", "views": []}

func _process(_delta: float) -> void:
	if externally_managed: return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	if externally_managed: return
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
	var near_bindings := 0
	var city: Node3D = world.get_node("CityShells")
	var seen_materials := {}
	if horizon != null:
		record["optical_preparation_ms"] = horizon.get_meta("window_optical_preparation_ms", -1)
		for draw: MeshInstance3D in city.find_children("*", "MeshInstance3D", true, false):
			if not str(draw.name).ends_with("__mirror_aged"): continue
			if not horizon.is_ancestor_of(draw) and not draw.get_meta("retained_city_shell", false): continue
			if draw.get_meta("retained_city_shell", false): near_bindings += 1
			check(draw.material_override is ShaderMaterial and draw.material_override.shader.resource_path.ends_with("v2_background_window_interior.gdshader"), "installed optical binding " + str(draw.name))
			if draw.material_override is ShaderMaterial and not seen_materials.has(draw.material_override.get_instance_id()):
				seen_materials[draw.material_override.get_instance_id()] = true
				check(is_equal_approx(float(draw.material_override.get_shader_parameter("minute_of_day")), clock.minute_of_day()), "installed windows read authoritative frozen clock")
				for key in ["albedo_tex", "rough_tex", "normal_tex", "wall_albedo", "wood_albedo"]:
					var texture: Texture2D = draw.material_override.get_shader_parameter(key)
					check(texture != null and texture.get_image().has_mipmaps(), "installed optical map has loaded mips " + key)
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
	check(near_bindings == 25, "all twenty-five neighbouring building window partitions installed")
	for draw: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if city.is_ancestor_of(draw) or draw.mesh == null: continue
		for surface in draw.mesh.get_surface_count():
			var material := draw.get_active_material(surface) as ShaderMaterial
			check(material == null or material.shader != preload("res://shaders/v2_background_window_interior.gdshader"), "Orison and its occupied windows remain outside optical installation")
	record["window_draw_bindings"] = bindings
	record["near_window_draw_bindings"] = near_bindings
	record["shared_window_materials"] = seen_materials.size()
	record["world_startup_ms"] = world.startup_ms
	var sky: ShaderMaterial = world.get_node("WakingAtmosphere").sky_material
	check(sky.get_shader_parameter("moon_relief_enabled") == true, "production relief Moon enabled")
	if OS.get_environment("ORISON_CITY_COMPOSITION_STUDY") == "1":
		await composition_study(world, clock)
	elif OS.get_environment("WINDOW_CITY_POSTCARDS") == "1":
		await postcards(world, clock)
	else:
		var moon: Vector3 = selected.moon
		var bearing := Vector3(moon.x, 0, moon.z).normalized()
		camera.look_at(camera.global_position + bearing * 100.0 + Vector3.UP * 3.0)
		for frame in 100: await RenderingServer.frame_post_draw
		await capture("orison_starlit_city_moon", world, clock)
		camera.fov = 65.0
		for frame in 30: await RenderingServer.frame_post_draw
		await capture("orison_starlit_city_detail", world, clock)
	world.shutdown_for_tests()
	world.free()
	await get_tree().physics_frame
	finish()

func run_composed(world: OrisonV2RuntimeRoot, host: Node) -> Dictionary:
	# Caller sets externally_managed before adding this helper. Never construct
	# a second world or run the standalone scene's reset/quit/input lifecycle.
	external_host = host
	output = OS.get_environment("SHOT_DIR")
	check(externally_managed and is_inside_tree() and world.player != null, "supplied optical review lifecycle")
	if not failures.is_empty(): return {"completed":false,"failures":failures}
	var actor := world.player
	var prior_camera := get_viewport().get_camera_3d()
	var physics := actor.is_physics_processing()
	var lamp := actor.lamp_is_enabled()
	var carrier := actor.carried_device as ServiceSetCarrier
	var hidden := carrier.is_capture_hidden() if carrier != null else false
	# This optical lease resets the campaign temporarily. The live shop cursor
	# belongs to the restored campaign, not to these out-of-order photo dates.
	var shops: Node = world.shop_simulation
	var shop_processing := shops.is_processing()
	var campaign_before := RealityState.data.duplicate(true)
	shops.set_process(false)
	var leased := RealityState.begin_preview_campaign(self)
	check(leased, "existing nonpersistent preview owner admits optical dates")
	if not leased:
		shops.set_process(shop_processing)
		return {"completed":false,"failures":failures}
	actor.set_physics_process(false)
	actor.set_lamp_enabled(false)
	if carrier != null: carrier.set_capture_hidden(true)
	camera = Camera3D.new()
	camera.cull_mask = actor.camera.cull_mask
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.far = 5000.
	add_child(camera); camera.make_current()
	await composition_study(world, CampaignClock.new())
	check(RealityState.end_preview_campaign(self), "original campaign context restored by its owner")
	# Allow time/weather readers to rebind before the enclosing survey proceeds.
	await get_tree().process_frame
	check(RealityState.data == campaign_before, "optical preview preserves the original durable campaign")
	check(not shops.failed and shops.advance_current(), "restored campaign retains a valid monotonic shop cursor")
	shops.set_process(shop_processing)
	actor.set_lamp_enabled(lamp)
	if carrier != null: carrier.set_capture_hidden(hidden)
	actor.set_physics_process(physics)
	if is_instance_valid(prior_camera): prior_camera.make_current()
	camera.free()
	record["completed"] = true; record["failures"] = failures
	record["scope"] = "Supplied production world optical diagnostic; preview lease and player presentation restored. No additional world or gameplay acceptance."
	var file := FileAccess.open(output.path_join("night_review.json"), FileAccess.WRITE)
	check(file != null, "write composed optical observations")
	if file != null:
		file.store_string(JSON.stringify(record, "\t")); check(file.get_error() == OK, "optical observations written"); file.close()
	return record

func composition_study(world: Node3D, clock: CampaignClock) -> void:
	# Diagnostic controls only. No production setting or material is changed.
	# Use one actual world and the existing absolute lighting writer; do not
	# invent another weather/time authority or repeat unrelated controller walks.
	var director: DayNightDirector = world.day_night_director
	var gains := Vector3(director._ambient_gain, director._fog_gain, director._sky_key_gain)
	var viewport_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	var inputs := {}
	for path: String in ["res://tests/v2_window_city_night_review.gd", "res://scripts/building/day_night_director.gd", "res://scripts/building/v2_city_day_night_director.gd", "res://scripts/building/orison_v2_atmosphere.gd", "res://data/orison_v2/exterior/city_horizon.json", "res://data/orison_v2/exterior/city_streets.json", "res://shaders/queens_weather_sky.gdshader"]:
		inputs[path] = FileAccess.get_sha256(path)
	var observations: Array[Dictionary] = []
	var poses := [
		{"id":"west_dusk", "date":[1928,11,10,1000], "eye":Vector3(14,24.5,9), "direction":Vector3(-1,-.12,-.15)},
		{"id":"north_noon", "date":[1928,11,10,720], "eye":Vector3(-14,24.5,-9), "direction":Vector3(0,-.12,-1)},
		{"id":"east_moonlight", "date":[1929,2,23,1170], "eye":Vector3(-14,24.5,-9), "direction":Vector3(1,-.08,-.04)}
	]
	for pose: Dictionary in poses:
		var date: Array = pose.date
		check(clock.configure_date(date[0],date[1],date[2],date[3]), "composition uses real campaign date")
		camera.global_position = world.adapter.root.to_global(pose.eye)
		camera.fov = 92.0
		camera.look_at(camera.global_position + (pose.direction as Vector3).normalized()*100.0)
		var roof := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-Vector3.UP*12.0,1))
		check(not roof.is_empty(), "composition photographic pose retains real roof support")
		await get_tree().create_timer(2.0).timeout
		var states := [gains.x, minf(2.0,gains.x*1.6), gains.x]
		for index in states.size():
			director.set_tuning_offsets(states[index],gains.y,gains.z)
			director._apply(float(date[3]))
			for frame in 30: await RenderingServer.frame_post_draw
			var samples: Array = []
			var previous := Time.get_ticks_usec()
			for frame in 60:
				await RenderingServer.frame_post_draw
				var current := Time.get_ticks_usec()
				samples.append([(current-previous)/1000.0,RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid),RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
				previous = current
			var suffix: String = ["baseline","ambient_control","restored"][index]
			var label: String = str(pose.id)+"_"+suffix
			await capture(label,world,clock)
			var environment: Environment = director._env
			observations.append({"id":label,"ambient_gain":states[index],"ambient_energy":environment.ambient_light_energy,"ambient_color":str(environment.ambient_light_color),"fog_gain":director._fog_gain,"key_gain":director._sky_key_gain,"render_samples":samples,"lighting":director.resolved_profile(),"image_sha256":FileAccess.get_sha256(output.path_join(label+".png"))})
		check(is_equal_approx(director._ambient_gain,gains.x) and is_equal_approx(director._fog_gain,gains.y) and is_equal_approx(director._sky_key_gain,gains.z), "lighting control fully restored")
	director.set_tuning_offsets(gains.x,gains.y,gains.z)
	RenderingServer.viewport_set_measure_render_time(viewport_rid, false)
	for path: String in inputs:
		check(FileAccess.get_sha256(path)==str(inputs[path]), "composition study source stayed frozen: "+path)
	check(observations.size()==9, "three actual composition poses have baseline/control/restore captures")
	record["composition_study"] = {"scope":"Three roof-supported posed cameras in one production world. Temporary ambient gain control through existing director, restored after each pose. Sixty static frames per state exclude PNG writes; observations under host contention, not walking or matched whole-city performance/artistic acceptance. No production lighting change.","inputs":inputs,"sample_columns":["wall_ms","main_render_cpu_ms","main_render_gpu_ms","engine_draws","engine_primitives"],"observations":observations,"render_settings":{"size":str(get_viewport().get_visible_rect().size),"msaa":get_viewport().msaa_3d,"taa":get_viewport().use_taa,"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode()}}

func postcards(world, clock: CampaignClock) -> void:
	# Roof-edge photographic crane poses. Never alter production player spawning.
	var shots := [
		{"id":"01_moonlit_east", "date":[1929,2,23,1170], "eye":Vector3(-14,24.5,-9), "direction":Vector3(1,-.015,-.04)},
		{"id":"02_blue_hour_west", "date":[1928,11,10,1035], "eye":Vector3(14,24.5,9), "direction":Vector3(-1,-.04,-.15)},
		{"id":"03_autumn_dawn", "date":[1928,11,10,405], "eye":Vector3(-14,24.5,9), "direction":Vector3(1,-.035,-.2)},
		{"id":"04_winter_afternoon", "date":[1929,2,23,990], "eye":Vector3(14,24.5,-9), "direction":Vector3(-1,-.065,.22)}
	]
	for shot: Dictionary in shots:
		var date: Array = shot.date
		check(clock.configure_date(date[0],date[1],date[2],date[3]), "postcard uses authoritative campaign date")
		camera.global_position = world.adapter.root.to_global(shot.eye)
		var roof: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position-Vector3.UP*12.0,1))
		check(not roof.is_empty(), "postcard roof fixture has real physical support")
		await get_tree().create_timer(2.0).timeout
		world.day_night_director._apply(float(date[3]))
		for angle in range(2):
			var direction: Vector3 = shot.direction
			if angle == 1: direction = direction.rotated(Vector3.UP, deg_to_rad(18.0))
			camera.fov = 92.0 if angle == 0 else 78.0
			camera.look_at(camera.global_position + direction.normalized()*100.0)
			for frame in 60: await RenderingServer.frame_post_draw
			await capture(str(shot.id)+("_wide" if angle == 0 else "_alternate"),world,clock)

func capture(label: String, world: Node, clock: CampaignClock) -> void:
	var path := output.path_join(label + ".png")
	check(get_viewport().get_texture().get_image().save_png(path) == OK, "actual rooftop image saved")
	record.views.append({"file": path, "campaign_local": clock.local_datetime(), "camera": str(camera.global_position), "horizontal_fov": camera.fov, "weather": world.weather_conditions()})

func check(ok: bool, label: String) -> void:
	if external_host != null: external_host.call("check", ok, "city composition: " + label)
	if not ok: failures.append(label); push_error(label)

func finish() -> void:
	record["failures"] = failures
	record["completed"] = true
	FileAccess.open(output.path_join("night_review.json"), FileAccess.WRITE).store_string(JSON.stringify(record, "\t"))
	print("WINDOW CITY NIGHT REVIEW ", JSON.stringify(record))
	get_tree().quit(0 if failures.is_empty() else 1)
