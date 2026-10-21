extends "res://tests/orison_v2_floor_surface_test.gd"
## Fixture camera census, not continuous access, played-room proof or acceptance.
var records: Array=[]
func _run() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true);CampaignClock.new().configure_date(1928,11,10,20*60)
	var world: OrisonV2RuntimeRoot=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	if world.startup_failed:world.free();get_tree().quit(1);return
	var player: PlayerController=world.player
	player.set_physics_process(false);player.set_lamp_enabled(true);player.carried_device.set_capture_hidden(true)
	player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var root: Node3D=world.adapter.root
	var selected:=OS.get_environment("ORISON_AREA_IDS").split(",",false)
	var settle:=maxi(4,int(OS.get_environment("ORISON_AREA_SETTLE_FRAMES")))
	for room: Dictionary in world.layout.spaces:
		if not selected.is_empty() and str(room.id) not in selected:continue
		var identity:=str(room.id);var rect: Array=room.rect
		var base: float=root.level_y[str(room.level)]
		var pose:=_stance(world,root,rect,base)
		if pose.is_empty() and OS.get_environment("ORISON_AREA_ADJACENT_VIEW")=="1":
			pose=_stance(world,root,[rect[0]-1.,rect[1]-1.,rect[2]+1.,rect[3]+1.],base)
			if not pose.is_empty():pose["outside_space"]=true
		var record: Dictionary={"id":identity,"class":room.get("class",""),"level":room.level,"rect":rect,"stance":pose,"images":[]}
		if not pose.is_empty():
			player.global_position=Vector3(pose.feet[0],pose.feet[1],pose.feet[2]);player.velocity=Vector3.ZERO
			player.camera.position.y=PlayerController.CROUCH_EYE if pose.crouched else PlayerController.STANDING_EYE
			for quarter in 4:
				player.global_rotation=Vector3(0,root.global_rotation.y+quarter*PI*.5,0);player.camera.rotation=Vector3(-.08,0,0)
				if pose.get("outside_space",false):player.face_world_point(root.to_global(Vector3((rect[0]+rect[2])*.5,base+.9,(rect[1]+rect[3])*.5)))
				for frame in settle:await RenderingServer.frame_post_draw
				var picture:=get_viewport().get_texture().get_image();picture.resize(640,360,Image.INTERPOLATE_LANCZOS)
				var filename:=identity+"_%d.jpg"%quarter
				check(picture.save_jpg(directory.path_join(filename),.86)==OK,"area camera saved: "+filename)
				record.images.append(filename)
		else:print("AREA SURVEY NO CAPSULE STANCE: ",identity)
		records.append(record)
		FileAccess.open(directory.path_join("areas.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Four diagnostic camera directions from measured capsule-clear floor poses; fixture placement, no route or interaction grant. Uncaptured areas remain explicit.","source_resolution":str(get_viewport().get_visible_rect().size),"records":records,"failures":failures},"\t"))
		print("AREA SURVEY ",records.size(),"/",world.layout.spaces.size()," ",identity," captured=",not pose.is_empty())
	world.shutdown_for_tests();world.free()
	await get_tree().physics_frame
	print("V2 AREA SURVEY: ",records.size()," areas; failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _stance(world: Node3D,root: Node3D,rect: Array,base: float) -> Dictionary:
	var space:=world.get_world_3d().direct_space_state
	for crouched: bool in [false,true]:
		var capsule:=CapsuleShape3D.new();capsule.radius=PlayerController.BODY_RADIUS;capsule.height=PlayerController.CROUCH_HEIGHT if crouched else PlayerController.STANDING_HEIGHT
		for z: float in [.5,.25,.75,.1,.9]:
			for x: float in [.5,.25,.75,.1,.9]:
				var at:=root.to_global(Vector3(lerpf(rect[0],rect[2],x),base,lerpf(rect[1],rect[3],z)))
				var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.4,at-Vector3.UP*.35,1,[world.player.get_rid()])
				var floor_hit:=space.intersect_ray(ray)
				if floor_hit.is_empty() or floor_hit.normal.y<.7:continue
				var feet: Vector3=floor_hit.position+Vector3.UP*.003
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*capsule.height*.5);query.margin=.001;query.collision_mask=1;query.exclude=[world.player.get_rid()]
				if space.intersect_shape(query,1).is_empty():return {"feet":[feet.x,feet.y,feet.z],"crouched":crouched,"floor":str(floor_hit.collider.get_path())}
	return {}
