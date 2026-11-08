extends Node3D
## Technical optical fixture for the distant districts: the ten agreed city views at
## day, dusk and night, a paired present/hidden roof view, and matched render cost.
## No campaign, route or save authority; the gameplay clock is frozen and checked.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Temporal := preload("res://scripts/game/prologue_temporal_sky.gd")
const ExtremeWeather := preload("res://scripts/building/queens_weather_extension.gd")
const ROOF_EYE := Vector3(-11.0, 20.8702503, 6.0)
const UPPER_BRIDGE_WALK := Vector3(835.2276, 50.85201, -11.45)
const TELESCOPE_FLOOR := Vector3(14.0, 19.24025, -9.0)
const EAST_STREET_FLOOR := Vector3(280.0, -0.02, -10.0)
const TIMES := {"day": 720, "dusk": 1043, "night": 1150}

var _failures: Array[String] = []
var _frames: Array[Dictionary] = []
var _costs: Array[Dictionary] = []
var _pose_witnesses: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(passed: bool, label: String) -> bool:
	if not passed:
		_failures.append(label)
		push_error("FAR DISTRICTS: " + label)
	return passed


func _ground_eye(world: OrisonV2RuntimeRoot, nominal: Vector3, height := 1.62) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(nominal + Vector3.UP * 60.0, nominal - Vector3.UP * 60.0, 1,
		[world.player.get_rid()])
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return nominal + Vector3.UP * height
	return hit.position + Vector3.UP * height


func _witnessed_eye(world: OrisonV2RuntimeRoot, id: String, nominal: Vector3, floor_part: String,
		bearing: float, pitch: float, clear_distance := 0.0) -> Vector3:
	# The corrected stations are independently posed evidence. Require the
	# nominated solid support and an ordinary standing capsule on that support.
	var space := world.get_world_3d().direct_space_state
	var exclude: Array[RID] = [world.player.get_rid()]
	var ray := PhysicsRayQueryParameters3D.create(nominal + Vector3.UP * 0.25,
		nominal - Vector3.UP * 0.25, 1, exclude)
	var hit := space.intersect_ray(ray)
	if not _check(not hit.is_empty() and hit.collider is StaticBody3D, "actual support at " + id):
		return Vector3.INF
	var floor: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var owner := str(hit.collider.get_path())
	var witness := {"nominal_floor": str(nominal), "floor": str(floor), "owner": owner, "normal": str(normal)}
	_pose_witnesses[id] = witness
	if not _check(owner.contains(floor_part) and normal.dot(Vector3.UP) > 0.98
			and absf(floor.y - nominal.y) < 0.10, "named floor and expected elevation at " + id):
		return Vector3.INF
	var capsule := CapsuleShape3D.new()
	capsule.radius = PlayerController.BODY_RADIUS
	capsule.height = PlayerController.STANDING_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.margin = 0.0
	query.exclude = exclude
	query.transform = Transform3D(Basis.IDENTITY, floor + Vector3.UP * (0.03 + capsule.height * 0.5))
	var clear := space.intersect_shape(query, 1).is_empty()
	witness["standing_capsule_clear"] = clear
	if not _check(clear, "ordinary standing capsule clear at " + id):
		return Vector3.INF
	var eye := floor + Vector3.UP * PlayerController.STANDING_EYE
	witness["eye"] = str(eye)
	if clear_distance > 0.0:
		var optical_rays: Array[Dictionary] = []
		var passage_clear := true
		for offset: float in [-8.0, 0.0, 8.0]:
			var azimuth := deg_to_rad(bearing + offset)
			var direction := Vector3(sin(azimuth), pitch, -cos(azimuth)).normalized()
			var endpoint := eye + direction * clear_distance
			var optical := PhysicsRayQueryParameters3D.create(eye, endpoint, 1, exclude)
			var blocker := space.intersect_ray(optical)
			passage_clear = passage_clear and blocker.is_empty()
			optical_rays.append({"offset_deg": offset, "end": str(endpoint),
				"first_hit": "" if blocker.is_empty() else str(blocker.collider.get_path())})
		witness["near_optical_rays"] = optical_rays
		if not _check(passage_clear, "near view corridor clear at " + id):
			return Vector3.INF
	return eye


