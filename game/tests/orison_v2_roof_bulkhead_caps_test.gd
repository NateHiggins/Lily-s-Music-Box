extends "res://tests/orison_v2_ventilation_fabric_test.gd"
## Actual upper closures, retained underside owners and wall bearing contacts.
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
	var root: Node3D=world.adapter.root;var owner: Node3D=root.get_node("RoofBulkheadCaps")
	var native:=PackedVector3Array();var cap_bodies: Array[RID]=[world.player.get_rid()]
	# The fitted weather cover now owns the first exterior service contact.
	# Exclude only its bodies when inspecting the original cap interface datum;
	# its independent suite tests first-contact physics without these exclusions.
	var weather_bodies: Array[RID]=[world.player.get_rid()]
	for weather_owner: String in ["RoofServiceWeathering","RoofPublicWeathering"]:
		for body: CollisionObject3D in root.get_node(weather_owner).find_children("*","CollisionObject3D",true,false):weather_bodies.append(body.get_rid())
	cap_bodies.append_array(weather_bodies.slice(1))
	var parts:=0;var triangles:=0;var footprints: Array[AABB]=[]
	for draw: MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		check(draw.mesh is ArrayMesh,"roof closure exports native triangles")
		check(draw.material_override==MatLib.get_mat("concrete"),"upper closure uses the existing mapped concrete")
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		var bounds: AABB=pose*draw.mesh.get_aabb()
		check(maxf(bounds.size.x,bounds.size.z)<=4.00001,"roof closure pieces have bounded culling extents")
		_check_cap_mapping(draw.mesh,true)
		native.append_array(pose*draw.mesh.get_faces());footprints.append(bounds)
	for body: CollisionObject3D in owner.find_children("*","CollisionObject3D",true,false):cap_bodies.append(body.get_rid())
	check(parts==10 and triangles==100,"two source bulkheads use ten bounded pieces around the true court aperture")
	for i in footprints.size():
		for j in range(i+1,footprints.size()):
			var a:=footprints[i];var b:=footprints[j]
			var area:=maxf(0.,minf(a.end.x,b.end.x)-maxf(a.position.x,b.position.x))*maxf(0.,minf(a.end.z,b.end.z)-maxf(a.position.z,b.position.z))
			check(area<.00001,"cap pieces have no duplicate horizontal footprint")
	var contacts:=0;var bearings:=0;var before_missing:=0;var underside_samples:=0
	var wall_half: float=root.layout.dimensions.partition_wall*.5
	var depth: float=root.layout.dimensions.slab_thickness
	for identity: String in ["ROOF_PUBLIC_CORE","ROOF_SERVICE_CORE"]:
		var room: Dictionary={}
		for record: Dictionary in root.layout.spaces:
			if str(record.id)==identity:room=record;break
		check(not room.is_empty(),"closure retains its authored room owner")
		if room.is_empty():continue
		var y: float=root.level_y[str(room.level)]+root.layout.dimensions.clear_height
		var r: Array=room.rect;var ceiling:=root.get_node(identity+"/Ceiling") as MeshInstance3D
		var original: PackedVector3Array=(root.global_transform.affine_inverse()*ceiling.global_transform)*ceiling.mesh.get_faces()
		check(not ceiling.has_node("Collision"),"retained interior ceiling has no duplicate new body")
		check(ceiling.mesh.get_surface_count()==1 and ceiling.get_meta("v2_material_key")=="trim","retained interior ceiling finish stays with its original owner")
		for ux: float in [.1,.5,.9]:
			for uz: float in [.1,.5,.9]:
				var point:=Vector3(lerpf(r[0],r[2],ux),y+depth,lerpf(r[1],r[3],uz))
				var ray:=point+Vector3.UP*.05
				var native_distance:=_mesh_distance(native,ray,Vector3.DOWN)
				check(is_finite(native_distance) and absf(native_distance-.05)<.00002,"actual native closure reaches the authored slab top")
				var old_distance:=_mesh_distance(original,ray,Vector3.DOWN)
				check(not is_finite(old_distance) or absf(old_distance-.05)>.1,"original ceiling alone reproduces the absent upper slab face")
				var query:=PhysicsRayQueryParameters3D.create(root.to_global(ray),root.to_global(point-Vector3.UP*.3),1,weather_bodies)
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty() and hit.collider.get_parent()==owner and root.to_local(hit.position).distance_to(point)<.00002,"original upper closure matches its physical interface beneath the weather cover")
				contacts+=1
				query.exclude=cap_bodies;hit=world.get_world_3d().direct_space_state.intersect_ray(query)
				check(hit.is_empty() or absf(root.to_local(hit.position).y-point.y)>.1,"excluding cap and its weather cover reproduces the original physical upper closure gap")
				before_missing+=1
				var under:=Vector3(point.x,y-.05,point.z)
				var retained_distance:=_mesh_distance(original,under,Vector3.UP)
				var added_distance:=_mesh_distance(native,under,Vector3.UP)
				check(is_finite(retained_distance) and absf(retained_distance-.05)<.00002,"original interior underside remains at the source datum")
				check(not is_finite(added_distance) or absf(added_distance-.05)>.1,"new native caps add no duplicate interior underside")
				underside_samples+=1
		for side: String in ["south","north","west","east"]:
			for along: float in [.1,.5,.9]:
				var seat:=Vector3(lerpf(r[0],r[2],along),y,r[1]-wall_half*.6)
				if side=="north":seat.z=r[3]+wall_half*.6
				if side=="west":seat=Vector3(r[0]-wall_half*.6,y,lerpf(r[1],r[3],along))
				if side=="east":seat=Vector3(r[2]+wall_half*.6,y,lerpf(r[1],r[3],along))
				var query:=PhysicsRayQueryParameters3D.create(root.to_global(seat+Vector3.UP*.02),root.to_global(seat-Vector3.UP*.08),1,cap_bodies)
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty() and str(root.get_path_to(hit.collider)).begins_with(identity+"/Wall") and root.to_local(hit.position).distance_to(seat)<.00002,"cap underside meets the retained outer half of the authored wall")
				bearings+=1
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=65
	for view: Array in [["roof_overview",Vector3(0,27,-18),Vector3(0,19.2,0)],
		["public_cap",Vector3(-3.8,24.3,-5.2),Vector3(1.6,22.4,0)],
		["service_cap",Vector3(14.4,24.3,11.4),Vector3(11.35,22.4,5.25)],
		["public_inside",Vector3(-1.35,20.724,0),Vector3(1.5,22.2,0)],
		["service_inside",Vector3(10.3,20.724,3),Vector3(11.35,22.2,6)]]:
		camera.global_position=root.to_global(view[1]);camera.look_at(root.to_global(view[2]))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
		world.player.camera.global_transform=camera.global_transform;world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0]))
	print("ROOF BULKHEAD CAPS: parts=%d triangles=%d upper_contacts=%d wall_bearings=%d reproduced_gaps=%d retained_undersides=%d checks=%d failures=%d" % [parts,triangles,contacts,bearings,before_missing,underside_samples,checks,failures.size()])
	for failure: String in failures:print("ROOF BULKHEAD CAP FAIL: ",failure)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

