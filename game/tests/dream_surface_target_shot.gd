extends Node
## THE OWNER'S ORGANIC ORISON TARGET, photographed in the production dream.
##
##     SHOT_DIR=<abs> godot --path game --resolution 1280x720 \
##             res://tests/DreamSurfaceTargetShot.tscn
##
## No helper light, environment, furniture, hazard or presentation geometry is
## added. The harness chooses a deterministic live descendant carrying two
## existing dark-live hazards and moves the real player/lamp into it. The
## oblique light reads its decorated walls without adding a beauty rig.

const SEED_HEX := "f123456789abcdef"

var root: DreamMazeRoot
var out_dir := ""
var failures := 0
var breach_record: Dictionary = {}
var portal_feed_dumped := false


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	var hazard := _stage_camera()
	if hazard == null:
		failures += 1
		printerr("[DREAM TARGET SHOT] no dark-live hazard in staged pocket")
		get_tree().quit(failures)
		return
	_settle_lamp(true)
	_seed_ruled_dwell()
	await _capture("01_furnished_breach_lamp_on", 75)
	await _capture("02_furnished_breach_motion", 150)
	_settle_lamp(false)
	await _capture("03_furnished_breach_dark_live", 75)
	print("[DREAM TARGET SHOT] 3 frames, findings=%d" % failures)
	get_tree().quit(failures)


