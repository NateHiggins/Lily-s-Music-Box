extends Node
## T6 fixed-camera proof. Three moments use the production traffic batches and
## authored first-shift staging: the curb handoff, pull-away, and east storm
## swallow. Traffic is advanced deterministically between frames.

const STATIONS := [
	{"name": "01_just_out_at_south_kerb",
		"eye": [-3.60, -24.72, 1.68], "look": [0.0, -9.82, 2.15],
		"advance": 0.0},
	{"name": "02_pull_away_across_crossing",
		"eye": [-6.80, -26.15, 1.72], "look": [4.10, -21.95, 0.82],
		"advance": StreetTraffic.ARRIVAL_HOLD_SECONDS + 2.20},
	{"name": "03_east_tear_swallow",
		"eye": [8.20, -25.35, 1.78], "look": [20.60, -21.80, 0.92],
		"advance": 2.45},
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
	camera.fov = 67.0
	add_child(camera)
	camera.make_current()
	root.view_override = camera
	root.player.set_physics_process(false)
	traffic = root.street_traffic
	traffic.set_process(false)
	traffic.begin_arrival()
	for station: Dictionary in STATIONS:
		var advance: float = float(station.advance)
		if advance > 0.0:
			traffic._advance(advance)
			traffic._write_instances()
		await _capture(station.name, station.eye, station.look)
	print("[ARRIVAL CAR SHOT] %s" % ["capture failed" if _failed
			else "%d frames saved" % STATIONS.size()])
	get_tree().quit(1 if _failed else 0)


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
