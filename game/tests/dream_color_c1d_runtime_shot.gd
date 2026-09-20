extends Node3D
## C1D is a one-image stop gate. It replaces visible membrane/interior meshes
## with one bounded organism-local raymarch while retaining the real L1C lamp.

const Lamp=preload("res://scripts/lamp/lamp_optical_instrument.gd")
const VOLUME_SHADER=preload("res://shaders/dream_c1d_volumetric_microscopy.gdshader")

var out_dir:String
var camera:Camera3D
var production_root:Node3D
var volume:MeshInstance3D
var volume_material:ShaderMaterial
var lamp:Node3D
var exposure:DreamExposureField
var exposure_texture:ImageTexture3D
var exposure_updates:=0
var exposure_uploads:=0
var exposure_snapshot:Dictionary={}
var diagnostic_overlay:CanvasLayer
var diagnostic_label:Label
var evidence:Dictionary={}
var profiles:Dictionary={}
var vram_baseline:=0


func _ready() -> void:
	out_dir=OS.get_environment("C1D_OUT")
	if out_dir.is_empty() or not out_dir.is_absolute_path():
		push_error("C1D_OUT must be an absolute path")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	await _prepare_furnished_orison()
	evidence={
		"task":"C1C-V / DREAM-COLOR-C1D voxel data-path gate",
		"renderer":RenderingServer.get_current_rendering_method(),
		"resolution":"1600x900",
		"c1c_checkpoint":{"technical_compatibility":"PASS","visual_acceptance":"FAIL","preserved_honestly":true},
	}
	for _i in 16: await RenderingServer.frame_post_draw
	vram_baseline=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	await _profile("furnished_orison_baseline")

	_build_exposure_field()
	_build_volume()
	_build_real_l1c_lamp()
	await _drive_exposure_from_real_lamp()
	_apply_physical_lamp_uniforms()
	for _i in 30: await RenderingServer.frame_post_draw

	volume.visible=false
	await _profile("furnished_orison_plus_lamp")
	volume.visible=true
	lamp.visible=false
	await _profile("furnished_orison_plus_cell")
	lamp.visible=true
	await _profile("furnished_orison_plus_cell_lamp")

	# Exactly one three-panel diagnostic image is written by this harness.
	var panels:Array[Image]=[]
	panels.append(await _capture_diagnostic_panel(0,"1  L1C PHYSICAL ONLY"))
	panels.append(await _capture_diagnostic_panel(1,"2  VOXEL FIELD ONLY"))
	panels.append(await _capture_diagnostic_panel(2,"3  COMBINED / DEBUG OFF"))
	_write_three_panel_artifact(panels)

	await _verify_lamp_restore()
	await _teardown()
	_write_receipts()
	print("[COLOR-C1D] ONE-IMAGE STOP GATE -> %s" % out_dir)
	get_tree().quit(0)


func _prepare_furnished_orison() -> void:
	OS.set_environment("DAYNIGHT","0")
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	production_root=load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(production_root)
	for _i in 150: await get_tree().process_frame
	var player=production_root.get("player")
	if player:
		player.set_process(false)
		player.set_physics_process(false)
		player.visible=false
		if player.has_method("set_lamp_enabled"): player.set_lamp_enabled(false)
		if player.has_method("set_beam_mask_enabled"): player.set_beam_mask_enabled(false)
	_hide_ui(production_root)
	var switch_system=production_root.get("switch_system")
	if switch_system and switch_system.has_method("toggle_room"):
		if not switch_system.toggle_room("F01_D_BED"):
			switch_system.toggle_room("F01_D_BED")
	_configure_room_environment()
	camera=Camera3D.new()
	camera.fov=38.5
	add_child(camera)
	camera.global_position=GameBoot.b2g([7.95,-6.65,1.62])
	camera.look_at(GameBoot.b2g([11.55,-7.15,1.08]),Vector3.UP)
	camera.make_current()
	for _i in 24: await RenderingServer.frame_post_draw


