extends Node
## INERT review capture of the traffic brought to spec (design/V2_TRAFFIC_INVENTORY_2026-11-23.md). Windowed only.
## Boots the production V2 world on New York's Moving Day, 1 May 1929, stages the WE TUNA PIANOS truck, a car
## steering through the east T, a Model T at the far end of the block, a milk wagon and a tram, and captures them by
## day and by night; then three frames of the piano truck rolling, and the distant el car up close. Not runtime
## proof and no acceptance grant.
const Selector := preload("res://scripts/building/building_root_selector.gd")
var directory: String
var world: OrisonV2RuntimeRoot
var failures := 0
var summary := {"evidence_class": "INERT", "checks": [], "captures": []}


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	summary.checks.append({"label": label, "ok": ok})
	print("TRAFFIC SPEC SHOT CHECK: ", label, " = ", ok)


func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless" or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Traffic spec review requires windowed capture and SHOT_DIR")
		get_tree().quit(1)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1929, 5, 1, 840)
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
	var file := FileAccess.open(directory.path_join("traffic_spec_review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, " ", false) + "\n")
	file.close()
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	CampaignTime.set_frozen_for_tests(false)
	print("TRAFFIC SPEC REVIEW: %d failures; no acceptance grant" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _index(traffic: OrisonV2StreetTraffic, id: String) -> int:
	for i in traffic._kinds.size():
		if str(traffic._kinds[i].id) == id:
			return i
	return -1


func _review() -> void:
	var traffic := world.period_traffic as OrisonV2StreetTraffic
	check(traffic != null, "the production world mounts the period traffic")
	if traffic == null:
		return
	var line := traffic.rail as OrisonV2StreetTrams
	for i in 6:
		await get_tree().physics_frame
	var street := traffic.get_parent() as Node3D
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for canvas: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		canvas.hide()
	world.player.camera.make_current()
	if world.service_set_carrier != null:
		world.service_set_carrier.visible = false
	var piano := _index(traffic, "piano_truck")
	check(piano >= 0 and traffic._signs.has(piano), "the piano truck and its legend are in the production traffic")
	for time: Array in [["day", 840.0], ["night", 1290.0]]:
		CampaignClock.new().configure_date(1929, 5, 1, int(time[1]))
		for i in 12:
			await get_tree().process_frame
		traffic.clock_override = {"valid": true, "day": "wed", "month": 5, "day_of_month": 1, "year": 1929, "minute_of_day": float(time[1])}
		traffic._read_clock()
		traffic.stage([{"id": "piano_truck", "lane_west": false, "x": -3.0},
				{"id": "milk_wagon", "lane_west": true, "x": 14.0, "speed": 2.0, "travel": 3.3},
				{"id": "model_t_touring", "lane_west": false, "x": 50.0},
				{"id": "model_a_tudor", "lane_west": false, "x": 60.0, "steer": 0.42}])
		# The Tudor is halfway round its right turn into the east cross street, front wheels locked over.
		for v: Dictionary in traffic._live:
			if str(traffic._kinds[int(v.kind)].id) == "model_a_tudor":
				v.side = 1.0
				traffic._begin_exit(v, traffic._kinds[int(v.kind)])
				v.arc = 0.7
		if line != null:
			var tram := traffic.rail_journey(line.kind_index, true)
			tram.phase = "street"
			tram.p = -30.0
			tram.speed = 0.0
			tram.travel = 1.1
			tram.paint = Color(0.16, 0.25, 0.19).srgb_to_linear()
			traffic._live.append(tram)
			line.update_lamps()
		traffic._write_instances()
		var holder: Node3D = traffic._signs.get(piano)
		check(holder != null and holder.visible, "%s: the legend rides on the staged truck" % time[0])
		var label := str(time[0])
		await _view(street, label + "_piano_far_kerb", Vector3(-7.0, 1.62, 17.2), Vector3(-2.2, 1.4, 12.0))
		await _view(street, label + "_piano_front", Vector3(3.4, 1.4, 9.6), Vector3(-1.6, 1.1, 12.0))
		await _view(street, label + "_piano_rear", Vector3(-11.0, 1.7, 14.8), Vector3(-3.0, 1.3, 12.0))
		await _view(street, label + "_door", Vector3(1.5, 1.62, 1.0), Vector3(-2.0, 1.6, 12.0))
		# Close on the turning Tudor's nose, to see its front wheels locked over.
		for v: Dictionary in traffic._live:
			if str(traffic._kinds[int(v.kind)].id) == "model_a_tudor":
				var pose := traffic._world_pose(v)
				var car := Transform3D(Basis(Vector3.UP, float(pose[2])), Vector3(float(pose[0]), 0.0, float(pose[1])))
				await _view(street, label + "_turn_east", car * Vector3(4.2, 1.3, -3.2), car * Vector3(1.2, 0.35, 0.0))
				await _view(street, label + "_turn_east_above", car * Vector3(1.4, 4.2, -2.4), car * Vector3(1.3, 0.3, 0.0))
		await _view(street, label + "_far_end", Vector3(36.0, 1.62, 15.4), Vector3(50.0, 0.8, 12.0))
		await _view(street, label + "_tram_milk", Vector3(-6.0, 1.62, 3.6), Vector3(20.0, 1.4, 8.0))
	# Rolling: three frames a quarter-second apart as the truck pulls away, the wheels turning with the road.
	traffic.clock_override.minute_of_day = 840.0
	CampaignClock.new().configure_date(1929, 5, 1, 840)
	traffic._read_clock()
	traffic.stage([{"id": "piano_truck", "lane_west": false, "x": -6.0, "speed": 1.2}])
	var truck: Dictionary = traffic._live[0]
	var start := float(truck.travel)
	for frame in 3:
		await _view(street, "day_rolling_%d" % frame, Vector3(-9.5, 1.0, 16.0), Vector3(-4.5, 0.7, 12.0))
		for i in 15:
			traffic._advance(1.0 / 60.0)
			traffic._write_instances(1.0 / 60.0)
	check(float(truck.travel) > start + 0.5, "the truck rolled between the frames (%.2f m)" % (float(truck.travel) - start))
	# The distant el: one car on the Queensboro Bridge's upper deck, seen from close by for review.
	var motion := world.find_child("FarMotion", true, false) as Node3D
	var cars := motion.get_node_or_null("ElCars") as MultiMeshInstance3D if motion != null else null
	check(cars != null and cars.multimesh.mesh.get_surface_count() >= 4, "the el cars are the rail stock's el_car")
	if cars != null:
		for i in cars.multimesh.instance_count:
			var pose := cars.multimesh.get_instance_transform(i)
			if pose.origin.y > 0.0:
				var at := motion.global_transform * pose
				var camera := world.player.camera
				camera.global_position = at.origin + at.basis.z * 26.0 + at.basis.x * 4.0 + Vector3.UP * 3.0
				camera.look_at(at.origin + Vector3.UP * 2.0)
				for k in 8:
					await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(directory.path_join("day_el_car.png"))
				summary.captures.append("day_el_car.png")
				break


func _view(street: Node3D, label: String, at: Vector3, target: Vector3) -> void:
	var camera := world.player.camera
	camera.global_position = street.to_global(at)
	camera.look_at(street.to_global(target))
	for i in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	summary.captures.append(label + ".png")
