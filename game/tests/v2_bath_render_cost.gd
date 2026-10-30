extends "res://tests/v2_bath_contact_lod_study.gd"
## INERT cost separation at an unchanged playable-world camera, then actual input.
var mirror: PlanarMirrorRenderer
var environment: Environment
var fixtures: Array=[]
var lights: Array=[]
var original: Dictionary={}
var foreground: Node
var animations: Array=[]

func phase_labels() -> Array[String]:
	var requested:=OS.get_environment("V2_BATH_PROFILE_PHASES")
	if not requested.is_empty():
		var labels:Array[String]=[];labels.assign(requested.split(",",false));return labels
	return ["normal_static","mirror_frozen","light_scripts_frozen","shadows_off","screen_space_off","fog_off","msaa4","normal_static_restored","normal_move"]

func _process(delta: float) -> void:
	super._process(delta)
	var main:=get_viewport().get_viewport_rid()
	var reflected:=mirror._view.get_viewport_rid()
	samples[-1].mirror_cpu_ms=RenderingServer.viewport_get_measured_render_time_cpu(reflected)
	samples[-1].mirror_gpu_ms=RenderingServer.viewport_get_measured_render_time_gpu(reflected)
	samples[-1].mirror_update_mode=mirror._view.render_target_update_mode
	samples[-1].foreground_cpu_ms=RenderingServer.viewport_get_measured_render_time_cpu(foreground.view.get_viewport_rid())
	samples[-1].foreground_gpu_ms=RenderingServer.viewport_get_measured_render_time_gpu(foreground.view.get_viewport_rid())
	samples[-1].foreground_update_mode=foreground.view.render_target_update_mode
	samples[-1].frame=Engine.get_process_frames()
	samples[-1].load_cycles=world.passage_region.residency.load_cycles
	samples[-1].housing_shadow=world.service_set_carrier._housing_shadow.cast_shadow
	for item: Array in [["main",main],["mirror",reflected]]:
		for info: Array in [["draws",RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME],["triangles",RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME]]:
			samples[-1][item[0]+"_"+info[0]]=RenderingServer.viewport_get_render_info(item[1],RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,info[1])
		samples[-1][item[0]+"_shadow_draws"]=RenderingServer.viewport_get_render_info(item[1],RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)

func restore() -> void:
	world.process_mode=original.world_mode
	world.service_set_carrier._housing_shadow.cast_shadow=original.housing_shadow
	world.service_set_carrier.set_capture_hidden(original.capture_hidden)
	world.light_rig._shadow_budget=original.shadow_budget
	for row:Dictionary in animations:row.node.active=row.active
	world.player_avatar.head_aim.active=original.head_aim
	foreground.composite_enabled=original.foreground
	world.service_light_visibility.set_process(original.visibility_process)
	world.light_rig.set_process(original.rig_process)
	for row: Dictionary in fixtures:
		if is_instance_valid(row.node):row.node.set_process(row.processing)
	for row: Dictionary in lights:
		if is_instance_valid(row.node) and row.node.shadow_enabled!=row.shadow:row.node.shadow_enabled=row.shadow
		if is_instance_valid(row.node) and row.node.visible!=row.visible:row.node.visible=row.visible
		if row.node is OmniLight3D and row.node.omni_shadow_mode!=row.omni_mode:row.node.omni_shadow_mode=row.omni_mode
	environment.ssao_enabled=original.ssao;environment.ssil_enabled=original.ssil
	environment.volumetric_fog_enabled=original.volumetric;environment.fog_enabled=original.fog
	get_viewport().msaa_3d=original.msaa
	mirror.set_process(true)

