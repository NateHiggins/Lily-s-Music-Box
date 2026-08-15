extends Node
## Fixed production-street proof for the WE TUNA PIANOS traffic addition.

const STATIONS := [
	{"name": "01_south_side_sign",
		"eye": [-8.0, -26.20, 1.65], "look": [-2.8, -21.8, 1.22],
		"truck_x": -2.8, "westbound": false},
	{"name": "02_street_three_quarter",
		"eye": [7.4, -26.55, 1.85], "look": [1.0, -21.8, 1.18],
		"truck_x": 1.0, "westbound": false},
	{"name": "03_north_side_opposite_lane",
		"eye": [-1.5, -12.75, 1.80], "look": [4.0, -17.0, 1.25],
		"truck_x": 4.0, "westbound": true},
]

var root: Node3D
var camera: Camera3D
var traffic: StreetTraffic
var _frame_serial := 0
var _failed := false


func _ready() -> void:
	if OS.get_environment("DAYNIGHT_FORCE") == "":
		OS.set_environment("DAYNIGHT_FORCE", "morning")
	if OS.get_environment("WEATHER_SEED") == "":
		OS.set_environment("WEATHER_SEED", "19280814")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	_hide_capture_ui(get_tree().root)
	camera = Camera3D.new()
	camera.fov = 64.0
	add_child(camera)
	camera.make_current()
	root.view_override = camera
	root.player.set_physics_process(false)
	traffic = root.street_traffic
	traffic.set_process(false)
	for station: Dictionary in STATIONS:
		_hold_truck(float(station.truck_x), bool(station.westbound))
		await _capture(station.name, station.eye, station.look)
	print("[PIANO REPAIR TRUCK SHOT] %s" % ["capture failed" if _failed
			else "%d frames saved" % STATIONS.size()])
	get_tree().quit(1 if _failed else 0)


func _hold_truck(x: float, westbound: bool) -> void:
	traffic._live = [{"kind": StreetTraffic.PIANO_REPAIR_KIND,
			"lane": westbound, "dir": -1.0 if westbound else 1.0,
			"x": x, "speed": 5.2, "stop_stage": 0, "dwell": 0.0}]
	traffic._write_instances()


func _capture(label: String, eye_b: Array, look_b: Array) -> void:
	var eye := GameBoot.b2g(eye_b)
	camera.global_position = eye
	camera.look_at(GameBoot.b2g(look_b))
	root.player.global_position = eye - Vector3(0.0,
			PlayerController.STANDING_EYE, 0.0)
	root.player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.8).timeout
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
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_capture_ui(child)
