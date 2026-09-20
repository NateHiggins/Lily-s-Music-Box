extends "res://tests/dream_zoo_warehouse_test.gd"
## Native import/batch diagnostic and explicitly labelled review poses.
## Actual ecology observations are recorded separately from forced poses.

var _settings: Environment
var _baseline := false
var _authored_kinds: Array[int] = []

func _capture(filename: String) -> void:
	# Let the render thread consume the new review mode and field before capture.
	for frame in 3:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(output.path_join(filename))
	_check("capture writes " + filename,error==OK)
	if error == OK: _captured.append(filename)

func _run() -> void:
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		get_tree().quit(2)
		return
	_logger = ErrorCapture.new()
	OS.add_logger(_logger)
	_original_mode = GameBoot.launch_mode
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	_baseline = OS.get_environment("DREAM_BLENDER_LEGACY") == "1"
	var environment := WorldEnvironment.new()
	_settings = Environment.new()
	_settings.background_mode = Environment.BG_COLOR
	_settings.background_color = Color(0.035, 0.025, 0.04)
	_settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_settings.ambient_light_color = Color.WHITE
	_settings.ambient_light_energy = 0.4
	environment.environment = _settings
	add_child(environment)
	exhibit = ExhibitScript.new()
	exhibit.position = Vector3(400, 0, 0)
	add_child(exhibit)
	var began := Time.get_ticks_usec()
	exhibit.setup()
	evidence["setup_usec"] = Time.get_ticks_usec() - began
	exhibit.activate(true)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check_population_and_bindings()
	if not _baseline:
		_check("both warehouse batches admit the Blender presentation", exhibit.blender_failures.is_empty()
			and exhibit.controllers[0].blender_visuals != null and exhibit.controllers[1].blender_visuals != null)
		if not exhibit.blender_failures.is_empty():
			evidence["provider_errors"] = exhibit.blender_failures
			await _finish()
			return
		for kind in exhibit.controllers[0].blender_visuals.assets.templates:
			_authored_kinds.append(int(kind))
		for controller in exhibit.controllers:
			_check("compiled batch has one real render surface", controller.mesh_instance.mesh.get_surface_count() == 1)
		_check_atlas()
		var controls = load("res://tests/dream_blender_decoder_controls.gd")
		evidence["decoder_controls"] = controls.run_checks(exhibit.controllers[0].blender_visuals.assets,
			func(passed:bool,label:String): _check(label,passed))
		_check_membranes()
		_check_reordering()
		_check_membership()
	exhibit.focus_species(3)
	exhibit.set_simulation_paused(true)
	await _measure_frames()
	if not _baseline:
		exhibit.set_simulation_paused(false)
		await _observe_pilots()
		exhibit.set_simulation_paused(true)
		await _review_poses()
		evidence["providers"] = [exhibit.controllers[0].blender_visuals.stats(), exhibit.controllers[1].blender_visuals.stats()]
	else:
		await _capture("baseline_tardigrade.png")
	await _finish()


