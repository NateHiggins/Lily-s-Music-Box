extends Node3D
const Field := preload("res://scripts/lamp/lamp_optical_voxel_field.gd")
const Reference := preload("res://tests/optical_reference.gd")
const Cloud := preload("res://shaders/optical_cloud.gdshader")
const Receiver := preload("res://shaders/optical_receiver.gdshader")
var camera: Camera3D
var environment: WorldEnvironment
var stable_state := {}
var field: LampOpticalVoxelField
var lamp: LampOpticalInstrument
var checks: Array[Dictionary] = []
var failures := 0
var probe: SubViewport
var probe_material: ShaderMaterial
var probe_points := PackedVector3Array()
var receivers: Array[MeshInstance3D] = []
var samples := {}
var particles: GPUParticles3D
var visualizer: MultiMeshInstance3D
var blocker_mesh: MeshInstance3D
var analytic_materials: Array[StandardMaterial3D] = []
var optical_materials: Array[ShaderMaterial] = []
var output := ""
var readback := PackedByteArray()
var readback_done := false

func _ready() -> void:
	output=OS.get_environment("SHOT_DIR")
	if output.is_empty():output=ProjectSettings.globalize_path("res://evidence/run")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")

func _check(label: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"id":label,"pass":ok,"detail":detail})
	if not ok:
		failures+=1
		push_error("OPTICAL FIELD: "+label+" "+str(detail))

func _frames(n:=3) -> void:
	for i in n:await get_tree().process_frame

func _inject() -> void:
	field.observe(lamp,true)
	await _frames(4)

