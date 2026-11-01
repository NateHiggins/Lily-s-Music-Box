extends "res://tests/v2_spatial_access_cohort.gd"
## INERT construction discovery. Native mesh bounds are never solid masks.
func _run() -> void:
	initial_inputs=_inputs();bindings=_dependencies()
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC;Selector.reset_for_tests("v2")
	var world: OrisonV2RuntimeRoot=(load(Selector.scene_path()) as PackedScene).instantiate()
	add_child(world);await get_tree().physics_frame;await get_tree().physics_frame
	# The runtime's ready path yields during companion composition. Two physics
	# ticks alone do not establish that every retained static owner exists yet.
	while world.startup_ms<=0. and not world.startup_failed:await get_tree().process_frame
	_check(not world.startup_failed,"current production-selected V2 starts for grade survey")
	if world.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	var root: Node3D=world.adapter.root
	var records: Array=[];var skipped: Dictionary={};var poses: Dictionary={}
	for shape: CollisionShape3D in world.find_children("*","CollisionShape3D",true,false):
		if not shape.get_parent() is StaticBody3D or shape.disabled or shape.shape==null:continue
		if ((shape.get_parent() as StaticBody3D).collision_layer&1)==0:continue
		if not shape.shape is BoxShape3D:
			var kind: String=shape.shape.get_class();skipped[kind]=int(skipped.get(kind,0))+1;continue
		var pose: Transform3D=root.global_transform.affine_inverse()*shape.global_transform
		var box: AABB=pose*AABB(-shape.shape.size*.5,shape.shape.size)
		if box.position.y>=.050001 or box.end.y<=-4.:continue
		var aligned:=true
		for axis: Vector3 in [pose.basis.x,pose.basis.y,pose.basis.z]:
			var active:=0
			for component: float in [axis.x,axis.y,axis.z]:
				if absf(component)>.00003:active+=1
			aligned=aligned and active==1 and absf(axis.length()-1.)<.00003
		records.append({"owner":str(world.get_path_to(shape.get_parent())),"shape_owner":str(shape.name),"shape_type":"BoxShape3D","aligned":aligned,"bounds":[box.position.x,box.position.y,box.position.z,box.end.x,box.end.y,box.end.z],"pose":_pose(pose)})
	# Receiving is a sibling of the registered blockout, with its own mount.
	# Its first child is the actual instantiated native asset, not a mesh AABB.
	var receiving: Node3D=world.get_node_or_null("BodegaReceiving")
	_check(receiving!=null and receiving.get_child_count()>0 and receiving.get_child(0) is Node3D,"native receiving registration owner exists")
	if failures>0:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	var native_receiving: Node3D=receiving.get_child(0)
	poses.receiving=_pose(root.global_transform.affine_inverse()*native_receiving.global_transform)
	poses.city=_pose(root.global_transform.affine_inverse()*(world.get_node("CityShells") as Node3D).global_transform)
	var directory: String=OS.get_environment("SHOT_DIR")
	_check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"explicit survey output")
	# Current layout and actual rendering inputs remain fixed during this survey.
	var final_inputs:=_inputs();_check(initial_inputs==final_inputs and bindings==_dependencies(),"survey inputs remain fixed")
	var file: FileAccess=FileAccess.open(directory.path_join("grade_owners.json"),FileAccess.WRITE)
	_check(file!=null,"write fresh grade ownership discovery")
	if file!=null:
		file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual aligned static boxes only. Unaligned boxes and all other shapes require separate native/source classification, never AABB solid substitution.","records":records,"skipped_shapes":skipped,"poses":poses,"source":{"runtime_inputs_sha256":final_inputs.runtime,"surface_inputs_sha256":final_inputs.surface,"test_dependencies":bindings},"failures":failures},"\t"));file.flush()
	await _after_discovery(world)
	world.shutdown_for_tests();world.free();await get_tree().process_frame
	print("V2 GRADE OWNER SURVEY: ","PASS" if failures==0 else "FAIL"," boxes=",records.size()," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)

func _after_discovery(_world: OrisonV2RuntimeRoot) -> void:
	# Optional same-world programme; the standalone discovery keeps its lifecycle.
	pass

static func _pose(pose: Transform3D) -> Dictionary:
	return {"origin":[pose.origin.x,pose.origin.y,pose.origin.z],"x_axis":[pose.basis.x.x,pose.basis.x.y,pose.basis.x.z],"y_axis":[pose.basis.y.x,pose.basis.y.y,pose.basis.y.z],"z_axis":[pose.basis.z.x,pose.basis.z.y,pose.basis.z.z]}
