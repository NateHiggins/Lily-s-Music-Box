extends Node
## MBIO-6 Forward+ storyboard. One production process, three local A/A pairs.

const MicroLight := preload("res://scripts/dream/dream_microbiology_light.gd")
const Mechanics := preload("res://scripts/dream/dream_microbiology_mechanics.gd")

var root: Node3D
var enc
var margin: DreamMarginController
var renderer: DreamPalpRenderer
var hero: DreamHeroTentacle
var director: DreamEcologyDirector
var palp: Dictionary
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
		out_dir = OS.get_user_data_dir().path_join(
				"dream_microbiology_mbio6_encounter")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	enc = root.get("apartment_encroachment")
	if enc == null:
		return _fail("production encroachment missing")
	margin = enc.get("margin")
	renderer = enc.get("palp_renderer")
	hero = enc.get("hero")
	director = enc.get("ecology")
	if margin == null or renderer == null or hero == null or director == null \
			or margin.palps.is_empty():
		return _fail("production encounter owners did not populate")

	_freeze_world()
	palp = margin.palps[0]
	margin.palps.clear()
	margin.palps.append(palp)
	_stage_palp()
	camera = Camera3D.new()
	camera.fov = 43.0
	root.add_child(camera)
	camera.make_current()
	root.view_override = camera
	root.player.flashlight.reparent(camera)
	root.player.flashlight.transform = Transform3D(Basis(),
			Vector3(0.14, -0.16, -0.05))
	renderer.material.set_shader_parameter("palp_time_override", 19.0)
	Engine.time_scale = 0.0

	# RECEPTOR LOCAL PAIR. The room and clock are fixed; only the receptor and
	# authored lamp state change after the duplicate dark controls.
	_frame_palp()
	root.player.set_lamp_enabled(false)
	root.player.flashlight.visible = false
	_reset_photo()
	await _capture("00_dark_control_a")
	await _capture("00_dark_control_b")
	root.player.set_lamp_enabled(true)
	root.player.flashlight.visible = true
	for i in 36:
		MicroLight.advance(palp.photo, 0.72 * float(i + 1) / 36.0, 0.05)
	await _capture("01_slow_scan")
	_reset_photo()
	MicroLight.advance(palp.photo, 0.72, 0.05)
	await _capture("02_photoshock")
	for _i in 80:
		MicroLight.advance(palp.photo, 0.72, 0.05)
	await _capture("03_adapted")

	# MECHANICAL LOCAL PAIR. This is the same production packet bed and cilium
	# receptor proved by the executable encounter; no proof mesh or animation
	# owner appears. The reply also enters the existing LivingField.
	palp.mechanical = Mechanics.state()
	await _capture("04_reply_control_a")
	await _capture("04_reply_control_b")
	director.emit_mechanical_packet(8606, palp.tip - Vector3.RIGHT, 2.0, 0.82,
			DreamEcologyDirector.Carrier.IMPULSE, Vector3.RIGHT, 2.0,
			DreamEcologyDirector.Substrate.FLOOR, 2.0)
	director._process(0.51)
	margin._update_mechanoreception(palp, 0.02)
	enc._receive_architecture_signals()
	await _capture("05_cilia_architecture_reply")

	# VESICLE LOCAL PAIR. Reframe, but stay in this same production process.
	if not _move_hero_to_camera_safe_wall():
		return _fail("no camera-safe production wall for hero")
	_frame_hero()
	_set_secretion(-1.0)
	await _capture("06_vesicle_control_a")
	await _capture("06_vesicle_control_b")
	hero._emit_contact_signal(hero.global_position)
	_set_secretion(0.64)
	await _capture("07_later_vesicle")
	_write_readme()
	Engine.time_scale = 1.0
	print("[MBIO-6 SHOT] one-session production storyboard -> %s" % out_dir)
	get_tree().quit(failures)


func _freeze_world() -> void:
	enc.set_process(false)
	enc.set_physics_process(false)
	root.set_process(false)
	root.set_physics_process(false)
	root.player.set_process(false)
	root.player.set_physics_process(false)
	margin.frozen = true
	for owner_name in ["critters", "dream_field"]:
		var owner = enc.get(owner_name)
		if owner != null:
			owner.set_process(false)
			owner.set_physics_process(false)
	hero.set_process(false)
	director.set_process(false)
	for overlay in root.find_children("*", "CanvasLayer", true, false):
		overlay.visible = false
	if root.player.carried_device != null:
		root.player.carried_device.visible = false
	root.player.pin_lamp_gutter_for_proof(1.0)


