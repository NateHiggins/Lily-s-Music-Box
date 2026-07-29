extends Node
## Screenshot driver (not shipped). Run under xvfb:
##   xvfb-run godot --path game res://tests/Screenshot.tscn
## Renders documentation framegrabs of key building views to $SHOT_DIR.

var root: Node3D
var cam: Camera3D
var _dir := ""

const SHOTS := [
	{"name": "b_01_exterior_street", "pos": Vector3(16, 12, 34),
	 "look": Vector3(0, 8, 0), "overlay": false},
	{"name": "b_02_lobby", "pos": Vector3(-2.5, 1.72, 8.6),
	 "look": Vector3(2.2, 1.2, 5.2), "overlay": false},
	{"name": "b_03_corridor_f04", "pos": Vector3(4.3, 11.25, 7.6),
	 "look": Vector3(4.3, 10.8, -6.0), "overlay": false},
	{"name": "b_04_apartment_4b", "pos": Vector3(-6.6, 11.25, -1.8),
	 "look": Vector3(-13.2, 10.3, -4.9), "overlay": false},
	{"name": "b_05_front_stair", "pos": Vector3(0.3, 1.8, 5.8),
	 "look": Vector3(-2.8, 3.1, 4.4), "overlay": false},
	{"name": "b_06_laundry_b1", "pos": Vector3(-7.8, -1.2, -2.2),
	 "look": Vector3(-11.5, -2.2, -5.4), "overlay": false},
	{"name": "b_07_roof", "pos": Vector3(-6, 21.4, 9.5),
	 "look": Vector3(2, 19.4, -4), "overlay": false},
	{"name": "b_08_acoustic_graph", "pos": Vector3(26, 14, 26),
	 "look": Vector3(0, 7, 0), "overlay": true},
	{"name": "b_09_4b_workstation", "pos": Vector3(-10.2, 11.15, -3.8),
	 "look": Vector3(-8.0, 10.45, -5.6), "overlay": false},
	{"name": "b_10_4b_kitchen", "pos": Vector3(-9.6, 11.15, -7.0),
	 "look": Vector3(-9.7, 10.45, -9.3), "overlay": false},
	{"name": "b_11_4b_door_anomaly", "pos": Vector3(-9.5, 11.1, -5.4),
	 "look": Vector3(-7.2, 10.7, -7.0), "overlay": false, "infection": 1.0},
	{"name": "b_15_6a_sacha", "pos": Vector3(-10.3, 17.5, 3.4),
	 "look": Vector3(-12.9, 17.2, 5.1), "overlay": false, "infection": 0.6},
]


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	_run()


func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	root.show_all_floors = true
	Conductor.infection = 0.6       # lights react in stills too
	cam = Camera3D.new()
	cam.fov = 72
	add_child(cam)
	cam.make_current()
	# stills need more ambient light than gameplay
	for c in root.get_children():
		if c is WorldEnvironment:
			c.environment.ambient_light_energy = 1.1
			c.environment.background_color = Color(0.05, 0.06, 0.10)
	for shot in SHOTS:
		AcousticGraphData.set_overlay_visible(shot.overlay, root)
		if shot.has("infection"):
			Conductor.infection = shot.infection
			await get_tree().create_timer(3.0).timeout  # let the seam manifest
		await _grab(shot.pos, shot.look, shot.name)

	# Case 01 at the desk: response window, then the manifested door
	var ci: CallInterface = root.call_interface
	ci.fast = true
	ci.enter(root.player)
	await _until_ci(func(): return not ci._isolate_btn.disabled, 15.0)
	ci.press_isolate(true)
	await _until_ci(func(): return not ci._capture_btn.disabled, 20.0)
	ci.press_capture()
	ci.press_route()
	await _until_ci(func(): return ci.stage == CallInterface.Stage.RESPONSE, 25.0)
	await _grab(Vector3(-9.0, 11.15, -4.8), Vector3(-8.0, 10.6, -5.6),
			"b_12_call_response_window")
	ci.press_respond("complete")
	await get_tree().create_timer(4.0).timeout
	ci.leave()
	await _grab(Vector3(-9.5, 11.0, -5.5), Vector3(-7.2, 10.6, -7.0),
			"b_13_door_anomaly_manifest")
	# through the seam: Room 0
	var anomaly = root.get_node_or_null("F04_B_DOOR_ANOMALY")
	if anomaly and anomaly.room0:
		anomaly.interact(root.player)
		await get_tree().create_timer(0.9).timeout
		await _grab(Vector3(-7.2, 91.6, -2.2), Vector3(-7.2, 91.0, -7.4),
				"b_14_room0")
	get_tree().quit(0)


func _grab(pos: Vector3, look: Vector3, shot_name: String) -> void:
	cam.global_position = pos
	cam.look_at(look)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_dir, shot_name]
	img.save_png(path)
	print("saved ", path)


func _until_ci(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while t < timeout and not cond.call():
		await get_tree().create_timer(0.25).timeout
		t += 0.25
