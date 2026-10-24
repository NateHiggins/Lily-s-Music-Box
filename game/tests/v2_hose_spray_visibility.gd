extends "res://tests/v2_hose_installed_world.gd"
## INERT installed spray visibility controls. Debug materials are never shipped.
var _spray_controls: Array=[]

func _picture(name: String) -> void:
	await super._picture(name)
	if name=="installed_held_nozzle" and OS.get_environment("V2_EXPECT_PREPARED_SPRAY")=="1":_verify_idle_spray()
	if name!="installed_spray":return
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	var actor: Node3D=native.stations.F02_FIRE_LINE_STAIR.get_ref()
	var spray: GPUParticles3D=actor._live_hose._spray
	if OS.get_environment("V2_SPRAY_FINAL_VERIFY")=="1":
		await _final_views(actor,spray)
		return
	var original_mesh: Mesh=spray.draw_pass_1
	var original_override: Material=spray.material_override
	var finish: StandardMaterial3D=original_mesh.surface_get_material(0)
	var styles: Dictionary={"original_a":original_override}
	for level: float in [.15,.35,.65]:
		var lit:=finish.duplicate() as StandardMaterial3D
		lit.backlight_enabled=false;lit.emission_enabled=true;lit.emission=Color(.85,.92,1.);lit.emission_energy_multiplier=level
		styles["fill_"+str(level)]=lit
	styles.original_b=original_override
	var description: Dictionary={"evidence_class":"INERT","scope":"Actual charged nozzle after mouse lever input. Debug visibility controls only; original resources restored. No production material exemption or runtime qualification.","emitting":spray.emitting,"amount":spray.amount,"amount_ratio":spray.amount_ratio,"local_coords":spray.local_coords,"global_transform":var_to_str(spray.global_transform),"capture_aabb":var_to_str(spray.capture_aabb()),"camera":var_to_str(player.camera.global_transform),"original_override_class":original_override.get_class() if original_override!=null else "none","original_material_class":original_mesh.surface_get_material(0).get_class(),"triangles_per_drop":original_mesh.get_faces().size()/3,"cast_shadow":spray.cast_shadow,"controls":_spray_controls}
	for treatment: String in styles:
		spray.draw_pass_1=original_mesh
		spray.material_override=styles[treatment]
		profile_phase="spray_visibility_"+treatment
		for frame in 30:await RenderingServer.frame_post_draw
		var samples: Array=[]
		var previous:=Time.get_ticks_usec()
		for frame in 120:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			samples.append({"wall_ms":(now-previous)/1000.,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())});previous=now
		_spray_controls.append({"name":treatment,"samples":samples,"bounds":var_to_str(spray.capture_aabb())})
		await super._picture("spray_"+treatment)
	spray.draw_pass_1=original_mesh;spray.material_override=original_override
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("spray_visibility.json"),FileAccess.WRITE).store_string(JSON.stringify(description,"\t"))

func _save_reload(wanted: Dictionary) -> void:
	if OS.get_environment("V2_SPRAY_SKIP_REBUILD")=="1":
		FileAccess.open(OS.get_environment("SHOT_DIR").path_join("rebuild_skipped.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Spray-only diagnostic explicitly skips the inherited disk/rebuild phase. No persistence proof from this run."},"\t"))
		return
	await super._save_reload(wanted)

func _look_at_angles(yaw: float,pitch: float) -> void:
	if player.inspecting():helper.key(KEY_ESCAPE)
	var sensitivity: float=clampf(float(GameBoot.settings.get("look_sensitivity",1.)),.25,2.)
	var motion:=InputEventMouseMotion.new()
	motion.relative=Vector2(wrapf(player.rotation.y-yaw,-PI,PI),player.camera.rotation.x-pitch)/(PlayerController.MOUSE_SENS*sensitivity)
	player._unhandled_input(motion)
	for frame in 3:await get_tree().process_frame

func _final_views(actor: Node3D,spray: GPUParticles3D) -> void:
	profile_phase="capture_excluded_spray_maps"
	var finish: StandardMaterial3D=spray.draw_pass_1.surface_get_material(0)
	_check(finish.normal_enabled and not finish.uv1_triplanar,"visible spray retains registered UV-based water finish")
	for texture: Texture2D in [finish.albedo_texture,finish.roughness_texture,finish.normal_texture]:
		_check(texture!=null and texture.get_image().has_mipmaps(),"visible spray retains a complete loaded physical-map mip chain")
	helper.key(KEY_ESCAPE)
	var original_yaw: float=player.rotation.y
	var original_pitch: float=player.camera.rotation.x
	var views: Array=[]
	for view: Dictionary in [{"id":"floor","yaw":original_yaw,"pitch":original_pitch},{"id":"level","yaw":original_yaw,"pitch":0.},{"id":"turned","yaw":original_yaw+PI*.5,"pitch":0.},{"id":"away","yaw":original_yaw-PI*.5,"pitch":0.},{"id":"back","yaw":original_yaw+PI,"pitch":0.}]:
		await _look_at_angles(float(view.yaw),float(view.pitch))
		var direction: Vector3=actor._nozzle_joint.body.global_basis.y.normalized()
		var error: float=rad_to_deg(acos(clampf(direction.dot(-player.camera.global_basis.z),-1.,1.)))
		_check(player._grab.holding_pickup() and error<1.,"actual spraying FPS turn retains nozzle aim within one degree: "+str(view.id))
		helper.key(KEY_SPACE)
		_check(player.inspecting() and player.inspect_owner==actor and actor._live_hose.water.spray>.7,"spraying nozzle keeps supported free-cursor inspection: "+str(view.id))
		profile_phase="spray_final_"+str(view.id)
		for frame in 30:await RenderingServer.frame_post_draw
		var samples: Array=[]
		var previous:=Time.get_ticks_usec()
		for frame in 120:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			samples.append({"wall_ms":(now-previous)/1000.,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())});previous=now
		await super._picture("spray_final_"+str(view.id))
		views.append({"id":view.id,"samples":samples,"aim_error_degrees":error,"camera":var_to_str(player.camera.global_transform)})
	await _look_at_angles(original_yaw,original_pitch)
	helper.key(KEY_SPACE)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("spray_final.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual spraying aim/inspection views and fixed-view performance. Visual readability requires image review; emission flags alone are not visual acceptance.","amount":spray.amount,"triangles_per_drop":spray.draw_pass_1.get_faces().size()/3,"cast_shadow":spray.cast_shadow,"views":views},"\t"))

func _verify_idle_spray() -> void:
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	var rows: Array=[]
	for reference: WeakRef in native.stations.values():
		var actor: Node3D=reference.get_ref()
		var hose: Node3D=actor._live_hose
		var spray: GPUParticles3D=hose._spray
		var inactive: bool=spray!=null and RenderingServer.particles_is_inactive(spray.get_base())
		_check(spray!=null and not spray.emitting and not spray.visible and inactive and not hose.is_processing() and not hose.is_physics_processing(),"prepared stored spray is hidden, GPU-inactive and has no cloth/fluid tick: "+str(actor.name))
		rows.append({"cabinet":str(actor.name),"prepared":spray!=null,"emitting":spray.emitting if spray!=null else false,"visible":spray.visible if spray!=null else false,"gpu_inactive":inactive})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("prepared_spray.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Renderer-observed prepared spray state before first flow; actual source and control ownership remain unchanged.","stations":rows},"\t"))
