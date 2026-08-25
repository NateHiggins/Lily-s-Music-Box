extends Node
## MBIO-1 rendered production proof: one cilium carpet and one listener.

const MicroLight := preload("res://scripts/dream/dream_microbiology_light.gd")

var root: Node3D
var margin: DreamMarginController
var renderer: DreamPalpRenderer
var critters: DreamCritterController
var palp: Dictionary
var listener: Dictionary
var camera: Camera3D
var out_dir := ""
var failures := 0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	OS.set_environment("DREAM_HERO", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir().path_join("dream_microbiology_light_mbio1")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = (load("res://scenes/building/orison_root.tscn") as PackedScene).instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(9.0).timeout
	var enc = root.get("apartment_encroachment")
	if enc == null:
		return _fail("no production encroachment")
	margin = enc.get("margin")
	renderer = enc.get("palp_renderer")
	critters = enc.get("critters")
	if margin == null or renderer == null or critters == null \
			or margin.palps.is_empty() or critters.critters.is_empty():
		return _fail("production recipients did not populate")

	margin.frozen = true
	critters.enabled = false
	palp = margin.palps[0]
	margin.palps.clear()
	margin.palps.append(palp)
	listener = critters.critters[0]
	critters.critters.clear()
	critters.critters.append(listener)
	_stage_anatomy()

	root.set_physics_process(false)
	root.player.set_physics_process(false)
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(1.0)
	root.player.set_process(false)
	for overlay in root.player.find_children("*", "CanvasLayer", true, false):
		overlay.visible = false
	if root.player.carried_device != null:
		root.player.carried_device.visible = false
	camera = Camera3D.new()
	camera.fov = 43.0
	root.add_child(camera)
	camera.make_current()
	_frame_subjects()
	renderer.material.set_shader_parameter("palp_time_override", 19.0)
	Engine.time_scale = 0.0

	_reset_photo()
	await _capture("00_control_a")
	await _capture("00_control_b")
	for i in 36:
		MicroLight.advance(palp.photo, 0.72 * float(i + 1) / 36.0, 0.05)
		MicroLight.advance(listener.photo, 0.72 * float(i + 1) / 36.0, 0.05)
	await _capture("01_slow_entry_scans")
	_reset_photo()
	MicroLight.advance(palp.photo, 0.72, 0.05)
	MicroLight.advance(listener.photo, 0.72, 0.05)
	listener.spin -= 0.20
	listener.unfold = maxf(float(listener.unfold), 0.72)
	await _capture("02_abrupt_photoshock")
	for i in 80:
		MicroLight.advance(palp.photo, 0.72, 0.05)
		MicroLight.advance(listener.photo, 0.72, 0.05)
	await _capture("03_sustained_adapted")
	for i in 34:
		MicroLight.advance(palp.photo, 0.0, 0.05)
		MicroLight.advance(listener.photo, 0.0, 0.05)
	MicroLight.advance(palp.photo, 0.72, 0.05)
	MicroLight.advance(listener.photo, 0.72, 0.05)
	listener.spin -= 0.12
	await _capture("04_unreliable_lamp_weaker")
	_write_readme()
	Engine.time_scale = 1.0
	print("[MBIO-1 SHOT] production proof -> %s" % out_dir)
	get_tree().quit(failures)


func _stage_anatomy() -> void:
	palp.morph = DreamPalpMorphology.generate(
			DreamPalpMorphology.Kind.CILIATED_WHISKER, 82011)
	palp.morph.length = 0.54
	palp.morph.base_radius = 0.052
	palp.morph.cilia = 1.0
	palp.grow = 1.0
	palp.extend = 1.0
	palp.aim = palp.normal
	palp.tip = (palp.anchor as Vector3) + (palp.normal as Vector3) * 0.50
	palp.last_tip = palp.tip
	palp.parent = 0
	palp.unfold = 1.0
	palp.cilia_out = 1.0
	palp.cilia_band = 0.62
	palp.task_left = 0.0
	palp.lifecycle_override = 3

	listener.morph = DreamCritterGenerator.generate(
			DreamCritterSpecies.Kind.CRYSTAL_LISTENER, 82012)
	listener.morph.length = 0.13
	listener.morph.wide = 0.13
	listener.morph.tall = 0.12
	listener.morph.feelers = 12
	listener.morph.crystal = 0.90
	listener.up = palp.normal
	listener.fwd = (palp.normal as Vector3).cross(palp.side as Vector3).normalized()
	listener.pos = (palp.anchor as Vector3) + (palp.side as Vector3) * 0.25 \
			+ (palp.normal as Vector3) * 0.065
	listener.moving = false
	listener.spin = 1.1
	listener.unfold = 0.34


func _frame_subjects() -> void:
	var normal: Vector3 = palp.normal
	var side: Vector3 = palp.side
	var look := (palp.anchor as Vector3) + normal * 0.24 + side * 0.08
	var eye := look + normal * 0.93 + side * 0.50 + Vector3.UP * 0.10
	var up := Vector3.UP if absf(normal.y) < 0.9 else side
	camera.global_position = eye
	camera.look_at(look, up)
	root.player.global_position = eye - Vector3.UP * root.player.STANDING_EYE
	root.player._hand.global_transform = camera.global_transform \
			* Transform3D(Basis(), Vector3(0.16, -0.19, -0.06))


func _reset_photo() -> void:
	palp.photo = MicroLight.state()
	palp.photo_side = 0.65
	listener.photo = MicroLight.state()
	listener.photo_side = -0.55


func _capture(label: String) -> void:
	renderer._process(0.0)
	critters._push()
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_dir.path_join(label + ".png"))
	if error != OK:
		failures += 1
		printerr("[MBIO-1 SHOT] failed %s" % label)
	else:
		print("[MBIO-1 SHOT] %s %dx%d" % [label, image.get_width(), image.get_height()])


func _write_readme() -> void:
	var file := FileAccess.open(out_dir.path_join("README.md"), FileAccess.WRITE)
	if file == null:
		failures += 1
		return
	file.store_string("# MBIO-1 — microbial light response in production Orison\n\n"
			+ "These frames instantiate `orison_root.tscn`, retain one production-born "
			+ "margin organ and one production-born fauna individual, and photograph "
			+ "them through the real margin/critter renderers and shared Dream surface "
			+ "stack. The anatomy is staged at authored maxima for readability; no proof "
			+ "mesh, material, ecology owner, light, collision, or save record is added.\n\n"
			+ "`00_control_a.png` and `00_control_b.png` hold identical recipient data, "
			+ "camera, player lamp, and pinned palp clock. They price the A/A floor. "
			+ "`01_slow_entry_scans.png` shows directional phase asymmetry without shock; "
			+ "`02_abrupt_photoshock.png` reverses/closes the same complete cilia and "
			+ "internal listener resonator; `03_sustained_adapted.png` settles under a "
			+ "constant stimulus; `04_unreliable_lamp_weaker.png` is the admitted later "
			+ "response after refractory recovery, at reduced sensitivity.\n\n"
			+ "The companion production-root executable test proves that these poses are "
			+ "driven from the existing `PlayerController.lamp_pose()` seam and create no "
			+ "node, surface, case fact, or persistence seam. This sheet proves the visual "
			+ "recipient language, not a completed waking case loop.\n")
	file.close()


func _fail(message: String) -> void:
	printerr("[MBIO-1 SHOT] ", message)
	get_tree().quit(1)
