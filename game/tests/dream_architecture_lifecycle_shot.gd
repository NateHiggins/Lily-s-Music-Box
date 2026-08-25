extends Node
## LC-6D Forward+ proof: one production LivingField, one camera, eight names
## for the architecture's existing growth/exchange/withdrawal facts.

const Lifecycle := preload("res://scripts/dream/dream_organelle_lifecycle.gd")

var root: Node3D
var enc
var field: LivingField
var camera: Camera3D
var focus := Vector3.ZERO
var out_dir := ""
var failures := 0


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
		out_dir = OS.get_user_data_dir().path_join(
				"dream_architecture_lifecycle_lc6d")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	enc = root.get("apartment_encroachment")
	if enc == null or not enc.fields.has("F02"):
		return _fail("production F02 architecture owner missing")
	field = enc.fields["F02"]
	var radiator := root.get_node(ServiceRoundDirector.RADIATOR_ID) as Node3D
	if radiator == null:
		return _fail("production 2B radiator framing anchor missing")
	focus = radiator.global_position + Vector3(0.0, 0.72, 0.0)
	_frame(radiator.global_position)
	# Let the production floor-visibility owner observe the real player's move
	# before anything freezes. The rejected first sheet froze it in the lobby
	# and honestly photographed the hidden-storey cutaway instead of F02.
	for _i in 10:
		await get_tree().process_frame
	_freeze_world()
	Engine.time_scale = 0.0

	_stage(Lifecycle.Stage.FOLDED)
	await _capture("00_folded_control_a")
	await _capture("00_folded_control_b")
	_stage(Lifecycle.Stage.BUD)
	await _capture("01_bud_attachment")
	_stage(Lifecycle.Stage.JUVENILE)
	await _capture("02_juvenile_sampling")
	_stage(Lifecycle.Stage.MATURE)
	await _capture("03_mature_control_a")
	await _capture("03_mature_control_b")
	_stage(Lifecycle.Stage.EXCHANGE)
	await _capture("04_vascular_exchange")
	_stage(Lifecycle.Stage.SENESCENT)
	await _capture("05_senescent_mineral_bloom")
	_stage(Lifecycle.Stage.SHED)
	await _capture("06_shed_bruise")
	_stage(Lifecycle.Stage.STAIN)
	await _capture("07_stain_control_a")
	await _capture("07_stain_control_b")
	_write_readme()
	Engine.time_scale = 1.0
	print("[LC6D SHOT] production architecture lifecycle -> %s" % out_dir)
	get_tree().quit(failures)


func _freeze_world() -> void:
	enc.set_process(false)
	enc.set_physics_process(false)
	root.set_process(false)
	root.set_physics_process(false)
	root.player.set_process(false)
	root.player.set_physics_process(false)
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(1.0)
	for overlay in root.find_children("*", "CanvasLayer", true, false):
		overlay.visible = false
	if root.player.carried_device != null:
		root.player.carried_device.visible = false


func _frame(radiator_at: Vector3) -> void:
	root.player.global_position = radiator_at + Vector3(1.1, 0.0, 0.1)
	camera = Camera3D.new()
	camera.fov = 51.0
	root.add_child(camera)
	camera.global_position = radiator_at + Vector3(1.42, 1.08, 0.12)
	camera.look_at(radiator_at + Vector3(0.0, 0.30, 0.0))
	camera.make_current()
	root.view_override = camera
	root.player.flashlight.reparent(camera)
	root.player.flashlight.transform = Transform3D(Basis(),
			Vector3(0.12, -0.15, -0.05))


