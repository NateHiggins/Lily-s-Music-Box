extends Node
## EN-1 — THE LAYER MODEL AS FRAMES (design/DREAM_ENCROACHMENT_BRIEF.md).
##
##     SHOT_DIR=<abs existing dir> godot --path game res://tests/DreamLayersShot.tscn
##     DREAM_LAYERS_DWELL_S=36    lamp dwell seeded across the wall for the high state
##
## Stages the same deterministic Atlas pocket DreamSurfaceTargetShot uses (a
## furnished room from D01_F04_LONG_HALL with a governed breach), stands the
## player's camera at the breached wall, and photographs, from that one
## camera: the shipping Klimt surface latent and at high retained exposure;
## then the EN-1 probe surface (game/tests/dream_layers_probe.gdshader) one
## layer at a time — base, +flesh, +skin, +weld, +portal — at the same high
## exposure, and the full stack latent. The probe carries the Klimt material's
## own base maps and plate and receives the root's exposure/lamp uniforms
## through the same collector, so only the layer model differs.
##
## Nothing in production changes: the probe lives under tests and the swap
## is a material_override the harness puts on and takes off.

const SEED_HEX := "f123456789abcdef"
const PROBE := preload("res://tests/dream_layers_probe.gdshader")
const FRAMES_SETTLE := 6
const COST_FRAMES := 36

var root: DreamMazeRoot
var out_dir := ""
var failures := 0
var breach_record: Dictionary = {}
var _originals: Dictionary = {}      # GeometryInstance3D -> ShaderMaterial
var _probes: Dictionary = {}         # GeometryInstance3D -> ShaderMaterial


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _build()
	var hazard := _stage_camera()
	if hazard == null:
		printerr("[DREAM LAYERS] no breach to stand at")
		get_tree().quit(1)
		return
	_settle_lamp(true)
	var growth := root.get("_hazard_growth") as MeshInstance3D
	# Latent pair first: shipping, then the whole probe stack, before any dwell.
	await _capture("00_klimt_latent", 0)
	_swap_to_probe(31)
	await _capture("01_probe_stack_latent", 31)
	_restore()
	# A radial high state from one held lamp at the wound: the wall then shows
	# the whole progression across its width, plaster to weld, in one frame.
	var dwell := 24.0
	var env_dwell := OS.get_environment("DREAM_LAYERS_DWELL_S")
	if not env_dwell.is_empty():
		dwell = env_dwell.to_float()
	_seed_centre(dwell * 0.33)
	await _capture("02_klimt_mid", 0)
	_swap_to_probe(31)
	await _capture("03_probe_stack_mid", 31)
	_restore()
	_seed_centre(dwell * 0.67)
	await _capture("04_klimt_high", 0)
	if growth != null:
		growth.visible = false
	_swap_to_probe(1)
	await _capture("05_probe_base", 1)
	_set_probe_mask(3)
	await _capture("06_probe_flesh", 3)
	_set_probe_mask(7)
	await _capture("07_probe_skin", 7)
	_set_probe_mask(15)
	await _capture("08_probe_weld", 15)
	_set_probe_mask(31)
	await _capture("09_probe_stack_high", 31)
	if growth != null:
		growth.visible = true
	await _capture("10_probe_stack_high_with_limbs", 31)
	_restore()
	print("[DREAM LAYERS] DONE failures=%d" % failures)
	get_tree().quit(failures)


func _build() -> void:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	root = scene.instantiate() as DreamMazeRoot
	root.autonomous = false
	root.configure_dream({
		"case_id": "mina_caption_crisis", "profile_id": "mina_release_print",
		"window": {}, "seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
		"night_index": 7, "spawn_anchor": 0,
	})
	add_child(root)
	await get_tree().process_frame
	root.player.set_physics_process(false)
	root.pursuer.set_physics_process(false)
	root.pursuer.visible = false
	_stage_target_pocket()
	await get_tree().process_frame
	root.player.camera.make_current()