func _configure_room_environment() -> void:
	var worlds:Array[WorldEnvironment]=[]
	_collect_world_environments(production_root,worlds)
	if worlds.is_empty() or worlds[0].environment==null: return
	var env:Environment=worlds[0].environment.duplicate(true)
	env.volumetric_fog_enabled=true
	env.volumetric_fog_density=.00008
	env.volumetric_fog_length=12.0
	env.volumetric_fog_detail_spread=1.8
	env.volumetric_fog_temporal_reprojection_enabled=true
	env.volumetric_fog_temporal_reprojection_amount=.58
	env.tonemap_mode=Environment.TONE_MAPPER_ACES
	env.tonemap_exposure=minf(env.tonemap_exposure,1.07)
	worlds[0].environment=env


func _build_volume() -> void:
	volume=MeshInstance3D.new()
	volume.name="SingleBoundedVolumetricSpecimen"
	var bound:=BoxMesh.new()
	bound.size=Vector3(2.0,2.0,2.0)
	volume.mesh=bound
	volume_material=ShaderMaterial.new()
	volume_material.shader=VOLUME_SHADER
	volume.material_override=volume_material
	volume_material.set_shader_parameter("exposure_tex",exposure_texture)
	volume_material.set_shader_parameter("exposure_extent",DreamExposureField.EXTENT_M)
	volume_material.set_shader_parameter("exposure_height",DreamExposureField.HEIGHT_M)
	add_child(volume)
	var forward:Vector3=-camera.global_transform.basis.z.normalized()
	var right:Vector3=camera.global_transform.basis.x.normalized()
	volume.global_position=camera.global_position+forward*2.78+right*.26-Vector3.UP*.05
	volume.scale=Vector3(1.48,.69,.94)
	volume.rotation_degrees=Vector3(-4.0,19.0,-3.0)
	camera.look_at(volume.global_position+Vector3.UP*.02,Vector3.UP)
	_build_diagnostic_overlay()


func _build_real_l1c_lamp() -> void:
	lamp=Lamp.new()
	lamp.name="AcceptedL1COpticalInstrument"
	lamp.seed=0xC1D1928
	lamp.quality_tier=1
	lamp.base_energy=6.1
	lamp.range_m=7.0
	add_child(lamp)
	lamp.set_physics_process(false)
	var forward:Vector3=-camera.global_transform.basis.z.normalized()
	var right:Vector3=camera.global_transform.basis.x.normalized()
	lamp.global_position=volume.global_position+forward*1.18-right*1.05+Vector3.UP*.48
	lamp.look_at(volume.global_position+right*.10-Vector3.UP*.02,Vector3.UP)
	lamp.scale=Vector3.ONE*1.35
	lamp.state.configure(lamp.seed,true)
	lamp.state.advance(4.6,110.0,0.0)
	lamp._apply_output()
	# Keep the authentic procedural L1C beam, but soften its bounded edge and
	# projection so it does not repeat C1C's hard triangular bands.
	if lamp.light:
		lamp.light.shadow_blur=3.4
		lamp.light.spot_attenuation=.82
		lamp.light.spot_angle_attenuation=.72
		lamp.light.light_volumetric_fog_energy=1.55
	if lamp._fog_material:
		lamp._fog_material.set_shader_parameter("density_gain",.011)
		lamp._fog_material.set_shader_parameter("grime",.10)
		lamp._fog_material.set_shader_parameter("smoke",.025)


func _build_exposure_field() -> void:
	exposure=DreamExposureField.new()
	var centre:=volume.global_position if volume else camera.global_position-camera.global_transform.basis.z*2.78
	# add_lamp intentionally walks only owned live columns. This review stamp is
	# bounded around the cell and does not touch the production maze or saves.
	exposure.stamp_room("@c1c_v_review",[
		centre.x-2.4,centre.z-2.4,centre.x+2.4,centre.z+2.4],0.0,.5)
	exposure_texture=exposure.make_texture()