func _views(world: OrisonV2RuntimeRoot) -> Array[Dictionary]:
	var roof: Vector3 = world.adapter.root.to_global(ROOF_EYE)
	# Street, bridge, canal and rail eyes are world coordinates. The blockout and its
	# ground are turned 180 degrees (world = -x, y, -z - 11.65), so the canal bulkhead's
	# local (58, -326) and the rail sidings' local (-469, -40) are written in world terms.
	var east := _witnessed_eye(world, "street_east_end", EAST_STREET_FLOOR, "/DistantApron/", 90.0, 0.03, 36.0)
	var telescope := _witnessed_eye(world, "telescope", world.adapter.root.to_global(TELESCOPE_FLOOR),
		"/ROOF_DECK_SOUTH/Floor/Collision", 280.5, 0.035, 18.0)
	var bridge := world.get_node_or_null("CityShells/QueensboroBridge") as Node3D
	var deck := Vector3.INF
	var deck_bearing := 299.70833333333333
	if _check(bridge != null, "mounted bridge provides upper-walk station"):
		var west := -bridge.global_basis.x
		deck_bearing = fposmod(rad_to_deg(atan2(west.x, -west.z)), 360.0)
		deck = _witnessed_eye(world, "bridge_approach", bridge.to_global(UPPER_BRIDGE_WALK),
			"/QueensboroBridge/Bridge_13_L0__timber/", deck_bearing, 0.0)
	return [
		{"id": "roof_north", "eye": roof, "bearing": 0.0, "pitch": 0.06, "fov": 78.0},
		{"id": "roof_east", "eye": roof, "bearing": 90.0, "pitch": 0.06, "fov": 78.0},
		{"id": "roof_south", "eye": roof, "bearing": 180.0, "pitch": 0.06, "fov": 78.0},
		{"id": "roof_west", "eye": roof, "bearing": 285.0, "pitch": 0.06, "fov": 78.0},
		{"id": "street_west_end", "eye": _ground_eye(world, Vector3(-280.0, 0.0, -10.0)), "bearing": 280.0, "pitch": 0.03, "fov": 78.0},
		{"id": "street_east_end", "eye": east, "bearing": 90.0, "pitch": 0.03, "fov": 78.0},
		{"id": "bridge_approach", "eye": deck, "bearing": deck_bearing, "pitch": 0.0, "fov": 78.0},
		{"id": "canal", "eye": _ground_eye(world, Vector3(-58.0, 0.0, 316.0)), "bearing": 260.0, "pitch": 0.02, "fov": 78.0},
		{"id": "rail_cut", "eye": _ground_eye(world, Vector3(469.0, 0.0, 28.0)), "bearing": 350.0, "pitch": 0.03, "fov": 78.0},
		{"id": "telescope", "eye": telescope, "bearing": 280.5, "pitch": 0.035, "fov": 14.0},
	]


