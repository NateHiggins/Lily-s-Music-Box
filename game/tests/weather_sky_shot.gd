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
	if OS.get_environment("DAYNIGHT_FORCE") == "" \
			and OS.get_environment("CELESTIAL_REALTIME") != "1":
		OS.set_environment("DAYNIGHT_FORCE", "night")
	if OS.get_environment("WEATHER_SEED") == "":
		OS.set_environment("WEATHER_SEED", "19280731")
	if OS.get_environment("CELESTIAL_PHASE_PAIR") == "1" \
			or OS.get_environment("CELESTIAL_SIDEREAL_PAIR") == "1":
		# A terminator proof needs a clear line of sight. This selects the public
		# deterministic weather simulation before production assembly.
		OS.set_environment("WEATHER_SIMULATE", "clear")
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
	var destructive_pair := OS.get_environment("WEATHER_CORE_SHADOW_PAIR") == "1" \
			or OS.get_environment("WEATHER_STREET_CORE_PAIR") == "1" \
			or OS.get_environment("WEATHER_HARUKIYA_PAIR") == "1" \
			or OS.get_environment("PERIOD_AIRMAIL_PAIR") == "1" \
			or OS.get_environment("CELESTIAL_PHASE_PAIR") == "1" \
			or OS.get_environment("CELESTIAL_SIDEREAL_PAIR") == "1"
	if destructive_pair and requested == "":
		push_error("A destructive A/A/B mode requires one SHOT_STATION; "
				+ "its final state cannot become the next station's control")
		get_tree().quit(1)
		return
	var captured := 0
	var captures_per_station := 3 \
			if OS.get_environment("WEATHER_CORE_SHADOW_PAIR") == "1" \
			or OS.get_environment("WEATHER_STREET_CORE_PAIR") == "1" \
			or OS.get_environment("WEATHER_HARUKIYA_PAIR") == "1" \
			or OS.get_environment("PERIOD_AIRMAIL_PAIR") == "1" \
			or OS.get_environment("CELESTIAL_PHASE_PAIR") == "1" \
			or OS.get_environment("CELESTIAL_SIDEREAL_PAIR") == "1" else 1
	for station: Dictionary in STATIONS:
		if requested != "" and requested != station.name:
			continue
		await _capture_blender(station.name, station.pos, station.look)
		captured += captures_per_station
	var street_only := OS.get_environment("SHOT_STREET_ONLY") == "1"
	if not street_only and (requested == "" or requested == "04_roof_skyline"):
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
	if not street_only and (requested == "" or requested == "05_atrium_skylight"):
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
	if label == "04_roof_skyline" \
			and OS.get_environment("CELESTIAL_SIDEREAL_PAIR") == "1":
		await _capture_sidereal_pair(label)
		return
	if label == "04_roof_skyline" \
			and OS.get_environment("CELESTIAL_PHASE_PAIR") == "1":
		await _capture_lunar_phase_pair(label, eye)
		return
	var airmail_proof := label == "04_roof_skyline" \
			and (OS.get_environment("PERIOD_AIRMAIL_SHOT") == "1" \
			or OS.get_environment("PERIOD_AIRMAIL_PAIR") == "1")
	if airmail_proof:
		root.period_reality.set_live_conditions({
			"cloud_low": 0.0, "precipitation_intensity": 0.0,
			"wind_speed_kmh": 14.0, "wind_direction_deg": 245.0,
			"weather_code": 0,
		})
		root.period_reality.start_airmail_pass()
		root.period_reality._process(PeriodRealityLayer.AIR_DURATION * 0.82)
		root.period_reality.set_process(false)
		var mailwing := root.period_reality.get_node("CAM19Mailwing") as MeshInstance3D
		cam.look_at(mailwing.global_position)
		label = "04_roof_airmail"
		if OS.get_environment("PERIOD_AIRMAIL_PAIR") == "1":
			process_mode = Node.PROCESS_MODE_ALWAYS
			mailwing.visible = false
			get_tree().paused = true
			await _save_current_frame(label + "_control_a")
			await _save_current_frame(label + "_control_b")
			mailwing.visible = true
			await _save_current_frame(label + "_final")
			get_tree().paused = false
			return
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
	# Same-process production proof for T7c. The retained control environment
	# keeps the gate open for A/A; the final applies BuildingRoot's exact index.
	if OS.get_environment("WEATHER_STREET_CORE_PAIR") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		root.light_rig.set_process(false)
		get_tree().paused = true
		await _save_current_frame(label + "_control_a")
		await _save_current_frame(label + "_control_b")
		_suppress_street_core_geometry(root)
		await _save_current_frame(label + "_final")
		get_tree().paused = false
		return
	# T7d isolates the second, dimensioned Harukiya prism from T7c's existing
	# central-core gate. Start with PERF_STREET_HARUKIYA_GEOMETRY_ON=1.
	if OS.get_environment("WEATHER_HARUKIYA_PAIR") == "1":
		process_mode = Node.PROCESS_MODE_ALWAYS
		root.light_rig.set_process(false)
		get_tree().paused = true
		await _save_current_frame(label + "_control_a")
		await _save_current_frame(label + "_control_b")
		_suppress_harukiya_geometry(root)
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


