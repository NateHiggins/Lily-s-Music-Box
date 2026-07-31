extends Node
## Screenshot driver (not shipped). Run under xvfb:
##   xvfb-run godot --path game res://tests/Screenshot.tscn
## Renders documentation framegrabs of key building views to $SHOT_DIR.

var root: Node3D
var cam: Camera3D
var _dir := ""

const SHOTS := [
	# Raised and pulled back: the block now has buildings where this camera
	# used to stand, and it was framing a neighbour's back wall.
	{"name": "b_01_exterior_street", "pos": Vector3(21, 27, 41),
	 "look": Vector3(-1, 9, 2), "overlay": false},
	{"name": "b_02_lobby", "pos": Vector3(-0.4, 1.72, 9.1),
	 "look": Vector3(3.6, 1.25, 6.6), "overlay": false},
	{"name": "b_03_corridor_f04", "pos": Vector3(4.3, 11.25, 7.6),
	 "look": Vector3(4.3, 10.8, -6.0), "overlay": false},
	{"name": "b_04_apartment_4b", "pos": Vector3(-8.1, 11.25, -3.2),
	 "look": Vector3(-13.2, 10.2, -8.0), "overlay": false},
	{"name": "b_05_front_stair", "pos": Vector3(-0.4, 1.75, 5.6),
	 "look": Vector3(-2.2, 3.6, -1.5), "overlay": false},
	{"name": "b_16_stair_half_landing", "pos": Vector3(0.0, 6.42, -2.31),
	 "look": Vector3(0.4, 4.4, 2.6), "overlay": false},
	# At the eye's edge looking up the well past the light tree. Further
	# back on the deck and the storey above fills the frame with its soffit.
	{"name": "b_18_atrium_eye", "pos": Vector3(0.0, 1.75, 1.58),
	 "look": Vector3(0.12, 15.0, 0.10), "overlay": false},
	{"name": "b_33_light_tree", "pos": Vector3(1.05, 8.05, 2.35),
	 "look": Vector3(-0.10, 6.60, -0.10), "overlay": false},
	{"name": "b_17_2a_mina_living", "pos": Vector3(-6.8, 4.78, 1.4),
	 "look": Vector3(-12.5, 3.9, 3.8), "overlay": false},
	{"name": "b_06_laundry_b1", "pos": Vector3(-8.7, -1.25, -3.7),
	 "look": Vector3(-11.6, -2.1, -5.1), "overlay": false},
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
	{"name": "b_16_street_level", "pos": Vector3(5.5, 1.7, 13.8),
	 "look": Vector3(-1.0, 7.0, 9.8), "overlay": false},
	{"name": "b_17_alley_porches", "pos": Vector3(-6.5, 1.8, -12.6),
	 "look": Vector3(-9.2, 8.0, -10.2), "overlay": false},
	{"name": "b_19_1a_teacher", "pos": Vector3(-6.6, 1.55, 1.2),
	 "look": Vector3(-8.55, 0.85, 3.10), "overlay": false},
	{"name": "b_20_2b_seamstress", "pos": Vector3(-11.2, 4.75, -2.9),
	 "look": Vector3(-8.25, 4.05, -3.82), "overlay": false},
	{"name": "b_21_5c_painter", "pos": Vector3(11.2, 14.35, -4.4),
	 "look": Vector3(8.50, 13.65, -2.22), "overlay": false},
	{"name": "b_22_2c_juno", "pos": Vector3(9.2, 4.75, -2.6),
	 "look": Vector3(12.9, 4.05, -4.9), "overlay": false, "infection": 0.6},
	{"name": "b_23_3b_omar", "pos": Vector3(-9.6, 7.95, -3.9),
	 "look": Vector3(-12.6, 7.30, -6.1), "overlay": false},
	{"name": "b_24_3d_rhea", "pos": Vector3(8.2, 7.95, 2.9),
	 "look": Vector3(11.2, 7.20, 5.4), "overlay": false},
	{"name": "b_25_5a_nadia", "pos": Vector3(-6.9, 14.35, 1.7),
	 "look": Vector3(-9.9, 13.60, 4.4), "overlay": false},
	{"name": "b_26_4b_bath", "pos": Vector3(-6.10, 11.20, -5.10),
	 "look": Vector3(-7.21, 10.85, -6.46), "overlay": false},
	{"name": "b_31_stair_bottom", "pos": Vector3(0.30, -1.70, 2.30),
	 "look": Vector3(-2.30, -2.72, 0.60), "overlay": false},
	{"name": "b_34_reading_nook", "pos": Vector3(1.55, -1.55, 2.55),
	 "look": Vector3(-0.30, -2.35, -0.20), "overlay": false},
	{"name": "b_32_stair_top", "pos": Vector3(1.6, 20.80, 2.40),
	 "look": Vector3(-1.00, 20.00, -1.00), "overlay": false},
	{"name": "b_29_street_east", "pos": Vector3(-1.0, 1.62, 12.2),
	 "look": Vector3(19.0, 1.50, 12.6), "overlay": false},
	{"name": "b_30_street_west", "pos": Vector3(1.0, 1.62, 12.2),
	 "look": Vector3(-19.0, 1.50, 12.6), "overlay": false},
]


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	for c in root.get_children():
		if c is CanvasLayer:
			c.visible = false  # doc stills are the building, not the HUD
	_run()