func _stage_target_pocket() -> void:
	var atlas: DreamAtlas = root.rooms.atlas
	var queue: Array[PackedInt32Array] = [PackedInt32Array()]
	var chosen := PackedInt32Array()
	var found := false
	var examined := 0
	while not queue.is_empty() and examined < 2400:
		var path: PackedInt32Array = queue.pop_front()
		var room: Dictionary = atlas.room(path)
		for door_index in int(room.doors):
			var child := DreamAtlas.step(path, door_index)
			if path.size() < 8:
				queue.append(child)
		if str(room.source) == "D01_F04_LONG_HALL":
			chosen = path
			found = true
			break
		examined += 1
	if not found:
		failures += 1
		printerr("[DREAM LAYERS] no furnished parent with dark child")
		return
	var key := DreamRoomBuilder.key_of(chosen)
	root.rooms.advance(root.get("_architecture") as Node3D, chosen)
	root.rooms.write_plan(root.plan, key)
	root.set("_here_path", chosen)
	root.set("_here_key", key)
	root.hazards.rearm(root.plan, root.profile_hazards)
	root.call("_rebuild_practicals")
	root.call("_rebuild_hazard_growth")
	root.call("_collect_molten_materials")


func _stage_camera() -> DreamHazard:
	var growth := root.get("_hazard_growth") as MeshInstance3D
	var breach: Dictionary = growth.get_meta("breach_record", {}) if growth != null else {}
	if breach.is_empty():
		return null
	breach_record = breach
	var chosen: DreamHazard = null
	for hazard in root.hazards.hazards:
		if hazard.id == str(breach.get("hazard_id", "")):
			chosen = hazard
			break
	if chosen == null:
		return null
	var focus: Vector3 = breach.center
	var normal: Vector3 = breach.normal
	var side: Vector3 = breach.side
	# The target harness's stand, verbatim in spirit: inside the room rect,
	# a little over a metre off the wall on the side away from the hazard
	# root, feet on the floor, camera looking at the wound.
	var rect: Array = _rect_for(str(breach.get("module", str(root.get("_here_key")))))
	if rect.is_empty():
		return null
	var width := float(rect[2]) - float(rect[0])
	var depth := float(rect[3]) - float(rect[1])
	var short_extent := minf(width, depth)
	var long_extent := maxf(width, depth)
	var away_from_root := focus - Vector3(chosen.position.x, focus.y, chosen.position.z)
	away_from_root -= normal * away_from_root.dot(normal)
	if away_from_root.length() < 0.01:
		away_from_root = side
	else:
		away_from_root = away_from_root.normalized()
	var stand := focus + normal * minf(1.38, short_extent * 0.64) 			+ away_from_root * minf(1.35, long_extent * 0.10)
	stand.y = 0.0
	stand.x = clampf(stand.x, float(rect[0]) + 0.58, float(rect[2]) - 0.58)
	stand.z = clampf(stand.z, float(rect[1]) + 0.58, float(rect[3]) - 0.58)
	root.player.global_position = stand
	var flat := focus - stand
	flat.y = 0.0
	if flat.length() > 0.01:
		root.player.rotation.y = atan2(flat.x, -flat.z)
	root.player.camera.look_at(focus, Vector3.UP)
	root.player.camera.fov = 70.0
	print("[DREAM LAYERS] breach=%s room=%s center=%s normal=%s stand=%s" % [
			str(breach.get("id", "")), str(breach.get("module", "")), str(focus), str(normal), str(stand)])
	root.player.flashlight.look_at(focus, Vector3.UP)
	root.call("_update_practical")
	root.player.set_process(false)
	root.set_physics_process(false)
	return chosen


func _rect_for(room_id: String) -> Array:
	for entry in root.plan.get("modules", []):
		if str(entry.get("id", "")) == room_id:
			return entry.get("rect", [])
	return []


func _settle_lamp(on: bool) -> void:
	root.player.set_lamp_enabled(on)
	root.player.pin_lamp_gutter_for_proof(1.0)
	root.player.set("_lamp_phase", 0.0)
	root.player.set("_lamp_phase_total", 0.0)
	root.player.flashlight.visible = on
	root.player.flashlight.light_energy = 1.1 if on else 0.0
	root.player.call("_advance_lamp", 0.0)
	root.call("_update_molten")