func _stage(stage: int) -> void:
	for source in field.sources:
		source.intensity = 0.8 if stage <= Lifecycle.Stage.EXCHANGE else 0.0
	field._agents_pos.clear()
	field._agents_dir.clear()
	field._agents_starve.clear()
	field._agents_src.clear()
	field.vascular_relays.clear()
	field.trail.fill(0.0)
	field.body.fill(0.0)
	field.stain.fill(0.0)
	var body_value := 0.0
	var trail_value := 0.0
	var stain_value := 0.0
	match stage:
		Lifecycle.Stage.BUD:
			body_value = 0.28; trail_value = 0.38
		Lifecycle.Stage.JUVENILE:
			body_value = 0.58; trail_value = 0.68
		Lifecycle.Stage.MATURE:
			body_value = 0.94; trail_value = 1.08; stain_value = 0.42
		Lifecycle.Stage.EXCHANGE:
			body_value = 0.94; trail_value = 1.08; stain_value = 0.42
			field.vascular_relays.append({"at": focus, "src": 0,
					"strength": 0.9, "age": 0.0, "radius": 0.5, "limit": 1.3})
		Lifecycle.Stage.SENESCENT:
			body_value = 0.86; trail_value = 0.82; stain_value = 0.62
		Lifecycle.Stage.SHED:
			body_value = 0.10; trail_value = 0.55; stain_value = 0.82
		Lifecycle.Stage.STAIN:
			stain_value = 0.98
	var radius := 1.58
	for y in field.ny:
		for z in field.nz:
			for x in field.nx:
				var at := field.origin + Vector3((float(x) + 0.5) * field.VOXEL_M,
						(float(y) + 0.5) * field.VOXEL_M,
						(float(z) + 0.5) * field.VOXEL_M)
				var unit := at.distance_to(focus) / radius
				if unit >= 1.0:
					continue
				var weight := 1.0 - smoothstep(0.52, 1.0, unit)
				var k := field._index(x, y, z)
				field.body[k] = body_value * weight
				field.trail[k] = trail_value * weight
				field.stain[k] = stain_value * weight
				field.who[k] = 0
	# Reuse the production encoder. Each state is restaged before this single
	# relaxation pass, so no prior frame can accumulate into the next.
	for y in field.ny:
		field._relax_slice(y)
	field.texture().update(field._images)
	enc._push_living_lifecycle("F02", field)
	for material in enc.storey_materials.get("F02", []):
		if is_instance_valid(material):
			(material as ShaderMaterial).set_shader_parameter("living_pulse", 0.31)
	var actual := field.lifecycle_stage()
	if actual != stage:
		failures += 1
		printerr("[LC6D SHOT] staged %s but owner classified %s" % [
				Lifecycle.stage_name(stage), Lifecycle.stage_name(actual)])


func _capture(label: String) -> void:
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_dir.path_join(label + ".png"))
	if error != OK:
		failures += 1
		printerr("[LC6D SHOT] failed %s" % label)
	else:
		print("[LC6D SHOT] %s %dx%d" % [label,
				image.get_width(), image.get_height()])


func _write_readme() -> void:
	# A reviewed proof ledger contains measured control deltas and content
	# hashes. Never replace that accepted verdict with the capture-time stub;
	# first captures still receive enough provenance for review.
	if FileAccess.file_exists(out_dir.path_join("README.md")):
		return
	var file := FileAccess.open(out_dir.path_join("README.md"), FileAccess.WRITE)
	if file == null:
		failures += 1
		return
	file.store_string("# LC-6D — living architecture lifecycle\n\n"
			+ "Forward+ frames from one `orison_root.tscn` process, one production "
			+ "F02 LivingField, its existing 3-D texture, layered materials, 2B wall "
			+ "and player lamp. Three duplicate-control pairs price the folded, mature "
			+ "and stain states. No proof mesh, material, light, collision, lifecycle "
			+ "clock, case fact or save owner is added.\n\n"
			+ "The field's existing facts are staged at readable maxima: source-driven "
			+ "attachment, juvenile sampling, mature body, vascular exchange, source-off "
			+ "senescence, residual shed tissue and the already-owned slime stain. The "
			+ "classifier itself changes none of those facts. Measurements and hashes are "
			+ "added after visual review; this generated text is not yet the proof verdict.\n")
	file.close()


func _fail(message: String) -> void:
	printerr("[LC6D SHOT] ", message)
	Engine.time_scale = 1.0
	get_tree().quit(1)