## The phone HUD is the one overlay worth documenting: it has to be judged
## against the room behind it, not on a blank screen.
func _shoot_touch_hud() -> void:
	if root.touch == null:
		return
	root.touch.set_enabled(true)
	root.touch.visible = true
	if root.player:
		root.player.global_position = Vector3(4.3, 11.25, 7.6)
	cam.global_position = Vector3(4.3, 11.25, 7.6)
	cam.look_at(Vector3(4.3, 10.8, -6.0))
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
			"%s/b_28_touch_controls.png" % _dir)
	print("saved %s/b_28_touch_controls.png" % _dir)
	root.touch.set_enabled(false)


func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	root.show_all_floors = true
	Conductor.infection = 0.6       # lights react in stills too
	cam = Camera3D.new()
	cam.fov = 72
	add_child(cam)
	cam.make_current()
	# Documentation must reflect playable exposure exactly; an old 0.55
	# ambient override hid navigation failures and erased real shadows.
	var only := OS.get_environment("SCREENSHOT_ONLY")
	for shot in SHOTS:
		if only != "" and shot.name != only:
			continue
		AcousticGraphData.set_overlay_visible(shot.overlay, root)
		if shot.has("infection"):
			Conductor.infection = shot.infection
			await get_tree().create_timer(3.0).timeout  # let the seam manifest
		await _grab(shot.pos, shot.look, shot.name)

	if only != "":
		get_tree().quit()
		return

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
	await _shoot_touch_hud()
	get_tree().quit(0)


func _grab(pos: Vector3, look: Vector3, shot_name: String) -> void:
	# The runtime light budget follows the player, so documentation cameras
	# must move that focus too or remote floors are intentionally dormant.
	if root.player:
		root.player.global_position = pos
	cam.global_position = pos
	cam.look_at(look)
	if OS.get_environment("SCREENSHOT_TEST_CAMERA_LIGHT") == "1":
		var test_light := OmniLight3D.new()
		test_light.light_energy = 10.0
		test_light.omni_range = 12.0
		test_light.shadow_enabled = false
		cam.add_child(test_light)
	await get_tree().create_timer(0.5).timeout
	if OS.get_environment("SCREENSHOT_LIGHT_TELEMETRY") == "1":
		print("[SHOT LIGHTS] ", root.light_rig.stats())
		var nearby := get_tree().get_nodes_in_group("light_fixtures")
		nearby.sort_custom(func(a, b):
			return a.global_position.distance_squared_to(pos) \
					< b.global_position.distance_squared_to(pos))
		for fixture in nearby.slice(0, 6):
			print("[SHOT LIGHT] %s d=%.2f energy=%.3f range=%.2f mask=%d shadow=%s" % [
				fixture.name, fixture.global_position.distance_to(pos),
				fixture.light.light_energy, fixture.light.omni_range,
				fixture.light.light_cull_mask, fixture.light.shadow_enabled])
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