## One held lamp at the wound: retained exposure falls off radially from it,
## so one frame carries the whole progression.
func _seed_centre(dwell_s: float) -> void:
	if root.exposure == null or breach_record.is_empty():
		return
	var centre: Vector3 = breach_record.center
	var normal: Vector3 = breach_record.normal
	var before := root.exposure.sample(centre)
	root.exposure.add_lamp(centre + normal * 1.25, -normal, 2.5,
			cos(deg_to_rad(34.0)), 1.0, dwell_s)
	root.exposure.upload(root.get("_exposure_tex") as ImageTexture3D)
	root.call("_update_molten")
	if root.has_method("_update_intrusion"):
		root.call("_update_intrusion", 0.0)
	if root.has_method("_update_phase_reflected_light"):
		root.call("_update_phase_reflected_light")
	print("[DREAM LAYERS] dwell %.1f s: exposure at breach %.3f -> %.3f, 1 m aside %.3f"
			% [dwell_s, before, root.exposure.sample(centre),
			root.exposure.sample(centre + breach_record.side * 1.0)])


## Every Klimt surface of the live pocket takes the probe, carrying its own
## base maps, tile size and plate.
func _swap_to_probe(mask: int) -> void:
	_restore()
	var architecture := root.get("_architecture") as Node3D
	if architecture == null:
		return
	var swapped := 0
	for node in architecture.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		var klimt := geometry.material_override as ShaderMaterial
		if klimt == null or klimt.shader == null \
				or not klimt.shader.resource_path.ends_with("dream_klimt.gdshader"):
			continue
		var probe := ShaderMaterial.new()
		probe.shader = PROBE
		for slot in ["base_albedo", "base_normal", "base_rough"]:
			var tex: Variant = klimt.get_shader_parameter(slot)
			if tex != null:
				probe.set_shader_parameter(slot, tex)
		var tile: Variant = klimt.get_shader_parameter("base_tile_m")
		if tile != null:
			probe.set_shader_parameter("base_tile_m", float(tile))
		var gain: Variant = klimt.get_shader_parameter("exposure_gain")
		if gain != null:
			probe.set_shader_parameter("exposure_gain", float(gain))
		probe.set_shader_parameter("layer_mask", mask)
		_originals[geometry] = klimt
		_probes[geometry] = probe
		geometry.material_override = probe
		swapped += 1
	# The root's collector now sees the probes and pushes exposure_tex, the
	# lamp pose and the incarnation bundle into them like any other surface.
	root.call("_collect_molten_materials")
	root.call("_update_molten")
	print("[DREAM LAYERS] probe on %d surfaces, mask %d" % [swapped, mask])


func _set_probe_mask(mask: int) -> void:
	for geometry in _probes:
		(_probes[geometry] as ShaderMaterial).set_shader_parameter("layer_mask", mask)


func _restore() -> void:
	for geometry in _originals:
		if is_instance_valid(geometry):
			(geometry as GeometryInstance3D).material_override = _originals[geometry]
	_originals.clear()
	_probes.clear()
	root.call("_collect_molten_materials")
	root.call("_update_molten")


func _capture(file_name: String, mask: int) -> void:
	for _frame in FRAMES_SETTLE:
		await get_tree().process_frame
		root.call("_update_molten")
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(file_name + ".png")
	var err := image.save_png(path)
	var compiled := not PROBE.get_shader_uniform_list().is_empty()
	# Cost of this exact frame state: GPU median over COST_FRAMES, vsync off.
	var vp_rid := get_viewport().get_viewport_rid()
	var samples: Array[float] = []
	for _i in COST_FRAMES:
		await RenderingServer.frame_post_draw
		samples.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
	samples.sort()
	var gpu := samples[samples.size() / 2]
	var calls := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("[DREAM LAYERS] %s mask=%d %s probe_compiled=%s gpu_median_ms=%.3f draw_calls=%d"
			% [file_name, mask, "ok" if err == OK else "SAVE FAILED %d" % err,
			compiled, gpu, calls])
	if err != OK:
		failures += 1
