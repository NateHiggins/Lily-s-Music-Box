extends "res://tests/dream_ecology_warehouse_test.gd"
## Scoped DEBUG zoo diagnostic. Reuses the sixteen-species binding checks;
## adds actual hero/organ display motion, placeholder navigation and retirement.
## No Blender export parity, complete gameplay, visual or performance acceptance.

const HERO_OBSERVE_SECONDS := 8.0
const EXPECTED_PLACEHOLDERS: Array[String] = [
	"jewelfruit", "spiralings", "chandelettes", "bezel_beetles", "deep_koi", "parliaments",
	"gilders_buttons", "tessellates", "wine_anemones", "ribbonettes", "the_loupe",
	"dream_pursuer", "dream_hazards", "dream_surface_tissue", "case_incarnation_surfaces",
]

class ErrorCapture:
	extends Logger
	var _guard := Mutex.new()
	var _errors: Array[Dictionary] = []
	var _warnings: Array[Dictionary] = []
	var _stderr: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		_guard.lock()
		var row := {"function": function, "file": file, "line": line,
			"code": code, "rationale": rationale, "type": error_type}
		if error_type == Logger.ERROR_TYPE_WARNING: _warnings.append(row)
		else: _errors.append(row)
		_guard.unlock()
	func _log_message(message: String, error: bool) -> void:
		if not error: return
		_guard.lock()
		_stderr.append(message)
		_guard.unlock()
	func snapshot() -> Dictionary:
		_guard.lock()
		var result := {"errors": _errors.duplicate(true),
			"warnings": _warnings.duplicate(true), "stderr": _stderr.duplicate()}
		_guard.unlock()
		return result

var _logger: ErrorCapture
var _original_mode := 0
var _captured: Array[String] = []


func _run() -> void:
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("DreamZooWarehouseTest requires writable SHOT_DIR")
		get_tree().quit(2)
		return
	_logger = ErrorCapture.new()
	OS.add_logger(_logger)
	_original_mode = GameBoot.launch_mode
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	_check_debug_refusal()
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	_build_environment()
	exhibit = ExhibitScript.new()
	exhibit.position = Vector3(400, 0, 0)
	add_child(exhibit)
	exhibit.setup()
	exhibit.activate(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var constructed: bool = is_instance_valid(exhibit.organelle) and is_instance_valid(exhibit.hero)
	constructed = constructed and bool(exhibit.organelle.stats().get("initialized", false))
	_check("zoo constructs its real organ adapter and hero", constructed)
	if not constructed:
		await _finish()
		return
	_check_population_and_bindings()
	_check("actual global viewing stand remains supported by the hall", exhibit.hall_aabb().has_point(exhibit.viewing_stand())
		and _supported(exhibit.viewing_stand()))
	_check_placeholder_catalogue()
	_check_hero_anatomy()
	await _observe_live_organs()
	await _check_zoo_pause()
	await _check_zoo_selections()
	_check_population_and_bindings()
	evidence["final_stats"] = exhibit.stats()
	evidence["final_organelle"] = exhibit.organelle.stats()
	evidence["final_hero"] = exhibit.hero.census()
	await _finish()


func _check_debug_refusal() -> void:
	var refused := ExhibitScript.new()
	add_child(refused)
	refused.setup()
	_check("non-DEBUG setup creates no zoo, organelle, hero or controller",
		refused.get_child_count() == 0 and refused.controllers.is_empty()
		and refused.organelle == null and refused.hero == null and refused.exposure == null)
	refused.free()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.055, 0.06, 0.075)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.75, 0.82, 1.0)
	settings.ambient_light_energy = 0.45
	world_environment.environment = settings
	add_child(world_environment)


func _supported(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.15,
		point - Vector3.UP * 3.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit.normal as Vector3).dot(Vector3.UP) > 0.99


func _check_placeholder_catalogue() -> void:
	var seen := {}
	var valid := exhibit.placeholders.size() == 15 and EXPECTED_PLACEHOLDERS.size() == 15
	for record: Dictionary in exhibit.placeholders:
		var id := str(record.get("id", ""))
		valid = valid and EXPECTED_PLACEHOLDERS.has(id) and not seen.has(id)
		valid = valid and not str(record.get("label", "")).is_empty()
		valid = valid and not str(record.get("description", "")).is_empty()
		seen[id] = true
	for id in EXPECTED_PLACEHOLDERS:
		valid = valid and seen.has(id) and exhibit.stations.has(id)
	_check("fifteen unique named placeholders exactly match the wider-life catalogue", valid)
	evidence["placeholder_ids"] = seen.keys()


