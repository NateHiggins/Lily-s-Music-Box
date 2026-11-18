extends Node
## INERT review capture of the trolley line (design/V2_STREET_TRAMS_2026-11-08.md). Windowed only. Boots the
## production V2 world, checks the line is mounted with its overhead raised, poses a car on each track, holds one
## arc lit, and captures the avenue by day and by night. Not runtime proof and no acceptance grant.
const Selector := preload("res://scripts/building/building_root_selector.gd")
var directory: String
var world: OrisonV2RuntimeRoot
var failures := 0
var summary := {"checks": [], "captures": []}


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	summary.checks.append({"label": label, "ok": ok})
	print("TRAM SHOT CHECK: ", label, " = ", ok)


func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless" or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Tram review requires windowed capture and SHOT_DIR")
		get_tree().quit(1)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1929, 11, 8, 900)
	Selector.reset_for_tests("v2")
	world = (load(Selector.scene_path()) as PackedScene).instantiate()
	add_child(world)
	for i in 4:
		await get_tree().physics_frame
	if world.startup_failed:
		push_error("Production world failed")
		get_tree().quit(1)
		return
	await _review()
	var file := FileAccess.open(directory.path_join("street_trams_review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, " ", false) + "\n")
	file.close()
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	CampaignTime.set_frozen_for_tests(false)
	print("STREET TRAMS REVIEW: %d failures; no acceptance grant" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _review() -> void:
	var traffic := world.period_traffic as OrisonV2StreetTraffic
	check(traffic != null, "the production world mounts the period traffic")
	if traffic == null:
		return
	var line := traffic.rail as OrisonV2StreetTrams
	check(line != null and line.is_inside_tree(), "and the trolley line with it")
	if line == null:
		return
	for i in 6:
		await get_tree().physics_frame
	check(line.built, "the overhead is raised in the world")
	var street := line.get_parent() as Node3D
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for canvas: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		canvas.hide()
	world.player.camera.make_current()
	# The companion's device hangs in front of the eye; keep it out of the frames (as open_shift_evidence_shot).
	if world.service_set_carrier != null:
		world.service_set_carrier.visible = false
	for time: Array in [["day", 840.0], ["night", 1290.0]]:
		# The sky follows the campaign clock; the traffic and the line read the same minute.
		CampaignClock.new().configure_date(1929, 11, 8, int(time[1]))
		for i in 12:
			await get_tree().process_frame
		traffic.clock_override = {"valid": true, "day": "fri", "month": 11, "day_of_month": 8, "year": 1929, "minute_of_day": float(time[1])}
		traffic._read_clock()
		# A car each way on the avenue, a motor car among them, and the line's own clock stopped for the frames.
		traffic.stage([{"id": "model_a_tudor", "lane_west": false, "x": -22.0}])
		var west := traffic.rail_journey(line.kind_index, true)
		west.phase = "street"
		west.p = -6.0
		west.speed = 0.0
		var east := traffic.rail_journey(line.kind_index, false)
		east.phase = "street"
		east.p = 4.0
		east.speed = 0.0
		for v: Dictionary in [west, east]:
			v.paint = Color(0.16, 0.25, 0.19).srgb_to_linear()
			traffic._live.append(v)
		traffic._write_instances()
		line.update_lamps()
		for f: Dictionary in line._flashes:
			f.left = 0.0
		line.flash(east)
		for f: Dictionary in line._flashes:
			f.left = 1.0e6 if float(f.left) > 0.0 else 0.0  # hold the arc for the frames
		var label := str(time[0])
		await _view(street, label + "_pavement_east", Vector3(-10.0, 1.62, 2.4), Vector3(14.0, 3.2, 10.0))
		await _view(street, label + "_door", Vector3(1.5, 1.62, 1.0), Vector3(2.0, 4.0, 12.0))
		await _view(street, label + "_far_kerb", Vector3(20.0, 1.62, 16.0), Vector3(-4.0, 3.0, 8.0))
		await _view(street, label + "_corner_east", Vector3(52.0, 1.62, 3.2), Vector3(70.0, 3.0, 26.0))
		await _view(street, label + "_above", Vector3(-12.0, 8.5, 6.0), Vector3(8.0, 3.0, 11.0))
		for f: Dictionary in line._flashes:
			f.left = 0.0
		line._process(0.0)
	traffic.frozen = false


func _view(street: Node3D, label: String, at: Vector3, target: Vector3) -> void:
	var camera := world.player.camera
	camera.global_position = street.to_global(at)
	camera.look_at(street.to_global(target))
	for i in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	summary.captures.append(label + ".png")
