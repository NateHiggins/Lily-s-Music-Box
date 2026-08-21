extends Node
## M-COVER — "bring frames, not adjectives". Photographs the same floors from
## the same stands under every anti-repetition option and prices each one.
##
##     COVER_DIR=<existing abs dir> godot --path game res://tests/CoverageShot.tscn
##     COVER_STATIONS=corridor,lobby        optional filter by station key
##     COVER_OPTIONS=current,hex            optional filter by option key
##
## Boot and lighting are FreeCam's: production fixtures as the rig budgets
## them, the player's own torch carried on the camera, no judging fill. The
## only thing that changes between frames of one stand is the FLOOR material:
## every `F0x_floors_*` surface of the station's floor is given the probe
## shader (game/tests/coverage_probe.gdshader) fed with the surface's own
## albedo / normal / roughness set, its own colour, roughness and metallic, so
## "current" and "plain" differ only by the material pipeline and every other
## option differs from "plain" by exactly its trick.
##
## Cost is measured where it lives, on the GPU: the viewport's measured render
## time over SAMPLE_FRAMES at each stand, plus CPU frame time, written to
## coverage.json beside the frames. The window is left at the project size so
## the frames compare with FreeCam's; the JSON records the size used.

const SAMPLE_FRAMES := 48
## Board rows across one 2.4 m oak tile, counted on the albedo map.
const OAK_ROWS_PER_TILE := 14
const SETTLE_FRAMES := 4
const PROBE := preload("res://tests/coverage_probe.gdshader")

const STATIONS := [
	{"key": "corridor", "floor": "F04", "pos": Vector3(4.3, 11.25, 7.6),
			"yaw": 0.0, "pitch": -2.0, "room": "F04_CORRIDOR"},
	{"key": "corridor_floor", "floor": "F04", "pos": Vector3(4.3, 10.75, 5.2),
			"yaw": 0.0, "pitch": -34.0, "room": "F04_CORRIDOR"},
	{"key": "lobby", "floor": "F01", "pos": Vector3(-0.4, 1.72, 9.1),
			"yaw": -58.0, "pitch": -6.0, "room": "F01_LOBBY"},
	{"key": "flat_4b", "floor": "F04", "pos": Vector3(-8.1, 11.25, -3.2),
			"yaw": 47.0, "pitch": -8.0, "room": "F04_B_MAIN"},
	{"key": "oak_floor", "floor": "F04", "pos": Vector3(-9.0, 10.75, -5.6),
			"yaw": 35.0, "pitch": -38.0, "room": "F04_B_MAIN"},
	{"key": "oak_floor_b", "floor": "F04", "pos": Vector3(-7.2, 10.75, -2.2),
			"yaw": -40.0, "pitch": -36.0, "room": "F04_B_MAIN"},
]

const OPTIONS := [
	{"key": "current", "mode": -1, "label": "shipping StandardMaterial3D"},
	{"key": "plain", "mode": 0, "label": "probe shader, one tap (control)"},
	{"key": "mirror", "mode": 1, "label": "per-tile mirror jitter, one tap"},
	{"key": "hex", "mode": 2, "label": "hex-grid stochastic, three taps"},
	{"key": "detail", "mode": 3, "label": "self-detail at 3.718x, two taps"},
	{"key": "hex_detail", "mode": 4, "label": "hex stochastic + self-detail"},
	{"key": "mirror_detail", "mode": 5, "label": "mirror jitter + self-detail"},
	{"key": "split", "mode": 6, "label": "hex with offsets snapped to the tile's 3x3 divider cells"},
	{"key": "rows", "mode": 7, "label": "per-board-row offset along the grain, one tap"},
]

var root
var cam: Camera3D
var _dir := ""
var _results := {}
var _probe_cache := {}
var _overridden: Array[Array] = []   # [mesh_instance, surface]


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	_dir = OS.get_environment("COVER_DIR")
	if _dir.is_empty():
		_dir = OS.get_user_data_dir()
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	_run()