func _check_hero_anatomy() -> void:
	var census: Dictionary = exhibit.hero.census()
	_check("hero instantiates authored skinned geometry and the deform rig",
		int(census.get("meshes", 0)) > 1 and int(census.get("skinned", 0)) > 0
		and int(census.get("deform_bones", 0)) == 28 and bool(census.get("skeleton", false)))
	_check("hero retains real eye and three lid bones", int(census.get("eye_bone", -1)) >= 0
		and int(census.get("lid_bones", 0)) == 3)
	var dressed := not exhibit.hero.meshes.is_empty()
	var triangles := 0
	var skinned := 0
	for mesh: MeshInstance3D in exhibit.hero.meshes:
		dressed = dressed and mesh.mesh != null and mesh.material_override is ShaderMaterial
		if mesh.material_override is ShaderMaterial:
			dressed = dressed and mesh.material_override.shader == exhibit.hero.SKIN
		dressed = dressed and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.skin != null:
			skinned += 1
			dressed = dressed and mesh.get_node_or_null(mesh.skeleton) == exhibit.hero.skeleton
		if mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				triangles += indices.size() / 3 if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check("real hero meshes use the production skin and skeleton without shadow casting",
		dressed and skinned == int(census.get("skinned", 0)) and triangles > 1000)
	evidence["hero_anatomy"] = {"census": census, "triangles": triangles, "skinned_meshes": skinned}


func _organ_snapshot() -> Dictionary:
	var result: Dictionary = exhibit.organelle.stats().duplicate(true)
	result["hero_clock"] = float(exhibit.hero._clock)
	result["hero_tip"] = _v(exhibit.hero.tip_world())
	result["hero_pose"] = _hero_pose()
	result["margin_clock"] = float(exhibit.margin._clock)
	return result


func _hero_pose() -> Array:
	var result: Array = []
	if exhibit.hero.skeleton != null:
		for bone in exhibit.hero.skeleton.get_bone_count():
			var pose := exhibit.hero.skeleton.get_bone_pose_rotation(bone)
			result.append([pose.x, pose.y, pose.z, pose.w])
	return result


func _observe_live_organs() -> void:
	exhibit.focus_organelle()
	await get_tree().process_frame
	var initial := _organ_snapshot()
	var initial_pose: Array = initial.hero_pose
	var pose_changed := false
	var tip_changed := false
	var elapsed := 0.0
	var frames := 0
	while elapsed < HERO_OBSERVE_SECONDS and frames < 60000:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		frames += 1
		pose_changed = pose_changed or _hero_pose() != initial_pose
		tip_changed = tip_changed or exhibit.hero.tip_world().distance_to(Vector3(
			initial.hero_tip[0], initial.hero_tip[1], initial.hero_tip[2])) > 0.001
	var final := _organ_snapshot()
	_check("eight seconds advance the real hero clock and bone poses",
		elapsed >= HERO_OBSERVE_SECONDS and float(final.hero_clock) - float(initial.hero_clock) >= 7.8
		and pose_changed and tip_changed)
	_check("the real LivingField advances steps and its clock", int(final.get("living_steps", 0)) > int(initial.get("living_steps", 0))
		and float(final.get("living_clock", 0.0)) > float(initial.get("living_clock", 0.0)))
	_check("organelle display has populated cells and actual surface tendrils",
		int(final.get("living_cells", 0)) > 0 and int(final.get("tendrils", {}).get("live", 0)) > 0)
	_check("architecture panel samples the actual populated RGBA8 LivingField",
		int(final.get("living_format", -1)) == Image.FORMAT_RGBA8
		and exhibit.organelle.panel_material.get_shader_parameter("living_tex") == exhibit.organelle.living.texture()
		and bool(exhibit.organelle.panel_material.get_shader_parameter("has_living")))
	_check_tendril_bounds()
	_check_margin_display()
	var listener: Dictionary = exhibit.specimen_for(SpeciesScript.Kind.CRYSTAL_LISTENER)
	_check("the existing listener is the nearby wall recipient",
		not listener.is_empty() and (listener.pos as Vector3).distance_to(exhibit.organelle.recipient_position()) < 0.30
		and (listener.up as Vector3).dot(Vector3.BACK) > 0.99)
	evidence["live_observation"] = {"elapsed_seconds": elapsed, "frames": frames,
		"initial": initial, "final": final, "pose_changed": pose_changed, "tip_changed": tip_changed}
	await _capture("hero_full_ensemble.png")


