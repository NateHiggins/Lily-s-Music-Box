extends Node3D
## Technical review fixture for the mid-ground batch (build_city_midground.py): street
## views from just inside Lily's 200 m edge looking out over the mid ground, at day, dusk
## and night; no mid-ground collision beyond the edge; and matched render cost with the
## batch present and hidden.
## No campaign, route or save authority; the gameplay clock is frozen and checked.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Temporal := preload("res://scripts/game/prologue_temporal_sky.gd")
const ExtremeWeather := preload("res://scripts/building/queens_weather_extension.gd")
const TIMES := {"day": 720, "dusk": 1043, "night": 1150}
const ROAD := 9.144
const WALK := 3.6
const BANK := Vector2(256.53, -379.64)  # art/blender/data/city_midground_survey/layout.json landmarks

var _failures: Array[String] = []
var _frames: Array[Dictionary] = []
var _costs: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(passed: bool, label: String) -> bool:
	if not passed:
		_failures.append(label)
		push_error("MIDGROUND: " + label)
	return passed


func _views(world: OrisonV2RuntimeRoot, _data: Dictionary) -> Array[Dictionary]:
	# Lily's edge is 200 m from the front door (ruling barrier_distance), and inside it is the
	# composed near city. The mid ground is what she sees beyond: stand just inside the edge at
	# the four compass points and on the diagonals, and look outward.
	var views: Array[Dictionary] = []
	for bearing: float in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
		# The near city is filled in, so the exact point may be a roof: take the nearest street or yard
		# around it (a little nearer or farther, a few degrees either side), still looking outward.
		var eye := Vector3.INF
		for radius: float in [160.0, 155.0, 165.0, 150.0, 170.0, 145.0]:
			for offset: float in [0.0, -4.0, 4.0, -8.0, 8.0]:
				var radians := deg_to_rad(bearing + offset)
				eye = _floor_eye(world, Vector3(sin(radians), 0.0, -cos(radians)) * radius)
				if eye.is_finite():
					break
			if eye.is_finite():
				break
		if eye.is_finite():
			views.append({"id": "out_%03d" % int(bearing), "eye": eye, "bearing": bearing, "pitch": 0.04, "fov": 72.0})
	_check(views.size() >= 7, "standing points just inside the edge")
	# The Queens Plaza bank clock (build_city_midground.py pick_landmark), from the Orison's roof:
	# at street level the lofts in front hide it.
	var roof: Vector3 = world.adapter.root.to_global(Vector3(-11.0, 20.8702503, 6.0))
	var bank_bearing := rad_to_deg(atan2(BANK.x - roof.x, -(BANK.y - roof.z)))
	views.append({"id": "bank_clock", "eye": roof, "bearing": bank_bearing, "pitch": 0.08, "fov": 30.0})
	return views


func _floor_eye(world: OrisonV2RuntimeRoot, nominal: Vector3) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(nominal + Vector3.UP * 80.0, nominal - Vector3.UP * 20.0, 1,
		[world.player.get_rid()]))
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.9 or hit.position.y > 6.0:
		return Vector3.INF  # roofs and walls are not a standing point
	return hit.position + Vector3.UP * PlayerController.STANDING_EYE


func _view_only(data: Dictionary) -> void:
	# Beyond the edge the fabric is seen, never stood on: no collision past the margin.
	var limit := 215.0  # WALKABLE in build_city_midground.py
	var outside := 0
	for item: Array in data.colliders:
		var nearest := Vector2(clampf(0.0, item[0] - item[3] * 0.5, item[0] + item[3] * 0.5),
			clampf(0.0, item[2] - item[5] * 0.5, item[2] + item[5] * 0.5))
		if nearest.length() >= limit:
			outside += 1
	_check(outside == 0, "no mid-ground collision beyond the walkable edge")