func _run() -> void:
	environment = WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0.018,0.02,0.025)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=0.025
	add_child(environment)
	camera = Camera3D.new()
	add_child(camera)
	camera.position=Vector3(0.6,0.7,1.2);camera.look_at(Vector3(0,0,-2.5))
	lamp=LampOpticalInstrument.new()
	lamp.quality_tier=0
	add_child(lamp)
	lamp.set_physics_process(false)
	lamp.state.configure(0xD1A6101,true)
	lamp.state.advance(3.0)
	lamp._apply_output()
	stable_state=lamp.state.save_state()
	lamp.position=Vector3(0,0,0)
	field=Field.new()
	field.initialize(0)
	for i in 120:
		if field.ready or not field.failed.is_empty():break
		await _frames(1)
	_check("field_initializes",field.ready,field.failed)
	if not field.ready:
		field.dispose();await _frames(8)
		_finish();return
	await _lifecycle_edges()
	await _inject()
	var near := Vector3(0,0,-1)
	var far := Vector3(0,0,-5)
	_check("on_nonzero",Reference.query(field,near).radiance.length()>0.01)
	_check("near_exceeds_far",Reference.query(field,near).radiance.length()>Reference.query(field,far).radiance.length())
	_check("behind_zero",Reference.query(field,Vector3(0,0,1)).radiance==Vector3.ZERO)
	_check("outside_zero",Reference.query(field,Vector3(5,0,-1)).radiance==Vector3.ZERO)
	_build_probe()
	await _verify_gpu("open")
	await _filtered_probe("open")
	var revision:=field._geometry_revision
	_check("invalid_occluders_rejected",not field.set_occluders([AABB(Vector3(NAN,0,0),Vector3.ONE)],[0.0],[1.0]) and not field.set_occluders([AABB(Vector3.ZERO,Vector3.ONE)],[0.0],[NAN]) and field._geometry_revision==revision)
	await _world_probe("world_bounds",[Vector3(0,0,1),Vector3(5,0,-1),Vector3(0,0,-10),Vector3(.52,.52,-1),Vector3(.5,.5,-8.99)])
	var before: float = Reference.query(field,Vector3(0,0,-3)).radiance.length()
	field.set_occluders([AABB(Vector3(-.35,-.35,-2.2),Vector3(.7,.7,.3))],[0.0],[1.0])
	await _inject()
	_check("sealed_blocker_shadow",Reference.query(field,Vector3(0,0,-3)).radiance.length()<before*0.05)
	_check("outside_shadow_recovery",Reference.query(field,Vector3(1.4,0,-3)).radiance.length()>0.005)
	await _verify_gpu("blocked")
	await _filtered_probe("blocked")
	var penumbra_found := false
	for i in 40:
		var v: float = Reference.query(field,Vector3(.50+i*.002,0,-3)).visibility
		if v>0.0 and v<1.0:penumbra_found=true
	_check("controlled_filtered_shadow_boundary",penumbra_found)
	field.set_occluders([AABB(Vector3(-.7,-.7,-2.1),Vector3(1.4,1.4,.1))],[3.0],[0.0])
	await _inject()
	var thin: float=Reference.query(field,Vector3(0,0,-3)).transmittance
	field.set_occluders([AABB(Vector3(-.7,-.7,-2.4),Vector3(1.4,1.4,.4))],[3.0],[0.0])
	await _inject()
	_check("thickness_reduces_transmission",Reference.query(field,Vector3(0,0,-3)).transmittance<thin)
	field.set_occluders([AABB(Vector3(-.7,-.7,-2.1),Vector3(1.4,1.4,.1)),AABB(Vector3(-.7,-.7,-2.6),Vector3(1.4,1.4,.1))],[3.0,3.0],[0.0,0.0])
	await _inject()
	_check("internal_layers_partially_occlude",Reference.query(field,Vector3(0,0,-3)).transmittance<thin and Reference.query(field,Vector3(0,0,-3)).transmittance>0.0)
	field.set_occluders([],[],[])
	lamp.rotation.y=PI*.5
	await _inject()
	await _verify_gpu("rotated")
	await _world_probe("rotated_old_beam_zero",[Vector3(0,0,-3)])
	_check("rotation_moves_response",Reference.query(field,Vector3(-3,0,0)).radiance.length()>0.005 and Reference.query(field,Vector3(0,0,-3)).radiance==Vector3.ZERO)
	lamp.position=Vector3(4,0,8)
	await _inject()
	await _world_probe("translated_old_beam_zero",[Vector3(-3,0,0),Vector3(0,0,-3)])
	_check("translation_no_history",Reference.query(field,Vector3(-3,0,0)).radiance.length()<0.005)
	lamp.state.switched_on=false
	await _inject()
	_check("off_immediately_zero",not field.enabled and Reference.query(field,Vector3(1,0,0)).radiance==Vector3.ZERO)
	await _verify_gpu("off")
	var off_max := 0.0
	for index in range(0,readback.size(),8):
		for channel in 3:off_max=maxf(off_max,absf(readback.decode_half(index+channel*2)))
	_check("entire_off_texture_zero",off_max==0.0,off_max)
	lamp.position=Vector3.ZERO;lamp.rotation=Vector3.ZERO
	lamp.state.configure(0xD1A6101,true);lamp.state.advance(3.0);lamp._apply_output()
	await _inject()
	var stable := field.stability
	lamp.state.apply_mechanical_shock(1.0);lamp.state.advance(.05);lamp._apply_output()
	await _inject()
	_check("instability_is_observed",field.stability<stable)
	var count:=field.updates
	_check("unchanged_observation_skips_update",not field.observe(lamp) and field.updates==count)
	_build_receivers()
	await _frames(10)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("technical_receivers.png"))
	await _receiver_proofs()
	await _profile()
	probe_material.set_shader_parameter("lamp_radiance",null)
	probe_material.set_shader_parameter("lamp_optics",null)
	field.dispose()
	await _frames(8)
	_check("new_rd_owners_released",_rids_released(field) and (field.near_cascade==null or _rids_released(field.near_cascade)))
	_finish()

func _build_probe() -> void:
	probe=SubViewport.new()
	probe.size=Vector2i(16,1)
	probe.use_hdr_2d=true
	probe.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(probe)
	var rect:=ColorRect.new();rect.size=Vector2(16,1)
	probe_material=ShaderMaterial.new();probe_material.shader=load("res://tests/optical_probe.gdshader")
	field.bind_material(probe_material);rect.material=probe_material;probe.add_child(rect)