func _check_atlas() -> void:
	var first = exhibit.controllers[0].blender_visuals
	var second = exhibit.controllers[1].blender_visuals
	_check("two batches retain exactly one shared pose atlas", first.assets == second.assets
		and first.assets.texture == second.assets.texture)
	var image: Image = first.assets.texture.get_image()
	var import_rows: Array = []
	for kind in _authored_kinds:
		for lod in [0,1]:
			var template: Dictionary = first.assets.templates[kind][lod]
			var scene = load(template.source).instantiate()
			var result := {"cursor":0,"position_error":0.0,"normal_error":0.0,"normalized":true,"samples":0}
			_compare_import(scene,Transform3D.IDENTITY,template,image,result)
			scene.free()
			_check("species %d LOD%d imported absolute poses match GPU atlas" % [kind,lod],
				result.normalized and result.samples > 1000 and result.position_error < 0.00002
				and result.normal_error < 0.00002 and result.cursor == template.positions.size())
			result["kind"] = kind
			result["lod"] = lod
			import_rows.append(result)
			_check("species %d LOD%d is within its triangle budget" % [kind,lod],
				int(template.triangles) <= (20000 if lod == 0 else 5000))
	_check("pose texture is nearest-ready full precision without mipmaps", image.get_format() == Image.FORMAT_RGBAF
		and not image.has_mipmaps() and image.get_width() == 1024)
	for kind in _authored_kinds:
		for lod in [0,1]:
			var template: Dictionary = first.assets.templates[kind][lod]
			var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(template.manifest))
			for channel in ["foot","cilium"]:
				var source_rows: Array=manifest[channel+"_anchors"]
				var expected_count: int=0 if source_rows.is_empty() else source_rows[0].size()
				var base: int=int(template[channel+"_base"])
				var declared: int=int(template.cilium_anchor_count) if channel=="cilium" else (8 if base>=0 else 0)
				_check("kind%d LOD%d %s atlas ownership matches manifest count"%[kind,lod,channel],
					declared==expected_count and ((base>=0)==(expected_count>0)))
				if expected_count==0: continue
				var maximum_error := 0.0
				for pose in 19:
					for branch in expected_count:
						var expected: Array = source_rows[pose][branch]
						var at: int = ((base+branch)*19+pose)*2
						var texel := image.get_pixel(at%1024,at/1024)
						maximum_error = maxf(maximum_error,Vector3(expected[0],expected[1],expected[2]).distance_to(Vector3(texel.r,texel.g,texel.b)))
				_check("kind%d LOD%d %s roots match every manifest pose"%[kind,lod,channel], maximum_error < 0.00002)
	for kind in _authored_kinds:
		for lod in [0,1]:
			var template: Dictionary=first.assets.templates[kind][lod]
			var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(template.manifest))
			for channel in ["prop","joint","manipulator"]:
				var row_count: int=5 if kind==1 and channel=="prop" else (40 if kind==2 and channel=="joint" else (6 if kind==2 and channel=="manipulator" else 0))
				_check("kind%d LOD%d %s declares exact source row count"%[kind,lod,channel],int(template.get(channel+"_row_count",0))==row_count)
				if row_count==0: continue
				var error := 0.0
				for pose in 19:
					for row in row_count:
						var expected_point: Array
						if channel=="prop": expected_point=manifest.prop_anchors[pose][row]
						elif channel=="joint": expected_point=manifest.rest_joint_chains[floori(float(row)/5.0)][row%5]
						else: expected_point=manifest.rest_manipulator_chains[floori(float(row)/3.0)][row%3]
						var expected:=Vector3(float(expected_point[0]),float(expected_point[1]),float(expected_point[2]))
						var at: int=((int(template[channel+"_base"])+row)*19+pose)*2
						var texel:=image.get_pixel(at%1024,at/1024)
						error=maxf(error,expected.distance_to(Vector3(texel.r,texel.g,texel.b)))
				_check("kind%d LOD%d %s rows match source manifest"%[kind,lod,channel],error<0.00002)
	evidence["import_parity"] = import_rows
	evidence["atlas"] = first.assets.stats()


func _check_membranes() -> void:
	var rows: Array = []
	for controller in exhibit.controllers:
		var provider = controller.blender_visuals
		var membrane: MeshInstance3D = provider.membrane_instance
		var material: ShaderMaterial = provider.membrane_material
		var stats: Dictionary = provider.stats()
		_check("membrane shares its controller frame, world field and pose atlas", membrane.get_parent() == controller.mesh_instance
			and membrane.global_transform == controller.mesh_instance.global_transform
			and membrane.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and material.get_shader_parameter("exposure_tex") == exhibit.exposure_texture
			and material.get_shader_parameter("blender_pose_tex") == provider.assets.texture)
		var split_valid := int(stats.opaque_triangles)+int(stats.membrane_triangles)==int(stats.total_triangles)
		split_valid = split_valid and int(stats.total_triangles)==int(stats.triangles)
		var opaque: Array = controller.mesh_instance.mesh.surface_get_arrays(0)
		split_valid = split_valid and _partition_matches(opaque,false)
		var actual_indices: PackedInt32Array = opaque[Mesh.ARRAY_INDEX].duplicate()
		if int(stats.membrane_triangles)>0:
			split_valid = split_valid and membrane.mesh.get_surface_count()==1
			if membrane.mesh.get_surface_count()==1:
				split_valid = split_valid and _partition_matches(membrane.mesh.surface_get_arrays(0),true)
				actual_indices.append_array(membrane.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX])
		var expected_indices := PackedInt32Array()
		var vertex_offset := 0
		var legacy: PackedInt32Array = controller._build_mesh().surface_get_arrays(0)[Mesh.ARRAY_INDEX].slice(0,21000)
		for section: Dictionary in stats.sections:
			var original: PackedInt32Array = provider.assets.templates[int(section.kind)][int(section.lod)].indices if int(section.lod)>=0 else legacy
			for index in original: expected_indices.append(index+vertex_offset)
			vertex_offset += int(section.vertices)
		split_valid = split_valid and actual_indices.size()==expected_indices.size()
		split_valid = split_valid and _triangle_fingerprint(actual_indices)==_triangle_fingerprint(expected_indices)
		_check("complete envelope and opaque organ triangles form a bounded disjoint partition", split_valid and int(stats.total_triangles)<=84000)
		rows.append(stats)
		controller.unbind_voxel_optics()
		_check("paused membrane unbind releases the shared field immediately", material.get_shader_parameter("exposure_tex") == null)
		controller.bind_voxel_optics(exhibit.exposure_texture,DreamExposureField.EXTENT_M,DreamExposureField.HEIGHT_M)
		_check("paused membrane rebind restores the same field immediately", material.get_shader_parameter("exposure_tex") == exhibit.exposure_texture)
	evidence["membranes"] = rows