# A source partition may contain only its upper quad and one real aperture
# edge. Inspect complete indexed native triangles rather than requiring the
# closed-duct helper's nine-vertex minimum. All UV/basis/derivative checks stay.
func _check_cap_mapping(mesh: Mesh, check_derivatives: bool=false) -> void:
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
		var bad_derivatives:=0
		var min_determinant:=INF
		var worst_dot:=1.0
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
				min_determinant=minf(min_determinant,absf(determinant))
				derivatives=derivatives and absf(determinant)>1e-12
				if absf(determinant)>1e-12:
					var expected: Vector3=(first*uv_second.y-second*uv_first.y)/determinant
					var bitangent: Vector3=(second*uv_first.x-first*uv_second.x)/determinant
					for index: int in [a,b,c]:
						var projected: Vector3=(expected-normals[index]*expected.dot(normals[index])).normalized()
						var actual:=Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
						worst_dot=minf(worst_dot,projected.dot(actual))
						if projected.dot(actual)<=.999 or normals[index].cross(actual).dot(bitangent)*tangents[index*4+3]<=0:
							bad_derivatives+=1
							if bad_derivatives<4:print("UV DERIVATIVE DIAGNOSTIC: ",mesh.resource_name," tri=",triangle," n=",normals[index]," actual=",actual," expected=",projected," bitangent=",bitangent," determinant=",determinant)
						derivatives=derivatives and projected.dot(actual)>.999
						derivatives=derivatives and normals[index].cross(actual).dot(bitangent)*tangents[index*4+3]>0
			for edge in 3:
				var a:=indices[triangle+edge]
				var b:=indices[triangle+(edge+1)%3]
				var length:=vertices[a].distance_to(vertices[b])
				var texture:=uv[a].distance_to(uv[b])
				mapped=mapped and texture<=length+.00005
				excess=maxf(excess,texture-length)
				if length>.00005: widest=maxf(widest,texture/length)
		check(mapped and absf(widest-1)<.005,"planar mapping retains one texture metre per model metre")
		if check_derivatives: check(derivatives,"tangent direction and handedness match actual imported UV derivatives")
		print("CAP MAPPING: mesh=",mesh.resource_name," valid_basis=",valid," max_uv_excess=",excess," widest=",widest," vertices=",vertices.size()," derivatives=",derivatives," bad_derivatives=",bad_derivatives," min_determinant=",min_determinant," worst_dot=",worst_dot)
