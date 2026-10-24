extends Node3D
const Hulls:=preload("res://scripts/props/native_convex_components.gd")
var failures: Array[String]=[]
var records: Array=[]
func _ready() -> void:_run.call_deferred()
func check(passed: bool,label: String) -> void:
	print("NATIVE CONVEX CHECK: ",label," = ",passed)
	if not passed:failures.append(label)
func _body(shapes: Array[Shape3D],layer: int) -> StaticBody3D:
	var body:=StaticBody3D.new();body.collision_layer=layer;body.collision_mask=0
	for stock: Shape3D in shapes:
		var shape:=CollisionShape3D.new();shape.shape=stock;body.add_child(shape)
	add_child(body);return body
func _native_hit(faces: PackedVector3Array,start: Vector3,end: Vector3) -> Dictionary:
	# Independent native triangle truth in millimetres avoids the engine's
	# tiny-triangle ray determinant threshold, as in existing stock_ray benches.
	var origin:=start*1000.;var direction: Vector3=(end-start).normalized()
	var length: float=start.distance_to(end)*1000.;var nearest:=INF;var at:=Vector3.ZERO
	for index in range(0,faces.size(),3):
		var hit: Variant=Geometry3D.ray_intersects_triangle(origin,direction,faces[index]*1000.,faces[index+1]*1000.,faces[index+2]*1000.)
		if hit is Vector3:
			var distance: float=origin.distance_to(hit)
			if distance<=length and distance<nearest:nearest=distance;at=hit/1000.
	return {} if nearest==INF else {"position":at}
func _run() -> void:
	var skin:=preload("res://scripts/building/orison_v2_fire_cabinet_skin.gd").new()
	if not skin.load_stock():get_tree().quit(1);return
	for identity: String in ["SafetyWire","F069"]:
		var mesh: Mesh=skin.meshes[identity]
		var candidates: Array[Shape3D]=Hulls.build(mesh)
		check(candidates.size()==(70 if identity=="SafetyWire" else 1),identity+" every original closed convex shell is retained separately")
		if candidates.is_empty():continue
		var original_faces:=mesh.get_faces()
		for shape: ConvexPolygonShape3D in candidates:
			for point: Vector3 in shape.points:
				if point not in original_faces:check(false,"convex point must be an exact original native vertex")
		var source: StaticBody3D=_body([mesh.create_trimesh_shape()],1)
		var candidate: StaticBody3D=_body(candidates,2)
		await get_tree().physics_frame;await get_tree().physics_frame
		var bounds:=mesh.get_aabb();var mismatches:=0;var max_error:=0.;var queries:=0;var engine_mismatches:=0
		for side: float in [-1.,1.]:
			for x in 20:
				for y in 20:
					var at:=Vector3(lerpf(bounds.position.x,bounds.end.x,(x+.5)/20.),lerpf(bounds.position.y,bounds.end.y,(y+.5)/20.),bounds.get_center().z)
					var query:=PhysicsRayQueryParameters3D.create(at+Vector3.BACK*1.05*side,at-Vector3.BACK*1.05*side,1)
					var before:=get_world_3d().direct_space_state.intersect_ray(query);query.collision_mask=2
					var after:=get_world_3d().direct_space_state.intersect_ray(query);queries+=1
					if before.is_empty()!=after.is_empty():engine_mismatches+=1
					var truth: Dictionary=_native_hit(original_faces,query.from,query.to)
					if truth.is_empty()!=after.is_empty():mismatches+=1
					elif not truth.is_empty():max_error=maxf(max_error,truth.position.distance_to(after.position))
		check(mismatches==0 and max_error<.000001,identity+" 800 interaction-length native-side ray/gap controls preserve original hit positions within1um")
		var capsule:=CapsuleShape3D.new();capsule.radius=PlayerController.BODY_RADIUS;capsule.height=PlayerController.STANDING_HEIGHT
		var source_player:=CharacterBody3D.new();source_player.collision_layer=0;source_player.collision_mask=1;add_child(source_player)
		var target_player:=CharacterBody3D.new();target_player.collision_layer=0;target_player.collision_mask=2;add_child(target_player)
		for body: CharacterBody3D in [source_player,target_player]:
			var collision:=CollisionShape3D.new();collision.shape=capsule;body.add_child(collision)
		await get_tree().physics_frame;await get_tree().physics_frame
		var motions: Array=[]
		for side: float in [-1.,1.]:
			for x: float in [.1,.5,.9]:
				var at:=Vector3(lerpf(bounds.position.x,bounds.end.x,x),bounds.get_center().y-.45,bounds.get_center().z+side*.40)
				var params:=PhysicsTestMotionParameters3D.new();params.from=Transform3D(Basis.IDENTITY,at);params.motion=Vector3(0,0,-side*.2);params.margin=.001
				var before:=PhysicsTestMotionResult3D.new();var after:=PhysicsTestMotionResult3D.new()
				var start:=Time.get_ticks_usec();var old_blocked:=PhysicsServer3D.body_test_motion(source_player.get_rid(),params,before);var original_us:=Time.get_ticks_usec()-start
				start=Time.get_ticks_usec();var new_blocked:=PhysicsServer3D.body_test_motion(target_player.get_rid(),params,after);var candidate_us:=Time.get_ticks_usec()-start
				var error: float=before.get_travel().distance_to(after.get_travel())
				check(old_blocked==new_blocked and error<.0001,identity+" actual player capsule cast retains contact/travel within100um")
				motions.append({"blocked":old_blocked,"travel_error_m":error,"original_us":original_us,"candidate_us":candidate_us})
		records.append({"id":identity,"shells":candidates.size(),"ray_queries":queries,"ray_mismatches":mismatches,"original_engine_ray_mismatches":engine_mismatches,"max_ray_error_m":max_error,"capsule_casts":motions})
		source_player.free();target_player.free();source.free();candidate.free()
	check(Hulls.build(skin.meshes.F065).is_empty(),"concave native frame refuses replacement rather than filling its opening")
	var open_mesh:=ArrayMesh.new();var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]);open_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	check(Hulls.build(open_mesh).is_empty(),"open native surface refuses a solid replacement")
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory);FileAccess.open(directory.path_join("contacts.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Imported native closed-shell half-space certificate plus physics ray/gap and actual player-capsule comparisons; not appearance or whole-world qualification.","records":records,"failures":failures},"\t"))
	print("V2 NATIVE CONVEX CONTACT: failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