func _build() -> void:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	root = scene.instantiate() as DreamMazeRoot
	root.autonomous = false
	root.configure_dream({
		"case_id": "mina_caption_crisis",
		"profile_id": "mina_release_print",
		"window": {},
		"seed_hex": SEED_HEX,
		"maze_revision": 1,
		"outcome": "",
		"night_index": 7,
		"spawn_anchor": 0,
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
		# The long hall carries Mina's runner and gives the growth enough depth
		# to be photographed from outside its contact radius.
		if str(room.source) == "D01_F04_LONG_HALL":
			chosen = path
			found = true
			break
		examined += 1
	if not found:
		failures += 1
		printerr("[DREAM TARGET SHOT] no furnished parent with dark child")
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


func _source_is_dark_hazard(source: String) -> bool:
	return source in ["D01_F04_LONG_HALL", "D03_LIFT_VOID"]


func _stage_camera() -> DreamHazard:
	var here_key := str(root.get("_here_key"))
	var here: Dictionary = root.rooms.room_at_key(here_key)
	if here.is_empty():
		return null
	var growth := root.get("_hazard_growth") as MeshInstance3D
	var breach: Dictionary = growth.get_meta("breach_record", {}) \
			if growth != null else {}
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
	var rect: Array = _rect_for(str(breach.get("module", here_key)))
	if rect.is_empty():
		return null
	var width := float(rect[2]) - float(rect[0])
	var depth := float(rect[3]) - float(rect[1])
	var focus: Vector3 = breach.center
	var normal: Vector3 = breach.normal
	var side: Vector3 = breach.side
	var short_extent := minf(width, depth)
	var long_extent := maxf(width, depth)
	# Stand inside the same Atlas room and look obliquely across the torn edge.
	# The parallax angle is what distinguishes a wall-thin texture from the
	# authored false volume, while the wide context keeps the Orison/flesh
	# balance judgeable instead of turning this into a material close-up.
	var away_from_root := focus - Vector3(chosen.position.x, focus.y,
			chosen.position.z)
	away_from_root -= normal * away_from_root.dot(normal)
	if away_from_root.length() < 0.01:
		away_from_root = side
	else:
		away_from_root = away_from_root.normalized()
	var stand := focus + normal * minf(1.38, short_extent * 0.64) \
			+ away_from_root * minf(1.35, long_extent * 0.10)
	stand.y = 0.0
	stand.x = clampf(stand.x, float(rect[0]) + 0.58,
			float(rect[2]) - 0.58)
	stand.z = clampf(stand.z, float(rect[1]) + 0.58,
			float(rect[3]) - 0.58)
	root.player.global_position = stand
	var flat := focus - stand
	flat.y = 0.0
	if flat.length() > 0.01:
		root.player.rotation.y = atan2(flat.x, -flat.z)
	root.player.camera.look_at(focus, Vector3.UP)
	root.player.camera.fov = 70.0
	print("[DREAM TARGET SHOT] breach=%s room=%s center=%s normal=%s stand=%s" % [
			str(breach.get("id", "")), str(breach.get("module", "")),
			str(focus), str(normal), str(stand)])
	# The normal player process chases the hand/tool aim toward the camera.
	# This proof freezes that process, so settle the real spotlight on the same
	# focal point once instead of leaving it aimed at its pre-teleport pose.
	root.player.flashlight.look_at(focus, Vector3.UP)
	# Production physics lights the first receding practical before the player
	# can inspect this room. The proof freezes physics immediately after its
	# teleport, so advance that same production owner once rather than leaving
	# the R6 destination uniquely black in the capture harness.
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
	# The camera and topology are frozen for a repeatable shot, so the normal
	# per-frame tungsten transient cannot advance itself. Put the production
	# player lamp at the same settled endpoint that _advance_lamp() reaches;
	# this is not a helper light and does not change its pose, range or cone.
	root.player.set_lamp_enabled(on)
	root.player.set("_lamp_phase", 0.0)
	root.player.set("_lamp_phase_total", 0.0)
	root.player.flashlight.visible = on
	root.player.flashlight.light_energy = 1.1 if on else 0.0
	root.player.call("_advance_lamp", 0.0)
	root.call("_update_molten")


## Optional production-owner staging for relief review.  A normal capture
## leaves the field exactly as the selected room inherited it. R2 proof sets
## DREAM_TARGET_DWELL_S to represent a deliberate stationary lamp hold without
## waiting that many real seconds: the real DreamExposureField performs the
## write, the real texture receives it, and no shader or showcase-only mask is
## bypassed.
func _seed_ruled_dwell() -> void:
	var dwell_s := OS.get_environment("DREAM_TARGET_DWELL_S").to_float()
	var centre: Vector3 = breach_record.get("center", Vector3.ZERO)
	var before := root.exposure.sample(centre) if root.exposure != null else 0.0
	if dwell_s <= 0.0 or root.exposure == null:
		print("[DREAM TARGET SHOT] phase dwell=0.00 exposure=%.4f" % before)
		return
	var pose: Dictionary = root.player.lamp_pose()
	if pose.is_empty():
		return
	root.exposure.add_lamp(pose.origin, pose.dir, float(pose.range),
			cos(deg_to_rad(float(pose.angle_deg))), float(pose.energy), dwell_s)
	root.exposure.upload(root.get("_exposure_tex") as ImageTexture3D)
	root.call("_update_molten")
	print("[DREAM TARGET SHOT] phase dwell=%.2f exposure=%.4f->%.4f" % [
			dwell_s, before, root.exposure.sample(centre)])


func _capture(file_name: String, frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame
		# Freeze topology and the player camera, but keep feeding the production
		# lamp pose to the real materials. Shader TIME continues independently.
		root.call("_update_molten")
	await RenderingServer.frame_post_draw
	if not portal_feed_dumped \
			and OS.get_environment("DREAM_PORTAL_FEED_DUMP") == "1":
		var portal := root.get("_view_portal") as SubViewport
		if portal != null and portal.get_texture() != null:
			var portal_image := portal.get_texture().get_image()
			var portal_path := out_dir.path_join("00_portal_feed_debug.png")
			if portal_image != null and not portal_image.is_empty() \
					and portal_image.save_png(portal_path) == OK:
				portal_feed_dumped = true
				print("[DREAM TARGET SHOT] saved %s" % portal_path)
	var image := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(file_name + ".png")
	var error := image.save_png(path)
	if error != OK:
		failures += 1
		printerr("[DREAM TARGET SHOT] failed to save %s (%d)" % [path, error])
	else:
		print("[DREAM TARGET SHOT] saved %s" % path)
