extends Node
## Fixed five-station proof for T8's four weather/sky states.
##
##   DAYNIGHT_FORCE=morning WEATHER_SEED=19280731 SHOT_DIR=<abs> \
##       godot --path game res://tests/WeatherSkyShot.tscn

const STATIONS := [
	{"name": "01_north_pavement", "pos": [-16.0, -13.5, 1.68],
		"look": [26.0, -19.6, 1.30]},
	{"name": "02_south_pavement", "pos": [0.0, -26.2, 1.68],
		"look": [0.0, -8.5, 5.60]},
	{"name": "03_east_road_mouth", "pos": [13.0, -18.5, 1.68],
		"look": [27.0, -19.3, 1.25]},
]

var root: Node3D
var cam: Camera3D
var _frame_serial := 0
var _capture_failed := false
var _hold_orison_core_shadows := false


func _ready() -> void:
	process_priority = 1000
	if OS.get_environment("DAYNIGHT_FORCE") == "":
		OS.set_environment("DAYNIGHT_FORCE", "night")
	if OS.get_environment("WEATHER_SEED") == "":
		OS.set_environment("WEATHER_SEED", "19280731")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	_hide_capture_ui(get_tree().root)
	cam = Camera3D.new()
	cam.fov = 72.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	root.player.set_physics_process(false)
	var requested := OS.get_environment("SHOT_STATION")
	var captured := 0
	var captures_per_station := 3 \
			if OS.get_environment("WEATHER_CORE_SHADOW_PAIR") == "1" else 1
	for station: Dictionary in STATIONS:
		if requested != "" and requested != station.name:
			continue
		await _capture_blender(station.name, station.pos, station.look)
		captured += captures_per_station
	if requested == "" or requested == "04_roof_skyline":
		await _capture_godot("04_roof_skyline",
				Vector3(-6.0, 21.4, 9.5), Vector3(-6.0, 19.8, 60.0))
		captured += captures_per_station
		if OS.get_environment("CLOUD_MOTION_PROOF") == "1":
			var motion_seconds := 20.0
			if OS.get_environment("CLOUD_MOTION_SECONDS").is_valid_float():
				motion_seconds = float(OS.get_environment("CLOUD_MOTION_SECONDS"))
			await get_tree().create_timer(motion_seconds).timeout
			await _capture_godot("04b_roof_cloud_plus_%ds" % int(motion_seconds),
					Vector3(-6.0, 21.4, 9.5), Vector3(-6.0, 19.8, 60.0))
			captured += captures_per_station
	if requested == "" or requested == "05_atrium_skylight":
		await _capture_godot("05_atrium_skylight",
				Vector3(0.0, 1.75, 1.58), Vector3(0.12, 15.0, 0.10))
		captured += captures_per_station
	print("[WEATHER SKY SHOT] %s" % ["capture failed" if _capture_failed
			else "%d frame(s) saved" % captured])
	get_tree().quit(1 if _capture_failed else 0)


func _capture_blender(label: String, eye: Array, target: Array) -> void:
	await _capture_godot(label, GameBoot.b2g(eye), GameBoot.b2g(target))


func _capture_godot(label: String, eye: Vector3, target: Vector3) -> void:
	cam.global_position = eye
	cam.look_at(target)
	# Weather follows the production player, not diagnostic cameras. Park the
	# inert player at the lens so this proof exercises the same exposure query
	# and emitter placement an actual player sees at every station.
	root.player.global_position = eye - Vector3(0.0, 1.41, 0.0)
	root.player.velocity = Vector3.ZERO
	# These are player viewpoints. BuildingRoot streams from controller feet in
	# production; the detached camera override would admit the storey above at
	# pavement eye height. LightRig still derives occupied height from the lens.
	root.view_override = null
	await get_tree().create_timer(1.0).timeout
	# Same-process visual proof for T7b. Start this mode with
	# PERF_STREET_CORE_SHADOWS_ON=1 so the first two frames reproduce the old
	# production state, pause every scene owner, then change exactly the eleven
	# core fixture shadow flags before the third frame. Two controls price any
	# renderer/particle movement that survives the pause.
	if OS.get_environment("WEATHER_CORE_SHADOW_PAIR") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		root.light_rig.set_process(false)
		get_tree().paused = true
		await _save_current_frame(label + "_control_a")
		await _save_current_frame(label + "_control_b")
		_suppress_orison_core_light_shadows(root)
		await _save_current_frame(label + "_final")
		get_tree().paused = false
		return
	if OS.get_environment("WEATHER_FREEZE_LIGHTS") == "1" \
			or OS.get_environment("WEATHER_ORISON_CORE_SHADOWS_OFF") == "1":
		root.light_rig.set_process(false)
	if OS.get_environment("WEATHER_ORISON_CORE_SHADOWS_OFF") == "1":
		_hold_orison_core_shadows = true
		_suppress_orison_core_light_shadows(root)
	await _save_current_frame(label)


func _save_current_frame(label: String) -> void:
	var expected_frame := _frame_serial + 1
	RenderingServer.frame_post_draw.connect(_mark_frame, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + 2000
	while _frame_serial < expected_frame and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if RenderingServer.frame_post_draw.is_connected(_mark_frame):
		RenderingServer.frame_post_draw.disconnect(_mark_frame)
	if _frame_serial < expected_frame:
		_capture_failed = true
		push_error("No rendered frame arrived for %s" % label)
		return
	var out_dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))


func _mark_frame() -> void:
	_frame_serial += 1


func _process(_delta: float) -> void:
	if _hold_orison_core_shadows and root != null:
		_suppress_orison_core_light_shadows(root, false)


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_capture_ui(child)


func _suppress_orison_core_light_shadows(scene_root: Node,
		report := true) -> int:
	var pending: Array[Node] = [scene_root]
	var suppressed := 0
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is SubViewport:
			continue
		if node is Light3D and not (node is DirectionalLight3D):
			var light := node as Light3D
			var p := light.global_position
			if light.shadow_enabled \
					and absf(p.x) <= LightRig.ORISON_CORE_HALF_X \
					and absf(p.z) <= LightRig.ORISON_CORE_HALF_Z:
				light.shadow_enabled = false
				suppressed += 1
		for child in node.get_children():
			pending.append(child)
	if report:
		print("[WEATHER SKY SHOT] ORISON-core shadows off: %d lights"
				% suppressed)
	return suppressed
