extends "res://tests/orison_v2_ventilation_fabric_test.gd"
## Retained steam feed: actual open lumen, structural seats and fitted steel.
## Static construction inspection; no distribution/flow or ledger promotion.

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production composition initializes")
	if world.player==null:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root
	var pipe:=root.get_node("BoilerPipework") as Node3D
	var inlet:=pipe.get_node("InletSleeves/InletFabricLining") as MeshInstance3D
	check(inlet.material_override==MatLib.get_mat("metal"),"inlet uses existing metal material")
	_check_mapping(inlet.mesh,true)
	var inlet_pose:=root.global_transform.affine_inverse()*inlet.global_transform
	var inlet_faces: PackedVector3Array=inlet_pose*inlet.mesh.get_faces()
	var fitted_shape:=pipe.get_node("InletFabricLiningCollision").get_child(0) as CollisionShape3D
	var fitted_pose:=root.global_transform.affine_inverse()*fitted_shape.global_transform
	var fitted_faces: PackedVector3Array=fitted_pose*fitted_shape.shape.get_faces()
	check(inlet_pose.is_equal_approx(fitted_pose),"fitted collision and rendered geometry share the same complete transform")
	check(not fitted_shape.disabled and fitted_shape.get_parent().collision_layer==1 and not fitted_shape.shape.backface_collision,"fitted body remains enabled with ordinary one-sided triangle collision")
	var own: Array[RID]=[world.player.get_rid()]
	for body: StaticBody3D in pipe.find_children("*","StaticBody3D",true,false):own.append(body.get_rid())
	check(own.size()==4,"two retained pipe bodies and one added fitted lining body")
	var boiler:=world.adapter.resolve("B1_BOILER_01") as BoilerProp
	var start:=root.to_local(boiler.to_global(Vector3(.05,2.02,.02)))
	var high:=Vector3(start.x,-.55,start.z)
	var turn:=Vector3(8.675,high.y,high.z)
	var end:=Vector3(turn.x,high.y,.525)
	var segments: Array=[
		[start+Vector3.UP*.002,high-Vector3.UP*.14],
		[high+Vector3.LEFT*.14,turn+Vector3.RIGHT*.14],
		[turn+Vector3.BACK*.14,end]]
	var tee:=root.to_local(boiler.to_global(Vector3(.05,2.35,.02)))
	segments.append([tee+Vector3.BACK*.003,tee+Vector3.BACK*.20,.016,.028])
	for corner: Array in [[high,Vector3.UP,Vector3.LEFT],[turn,Vector3.LEFT,Vector3.BACK]]:
		var center: Vector3=corner[0]-corner[1]*.14+corner[2]*.14
		for index in 16:
			var a: float=index*PI/32;var b: float=(index+1)*PI/32
			segments.append([center-corner[2]*.14*cos(a)+corner[1]*.14*sin(a),center-corner[2]*.14*cos(b)+corner[1]*.14*sin(b)])
	var physics_samples:=0
	var volumes: Array=[]
	for segment: Array in segments:
		var a: Vector3=segment[0];var b: Vector3=segment[1]
		var direction: Vector3=(b-a).normalized()
		var seed:=Vector3.UP if absf(direction.y)<.95 else Vector3.BACK
		var u:=direction.cross(seed).normalized();var v:=direction.cross(u).normalized()
		var hits: Array=[]
		for index in 9:
			var offset:=Vector3.ZERO
			if index>0:offset=(segment[3] if segment.size()>3 else .068)*(u*cos((index-1)*TAU/8)+v*sin((index-1)*TAU/8))
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(a+offset),root.to_global(b+offset),1,[world.player.get_rid()])
			query.hit_from_inside=true
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():hits.append(str(root.get_path_to(hit.collider)))
			physics_samples+=1
		check(hits.is_empty(),"sampled lumen clears live collision along retained straight/elbow/tee "+str(a)+" to "+str(b)+": "+str(hits))
		var volume:=AABB(a,Vector3.ZERO).expand(b).grow(segment[2] if segment.size()>2 else .037)
		if volumes.size()<3:
			# The source boss is the deliberate upstream receptor boundary.
			# Expand the sampled section sideways, not back into that source.
			var axis: int=(b-a).abs().max_axis_index()
			volume.position[axis]=minf(a[axis],b[axis])+.000001
			volume.size[axis]=absf(b[axis]-a[axis])-.000002
		volumes.append(volume)
	var obstruction: Dictionary={}
	var tested_draws:=0
	for draw: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null or not draw.is_visible_in_tree():continue
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		var bound: AABB=pose*draw.mesh.get_aabb()
		var relevant: Array=[]
		for volume: AABB in volumes:
			if bound.intersects(volume):relevant.append(volume)
		if relevant.is_empty():continue
		tested_draws+=1
		var faces: PackedVector3Array=pose*draw.mesh.get_faces()
		for volume: AABB in relevant:
			for index in range(0,faces.size(),3):
				if _triangle_in_box(faces[index],faces[index+1],faces[index+2],volume):obstruction[str(root.get_path_to(draw))]=true
	check(obstruction.is_empty(),"actual retained inlet lumen is free of geometry: "+str(obstruction.keys()))
	var bearing_samples:=0
	var bolts:=0
	for seat: Array in [
		["B1_BOILER_ROOM",0,Vector3(9.43,-.55,-.55),-1.0],
		["B1_BOILER_ROOM",0,Vector3(9.57,-.55,-.55),1.0],
		["B1_BOILER_APPROACH",2,Vector3(8.675,-.55,.13),-1.0],
		["B1_BOILER_APPROACH",2,Vector3(8.675,-.55,.27),1.0],
		["HEAT_STACK",2,Vector3(8.675,-.55,.3),-1.0]]:
		var holder:=root.get_node(str(seat[0])) as Node3D
		var structural:=PackedVector3Array()
		var draws: Array[MeshInstance3D]=[]
		if holder is MeshInstance3D:draws.append(holder)
		for draw: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):draws.append(draw)
		for draw: MeshInstance3D in draws:
			var pose:=root.global_transform.affine_inverse()*draw.global_transform
			structural.append_array(pose*draw.mesh.get_faces())
		var axis: int=seat[1];var center: Vector3=seat[2]
		var outward:=Vector3.ZERO;outward[axis]=seat[3]
		for du: float in [-.122,0.0,.122]:
			for dv: float in [-.122,0.0,.122]:
				if du==0 and dv==0:continue
				var at:=center+outward*.04;at[(axis+1)%3]+=du;at[(axis+2)%3]+=dv
				var distance:=_mesh_distance(structural,at,-outward)
				check(is_finite(distance) and absf(distance-.04)<.00001,"full bearing-plate perimeter meets its actual structural face")
				var query:=PhysicsRayQueryParameters3D.create(root.to_global(at),root.to_global(at-outward*.06),1,own)
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty() and holder.is_ancestor_of(hit.collider),"bearing perimeter also meets live structural collision")
				bearing_samples+=1
		for du: float in [-.109,.109]:
			for dv: float in [-.109,.109]:
				# Sample inside the hex face, away from its shared triangulation
				# diagonal; a boundary ray is not a stable contact measurement.
				var at:=center+outward*.02;at[(axis+1)%3]+=du+.001;at[(axis+2)%3]+=dv+.0007
				var distance:=_mesh_distance(inlet_faces,at,-outward)
				check(is_finite(distance) and absf(distance-.015)<.00002,"fixed hex bolt meets its exported head")
				var query:=PhysicsRayQueryParameters3D.create(root.to_global(at),root.to_global(at-outward*2.0),1,[world.player.get_rid()])
				# Geometry3D's triangle determinant test is length-dependent;
				# retain a long ray and require the same first 15 mm contact.
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty() and pipe.is_ancestor_of(hit.collider) and absf(at.distance_to(root.to_local(hit.position))-distance)<.00002,"bolt's own collision matches the transformed native mesh: "+str(hit.get("collider"))+" mesh="+str(distance)+" shape="+str(_mesh_distance(fitted_faces,at,-outward))+" actual="+str(at.distance_to(root.to_local(hit.position)) if not hit.is_empty() else INF))
				bolts+=1
	check(segments.size()==36 and physics_samples==324 and bearing_samples==40 and bolts==20,"every retained leg, bend, tee, plate perimeter and bolt is inspected")
	await _capture_inlet(world,root)
	print("BOILER INLET: checks=%d straight_legs=3 elbow_chords=32 tee_leg=1 physics_samples=%d bearing_samples=%d bolts=%d draws=%d lining_triangles=%d obstructions=%d failures=%d startup_ms=%f" % [checks,physics_samples,bearing_samples,bolts,tested_draws,inlet_faces.size()/3,obstruction.size(),failures.size(),world.startup_ms])
	world.shutdown_for_tests();world.free();await _retired_audio()
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture_inlet(world: Node3D,root: Node3D) -> void:
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=50
	for view: Array in [
		["boiler_west",Vector3(10.4,-1.676,-2.2),Vector3(9.575,-.55,-.55)],
		["approach_west",Vector3(8.4,-1.676,-.85),Vector3(9.428,-.55,-.55)],
		["approach_north",Vector3(8.35,-1.676,-.8),Vector3(8.675,-.55,.128)]]:
		camera.global_position=root.to_global(view[1]);camera.look_at(root.to_global(view[2]))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
		world.player.camera.global_transform=camera.global_transform;world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0])
	# An explicitly internal fabrication inspection, separate from player views.
	camera.global_position=root.to_global(Vector3(8.675,-.55,.611));camera.look_at(root.to_global(Vector3(8.675,-.55,.35)))
	world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
	world.player.camera.global_transform=camera.global_transform
	await _settled_optics();await shot("receiver_internal_inspection")
