extends "res://tests/v2_hose_installed_world.gd"
## INERT fixed-view perturbations after a real standing approach.
## Visibility/shadow controls are diagnostic only, never a production policy.
var render_records: Array=[]
var draw_state: Array=[]
var light_state: Array=[]
var render_observations: Array=[]

func _play_route() -> void:
	for point in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.65,3.2,-3.),Vector3(4.5,3.2,-2.95)]:
		if not await _walk(point):return
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	var actor: Node3D=native.stations.F02_FIRE_LINE_STAIR.get_ref()
	actor.door_open=true;actor._refresh_cabinet()
	player.face_world_point(actor.to_global(Vector3(0,.35,.15)))
	for frame in 20:await RenderingServer.frame_post_draw
	var cloth: Array[MeshInstance3D]=[]
	for branch: Node3D in actor._live_hose._stored:
		if branch is MeshInstance3D and not cloth.has(branch):cloth.append(branch)
		for draw: MeshInstance3D in branch.find_children("*","MeshInstance3D",true,false):
			if not cloth.has(draw):cloth.append(draw)
	var all: Array[MeshInstance3D]=[]
	for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		all.append(draw);draw_state.append({"draw":draw,"shadow":draw.cast_shadow,"visible":draw.visible})
	var pose: Transform3D=player.camera.global_transform
	var before: Dictionary=actor.mechanism_snapshot()
	var mode: String=OS.get_environment("V2_HOSE_RENDER_LIGHTS")
	var light_mode: bool=not mode.is_empty()
	var visibility_control: bool=mode=="visiblefade"
	var policy_processing: bool=world.service_light_visibility.is_processing()
	if visibility_control:world.service_light_visibility.set_process(false)
	var service: Array=[]
	for row: Dictionary in world.service_light_visibility.sources:service.append(row.light)
	for light: Light3D in world.find_children("*","Light3D",true,false):
		light_state.append({"light":light,"visible":light.visible,"shadow":light.shadow_enabled,"service":service.has(light),"fade":light.distance_fade_enabled,"begin":light.distance_fade_begin,"length":light.distance_fade_length,"shadow_distance":light.distance_fade_shadow})
	var count:=0
	for draw: MeshInstance3D in cloth:
		if draw.mesh!=null:count+=draw.mesh.get_faces().size()/3
	_check(not cloth.is_empty() and not all.is_empty(),"diagnostic finds retained native cloth and cabinet draws")
	var variants: Array=["original_a","cloth_shadows_off","original_b","cloth_hidden","original_c","cabinet_shadows_off","original_d","cabinet_hidden","original_e"]
	if light_mode:variants=["original_a","service_shadows_off","original_b","other_point_shadows_off","original_c","all_point_shadows_off","original_d","directional_shadows_off","original_e"]
	if mode=="fade":variants=["original_a","service_fade_8","original_b","service_fade_12","original_c","service_fade_16","original_d"]
	if mode=="wholefade":variants=["original_a","service_fade_8","original_b","service_fade_12","original_c","service_fade_16","original_d"]
	if visibility_control:variants=["original_a","service_visible_4","original_b","service_visible_6","original_c","service_visible_8","original_d"]
	if mode=="installed":variants=["original_a","installed_a","original_b","installed_b","original_c"]
	for variant: String in variants:
		for row: Dictionary in draw_state:row.draw.visible=row.visible;row.draw.cast_shadow=row.shadow
		for row: Dictionary in light_state:
			row.light.visible=row.visible
			row.light.shadow_enabled=row.shadow
			row.light.distance_fade_enabled=row.fade;row.light.distance_fade_begin=row.begin;row.light.distance_fade_length=row.length;row.light.distance_fade_shadow=row.shadow_distance
			if row.service and variant.begins_with("service_fade_"):
				row.light.distance_fade_enabled=true;row.light.distance_fade_begin=128.;row.light.distance_fade_length=4.;row.light.distance_fade_shadow=float(variant.get_slice("_",2))
				if mode=="wholefade":row.light.distance_fade_begin=row.light.distance_fade_shadow
			if row.service and variant.begins_with("service_visible_"):
				var start: float=float(variant.get_slice("_",2))
				row.light.distance_fade_enabled=true;row.light.distance_fade_begin=start;row.light.distance_fade_length=4.;row.light.distance_fade_shadow=start
				row.light.visible=row.visible and row.light.global_position.distance_to(player.camera.global_position)<start+4.
			if variant=="service_shadows_off" and row.service:row.light.shadow_enabled=false
			if variant=="other_point_shadows_off" and not row.service and not row.light is DirectionalLight3D:row.light.shadow_enabled=false
			if variant=="all_point_shadows_off" and not row.light is DirectionalLight3D:row.light.shadow_enabled=false
			if variant=="directional_shadows_off" and row.light is DirectionalLight3D:row.light.shadow_enabled=false
		if variant=="cloth_shadows_off":
			for draw: MeshInstance3D in cloth:draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if variant=="cloth_hidden":
			for draw: MeshInstance3D in cloth:draw.visible=false
		if variant=="cabinet_shadows_off":
			for draw: MeshInstance3D in all:draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if variant=="cabinet_hidden":
			for draw: MeshInstance3D in all:draw.visible=false
		if mode=="installed":world.service_light_visibility.set_distance_enabled(variant.begins_with("installed_"))
		profile_phase="warm_"+variant
		for frame in 20:await RenderingServer.frame_post_draw
		var observed: Array=[]
		for row: Dictionary in light_state:
			if row.service:observed.append({"path":str(row.light.get_path()),"visible":row.light.visible,"shadow":row.light.shadow_enabled,"fade":row.light.distance_fade_enabled,"begin":row.light.distance_fade_begin,"length":row.light.distance_fade_length,"shadow_distance":row.light.distance_fade_shadow,"camera_distance_m":row.light.global_position.distance_to(player.camera.global_position)})
		render_observations.append({"phase":variant,"service_lights":observed,"reflection_refresh_count":world.get_node("V2RoomReflections").refresh_count})
		profile_phase=variant
		var previous: int=Time.get_ticks_usec()
		for frame in 120:
			await RenderingServer.frame_post_draw
			var now: int=Time.get_ticks_usec();var viewport: RID=get_viewport().get_viewport_rid()
			render_records.append({"phase":variant,"wall_ms":(now-previous)/1000.,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"distance_policy_usec":world.service_light_visibility.distance_budget.last_tick_usec,"monitors":_monitor_values()});previous=now
		_check(player.camera.global_transform.is_equal_approx(pose),"fixed real camera retained: "+variant)
		await _picture(variant)
	for row: Dictionary in draw_state:row.draw.visible=row.visible;row.draw.cast_shadow=row.shadow
	var lights: Array=[]
	for row: Dictionary in light_state:
		row.light.visible=row.visible
		row.light.shadow_enabled=row.shadow
		row.light.distance_fade_enabled=row.fade;row.light.distance_fade_begin=row.begin;row.light.distance_fade_length=row.length;row.light.distance_fade_shadow=row.shadow_distance
		lights.append({"path":str(row.light.get_path()),"shadow":row.shadow,"service":row.service,"class":row.light.get_class(),"visible":row.light.is_visible_in_tree()})
	if visibility_control:world.service_light_visibility.set_process(policy_processing)
	if mode=="installed":world.service_light_visibility.set_distance_enabled(true)
	var comparison: Dictionary=preload("res://tests/hose_saved_pose_comparison.gd").compare(actor.mechanism_snapshot(),before)
	_check(comparison.equal,"rendering controls preserve all mechanism state")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("render_attribution.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"One actual walked approach; fixed-view diagnostic perturbations. No production visual policy or human acceptance.","mode":mode,"light_mode":light_mode,"light_observations":render_observations,"lights":lights,"service_context":{"room":world.service_light_visibility.context_room,"conservative":world.service_light_visibility.conservative},"cloth_draws":cloth.size(),"cabinet_draws":all.size(),"cloth_triangles":count,"camera":str(pose),"resolution":str(get_viewport().get_visible_rect().size),"vsync":false,"records":render_records,"checks":hose_checks,"comparison":comparison,"failures":failures},"\t"))
