extends Node
## The V2 performance matrix: startup, frame time, draw calls and memory at
## named stations of the composed V2 world, with the real player, the real
## renderer and vsync off.
##
## Measurement only. It judges nothing: tools/v2_performance_matrix.py holds
## the budgets and writes the receipt the gate board reads. Needs a real
## window (the headless renderer draws no frames), so it runs -Windowed on
## the hidden desktop through the lane.
##
##   SHOT_DIR                 where performance_matrix.json is written
##   ORISON_PERF_STATION      measure one station by name
##
## Each station is measured at four headings a quarter turn apart, so a wall
## in front of the lens cannot make a station look cheap.

const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const SCHEMA := "orison.v2-performance-samples.v1"
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 120
const HEADINGS := 4
const SETTLE_SECONDS := 20.0
const EYE_NOTE := "the player's own camera at the player's own eye height"

## "local" is in the building's frame (the adapter root), "passage" in the
## passage region's frame; "anchor" is a named node the adapter resolves;
## "arrival" is where the campaign sets the player down on the street.
const STATIONS := [
	{"name": "street_arrival", "arrival": true},
	{"name": "lobby", "local": Vector3(1.925, 0.02, -3.5)},
	{"name": "main_stair_first_flight", "local": Vector3(1.925, 1.62, 1.3)},
	{"name": "second_floor_landing", "local": Vector3(3.975, 3.22, -3.4)},
	{"name": "third_floor_crossing", "local": Vector3(8.85, 6.42, -3.25)},
	{"name": "fourth_floor_service_hall", "local": Vector3(8.9, 9.62, -1.0)},
	{"name": "flat_4b_desk", "anchor": "F04_B_MONITOR_STANCE"},
	{"name": "sixth_floor_landing", "local": Vector3(3.975, 16.02, -3.4)},
	{"name": "roof_deck", "local": Vector3(8.2, 19.22, 3.0)},
	{"name": "basement_landing", "local": Vector3(1.925, -3.18, -3.5)},
	{"name": "passage_nave", "passage": Vector3(14.0, 0.02, 32.0)},
]

var world: OrisonV2RuntimeRoot
var player: PlayerController
var failures: Array[String] = []
var _frame_usec: PackedInt64Array = []
var _sampling := false
var _last_usec := 0
var _cpu_ms: PackedFloat64Array = []
var _gpu_ms: PackedFloat64Array = []
var _viewport_rid: RID


func _ready() -> void:
	_run.call_deferred()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _sampling and _last_usec > 0:
		_frame_usec.append(now - _last_usec)
		_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid))
		_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid))
	_last_usec = now


func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 20 * 60)
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_viewport_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)

	var started := Time.get_ticks_usec()
	world = Runtime.instantiate()
	add_child(world)
	while world.startup_ms <= 0.0 and not world.startup_failed:
		await get_tree().process_frame
	var startup_wall_ms := float(Time.get_ticks_usec() - started) / 1000.0
	if world.startup_failed:
		failures.append("the V2 world did not start")
		_write({"startup_ms": 0.0, "startup_wall_ms": startup_wall_ms}, [])
		_leave()
		return
	player = world.player
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The first frames after startup still compile pipelines and settle the
	# opening; they are startup cost, reported apart from the stations.
	var first_frame_ms := await _first_frames()

	var only := OS.get_environment("ORISON_PERF_STATION")
	var rows: Array[Dictionary] = []
	for station: Dictionary in STATIONS:
		if not only.is_empty() and str(station.name) != only:
			continue
		rows.append(await _measure(station))
	if rows.is_empty():
		failures.append("no station matched ORISON_PERF_STATION=%s" % only)
	_write({"startup_ms": world.startup_ms, "startup_wall_ms": startup_wall_ms,
		"first_frames_ms": first_frame_ms, "startup_memory": _memory()}, rows)
	_leave()


func _first_frames() -> Array:
	var times: Array = []
	var before := Time.get_ticks_usec()
	for i in 10:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append(snappedf(float(now - before) / 1000.0, 0.01))
		before = now
	return times


func _place(station: Dictionary) -> Dictionary:
	var at := Vector3.ZERO
	var frame := "world"
	if station.has("arrival"):
		at = world.arrival_placement().get("position", Vector3.ZERO)
		frame = "arrival"
	elif station.has("anchor"):
		var node := world.adapter.resolve(str(station.anchor)) as Node3D
		if node == null:
			return {"ok": false, "why": "anchor %s does not resolve" % station.anchor}
		at = node.global_position + Vector3.UP * 0.05
		frame = "anchor " + str(station.anchor)
	elif station.has("passage"):
		at = (world.passage_region as Node3D).to_global(station.passage)
		frame = "passage"
	else:
		at = (world.adapter.root as Node3D).to_global(station.local)
		frame = "building"
	player.velocity = Vector3.ZERO
	player.global_position = at
	return {"ok": true, "position": at, "frame": frame}


## Streaming must be at rest before a station counts: a load in flight is a
## hitch, not the station's steady cost.
func _settle() -> bool:
	var residency: Node = world.passage_region.residency
	var deadline := Time.get_ticks_msec() + int(SETTLE_SECONDS * 1000.0)
	var calm := 0
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		calm = calm + 1 if str(residency.state) != "LOADING" else 0
		if calm >= 30:
			return true
	return false


