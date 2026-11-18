extends Node3D
## Review fixture for the near city's street furniture (Lily's ruling city_complete_next_20261117): starts the
## production V2 world, frames its installed near street furniture at a fixed afternoon, and measures
## the frame with the overlay hidden and shown (ruling city_vs_frametime_20261114). SHOT_DIR receives the frames and
## review.json. Windowed only; no campaign, route or save authority.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(n: int) -> float:
	var started := Time.get_ticks_usec()
	for i in n:
		await RenderingServer.frame_post_draw
	return (Time.get_ticks_usec() - started) / 1000.0 / float(n)


func _run() -> void:
	var output := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 17, 14 * 60)
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled = false
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	while world.startup_ms <= 0.0 and not world.startup_failed:
		await get_tree().process_frame
	if world.startup_failed:
		print("NEAR FURNITURE REVIEW: world did not start")
		get_tree().quit(1)
		return
	var overlay := world.get_node("CityNearFurniture") as Node3D
	var data: Dictionary = overlay.data
	var camera := Camera3D.new()
	camera.fov = 62.0
	world.add_child(camera)
	camera.make_current()
	world.player.set_physics_process(false)
	var views: Array = []
	for group: Dictionary in data.furniture:
		if not (group["items"] as Array).is_empty():
			views.append([str(group.kind), group["items"][0]])
	for sign: Dictionary in data.get("signs", []):
		views.append(["sign_" + str(sign.street[0]).replace(" ", "_"), [sign.x, sign.y, sign.z, 0.0]])
	var poles: Array = data.poles
	if not poles.is_empty():
		views.append(["telegraph_pole", poles[0]])
		views.append(["telegraph_pole_run", poles[mini(2, poles.size() - 1)]])
	var timing := {}
	var n := 0
	for view: Array in views:
		var item: Array = view[1]
		var at := Vector3(float(item[0]), float(item[1]), float(item[2]))
		var yaw := float(item[3])
		# Stand out in the road, looking back at the piece and along the kerb.
		var face := Vector3(sin(yaw), 0.0, cos(yaw))
		var along := Vector3(cos(yaw), 0.0, -sin(yaw))
		var tall := str(view[0]).begins_with("telegraph")
		if str(view[0]).begins_with("sign_"):
			# Below the corner, looking up at the blades.
			camera.global_position = at + Vector3(-3.2, 1.7, 4.5)
			camera.look_at(at + Vector3.UP * 3.0, Vector3.UP)
			for f in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output.path_join("near_%02d_%s.png" % [n, view[0]]))
			n += 1
			continue
		camera.global_position = at + face * (7.0 if not tall else 14.0) + along * 3.0 + Vector3.UP * (1.6 if not tall else 2.2)
		camera.look_at(at + Vector3.UP * (0.6 if not tall else 6.5), Vector3.UP)
		for f in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("near_%02d_%s.png" % [n, view[0]]))
		overlay.visible = false
		var hidden := await _frames(60)
		overlay.visible = true
		var shown := await _frames(60)
		timing[str(n) + "_" + str(view[0])] = {"hidden_ms": snappedf(hidden, 0.01), "shown_ms": snappedf(shown, 0.01)}
		n += 1
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class": "INERT", "views": n, "frame_ms": timing}, "\t"))
	file.close()
	print("NEAR FURNITURE REVIEW views ", n, " timing ", timing)
	get_tree().quit(0)
