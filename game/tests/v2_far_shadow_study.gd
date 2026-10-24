extends "res://tests/v2_hose_installed_world.gd"
## INERT fixed-view controls after actual movement and cabinet manipulation.
var shadow_rows: Array=[]
var shadow_samples: Array=[]
var observations: Array=[]

func _play_route() -> void:
	for point in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.65,3.2,-3.),Vector3(4.5,3.2,-2.95)]:
		if not await _walk(point):return
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	var actor: Node3D=native.stations.F02_FIRE_LINE_STAIR.get_ref()
	driver=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand.new();driver.player=player;add_child(driver)
	if not _check(await driver.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),"actual input opens cabinet before fixed-view study"):return
	player.face_world_point(actor.to_global(Vector3(0,.35,.15)))
	for frame in 30:await RenderingServer.frame_post_draw
	var pose: Transform3D=player.camera.global_transform
	var before: Dictionary=actor.mechanism_snapshot()
	var rig_processing: bool=world.light_rig.is_processing()
	var service_processing: bool=world.service_light_visibility.is_processing()
	world.light_rig.set_process(false);world.service_light_visibility.set_process(false)
	var eyes: Array[Vector3]=[player.camera.global_position]
	var reflected: Camera3D=world.mirror_renderer.active_camera()
	if reflected!=null:eyes.append(reflected.global_position)
	var services: Array=[]
	for row: Dictionary in world.service_light_visibility.sources:services.append(row.light)
	for light: Light3D in world.find_children("*","Light3D",true,false):
		var gap:=INF
		for eye: Vector3 in eyes:gap=minf(gap,maxf(0.,light.global_position.distance_to(eye)-light.get_param(Light3D.PARAM_RANGE)))
		shadow_rows.append({"light":light,"path":str(light.get_path()),"shadow":light.shadow_enabled,"visible":light.visible,"service":services.has(light),"directional":light is DirectionalLight3D,"gap":gap})
	for phase: String in ["original_a","far_gap4","original_b","far_gap8","original_c","service_off","original_d","other_point_off","original_e","directional_off","original_f"]:
		var disabled: Array=[]
		for row: Dictionary in shadow_rows:
			var off: bool=(phase=="far_gap4" and row.gap>4. and not row.directional) or (phase=="far_gap8" and row.gap>8. and not row.directional) or (phase=="service_off" and row.service) or (phase=="other_point_off" and not row.service and not row.directional) or (phase=="directional_off" and row.directional)
			row.light.shadow_enabled=row.shadow and not off
			if off and row.shadow and row.visible:disabled.append(row.path)
		profile_phase="warm_"+phase
		for frame in 30:await RenderingServer.frame_post_draw
		profile_phase=phase
		var previous:=Time.get_ticks_usec()
		for frame in 120:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec();var rid:=get_viewport().get_viewport_rid()
			shadow_samples.append({"phase":phase,"wall_ms":(now-previous)/1000.,"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid),"visible_draws":RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"shadow_draws":RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"monitors":_monitor_values()});previous=now
		var visible_unchanged:=true
		for row: Dictionary in shadow_rows:visible_unchanged=visible_unchanged and row.light.visible==row.visible
		_check(visible_unchanged and player.camera.global_transform.is_equal_approx(pose),"fixed camera and color visibility preserved: "+phase)
		observations.append({"phase":phase,"disabled_visible_shadows":disabled})
		await _picture(phase)
	for row: Dictionary in shadow_rows:row.light.shadow_enabled=row.shadow
	world.light_rig.set_process(rig_processing);world.service_light_visibility.set_process(service_processing)
	var comparison: Dictionary=preload("res://tests/hose_saved_pose_comparison.gd").compare(actor.mechanism_snapshot(),before)
	_check(comparison.equal,"shadow controls preserve cabinet mechanism state")
	var inventory: Array=[]
	for row: Dictionary in shadow_rows:inventory.append({"path":row.path,"shadow":row.shadow,"visible":row.visible,"service":row.service,"directional":row.directional,"gap":row.gap})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("shadow_study.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"One actual walked approach and cabinet operation. Fixed camera; both rendering policy callbacks paused in every phase, fixture power/flicker unchanged. No persistence timing, production policy or human acceptance. Gap is camera-to-light-center minus authored range, nearest live main/mirror eye.","samples":shadow_samples,"observations":observations,"lights":inventory,"comparison":comparison,"checks":hose_checks,"failures":failures},"\t"))