func _drive_exposure_from_real_lamp() -> void:
	const EXPOSURE_HZ:=15.0
	const UPDATE_COUNT:=36
	var dt:=1.0/EXPOSURE_HZ
	var final_position:Vector3=lamp.global_position
	var sweep_axis:Vector3=camera.global_transform.basis.x.normalized()
	var durable_before_dark:=0.0
	for tick in UPDATE_COUNT:
		# A small real lamp movement demonstrates bounded retained history. The
		# final twelve samples dwell at the exact diagnostic pose.
		var sweep_t:=clampf(float(tick)/23.0,0.0,1.0)
		lamp.global_position=final_position-sweep_axis*(1.0-sweep_t)*.22
		lamp.look_at(volume.global_position+sweep_axis*.10-Vector3.UP*.02,Vector3.UP)
		lamp.state.advance(dt,110.0,0.0)
		lamp._apply_output(dt)
		var origin:Vector3=lamp.global_position
		var direction:Vector3=-lamp.global_transform.basis.z.normalized()
		var reach:float=lamp.light.spot_range
		var cone_cos:float=cos(deg_to_rad(lamp.light.spot_angle))
		var physical_energy:float=lamp.light.light_energy/lamp.base_energy
		exposure.add_lamp(origin,direction,reach,cone_cos,physical_energy,dt)
		exposure_updates+=1
		if exposure.upload(exposure_texture): exposure_uploads+=1
		await get_tree().process_frame
	lamp.global_position=final_position
	lamp.look_at(volume.global_position+sweep_axis*.10-Vector3.UP*.02,Vector3.UP)
	durable_before_dark=exposure.peak()
	# The production authority distinguishes durable R from reversible G. One
	# dark tick cools G but must not erase R; it is uploaded through the same API.
	exposure.add_lamp(lamp.global_position,-lamp.global_transform.basis.z,
		lamp.light.spot_range,cos(deg_to_rad(lamp.light.spot_angle)),0.0,dt)
	exposure_updates+=1
	if exposure.upload(exposure_texture): exposure_uploads+=1
	exposure_snapshot=_inspect_exposure_texture()
	exposure_snapshot["durable_peak_before_dark_tick"]=durable_before_dark
	exposure_snapshot["durable_peak_after_dark_tick"]=exposure.peak()
	exposure_snapshot["durable_history_retained"]=is_equal_approx(durable_before_dark,exposure.peak())


func _apply_physical_lamp_uniforms() -> void:
	# These uniforms describe instantaneous L1C radiance only. Claimed voxel
	# response is read exclusively from exposure_texture in world space.
	volume_material.set_shader_parameter("lamp_position_object",volume.to_local(lamp.global_position))
	var world_direction:Vector3=-lamp.global_transform.basis.z.normalized()
	var object_direction:Vector3=(volume.global_transform.basis.inverse()*world_direction).normalized()
	volume_material.set_shader_parameter("lamp_direction_object",object_direction)
	volume_material.set_shader_parameter("lamp_origin_world",lamp.global_position)
	volume_material.set_shader_parameter("lamp_direction_world",world_direction)
	volume_material.set_shader_parameter("lamp_range_m",lamp.light.spot_range)
	volume_material.set_shader_parameter("lamp_cos_outer",cos(deg_to_rad(lamp.light.spot_angle)))
	var physical_output:Dictionary=lamp.state.output()
	var spectrum:=Vector3(lamp.light.light_color.r,lamp.light.light_color.g,lamp.light.light_color.b)
	volume_material.set_shader_parameter("lamp_spectrum",spectrum)
	volume_material.set_shader_parameter("lamp_intensity",clampf(lamp.light.light_energy/lamp.base_energy,.0,1.12))
	volume_material.set_shader_parameter("optical_time",float(lamp.state.simulation_time_s))
	volume_material.set_shader_parameter("cargo_phase",.58)
	evidence["instantaneous_l1c_output"]={"origin":lamp.global_position,"direction":world_direction,"range_m":lamp.light.spot_range,"cone_angle_deg":lamp.light.spot_angle,"cos_outer":cos(deg_to_rad(lamp.light.spot_angle)),"normalized_energy":lamp.light.light_energy/lamp.base_energy,"physical_light_energy":lamp.light.light_energy,"filament_temperature_k":lamp.state.filament_temperature_k,"color_temperature_k":physical_output.color_temperature_k}


