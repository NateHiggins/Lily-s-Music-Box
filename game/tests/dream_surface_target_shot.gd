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
	var chosen: DreamHazard = null
	for hazard in root.hazards.hazards:
		if hazard.module == here_key and hazard.condition != "lamp_on":
			chosen = hazard
			break
	if chosen == null:
		return null
	var rect: Array = here.rect
	var width := float(rect[2]) - float(rect[0])
	var depth := float(rect[3]) - float(rect[1])
	var axis := Vector3.RIGHT if width >= depth else Vector3.FORWARD
	var distance := minf(5.2, maxf(3.8, maxf(width, depth) * 0.31))
	var stands := [
		Vector3(chosen.position.x, 0.0, chosen.position.z) + axis * distance,
		Vector3(chosen.position.x, 0.0, chosen.position.z) - axis * distance,
	]
	var stand: Vector3 = stands[0]
	for candidate in stands:
		if candidate.x > float(rect[0]) + 0.56 \
				and candidate.x < float(rect[2]) - 0.56 \
				and candidate.z > float(rect[1]) + 0.56 \
				and candidate.z < float(rect[3]) - 0.56:
			stand = candidate
			break
	var short_axis := Vector3.FORWARD if width >= depth else Vector3.RIGHT
	var short_extent := minf(width, depth)
	# Put the hazard slightly off-centre and spend the beam on the wall where
	# its crawler becomes tissue.  The prior straight-on shot proved the limb
	# but left the architectural question in darkness.
	var focus := Vector3(chosen.position.x, 1.28, chosen.position.z) \
			+ short_axis * short_extent * 0.34
	root.player.global_position = stand
	var flat := focus - stand
	flat.y = 0.0
	if flat.length() > 0.01:
		root.player.rotation.y = atan2(flat.x, -flat.z)
	root.player.camera.look_at(focus, Vector3.UP)
	root.player.camera.fov = 78.0
	# The normal player process chases the hand/tool aim toward the camera.
	# This proof freezes that process, so settle the real spotlight on the same
	# focal point once instead of leaving it aimed at its pre-teleport pose.
	root.player.flashlight.look_at(focus, Vector3.UP)
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


func _capture(file_name: String, frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame
		# Freeze topology and the player camera, but keep feeding the production
		# lamp pose to the real materials. Shader TIME continues independently.
		root.call("_update_molten")
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(file_name + ".png")
	var error := image.save_png(path)
	if error != OK:
		failures += 1
		printerr("[DREAM TARGET SHOT] failed to save %s (%d)" % [path, error])
	else:
		print("[DREAM TARGET SHOT] saved %s" % path)