func _triangle_fingerprint(indices: PackedInt32Array) -> Vector2i:
	var combined_sum := 0
	var combined_xor := 0
	for at in range(0,indices.size(),3):
		var fingerprint := hash(Vector3i(indices[at],indices[at+1],indices[at+2]))
		combined_sum = (combined_sum+fingerprint)%2147483647
		combined_xor = combined_xor^fingerprint
	return Vector2i(combined_sum,combined_xor)


func _partition_matches(arrays: Array, membrane: bool) -> bool:
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for at in range(0,indices.size(),3):
		var thin := false
		for corner in 3:
			var v := indices[at+corner]
			var region := int(round(colors[v].b*255.0))
			thin = thin or (tags[v].y>999.0 and region in [1,3,4,5])
		if thin != membrane: return false
	return true


func _compare_import(node: Node, parent: Transform3D, template: Dictionary, image: Image, result: Dictionary) -> void:
	var transform: Transform3D = parent * node.transform if node is Node3D else parent
	if node is MeshInstance3D:
		var mesh: ArrayMesh = node.mesh
		result.normalized = result.normalized and mesh.get_blend_shape_mode() == Mesh.BLEND_SHAPE_MODE_NORMALIZED
		for surface in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			var shapes: Array = mesh.surface_get_blend_shape_arrays(surface)
			var count: int = arrays[Mesh.ARRAY_VERTEX].size()
			for pose in [0,1,8,15,16,17,18]:
				var source: Array = arrays if pose == 0 else shapes[pose-1]
				for vertex in count:
					var at: int = ((int(template.atlas_base)+int(result.cursor)+vertex)*19+pose)*2
					var texel := image.get_pixel(at%1024,at/1024)
					var expected: Vector3 = transform * source[Mesh.ARRAY_VERTEX][vertex]
					result.position_error = maxf(result.position_error,expected.distance_to(Vector3(texel.r,texel.g,texel.b)))
					at += 1
					texel = image.get_pixel(at%1024,at/1024)
					expected = (transform.basis.inverse().transposed()*source[Mesh.ARRAY_NORMAL][vertex]).normalized()
					result.normal_error = maxf(result.normal_error,expected.distance_to(Vector3(texel.r,texel.g,texel.b)))
					result.samples += 1
			result.cursor += count
	for child in node.get_children(): _compare_import(child,transform,template,image,result)


func _check_reordering() -> void:
	exhibit.set_simulation_paused(true)
	var controller = exhibit.controllers[0]
	var old_camera: Transform3D = exhibit.camera.global_transform
	controller._push()
	var before: Dictionary = controller.blender_visuals.stats()
	exhibit.camera.global_position += Vector3(80,12,-45)
	controller._push()
	var after: Dictionary = controller.blender_visuals.stats()
	var correct := true
	var positions: PackedVector4Array = controller.material.get_shader_parameter("critter_pos")
	for section: Dictionary in after.sections:
		correct = correct and int(round(positions[int(section.packed_slot)].w)) == int(section.kind)
	_check("eye reordering preserves compiled mesh and maps every stable section to its species",
		before.mesh_id == after.mesh_id and before.rebuild_count == after.rebuild_count and correct)
	exhibit.camera.global_transform = old_camera
	controller._push()
	evidence["reorder"] = {"before":before,"after":after}


