extends "res://tests/orison_v2_vertical_route_test.gd"

const FURNISHINGS := [
	"ParcelTable", "ReadingTable", "LiftWaitingSettee", "MendingMachine", "RoofWaitingSettee",
]


func _init() -> void:
	route_label = "UPPER FRONT COMMONS"


func _prepare_campaign() -> bool:
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled = false
	return super._prepare_campaign()


func _route() -> void:
	# Reuse proven walking evidence when only the camera framing changes.
	var capture_only := OS.get_environment("ORISON_UPPER_COMMONS_CAPTURE_ONLY") == "1"
	for index in range(5):
		var floor_id := "F%02d" % (index + 2)
		var floor_y := float(index + 1) * 3.2
		var gallery := floor_id + "_FRONT_GALLERY"
		var lamp := world.adapter.root.get_node_or_null(gallery + "_LT_2") as LightFixtureProp
		if lamp == null or not is_equal_approx(lamp.light.omni_range, 8.0):
			failures.append(gallery + " requires its single wide-throw light")
		for retired in ["_FRONT_GALLERY_LT_1", "_FRONT_GALLERY_LT_3",
				"_FRONT_HALL_LT_1", "_FRONT_HALL_LT_2", "_FRONT_HALL_SWITCH"]:
			if world.adapter.root.has_node(floor_id + retired):
				failures.append(floor_id + retired + " is still installed")
		var furnishing_path := "UpperFrontCommons/%s/%s" % [floor_id, FURNISHINGS[index]]
		var furnishing := world.adapter.root.get_node_or_null(furnishing_path) as StaticBody3D
		if furnishing == null:
			failures.append(floor_id + " is missing its shared furnishing")

		# Start each local path at a known stance. The default controller then
		# crosses the widened edges under its ordinary physics and collision.
		var paths := [
			[Vector3(6.10, floor_y, -3.34), Vector3(6.10, floor_y, -5.0)],
			[Vector3(-1.27, floor_y, -4.70), Vector3(-1.27, floor_y, -3.26)],
			[Vector3(3.80, floor_y, -4.70), Vector3(3.80, floor_y, -3.26)],
			[Vector3(-1.2, floor_y, -8.72), Vector3(5.8, floor_y, -8.72)],
		]
		if index < 3:
			paths.append([Vector3(-4.64, floor_y, -6.48), Vector3(-4.64, floor_y, -8.42)])
		if not capture_only:
			for path: Array in paths:
				await _cross(path[0], path[1])
		if furnishing != null:
			await _capture(floor_id, floor_y, furnishing.global_position)


func _cross(start: Vector3, finish: Vector3) -> void:
	player.global_position = world.adapter.root.to_global(start + Vector3.UP * 0.03)
	player.velocity = Vector3.ZERO
	for step in range(6):
		await get_tree().physics_frame
	await _walk(finish)


func _capture(floor_id: String, floor_y: float, subject: Vector3) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	player.global_position = world.adapter.root.to_global(Vector3(1.35, floor_y + 0.03, -5.75))
	player.velocity = Vector3.ZERO
	var aim := subject - player.global_position
	player.rotation.y = atan2(-aim.x, -aim.z)
	player.camera.rotation = Vector3.ZERO
	var lamp_was_on := player.lamp_is_enabled()
	player.set_lamp_enabled(false)
	for step in range(36):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(directory.path_join(floor_id + "_commons.png")) != OK:
		failures.append(floor_id + " capture could not be written")
	player.set_lamp_enabled(lamp_was_on)