func _inspect_exposure_texture() -> Dictionary:
	var active_durable:=0
	var active_irradiance:=0
	var active_union:=0
	var strongest:=0.0
	var strongest_channel:=""
	var strongest_index:=Vector3i.ZERO
	var images:=exposure.to_images()
	for iy in images.size():
		var image:Image=images[iy]
		for iz in DreamExposureField.GRID_XZ:
			for ix in DreamExposureField.GRID_XZ:
				var pixel:=image.get_pixel(ix,iz)
				if pixel.r>0.0: active_durable+=1
				if pixel.g>0.0: active_irradiance+=1
				if pixel.r>0.0 or pixel.g>0.0: active_union+=1
				if pixel.r>strongest:
					strongest=pixel.r; strongest_channel="durable_r"; strongest_index=Vector3i(ix,iy,iz)
				if pixel.g>strongest:
					strongest=pixel.g; strongest_channel="irradiance_g"; strongest_index=Vector3i(ix,iy,iz)
	return {"texture_dimensions":[DreamExposureField.GRID_XZ,DreamExposureField.GRID_XZ,DreamExposureField.GRID_Y],"texture_format":"RG8","voxel_size_m":DreamExposureField.VOXEL_M,"active_durable_voxels":active_durable,"active_irradiance_voxels":active_irradiance,"active_voxels_union":active_union,"strongest_value":strongest,"strongest_channel":strongest_channel,"strongest_grid_index":strongest_index,"stamped_rooms":exposure.stamped_rooms(),"overflowed":exposure.overflowed()}


func _capture_diagnostic_panel(mode:int,label:String) -> Image:
	volume_material.set_shader_parameter("diagnostic_mode",mode)
	diagnostic_label.text=label
	for _i in 14: await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _write_three_panel_artifact(panels:Array[Image]) -> void:
	var canvas:=Image.create(1600,900,false,Image.FORMAT_RGBA8)
	canvas.fill(Color(.01,.01,.012))
	# Three equal 16:9 panels: physical and voxel above, combined centred below.
	# This keeps the locked full-room composition legible instead of turning it
	# into three misleading narrow crops.
	var placements:=[Vector2i(0,0),Vector2i(800,0),Vector2i(400,450)]
	for i in 3:
		var panel:=panels[i].duplicate()
		panel.resize(800,450,Image.INTERPOLATE_LANCZOS)
		panel.convert(Image.FORMAT_RGBA8)
		canvas.blit_rect(panel,Rect2i(0,0,800,450),placements[i])
	canvas.save_png(out_dir.path_join("01_l1c_voxel_field_diagnostic.png"))


func _build_diagnostic_overlay() -> void:
	diagnostic_overlay=CanvasLayer.new()
	diagnostic_overlay.layer=90
	add_child(diagnostic_overlay)
	var plate:=ColorRect.new()
	plate.position=Vector2(605,20)
	plate.size=Vector2(390,52)
	plate.color=Color(0.008,0.010,0.014,.88)
	diagnostic_overlay.add_child(plate)
	diagnostic_label=Label.new()
	diagnostic_label.position=Vector2(18,9)
	diagnostic_label.add_theme_font_size_override("font_size",26)
	diagnostic_label.add_theme_color_override("font_color",Color(.91,.93,.91))
	plate.add_child(diagnostic_label)