func _run() -> void:
	var output := OS.get_environment("SHOT_DIR")
	if not _check(not output.is_empty() and DisplayServer.get_name() != "headless", "hidden native window and evidence directory required"):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled = false
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var clock := CampaignClock.new()
	_check(clock.configure_date(1929, 2, 23, 0), "isolated fixture date initialised once")
	var midnight := float(Time.get_unix_time_from_datetime_dict(clock.utc_datetime()))
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	while world.startup_ms <= 0.0 and not world.startup_failed:
		await get_tree().process_frame
	var record: Dictionary = {"evidence_class": "INERT", "scope": "Technical views, support and matched cost of the mid-ground batch",
		"frames": _frames, "costs": _costs, "failures": _failures,
		"artistically_accepted": false, "human_played": false,
		"source": {"test_sha256": FileAccess.get_sha256(get_script().resource_path),
			"asset_sha256": FileAccess.get_sha256("res://assets/props/city_midground.glb")}}
	if _check(not world.startup_failed and world.player != null, "complete production city starts"):
		await get_tree().physics_frame
		await get_tree().physics_frame
		var mid = world.find_child("Midground", true, false)
		var city := world.get_node_or_null("CityShells") as Node3D
		var far = world.find_child("FarDistricts", true, false)
		if _check(mid != null and city != null and far != null, "mid ground, city shells and far districts are mounted"):
			var data: Dictionary = mid.get("data")
			record["counts"] = {"colliders": data.colliders.size(),
				"draws": mid.find_children("*", "GeometryInstance3D", true, false).size()}
			_check(not (mid.get("window_materials") as Array).is_empty(), "window optics are bound")
			await _review(output, world, city, far, mid, data, midnight)
	world.shutdown_for_tests()
	world.free()
	for drain: int in 8:
		await get_tree().process_frame
	record["status"] = "PASS" if _failures.is_empty() else "FAIL"
	var receipt := FileAccess.open(output.path_join("midground_review.json"), FileAccess.WRITE)
	if receipt != null:
		receipt.store_string(JSON.stringify(record, "\t") + "\n")
		receipt.close()
	print("MIDGROUND VIEW REVIEW: ", record.status, "; ", _frames.size(), " frames; ", _failures.size(), " failures")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _measure(mid, label: String) -> Dictionary:
	var viewport := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var result := {"view": label}
	for visible: bool in [true, false]:
		mid.visible = visible
		for settle: int in 12:
			await RenderingServer.frame_post_draw
		var gpu := 0.0
		var cpu := 0.0
		var draws := 0
		var primitives := 0
		for sample: int in 60:
			await RenderingServer.frame_post_draw
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
			draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			primitives = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		result["present" if visible else "hidden"] = {"gpu_ms": gpu / 60.0, "cpu_ms": cpu / 60.0, "draw_calls": draws, "primitives": primitives}
	mid.visible = true
	result["delta_gpu_ms"] = float(result.present.gpu_ms) - float(result.hidden.gpu_ms)
	result["delta_draw_calls"] = int(result.present.draw_calls) - int(result.hidden.draw_calls)
	print("MIDGROUND COST ", JSON.stringify(result))
	return result


func _review(output: String, world: OrisonV2RuntimeRoot, city: Node3D, far, mid, data: Dictionary, midnight: float) -> void:
	var views := _views(world, data)
	_view_only(data)
	views.append({"id": "roof_south", "eye": world.adapter.root.to_global(Vector3(-11.0, 20.8702503, 6.0)), "bearing": 180.0, "pitch": -0.05, "fov": 78.0})
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var snapshot: Dictionary = RealityState.data.campaign_clock.duplicate(true)
	var camera := Camera3D.new()
	add_child(camera)
	camera.cull_mask = world.player.camera.cull_mask
	camera.near = world.player.camera.near
	camera.far = world.player.camera.far
	camera.make_current()
	var projection := Temporal.new()
	add_child(projection)
	projection.world = world
	projection.camera = camera
	projection.director = world.day_night_director
	projection.manager = world.get_node("WakingAtmosphere").weather_manager
	projection._view_extreme = ExtremeWeather.new()
	projection._city = city
	projection._far_districts = far
	projection._midground = mid
	projection.age = Temporal.ROOF_START
	var original_clock: CampaignClock = projection.director._campaign_clock
	var original_extreme: RefCounted = projection.director.extreme_weather
	projection.director._campaign_clock = projection.view_clock
	projection.director.extreme_weather = projection._view_extreme
	var lamp_clocks := get_tree().get_nodes_in_group("v2_street_lamp_clocks")
	for time_id: String in TIMES:
		for view: Dictionary in views:
			var eye: Vector3 = view.eye
			if not eye.is_finite():
				continue
			projection.sampled_utc = midnight + float(TIMES[time_id]) * 60.0
			if not _check(projection.view_clock.seek_utc(projection.sampled_utc), "detached sample " + view.id):
				continue
			projection._optical_minute = INF
			for lamps in lamp_clocks:
				lamps.set("clock_override", projection.view_clock.day_info())
				lamps.call("refresh")
			camera.fov = float(view.fov)
			camera.global_position = eye
			var bearing := deg_to_rad(float(view.bearing))
			camera.look_at(camera.global_position + Vector3(sin(bearing), float(view.pitch), -cos(bearing)))
			projection._publish()
			mid.call("_follow_lamps")
			var minute: float = projection.view_clock.minute_of_day()
			var clock_matches := true
			for material: ShaderMaterial in mid.get("window_materials"):
				var loaded: Variant = material.get_shader_parameter("minute_of_day")
				clock_matches = clock_matches and loaded != null and is_equal_approx(float(loaded), minute)
			_check(clock_matches, "detached publish reaches the mid-ground windows " + view.id)
			for settle: int in 18:
				await RenderingServer.frame_post_draw
			_check(RealityState.data.campaign_clock == snapshot, "detached optics preserve the campaign clock")
			var filename := "%s_%s.png" % [view.id, time_id]
			var path := output.path_join(filename)
			if _check(get_viewport().get_texture().get_image().save_png(path) == OK, "save frame " + filename):
				_frames.append({"file": filename, "sha256": FileAccess.get_sha256(path), "eye": str(camera.global_position),
					"bearing": view.bearing, "fov": camera.fov, "minute": minute})
				print("MIDGROUND FRAME ", filename)
			if view.id == "roof_south" and time_id == "night":
				_costs.append(await _measure(mid, "roof_south_night"))
			if view.id == views[0].id and time_id == "day":
				_costs.append(await _measure(mid, view.id + "_day"))
	for lamps in lamp_clocks:
		lamps.set("clock_override", {})
	_check(_frames.size() == views.size() * TIMES.size(), "every view at every time")
	projection.director._campaign_clock = original_clock
	projection.director.extreme_weather = original_extreme
	world.player.camera.make_current()
	projection.free()
	camera.free()
