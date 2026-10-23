extends "res://tests/v2_bath_contact_installed.gd"
## Installed owner checks, paired opening views and actual portal manipulation.
var policy: Node
var checks:=0
var observations: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1;print("SERVICE VISIBILITY: ",label," = ",ok)
	if not ok:failures.append(label)

func stance_near(anchor: Node3D,axis: String,floor_y: float) -> Vector3:
	var normal: Vector3=world.adapter.root.global_basis*(Vector3.BACK if axis=="x" else Vector3.RIGHT)
	var tangent: Vector3=normal.cross(Vector3.UP)
	for distance: float in [.0,.65,-.65,1.,-1.]:
		for offset: float in [0.,.18,-.18]:
			var feet: Vector3=anchor.global_position+normal*distance+tangent*offset;feet.y=floor_y+.01
			var capsule:=CapsuleShape3D.new();capsule.radius=PlayerController.BODY_RADIUS;capsule.height=PlayerController.STANDING_HEIGHT
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=player.collision_mask;query.exclude=[player.get_rid()];query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*PlayerController.STANDING_HEIGHT*.5)
			if world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return feet
	return Vector3.INF

func sample_view(label: String,frames: int=40) -> Dictionary:
	phase=label+"_warm";previous=Time.get_ticks_usec();set_process(true)
	for frame in 12:await RenderingServer.frame_post_draw
	set_process(false)
	var before:=player.camera.global_transform
	phase=label;previous=Time.get_ticks_usec();set_process(true)
	for frame in frames:await RenderingServer.frame_post_draw
	set_process(false)
	check(player.camera.global_transform.is_equal_approx(before),"paired view holds real camera: "+label)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
	return {"phase":label,"room":policy.context_room,"reachable":policy.reachable.keys(),"conservative":policy.conservative,"visible_sources":policy.visible_sources.duplicate(),"camera":str(before)}

func run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests();GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	world=load("res://scenes/building/orison_v2_runtime.tscn").instantiate();add_child(world)
	check(not world.startup_failed,"ordinary production world starts")
	if world.startup_failed:get_tree().quit(1);return
	player=world.player;player.set_physics_process(false);policy=world.service_light_visibility
	# Retained room/door-graph regression. New distance/active-camera behavior
	# has separate installed render and source-state controls.
	policy.set_distance_enabled(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	world.service_set_carrier.set_capture_hidden(true);player.set_lamp_enabled(false)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	check(policy.enabled and policy.sources.size()==16,"all 16 original service lights registered")
	var state_before:=var_to_bytes(RealityState.data)
	policy._poll()
	check(var_to_bytes(RealityState.data)==state_before,"visibility writes no durable gameplay facts")
	var refreshes: Node=world.get_node("V2RoomReflections")
	for source: Dictionary in policy.sources:
		var opening: Dictionary={}
		for record: Dictionary in world.layout.openings:
			if str(record.id)==source.id:opening=record;break
		check(not opening.is_empty(),"existing opening owns source: "+source.id)
		check(source.light.shadow_enabled and source.light.omni_shadow_mode==OmniLight3D.SHADOW_CUBE and is_equal_approx(source.light.light_energy,3.2) and is_equal_approx(source.light.omni_range,4.8),"original energy, reach and cube shadows: "+source.id)
		var anchor: Node3D=world.adapter.root.get_node(source.id)
		var feet:=stance_near(anchor,str(opening.axis),anchor.global_position.y)
		check(feet.is_finite(),"full-capsule view at source: "+source.id)
		if not feet.is_finite():continue
		player.global_position=feet;player.velocity=Vector3.ZERO;player.face_world_point(anchor.global_position+Vector3.UP*.95)
		refreshes.set_physics_process(true)
		for tick in 20:await get_tree().physics_frame
		for frame in 8:await RenderingServer.frame_post_draw
		refreshes.set_physics_process(false)
		policy.set_enabled(false)
		observations.append(await sample_view(source.id+"_original"))
		policy.set_enabled(true)
		observations.append(await sample_view(source.id+"_connected"))
		check(source.light.visible,"own connected opening retains its service light: "+source.id)
	# Unknown/outside and open vertical volumes must retain the original view.
	player.global_position=Vector3(90,0,90);player.face_world_point(Vector3(91,1.4,90));policy._invalidate();policy._poll()
	check(policy.conservative and policy.visible_sources.size()==16,"unknown/outside context conservatively retains every source")
	var anchor:=world.adapter.root.get_node("F03_B_BATH_DOOR") as Node3D
	var door:=anchor.get_node("F03_B_BATH_DOOR_Leaf") as DoorProp
	var saved: Dictionary=door.mechanism_snapshot()
	var driver:=preload("res://tests/orison_v2_4b_door_route_test.gd").new();driver.externally_managed=true;driver.world=world;driver.player=player;add_child(driver)
	player.global_position=Vector3(-14.325,6.400265,-.575);player.velocity=Vector3.ZERO;policy._invalidate();policy._poll()
	check(policy.context_room=="F03_B_BATH" and not policy.conservative,"closed bathroom context comes from existing room owner")
	var closed_sources: Array=policy.visible_sources.duplicate()
	check(closed_sources.is_empty(),"closed opaque bath isolates unrelated service lights")
	var aim: Vector3=door.to_global(Vector3(door.width*.5,1.1,0))
	player.face_world_point(aim)
	await get_tree().physics_frame
	if await driver._drag_part(door,aim,door.motion_target_angle(true),"service_visibility_open"):
		policy._invalidate();policy._poll()
		check(door.open and policy.visible_sources.size()>closed_sources.size(),"actual door opening restores connected service lights")
		observations.append(await sample_view("bath_door_open"))
		if await driver._drag_part(door,door._body.to_global(Vector3(door.width*.5,1.1,0)),0.,"service_visibility_close"):
			policy._invalidate();policy._poll()
			check(not door.open and policy.visible_sources==closed_sources,"actual closing restores isolated source set")
	for failure: String in driver.failures:failures.append(failure)
	player.cancel_manipulation();door.restore_mechanism(saved);policy._invalidate();policy._poll();driver.free()
	var sink_check: Dictionary=await installed_interactions()
	FileAccess.open(directory.path_join("review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"observations":observations,"sink_checks":sink_check,"samples":samples,"limits":"Sixteen actual source views, fixed-camera before/after and real door/sink input. Direct placement at surveyed full capsule stances, not walked routes. No whole-V2 surface/runtime qualification, cross-court glazing qualification or human acceptance."},"\t"))
	print("SERVICE LIGHT VISIBILITY REVIEW: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks)
	get_tree().quit(0 if failures.is_empty() else 1)