func _check_membership() -> void:
	var controller = exhibit.controllers[0]
	var material_id: int = controller.material.get_instance_id()
	var atlas_id: int = controller.blender_visuals.assets.texture.get_instance_id()
	var saved: Array = controller.critters.duplicate(true)
	var victim_id: int = controller.critters[0].id
	controller.critters.remove_at(0)
	controller._push()
	var retired := true
	for section: Dictionary in controller.blender_visuals.stats().sections:
		retired = retired and int(section.id) != victim_id
	_check("retiring an animal removes all compiled sections for its identity", retired)
	controller.critters = saved
	controller._push()
	exhibit.focus_species(3)
	var inspected: Dictionary = controller.blender_visuals.stats()
	var high := false
	for section: Dictionary in inspected.sections:
		if int(section.kind) == 3: high = int(section.lod) == 0
	_check("inspection selects the detailed mesh within the original batch triangle cap", high and int(inspected.triangles) <= 84000)
	exhibit.reset_specimens()
	_check("reset and replacement preserve material, atlas and single world field", controller.material.get_instance_id() == material_id
		and controller.blender_visuals.assets.texture.get_instance_id() == atlas_id
		and controller.material.get_shader_parameter("exposure_tex") == exhibit.exposure_texture)
	var twins := 0
	for section: Dictionary in controller.blender_visuals.stats().sections:
		if bool(section.twin): twins += 1
	evidence["membership"] = {"retired_id":victim_id,"inspection":inspected,"visible_twins":twins}


func _measure_frames() -> void:
	for frame in 35: await RenderingServer.frame_post_draw
	var samples: Array[float] = []
	var start := Time.get_ticks_usec()
	for frame in 240:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append(float(now-start)/1000.0)
		start = now
	samples.sort()
	evidence["frame_sample"] = {"frames":samples.size(),"median_ms":samples[120],"p95_ms":samples[228],
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"scope":"whole isolated warehouse at fixed tardigrade camera, CPU clocks paused; includes hero/margin/architecture; desktop wall-frame interval, not GPU timing"}
	_check("frame measurement records 240 finite intervals", samples.size()==240 and samples[0]>0 and is_finite(samples[239]))


func _observe_pilots() -> void:
	var states := {}
	for kind in _authored_kinds:
		states[kind]={"min":1.0,"max":0.0,"phase_min":INF,"phase_max":-INF}
	var elapsed := 0.0
	while elapsed < 18.0:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		for kind in _authored_kinds:
			var c: Dictionary = exhibit.specimen_for(kind)
			var amount: float = c.tun if kind == 3 else c.micro_state
			var phase: float = c.gait if kind == 3 else c.micro_phase
			if kind == 0: amount=c.unfold; phase=c.gait
			elif kind == 1: amount=fposmod(c.spin,TAU)/TAU; phase=c.spin
			elif kind == 2: amount=c.fold; phase=c.gait
			states[kind].min = minf(states[kind].min,amount)
			states[kind].max = maxf(states[kind].max,amount)
			states[kind].phase_min = minf(states[kind].phase_min,phase)
			states[kind].phase_max = maxf(states[kind].phase_max,phase)
	for kind in _authored_kinds:
		var moving_phase: bool = states[kind].phase_max-states[kind].phase_min>0.2
		var amount_changes: bool = states[kind].max-states[kind].min>(0.8 if kind in [3,6] else 0.25)
		# Noctiluca's flash needs the existing debug stimulus; this passive
		# interval only observes its independent ongoing phase.
		_check("species %d retains its actual live controller clock"%kind,
			moving_phase and (kind in [0,1,2,12] or amount_changes))
	evidence["live_laws"] = {"seconds":elapsed,"states":states,"state_writes":false}