func _measure(station: Dictionary) -> Dictionary:
	var placed := _place(station)
	var row := {"name": str(station.name)}
	if not placed.ok:
		failures.append("%s: %s" % [station.name, placed.why])
		row["valid"] = false
		row["why"] = placed.why
		return row
	await get_tree().physics_frame
	await get_tree().physics_frame
	var settled := await _settle()
	if not settled:
		failures.append("%s: streaming did not settle in %.0f s" % [station.name, SETTLE_SECONDS])
	# Hold the station: the opening and gravity may move the player; the
	# matrix measures the place, so the body is put back before each heading.
	var headings: Array[Dictionary] = []
	for index in HEADINGS:
		player.velocity = Vector3.ZERO
		player.global_position = placed.position
		player.rotation.y = TAU * float(index) / float(HEADINGS)
		for i in WARMUP_FRAMES:
			await get_tree().process_frame
		_frame_usec = PackedInt64Array()
		_cpu_ms = PackedFloat64Array()
		_gpu_ms = PackedFloat64Array()
		_last_usec = 0
		_sampling = true
		var calls := 0.0
		var primitives := 0.0
		var objects := 0.0
		for i in SAMPLE_FRAMES:
			await get_tree().process_frame
			calls = maxf(calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			primitives = maxf(primitives, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			objects = maxf(objects, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		_sampling = false
		var wall := _summary_usec(_frame_usec)
		headings.append({
			"yaw_degrees": 360.0 * float(index) / float(HEADINGS),
			"frames": _frame_usec.size(),
			"wall_ms_median": wall.median, "wall_ms_p95": wall.p95, "wall_ms_max": wall.maximum,
			"render_cpu_ms_median": _median(_cpu_ms), "render_gpu_ms_median": _median(_gpu_ms),
			"draw_calls": int(calls), "primitives": int(primitives), "objects": int(objects),
		})
	var worst: Dictionary = headings[0]
	for heading: Dictionary in headings:
		if float(heading.wall_ms_median) > float(worst.wall_ms_median):
			worst = heading
	row.merge({
		"valid": settled, "frame": placed.frame,
		"position": [snappedf(placed.position.x, 0.001), snappedf(placed.position.y, 0.001), snappedf(placed.position.z, 0.001)],
		"drift_m": snappedf(player.global_position.distance_to(placed.position), 0.001),
		"room": world.room_at_world(player.global_position),
		"passage_residency": str(world.passage_region.residency.state),
		"worst_heading": worst, "headings": headings, "memory": _memory(),
	})
	print("[V2 PERF] %-26s %6.2f ms median  %6.2f p95  %5d calls  %8d prims  gpu %5.2f ms  (%s)" % [
		row.name, worst.wall_ms_median, worst.wall_ms_p95, worst.draw_calls, worst.primitives,
		worst.render_gpu_ms_median, row.passage_residency])
	return row


func _summary_usec(values: PackedInt64Array) -> Dictionary:
	if values.is_empty():
		return {"median": 0.0, "p95": 0.0, "maximum": 0.0}
	var sorted := Array(values)
	sorted.sort()
	return {
		"median": snappedf(float(sorted[sorted.size() / 2]) / 1000.0, 0.001),
		"p95": snappedf(float(sorted[mini(sorted.size() - 1, int(ceil(sorted.size() * 0.95)) - 1)]) / 1000.0, 0.001),
		"maximum": snappedf(float(sorted[-1]) / 1000.0, 0.001),
	}


func _median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := Array(values)
	sorted.sort()
	return snappedf(float(sorted[sorted.size() / 2]), 0.001)


func _memory() -> Dictionary:
	return {
		"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"static_peak_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
		"video_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"texture_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buffer_bytes": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
	}


func _write(startup: Dictionary, rows: Array) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty():
		failures.append("SHOT_DIR is not set; nothing was written")
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var size := get_viewport().get_visible_rect().size
	var record := {
		"schema": SCHEMA,
		"scope": "Stationary cost at named stations, four headings each, campaign frozen at 20:00 on 10 Nov 1928, weather network off. Not a walk, not a cold shader cache, not the dream.",
		"lens": EYE_NOTE,
		"resolution": [int(size.x), int(size.y)],
		"vsync": false, "max_fps": Engine.max_fps,
		"display_server": DisplayServer.get_name(),
		"engine": Engine.get_version_info().get("string", ""),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"msaa_3d": get_viewport().msaa_3d, "taa": get_viewport().use_taa,
		"scaling_3d_scale": get_viewport().scaling_3d_scale,
		"warmup_frames": WARMUP_FRAMES, "sample_frames": SAMPLE_FRAMES, "headings": HEADINGS,
		"counter_limits": "Wall time is the interval between process frames with vsync off. Render CPU and GPU times are the main viewport only. Draw calls, primitives and objects are the frame's whole total, taken as the largest seen while sampling.",
		"startup": startup, "stations": rows, "failures": failures,
	}
	var file := FileAccess.open(directory.path_join("performance_matrix.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
	file.close()


func _leave() -> void:
	print("[V2 PERF] RESULT: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	for line in failures:
		print("  [FAIL] ", line)
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