func _check_tendril_bounds() -> void:
	var tendrils: DreamSurfaceTendrils = exhibit.organelle.tendrils
	var mesh: MeshInstance3D = tendrils.mesh_instance
	# get_aabb() reports undeformed vertices. ArrayMesh.custom_aabb is the
	# renderer's separate culling override for these shader-positioned spines.
	var bounds: AABB = mesh.mesh.custom_aabb if mesh.mesh is ArrayMesh else AABB()
	var raw_bounds := mesh.mesh.get_aabb()
	var inside := bounds.has_point(mesh.to_local(exhibit.organelle.focus_position()))
	var live := 0
	for slot in tendrils._life.size():
		if tendrils._life[slot] < 0.0: continue
		live += 1
		inside = inside and bounds.has_point(mesh.to_local(tendrils._anchor[slot]))
		for joint in tendrils.JOINTS:
			inside = inside and bounds.has_point(mesh.to_local(tendrils._spine[slot * tendrils.JOINTS + joint]))
	_check("translated tendril draw bounds contain actual live anchors and spine points",
		live > 0 and bounds.has_volume() and inside and mesh.global_transform.is_equal_approx(Transform3D.IDENTITY))
	evidence["tendril_bounds"] = {"position": _v(bounds.position), "size": _v(bounds.size),
		"live_slots": live, "live_geometry_inside": inside,
		"source": "ArrayMesh.custom_aabb", "raw_vertex_position": _v(raw_bounds.position),
		"raw_vertex_size": _v(raw_bounds.size),
		"identity_transform": mesh.global_transform.is_equal_approx(Transform3D.IDENTITY)}


func _check_margin_display() -> void:
	var by_kind := {}
	var living_records := true
	var displayed := true
	var mesh: MeshInstance3D = exhibit.palps.mesh_instance
	var bounds: AABB = mesh.mesh.custom_aabb if mesh.mesh is ArrayMesh else AABB()
	var raw_bounds := mesh.mesh.get_aabb()
	var inside := true
	var bounded_draws := 0
	for palp: Dictionary in exhibit.margin.palps:
		if exhibit.palps.drawn_ids.has(int(palp.id)):
			bounded_draws += 1
			inside = inside and bounds.has_point(mesh.to_local(palp.anchor))
			inside = inside and bounds.has_point(mesh.to_local(palp.tip))
		if int(palp.get("parent", -1)) >= 0 or int(palp.tier) != 0: continue
		by_kind[int(palp.morph.kind)] = true
		living_records = living_records and float(palp.age) > 1.2
		displayed = displayed and exhibit.palps.drawn_ids.has(int(palp.id))
	var all_six := true
	for kind in 6: all_six = all_six and by_kind.has(kind)
	var draw: Dictionary = exhibit.palps.census()
	_check("six arranged margin archetypes remain live and advance with the controller",
		all_six and living_records and not exhibit.margin.frozen and exhibit.margin.is_physics_processing())
	_check("the real palp renderer submits margin geometry", int(draw.get("drawn", 0)) >= 6
		and displayed and int(draw.get("vertices", 0)) > 0 and exhibit.palps.mesh_instance.visible)
	_check("translated palp draw bounds contain actual rendered anchors and tips",
		bounded_draws >= 6 and bounds.has_volume() and inside and mesh.global_transform.is_equal_approx(Transform3D.IDENTITY))
	evidence["margin"] = {"kinds": by_kind.keys(), "controller": exhibit.margin.census(), "renderer": draw}
	evidence["palp_bounds"] = {"position": _v(bounds.position), "size": _v(bounds.size),
		"bounded_draws": bounded_draws, "live_geometry_inside": inside,
		"source": "ArrayMesh.custom_aabb", "raw_vertex_position": _v(raw_bounds.position),
		"raw_vertex_size": _v(raw_bounds.size),
		"identity_transform": mesh.global_transform.is_equal_approx(Transform3D.IDENTITY)}