func _measure(far, label: String) -> Dictionary:
	var viewport := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var result := {"view": label}
	for visible: bool in [true, false]:
		far.visible = visible
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
		var key := "present" if visible else "hidden"
		result[key] = {"gpu_ms": gpu / 60.0, "cpu_ms": cpu / 60.0, "draw_calls": draws, "primitives": primitives}
	far.visible = true
	result["delta_gpu_ms"] = float(result.present.gpu_ms) - float(result.hidden.gpu_ms)
	result["delta_draw_calls"] = int(result.present.draw_calls) - int(result.hidden.draw_calls)
	print("FAR DISTRICTS COST ", JSON.stringify(result))
	return result


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
	var record: Dictionary = {"evidence_class": "INERT", "scope": "Technical views and matched render cost of the distant districts",
		"frames": _frames, "costs": _costs, "failures": _failures, "artistically_accepted": false, "human_played": false,
		"source": {"test_sha256": FileAccess.get_sha256(get_script().resource_path),
			"bridge_sha256": FileAccess.get_sha256("res://assets/props/city_bridge.glb")},
		"posed_view_support": _pose_witnesses}
	if _check(not world.startup_failed and world.player != null, "complete production city starts"):
		await get_tree().physics_frame
		var far = world.find_child("FarDistricts", true, false)
		var city := world.get_node_or_null("CityShells") as Node3D
		if _check(far != null and city != null, "far districts and city shells are mounted"):
			_check(not (far.get("facade_materials") as Array).is_empty(), "facade lamp materials are bound")
			var draws: Array = far.find_children("*", "MeshInstance3D", true, false)
			record["draws"] = draws.size()
			var children_ok := true
			for draw: MeshInstance3D in draws:
				children_ok = children_ok and draw.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
					and draw.find_children("*", "CollisionShape3D", true, false).is_empty()
			_check(children_ok, "every far draw is shadowless and has no collision")
			await _review(output, world, city, far, midnight)
	world.shutdown_for_tests()
	world.free()
	for drain: int in 8:
		await get_tree().process_frame
	record["status"] = "PASS" if _failures.is_empty() else "FAIL"
	var receipt := FileAccess.open(output.path_join("far_district_review.json"), FileAccess.WRITE)
	if receipt != null:
		receipt.store_string(JSON.stringify(record, "\t") + "\n")
		receipt.close()
	print("FAR DISTRICTS VIEW REVIEW: ", record.status, "; ", _frames.size(), " frames; ", _failures.size(), " failures")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _review(output: String, world: OrisonV2RuntimeRoot, city: Node3D, far, midnight: float) -> void:
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var views := _views(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var snapshot: Dictionary = RealityState.data.campaign_clock.duplicate(true)
	var camera := Camera3D.new()
	add_child(camera)
	camera.cull_mask = world.player.camera.cull_mask
	camera.near = world.player.camera.near
	camera.far = world.player.camera.far
	camera.keep_aspect = world.player.camera.keep_aspect
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
	projection.age = Temporal.ROOF_START
	var original_clock: CampaignClock = projection.director._campaign_clock
	var original_extreme: RefCounted = projection.director.extreme_weather
	projection.director._campaign_clock = projection.view_clock
	projection.director.extreme_weather = projection._view_extreme
	for time_id: String in TIMES:
		for view: Dictionary in views:
			var eye: Vector3 = view.eye
			if not eye.is_finite():
				continue
			projection.sampled_utc = midnight + float(TIMES[time_id]) * 60.0
			if not _check(projection.view_clock.seek_utc(projection.sampled_utc), "detached sample " + view.id):
				continue
			projection._optical_minute = INF
			camera.fov = float(view.fov)
			camera.global_position = eye
			var bearing := deg_to_rad(float(view.bearing))
			camera.look_at(camera.global_position + Vector3(sin(bearing), float(view.pitch), -cos(bearing)))
			var posed := camera.global_transform
			projection._publish()
			var minute: float = projection.view_clock.minute_of_day()
			var materials: Array = far.get("facade_materials")
			var clock_matches := not materials.is_empty()
			for material: ShaderMaterial in materials:
				var loaded_minute: Variant = material.get_shader_parameter("minute_of_day")
				clock_matches = clock_matches and loaded_minute != null and is_equal_approx(float(loaded_minute), minute)
			_check(clock_matches, "detached publish reaches loaded facades " + view.id)
			for settle: int in 18:
				await RenderingServer.frame_post_draw
			_check(RealityState.data.campaign_clock == snapshot, "detached optics preserve the campaign clock")
			if _pose_witnesses.has(view.id):
				_check(camera.is_current() and camera.global_transform.is_equal_approx(posed),
					"actual camera retained the witnessed pose " + view.id)
			var filename := "%s_%s.png" % [view.id, time_id]
			var frame := get_viewport().get_texture().get_image()
			var path := output.path_join(filename)
			if _check(frame.save_png(path) == OK, "save frame " + filename):
				_frames.append({"file": filename, "sha256": FileAccess.get_sha256(path), "eye": str(camera.global_position),
					"bearing": view.bearing, "pitch": view.pitch, "basis": str(camera.global_basis), "fov": camera.fov,
					"facade_minute": minute if clock_matches else null, "utc": projection.view_clock.utc_datetime()})
				print("FAR DISTRICTS FRAME ", filename)
			if view.id in ["roof_west", "roof_east"] and time_id == "night":
				_costs.append(await _measure(far, view.id + "_night"))
				far.visible = false
				for settle: int in 12:
					await RenderingServer.frame_post_draw
				var hidden := get_viewport().get_texture().get_image()
				hidden.save_png(output.path_join("%s_%s_hidden.png" % [view.id, time_id]))
				far.visible = true
	_check(_frames.size() == 30, "ten views at three times are complete")
	projection.director._campaign_clock = original_clock
	projection.director.extreme_weather = original_extreme
	world.player.camera.make_current()
	projection.free()
	camera.free()
