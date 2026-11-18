extends Node3D
## Review fixture for the near city's building fronts (Lily's ruling city_next_batch_20261117): starts the production V2
## world at a fixed afternoon, frames its installed fronts, then the shop signs again after dark, and
## measures the frame with the overlay hidden and shown (ruling city_vs_frametime_20261114). SHOT_DIR receives the
## frames and review.json. Windowed only; no campaign, route or save authority.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(n: int) -> float:
	var started := Time.get_ticks_usec()
	for i in n:
		await RenderingServer.frame_post_draw
	return (Time.get_ticks_usec() - started) / 1000.0 / float(n)


func _shoot(camera: Camera3D, at: Vector3, yaw: float, back: float, rise: float, look_up: float, path: String) -> void:
	var out := Vector3(sin(yaw), 0.0, cos(yaw))
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	camera.global_position = Vector3(at.x, 1.7 + rise, at.z) + out * back + along * (back * 0.35)
	camera.look_at(at + Vector3.UP * look_up, Vector3.UP)
	for f in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _run() -> void:
	var output := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928, 11, 17, 13 * 60)
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled = false
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	while world.startup_ms <= 0.0 and not world.startup_failed:
		await get_tree().process_frame
	if world.startup_failed:
		print("CITY FRONTS REVIEW: world did not start")
		get_tree().quit(1)
		return
	var overlay := world.get_node("CityFronts") as Node3D
	var data: Dictionary = overlay.data
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 800.0
	world.add_child(camera)
	camera.make_current()
	world.player.set_physics_process(false)
	var n := 0
	var views: Array = []
	for sign: Dictionary in data.signs:
		views.append(["sign", sign, 7.0, 0.0, 3.4])
	for advert: Dictionary in data.wall_adverts:
		views.append(["wall_advert", advert, 22.0, 0.0, float(advert.at[1])])
	for board: Dictionary in data.billboards:
		views.append(["billboard", board, 30.0, 4.0, float(board.at[1]) + 2.6])
	for view: Array in views:
		var item: Dictionary = view[1]
		var at := Vector3(float(item.at[0]), 0.0, float(item.at[2]))
		await _shoot(camera, at, float(item.yaw), float(view[2]), float(view[3]), float(view[4]), output.path_join("front_%02d_%s.png" % [n, view[0]]))
		n += 1
	# Fire escapes and awnings from across the street; roof tanks from above.
	var accepted_path := ProjectSettings.globalize_path("res://").path_join("../art/blender/data/city_fronts/accepted.json").simplify_path()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(accepted_path)) if FileAccess.file_exists(accepted_path) else {}
	for kind: String in ["fire_escape", "awning"]:
		for item: Dictionary in (source.get("items", {}).get(kind, []) as Array).slice(0, 2):
			var at := Vector3(float(item.at[0]), 0.0, float(item.at[2]))
			await _shoot(camera, at, float(item.yaw), 12.0, 0.0, 4.0 if kind == "fire_escape" else 2.6, output.path_join("front_%02d_%s.png" % [n, kind]))
			n += 1
	for target: Array in (data.get("roof_tanks", []) as Array).slice(0, 2):
		camera.global_position = Vector3(float(target[0]) + 9.0, float(target[1]) + 8.0, float(target[2]) + 9.0)
		camera.look_at(Vector3(float(target[0]), float(target[1]) + 2.0, float(target[2])), Vector3.UP)
		for f in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("front_%02d_roof_tank.png" % n))
		n += 1
	var timing := {}
	overlay.visible = false
	timing["hidden_ms"] = snappedf(await _frames(90), 0.01)
	overlay.visible = true
	timing["shown_ms"] = snappedf(await _frames(90), 0.01)
	# The shop signs after dark: the lettering reads lit with no light added.
	clock.configure_date(1928, 11, 17, 21 * 60)
	overlay._apply_light(true)
	for sign: Dictionary in data.signs:
		var at := Vector3(float(sign.at[0]), 0.0, float(sign.at[2]))
		await _shoot(camera, at, float(sign.yaw), 7.0, 0.0, 3.4, output.path_join("front_%02d_sign_night.png" % n))
		n += 1
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class": "INERT", "views": n, "frame_ms": timing}, "\t"))
	file.close()
	print("CITY FRONTS REVIEW views ", n, " timing ", timing)
	get_tree().quit(0)
