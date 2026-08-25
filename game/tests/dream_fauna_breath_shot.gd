extends Node
## LC-5 — production-root proof for the visible closed breath.
##
## No proof creature, gas volume, light or material exists here. The harness
## aims the production player and unreliable service lamp at analytical fauna
## addresses, then pins two presentation uniforms so a live shader can have a
## truthful A/A control despite Godot's global TIME continuing between frames.

const SEED_HEX := "f123456789abcdef"

var root: DreamMazeRoot
var out_dir := ""
var room_key := ""
var failures := 0
var frames := 0
var perf := {}


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	if not _prepare_room():
		get_tree().quit(1)
		return

	# The same production moss bed, same camera, same pinned shader phase. Only
	# the existing material's LC-5 contribution changes after the A/A pair.
	if not _aim_at("GildersButtons", 0.54):
		get_tree().quit(1)
		return
	_set_ether_picture(0.0, 1.25)
	await _capture("00_moss_control_a", 45)
	await _capture("00_moss_control_b", 45)
	_set_ether_picture(1.0, 1.25)
	await _capture("01_moss_exhale_phase_a", 45)
	_set_ether_picture(1.0, 2.05)
	await _capture("02_moss_exhale_phase_b", 45)

	# Two different organs, one byte from the same conserved room ledger.
	_aim_at("Tessellates", 0.72)
	_set_ether_picture(1.0, 1.25)
	await _capture("03_tessellate_inhales")
	_aim_at("WineAnemones", 0.62)
	await _capture("04_anemone_returns_stain")

	# The unreliable lamp is not bypassed. Price the same mat at the ruled deep
	# gutter and fully off; the cold trace may survive, but it owns no light.
	_aim_at("GildersButtons", 0.72)
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(0.35)
	root.player.call("_advance_lamp", 0.0)
	root.call("_update_molten")
	await _capture("05_moss_deep_gutter")
	root.player.set_lamp_enabled(false)
	root.player.set("_lamp_phase", 0.0)
	root.player.call("_advance_lamp", 0.0)
	root.call("_update_molten")
	await _capture("06_moss_lamp_off")

	# Restore ordinary animation for the contextual room frame. The close-ups
	# prove the mechanism; this one proves it belongs to the occupied room.
	_set_ether_picture(1.0, -1.0)
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(1.0)
	root.player.set("_lamp_phase", 0.0)
	root.player.call("_advance_lamp", 0.0)
	_aim_room_wide()
	await _capture("07_occupied_room")

	var monitor := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print("[LC5 SHOT] %d frames, findings=%d, draws=%s, census=%s, perf=%s"
			% [frames, failures, monitor, root.fauna.census(), perf])
	get_tree().quit(failures)


func _build() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id": "mina_caption_crisis",
			"profile_id": "mina_release_print", "window": {},
			"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
			"night_index": 3, "spawn_anchor": 1})
	add_child(root)
	await get_tree().process_frame
	root.set_physics_process(false)
	root.player.set_physics_process(false)
	root.pursuer.set_physics_process(false)
	root.pursuer.visible = false
	root.fauna.set_physics_process(false)
	root.player.camera.make_current()


func _prepare_room() -> bool:
	room_key = str(root.get("_here_key"))
	for _i in 24:
		root.call("_update_exposure", 0.25)
	for _i in 16:
		root.fauna.advance_fixed()
	root.fauna.refresh()
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(1.0)
	root.player.set("_lamp_phase", 0.0)
	root.player.set("_lamp_phase_total", 0.0)
	root.player.call("_advance_lamp", 0.0)
	root.call("_update_molten")
	for batch in root.fauna.get_children():
		var mm := batch as MultiMeshInstance3D
		if mm == null or mm.multimesh == null or mm.multimesh.mesh == null:
			continue
		var material := mm.multimesh.mesh.surface_get_material(0) as ShaderMaterial
		if material != null:
			material.set_shader_parameter("gait_amount", 0.0)
	return not root.fauna.cohorts_in_room(room_key).is_empty()


func _aim_at(batch_name: String, eye_height: float) -> bool:
	for cohort in root.fauna.cohorts_in_room(room_key):
		if str((cohort as Dictionary).get("batch", "")) != batch_name:
			continue
		var at: Vector3 = (cohort as Dictionary).position
		var room := root.rooms.room_at_key(room_key)
		var rect: Array = room.rect
		var centre := Vector3((float(rect[0]) + float(rect[2])) * 0.5, 0.0,
				(float(rect[1]) + float(rect[3])) * 0.5)
		var approach := centre - at
		approach.y = 0.0
		if approach.length() < 0.05:
			approach = Vector3(0.0, 0.0, 1.0)
		_stand(at + approach.normalized() * 0.88
				+ Vector3(0.0, eye_height, 0.0), at + Vector3(0.0, 0.08, 0.0))
		print("[LC5 SHOT] %s at %s life=%s" % [batch_name, at,
				(cohort as Dictionary).life])
		return true
	failures += 1
	printerr("[LC5 SHOT] no %s cohort in %s" % [batch_name, room_key])
	return false


func _aim_room_wide() -> void:
	var room := root.rooms.room_at_key(room_key)
	var rect: Array = room.rect
	var centre := Vector3((float(rect[0]) + float(rect[2])) * 0.5, 0.0,
			(float(rect[1]) + float(rect[3])) * 0.5)
	_stand(centre + Vector3(0.0, 1.45, 3.0), centre + Vector3(0.0, 0.18, 0.0))


func _stand(eye: Vector3, look: Vector3) -> void:
	root.player.global_position = eye - root.player.camera.position
	root.player.camera.look_at(look, Vector3.UP)
	root.call("_update_molten")


func _set_ether_picture(gain: float, clock: float) -> void:
	for batch in root.fauna.get_children():
		var mm := batch as MultiMeshInstance3D
		if mm == null or mm.multimesh == null or mm.multimesh.mesh == null:
			continue
		var material := mm.multimesh.mesh.surface_get_material(0) as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("ether_breath_gain", gain)
		material.set_shader_parameter("ether_time_override", clock)
		material.set_shader_parameter("fauna_time_override", clock)


func _capture(label: String, settle_frames := 45) -> void:
	var process_ms := 0.0
	var physics_ms := 0.0
	var draws := 0.0
	for _frame in settle_frames:
		await get_tree().process_frame
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(
				Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draws += Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	perf[label] = {"process_ms": process_ms / float(settle_frames),
			"physics_ms": physics_ms / float(settle_frames),
			"draws": draws / float(settle_frames)}
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(label + ".png")
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		failures += 1
		printerr("[LC5 SHOT] failed %s (%d)" % [path, error])
		return
	frames += 1
	print("[LC5 SHOT] saved %s %dx%d" % [path, image.get_width(),
			image.get_height()])
