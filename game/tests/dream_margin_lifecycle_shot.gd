extends Node
## LC-6A — one production-born margin palp, photographed through Orison's
## production root, margin renderer, shared surface stack and player lamp.

const Lifecycle = preload("res://scripts/dream/dream_organelle_lifecycle.gd")

var root: Node3D
var margin: DreamMarginController
var renderer: DreamPalpRenderer
var subject: Dictionary
var proof_camera: Camera3D
var out_dir := ""
var failures := 0
var frames := 0
var notes: Array[String] = []


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
		out_dir = OS.get_user_data_dir().path_join("dream_margin_lifecycle_lc6a")
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

	# Hold every owner that can move the comparison. The material's own clock
	# is pinned separately; its production default remains live TIME.
	margin.frozen = true
	margin.palps.clear()
	margin.palps.append(subject)
	root.set_physics_process(false)
	root.player.set_physics_process(false)
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(1.0)
	root.player.set_process(false)
	for overlay in root.player.find_children("*", "CanvasLayer", true, false):
		overlay.visible = false
	if root.player.carried_device != null:
		root.player.carried_device.visible = false
	proof_camera = Camera3D.new()
	proof_camera.name = "LifecycleProofCamera"
	proof_camera.fov = 47.0
	root.add_child(proof_camera)
	proof_camera.make_current()
	renderer.material.set_shader_parameter("palp_time_override", 17.0)
	# The production root contains several unrelated TIME-driven surfaces. Hold
	# engine time only after the root, owner and lamp are established so the A/A
	# floor measures the staged subject instead of the room's animation.
	Engine.time_scale = 0.0

	_set_stage(Lifecycle.Stage.MATURE)
	_frame_subject()
	await _capture("00_control_a")
	await _capture("00_control_b")
	notes.clear()
	for stage in Lifecycle.Stage.values():
		_set_stage(stage)
		await _capture("%02d_%s" % [stage + 1,
				Lifecycle.stage_name(stage)])
	_write_readme()
	print("[LC6A SHOT] %d production-root frames -> %s" % [frames, out_dir])
	Engine.time_scale = 1.0
	get_tree().quit(failures)


func _choose_subject() -> bool:
	var best_length := -1.0
	for p in margin.palps:
		if int(p.parent) >= 0 or int(p.tier) != DreamMarginController.TIER_PRIMARY:
			continue
		var length := float(p.morph.length)
		if length > best_length:
			best_length = length
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
	print("[LC6A SHOT] subject id=%d kind=%s anchor=%s normal=%s length=%.3f"
			% [int(subject.id), subject.morph.name_of_kind(), subject.anchor,
			subject.normal, float(subject.morph.length)])
	return true


func _set_stage(stage: int) -> void:
	subject.lifecycle_override = stage
	subject.lifecycle_stage = stage
	subject.age = _stage_midpoint(stage) * float(subject.life)
	subject.grow = 1.0
	renderer._process(0.0)
	var root_at: Vector3 = renderer._spine[0]
	var tip_at: Vector3 = renderer._spine[DreamPalpRenderer.JOINTS - 1]
	notes.append("%02d_%s.png — %s at anatomy scale %.1f; reach %.3f m."
			% [stage + 1, Lifecycle.stage_name(stage),
			Lifecycle.stage_name(stage), float(subject.grow),
			root_at.distance_to(tip_at)])


func _frame_subject() -> void:
	var normal: Vector3 = subject.normal
	var side: Vector3 = subject.side
	var stand_off := maxf(0.62, float(subject.morph.length) * 2.2)
	var look: Vector3 = subject.anchor \
			+ normal * float(subject.morph.length) * 0.35
	# Not down the organ's axis: mature anatomy reaches toward the room and an
	# axial camera reduces a full ribbon to its tip. One oblique stand is held
	# for the whole sheet so every pixel comparison has the same camera/lamp.
	var eye := look + normal * stand_off + side * stand_off * 0.68 \
			+ Vector3.UP * 0.08
	var camera_up := Vector3.UP if absf(normal.y) < 0.90 else side
	proof_camera.global_position = eye
	proof_camera.look_at(look, camera_up)
	# Visibility still classifies from the production player, while the real
	# hand lamp is placed at the proof eye and aimed down the proof camera.
	root.player.global_position = eye - Vector3.UP * root.player.STANDING_EYE
	root.player._hand.global_transform = proof_camera.global_transform \
			* Transform3D(Basis(), Vector3(0.16, -0.19, -0.06))


func _stage_midpoint(stage: int) -> float:
	return [0.04, 0.13, 0.28, 0.515, 0.715, 0.84, 0.935, 0.985][stage]


func _capture(label: String) -> void:
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(label + ".png")
	var error := image.save_png(path)
	if error != OK:
		failures += 1
		printerr("[LC6A SHOT] failed %s (%d)" % [path, error])
		return
	frames += 1
	print("[LC6A SHOT] saved %s %dx%d" % [path, image.get_width(),
			image.get_height()])


func _write_readme() -> void:
	var readme := FileAccess.open(out_dir.path_join("README.md"), FileAccess.WRITE)
	if readme == null:
		failures += 1
		return
	readme.store_string("# LC-6A — production margin lifecycle\n\n"
			+ "These frames instantiate `orison_root.tscn`, wait for its production "
			+ "`ApartmentEncroachment` to grow a palp on real building geometry, then "
			+ "photograph that named palp through `DreamPalpRenderer`, "
			+ "`dream_palp.gdshader`, and the player's service lamp. No proof mesh or "
			+ "proof light replaces a production owner.\n\n"
			+ "`00_control_a.png` and `00_control_b.png` are identical mature state, "
			+ "camera, lamp, owner data and pinned palp shader clock. Engine time is "
			+ "held after the live root and lamp settle so unrelated animated building "
			+ "surfaces do not become the comparison. The controls price residual render "
			+ "noise before any stage comparison. Frames 01–08 hold the same individual "
			+ "at the midpoint of each shared lifecycle stage.\n\n"
			+ "What this proves: the margin owner uses the shared eight-stage language; "
			+ "folded and shed are architectural-surface postures of complete anatomy; "
			+ "mature and exchange reach into playable space; senescence droops and "
			+ "returns toward the surface; no stage scales the organ from zero.\n\n"
			+ "What this does **not** prove: a persistent post-removal margin stain. "
			+ "Frame 08 is the spent attached imprint immediately before owner removal. "
			+ "Persistent architectural memory remains the next LC-6 owner slice.\n\n"
			+ "## Frames\n\n- 00_control_a.png — mature A/A control.\n"
			+ "- 00_control_b.png — unchanged mature A/A control.\n- "
			+ "\n- ".join(notes) + "\n")
	readme.close()


func _fail(message: String) -> void:
	printerr("[LC6A SHOT] ", message)
	get_tree().quit(1)