func _review_poses() -> void:
	# The following are controlled diagnostic poses, not gameplay observations.
	var field_samples: Array = []
	for kind in _authored_kinds:
		exhibit.focus_species(kind)
		var c: Dictionary = exhibit.specimen_for(kind)
		var saved: Dictionary = c.duplicate(true)
		if kind == 2:
			# Preserve the live support-frame inputs for the joint silhouette
			# review; these are observations, not new locomotion authority.
			var leg_rows: Array = []
			var up: Vector3 = c.up
			var forward: Vector3 = c.fwd
			var side: Vector3 = up.cross(forward).normalized()
			for leg: Dictionary in c.leg_state:
				var relative: Vector3 = leg.foot-c.pos
				leg_rows.append({"foot_local":[relative.dot(side),relative.dot(up),relative.dot(forward)],
					"stance":leg.was_stance,"phase":leg.phase})
			evidence["fold_live_support"]={"morph":c.morph.duplicate(true),"legs":leg_rows,
				"scope":"Existing CPU support state before controlled review; no floor-contact guarantee."}
		for amount in [0.0,0.5,1.0]:
			_set_review_state(c,kind,amount)
			for controller in exhibit.controllers: controller._push()
			exhibit.set_blender_review_mode(1)
			await _capture("species_%02d_neutral_%03d.png"%[kind,int(amount*100)])
			if amount == 0.5:
				exhibit.set_blender_review_mode(2)
				await _capture("species_%02d_cutaway_050.png"%kind)
		_set_review_state(c,kind,0.0)
		for controller in exhibit.controllers: controller._push()
		exhibit.set_blender_review_mode(0)
		var counts: Array = {0:[3,6,8],1:[5,9,12],2:[2,4,5],4:[10,12],6:[10,11,12],7:[3,5,6],8:[10,12],10:[1],11:[10,12],12:[1,2],15:[10,12]}.get(kind,[])
		if not counts.is_empty():
			var saved_count: int = c.morph.feelers
			for count in counts:
				c.morph.feelers = count
				for controller in exhibit.controllers: controller._push()
				await _capture("species_%02d_cilia_%02d.png"%[kind,count])
			c.morph.feelers = saved_count
			for controller in exhibit.controllers: controller._push()
		if kind in [1,2]:
			var saved_limbs: int = c.morph.limbs
			var saved_legs: Array = c.get("leg_state",[]).duplicate(true)
			for count in ([3,4,5] if kind==1 else [6,7,8]):
				c.morph.limbs=count
				if kind==2:
					c.leg_state=[]
					exhibit.controllers[0]._advance_crab_gait(c,0.0)
					c.fold_leg=count-1
					c.fold=0.8
				for controller in exhibit.controllers: controller._push()
				await _capture("species_%02d_limbs_%02d.png"%[kind,count])
			c.morph.limbs=saved_limbs
			c.leg_state=saved_legs
			if kind==2:
				c.fold=0.0
				for deployment in [0.0,1.0]:
					c.manipulator_deploy=deployment
					for controller in exhibit.controllers: controller._push()
					await _capture("species_02_jaws_%03d.png"%int(deployment*100.0))
			for controller in exhibit.controllers: controller._push()
		_settings.ambient_light_energy = 0.0
		exhibit.inspection_key.light_energy = 0.0
		exhibit.set_lamp_enabled(false)
		exhibit.exposure.pin_irradiance_for_proof(0.0)
		exhibit.exposure.upload(exhibit.exposure_texture)
		await _capture("species_%02d_dark.png"%kind)
		_settings.ambient_light_energy = 0.08
		exhibit.inspection_key.light_energy = 0.55
		exhibit.inspection_key.rotation_degrees = Vector3(-12,-65,0)
		exhibit.exposure.pin_irradiance_for_proof(0.25)
		exhibit.exposure.upload(exhibit.exposure_texture)
		await _capture("species_%02d_oblique.png"%kind)
		exhibit.set_lamp_enabled(true)
		var pose: Dictionary = exhibit.lamp_pose()
		for step in 90:
			exhibit.exposure.add_lamp(pose.origin,pose.dir,pose.range,cos(deg_to_rad(pose.angle_deg*0.5)),1.0,0.1)
		exhibit.exposure.upload(exhibit.exposure_texture)
		field_samples.append({"kind":kind,"stage":"full_beam","exposure":exhibit.exposure.sample(c.pos),"irradiance":exhibit.exposure.sample_irradiance(c.pos)})
		await _capture("species_%02d_full_beam.png"%kind)
		if kind == 5:
			var saved_phase: float = c.micro_phase
			var saved_aux: float = c.micro_aux
			c.micro_state = 1.0
			for scan in [-1.0,0.0,1.0]:
				c.micro_aux = scan
				c.micro_phase = (scan+1.0)*3.14159265
				for controller in exhibit.controllers: controller._push()
				await _capture("species_05_search_%02d.png"%int(scan+1.0))
			c.micro_phase = saved_phase
			c.micro_aux = saved_aux
		if kind == 12:
			exhibit.stimulate_selected()
			c.micro_state = 1.0
			for controller in exhibit.controllers: controller._push()
			await _capture("species_12_debug_flash.png")
		c.merge(saved,true)
		for controller in exhibit.controllers: controller._push()
		_settings.ambient_light_energy = 0.4
		exhibit.inspection_key.light_energy = 1.0
		exhibit.inspection_key.rotation_degrees = Vector3(-55,-28,0)
	evidence["review"] = "Explicit forced law poses 0/0.5/1, neutral/cutaway plus controlled dark/oblique/full-beam lighting. Dark key+ambient+lamp all zero; oblique pinned G=.25; full beam calls original lamp accumulator for9s. Cyclic species use explicitly staged controller phases. Noctiluca debug flash calls the existing debug stimulus and stages its flash value, not a gameplay receptor. These captures are art review, not observed gameplay."
	evidence["review_field_samples"] = field_samples