func _capture_sidereal_pair(label: String) -> void:
	var dome := root.get_node("NightSkyHalfDome") as MeshInstance3D
	var sky := dome.material_override as ShaderMaterial
	var utc_a := {"year": 2026, "month": 8, "day": 26,
			"hour": 2, "minute": 0}
	var utc_b := {"year": 2026, "month": 8, "day": 26,
			"hour": 8, "minute": 0}
	root.day_night_director.set_process(false)
	root.light_rig.set_process(false)
	_set_sidereal_axes(sky, CelestialEphemeris.equatorial_axes(
			utc_a, 40.75, -73.92))
	await _save_current_frame(label + "_sidereal_control_a")
	await _save_current_frame(label + "_sidereal_control_b")
	_set_sidereal_axes(sky, CelestialEphemeris.equatorial_axes(
			utc_b, 40.75, -73.92))
	await _save_current_frame(label + "_sidereal_plus_6h")


func _set_sidereal_axes(sky: ShaderMaterial,
		axes: PackedVector3Array) -> void:
	sky.set_shader_parameter("equatorial_axis_x", axes[0])
	sky.set_shader_parameter("equatorial_axis_y", axes[1])
	sky.set_shader_parameter("equatorial_axis_z", axes[2])


func _capture_lunar_phase_pair(label: String, eye: Vector3) -> void:
	# Observe the production dome at its production 0.54-degree diameter. The
	# declared 8-degree lens is an observational close-up, not a larger Moon.
	var dome := root.get_node("NightSkyHalfDome") as MeshInstance3D
	var sky := dome.material_override as ShaderMaterial
	var moon := Vector3(0.0, 0.34, 0.94).normalized()
	var side := moon.cross(Vector3.UP).normalized()
	cam.fov = 8.0
	cam.look_at(eye + moon * 100.0)
	sky.set_shader_parameter("celestial_direction", moon)
	sky.set_shader_parameter("celestial_core_radius", deg_to_rad(0.27))
	sky.set_shader_parameter("celestial_strength", 1.0)
	sky.set_shader_parameter("moon_phase_enabled", true)
	sky.set_shader_parameter("moon_illumination", 1.0)
	sky.set_shader_parameter("sun_direction", -moon)
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.day_night_director.set_process(false)
	root.light_rig.set_process(false)
	await _save_current_frame(label + "_full_control_a")
	await _save_current_frame(label + "_full_control_b")
	# cos(elongation)=0.70 gives (1-cos)/2 = 0.15 illumination.
	var crescent_sun := (moon * 0.70 + side * sqrt(0.51)).normalized()
	sky.set_shader_parameter("sun_direction", crescent_sun)
	sky.set_shader_parameter("moon_illumination", 0.15)
	await _save_current_frame(label + "_crescent_final")


func _save_current_frame(label: String) -> void:
	# Godot 4.7's headless Forward+ driver can complete the viewport without
	# emitting frame_post_draw. Two process frames are the actual contract we
	# need; validate the resulting image rather than waiting on that signal.
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_capture_failed = true
		push_error("No rendered frame arrived for %s" % label)
		return
	var out_dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	if image.save_png(out_dir.path_join(label + ".png")) != OK:
		_capture_failed = true
		push_error("Could not save rendered frame for %s" % label)


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


func _suppress_street_core_geometry(_scene_root: Node) -> int:
	# Reuse the production index rather than cloning its ownership law into the
	# visual instrument. Start this pair with PERF_STREET_CORE_GEOMETRY_ON=1.
	root._index_street_core_geometry()
	var suppressed := 0
	for geometry in root.street_core_nodes:
		if is_instance_valid(geometry) and geometry.layers != 0:
			geometry.layers = 0
			suppressed += 1
	print("[WEATHER SKY SHOT] STREET-core geometry off: %d objects" % suppressed)
	return suppressed


func _suppress_harukiya_geometry(_scene_root: Node) -> int:
	# Let the production index classify the wing with its normal compound-owner
	# protections, then touch only nodes inside the new prism. Existing T7c
	# core nodes are already gated in the control frames and remain untouched.
	root._street_harukiya_gate_enabled = true
	root._index_street_core_geometry()
	var suppressed := 0
	for geometry in root.street_core_nodes:
		if is_instance_valid(geometry) \
				and root._fully_in_harukiya_core(geometry) \
				and geometry.layers != 0:
			geometry.layers = 0
			suppressed += 1
	print("[WEATHER SKY SHOT] Harukiya geometry off: %d objects" % suppressed)
	return suppressed
