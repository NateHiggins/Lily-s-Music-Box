extends Node
## Fixed human-height visual proof for T5. Four frames prove the restored
## architecture without a vehicle masking it; the fifth holds a production
## tram at the actual service dwell and proves the shelter belongs to a route.

const STATIONS := [
	{"name": "01_west_curb_architecture", "eye": [-17.2, -24.72, 1.68],
		"look": [-10.4, -26.20, 1.18], "service": false},
	{"name": "02_curb_front_architecture", "eye": [-10.4, -22.90, 1.68],
		"look": [-10.4, -26.20, 1.34], "service": false},
	{"name": "03_under_canopy_along_curb", "eye": [-11.75, -26.05, 1.68],
		"look": [-5.8, -25.82, 1.16], "service": false},
	{"name": "04_rear_bypass_architecture", "eye": [-16.2, -28.00, 1.68],
		"look": [-10.4, -26.15, 1.15], "service": false},
	{"name": "05_serving_tram_three_quarter", "eye": [-3.2, -28.00, 1.82],
		"look": [-10.4, -23.10, 1.28], "service": true},
]

var root: Node3D
var camera: Camera3D
var _frame_serial := 0
var _failed := false


func _ready() -> void:
	if OS.get_environment("DAYNIGHT_FORCE") == "":
		OS.set_environment("DAYNIGHT_FORCE", "day")
	if OS.get_environment("WEATHER_SEED") == "":
		OS.set_environment("WEATHER_SEED", "19280731")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	_hide_capture_ui(get_tree().root)
	camera = Camera3D.new()
	camera.fov = 70.0
	add_child(camera)
	camera.make_current()
	root.view_override = camera
	root.player.set_physics_process(false)
	_clear_traffic()
	for station: Dictionary in STATIONS:
		if station.service:
			_hold_serving_tram()
		await _capture(station.name, station.eye, station.look)
	print("[TRANSIT SHELTER SHOT] %s" % ["capture failed" if _failed
			else "%d frames saved" % STATIONS.size()])
	get_tree().quit(1 if _failed else 0)


func _hold_serving_tram() -> void:
	var traffic: StreetTraffic = root.street_traffic
	traffic.set_process(false)
	var tram_kind := 0
	for index in StreetTraffic.KINDS.size():
		if str(StreetTraffic.KINDS[index][0]) == "tram":
			tram_kind = index
			break
	traffic._live = [{"kind": tram_kind, "lane": false, "dir": 1.0,
			"x": StreetTraffic.TRANSIT_STOP_X, "speed": 5.0,
			"stop_stage": 1, "dwell": StreetTraffic.TRANSIT_STOP_DWELL}]
	traffic._write_instances()


func _clear_traffic() -> void:
	var traffic: StreetTraffic = root.street_traffic
	traffic.set_process(false)
	traffic._live.clear()
	traffic._write_instances()


func _capture(label: String, eye_b: Array, look_b: Array) -> void:
	var eye := GameBoot.b2g(eye_b)
	camera.global_position = eye
	camera.look_at(GameBoot.b2g(look_b))
	root.player.global_position = eye - Vector3(0.0,
			PlayerController.STANDING_EYE, 0.0)
	root.player.velocity = Vector3.ZERO
	await get_tree().create_timer(1.0).timeout
	var expected := _frame_serial + 1
	RenderingServer.frame_post_draw.connect(_mark_frame, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + 2000
	while _frame_serial < expected and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if RenderingServer.frame_post_draw.is_connected(_mark_frame):
		RenderingServer.frame_post_draw.disconnect(_mark_frame)
	if _frame_serial < expected:
		_failed = true
		push_error("No rendered frame arrived for %s" % label)
		return
	var output := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	get_viewport().get_texture().get_image().save_png(
			output.path_join(label + ".png"))


func _mark_frame() -> void:
	_frame_serial += 1


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or (node is Label3D
			and node.name != "TransitShelterStopSign"):
		node.visible = false
	for child in node.get_children():
		_hide_capture_ui(child)