func _stage_palp() -> void:
	palp.morph = DreamPalpMorphology.generate(
			DreamPalpMorphology.Kind.CILIATED_WHISKER, 8606)
	palp.morph.length = 0.58
	palp.morph.base_radius = 0.055
	palp.morph.cilia = 1.0
	palp.grow = 1.0
	palp.extend = 1.0
	palp.aim = palp.normal
	palp.tip = (palp.anchor as Vector3) + (palp.normal as Vector3) * 0.54
	palp.last_tip = palp.tip
	palp.parent = 0
	palp.unfold = 1.0
	palp.cilia_out = 1.0
	palp.cilia_band = 0.62
	palp.task_left = 0.0
	palp.lifecycle_override = 3
	palp.mechanical = Mechanics.state()
	_reset_photo()


func _reset_photo() -> void:
	palp.photo = MicroLight.state()
	palp.photo_side = 0.68


func _frame_palp() -> void:
	var normal: Vector3 = palp.normal
	var side: Vector3 = palp.side
	var look := (palp.anchor as Vector3) + normal * 0.25
	var eye := look + normal * 0.98 + side * 0.50 + Vector3.UP * 0.10
	var up := Vector3.UP if absf(normal.y) < 0.9 else side
	camera.global_position = eye
	camera.look_at(look, up)


func _move_hero_to_camera_safe_wall() -> bool:
	var space := get_viewport().find_world_3d().direct_space_state
	var from := Vector3(-9.6, 4.55, 3.4)
	var best := {}
	var best_clear := 0.0
	for step in 24:
		var angle := float(step) / 24.0 * TAU
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var hit := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(from, from + direction * 6.0))
		if hit.is_empty():
			continue
		var normal: Vector3 = (hit.normal as Vector3).normalized()
		if absf(normal.y) > 0.35:
			continue
		var probe: Vector3 = (hit.position as Vector3) + normal * 1.2
		if probe.x < -13.45 or probe.x > -5.75 or probe.z < 0.65 or probe.z > 6.05:
			continue
		var outside: Vector3 = (hit.position as Vector3) + normal * 0.08
		var block := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(outside, outside + normal * 4.0))
		var clear := 4.0 if block.is_empty() \
				else outside.distance_to(block.position as Vector3)
		if clear > best_clear:
			best_clear = clear
			best = {"position": hit.position, "normal": normal}
	if best.is_empty():
		return false
	var normal: Vector3 = best.normal
	var at: Vector3 = (best.position as Vector3) + normal * 0.04
	hero.look_at_from_position(at, at + normal, Vector3.UP)
	hero.anchor_normal = normal
	hero.grow = 1.0
	hero.slice_close = 0.0
	for mesh in hero.meshes:
		mesh.visible = true
	for mat in hero.materials:
		mat.set_shader_parameter("grow", 1.0)
		mat.set_shader_parameter("slice_close", 0.0)
		mat.set_shader_parameter("lifecycle_stage", 4.0)
		mat.set_shader_parameter("proof_time", 7.25)
	return true


func _frame_hero() -> void:
	var normal := -(hero.global_transform.basis.z).normalized()
	var side := normal.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var look := hero.global_position + normal * 1.22
	var eye := look + (normal + side * 0.56 + Vector3.UP * 0.12).normalized() * 0.92
	camera.global_position = eye
	camera.look_at(look, Vector3.UP)


func _set_secretion(phase: float) -> void:
	hero.secretion_phase = phase
	for mat in hero.materials:
		mat.set_shader_parameter("secretion_phase", phase)


func _capture(label: String) -> void:
	renderer._process(0.0)
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(out_dir.path_join(label + ".png"))
	if err != OK:
		failures += 1
		printerr("[MBIO-6 SHOT] failed %s" % label)
	else:
		print("[MBIO-6 SHOT] %s %dx%d" % [label,
				image.get_width(), image.get_height()])


func _write_readme() -> void:
	var file := FileAccess.open(out_dir.path_join("README.md"), FileAccess.WRITE)
	if file == null:
		failures += 1
		return
	file.store_string("# MBIO-6 — one production cellular encounter\n\n"
			+ "All frames come from one Forward+ `orison_root.tscn` process. The "
			+ "three duplicate-control pairs price local noise after each camera setup. "
			+ "The production-born cilium, existing margin renderer, signal bed, "
			+ "LivingField and modelled hero are retained; anatomy is staged at readable "
			+ "authored maxima. No proof mesh, material, light, collision, biology owner, "
			+ "case fact or save seam is added.\n\n"
			+ "The companion `DreamMicrobiologyEncounterTest` proves 12/12 that the real "
			+ "player path is dark → slow scan → photoshock → adaptation → collision-"
			+ "resolved footfall → finite cilium answer → LivingField uptake → later hero "
			+ "vesicle. This sheet proves those already-causal states remain legible in "
			+ "one production session. It does not claim combat or a completed waking "
			+ "case loop.\n")
	file.close()


func _fail(message: String) -> void:
	printerr("[MBIO-6 SHOT] ", message)
	Engine.time_scale = 1.0
	get_tree().quit(1)
