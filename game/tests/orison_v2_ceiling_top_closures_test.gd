extends "res://tests/orison_v2_ventilation_fabric_test.gd"
## Actual uncovered ceiling tops, retained undersides and distinct floor bodies.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production world initializes")
	if world.player==null:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root
	var owner: Node3D=root.get_node("CeilingTopClosures")
	var depth: float=root.layout.dimensions.slab_thickness
	var native:=PackedVector3Array();var footprints: Array[AABB]=[];var parts:=0;var triangles:=0
	for draw: MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		check(draw.material_override==MatLib.get_mat("concrete"),"closure retains the existing mapped concrete")
		_check_planar_mapping(draw.mesh,true)
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		var bounds: AABB=pose*draw.mesh.get_aabb();footprints.append(bounds)
		check(maxf(bounds.size.x,bounds.size.z)<=4.00001,"new upper faces have bounded extents")
		native.append_array(pose*draw.mesh.get_faces())
	await get_tree().physics_frame;await get_tree().physics_frame
	check(parts==51 and triangles==374,"closure exports fifty-one source-owned uncovered partitions")
	for i in footprints.size():
		for j in range(i+1,footprints.size()):
			var a:=footprints[i];var b:=footprints[j]
			if absf(a.end.y-b.end.y)>.0001:continue
			var area:=maxf(0.,minf(a.end.x,b.end.x)-maxf(a.position.x,b.position.x))*maxf(0.,minf(a.end.z,b.end.z)-maxf(a.position.z,b.position.z))
			check(area<.00001,"new upper partitions have no duplicate source footprint")
	var excluded: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in owner.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	var original_ceilings:=PackedVector3Array();var original_floors:=PackedVector3Array()
	for room: Dictionary in root.layout.spaces:
		var holder:=root.get_node(str(room.id))
		for identity: String in ["Floor","Ceiling"]:
			var draw:=holder.get_node_or_null(identity) as MeshInstance3D
			if draw==null:continue
			var faces: PackedVector3Array=(root.global_transform.affine_inverse()*draw.global_transform)*draw.mesh.get_faces()
			if identity=="Ceiling":original_ceilings.append_array(faces)
			else:original_floors.append_array(faces)
	for platform: Dictionary in root.layout.platforms:
		var draw:=root.get_node(str(platform.id)) as MeshInstance3D
		original_floors.append_array((root.global_transform.affine_inverse()*draw.global_transform)*draw.mesh.get_faces())
	var overlaps:=0;var slab_pairs:=0
	var floor_shapes: Array[CollisionShape3D]=[]
	for room: Dictionary in root.layout.spaces:
		var body:=root.get_node_or_null(str(room.id)+"/Floor/Collision")
		if body!=null:
			for shape: CollisionShape3D in body.find_children("*","CollisionShape3D",true,false):floor_shapes.append(shape)
	for platform: Dictionary in root.layout.platforms:
		for shape: CollisionShape3D in root.get_node(str(platform.id)+"/Collision").find_children("*","CollisionShape3D",true,false):floor_shapes.append(shape)
	for bounds: AABB in footprints:
		var cap:=AABB(Vector3(bounds.position.x,bounds.end.y-depth,bounds.position.z),Vector3(bounds.size.x,depth,bounds.size.z))
		for shape_node: CollisionShape3D in floor_shapes:
			check(shape_node.shape is BoxShape3D,"retained floor collision uses its original box pieces")
			var size: Vector3=(shape_node.shape as BoxShape3D).size
			var actual: AABB=(root.global_transform.affine_inverse()*shape_node.global_transform)*AABB(-size*.5,size)
			var overlap:=cap.intersection(actual)
			if overlap.size.x>.00001 and overlap.size.y>.00001 and overlap.size.z>.00001:overlaps+=1
			slab_pairs+=1
	check(overlaps==0,"new slab bodies have no duplicate volume with any actual retained floor or landing shape")
	print("CEILING VOLUME OWNERSHIP: pairs=%d overlapping_volumes=%d" % [slab_pairs,overlaps])
	var contacts:=0;var reproduced:=0;var undersides:=0;var foreground:=0
	for bounds: AABB in footprints:
		for ux: float in [.1,.5,.9]:
			for uz: float in [.1,.5,.9]:
				var point:=Vector3(lerpf(bounds.position.x,bounds.end.x,ux),bounds.end.y,lerpf(bounds.position.z,bounds.end.z,uz))
				var ray:=point+Vector3.UP*.05
				var distance:=_mesh_distance(native,ray,Vector3.DOWN)
				check(is_finite(distance) and absf(distance-.05)<.00003,"actual native cap reaches its source upper plane")
				var old_distance:=_mesh_distance(original_floors,ray,Vector3.DOWN)
				check(not is_finite(old_distance) or absf(old_distance-.05)>.0001,"new top has no duplicate retained room-floor or landing top")
				var query:=PhysicsRayQueryParameters3D.create(root.to_global(ray),root.to_global(point-Vector3.UP*.3),1,[world.player.get_rid()])
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty() or hit.collider.get_parent()!=owner:foreground+=1;print("CEILING TRIAL FOREGROUND: ",point," ",str(root.get_path_to(hit.collider)) if not hit.is_empty() else "none")
				check(not hit.is_empty() and hit.collider.get_parent()==owner and root.to_local(hit.position).distance_to(point)<.00003,"new cap is the first matching actual physical upper surface")
				contacts+=1
				query.exclude=excluded;hit=world.get_world_3d().direct_space_state.intersect_ray(query)
				check(hit.is_empty() or absf(root.to_local(hit.position).y-point.y)>.0001,"excluding only the new cap reproduces the original physical upper gap")
				if hit.is_empty() or absf(root.to_local(hit.position).y-point.y)>.0001:reproduced+=1
				var below:=point-Vector3.UP*(depth+.05)
				var original_distance:=_mesh_distance(original_ceilings,below,Vector3.UP)
				check(is_finite(original_distance) and absf(original_distance-.05)<.00003,"retained ceiling owns the original underside")
				var new_distance:=_mesh_distance(native,below,Vector3.UP)
				check(not is_finite(new_distance) or absf(new_distance-.05)>.0001,"native addition has no duplicate underside")
				undersides+=1
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=65
	for view: Array in [["ground_closures",Vector3(0,5,-15),Vector3(0,3.2,-7)],
		["basement_top",Vector3(-5,3.3,13),Vector3(-5,0,6)],
		["west_light_slot",Vector3(-17,15,0),Vector3(-9,12.8,0)],
		["lobby_inside",Vector3(0,1.524,-8),Vector3(0,3,-6)],
		["rear_setback",Vector3(-7,1.524,14),Vector3(-7,3.5,10.2)]]:
		camera.global_position=root.to_global(view[1]);camera.look_at(root.to_global(view[2]))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
		world.player.camera.global_transform=camera.global_transform;world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0]))
	print("CEILING TOP CLOSURES: parts=%d triangles=%d contacts=%d reproduced=%d retained_undersides=%d foreground=%d checks=%d failures=%d" % [parts,triangles,contacts,reproduced,undersides,foreground,checks,failures.size()])
	for failure: String in failures:print("CEILING TOP CLOSURE FAIL: ",failure)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _check_planar_mapping(mesh: Mesh, check_derivatives: bool=false) -> void:
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
		check(vertices.size()>=4 and normals.size()==vertices.size() and uv.size()==vertices.size() and tangents.size()==vertices.size()*4,"planar quad has active UV, normal and tangent on every imported vertex")
		var valid:=true
		for i in vertices.size():
			valid=valid and vertices[i].is_finite() and uv[i].is_finite() and absf(normals[i].length()-1)<.001
			if tangents.size()==vertices.size()*4:
				var tangent:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				valid=valid and tangent.is_finite() and absf(tangent.length()-1)<.001 and absf(tangent.dot(normals[i]))<.001 and absf(absf(tangents[i*4+3])-1)<.001
		check(valid,"finite unit normals and orthogonal tangent handedness")
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		check(indices.size()>=6 and indices.size()%3==0,"planar surface has complete native indexed triangles")
		var mapped:=true
		var widest:=0.0
		var excess:=0.0
		var derivatives:=true
		for triangle in range(0,indices.size(),3):
			if check_derivatives:
				var a:=indices[triangle]
				var b:=indices[triangle+1]
				var c:=indices[triangle+2]
				var first:=vertices[b]-vertices[a]
				var second:=vertices[c]-vertices[a]
				var uv_first:=uv[b]-uv[a]
				var uv_second:=uv[c]-uv[a]
				var determinant:=uv_first.x*uv_second.y-uv_second.x*uv_first.y
				derivatives=derivatives and absf(determinant)>1e-12
				if absf(determinant)>1e-12:
					var expected: Vector3=(first*uv_second.y-second*uv_first.y)/determinant
					var bitangent: Vector3=(second*uv_first.x-first*uv_second.x)/determinant
					for index: int in [a,b,c]:
						var projected: Vector3=(expected-normals[index]*expected.dot(normals[index])).normalized()
						var actual:=Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
						derivatives=derivatives and projected.dot(actual)>.999
						derivatives=derivatives and normals[index].cross(actual).dot(bitangent)*tangents[index*4+3]>0
			for edge in 3:
				var a:=indices[triangle+edge]
				var b:=indices[triangle+(edge+1)%3]
				var length:=vertices[a].distance_to(vertices[b])
				var texture:=uv[a].distance_to(uv[b])
				mapped=mapped and texture<=length+.00005
				excess=maxf(excess,texture-length)
				if length>.01: widest=maxf(widest,texture/length)
		check(mapped and absf(widest-1)<.005,"planar mapping retains one texture metre per model metre")
		if check_derivatives: check(derivatives,"tangent direction and handedness match actual imported UV derivatives")
		print("CEILING MAPPING: mesh=",mesh.resource_name," valid_basis=",valid," max_uv_excess=",excess," widest=",widest," vertices=",vertices.size()," derivatives=",derivatives)