func _verify_gpu(label: String) -> void:
	probe_points.clear()
	var cells: Array[Vector3i] = []
	for i in 16:
		var cell:=Vector3i(16+i,24,16+(i%4)*10)
		cells.append(cell);probe_points.append(Reference.cell_world(field,cell))
	probe_material.set_shader_parameter("probe_points",probe_points)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var pixels:=probe.get_texture().get_image()
	var shader_error:=0.0
	for i in 16:
		var reference: Dictionary=Reference.query(field,probe_points[i])
		var result:=pixels.get_pixel(i,0)
		# Off explicitly clears radiance; auxiliary visibility remains geometry data.
		shader_error=maxf(shader_error,maxf(absf(result.r-reference.radiance.x),maxf(absf(result.g-reference.visibility),absf(result.b-reference.transmittance))))
	_check(label+"_receiver_shader_matches",shader_error<0.003,shader_error)
	readback_done=false
	field.debug_readback(func(data: PackedByteArray):readback=data;readback_done=true)
	for i in 120:
		if readback_done:break
		await _frames(1)
	_check(label+"_readback_arrived",readback_done)
	var maximum:=0.0
	if readback_done:
		for i in cells.size():
			var c:=cells[i]
			var offset:=((c.z*field.dimensions.y+c.y)*field.dimensions.x+c.x)*8
			var expected: Vector3=Reference.query(field,probe_points[i]).radiance
			for channel in 3:maximum=maxf(maximum,absf(readback.decode_half(offset+channel*2)-expected[channel]))
	_check(label+"_cpu_gpu_staging_matches",maximum<0.003,maximum)

func _build_receivers() -> void:
	for family in 10:
		var mesh:=MeshInstance3D.new()
		var box:=BoxMesh.new();box.size=Vector3(.58,.6,.01 if family==3 else .45 if family==4 else .10)
		if family==5:box.size=Vector3(.58,.12,.02)
		mesh.mesh=box
		mesh.position=Vector3((family%5-2)*.68,(floorf(family/5.0)-.5)*.8,-2.8)
		var material:=ShaderMaterial.new();material.shader=Cloud if family==4 else Receiver
		material.set_shader_parameter("family",family)
		material.set_shader_parameter("base_color",Vector3(.9,.63,.15) if family==5 else Vector3(.6,.65,.7))
		if family==4:material.set_shader_parameter("volume_to_world",mesh.transform)
		field.bind_material(material);mesh.material_override=material
		add_child(mesh);receivers.append(mesh);optical_materials.append(material)
		var standard:=StandardMaterial3D.new();standard.albedo_color=Color(.6,.65,.7)
		standard.metallic=1.0 if family==5 else 0.0
		analytic_materials.append(standard)
		var label:=Label3D.new();label.text=["OPAQUE","WET","FIBERS","THIN","CYTOPLASM","GOLD","DUST","SSS","GLASS","DEPTH"][family]
		label.font_size=30;label.pixel_size=.0015;label.position=mesh.position+Vector3(0,.37,.1)
		add_child(label)
	var shared:=receivers.size()==10
	for material in optical_materials:shared=shared and material.shader.code.contains("lamp_optical_sample.gdshaderinc")
	_check("all_ten_families_share_sampler",shared)
	particles=GPUParticles3D.new();particles.amount=256;particles.lifetime=10.0
	particles.position=Vector3(0,0,-2.2);particles.preprocess=1.0
	var process:=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents=Vector3(1.2,.7,.5);process.gravity=Vector3(0,.01,0)
	particles.process_material=process
	var dust:=BoxMesh.new();dust.size=Vector3(.012,.012,.012);dust.material=optical_materials[6]
	particles.draw_pass_1=dust;add_child(particles)
	blocker_mesh=MeshInstance3D.new();var blocker:=BoxMesh.new();blocker.size=Vector3(.24,.24,.15)
	blocker_mesh.mesh=blocker;blocker_mesh.position=Vector3(.35,.25,-1.8);add_child(blocker_mesh)
	field.set_occluders([AABB(blocker_mesh.position-blocker.size*.5,blocker.size)],[0.0],[1.0])
	field.observe(lamp,true)
	visualizer=MultiMeshInstance3D.new();var multimesh:=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true
	var voxel:=BoxMesh.new();voxel.size=Vector3(.012,.012,.012)
	var voxel_material:=StandardMaterial3D.new();voxel_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;voxel_material.vertex_color_use_as_albedo=true
	voxel.material=voxel_material;multimesh.mesh=voxel;multimesh.instance_count=512
	for i in 512:
		var cell:=Vector3i(8+(i%8)*4,8+((i/8)%8)*4,8+(i/64)*6)
		var point:=Reference.cell_world(field,cell)
		var value: Vector3=Reference.query(field,point).radiance
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,point))
		multimesh.set_instance_color(i,Color(value.x,value.y,value.z)*2.0)
	visualizer.multimesh=multimesh;add_child(visualizer)