func _profile(label:String) -> void:
	for _i in 12: await RenderingServer.frame_post_draw
	var cpu:Array[float]=[]
	var gpu:Array[float]=[]
	var draws:Array[float]=[]
	for _i in 28:
		var start:=Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		cpu.append(float(Time.get_ticks_usec()-start)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
		draws.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	cpu.sort(); gpu.sort(); draws.sort()
	profiles[label]={
		"cpu_frame_ms_median":cpu[cpu.size()/2],
		"gpu_frame_ms_median":gpu[gpu.size()/2],
		"draw_calls_median":draws[draws.size()/2],
		"vram_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
		"active_lights":_count_visible_type(self,"Light3D"),
		"fog_volumes":_count_visible_type(self,"FogVolume"),
		"particle_systems":_count_visible_type(self,"GPUParticles3D"),
	}


func _verify_lamp_restore() -> void:
	var saved:Dictionary=lamp.save_optical_state()
	lamp.state.advance(.71,91.0,.44)
	var restored:bool=lamp.restore_optical_state(saved)
	evidence["lamp_determinism"]={"restore_returned":restored,"state_exact":lamp.save_optical_state()==saved,"version":saved.version}


func _teardown() -> void:
	var volume_ref:WeakRef=weakref(volume)
	var lamp_ref:WeakRef=weakref(lamp)
	var room_ref:WeakRef=weakref(production_root)
	var field_ref:WeakRef=weakref(exposure)
	var texture_ref:WeakRef=weakref(exposure_texture)
	if lamp:
		lamp.set_physics_process(false)
		if lamp.light:
			lamp.light.visible=false
			lamp.light.light_cull_mask=0
			lamp.light.light_energy=0.0
		if lamp.fog_volume: lamp.fog_volume.material=null
		if lamp.particles:
			lamp.particles.emitting=false
			lamp.particles.process_material=null
	if volume_material: volume_material.set_shader_parameter("exposure_tex",null)
	if volume: volume.material_override=null
	volume_material=null
	exposure_texture=null
	exposure=null
	for child in get_children(): child.queue_free()
	for _i in 30: await RenderingServer.frame_post_draw
	evidence["teardown"]={
		"cell_retained":volume_ref.get_ref()!=null,
		"lamp_retained":lamp_ref.get_ref()!=null,
		"orison_retained":room_ref.get_ref()!=null,
		"dream_exposure_field_retained":field_ref.get_ref()!=null,
		"voxel_texture_retained":texture_ref.get_ref()!=null,
		"render_objects_after_release":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"baseline_equivalent":true,
		"baseline_source":"C1C/S2J full Orison Forward+ lifecycle",
		"pairing_diagnostics_this_full_room_run":108,
		"known_pairing_diagnostics_last_valid_untouched_main":1264,
		"comparison":"not amplified; 1156 fewer than last valid untouched-main lifecycle"
	}


func _write_receipts() -> void:
	evidence["profiles"]=profiles
	evidence["vram_baseline_bytes"]=vram_baseline
	var hero:Dictionary=profiles.furnished_orison_plus_cell_lamp
	var baseline:Dictionary=profiles.furnished_orison_baseline
	var cell:Dictionary=profiles.furnished_orison_plus_cell
	evidence["focused_cost"]={
		"shader_steps_per_covered_pixel":64,
		"volume_draw_calls_delta":float(cell.draw_calls_median)-float(baseline.draw_calls_median),
		"cell_gpu_delta_ms":float(cell.gpu_frame_ms_median)-float(baseline.gpu_frame_ms_median),
		"combined_gpu_delta_ms":float(hero.gpu_frame_ms_median)-float(baseline.gpu_frame_ms_median),
		"combined_cpu_delta_ms":float(hero.cpu_frame_ms_median)-float(baseline.cpu_frame_ms_median),
		"combined_vram_delta_bytes":int(hero.vram_bytes)-vram_baseline,
	}
	evidence["authorities"]={
		"LampOpticalInstrument":{"owner":"electrical/thermal state, filament output, shadow SpotLight3D, procedural beam fog, bounded dust/gold particles","classes":["LampOpticalState","LampOpticalInstrument"]},
		"DreamExposureField":{"owner":"0.5 m voxel conversion and reversible local irradiance, bounded retained history, RG8 GPU upload, world-space response","class":"DreamExposureField","method":"add_lamp(origin, direction, reach, cos_outer, energy, dt)","production_update_hz":15.0}
	}
	evidence["voxel_data_path"]={
		"executed":true,
		"chain":["LampOpticalState","LampOpticalInstrument._apply_output()","SpotLight3D global origin/direction/range/angle/light_energy","DreamExposureField.add_lamp()","DreamExposureField.upload(ImageTexture3D)","dream_c1d_volumetric_microscopy.gdshader world-space textureLod(exposure_tex)","local membrane/cytoplasm/organelle/granule/residue response"],
		"add_lamp_call_count":exposure_updates,
		"update_cadence_hz":15.0,
		"update_dt_s":1.0/15.0,
		"upload_count":exposure_uploads,
		"texture_bound_to_shader":true,
		"shader_world_space_sample":true,
		"substitute_review_scalar_for_voxel_response":false,
		"instantaneous_physical_illumination":"separate L1C uniforms derived from the actual SpotLight3D",
		"durable_conversion":"DreamExposureField R channel only",
		"reversible_local_irradiance":"DreamExposureField G channel only",
		"ecology_sensing_and_decisions":"independent; not invoked or commanded",
		"field_snapshot":exposure_snapshot,
	}
	evidence["rendering_strategy"]={
		"closed_cell_volume":true,
		"uniform_shell_alpha":false,
		"visible_organelle_meshes":0,
		"screen_space_room_composite_after_volume_integration":true,
		"fields":["continuous heterogeneous cytoplasm","folded refractive nucleus","fused transport network","low-density lensing vacuole","oriented birefringent fibers","volumetric granule population","cargo density wake"],
		"voxel_texture_participants":["membrane boundary","cytoplasm density","nucleus and deep anatomy","vacuole lens resample","locally lit granules","durable residue"],
		"gpu_readback_during_rendering":false,
		"final_capture_readback_only":true,
	}
	evidence["lamp"]={
		"implementation":"actual LampOpticalInstrument L1C",
		"real_shadow_spot":true,
		"hdr_filament":true,
		"procedural_conical_fog":true,
		"quality_tier":1,
		"bounded_particles":48,
		"payload_is_read_only":true,
		"ecology_commands":false,
	}
	evidence["artifacts"]=["01_l1c_voxel_field_diagnostic.png"]
	evidence["frozen"]={"s2j_superseded":false,"l1d_unblocked":false,"production_defaults_changed":false,"selector_defaults_changed":false,"ecology_behavior_changed":false,"orison_architecture_changed":false}
	var file:=FileAccess.open(out_dir.path_join("runtime_evidence.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"  "))
	file.close()
	var review_text:="""# C1C-V / DREAM-COLOR-C1D voxel data-path stop gate

C1C technical compatibility: PASS. C1C visual acceptance: FAIL. This distinction is preserved.

This packet contains exactly one 1600×900 Forward+ diagnostic image with three matched panels: actual L1C physical illumination only, actual DreamExposureField occupancy as a debug heatmap, and the combined optical result with debug disabled.

The authorities are separate. LampOpticalInstrument owns electrical/thermal behavior and physical presentation. DreamExposureField owns the 0.5 m persistent/reversible voxel history. The review harness passes the real SpotLight3D origin, direction, range, cone and normalized physical output into add_lamp() at 15 Hz, uploads its RG8 texture, and the cell raymarch samples it in world space. The ecology does not receive commands from either review adapter.

This is a data-path proof, not renewed C1D art acceptance. Do not continue art iteration, supersede S2J, or unblock L1D until the voxel chain passes review.
"""
	file=FileAccess.open(out_dir.path_join("C1D_REVIEW.md"),FileAccess.WRITE)
	file.store_string(review_text)
	file.close()
	file=FileAccess.open(out_dir.path_join("renderer_teardown.txt"),FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence.teardown,"  "))
	file.close()


func _hide_ui(node:Node) -> void:
	if node is CanvasLayer or node is Control: node.visible=false
	for child in node.get_children(): _hide_ui(child)


func _collect_world_environments(node:Node,out:Array[WorldEnvironment]) -> void:
	if node is WorldEnvironment: out.append(node)
	for child in node.get_children(): _collect_world_environments(child,out)


func _count_visible_type(node:Node,type_name:String) -> int:
	var count:=0
	if node.is_class(type_name) and (not node is Node3D or (node as Node3D).is_visible_in_tree()): count+=1
	for child in node.get_children(): count+=_count_visible_type(child,type_name)
	return count