func _run() -> void:
	await get_tree().create_timer(1.2).timeout
	if root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if root.fourth_wall:
		root.fourth_wall.force_finish()
	_hide_overlays(root)
	var player: PlayerController = root.player
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 220.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	# The torch rides the camera, as in FreeCam: it is the light the player
	# actually carries down this corridor.
	player.flashlight.visible = true
	player._light_mask.visible = true
	player.flashlight.reparent(cam)
	player.flashlight.transform = Transform3D(Basis(), Vector3(0.16, -0.19, -0.06))
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	# Cost is GPU time; a vsync cap would hide it behind a flat 16.7 ms.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var station_filter := OS.get_environment("COVER_STATIONS").split(",", false)
	var option_filter := OS.get_environment("COVER_OPTIONS").split(",", false)
	_results = {"window": str(DisplayServer.window_get_size()),
			"renderer": RenderingServer.get_current_rendering_method(),
			"sample_frames": SAMPLE_FRAMES, "stations": {}}
	for station in STATIONS:
		if not station_filter.is_empty() and not station_filter.has(station.key):
			continue
		_place(station.pos, station.yaw, station.pitch)
		_room_lights_on(str(station.room))
		await get_tree().create_timer(0.6).timeout
		# Warm every probe variant once before anything is timed: the first
		# use of a shader mode compiles it, and that stall landed inside the
		# first run's sample window as a 32 ms "plain".
		for option in OPTIONS:
			_apply_option(str(station.floor), int(option.mode))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
		_restore()
		var rows := {}
		for option in OPTIONS:
			if not option_filter.is_empty() and not option_filter.has(option.key):
				continue
			var swapped := _apply_option(str(station.floor), int(option.mode))
			for _i in SETTLE_FRAMES:
				await RenderingServer.frame_post_draw
			var gpu_samples: Array[float] = []
			var cpu_samples: Array[float] = []
			for _i in SAMPLE_FRAMES:
				var t0 := Time.get_ticks_usec()
				await RenderingServer.frame_post_draw
				cpu_samples.append(float(Time.get_ticks_usec() - t0) / 1000.0)
				gpu_samples.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
			gpu_samples.sort()
			cpu_samples.sort()
			var gpu := gpu_samples[gpu_samples.size() / 2]
			var cpu := cpu_samples[cpu_samples.size() / 2]
			var calls := RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			var path := _dir.path_join("%s__%s.png" % [station.key, option.key])
			await RenderingServer.frame_post_draw
			var err := get_viewport().get_texture().get_image().save_png(path)
			rows[option.key] = {"label": option.label, "mode": option.mode,
					"surfaces_swapped": swapped, "gpu_ms": gpu, "cpu_ms": cpu,
					"draw_calls": calls, "png": path, "save_error": err}
			print("[COVER] %-14s %-14s gpu %.3f ms  cpu %.3f ms  calls %d  swapped %d  %s"
					% [station.key, option.key, gpu, cpu, calls, swapped,
					"ok" if err == OK else "SAVE FAILED %d" % err])
			_restore()
		_results.stations[station.key] = rows
	var f := FileAccess.open(_dir.path_join("coverage.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_results, "  "))
		print("[COVER] wrote %s" % _dir.path_join("coverage.json"))
	print("[COVER] DONE")
	get_tree().quit(0)


func _place(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	cam.global_position = pos
	cam.rotation = Vector3.ZERO
	cam.rotate_y(deg_to_rad(yaw_deg))
	cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(pitch_deg))


## Production fixtures for the stand's room, exactly as FreeCam's SHOT_LIGHTS.
func _room_lights_on(room_id: String) -> void:
	if room_id.is_empty() or not ("switch_system" in root) or root.switch_system == null:
		return
	if not root.switch_system.toggle_room(room_id):
		root.switch_system.toggle_room(room_id)


## Every floor surface of one storey takes the probe with the given mode;
## mode -1 leaves the shipping materials in place (the "current" row).
func _apply_option(floor_id: String, mode: int) -> int:
	_restore()
	if mode < 0:
		return 0
	var floor_node: Node = root.floor_nodes.get(floor_id)
	if floor_node == null:
		return 0
	var swapped := 0
	for node in floor_node.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.name.contains("_floors_") or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var original := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if original == null or original.albedo_texture == null:
				continue
			var probe := _probe_for(original, mode)
			mi.set_surface_override_material(s, probe)
			_overridden.append([mi, s])
			swapped += 1
	return swapped


func _restore() -> void:
	for entry in _overridden:
		(entry[0] as MeshInstance3D).set_surface_override_material(int(entry[1]), null)
	_overridden.clear()


## One probe material per (shipping material, mode), carrying that material's
## own maps and scalars so nothing but the trick differs.
func _probe_for(original: BaseMaterial3D, mode: int) -> ShaderMaterial:
	var key := "%d|%d" % [original.get_instance_id(), mode]
	if _probe_cache.has(key):
		return _probe_cache[key]
	var stats := _texture_stats(original)
	var m := ShaderMaterial.new()
	m.shader = PROBE
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("albedo_tex", original.albedo_texture)
	m.set_shader_parameter("albedo_color", original.albedo_color)
	if original.normal_texture != null:
		m.set_shader_parameter("normal_tex", original.normal_texture)
		m.set_shader_parameter("normal_scale", original.normal_scale
				if original.normal_enabled else 0.0)
	else:
		m.set_shader_parameter("normal_scale", 0.0)
	if original.roughness_texture != null:
		m.set_shader_parameter("rough_tex", original.roughness_texture)
		m.set_shader_parameter("has_rough_tex", true)
	else:
		m.set_shader_parameter("has_rough_tex", false)
	m.set_shader_parameter("roughness_mul", original.roughness)
	m.set_shader_parameter("metallic", original.metallic)
	m.set_shader_parameter("albedo_mean", stats.albedo_mean)
	m.set_shader_parameter("rough_mean", stats.rough_mean)
	# Boards per tile across the grain, from the set's name; terrazzo and the
	# rest keep the default, which only matters to the ROW OFFSET mode.
	var tex_path := original.albedo_texture.resource_path
	if tex_path.contains("oak"):
		m.set_shader_parameter("rows_per_tile", float(OAK_ROWS_PER_TILE))
		# The oak map's seams run along V (29 dark column bands, 3 row bands
		# on the albedo): boards lie along V, rows step across U.
		m.set_shader_parameter("grain_along_u", false)
	_probe_cache[key] = m
	return m


## Means of the albedo and roughness maps, from a 64x64 resample. The
## variance-preserving blend is only preserving around the right mean.
func _texture_stats(original: BaseMaterial3D) -> Dictionary:
	var out := {"albedo_mean": Vector3(0.5, 0.5, 0.5), "rough_mean": 0.5}
	var img := original.albedo_texture.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
		var sum := Vector3.ZERO
		for y in 64:
			for x in 64:
				var c := img.get_pixel(x, y)
				sum += Vector3(c.r, c.g, c.b)
		out.albedo_mean = sum / 4096.0
	if original.roughness_texture != null:
		var rimg := original.roughness_texture.get_image()
		if rimg != null:
			if rimg.is_compressed():
				rimg.decompress()
			rimg.resize(64, 64, Image.INTERPOLATE_BILINEAR)
			var rsum := 0.0
			for y in 64:
				for x in 64:
					rsum += rimg.get_pixel(x, y).r
			out.rough_mean = rsum / 4096.0
	return out


func _hide_overlays(node: Node) -> void:
	for c in node.get_children():
		if c is CanvasLayer:
			c.visible = false
		elif c is Label3D and (c.name == "Nameplate"
				or node.is_in_group("resident_placeholders")):
			c.visible = false
		_hide_overlays(c)