func _check_zoo_pause() -> void:
	exhibit.set_simulation_paused(true)
	await get_tree().process_frame
	var initial := _organ_snapshot()
	var paused_emissions := int(initial.get("signals", {}).get("emitted", 0))
	_check("paused organelle refuses a debug secretion without emitting a packet",
		not exhibit.organelle.pulse()
		and int(exhibit.organelle.stats().get("signals", {}).get("emitted", -1)) == paused_emissions)
	await _physics_seconds(0.5)
	var paused := _organ_snapshot()
	_check("pause holds the hero clock, actual bone poses and LivingField clock/steps",
		initial.hero_clock == paused.hero_clock and initial.hero_pose == paused.hero_pose
		and initial.get("living_clock", -1) == paused.get("living_clock", -2)
		and initial.get("living_steps", -1) == paused.get("living_steps", -2)
		and bool(paused.get("paused", false)))
	exhibit.set_simulation_paused(false)
	await _physics_seconds(0.5)
	var resumed := _organ_snapshot()
	_check("resume advances both real owners", float(resumed.hero_clock) > float(paused.hero_clock)
		and int(resumed.get("living_steps", 0)) > int(paused.get("living_steps", 0))
		and not bool(resumed.get("paused", true)))
	var emissions := int(resumed.get("signals", {}).get("emitted", 0))
	var secretions := int(exhibit.hero.secretion_events)
	_check("active debug pulse uses one real hero secretion and director packet",
		exhibit.organelle.pulse() and exhibit.hero.secretion_events == secretions + 1
		and int(exhibit.organelle.stats().get("signals", {}).get("emitted", -1)) == emissions + 1)
	evidence["pause"] = {"before": initial, "paused": paused, "resumed": resumed}


func _check_zoo_selections() -> void:
	exhibit.focus_organelle()
	await get_tree().process_frame
	_check("organelle selection names the live display and frames it", exhibit.selected_exhibit == "organelle"
		and not exhibit._title.text.is_empty() and _camera_sees(exhibit.organelle.focus_position()))
	await _capture("organelle.png")
	exhibit.focus_hero()
	await get_tree().process_frame
	_check("hero close-up follows the actual moving tip", exhibit.selected_exhibit == "hero"
		and exhibit._title.text.to_upper().contains("HERO") and _camera_sees(exhibit.hero.tip_world()))
	await _capture("hero_tip_close.png")
	var selections: Array = []
	for record: Dictionary in exhibit.placeholders:
		var id := str(record.id)
		exhibit.focus_placeholder(id)
		await get_tree().process_frame
		var station: Marker3D = exhibit.stations.get(id)
		var inside := station != null and exhibit.hall_aabb().has_point(station.global_position)
		var framed := station != null and _camera_sees(station.global_position)
		var labelled := exhibit._title.text.to_lower().contains(str(record.label).to_lower())
		var described := exhibit._status.text.contains(str(record.description))
		var sightline: Dictionary = _camera_path_sample(station.global_position) if station != null else {"clear": false}
		_check("placeholder %s selects its own labelled, described and framed bay" % id,
			exhibit.selected_exhibit == id and labelled and described and inside and framed)
		_check("placeholder %s camera remains within the hall" % id,
			exhibit.hall_aabb().has_point(exhibit.camera.global_position))
		_check("placeholder %s centre sightline clears physical hall geometry" % id, bool(sightline.clear))
		selections.append({"id": id, "title": exhibit._title.text, "status": exhibit._status.text,
			"camera": _v(exhibit.camera.global_position), "inside": inside, "framed": framed,
			"sightline": sightline})
		await _capture("placeholder_" + id + ".png")
	await _check_occlusion_control()
	exhibit.focus_species(SpeciesScript.Kind.TARDIGRADE)
	await get_tree().process_frame
	_check("species selection leaves placeholder mode", exhibit.selected_exhibit.is_empty()
		and exhibit.selected_kind == SpeciesScript.Kind.TARDIGRADE)
	evidence["selections"] = selections
	exhibit._overview = true
	await _capture("zoo_overview.png")


func _camera_sees(point: Vector3) -> bool:
	return not exhibit.camera.is_position_behind(point) and get_viewport().get_visible_rect().has_point(
		exhibit.camera.unproject_position(point))


func _camera_path_sample(point: Vector3) -> Dictionary:
	# Collision centreline only: screenshots still own visual review of signs,
	# non-colliding decoration, the full frame, and readability behind the GUI.
	var query := PhysicsRayQueryParameters3D.create(exhibit.camera.global_position, point, 1)
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return {"clear": hit.is_empty(), "from": _v(query.from), "to": _v(point),
		"collider": str(hit.collider.get_path()) if not hit.is_empty() else "",
		"hit": _v(hit.position) if not hit.is_empty() else []}