func treatment(label: String) -> void:
	if label in ["shadows_off","point_shadows_off","directional_shadows_off"]:
		world.light_rig.set_process(false)
		world.service_light_visibility.set_process(false)
		for row: Dictionary in fixtures:row.node.set_process(false)
		for row: Dictionary in lights:
			if label=="shadows_off" or (row.node is DirectionalLight3D)==(label=="directional_shadows_off"):row.node.shadow_enabled=false
	elif label=="mirror_frozen":
		# Preserve the exact static reflected image, but stop rendering it.
		mirror.set_process(false);mirror._view.render_target_update_mode=SubViewport.UPDATE_DISABLED
		world.player_avatar.set_reflection_active(false)
	elif label=="light_scripts_frozen":
		world.light_rig.set_process(false)
		for row: Dictionary in fixtures:row.node.set_process(false)
	elif label=="foreground_frozen":foreground.composite_enabled=false
	elif label=="mirror_pose_frozen":mirror.set_process(false)
	elif label=="world_frozen":world.process_mode=Node.PROCESS_MODE_DISABLED
	elif label=="carrier_hidden":world.service_set_carrier.set_capture_hidden(true)
	elif label.begins_with("shadow_budget_8"):world.light_rig.set_budgets(original.active_budget,8)
	elif label.begins_with("shadow_budget_32"):world.light_rig.set_budgets(original.active_budget,32)
	elif label=="avatar_frozen":
		world.player_avatar.animator.active=false;world.player_avatar.head_aim.active=false
	elif label=="animations_frozen":
		for row:Dictionary in animations:row.node.active=false
		world.player_avatar.head_aim.active=false
	elif label=="screen_space_off":
		environment.ssao_enabled=false;environment.ssil_enabled=false
	elif label=="fog_off":
		environment.volumetric_fog_enabled=false;environment.fog_enabled=false
	elif label=="msaa4":get_viewport().msaa_3d=Viewport.MSAA_4X
	elif label.begins_with("away_"):
		# Exercise the real sleeping-mirror selection, not a frozen viewport.
		player.rotate_y(PI)
		world.service_set_carrier._housing_shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if "_off" in label else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests();GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	CampaignClock.new().configure_date(1928,11,10,18*60)
	directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	world=load("res://scenes/building/orison_v2_runtime.tscn").instantiate();add_child(world)
	if world.startup_failed:get_tree().quit(1);return
	player=world.player;player.set_physics_process(false);player.profile_physics=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	world.service_set_carrier.set_capture_hidden(OS.get_environment("V2_BATH_PROFILE_CARRIER")!="1");player.set_lamp_enabled(false)
	foreground=world.service_set_carrier.screen_frame
	for driver:CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	world.get_node("V2RoomReflections").set_physics_process(false)
	mirror=world.mirror_renderer;environment=world.get_node("WakingAtmosphere").environment
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	RenderingServer.viewport_set_measure_render_time(mirror._view.get_viewport_rid(),true)
	RenderingServer.viewport_set_measure_render_time(foreground.view.get_viewport_rid(),true)
	var wanted:=OS.get_environment("V2_BATH_MIRROR_ID")
	if wanted.is_empty():wanted="F03_3B_MIRROR_01"
	var subject: Node3D
	for surface in get_tree().get_nodes_in_group("planar_mirror_surface"):
		var owner: Node=surface.get_parent()
		while owner!=null and not owner.has_method("mirror_center"):owner=owner.get_parent()
		if owner!=null and str(owner.name)==wanted:subject=owner;break
	if subject==null:get_tree().quit(1);return
	var tokens:=wanted.split("_")
	var room:=str(tokens[0])+"_"+str(tokens[1]).right(1)+"_BATH"
	var switches: SwitchSystem=world.get_node("V2RoomSwitches");var saved:=switches.room_snapshot(room);var lit: Dictionary={}
	for id: String in saved:lit[id]=true
	switches.restore_room(room,lit)
	var stance:Vector3=subject.mirror_center()+subject.mirror_normal()*1.1
	stance.y=subject.global_position.y+.025
	var capsule:=CapsuleShape3D.new();capsule.radius=PlayerController.BODY_RADIUS;capsule.height=PlayerController.STANDING_HEIGHT
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=player.collision_mask;query.exclude=[player.get_rid()]
	query.transform=Transform3D(Basis.IDENTITY,stance+Vector3.UP*PlayerController.STANDING_HEIGHT*.5)
	if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		push_error("Full standing capsule blocked at selected mirror");get_tree().quit(1);return
	player.global_position=stance;player.velocity=Vector3.ZERO;player.face_world_point(subject.mirror_center())
	for frame in 20:await RenderingServer.frame_post_draw
	original={"msaa":get_viewport().msaa_3d,"ssao":environment.ssao_enabled,"ssil":environment.ssil_enabled,"volumetric":environment.volumetric_fog_enabled,"fog":environment.fog_enabled,"rig_process":world.light_rig.is_processing(),"active_budget":world.light_rig._active_budget,"shadow_budget":world.light_rig._shadow_budget,"mirror_atlas":mirror._view.positional_shadow_atlas_size}
	original.foreground=foreground.composite_enabled;original.visibility_process=world.service_light_visibility.is_processing()
	original.world_mode=world.process_mode;original.capture_hidden=world.service_set_carrier.is_capture_hidden()
	original.head_aim=world.player_avatar.head_aim.active
	original.housing_shadow=world.service_set_carrier._housing_shadow.cast_shadow
	for node:AnimationMixer in world.find_children("*","AnimationMixer",true,false):animations.append({"node":node,"active":node.active})
	for node: Node in world.light_rig._controlled_lights():fixtures.append({"node":node,"processing":node.is_processing()})
	var inventory: Array=[]
	for node: Light3D in world.find_children("*","Light3D",true,false):
		var controlled:=false
		for fixture: Dictionary in fixtures:
			if fixture.node==node or fixture.node.is_ancestor_of(node):controlled=true;break
		lights.append({"node":node,"shadow":node.shadow_enabled,"visible":node.visible,"controlled":controlled,"omni_mode":node.omni_shadow_mode if node is OmniLight3D else -1})
		inventory.append({"path":str(node.get_path()),"kind":node.get_class(),"position":str(node.global_position),"energy":node.light_energy,"visible":node.is_visible_in_tree(),"shadow":node.shadow_enabled,"controlled":controlled,"range":node.get_param(Light3D.PARAM_RANGE) if not node is DirectionalLight3D else 0.,"omni_mode":node.omni_shadow_mode if node is OmniLight3D else -1})
	FileAccess.open(directory.path_join("light_inventory.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","lights":inventory},"\t"))
	var records: Array=[]
	for label: String in phase_labels():
		restore();player.set_physics_process(false);player.global_position=stance;player.velocity=Vector3.ZERO;player.face_world_point(subject.mirror_center())
		# First settle the ordinary state; then retain treatment warm-up samples,
		# including compilation/reconfiguration spikes, separately from steady work.
		for frame in 12:await RenderingServer.frame_post_draw
		var setting_started:=Time.get_ticks_usec();treatment(label)
		var setting_ms: float=(Time.get_ticks_usec()-setting_started)/1000.
		phase=label+"_warm";previous=Time.get_ticks_usec();set_process(true)
		for frame in 16:await RenderingServer.frame_post_draw
		set_process(false)
		var start:=player.global_position;var camera_before:=player.camera.global_transform
		var query_times:Array=[]
		if world.process_mode!=Node.PROCESS_MODE_DISABLED:query_times=measure()
		player.physics_profile_records.clear()
		phase=label;previous=Time.get_ticks_usec();set_process(true)
		if label.ends_with("_move"):
			player.set_physics_process(true)
			for tick in 240:
				if tick==0:key(KEY_A,true)
				if tick==12:key(KEY_A,false)
				if tick==36:key(KEY_D,true)
				if tick==48:key(KEY_D,false)
				if tick<48:
					var event:=InputEventMouseMotion.new();event.relative=Vector2(1.5 if tick<24 else -1.5,0);Input.parse_input_event(event)
				await get_tree().physics_frame
		else:
			for frame in 120:await RenderingServer.frame_post_draw
		set_process(false);key(KEY_A,false);key(KEY_D,false);player.set_physics_process(false)
		var unchanged:=player.camera.global_transform.is_equal_approx(camera_before)
		if not label.ends_with("_move") and not unchanged:failures.append("static camera changed: "+label)
		records.append({"phase":label,"setting_ms":setting_ms,"start":str(start),"end":str(player.global_position),"camera_before":str(camera_before),"camera_after":str(player.camera.global_transform),"static_camera_unchanged":unchanged,"query_ms":query_times,"slow_physics":player.physics_profile_records.duplicate(true),"active_mirror":str(mirror.active_mirror()),"housing_shadow":world.service_set_carrier._housing_shadow.cast_shadow,"msaa":get_viewport().msaa_3d,"light_rig":world.light_rig.stats(),"shadow_budget":world.light_rig._shadow_budget,"mirror_atlas":mirror._view.positional_shadow_atlas_size})
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
	restore();switches.restore_room(room,saved)
	FileAccess.open(directory.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","settings":{"viewport":str(get_viewport().size),"vsync":"disabled","max_fps":0,"physics_hz":Engine.physics_ticks_per_second,"static_frames":120,"moving_ticks":240},"original":original,"fixture_scripts":fixtures.size(),"light_nodes":lights.size(),"records":records,"samples":samples,"failures":failures,"limits":"Diagnostic controls only, not installed quality changes. Fixed world camera for causal static comparisons; actual-input control separately. Monitor values overlap/lag; warm-up retained. Room reflection streaming held stable; asset loading not isolated; no runtime qualification or human acceptance."},"\t"))
	print("BATH RENDER COST: ","PASS" if failures.is_empty() else "FAIL"," diagnostic only")
	get_tree().quit(0 if failures.is_empty() else 1)