func _set_review_state(c: Dictionary,kind: int,amount: float) -> void:
	if kind == 0: c.unfold=amount
	elif kind == 1: c.spin=amount*TAU
	elif kind == 2: c.fold=amount; c.fold_leg=0
	elif kind == 3: c.tun = amount
	elif kind == 7:
		c.micro_phase = floor(amount*3.0)
		c.micro_state = floor(amount*3.0)/3.0
	elif kind == 10: c.micro_phase = amount*TAU/1.7
	elif kind == 13: c.micro_phase = amount*TAU
	elif kind == 15: c.micro_phase = amount*TAU/0.22
	else: c.micro_state = amount


func _blender_retirement_observers() -> Array[WeakRef]:
	var refs: Array[WeakRef] = []
	for controller in exhibit.controllers:
		if controller.blender_visuals != null:
			refs.append(weakref(controller.blender_visuals))
			refs.append(weakref(controller.blender_visuals.assets))
			refs.append(weakref(controller.blender_visuals.assets.texture))
			refs.append(weakref(controller.blender_visuals.membrane_instance))
	return refs


func _finish() -> void:
	var retained: Array[ShaderMaterial] = []
	var refs := _blender_retirement_observers() if is_instance_valid(exhibit) else []
	if is_instance_valid(exhibit):
		for controller in exhibit.controllers:
			retained.append(controller.material)
			if controller.blender_visuals != null: retained.append(controller.blender_visuals.membrane_material)
		exhibit.queue_free()
	exhibit = null
	for frame in 5: await get_tree().process_frame
	_check("departed providers and the shared atlas are released", _all_retired(refs))
	var cleared := true
	for material in retained:
		cleared = cleared and material.get_shader_parameter("exposure_tex") == null
		cleared = cleared and material.get_shader_parameter("blender_pose_tex") == null
	_check("retained materials release both world and pose samplers", cleared)
	retained.clear()
	GameBoot.launch_mode = _original_mode
	var logs := _logger.snapshot()
	_check("no native script, shader or runtime errors", logs.errors.is_empty())
	OS.remove_logger(_logger)
	_logger = null
	evidence["schema"] = "dream_blender_critter_diagnostic.v1"
	evidence["evidence_class"] = "INERT"
	evidence["scope"] = "Native imported researched anatomy, absolute morph atlas, stable section mapping, existing controller cycles, controlled review poses and sampler retirement; not campaign runtime_contract or artistic acceptance."
	evidence["baseline"] = _baseline
	evidence["logs"] = logs
	evidence["checks"] = checks
	evidence["failures"] = failures
	var file := FileAccess.open(output.path_join("dream_blender_critters.json"),FileAccess.WRITE)
	if file == null:
		get_tree().quit(2)
		return
	file.store_buffer(JSON.stringify(evidence,"\t").to_utf8_buffer())
	file.close()
	print("[DREAM BLENDER CRITTERS] %d/%d passed"%[checks.size()-failures,checks.size()])
	get_tree().quit(0 if failures == 0 else 1)
