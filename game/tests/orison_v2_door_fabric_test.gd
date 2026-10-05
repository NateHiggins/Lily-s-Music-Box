extends "res://tests/orison_v2_roof_membrane_test.gd"
## Actual fitted moving bodies must clear retained fabric throughout motion.
const WC := preload("res://scripts/building/orison_v2_bar_wc_door.gd")

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	if world.startup_failed:get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	var excluded: Array[RID]=[]
	for actor: CharacterBody3D in world.find_children("*","CharacterBody3D",true,false):excluded.append(actor.get_rid())
	var poses:=0;var leaves:=0;var records: Array=[]
	for node: Node3D in world.find_children("*","Node3D",true,false):
		if node is not DoorProp or not (node is OrisonV2FittedDoor or node.get_script()==WC):continue
		var door:=node as DoorProp;var collision:=door._body.get_child(0) as CollisionShape3D
		var target:=door.motion_target_angle(true);var steps:=roundi(absf(rad_to_deg(target)))
		check(absf(door._body.rotation.y-(target if door.open else 0.0))<.001,"settled actual startup pose matches its fitted stop: "+DoorKeyring.identity(door))
		var self_excluded:=excluded.duplicate();self_excluded.append(door._body.get_rid())
		var conflicts: Array=[]
		for degree in range(steps+1):
			var pose:=door._body.global_transform
			pose.basis=door.global_basis*Basis(Vector3.UP,target*float(degree)/steps)
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=collision.shape;query.transform=pose*collision.transform
			query.margin=.0001;query.collision_mask=1;query.exclude=self_excluded
			var contacts:=world.get_world_3d().direct_space_state.intersect_shape(query,8)
			for contact: Dictionary in contacts:conflicts.append({"degree":degree,"collider":str(contact.collider.get_path())})
			poses+=1
		check(conflicts.is_empty(),"full actual moving-body clearance: "+DoorKeyring.identity(door))
		if not conflicts.is_empty():print("FITTED DOOR CONFLICT ",DoorKeyring.identity(door)," ",conflicts[0])
		records.append({"id":DoorKeyring.identity(door),"degrees":steps,"conflicts":conflicts,"hinge_origin_local":str(door._body.position),"shape_origin_local":str(collision.position),"closed_center_world":str(door._body.global_transform*collision.position),"leaf_origin":str(door.global_position)})
		leaves+=1
	check(leaves>100,"all fitted residential/service leaves and the bar restroom are inspected")
	var wc: DoorProp=world.bar_region.doors["F01_BAR_WC_DOOR"]
	# Production batches repeated hinge copies into each moving/fixed owner.
	# Reopen the actual installed export for its two independent UV charts.
	var native: Node3D=(preload("res://assets/props/wc_swing_clear_hinge.glb") as PackedScene).instantiate()
	var mapped:=0
	for draw: MeshInstance3D in native.find_children("*","MeshInstance3D",true,false):
		_check_cap_mapping(draw.mesh,true)
		mapped+=1
	check(mapped==2,"both actual imported hinge halves retain metric UVs and derivative tangents")
	native.free()
	for fraction: float in [0.0,.5,1.0]:
		wc._body.rotation.y=wc.motion_target_angle(true)*fraction
		world.player.global_position=wc.to_global(Vector3(.35,.02,-.9))
		world.player.face_world_point(wc.to_global(Vector3(-.06,1.07,-.04)))
		await get_tree().create_timer(.65).timeout
		await shot("wc_hinge_"+str(roundi(fraction*90)))
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("door-fabric.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","leaves":leaves,"poses":poses,"records":records,"failures":failures.size(),"failure_labels":failures},"\t"))
	for failure: String in failures:print("FITTED DOOR FAIL: ",failure)
	print("FITTED DOOR FABRIC: leaves=",leaves," poses=",poses," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
