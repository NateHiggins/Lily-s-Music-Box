extends Node3D
## Technical review fixture for the city greenery batch (build_city_greenery.py): street
## views of the planted kerbs at day and night, one street through the year, a trunk
## the player stands against, matched render cost with the greenery present and hidden,
## and the owner's build time. No campaign, route or save authority; the gameplay clock
## is frozen and checked.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Temporal := preload("res://scripts/game/prologue_temporal_sky.gd")
const ExtremeWeather := preload("res://scripts/building/queens_weather_extension.gd")
const Greenery := preload("res://scripts/building/orison_v2_city_greenery.gd")
const TIMES := {"day": 720, "night": 1150}

var _failures: Array[String] = []
var _frames: Array[Dictionary] = []
var _costs: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(passed: bool, label: String) -> bool:
	if not passed:
		_failures.append(label)
		push_error("GREENERY: " + label)
	return passed


func _floor_eye(world: OrisonV2RuntimeRoot, nominal: Vector3) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(nominal + Vector3.UP * 80.0, nominal - Vector3.UP * 20.0, 1,
		[world.player.get_rid()]))
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.9 or hit.position.y > 6.0:
		return Vector3.INF
	return hit.position + Vector3.UP * PlayerController.STANDING_EYE


func _views(world: OrisonV2RuntimeRoot) -> Array[Dictionary]:
	var views: Array[Dictionary] = []
	for spec: Array in [["avenue_west", Vector3(-100.0, 0.0, 9.5), 270.0, 0.02, 70.0],
			["avenue_east", Vector3(-40.0, 0.0, 9.5), 90.0, 0.02, 70.0],
			["cross_west", Vector3(-142.9, 0.0, 40.0), 0.0, 0.03, 70.0],
			["cross_east", Vector3(142.9, 0.0, -30.0), 180.0, 0.03, 70.0],
			["midground_south", Vector3(0.0, 0.0, 160.0), 180.0, 0.05, 70.0]]:
		var eye := Vector3.INF
		for nudge: Vector3 in [Vector3.ZERO, Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2)]:
			eye = _floor_eye(world, spec[1] + nudge)
			if eye.is_finite():
				break
		if _check(eye.is_finite(), "a street standing point for " + str(spec[0])):
			views.append({"id": spec[0], "eye": eye, "bearing": spec[2], "pitch": spec[3], "fov": spec[4]})
	views.append({"id": "roof_south", "eye": world.adapter.root.to_global(Vector3(-11.0, 20.8702503, 6.0)),
		"bearing": 0.0, "pitch": -0.18, "fov": 78.0})
	return views


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
	_check(clock.configure_date(1929, 7, 12, 0), "isolated fixture date initialised once")
	var midnight := float(Time.get_unix_time_from_datetime_dict(clock.utc_datetime()))
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	while world.startup_ms <= 0.0 and not world.startup_failed:
		await get_tree().process_frame
	var record: Dictionary = {"evidence_class": "INERT", "scope": "Technical views, support and matched cost of the city greenery batch",
		"frames": _frames, "costs": _costs, "failures": _failures,
		"artistically_accepted": false, "human_played": false,
		"source": {"test_sha256": FileAccess.get_sha256(get_script().resource_path),
			"asset_sha256": FileAccess.get_sha256("res://assets/props/city_greenery.glb"),
			"data_sha256": FileAccess.get_sha256(Greenery.DATA)}}
	if _check(not world.startup_failed and world.player != null, "complete production city starts"):
		await get_tree().physics_frame
		await get_tree().physics_frame
		var green := world.find_child("CityGreenery", true, false)
		var city := world.get_node_or_null("CityShells") as Node3D
		if _check(green != null and city != null, "greenery and city shells are mounted"):
			var data: Dictionary = green.get("data")
			var expected := 0
			for kind: String in data.kinds:
				expected += (data.kinds[kind] as Array).size()
			_check(int(green.get("instance_count")) == expected, "every planted record is drawn")
			_check(int(green.get("collider_count")) == (data.colliders as Array).size(), "every reachable trunk has a collider")
			record["counts"] = {"instances": expected, "draws": int(green.get("draw_count")), "colliders": int(green.get("collider_count")),
				"by_kind": data.kinds.keys().map(func(k): return [k, (data.kinds[k] as Array).size()])}
			# The owner's own build cost, rebuilt detached.
			var started := Time.get_ticks_usec()
			var probe: Node3D = Greenery.new()
			add_child(probe)
			record["build_ms"] = (Time.get_ticks_usec() - started) / 1000.0
			probe.free()
			_support(world, data)
			await _review(output, world, city, green, midnight)
	world.shutdown_for_tests()
	world.free()
	for drain: int in 8:
		await get_tree().process_frame
	record["status"] = "PASS" if _failures.is_empty() else "FAIL"
	var receipt := FileAccess.open(output.path_join("greenery_review.json"), FileAccess.WRITE)
	if receipt != null:
		receipt.store_string(JSON.stringify(record, "\t") + "\n")
		receipt.close()
	print("GREENERY REVIEW: ", record.status, "; ", _frames.size(), " frames; ", _failures.size(), " failures; build_ms=", record.get("build_ms", -1))
	get_tree().quit(0 if _failures.is_empty() else 1)


