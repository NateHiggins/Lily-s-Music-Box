extends Node3D
## Headless passive support/timing diagnostic, never player-input acceptance.
const Fixture=preload("res://tests/v2_fire_hand_bench.gd")
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	print("NOZZLE PHYSICS ENGINE: ",ProjectSettings.get_setting("physics/3d/physics_engine")," server=",PhysicsServer3D.get_class())
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var adapter:=Fixture.FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=preload("res://scripts/building/orison_v2_native_fire_service.gd").new()
	if not native.mount(adapter,{"levels":[{"y":0.}]}):push_error(str(native.errors));get_tree().quit(1);return
	var before: Dictionary={};var started: int=Time.get_ticks_usec()
	for step in range(40):
		await get_tree().physics_frame
		if step not in [0,9,19,39]:continue
		for key: String in native.stations:
			var joint: Node3D=native.stations[key].get_ref()._nozzle_joint
			print("NOZZLE SUPPORT PROBE ",step," ",key," pose=",joint.body.position," support=",joint._support.get_ref().get_path() if joint._support!=null and joint._support.get_ref()!=null else "none"," last_sweep_ms=",joint.last_sweep_ms)
			if step==19:before[key]=joint.body.position
	var ok: bool=true
	for key: String in native.stations:
		var joint: Node3D=native.stations[key].get_ref()._nozzle_joint
		ok=ok and joint._support!=null and joint.body.position==before[key]
	var joint: Node3D=native.stations.values()[0].get_ref()._nozzle_joint
	# Query the installed receiver alone using the same overlap API as carry.
	# Sample the native-certified bore and retain a positive stock control.
	var exclusions: Array[RID]=[]
	for key: String in native.stations:
		var other: Node3D=native.stations[key].get_ref()._nozzle_joint
		exclusions.append((other.seat.get_child(0) as CollisionObject3D).get_rid())
		if other!=joint:exclusions.append(other.physical_nut.get_rid())
	var receiver_frame: Transform3D=joint.physical_nut.global_transform
	var skin_query:=PhysicsShapeQueryParameters3D.new();var skin:=SphereShape3D.new();skin.radius=.0002;skin_query.shape=skin;skin_query.collision_mask=joint.FITTING_LAYER;skin_query.exclude=exclusions;skin_query.margin=0.
	var bore_clear:=true
	for sample in 17:
		var theta: float=TAU*sample/16.;var radius: float=0. if sample==16 else .02015
		for height: float in [.017,.019,.021,.023,.025,.027,.029]:
			skin_query.transform=Transform3D(Basis.IDENTITY,receiver_frame*Vector3(radius*cos(theta),height,radius*sin(theta)))
			bore_clear=bore_clear and get_world_3d().direct_space_state.intersect_shape(skin_query,1).is_empty()
	skin_query.transform=Transform3D(Basis.IDENTITY,receiver_frame*Vector3(.025,.029,0))
	var wall_hits: Array[Dictionary]=get_world_3d().direct_space_state.intersect_shape(skin_query,1)
	var bore_ok: bool=bore_clear and not wall_hits.is_empty() and wall_hits[0].collider==joint.physical_nut
	print("NOZZLE RECEIVER BORE: ",bore_ok," clear_overlap_samples=119 clear=",bore_clear," positive_stock=",not wall_hits.is_empty())
	ok=ok and bore_ok
	var state: Dictionary=joint.snapshot();state.clocking=1.1;state.spin=1.1
	var at: Vector3=joint.thread_pose(joint.stock.maximum_angle(),1.1).origin
	state.position=[at.x,at.y,at.z];joint.restore(state)
	for step in range(40):await get_tree().physics_frame
	print("NOZZLE PHASE SUPPORT: ",joint.body.position," support=",joint._support.get_ref().get_path() if joint._support!=null and joint._support.get_ref()!=null else "none")
	if joint._support!=null and joint._support.get_ref()!=null:
		var floor: Node3D=joint._support.get_ref().get_parent_node_3d()
		var height: float=joint.body.position.y
		print("NOZZLE MOVING SUPPORT: ",floor.get_path());floor.position.y-=.03
		for step in range(30):
			await get_tree().physics_frame
			if step in [0,1,10,29]:print("NOZZLE DROP ",step," at=",joint.body.position," hit=",joint._last_contact.get_path() if is_instance_valid(joint._last_contact) else "none"," cached=",joint._support.get_ref().get_path() if joint._support!=null and joint._support.get_ref()!=null else "none"," ms=",joint.last_sweep_ms)
		ok=ok and joint.body.position.y<height-.01
	joint.set_physics_process(false);joint.clocking=0.;joint.spin=0.
	joint.body.transform=joint.thread_pose(joint.stock.maximum_angle(),0.);joint._apply_visuals()
	await get_tree().physics_frame;await get_tree().physics_frame
	var inward: Vector3=-joint.receiver.basis.y*.006
	var proof: bool=not joint._outside_receiver(joint.body.global_transform,joint.actor.global_basis*inward)
	if OS.get_environment("ORISON_NOZZLE_CONTACT_PROFILE")=="1":
		for distance: float in [0.,.0001,.0007,.0014,.002,.003,.0037]:
			var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=1;query.margin=0.;query.exclude=[joint.body.get_rid(),joint.actor._bodies.lever.get_rid()]
			var count:=0
			for leaf: CollisionShape3D in joint._spigot_shapes:
				query.shape=leaf.shape;query.transform=joint.body.global_transform*leaf.transform;query.transform.origin+=joint.actor.global_basis*inward.normalized()*distance
				if not joint.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():count+=1
			print("NOZZLE START PROFILE: distance=",distance," overlapping_sectors=",count)
		for distance: float in [.0001,.0007,.0014,.006]:
			var query:=PhysicsTestMotionParameters3D.new();query.from=joint.body.global_transform;query.motion=joint.actor.global_basis*inward.normalized()*distance;query.margin=.00002;query.exclude_bodies=[joint.actor._bodies.lever.get_rid()]
			var result:=PhysicsTestMotionResult3D.new();var start: int=Time.get_ticks_usec()
			var hit: bool=PhysicsServer3D.body_test_motion(joint.body.get_rid(),query,result)
			print("NOZZLE CONTACT PROFILE: shapes=",joint.body.get_child_count()," distance=",distance," ms=",(Time.get_ticks_usec()-start)/1000.," hit=",hit," travel=",result.get_travel()," collider=",result.get_collider().get_path() if hit and result.get_collider()!=null else "none")
		var shapes: Array[ConvexPolygonShape3D]=joint._draw_shapes(joint.spigot)
		var earliest:=1.;var contact: Dictionary={};var start: int=Time.get_ticks_usec()
		for shape: ConvexPolygonShape3D in shapes:
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=joint.body.global_transform;query.motion=joint.actor.global_basis*inward;query.margin=.00002;query.collision_mask=1;query.exclude=[joint.body.get_rid(),joint.actor._bodies.lever.get_rid()]
			var fractions: PackedFloat32Array=joint.get_world_3d().direct_space_state.cast_motion(query)
			if fractions[0]<earliest:
				earliest=fractions[0];query.transform.origin+=query.motion*fractions[1];query.motion=Vector3.ZERO
				contact=joint.get_world_3d().direct_space_state.get_rest_info(query)
		print("NOZZLE SPIGOT CAST PROFILE: shapes=",shapes.size()," ms=",(Time.get_ticks_usec()-start)/1000.," fraction=",earliest," info=",contact)
		earliest=1.;start=Time.get_ticks_usec()
		for leaf: CollisionShape3D in joint._spigot_shapes:
			var frame: Transform3D=joint.body.global_transform*leaf.transform
			var points:=PackedVector3Array()
			for point: Vector3 in leaf.shape.points:points.append(frame.basis*point)
			var baked:=ConvexPolygonShape3D.new();baked.points=points;baked.margin=.00001
			var cast:=PhysicsShapeQueryParameters3D.new();cast.shape=baked;cast.transform=Transform3D(Basis.IDENTITY,frame.origin);cast.motion=joint.actor.global_basis*inward;cast.margin=.00002;cast.collision_mask=1;cast.exclude=[joint.body.get_rid(),joint.actor._bodies.lever.get_rid()]
			var fractions: PackedFloat32Array=joint.get_world_3d().direct_space_state.cast_motion(cast)
			earliest=minf(earliest,fractions[0])
		print("NOZZLE BAKED BASIS CAST: ms=",(Time.get_ticks_usec()-start)/1000.," fraction=",earliest)
		var sweep_rows: Array=[];var total_points:=0
		for leaf: CollisionShape3D in joint._spigot_shapes:
			var unique: Dictionary={};var debug: Mesh=leaf.shape.get_debug_mesh()
			for surface in debug.get_surface_count():
				var arrays: Array=debug.surface_get_arrays(surface)
				for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:unique[point]=true
			var points:=PackedVector3Array(unique.keys());total_points+=points.size()
			sweep_rows.append({"points":points,"frame":leaf.global_transform})
		start=Time.get_ticks_usec();var swept_hit:=false
		for row: Dictionary in sweep_rows:
			var expanded: PackedVector3Array=row.points.duplicate();var delta: Vector3=row.frame.basis.inverse()*(joint.actor.global_basis*inward)
			for point: Vector3 in row.points:expanded.append(point+delta)
			var volume:=ConvexPolygonShape3D.new();volume.points=expanded;volume.margin=.00001
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=volume;query.transform=row.frame;query.margin=.00002;query.collision_mask=joint.FITTING_LAYER
			if not joint.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():swept_hit=true;break
		print("NOZZLE SWEPT VOLUME PROFILE: hull_vertices=",total_points," ms=",(Time.get_ticks_usec()-start)/1000.," hit=",swept_hit)
		var isolated:=RigidBody3D.new();isolated.freeze=true;isolated.collision_layer=0;isolated.collision_mask=1;add_child(isolated)
		for shape: ConvexPolygonShape3D in shapes:
			var leaf:=CollisionShape3D.new();leaf.shape=shape;isolated.add_child(leaf)
		await get_tree().physics_frame;await get_tree().physics_frame
		var isolated_query:=PhysicsTestMotionParameters3D.new();isolated_query.from=joint.body.global_transform;isolated_query.motion=joint.actor.global_basis*inward;isolated_query.margin=.00002;isolated_query.exclude_bodies=[joint.body.get_rid(),joint.actor._bodies.lever.get_rid()]
		var isolated_result:=PhysicsTestMotionResult3D.new();start=Time.get_ticks_usec()
		var isolated_hit: bool=PhysicsServer3D.body_test_motion(isolated.get_rid(),isolated_query,isolated_result)
		print("NOZZLE SPIGOT BODY PROFILE: shapes=",shapes.size()," ms=",(Time.get_ticks_usec()-start)/1000.," hit=",isolated_hit," travel=",isolated_result.get_travel()," normal=",isolated_result.get_collision_normal())
		isolated.free()
		var candidate: String=OS.get_environment("ORISON_NOZZLE_COLLISION_CANDIDATE")
		if not candidate.is_empty():
			var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(candidate))
			var faces:=PackedVector3Array()
			# Native Blender faces are CCW; Godot imported faces are CW.
			for tri in range(0,raw.indices.size(),3):
				for corner in [2,1,0]:
					var v: Array=raw.vertices[raw.indices[tri+corner]];faces.append(Vector3(v[0],v[1],v[2]))
			var collision: CollisionShape3D=joint.nut.get_child(0).get_child(0)
			var mesh:=ConcavePolygonShape3D.new();mesh.set_faces(faces);collision.shape=mesh
			await get_tree().physics_frame;await get_tree().physics_frame
			var query:=PhysicsTestMotionParameters3D.new();query.from=joint.body.global_transform;query.motion=joint.actor.global_basis*inward;query.margin=.00002;query.exclude_bodies=[joint.actor._bodies.lever.get_rid()]
			var result:=PhysicsTestMotionResult3D.new();start=Time.get_ticks_usec()
			var hit: bool=PhysicsServer3D.body_test_motion(joint.body.get_rid(),query,result)
			print("NOZZLE REDUCED BODY PROFILE: triangles=",faces.size()/3," ms=",(Time.get_ticks_usec()-start)/1000.," hit=",hit," travel=",result.get_travel())
			earliest=1.;start=Time.get_ticks_usec()
			for shape: ConvexPolygonShape3D in shapes:
				var cast:=PhysicsShapeQueryParameters3D.new();cast.shape=shape;cast.transform=joint.body.global_transform;cast.motion=joint.actor.global_basis*inward;cast.margin=.00002;cast.collision_mask=1;cast.exclude=[joint.body.get_rid(),joint.actor._bodies.lever.get_rid()]
				var fractions: PackedFloat32Array=joint.get_world_3d().direct_space_state.cast_motion(cast)
				earliest=minf(earliest,fractions[0])
			print("NOZZLE REDUCED CAST PROFILE: ms=",(Time.get_ticks_usec()-start)/1000.," fraction=",earliest)
	var initial: Vector3=joint.body.position
	joint._carry(initial+inward)
	proof=proof and is_instance_valid(joint._last_contact) and joint._last_contact in [joint.nut.get_child(0),joint.physical_nut,joint.seat.get_child(0)]
	proof=proof and joint.body.position.distance_to(initial)<=inward.length()+.0001
	print("NOZZLE INWARD RECEIVER COLLISION: ",proof," sweep_ms=",joint.last_sweep_ms," queries=",joint.receiver_queries," displacement=",joint.body.position-initial," hit=",joint._last_contact.get_path() if is_instance_valid(joint._last_contact) else "none")
	ok=ok and proof
	var timings: Array[float]=[]
	for phase: float in [0.,1.1,2.5]:
		for sideways: float in [-.0005,0.,.0005]:
			joint.clocking=phase;joint.spin=phase;joint.body.transform=joint.thread_pose(joint.stock.maximum_angle(),phase);joint._apply_visuals()
			await get_tree().physics_frame;await get_tree().physics_frame
			initial=joint.body.position
			var motion: Vector3=inward+joint.receiver.basis.z*sideways
			joint._carry(initial+motion);timings.append(joint.last_sweep_ms)
			var blocked: bool=is_instance_valid(joint._last_contact) and joint.body.position.distance_to(initial)<=motion.length()+.0001
			print("NOZZLE CONTACT MATRIX: phase=",phase," side=",sideways," ms=",joint.last_sweep_ms," queries=",joint.receiver_queries," bounded_hit=",blocked)
			ok=ok and blocked
	timings.sort();print("NOZZLE CONTACT P95 MS: ",timings[ceili(timings.size()*.95)-1])
	print("V2 FIRE NOZZLE PASSIVE SUPPORT: ","PASS" if ok else "FAIL"," ms=",(Time.get_ticks_usec()-started)/1000.)
	get_tree().quit(0 if ok else 1)
