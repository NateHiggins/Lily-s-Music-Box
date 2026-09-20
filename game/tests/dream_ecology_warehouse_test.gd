extends Node3D
## Debug exhibit contract only: actual shared fauna batches, live presentation
## laws, the one R/G exposure owner and teardown. No composed campaign proof,
## complete hero/margin interactions, visual acceptance or performance acceptance.

const ExhibitScript = preload("res://scripts/debug/dream_ecology_warehouse.gd")
const SpeciesScript = preload("res://scripts/dream/critters/dream_critter_species.gd")
const ExposureScript = preload("res://scripts/dream/dream_exposure_field.gd")
const OBSERVE_SECONDS := 32.0

var exhibit: ExhibitScript
var checks: Array[Dictionary] = []
var failures := 0
var evidence := {}
var observations := {}
var output := ""


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("DreamEcologyWarehouseTest requires writable SHOT_DIR")
		get_tree().quit(2)
		return
	var original_mode: int = GameBoot.launch_mode
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var refused := ExhibitScript.new()
	add_child(refused)
	refused.setup()
	_check("non-DEBUG setup constructs no exhibit or controllers", refused.get_child_count() == 0
		and refused.controllers.is_empty() and refused.exposure == null and refused.exposure_texture == null)
	refused.queue_free()
	refused = null
	await get_tree().process_frame
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.055, 0.06, 0.075)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.75, 0.82, 1.0)
	settings.ambient_light_energy = 0.45
	environment.environment = settings
	add_child(environment)
	exhibit = ExhibitScript.new()
	exhibit.name = "DreamEcologyWarehouse"
	exhibit.position = Vector3(400, 0, 0)
	add_child(exhibit)
	exhibit.setup()
	exhibit.activate(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("exactly two production fauna controllers are constructed", exhibit.controllers.size() == 2)
	if exhibit.controllers.size() != 2:
		GameBoot.launch_mode = original_mode
		await _finish()
		return
	_check("viewing stand is inside the actual global hall volume",
		exhibit.hall_aabb().has_point(exhibit.viewing_stand()) and exhibit.viewing_stand().x > 380)
	var floor_query := PhysicsRayQueryParameters3D.create(exhibit.viewing_stand(),
		exhibit.viewing_stand() - Vector3.UP * 4.0)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(floor_query)
	_check("viewing stand has real supporting collision", not floor_hit.is_empty()
		and (floor_hit.normal as Vector3).dot(Vector3.UP) > 0.99)
	evidence["stand"] = _v(exhibit.viewing_stand())
	evidence["hall"] = {"position": _v(exhibit.hall_aabb().position), "size": _v(exhibit.hall_aabb().size)}
	_check_population_and_bindings()
	_check_grazer_panel()
	exhibit._overview = true
	await _capture("overview.png")
	exhibit.set_lamp_enabled(false)
	var initial: Dictionary = _state_snapshot()
	for kind in SpeciesScript.all_kinds():
		observations[kind] = {"min": INF, "max": -INF, "phase_min": INF, "phase_max": -INF,
			"twin_seen": false, "shader_law_changed": false, "first_shader_law": null}
	exhibit.focus_species(SpeciesScript.Kind.NOCTILUCA)
	exhibit.stimulate_selected()
	await get_tree().physics_frame
	await _capture("noctiluca_touch.png")
	var elapsed := 0.0
	var frames := 0
	while elapsed < OBSERVE_SECONDS and frames < 4096:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		frames += 1
		_observe_laws()
	evidence["simulation"] = {"physics_frames": frames, "simulated_seconds": elapsed,
		"stimulus": "One selected Noctiluca debug touch through exhibit.stimulate_selected; no law-state writes in this test."}
	_check("live physics observation covers thirty-two seconds", elapsed >= OBSERVE_SECONDS)
	_check_law_results(initial)
	evidence["laws"] = observations.duplicate(true)
	await _capture("noctiluca_after.png")
	await _check_lamp()
	await _check_pause_and_reset()
	exhibit.set_lamp_enabled(true)
	for kind in SpeciesScript.all_kinds():
		exhibit.focus_species(kind)
		await _physics_seconds(0.4)
		if kind == SpeciesScript.Kind.NOCTILUCA: exhibit.stimulate_selected()
		await _capture("species_%02d.png" % kind)
	evidence["final_stats"] = exhibit.stats()
	GameBoot.launch_mode = original_mode
	await _finish()


func _check_population_and_bindings() -> void:
	var seen := {}
	var packed := {}
	var materials := {}
	var meshes := {}
	var per_controller: Array = []
	for controller in exhibit.controllers:
		var kinds: Array = []
		_check("controller has eight authored records", controller.critters.size() == 8)
		for critter: Dictionary in controller.critters:
			var kind := int(critter.morph.kind)
			seen[kind] = int(seen.get(kind, 0)) + 1
			kinds.append(kind)
			_check("%s retains its authored anatomy and long exhibit life" % SpeciesScript.name_of(kind),
				SpeciesScript.violates_identity(kind, critter.morph) == "" and float(critter.life) >= 3600)
		materials[controller.material.get_instance_id()] = true
		meshes[controller.mesh_instance.get_instance_id()] = true
		_check("one controller mesh owns one shared material", controller.mesh_instance.material_override == controller.material)
		_check("both controller bindings use the exact world texture", controller._voxel_texture == exhibit.exposure_texture
			and controller.material.get_shader_parameter("exposure_tex") == exhibit.exposure_texture
			and float(controller.material.get_shader_parameter("voxel_optics_enabled")) == 1.0
			and float(controller.material.get_shader_parameter("exposure_extent")) == ExposureScript.EXTENT_M
			and float(controller.material.get_shader_parameter("exposure_height")) == ExposureScript.HEIGHT_M)
		var count := int(controller.material.get_shader_parameter("critter_count"))
		var positions: PackedVector4Array = controller.material.get_shader_parameter("critter_pos")
		_check("packed draw slots cover the eight live animals within capacity", count >= 8 and count <= 12 and positions.size() >= count)
		for slot in mini(count, positions.size()): packed[int(round(positions[slot].w))] = true
		per_controller.append({"kinds": kinds, "draw_slots": count, "material_id": controller.material.get_instance_id(),
			"mesh_instance_id": controller.mesh_instance.get_instance_id()})
	var complete := seen.size() == 16 and packed.size() == 16
	for kind in SpeciesScript.all_kinds(): complete = complete and int(seen.get(kind, 0)) == 1 and packed.has(kind)
	_check("all sixteen enum kinds are unique animals and actual shader kind IDs", complete)
	_check("sixteen animals retain two primary controller meshes and materials", materials.size() == 2 and meshes.size() == 2)
	_check("the one exposure texture is the existing RG8 world grid", exhibit.exposure_texture != null
		and exhibit.exposure_texture.get_format() == Image.FORMAT_RG8
		and exhibit.exposure_texture.get_width() == ExposureScript.GRID_XZ
		and exhibit.exposure_texture.get_depth() == ExposureScript.GRID_Y
		and not exhibit.exposure.overflowed())
	evidence["batches"] = per_controller
	evidence["packed_kinds"] = packed.keys()
	evidence["texture_id"] = exhibit.exposure_texture.get_instance_id()


func _check_grazer_panel() -> void:
	var grazer: Dictionary = exhibit.specimen_for(SpeciesScript.Kind.SEAM_GRAZER)
	if grazer.is_empty():
		_check("grazer has a real thin-wall specimen", false)
		return
	var at: Vector3 = grazer.pos
	var up: Vector3 = grazer.up
	var query := PhysicsRayQueryParameters3D.create(at - up * 0.32, at)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var six_cm := false
	if not hit.is_empty():
		for child in hit.collider.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				var size: Vector3 = child.shape.size
				six_cm = six_cm or absf(minf(size.x, minf(size.y, size.z)) - 0.06) < 0.00001
	_check("grazer twin rests on an actual six-centimetre collision panel", six_cm and bool(grazer.get("twin", false)))
	evidence["grazer_support"] = {"collider": str(hit.collider.get_path()) if not hit.is_empty() else "missing",
		"six_cm_box": six_cm, "twin": grazer.get("twin", false)}


func _state_snapshot() -> Dictionary:
	var states := {}
	for kind in SpeciesScript.all_kinds():
		var c: Dictionary = exhibit.specimen_for(kind)
		states[kind] = {"age": float(c.get("age", -1)), "gait": float(c.get("gait", 0)),
			"position": _v(c.get("pos", Vector3.ZERO)), "morph": c.get("morph", {}).duplicate(true)}
	return states


func _observe_laws() -> void:
	for kind in SpeciesScript.all_kinds():
		var c: Dictionary = exhibit.specimen_for(kind)
		if c.is_empty(): continue
		var row: Dictionary = observations[kind]
		var value := float(c.get("micro_state", 0.0))
		if kind == SpeciesScript.Kind.CRYSTAL_LISTENER: value = float(c.get("spin", 0.0))
		elif kind == SpeciesScript.Kind.FOLD_CRAB: value = float(c.get("fold", 0.0))
		elif kind == SpeciesScript.Kind.TARDIGRADE: value = float(c.get("tun", 0.0))
		row.min = minf(float(row.min), value)
		row.max = maxf(float(row.max), value)
		row.phase_min = minf(float(row.phase_min), float(c.get("micro_phase", 0.0)))
		row.phase_max = maxf(float(row.phase_max), float(c.get("micro_phase", 0.0)))
		row.twin_seen = bool(row.twin_seen) or bool(c.get("twin", false))
	for controller in exhibit.controllers:
		var positions: PackedVector4Array = controller.material.get_shader_parameter("critter_pos")
		var laws: PackedVector4Array = controller.material.get_shader_parameter("critter_law")
		var count := int(controller.material.get_shader_parameter("critter_count"))
		for slot in mini(count, mini(positions.size(), laws.size())):
			var kind := int(round(positions[slot].w))
			if not observations.has(kind): continue
			var row: Dictionary = observations[kind]
			if row.first_shader_law == null: row.first_shader_law = laws[slot]
			else: row.shader_law_changed = bool(row.shader_law_changed) or (row.first_shader_law as Vector4).distance_to(laws[slot]) > 0.001


func _check_law_results(initial: Dictionary) -> void:
	for kind in SpeciesScript.all_kinds():
		var c: Dictionary = exhibit.specimen_for(kind)
		var row: Dictionary = observations[kind]
		var label := SpeciesScript.name_of(kind)
		_check(label + " remains alive in the actual physics simulation", not c.is_empty()
			and float(c.get("age", -1)) - float(initial[kind].age) >= OBSERVE_SECONDS - 0.1)
		if kind == SpeciesScript.Kind.SEAM_GRAZER:
			_check(label + " produces its second surface appearance", bool(row.twin_seen))
		else:
			var threshold := 0.5 if kind == SpeciesScript.Kind.CRYSTAL_LISTENER else 0.04
			_check(label + " advances its authored law and uploaded shader state",
				float(row.max) - float(row.min) > threshold and bool(row.shader_law_changed))
		if kind >= SpeciesScript.Kind.STENTOR:
			_check(label + " advances its distinct microscopic phase", float(row.phase_max) - float(row.phase_min) > 0.1)
		row["name"] = label
		row["law"] = str(SpeciesScript.rules(kind).law)
		row["first_shader_law"] = str(row.first_shader_law)


func _check_lamp() -> void:
	exhibit.focus_species(SpeciesScript.Kind.TARDIGRADE)
	exhibit.set_lamp_enabled(false)
	await _physics_seconds(1.0)
	var c: Dictionary = exhibit.specimen_for(SpeciesScript.Kind.TARDIGRADE)
	var at: Vector3 = c.pos
	var before_r := exhibit.exposure.total()
	var before_g := _nearby_irradiance(at)
	var texture_id := exhibit.exposure_texture.get_instance_id()
	exhibit.set_lamp_enabled(true)
	await _physics_seconds(2.0)
	var lit_r := exhibit.exposure.total()
	var lit_g := _nearby_irradiance(at)
	await _capture("tardigrade_lit.png")
	exhibit.set_lamp_enabled(false)
	await _physics_seconds(3.0)
	var dark_r := exhibit.exposure.total()
	var dark_g := _nearby_irradiance(at)
	_check("actual inspection lamp grows durable R and reversible G", lit_r > before_r and lit_g > before_g + 0.01)
	_check("lamp-off preserves R while G decays", dark_r >= lit_r and dark_g < lit_g - 0.01)
	_check("field uploads preserve the shared texture object", exhibit.exposure_texture.get_instance_id() == texture_id)
	evidence["lamp"] = {"sample": _v(at), "before_r": before_r, "lit_r": lit_r, "dark_r": dark_r,
		"before_g": before_g, "lit_g": lit_g, "dark_g": dark_g, "texture_id": texture_id}


func _nearby_irradiance(at: Vector3) -> float:
	var maximum := 0.0
	for x in [-0.5, 0.0, 0.5]:
		for y in [-0.5, 0.0, 0.5]:
			for z in [-0.5, 0.0, 0.5]:
				maximum = maxf(maximum, exhibit.exposure.sample_irradiance(at + Vector3(x, y, z)))
	return maximum


func _check_pause_and_reset() -> void:
	exhibit.set_simulation_paused(true)
	var frozen := _state_snapshot()
	var conversion := exhibit.exposure.total()
	await _physics_seconds(0.5)
	_check("pause holds actual specimen state and field conversion", _state_snapshot() == frozen
		and exhibit.exposure.total() == conversion)
	exhibit.set_simulation_paused(false)
	await _physics_seconds(0.2)
	_check("resume advances the actual specimen clock", _state_snapshot() != frozen)
	var material_ids: Array = []
	for controller in exhibit.controllers: material_ids.append(controller.material.get_instance_id())
	var texture_id := exhibit.exposure_texture.get_instance_id()
	exhibit.reset_specimens()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var reset_is_bounded := exhibit.controllers.size() == 2 and exhibit.exposure_texture.get_instance_id() == texture_id
	for i in exhibit.controllers.size():
		reset_is_bounded = reset_is_bounded and exhibit.controllers[i].critters.size() == 8
		reset_is_bounded = reset_is_bounded and exhibit.controllers[i].material.get_instance_id() == material_ids[i]
	_check("reset replaces specimens without adding controllers, materials or fields", reset_is_bounded)


func _physics_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()


func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(output.path_join(filename))
	_check("capture writes " + filename, error == OK)


func _finish() -> void:
	var retained: Array[ShaderMaterial] = []
	if is_instance_valid(exhibit):
		for controller in exhibit.controllers: retained.append(controller.material)
	var retired: WeakRef = weakref(exhibit) if is_instance_valid(exhibit) else null
	if is_instance_valid(exhibit): exhibit.queue_free()
	exhibit = null
	for _frame in 4: await get_tree().process_frame
	_check("exhibit owner is retired", retired == null or retired.get_ref() == null)
	var cleared := true
	for material in retained:
		cleared = cleared and material.get_shader_parameter("exposure_tex") == null
		cleared = cleared and float(material.get_shader_parameter("voxel_optics_enabled")) == 0.0
	_check("retained departed materials release the voxel sampler", cleared)
	retained.clear()
	evidence["checks"] = checks
	evidence["failures"] = failures
	evidence["scope"] = "Isolated DEBUG warehouse: actual sixteen-species batches, live law observations, R/G field response, pause/reset and sampler retirement. Selected Noctiluca receives the explicit debug touch stimulus. This is a scoped scene diagnostic, not a schema-2 runtime_contract, complete hero/margin acceptance, visual judgement or composed performance proof."
	var file := FileAccess.open(output.path_join("dream_ecology_warehouse.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write requested warehouse diagnostic")
		get_tree().quit(2)
		return
	var stored := file.store_buffer(JSON.stringify(evidence, "\t").to_utf8_buffer())
	file.flush()
	var error := file.get_error()
	file.close()
	if not stored or error != OK:
		push_error("Cannot persist requested warehouse diagnostic")
		get_tree().quit(2)
		return
	print("[DREAM ECOLOGY WAREHOUSE] %d/%d passed" % [checks.size() - failures, checks.size()])
	get_tree().quit(0 if failures == 0 else 1)


func _v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed: failures += 1
	print("[DREAM ECOLOGY WAREHOUSE] %s %s" % ["PASS" if passed else "FAIL", label])
