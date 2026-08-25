extends Node
## MBIO-3 Forward+ proof: one mechanical event, three existing tissues.

const Mechanics := preload("res://scripts/dream/dream_microbiology_mechanics.gd")

var root: Node3D
var margin: DreamMarginController
var renderer: DreamPalpRenderer
var critters: DreamCritterController
var palp: Dictionary
var listener: Dictionary
var camera: Camera3D
var living = null
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
				"dream_microbiology_mechanics_mbio3")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = (load("res://scenes/building/orison_root.tscn") as PackedScene).instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	# The root has completed its deferred material sweep by two game-seconds;
	# longer waits spend the 60 s production-shot ceiling on unrelated routines.
	await get_tree().create_timer(2.0).timeout
	var enc = root.get("apartment_encroachment")
	if enc == null:
		return _fail("no production encroachment")
	margin = enc.get("margin")
	renderer = enc.get("palp_renderer")
	critters = enc.get("critters")
	if margin == null or renderer == null or critters == null \
			or margin.palps.is_empty() or critters.critters.is_empty():
		return _fail("production recipients did not populate")
	living = margin.field.living_field
	enc.set_physics_process(false)
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

	_reset_mechanics()
	await _capture("00_control_a")
	await _capture("00_control_b")
	_set_mechanics(DreamEcologyDirector.Carrier.IMPULSE, 0.92, 0.16)
	if living != null and not living.sources.is_empty():
		living.receive_vascular_pulse(palp.anchor, 0, 0.92)
	await _capture("01_impulse_front_early")
	_set_mechanics(DreamEcologyDirector.Carrier.IMPULSE, 0.58, 0.72)
	if living != null:
		for _i in 5:
			living.tick(0.125)
	await _capture("02_impulse_front_late")
	_set_mechanics(DreamEcologyDirector.Carrier.HUM, 0.88, 0.38)
	await _capture("03_sustained_hum_loaded")
	_reset_mechanics()
	await _capture("04_recovered_autonomy")
	_write_readme()
	Engine.time_scale = 1.0
	print("[MBIO-3 SHOT] production proof -> %s" % out_dir)
	get_tree().quit(failures)


func _stage_anatomy() -> void:
	palp.morph = DreamPalpMorphology.generate(
			DreamPalpMorphology.Kind.CILIATED_WHISKER, 83011)
	palp.morph.length = 0.58
	palp.morph.base_radius = 0.056
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

	listener.morph = DreamCritterGenerator.generate(
			DreamCritterSpecies.Kind.CRYSTAL_LISTENER, 83012)
	listener.morph.length = 0.15
	listener.morph.wide = 0.15
	listener.morph.tall = 0.13
	listener.morph.feelers = 12
	listener.morph.crystal = 0.92
	listener.up = palp.normal
	listener.fwd = (palp.normal as Vector3).cross(palp.side as Vector3).normalized()
	listener.pos = (palp.anchor as Vector3) + (palp.side as Vector3) * 0.27 \
			+ (palp.normal as Vector3) * 0.072
	listener.moving = false
	listener.spin = 1.1
	listener.unfold = 0.42


func _frame_subjects() -> void:
	var normal: Vector3 = palp.normal
	var side: Vector3 = palp.side
	var look := (palp.anchor as Vector3) + normal * 0.25 + side * 0.08
	var eye := look + normal * 0.96 + side * 0.52 + Vector3.UP * 0.10
	var up := Vector3.UP if absf(normal.y) < 0.9 else side
	camera.global_position = eye
	camera.look_at(look, up)
	root.player.global_position = eye - Vector3.UP * root.player.STANDING_EYE
	root.player._hand.global_transform = camera.global_transform \
			* Transform3D(Basis(), Vector3(0.16, -0.19, -0.06))


func _reset_mechanics() -> void:
	palp.mechanical = Mechanics.state()
	listener.mechanical = Mechanics.state()


func _set_mechanics(carrier: int, response: float, age: float) -> void:
	for receptor in [palp.mechanical, listener.mechanical]:
		receptor.response = response
		receptor.carrier = carrier
		receptor.age = age
		receptor.direction = palp.side
		receptor.received = 1


func _capture(label: String) -> void:
	renderer._process(0.0)
	critters._push()
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_dir.path_join(label + ".png"))
	if error != OK:
		failures += 1
		printerr("[MBIO-3 SHOT] failed %s" % label)
	else:
		print("[MBIO-3 SHOT] %s %dx%d" % [label,
				image.get_width(), image.get_height()])


func _write_readme() -> void:
	var file := FileAccess.open(out_dir.path_join("README.md"), FileAccess.WRITE)
	if file == null:
		failures += 1
		return
	file.store_string("# MBIO-3 — metachronal and electrochemical response\n\n"
			+ "Forward+ frames from `orison_root.tscn`. One production-born ciliated "
			+ "margin organ and one production-born crystal listener are retained in "
			+ "their real one-surface renderers. Anatomy is staged at authored maxima "
			+ "for readability. No proof mesh, material, light, collision or save owner "
			+ "is added.\n\n"
			+ "The duplicate controls price live rendering noise. The early and late "
			+ "impulse frames move one perfusion band root-to-tip while reversing the "
			+ "phase-offset ciliary power stroke and the listener resonator. Sustained "
			+ "hum loads/slows rather than synchronously shaking the carpet. Recovery "
			+ "returns byte-identically to the second control. The production executable "
			+ "proves finite signal arrival, recipient selection and unchanged attention/"
			+ "case/save ownership. `LivingFieldTest` proves the architecture front "
			+ "expands locally through its existing 3-D material texture and ends; this "
			+ "close sheet does not claim that background response is visually legible.\n")
	file.close()


func _fail(message: String) -> void:
	printerr("[MBIO-3 SHOT] ", message)
	get_tree().quit(1)
