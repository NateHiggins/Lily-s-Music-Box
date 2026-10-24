extends Node
## INERT review capture of the V2 period traffic (design/V2_PERIOD_TRAFFIC_2026-10-24.md).
## Windowed only. Boots the production V2 world, checks the stream's owner and
## finishes, lets the live stream run, then stages fixed street scenes for
## review captures. Not runtime proof and no acceptance grant.
const Selector := preload("res://scripts/building/building_root_selector.gd")
var directory: String
var world: OrisonV2RuntimeRoot
var failures := 0
var summary := {"checks": [], "captures": [], "draw_calls": {}}


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	summary.checks.append({"label": label, "ok": ok})
	print("PERIOD TRAFFIC CHECK: ", label, " = ", ok)


func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless" \
			or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Period traffic review requires windowed capture and SHOT_DIR")
		get_tree().quit(1)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928, 11, 20, 1260)
	Selector.reset_for_tests("v2")
	world = (load(Selector.scene_path()) as PackedScene).instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if world.startup_failed:
		push_error("Production world failed")
		get_tree().quit(1)
		return
	await _review()
	var file := FileAccess.open(directory.path_join("period_traffic_review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, " ", false) + "\n")
	file.close()
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	CampaignTime.set_frozen_for_tests(false)
	print("PERIOD TRAFFIC REVIEW: %d failures; no acceptance grant" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _review() -> void:
	var traffic := world.period_traffic as OrisonV2StreetTraffic
	check(traffic != null and traffic.is_inside_tree() and not traffic.startup_failed,
			"production V2 composes the period traffic owner")
	if traffic == null:
		return
	check(traffic.get_parent() == world.exterior_cell.instance_node("STREET_ORISON_01"),
			"traffic lives in the authored street frame")
	check(not traffic.live_kinds().is_empty(), "the street starts already in use")
	var finishes_ok := true
	for node: MultiMeshInstance3D in traffic.find_children("Traffic_*", "MultiMeshInstance3D", false, false):
		var mesh := node.multimesh.mesh
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface) as StandardMaterial3D
			var arrays := mesh.surface_get_arrays(surface)
			var ok := mat != null and not mat.uv1_triplanar and mat.albedo_texture != null \
					and mat.normal_texture != null and mat.roughness_texture != null \
					and mat.normal_enabled and arrays[Mesh.ARRAY_TEX_UV] != null \
					and mat.albedo_texture.get_image().has_mipmaps()
			if not ok:
				finishes_ok = false
				print("  finish defect: ", node.name, " surface ", surface)
	check(finishes_ok, "every traffic surface samples authored UVs with catalogue albedo, normal and roughness maps and mips")
	var lane_z := float(traffic.data.site.lane_west_z)
	check(traffic.blocks_sleep_entry(traffic.to_global(Vector3(0, 0, lane_z)))
			and not traffic.blocks_sleep_entry(traffic.to_global(Vector3(0, 0, 2.5))),
			"the carriageway, not the pavement, refuses sleep")

	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for canvas: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		canvas.hide()
	var camera := world.player.camera
	camera.make_current()

	# Yield: a person standing in the west lane stops the next vehicle short.
	traffic.stage([{"id": "ice_wagon", "lane_west": true, "x": 12.0, "speed": 3.0}])
	traffic.warnings.clear()
	traffic.frozen = false
	var keep := world.player.global_position
	world.player.global_position = traffic.to_global(Vector3(2.0, 0.0, lane_z))
	for i in 240:
		await get_tree().process_frame
	var wagon: Dictionary = traffic._live[0] if not traffic._live.is_empty() else {}
	check(not wagon.is_empty() and float(wagon.speed) < 0.2, "a horse wagon stops for a person in its lane")
	var clearance := -1.0
	if not wagon.is_empty():
		# Westbound progress runs along -x: the person stands at p = -2.
		clearance = -2.0 - OrisonV2StreetTraffic.PLAYER_RADIUS 				- (float(wagon.p) + float(traffic._kinds[int(wagon.kind)].extent[1]))
	summary["yield_clearance_m"] = clearance
	summary["yield_warnings"] = traffic.warnings.map(func(w): return w.cue)
	summary["yield_detail"] = traffic.warnings.duplicate(true)
	check(clearance >= 0.0 and clearance < 3.0, "and stops short of them rather than through them")
	# The windowed world runs slowly, so the wait spans many simulated seconds:
	# judge the alarm (sounded while moving) and the courtesy cap, not a count.
	var alarms: Array = summary.yield_detail.filter(func(w): return float(w.speed) > 0.5)
	check(alarms.size() == 1 and alarms[0].cue == "traffic.whip_crack" and summary.yield_detail.size() <= 3,
			"the teamster's whip cracks once as the horse is pulled up; at most two courtesy notes follow")
	world.player.global_position = keep

	# Live stream for review: let it run, capture what is actually there.
	traffic.stage([])
	traffic.frozen = false
	for i in 900:
		await get_tree().process_frame
	check(not traffic.live_kinds().is_empty(), "the live stream keeps the street populated")
	summary["live_kinds"] = traffic.live_kinds()
	await _view(traffic, "live_east", Vector3(-6.0, 1.62, 3.4), Vector3(12.0, 1.0, 10.0))

	traffic.stage([
		{"id": "ice_wagon", "lane_west": true, "x": 4.0, "travel": 0.4},
		{"id": "model_a_tudor", "lane_west": true, "x": 13.5, "paint": 1},
		{"id": "checker_cab", "lane_west": false, "x": 1.0},
		{"id": "coal_cart", "lane_west": false, "x": -9.0, "travel": 1.1},
		{"id": "saloon_bus", "lane_west": false, "x": 12.5},
	])
	await _view(traffic, "street_east", Vector3(-6.0, 1.62, 3.4), Vector3(12.0, 1.0, 10.0))
	await _measure(traffic, "street_east")
	traffic.stage([
		{"id": "sound_wagon", "lane_west": true, "x": -2.0},
		{"id": "valve_wagon", "lane_west": true, "x": 7.5, "travel": 0.9},
		{"id": "line_truck", "lane_west": false, "x": -8.5},
		{"id": "milk_wagon_riderless", "lane_west": false, "x": 2.5, "coat": 2},
		{"id": "broadcast_car", "lane_west": false, "x": 12.0},
	])
	await _view(traffic, "signal_traffic", Vector3(-9.0, 1.62, 3.6), Vector3(6.0, 1.2, 10.0))
	traffic.stage([
		{"id": "mack_ac", "lane_west": true, "x": 9.0},
		{"id": "model_t_touring", "lane_west": true, "x": 1.5},
		{"id": "motorcycle", "lane_west": false, "x": 3.0},
		{"id": "aa_stake", "lane_west": false, "x": -5.0, "paint": 2},
		{"id": "milk_wagon", "lane_west": false, "x": 10.0, "travel": 0.3},
	])
	await _view(traffic, "street_west", Vector3(16.0, 1.62, 3.4), Vector3(-2.0, 1.0, 10.0))
	await _view(traffic, "from_arcade_kerb", Vector3(6.0, 1.62, 15.4), Vector3(4.0, 1.0, 6.0))
	# Hand signals: left arm out to turn left, raised to turn right, down to stop.
	traffic.stage([
		{"id": "model_a_tudor", "lane_west": true, "x": 2.0, "hand": "left"},
		{"id": "checker_cab", "lane_west": true, "x": 9.0, "hand": "right", "paint": 1},
		{"id": "ice_wagon", "lane_west": true, "x": -6.0, "hand": "stop"},
	])
	# Drivers signal with the left arm, toward the crown of the road: watch from the far kerb.
	await _view(traffic, "hand_signals", Vector3(4.0, 1.62, 15.2), Vector3(-1.0, 1.5, 7.6))
	# Seen from the road: a cab braking hard for the player standing in its lane.
	traffic.stage([{"id": "checker_cab", "lane_west": false, "x": -19.0, "speed": 10.0}])
	traffic.warnings.clear()
	world.player.global_position = traffic.to_global(Vector3(0.0, 0.0, float(traffic.data.site.lane_east_z)))
	traffic.frozen = false
	for i in 150:
		await get_tree().process_frame
	traffic.frozen = true
	summary["hard_stop_warnings"] = traffic.warnings.map(func(w): return w.cue)
	summary["hard_stop_detail"] = traffic.warnings.duplicate(true)
	var scare: Array = summary.hard_stop_detail.filter(func(w): return float(w.speed) > 0.5)
	check(scare.map(func(w): return w.cue) == ["traffic.klaxon", "traffic.brake_shriek"] and summary.hard_stop_detail.size() <= 4,
			"a cab sounds its Klaxon once and shrieks to a stop for the player; at most two courtesy notes follow")
	await _view(traffic, "hard_stop_from_the_road", Vector3(0.0, 1.62, float(traffic.data.site.lane_east_z)),
			Vector3(-8.0, 1.2, float(traffic.data.site.lane_east_z)))
	world.player.global_position = keep
	# The middle distance: the block ends at a T with its own traffic both ways.
	traffic.stage([])
	traffic.frozen = false
	traffic.clock_override = {"valid": true, "day": "tue", "month": 11, "day_of_month": 20, "year": 1928, "minute_of_day": 1050.0}
	traffic._read_clock()
	for i in 1200:
		await get_tree().process_frame
	summary["cross_live"] = traffic.cross_count()
	check(traffic.cross_count() > 0, "the cross streets carry traffic in the middle distance")
	var junctions: Dictionary = traffic.data.junctions
	await _view(traffic, "toward_east_t", Vector3(17.5, 1.62, 9.5), Vector3(float(junctions.east_x), 1.4, float(junctions.center_z)))
	await _view(traffic, "toward_west_t", Vector3(-17.5, 1.62, 9.5), Vector3(float(junctions.west_x), 1.4, float(junctions.center_z)))
	traffic.frozen = false


func _view(traffic: Node3D, label: String, at: Vector3, target: Vector3) -> void:
	var camera := world.player.camera
	camera.global_position = traffic.to_global(at)
	camera.look_at(traffic.to_global(target))
	for i in 8:
		await RenderingServer.frame_post_draw
	var path := directory.path_join(label + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	summary.captures.append(label + ".png")


func _measure(traffic: Node3D, label: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	var with_traffic := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	traffic.visible = false
	for i in 4:
		await RenderingServer.frame_post_draw
	var without := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	traffic.visible = true
	summary.draw_calls[label] = {"with_traffic": with_traffic, "without": without}
	print("PERIOD TRAFFIC DRAWS: ", label, " with ", with_traffic, " without ", without)
