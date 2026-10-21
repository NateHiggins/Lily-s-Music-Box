extends "res://tests/v2_spatial_access_cohort.gd"
## INERT actual-room authoring discovery. No stack, cut, route or network grant.
const Hand=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand

func _run() -> void:
	initial_inputs=_inputs();bindings=_dependencies()
	var plan_path:=ProjectSettings.globalize_path("res://..").path_join("art/data/c_stove_stack/source_plan.json")
	var plan_hash:=FileAccess.get_sha256(plan_path)
	var proposal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(plan_path))
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests();CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC;Selector.reset_for_tests("v2")
	var world: OrisonV2RuntimeRoot=(load(Selector.scene_path()) as PackedScene).instantiate()
	add_child(world);await get_tree().physics_frame;await get_tree().physics_frame
	_check(not world.startup_failed and world.player!=null,"current V2 starts before source design is projected")
	if world.startup_failed or world.player==null:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	var root: Node3D=world.adapter.root
	var player: PlayerController=world.player;player.set_physics_process(false)
	player.call_locked=false;player.mouse_released=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	player.camera.make_current();player.set_lamp_enabled(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var physical:=world.get_world_3d().direct_space_state
	var moved: Array=[]
	for move: Dictionary in proposal.furniture_moves:
		var owner:=world.adapter.resolve(str(move.id)) as Node3D
		_check(owner!=null,"candidate furnishing has a unique existing owner: "+str(move.id))
		if owner==null:continue
		var before:=root.to_local(owner.global_position);var after:=before;after.z=float(move.z)
		owner.global_position=root.to_global(after)
		moved.append({"id":move.id,"from_local":[before.x,before.y,before.z],"to_local":[after.x,after.y,after.z]})
	await get_tree().physics_frame;await get_tree().physics_frame
	var directory: String=OS.get_environment("SHOT_DIR")
	_check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"explicit authoring discovery destination")
	var hand:=Hand.new();hand.player=player;add_child(hand)
	var rooms: Array=[];var prototypes: Array[FlueBreastProp]=[]
	for port: Dictionary in proposal.ports:
		var floor_y: float=root.level_y[port.level]
		var at:=Vector3(port.position[0],floor_y+1.44,port.position[2])
		# First record the original surface. Do not exclude the wall to pretend
		# that a port already exists in the live architecture.
		var ray:=PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.LEFT*.8),root.to_global(at+Vector3.RIGHT*.6),1,[player.get_rid()])
		var wall: Dictionary=physical.intersect_ray(ray)
		var wall_record: Dictionary=_hit(world,root,wall)
		_check(not wall.is_empty() and absf(root.to_local(wall.position).x-(float(port.position[0])+.002))<.00005,"actual original room-side wall datum: "+str(port.id))
		var prop:=FlueBreastProp.new();prop.name="Candidate_"+str(port.id);prop.prop_type="flue_breast";prop.unit=port.unit
		root.add_child(prop);prop.position=Vector3(port.position[0],floor_y,port.position[2]);prop.rotation.y=float(port.yaw);prototypes.append(prop)
		var feet:=Vector3(float(port.position[0])-.78,floor_y+.003,float(port.position[2])-.12)
		var capsule:=CapsuleShape3D.new();capsule.radius=PlayerController.BODY_RADIUS;capsule.height=PlayerController.STANDING_HEIGHT
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule
		query.transform=Transform3D(root.global_basis,root.to_global(feet+Vector3.UP*capsule.height*.5));query.collision_mask=1;query.exclude=[player.get_rid()]
		var obstructions: Array=[]
		for hit: Dictionary in physical.intersect_shape(query,32):obstructions.append(str(world.get_path_to(hit.collider)))
		_check(obstructions.is_empty(),"real standing capsule fits candidate service stance: "+str(port.id)+" "+str(obstructions))
		player.global_position=root.to_global(feet);player.camera.position=Vector3(0,PlayerController.STANDING_EYE,0)
		var contact: Vector3=prop._cap.to_global(Vector3(0,-.01,-.023))
		player.camera.look_at(contact)
		await get_tree().physics_frame;await get_tree().physics_frame
		var picked: Dictionary=player._grab.find_target()
		_check(picked.get("owner")==prop,"actual furnished-room cursor reaches candidate closure: "+str(port.id))
		var operated:=await hand.operate(contact,Vector3(.002,-.001,-.003).length(),prop)
		_check(operated,"actual furnished-room hand gesture completes: "+str(port.id))
		var released_at:=Time.get_ticks_msec()/1000.
		await get_tree().create_timer(.35).timeout
		# This live building keeps playing. A later conductor delivery may start
		# another legitimate rock after hand release; record its actual authority
		# timestamp rather than treating any nonzero pose as a broken spring.
		var later_delivery: bool=prop._last_action>released_at-.05
		_check(not prop._held and prop._pose_amount>=0. and prop._pose_amount<=1. and (later_delivery or is_zero_approx(prop._pose_amount)),"closure releases and reseats unless the live conductor delivers again: "+str(port.id))
		for frame in 8:await get_tree().process_frame
		await _shot(directory,str(port.id))
		rooms.append({"id":port.id,"space":port.space,"original_wall":wall_record,"feet_local":[feet.x,feet.y,feet.z],"standing_obstructions":obstructions,"actual_hand_completed":operated,"released_at_s":released_at,"last_conductor_delivery_s":prop._last_action,"new_delivery_near_release":later_delivery,"observed_pose_after_release":prop._pose_amount})
	# Test a proposed solid-slab vibration path, not a smoke connection. Each
	# sample records its actual first floor contact; missing slabs stay failures.
	var slab_records: Array=[];var intervals: Array=[];var points: Array=proposal.masonry_coupling.points_local_godot
	var structural_boxes: Array[CollisionShape3D]=[]
	for owner: String in proposal.masonry_coupling.owners:
		var floor:=root.get_node_or_null(owner+"/Collision") as StaticBody3D
		_check(floor!=null,"structural route has an actual existing floor owner: "+owner)
		if floor==null:continue
		for shape: CollisionShape3D in floor.get_children():
			# Roof fall/weather meshes share the floor body. Their envelopes are
			# not the retained structural slab. Inspect its real solid box shapes.
			if shape.shape is BoxShape3D and not shape.disabled:structural_boxes.append(shape)
	for segment in points.size()-1:
		var a:=Vector3(points[segment][0],points[segment][1],points[segment][2])
		var b:=Vector3(points[segment+1][0],points[segment+1][1],points[segment+1][2])
		var pieces: Array=[]
		for shape: CollisionShape3D in structural_boxes:
			var frame: Transform3D=shape.global_transform.affine_inverse()*root.global_transform
			var interval:=_interval(frame*a,frame*b,(shape.shape as BoxShape3D).size)
			if not interval.is_empty():pieces.append({"start":interval[0],"end":interval[1],"owner":str(world.get_path_to(shape))})
		pieces.sort_custom(func(one: Dictionary,two: Dictionary):return one.start<two.start)
		var covered:=0.;var continuous:=not pieces.is_empty()
		for piece: Dictionary in pieces:
			if float(piece.start)>covered+.00001/a.distance_to(b):continuous=false
			covered=maxf(covered,float(piece.end))
		_check(continuous and covered>=1.-.000001,"entire proposed vibration segment lies in actual retained structural boxes, with no stairwell shortcut: "+str(segment))
		intervals.append({"segment":segment,"pieces":pieces,"continuous":continuous,"covered_to":covered})
		var count:=int(ceil(a.distance_to(b)/float(proposal.masonry_coupling.probe_spacing_m)))
		for step in count+1:
			var point:=a.lerp(b,float(step)/count)
			var ray:=PhysicsRayQueryParameters3D.create(root.to_global(Vector3(point.x,19.29,point.z)),root.to_global(Vector3(point.x,18.95,point.z)),1,[player.get_rid()])
			var hit: Dictionary=physical.intersect_ray(ray);var record:=_hit(world,root,hit);record["segment"]=segment;record["step"]=step
			var valid:=false
			for shape: CollisionShape3D in structural_boxes:
				var local: Vector3=shape.to_local(root.to_global(point));var half: Vector3=(shape.shape as BoxShape3D).size*.5
				if local.abs().x<=half.x+.00001 and local.abs().y<=half.y+.00001 and local.abs().z<=half.z+.00001:valid=true
			_check(valid,"actual solid structural roof membership below the separate weather falls: "+str(segment)+"/"+str(step))
			record["expected_roof_contact"]=valid;slab_records.append(record)
	var core_records: Array=[];var rect: Array=proposal.riser.rect
	for x: float in [float(rect[0])+.05,(float(rect[0])+float(rect[2]))*.5,float(rect[2])-.05]:
		var z: float=(float(rect[1])+float(rect[3]))*.5
		var ray:=PhysicsRayQueryParameters3D.create(root.to_global(Vector3(x,-3.1,z)),root.to_global(Vector3(x,21.5,z)),1,[player.get_rid()])
		core_records.append(_hit(world,root,physical.intersect_ray(ray)))
	for prop: FlueBreastProp in prototypes:prop.free()
	hand.free();world.shutdown_for_tests();world.free();await get_tree().process_frame
	var final_inputs:=_inputs();_check(initial_inputs==final_inputs and bindings==_dependencies() and plan_hash==FileAccess.get_sha256(plan_path),"survey source and actual rendering inputs remain fixed")
	var record: Dictionary={"evidence_class":"INERT","scope":"Actual existing wall datums, full standing capsule placements, three temporarily relocated furnishings, temporary thimble hand/captures and actual structural-box segment coverage. Proposed stove stack and all new apertures NOT installed; no walked route, network, soil/foundation or human acceptance.","source":{"production":final_inputs,"test_dependencies":bindings,"plan_sha256":plan_hash},"rooms":rooms,"furniture_moves":moved,"roof_slab_samples":slab_records,"structural_segments":intervals,"existing_stack_core_obstructions":core_records,"checks":checks,"failures":failures}
	FileAccess.open(directory.path_join("survey.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	print("C STOVE STACK SURVEY: ","PASS" if failures==0 else "FAIL"," rooms=",rooms.size()," roof_samples=",slab_records.size()," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)

func _hit(world: Node,root: Node3D,hit: Dictionary) -> Dictionary:
	if hit.is_empty():return {"owner":"none"}
	var point: Vector3=root.to_local(hit.position)
	return {"owner":str(world.get_path_to(hit.collider)),"position":[point.x,point.y,point.z]}

func _shot(directory: String,identity: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(directory.path_join(identity+".png"))==OK,"actual furnished-room candidate frame: "+identity)

func _interval(a: Vector3,b: Vector3,size: Vector3) -> Array:
	var low:=0.;var high:=1.;var delta:=b-a;var half:=size*.5
	for axis in 3:
		if absf(delta[axis])<.00000001:
			if a[axis]<-half[axis] or a[axis]>half[axis]:return []
		else:
			var first:=(-half[axis]-a[axis])/delta[axis];var last: float=(half[axis]-a[axis])/delta[axis]
			low=maxf(low,minf(first,last));high=minf(high,maxf(first,last))
			if high<low:return []
	return [low,high]
