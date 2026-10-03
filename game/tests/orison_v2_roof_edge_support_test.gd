extends "res://tests/orison_v2_ventilation_fabric_test.gd"
## Scoped slab-rim/guard bearing inspection; foundation and whole shell stay open.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production world initializes with the source roof rim")
	if world.player==null:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root;var owner: Node3D=root.get_node("RoofEdgeSupport")
	var native:=PackedVector3Array();var bodies: Array[RID]=[world.player.get_rid()]
	var triangles:=0;var parts:=0
	for draw: MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		check(draw.mesh is ArrayMesh,"rim uses actual native triangles")
		check(draw.material_override==MatLib.get_mat("concrete"),"rim retains the existing mapped concrete finish")
		var extent: Vector3=draw.mesh.get_aabb().size
		check(maxf(extent.x,maxf(extent.y,extent.z))<=4.00001,"native pieces have bounded culling extents")
		_check_mapping(draw.mesh,true)
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		native.append_array(pose*draw.mesh.get_faces())
	for body: CollisionObject3D in owner.find_children("*","CollisionObject3D",true,false):bodies.append(body.get_rid())
	check(parts==28 and triangles==240,"four strips export once without caps at their culling divisions")
	var rim_contacts:=0;var bearings:=0;var reproduced:=0
	for side: String in ["south","north","west","east"]:
		var parapet:=root.get_node("ROOF_PARAPET_"+side.to_upper())
		var exclusion: Array[RID]=[world.player.get_rid()]
		for body: CollisionObject3D in parapet.find_children("*","CollisionObject3D",true,false):exclusion.append(body.get_rid())
		for along: float in [-10.,0.,10.]:
			var a:=Vector3(along,19.1,-12.75);var direction:=Vector3.BACK
			var expected:=Vector3(along,19.1,-12.63);var seat:=Vector3(along,19.2,-12.45)
			var old:=Vector3(along,19.1,-12.35)
			if side=="north":
				a=Vector3(along,19.1,12.05);direction=Vector3.FORWARD
				expected=Vector3(along,19.1,11.93);seat=Vector3(along,19.2,11.75);old=Vector3(along,19.1,11.65)
			if side=="west":
				a=Vector3(-16.05,19.1,along);direction=Vector3.RIGHT
				expected=Vector3(-15.93,19.1,along);seat=Vector3(-15.75,19.2,along);old=Vector3(-15.65,19.1,along)
			if side=="east":
				a=Vector3(16.05,19.1,along);direction=Vector3.LEFT
				expected=Vector3(15.93,19.1,along);seat=Vector3(15.75,19.2,along);old=Vector3(15.65,19.1,along)
			var distance:=_mesh_distance(native,a,direction)
			check(is_finite(distance) and absf(distance-a.distance_to(expected))<.00002,"native rim closes the recessed slab band at the masonry envelope")
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(a),root.to_global(a+direction*.55),1,[world.player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider.get_parent()==owner,"visible rim is the first physical outer edge")
			if not hit.is_empty():check(root.to_local(hit.position).distance_to(expected)<.00002,"visible and physical rim share the source datum")
			rim_contacts+=1
			query=PhysicsRayQueryParameters3D.create(root.to_global(a),root.to_global(a+direction*.55),1,bodies)
			hit=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and root.to_local(hit.position).distance_to(old)<.00002,"excluding only the new rim reproduces the former recessed slab edge")
			reproduced+=1
			query=PhysicsRayQueryParameters3D.create(root.to_global(seat+Vector3.UP*.02),root.to_global(seat-Vector3.UP*.08),1,exclusion)
			hit=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider.get_parent()==owner,"retained parapet outer base now contacts the physical slab course")
			if not hit.is_empty():check(root.to_local(hit.position).distance_to(seat)<.00002,"parapet bearing remains at the authored roof datum")
			bearings+=1
	# Shared footprint boundaries have no horizontal overlap with existing decks.
	for draw: MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
		var bound: AABB=(root.global_transform.affine_inverse()*draw.global_transform)*draw.mesh.get_aabb()
		for room: Dictionary in root.layout.spaces:
			if not str(room.id).begins_with("ROOF_DECK_"):continue
			var area:=maxf(0.,minf(bound.end.x,room.rect[2])-maxf(bound.position.x,room.rect[0]))*maxf(0.,minf(bound.end.z,room.rect[3])-maxf(bound.position.z,room.rect[1]))
			check(area<.00001,"existing deck and added rim have distinct surface footprints")
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=65
	for view: Array in [["west_edge",Vector3(-17.2,19.05,-5),Vector3(-15.65,19.1,-5)],
		["north_edge",Vector3(-6,19.05,13.2),Vector3(-6,19.1,11.65)],
		["roof_guard",Vector3(-15.1,20.724,-4),Vector3(-15.65,19.45,-5)]]:
		camera.global_position=root.to_global(view[1]);camera.look_at(root.to_global(view[2]))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
		world.player.camera.global_transform=camera.global_transform;world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0])
	print("ROOF EDGE SUPPORT: parts=%d triangles=%d rim_contacts=%d parapet_bearings=%d reproduced_before=%d checks=%d failures=%d" % [parts,triangles,rim_contacts,bearings,reproduced,checks,failures.size()])
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