func _profile() -> void:
	probe.render_target_update_mode=SubViewport.UPDATE_DISABLED
	visualizer.visible=false
	field.dispose();await _frames(8)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var matched_state := lamp.state.save_state()
	for configuration in ["empty","analytic","field_no_occlusion","field_occlusion","opaque","transparent_sss","particles","combined_production","combined_hero"]:
		if configuration=="field_no_occlusion":
			field=Field.new();field.initialize(0)
			for i in 120:
				if field.ready:break
				await _frames(1)
			for material in optical_materials:field.bind_material(material)
		if configuration=="combined_hero":
			field.dispose();await _frames(8)
			field=Field.new();field.initialize(1)
			for i in 120:
				if field.ready:break
				await _frames(1)
			for material in optical_materials:field.bind_material(material)
			field.observe(lamp,true);await _frames(5)
			_check("hero_near_cascade_ready",field.near_cascade!=null and field.near_cascade.ready)
			var parent_field:=field
			field=parent_field.near_cascade
			probe.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			field.bind_material(probe_material)
			await _verify_gpu("hero_near")
			_check("hero_near_lateral_resolution",2.0*.05*field.outer/field.dimensions.x<.001,2.0*.05*field.outer/field.dimensions.x)
			field=parent_field
			field.bind_material(probe_material)
			await _filtered_probe("hero_blend")
			probe.render_target_update_mode=SubViewport.UPDATE_DISABLED
		lamp.state.restore_state(matched_state);lamp._apply_output()
		var uses_field: bool=configuration not in ["empty","analytic"]
		for i in receivers.size():
			receivers[i].visible=configuration not in ["empty","particles"]
			if configuration=="opaque":receivers[i].visible=i in [0,1,2,5,9]
			if configuration=="transparent_sss":receivers[i].visible=i in [3,4,7,8]
			receivers[i].material_override=optical_materials[i] if uses_field and configuration not in ["field_no_occlusion","field_occlusion"] else analytic_materials[i]
		particles.visible=configuration in ["particles","combined_production","combined_hero"]
		blocker_mesh.visible=configuration in ["field_occlusion","combined_production","combined_hero"]
		if blocker_mesh.visible:
			field.set_occluders([AABB(Vector3(.23,.13,-1.875),Vector3(.24,.24,.15))],[0.0],[1.0])
		else:
			field.set_occluders([],[],[])
		field.profiling=uses_field
		for i in 30:
			if uses_field:field.observe(lamp,true)
			await _frames(1)
		if field.near_cascade!=null:field.near_cascade.gpu_samples_us.clear();field.near_cascade.construction_us.clear();field.near_cascade.submission_us.clear()
		field.gpu_samples_us.clear();field.construction_us.clear();field.submission_us.clear()
		var gpu_ms: Array[float]=[];var draw_calls: Array[float]=[];var vram: Array[float]=[];var controller: Array[float]=[]
		var allocations_before:=field.resource_allocations;var bindings_before:=field.texture_bindings;var transforms_before:=field.transform_bindings
		var near_updates_before:=field.near_cascade.updates if field.near_cascade!=null else 0
		var near_uploads_before:=field.near_cascade.uploads if field.near_cascade!=null else 0
		var update_frames: Array[float]=[];var upload_frames: Array[float]=[];var readback_frames: Array[float]=[]
		var updates_before:=field.updates;var uploads_before:=field.uploads;var readbacks_before:=field.readbacks
		for i in 120:
			var previous_updates:=field.updates;var previous_uploads:=field.uploads;var previous_readbacks:=field.readbacks
			var start:=Time.get_ticks_usec();lamp.state.advance(1.0/120.0);lamp._apply_output(1.0/120.0)
			controller.append(float(Time.get_ticks_usec()-start))
			if uses_field:field.observe(lamp,true)
			await _frames(1)
			gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
			draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			vram.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
			update_frames.append(field.updates-previous_updates);upload_frames.append(field.uploads-previous_uploads);readback_frames.append(field.readbacks-previous_readbacks)
		samples[configuration]={"construction_us":_stats(field.construction_us),"submission_us":_stats(field.submission_us),"gpu_field_us":_stats(field.gpu_samples_us),"viewport_gpu_ms":_stats(gpu_ms),"draw_calls":_stats(draw_calls),"vram_bytes":_stats(vram),"controller_us":_stats(controller),"updates":field.updates-updates_before,"uploads":field.uploads-uploads_before,"readbacks":field.readbacks-readbacks_before}
		samples[configuration]["updates_per_frame"]=_stats(update_frames)
		samples[configuration]["uploads_per_frame"]=_stats(upload_frames)
		samples[configuration]["readback_calls_per_frame"]=_stats(readback_frames)
		if field.near_cascade!=null:
			samples[configuration]["gpu_near_field_us"]=_stats(field.near_cascade.gpu_samples_us)
			samples[configuration]["near_construction_us"]=_stats(field.near_cascade.construction_us)
			samples[configuration]["near_submission_us"]=_stats(field.near_cascade.submission_us)
			samples[configuration]["near_updates"]=field.near_cascade.updates-near_updates_before
			samples[configuration]["near_uploads"]=field.near_cascade.uploads-near_uploads_before
			_check("hero_near_timing_available",not field.near_cascade.gpu_samples_us.is_empty() and field.near_cascade.gpu_samples_us.min()>0.0)
		_check(configuration+"_persistent_resources",field.resource_allocations==allocations_before and field.texture_bindings==bindings_before and field.transform_bindings==transforms_before)
		_check(configuration+"_no_frame_readback",field.readbacks==readbacks_before)
		_check(configuration+"_gpu_timing_available",gpu_ms.min()>0.0)
		if uses_field:_check(configuration+"_field_timing_available",not field.gpu_samples_us.is_empty() and field.gpu_samples_us.min()>0.0)
		field.profiling=false
		if field.near_cascade!=null:field.near_cascade.profiling=false
		var baseline_vram: float=samples.empty.vram_bytes.median
		var vram_delta: Array[float]=[]
		for value in vram:vram_delta.append(value-baseline_vram)
		samples[configuration]["vram_delta_bytes"]=_stats(vram_delta)
		if configuration in ["opaque","transparent_sss","particles","combined_production","combined_hero"]:
			for material in optical_materials:material.set_shader_parameter("optical_benchmark_bypass",true)
			lamp.state.restore_state(matched_state);lamp._apply_output()
			for i in 30:field.observe(lamp,true);await _frames(1)
			var sampling_delta: Array[float]=[]
			for i in 120:
				lamp.state.advance(1.0/120.0);lamp._apply_output(1.0/120.0);field.observe(lamp,true)
				await _frames(1)
				sampling_delta.append(gpu_ms[i]-RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
			samples[configuration]["gpu_material_sampling_delta_ms"]=_stats(sampling_delta)
			for material in optical_materials:material.set_shader_parameter("optical_benchmark_bypass",false)
	_check("controller_under_020_ms",float(samples.combined_production.controller_us.max)<200.0,samples.combined_production.controller_us)
	var overhead: float=samples.combined_production.viewport_gpu_ms.median-samples.analytic.viewport_gpu_ms.median+samples.combined_production.gpu_field_us.median/1000.0
	_check("production_optical_gpu_overhead_under_2ms",overhead<2.0,overhead)

func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty():return {"available":false}
	var sorted:=values.duplicate();sorted.sort()
	return {"n":sorted.size(),"median":sorted[sorted.size()/2],"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"max":sorted[-1]}

func _track_owners(node: Node, owners: Array[WeakRef]) -> void:
	owners.append(weakref(node))
	if node is MeshInstance3D:
		if node.mesh!=null:owners.append(weakref(node.mesh))
		if node.material_override!=null:owners.append(weakref(node.material_override))
	if node is MultiMeshInstance3D and node.multimesh!=null:owners.append(weakref(node.multimesh))
	if node is GPUParticles3D:
		if node.process_material!=null:owners.append(weakref(node.process_material))
		if node.draw_pass_1!=null:owners.append(weakref(node.draw_pass_1))
	for child in node.get_children():_track_owners(child,owners)

func _release_scene() -> Array[WeakRef]:
	var owners: Array[WeakRef]=[]
	for child in get_children():_track_owners(child,owners);child.queue_free()
	for material in optical_materials:owners.append(weakref(material))
	for material in analytic_materials:owners.append(weakref(material))
	owners.append(weakref(field));owners.append(weakref(field.radiance));owners.append(weakref(field.optics))
	if field.near_cascade!=null:
		owners.append(weakref(field.near_cascade));owners.append(weakref(field.near_cascade.radiance));owners.append(weakref(field.near_cascade.optics))
	for mesh in receivers:mesh.material_override=null
	optical_materials.clear();analytic_materials.clear();receivers.clear()
	probe_material=null;field=null;readback.clear();probe_points.clear()
	return owners

func _finish() -> void:
	var owners:=_release_scene()
	await _frames(8)
	var retained := 0
	for owner in owners:
		if owner.get_ref()!=null:retained+=1
	_check("all_new_scene_owners_released",retained==0,{"observed":owners.size(),"retained":retained})
	var file:=FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"performance":samples,"gpu":RenderingServer.get_video_adapter_name()},"  "))
	print("OPTICAL FIELD: ",checks.size()," checks; ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)

# Rendered receiver proofs use the same actual spatial shader as the fixture.
# Readbacks here are explicit diagnostic captures, outside performance intervals.
func _pixel_capture(name: String = "") -> float:
	await _frames(5)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if not name.is_empty():image.save_png(output.path_join(name+".png"))
	var value := 0.0
	for y in range(310,330):
		for x in range(470,490):
			var pixel := image.get_pixel(x,y)
			value+=(pixel.r+pixel.g+pixel.b)/3.0
	return value/400.0

func _receiver_proofs() -> void:
	var camera_pose := camera.transform
	var positions: Array[Vector3]=[]
	for mesh in receivers:positions.append(mesh.position);mesh.visible=false
	for child in get_children():
		if child is Label3D:child.visible=false
	particles.visible=false;visualizer.visible=false;blocker_mesh.visible=false
	environment.environment.ambient_light_energy=0.0
	environment.environment.background_color=Color.BLACK
	field.set_occluders([],[],[])
	camera.position=Vector3(0,0,-.3);camera.look_at(Vector3(0,0,-2))
	for i in receivers.size():
		var mesh:=receivers[i];mesh.position=Vector3(0,0,-2);mesh.visible=true
		if i==4:optical_materials[i].set_shader_parameter("volume_to_world",mesh.transform)
		lamp.state.restore_state(stable_state);lamp._apply_output();await _inject()
		var on: float=await _pixel_capture("family_%02d_on"%i)
		lamp.state.switched_on=false;lamp._apply_output();await _inject()
		var off: float=await _pixel_capture()
		_check("family_%02d_rendered_on_off"%i,on>off+.001,{"on":on,"off":off})
		lamp.state.restore_state(stable_state);lamp._apply_output();await _inject()
		if i==0:
			field.set_occluders([AABB(Vector3(-.2,-.2,-1),Vector3(.4,.4,.1))],[0.0],[1.0]);await _inject()
			var shadow: float=await _pixel_capture("opaque_carved_shadow")
			_check("rendered_opaque_carved_shadow",shadow<on*.05,{"open":on,"shadow":shadow})
			field.set_occluders([],[],[]);await _inject()
		if i in [3,4,7,8]:
			optical_materials[i].set_shader_parameter("thickness",.01)
			var thin: float=await _pixel_capture()
			optical_materials[i].set_shader_parameter("thickness",.5)
			var thick: float=await _pixel_capture("family_%02d_thick"%i)
			_check("family_%02d_rendered_thickness"%i,absf(thick-thin)>.001,{"thin":thin,"thick":thick})
			optical_materials[i].set_shader_parameter("thickness",.08)
		if i==8:
			optical_materials[i].render_priority=100
			var last: float=await _pixel_capture()
			optical_materials[i].render_priority=-100
			var first: float=await _pixel_capture()
			_check("glass_hash_order_stable",absf(last-first)<.0001,{"first":first,"last":last})
			optical_materials[i].render_priority=0
		if i==5:
			camera.position=Vector3(.9,0,-.3);camera.look_at(mesh.position)
			var updates_before:=field.updates
			var angled: float=await _pixel_capture("gold_angled")
			_check("camera_motion_does_not_reinject",field.updates==updates_before)
			_check("gold_view_dependent_glint",on>angled+.01,{"aligned":on,"angled":angled})
			camera.position=Vector3(0,0,-.3);camera.look_at(mesh.position)
		if i==4:
			field.set_occluders([AABB(Vector3(-.2,-.2,-1.96),Vector3(.4,.4,.035))],[4.0],[.35])
			await _inject()
			var front: float=await _pixel_capture("cloud_front_internal_layer")
			field.set_occluders([AABB(Vector3(-.2,-.2,-2.13),Vector3(.4,.4,.035))],[4.0],[.35])
			await _inject()
			var rear: float=await _pixel_capture("cloud_rear_internal_layer")
			field.set_occluders([AABB(Vector3(-.2,-.2,-1.96),Vector3(.4,.4,.035)),AABB(Vector3(-.2,-.2,-2.13),Vector3(.4,.4,.035))],[4.0,4.0],[.35,.35])
			await _inject()
			var both: float=await _pixel_capture("cloud_two_internal_layers")
			_check("rendered_internal_depth_partial_occlusion",front<rear and both<front and both>0.0,{"open":on,"front":front,"rear":rear,"both":both})
			field.set_occluders([],[],[]);await _inject()
		mesh.visible=false;mesh.position=positions[i]
		if i==4:optical_materials[i].set_shader_parameter("volume_to_world",mesh.transform)
	# Compare equal-duration deterministic temporal sequences on the opaque receiver.
	receivers[0].position=Vector3(0,0,-2);receivers[0].visible=true
	var sequences := {}
	for mode in ["stable","unstable"]:
		lamp.state.restore_state(stable_state)
		var values: Array[float]=[]
		for i in 24:
			lamp.state.advance(1.0/24.0,110.0,1.0 if mode=="unstable" else 0.0)
			lamp._apply_output();await _inject()
			values.append(await _pixel_capture("temporal_"+mode+"_%02d"%i if i in [0,8,16,23] else ""))
		sequences[mode]={"values":values,"range":values.max()-values.min()}
	_check("rendered_temporal_instability",sequences.unstable.range>sequences.stable.range+.005,sequences)
	receivers[0].position=positions[0]
	for mesh in receivers:mesh.visible=true
	for child in get_children():
		if child is Label3D:child.visible=true
	camera.transform=camera_pose
	lamp.state.restore_state(stable_state);lamp._apply_output();await _inject()

func _world_probe(label: String, points: Array[Vector3]) -> void:
	var positions:=PackedVector3Array()
	for i in 16:positions.append(points[i%points.size()])
	probe_material.set_shader_parameter("probe_points",positions)
	await _frames(4);await RenderingServer.frame_post_draw
	var pixels:=probe.get_texture().get_image()
	var maximum:=0.0
	for i in 16:maximum=maxf(maximum,pixels.get_pixel(i,0).r)
	_check(label,maximum==0.0,maximum)

func _rids_released(owner: LampOpticalVoxelField) -> bool:
	return not owner.ready and not owner._radiance_rid.is_valid() and not owner._optics_rid.is_valid() and not owner._buffer.is_valid() and not owner._shader.is_valid() and not owner._pipeline.is_valid() and not owner._set.is_valid()

func _lifecycle_edges() -> void:
	var premature:=Field.new()
	premature.dispose();premature.dispose();premature.initialize()
	await _frames(4)
	_check("dispose_before_init_is_terminal",_rids_released(premature))
	var queued:=Field.new()
	queued.initialize();queued.dispose();queued.dispose()
	await _frames(8)
	_check("queued_init_dispose_releases",_rids_released(queued))
	var allocation_count:=field.resource_allocations
	field.initialize()
	await _frames(3)
	_check("initialize_is_idempotent",field.resource_allocations==allocation_count)

func _filtered_probe(label: String) -> void:
	var positions:=PackedVector3Array()
	for i in 16:
		var depth: float=[.012,.03,.08,.23,.42,.49,.54,.58,.61,.85,1.37,2.14,2.7,3.2,4.9,7.5][i]
		positions.append(field.pose*Vector3(depth*.13,depth*.07,-depth))
	probe_material.set_shader_parameter("probe_points",positions)
	await _frames(4);await RenderingServer.frame_post_draw
	var pixels:=probe.get_texture().get_image()
	var maximum:=0.0
	for i in 16:
		var expected:=Reference.filtered(field,positions[i])
		var pixel:=pixels.get_pixel(i,0)
		maximum=maxf(maximum,maxf(absf(pixel.r-expected.radiance.x),maxf(absf(pixel.g-expected.visibility),absf(pixel.b-expected.transmittance))))
	_check(label+"_filtered_world_samples",maximum<.003,maximum)