## A trunk stops a walker; nothing is planted outside the walkable edge with collision.
func _support(world: OrisonV2RuntimeRoot, data: Dictionary) -> void:
	var space := world.get_world_3d().direct_space_state
	var stopped := 0
	var tried := 0
	for record: Array in data.colliders:
		if float(record[3]) < 0.4:
			continue
		var at := Vector3(record[0], float(record[1]) + 1.0, record[2])
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3(2.0, 0, 0), at, 0xFFFFFFFF, [world.player.get_rid()])
		var hit := space.intersect_ray(ray)
		tried += 1
		if not hit.is_empty() and hit.position.distance_to(at) <= float(record[3]) + 0.05:
			stopped += 1
		if tried >= 20:
			break
		_check(Vector2(record[0], record[2]).length() < 216.0, "trunk collision only inside the walkable edge")
	_check(tried > 0 and stopped == tried, "a walker meets each trunk (%d of %d)" % [stopped, tried])


func _measure(green: Node3D, label: String) -> Dictionary:
	var viewport := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var result := {"view": label}
	for visible: bool in [true, false, true]:
		green.visible = visible
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
		var key := "hidden" if not visible else ("present_again" if result.has("present") else "present")
		result[key] = {"gpu_ms": gpu / 60.0, "cpu_ms": cpu / 60.0, "draw_calls": draws, "primitives": primitives}
	green.visible = true
	result["delta_gpu_ms"] = float(result.present.gpu_ms) - float(result.hidden.gpu_ms)
	result["delta_draw_calls"] = int(result.present.draw_calls) - int(result.hidden.draw_calls)
	result["delta_primitives"] = int(result.present.primitives) - int(result.hidden.primitives)
	print("GREENERY COST ", JSON.stringify(result))
	return result


func _review(output: String, world: OrisonV2RuntimeRoot, city: Node3D, green: Node3D, midnight: float) -> void:
	var views := _views(world)
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
	projection._far_districts = world.find_child("FarDistricts", true, false)
	projection._midground = world.find_child("Midground", true, false)
	projection.age = Temporal.ROOF_START
	var original_clock: CampaignClock = projection.director._campaign_clock
	var original_extreme: RefCounted = projection.director.extreme_weather
	projection.director._campaign_clock = projection.view_clock
	projection.director.extreme_weather = projection._view_extreme
	var lamp_clocks := get_tree().get_nodes_in_group("v2_street_lamp_clocks")
	var shots: Array[Array] = []
	for view: Dictionary in views:
		for time_id: String in TIMES:
			if time_id == "night" and not (view.id in ["avenue_west", "roof_south"]):
				continue
			shots.append([view, time_id, 7])
	for season: int in [4, 10, 1]:
		shots.append([views[mini(2, views.size() - 1)], "day", season])
	for shot: Array in shots:
		var view: Dictionary = shot[0]
		var time_id: String = shot[1]
		var month: int = shot[2]
		green.set("month_override", month)
		green.call("_refresh", true)
		projection.sampled_utc = midnight + float(TIMES[time_id]) * 60.0
		if not _check(projection.view_clock.seek_utc(projection.sampled_utc), "detached sample " + view.id):
			continue
		projection._optical_minute = INF
		for lamps in lamp_clocks:
			lamps.set("clock_override", projection.view_clock.day_info())
			lamps.call("refresh")
		camera.fov = float(view.fov)
		camera.global_position = view.eye
		var bearing := deg_to_rad(float(view.bearing))
		camera.look_at(camera.global_position + Vector3(sin(bearing), float(view.pitch), -cos(bearing)))
		projection._publish()
		for settle: int in 18:
			await RenderingServer.frame_post_draw
		_check(RealityState.data.campaign_clock == snapshot, "detached optics preserve the campaign clock")
		var filename := "%s_%s_m%02d.png" % [view.id, time_id, month]
		var path := output.path_join(filename)
		if _check(get_viewport().get_texture().get_image().save_png(path) == OK, "save frame " + filename):
			_frames.append({"file": filename, "sha256": FileAccess.get_sha256(path), "eye": str(camera.global_position),
				"bearing": view.bearing, "fov": camera.fov, "month": month})
			print("GREENERY FRAME ", filename)
		if month == 7 and time_id == "day" and view.id in ["avenue_west", "cross_west", "roof_south"]:
			_costs.append(await _measure(green, view.id + "_day"))
	green.set("month_override", 0)
	for lamps in lamp_clocks:
		lamps.set("clock_override", {})
	_check(_frames.size() == shots.size(), "every shot taken")
	projection.director._campaign_clock = original_clock
	projection.director.extreme_weather = original_extreme
	world.player.camera.make_current()
	projection.free()
	camera.free()
