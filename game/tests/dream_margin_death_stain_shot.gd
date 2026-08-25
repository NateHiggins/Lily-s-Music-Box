extends Node
## LC-6B — a production-born palp withdraws; its existing owner remembers the
## full anatomical silhouette after the live dictionary has been removed.

const Lifecycle = preload("res://scripts/dream/dream_organelle_lifecycle.gd")

var root: Node3D
var margin: DreamMarginController
var renderer: DreamPalpRenderer
var subject: Dictionary
var proof_camera: Camera3D
var out_dir := ""
var failures := 0
var frames := 0
var dead_id := -1
var mode_name := "quiescent"


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir().path_join("dream_margin_death_stain_lc6b")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = (load("res://scenes/building/orison_root.tscn") as PackedScene).instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(4.0).timeout
	var enc: Node = root.get("apartment_encroachment")
	if enc == null:
		return _fail("production encroachment owner was not built")
	margin = enc.get("margin")
	renderer = enc.get("palp_renderer")
	if margin == null or renderer == null:
		return _fail("production margin owner or renderer was not built")
	await get_tree().create_timer(5.0).timeout
	if not _choose_subject():
		return _fail("no production primary was born")

	margin.frozen = true
	margin.palps.clear()
	margin.palps.append(subject)
	root.set_physics_process(false)
	root.player.set_physics_process(false)
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(1.0)
	root.player.set_process(false)
	for overlay in root.find_children("*", "CanvasLayer", true, false):
		overlay.visible = false
	if root.player.carried_device != null:
		root.player.carried_device.visible = false
	proof_camera = Camera3D.new()
	proof_camera.fov = 34.0
	root.add_child(proof_camera)
	proof_camera.make_current()
	renderer.material.set_shader_parameter("palp_time_override", 23.0)
	_frame_subject()
	Engine.time_scale = 0.0

	subject.lifecycle_override = Lifecycle.Stage.MATURE
	subject.grow = 1.0
	renderer._process(0.0)
	await _capture("00_mature_control_a")
	await _capture("00_mature_control_b")

	# The attached last posture, followed by the real owner removal path.
	subject.lifecycle_override = -1
	subject.age = float(subject.life) * 0.94
	renderer._process(0.0)
	await _capture("01_shed_before_withdrawal")
	dead_id = int(subject.id)
	subject.age = float(subject.life) - 0.01
	margin._age(0.02)
	if not margin.palps.is_empty() or margin.impressions.size() != 1:
		return _fail("owner removal did not leave exactly one impression")
	if margin._pending_recruits.size() > 0:
		mode_name = Lifecycle.reproduction_name(
				int(margin._pending_recruits[0].mode))
	renderer._process(0.0)
	await _capture("02_stain_control_a")
	await _capture("02_stain_control_b")

	# Ordinary owner work continues and the same record is re-submitted. This
	# is a visit-memory proof, not a save/load claim.
	margin._age(3.0)
	renderer._process(0.0)
	await _capture("03_stain_after_owner_work")
	_write_readme()
	Engine.time_scale = 1.0
	print("[LC6B SHOT] %d production-root frames -> %s" % [frames, out_dir])
	get_tree().quit(failures)


func _choose_subject() -> bool:
	var best_length := -1.0
	for p in margin.palps:
		if int(p.parent) >= 0 or int(p.tier) != DreamMarginController.TIER_PRIMARY:
			continue
		if float(p.morph.length) > best_length:
			best_length = float(p.morph.length)
			subject = p
	if subject.is_empty():
		return false
	subject.lifecycle_override = Lifecycle.Stage.MATURE
	subject.grow = 1.0
	subject.extend = 1.0
	subject.aim = subject.normal
	subject.swell = 0.0
	subject.cilia_out = 0.0
	subject.task_left = 0.0
	return true


func _frame_subject() -> void:
	var normal: Vector3 = subject.normal
	var side: Vector3 = subject.side
	var stand_off := maxf(0.54, float(subject.morph.length) * 1.75)
	var wall_dir := (side * cos(float(subject.morph.seed_value) * 2.7)
			+ normal.cross(side) * sin(float(subject.morph.seed_value) * 2.7)).normalized()
	var look: Vector3 = subject.anchor + wall_dir * float(subject.morph.length) * 0.48
	var eye := look + normal * stand_off + side * stand_off * 0.68 \
			+ Vector3.UP * 0.08
	var camera_up := Vector3.UP if absf(normal.y) < 0.90 else side
	proof_camera.global_position = eye
	proof_camera.look_at(look, camera_up)
	root.player.global_position = eye - Vector3.UP * root.player.STANDING_EYE
	root.player._hand.global_transform = proof_camera.global_transform \
			* Transform3D(Basis(), Vector3(0.16, -0.19, -0.06))


func _capture(label: String) -> void:
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(label + ".png")
	var error := image.save_png(path)
	if error != OK:
		failures += 1
		printerr("[LC6B SHOT] failed %s (%d)" % [path, error])
		return
	frames += 1


func _write_readme() -> void:
	var stain: Dictionary = margin.impressions[0]
	var readme := FileAccess.open(out_dir.path_join("README.md"), FileAccess.WRITE)
	if readme == null:
		failures += 1
		return
	var identity := ("The live palp id %d is absent after withdrawal; "
			+ "impression %d retains its authored %s morphology at anatomy scale "
			+ "%.1f. It remains after subsequent owner work.\n\n") % [dead_id,
			int(stain.id), stain.morph.name_of_kind(), float(stain.grow)]
	var selection := ("The naturally observed successor selection for this "
			+ "isolated subject was **%s**.\n\n") % mode_name
	readme.store_string("# LC-6B — production margin death memory\n\n"
			+ "This sheet instantiates `orison_root.tscn`, waits for the production "
			+ "margin to grow a primary on real building geometry, and drives that "
			+ "same owner's `_age()` removal path. " + identity
			+ "The renderer reserves the nearest stain inside its existing forty slots; "
			+ "the production surface count remains one. No collision, light, save fact, "
			+ "hazard, route or case truth is added. " + selection
			+ "`00_mature_control_a/b` are the unchanged live A/A control. "
			+ "`02_stain_control_a/b` are the unchanged post-removal A/A control. "
			+ "`03_stain_after_owner_work` proves visit persistence, not save/load "
			+ "persistence.\n")
	readme.close()


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	printerr("[LC6B SHOT] ", message)
	get_tree().quit(1)
