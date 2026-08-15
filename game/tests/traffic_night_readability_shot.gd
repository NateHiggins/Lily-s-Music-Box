extends Node
## Fixed canonical-night control/control/final frames for T2d. The duplicate
## control is mandatory because live rain changes while the camera stands still.

const STATIONS := [
	{"name": "01_north_kerb_long_view",
		"eye": [-16.0, -13.50, 1.68], "look": [18.0, -19.0, 1.05]},
	{"name": "02_south_kerb_crossing",
		"eye": [-1.8, -25.55, 1.68], "look": [4.0, -17.8, 1.05]},
]

var root: Node3D
var camera: Camera3D
var traffic: StreetTraffic
var _frame_serial := 0
var _failed := false


func _ready() -> void:
	OS.set_environment("DAYNIGHT_FORCE", "night")
	OS.set_environment("WEATHER_SEED", "19280214")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	_hide_capture_ui(get_tree().root)
	camera = Camera3D.new()
	camera.fov = 66.0
	add_child(camera)
	camera.make_current()
	root.view_override = camera
	root.player.set_process(false)
	root.player.set_physics_process(false)
	traffic = root.street_traffic
	traffic.set_process(false)
	_hold_stream()

	traffic._headlight_pools.visible = false
	for station: Dictionary in STATIONS:
		await _capture("control_a", station)
	for station: Dictionary in STATIONS:
		await _capture("control_b", station)
	traffic._headlight_pools.visible = true
	for station: Dictionary in STATIONS:
		await _capture("final", station)
	print("[TRAFFIC NIGHT READABILITY SHOT] %s" % ["capture failed"
			if _failed else "six frames saved"])
	get_tree().quit(1 if _failed else 0)


func _hold_stream() -> void:
	traffic._live = [
		_vehicle("motor_car", false, -3.0),
		_vehicle("coal_lorry", true, 2.0),
		_vehicle("piano_repair", false, 11.0),
	]
	traffic._write_instances()


func _vehicle(label: String, westbound: bool, x: float) -> Dictionary:
	var kind := -1
	for index in StreetTraffic.KINDS.size():
		if str(StreetTraffic.KINDS[index][0]) == label:
			kind = index
			break
	return {"kind": kind, "lane": westbound,
			"dir": -1.0 if westbound else 1.0,
			"x": x, "speed": 5.2, "stop_stage": 0, "dwell": 0.0}


func _capture(group: String, station: Dictionary) -> void:
	var eye := GameBoot.b2g(station.eye)
	camera.global_position = eye
	camera.look_at(GameBoot.b2g(station.look))
	root.player.global_position = eye - Vector3(0.0,
			PlayerController.STANDING_EYE, 0.0)
	root.player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.55).timeout
	var expected := _frame_serial + 1
	RenderingServer.frame_post_draw.connect(_mark_frame, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + 2000
	while _frame_serial < expected and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if RenderingServer.frame_post_draw.is_connected(_mark_frame):
		RenderingServer.frame_post_draw.disconnect(_mark_frame)
	if _frame_serial < expected:
		_failed = true
		push_error("No rendered frame arrived for %s/%s" % [group, station.name])
		return
	var output := OS.get_environment("SHOT_DIR").path_join(group)
	DirAccess.make_dir_recursive_absolute(output)
	get_viewport().get_texture().get_image().save_png(
			output.path_join(str(station.name) + ".png"))


func _mark_frame() -> void:
	_frame_serial += 1


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_capture_ui(child)