func _check_occlusion_control() -> void:
	var station: Marker3D = exhibit.stations.get("case_incarnation_surfaces")
	if station == null:
		_check("occlusion control has its catalogue station", false)
		return
	var point := station.global_position
	var blocker := StaticBody3D.new()
	blocker.name = "SightlineNegativeControl"
	blocker.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 0.4
	shape.shape = box
	blocker.add_child(shape)
	add_child(blocker)
	blocker.global_position = exhibit.camera.global_position.lerp(point, 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var obstructed := _camera_path_sample(point)
	_check("sightline test detects a real inserted blocking body", not bool(obstructed.clear)
		and str(obstructed.collider).ends_with("/SightlineNegativeControl"))
	blocker.queue_free()
	blocker = null
	await get_tree().physics_frame
	await get_tree().physics_frame
	var restored := _camera_path_sample(point)
	_check("sightline clears when the same blocking body is removed", bool(restored.clear))
	evidence["occlusion_control"] = {"obstructed": obstructed, "restored": restored,
		"scope": "physical centreline; not all-pixel visual occlusion proof"}


func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(output.path_join(filename))
	_check("capture writes " + filename, error == OK)
	if error == OK: _captured.append(filename)


func _retirement_observers() -> Dictionary:
	var owners: Array[WeakRef] = []
	var retained: Array[ShaderMaterial] = []
	for node in [exhibit, exhibit.hero, exhibit.organelle, exhibit.organelle.living,
			exhibit.organelle.receiver, exhibit.organelle.tendrils, exhibit.margin,
			exhibit.palps, exhibit.voxel_binding, exhibit.field, exhibit.residue,
			exhibit.director, exhibit.camera, exhibit.exposure, exhibit.exposure_texture]:
		if is_instance_valid(node): owners.append(weakref(node))
	for controller in exhibit.controllers:
		owners.append(weakref(controller))
		retained.append(controller.material)
	return {"owners": owners, "materials": retained, "panel": exhibit.organelle.panel_material}


func _all_retired(refs: Array) -> bool:
	# Observe weak references in a synchronous frame; no suspended strong local.
	for ref: WeakRef in refs:
		if ref.get_ref() != null: return false
	return true


func _finish() -> void:
	var observers := {}
	if is_instance_valid(exhibit):
		if is_instance_valid(exhibit.organelle): observers = _retirement_observers()
		exhibit.queue_free()
	exhibit = null
	for _frame in 5: await get_tree().process_frame
	if not observers.is_empty():
		_check("zoo, organelle and fauna owners are released", _all_retired(observers.owners))
		var samplers_cleared := true
		for material: ShaderMaterial in observers.materials:
			samplers_cleared = samplers_cleared and material.get_shader_parameter("exposure_tex") == null
			samplers_cleared = samplers_cleared and float(material.get_shader_parameter("voxel_optics_enabled")) == 0.0
		_check("retained fauna materials release their departed field", samplers_cleared)
		_check("retained architecture material releases the retired LivingField",
			observers.panel != null and observers.panel.get_shader_parameter("living_tex") == null
			and not bool(observers.panel.get_shader_parameter("has_living")))
		observers.clear()
	GameBoot.launch_mode = _original_mode
	var logs := _logger.snapshot()
	_check("no runtime, script or shader error occurred during this diagnostic", logs.errors.is_empty())
	OS.remove_logger(_logger)
	_logger = null
	evidence["schema"] = "dream_zoo_warehouse_diagnostic.v1"
	evidence["evidence_class"] = "INERT"
	evidence["scope"] = "Isolated DEBUG scene: sixteen existing specimens, authored hero rig/skin and eight seconds of actual pose motion, arranged live margin, LivingField/tendrils, pause/resume, fifteen placeholder selections and owner retirement. Captures are review material, not visual acceptance. No Blender source/export parity, all-organ interactions, full lifecycle, campaign runtime_contract or performance proof."
	evidence["logs"] = logs
	evidence["checks"] = checks
	evidence["failures"] = failures
	evidence["captures"] = _captured
	evidence["headless"] = DisplayServer.get_name() == "headless"
	var file := FileAccess.open(output.path_join("dream_zoo_warehouse.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write requested zoo diagnostic")
		get_tree().quit(2)
		return
	var stored := file.store_buffer(JSON.stringify(evidence, "\t").to_utf8_buffer())
	file.flush()
	var error := file.get_error()
	file.close()
	if not stored or error != OK:
		push_error("Cannot persist requested zoo diagnostic")
		get_tree().quit(2)
		return
	print("[DREAM ZOO WAREHOUSE] %d/%d passed" % [checks.size() - failures, checks.size()])
	get_tree().quit(0 if failures == 0 else 1)


func _check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed: failures += 1
	print("[DREAM ZOO WAREHOUSE] %s %s" % ["PASS" if passed else "FAIL", label])
