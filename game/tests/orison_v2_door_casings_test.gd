extends "res://tests/orison_v2_floor_surface_test.gd"
## Installed joinery bounds, wall support, and rendered material inspection.
## Door operation is covered by the existing apartment route suite.
func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Casing inspection requires a windowed renderer for MultiMesh bounds")
		get_tree().quit(2)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if world.player==null:
		check(false,"production world initialized")
		world.free(); get_tree().quit(1); return
	world.player.set_physics_process(false)
	for child in world.adapter.root.get_children():
		if child is OrisonV2ReadabilityCues:
			check(not child.show_portal_masses,"production disables duplicate debug portal masses")
			for portal: Node in child.get_children():
				if portal.get_class()=="Node3D":
					check(portal.get_child_count()==1 and portal.get_child(0) is Label3D,"portal retains its label without overlapping debug boxes")
	for child in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	var openings := 0
	var service_openings := 0
	var fasteners := 0
	var service_detail: Node3D
	var contacts := 0
	var capture_ids: Array[String] = []
	var captured_types: Array[String] = []
	var half_depth := float(world.layout.dimensions.partition_wall)*.5
	var profile_source := (load("res://assets/props/millwork_profile.glb") as PackedScene).instantiate()
	var expected_service_mesh := (profile_source.find_child("ServiceCasing",true,false) as MeshInstance3D).mesh
	var expected_domestic_mesh := (profile_source.find_child("DoorCasing",true,false) as MeshInstance3D).mesh
	profile_source.free()
	for record: Dictionary in world.layout.doors:
		var anchor := world.adapter.resolve(str(record.id)) as Node3D
		if anchor==null: continue
		var leaf := anchor.get_node_or_null(str(record.id)+"_Leaf") as DoorProp
		if leaf==null or leaf.door_kind not in ["apartment_entry","apartment_interior","service"]: continue
		var service := leaf.door_kind=="service"
		if service:
			service_openings+=1
			service_detail = anchor
		var category := str(record.level)+":"+leaf.door_kind
		if capture_ids.size()<4 and category not in captured_types:
			capture_ids.append(str(record.id)); captured_types.append(category)
		openings+=1
		var casing := anchor.get_node_or_null("DoorCasings") as MultiMeshInstance3D
		var lining := anchor.get_node_or_null("DoorLinings") as MultiMeshInstance3D
		check(casing!=null and lining!=null,str(record.id)+" has its molded surround")
		if casing==null or lining==null: continue
		check(casing.multimesh.instance_count==6 and lining.multimesh.instance_count==3,"two-sided casing and three reveal liners")
		check(casing.multimesh.mesh is ArrayMesh and casing.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()>8,"Blender section is imported")
		check(casing.get_child_count()==0 and lining.get_child_count()==0,"joinery adds no collision owners")
		check(leaf.get_node("HingedLeaf") is AnimatableBody3D,"existing moving collision owner retained")
		check(casing.multimesh.mesh==(expected_service_mesh if service else expected_domestic_mesh),"opening uses the correct imported Blender section")
		if service:
			var screws := anchor.get_node_or_null("FrameFasteners") as MultiMeshInstance3D
			check(screws!=null,"service frame retains visible mechanical fixings")
			if screws!=null:
				check(screws.multimesh.instance_count==16,"eight screws on each service frame face")
				check(screws.multimesh.mesh is ArrayMesh,"fasteners use the Blender hardware mesh")
				for screw_index in screws.multimesh.instance_count:
					var screw := screws.multimesh.get_instance_transform(screw_index)
					var screw_bounds: AABB = screw*screws.multimesh.mesh.get_aabb()
					check(screw.basis.get_scale().is_equal_approx(Vector3.ONE),"hardware retains real dimensions on differently sized openings")
					var side := signf(screw.origin.z)
					var back: float = screw_bounds.position.z if side>0 else -screw_bounds.end.z
					check(absf(back-half_depth-.018)<.0001,"washer back seats on the metal frame face")
					var on_face := false
					for face_index in casing.multimesh.instance_count:
						var face: AABB = casing.multimesh.get_instance_transform(face_index)*casing.multimesh.mesh.get_aabb()
						if face.grow(.0002).has_point(Vector3(screw.origin.x,screw.origin.y,side*(half_depth+.018))): on_face=true
					check(on_face,"each screw has a frame behind it")
					fasteners+=1
		for index in 6:
			var transform := casing.multimesh.get_instance_transform(index)
			var bounds: AABB = transform*casing.multimesh.mesh.get_aabb()
			for room_id: String in record.connects:
				var room := world.adapter.resolve(room_id) as Node3D
				if room==null: continue
				for batch_name in ["HistoricMillwork","PublicWainscot","PublicWainscotFrames"]:
					var trim := room.get_node_or_null(batch_name) as MultiMeshInstance3D
					if trim==null: continue
					for strip in trim.multimesh.instance_count:
						var relative := anchor.global_transform.affine_inverse()*trim.global_transform*trim.multimesh.get_instance_transform(strip)
						var trim_bounds: AABB = relative*trim.multimesh.mesh.get_aabb()
						var overlap := bounds.intersection(trim_bounds).size
						check(minf(overlap.x,minf(overlap.y,overlap.z))<.0001,str(record.id)+" casing is clear of room trim: "+room_id+"/"+batch_name+" casing="+str(bounds)+" trim="+str(trim_bounds))
			var part: String = ["FrameLeft","FrameRight","FrameHead"][index/2]
			var frame := anchor.get_node(part) as MeshInstance3D
			check(not frame.visible,"original rectangular frame is not double-rendered")
			check(casing.material_override==(MatLib.get_mat("cast_iron",Color(.24,.25,.23)) if service else frame.get_active_material(0)),"architectural material authority retained")
			check(bounds.position.y>=-.0001,"casing never extends below the finished floor")
			if part=="FrameHead":
				check(bounds.position.y>=float(record.height)-.0001,"head stays above the clear opening")
			else:
				check(bounds.end.x<=-float(record.width)*.5+.0001 or bounds.position.x>=float(record.width)*.5-.0001,"uprights retain full aperture width")
			var side := signf(transform.origin.z)
			check(transform.basis.z.normalized().dot(Vector3.BACK*side)>.999,"molded face points away from wall")
			check(absf(absf(transform.origin.z)-half_depth-.009)<.0001,"casing back touches the partition face")
			# A real ray independently checks that the built collision wall is
			# behind each jamb/head, on both faces of the semantic aperture.
			var at := frame.position
			var ray := PhysicsRayQueryParameters3D.create(anchor.to_global(at+Vector3.BACK*side*(half_depth+.04)),anchor.to_global(at+Vector3.BACK*side*(half_depth-.01)),1,[world.player.get_rid()])
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and absf(anchor.to_local(hit.position).z-side*half_depth)<.003,str(record.id)+" "+part+" casing has actual wall backing")
			contacts+=1
	check(openings>=40,"casing batch covers occupied homes")
	check(service_openings>=6 and fasteners==service_openings*16,"service entrances receive complete metal surrounds")
	check(capture_ids.size()==4,"detail stations cover multiple floors and door types")
	for identity in capture_ids:
		var anchor := world.adapter.resolve(identity) as Node3D
		if anchor==null or not anchor.has_node("DoorCasings"): continue
		var leaf := anchor.get_node(identity+"_Leaf") as DoorProp
		var stance := Vector3.ZERO
		var found := false
		for distance in [1.9,1.2,.8]:
			for side in [-1.0,1.0]:
				var eye := anchor.to_global(Vector3(0,1.65,side*distance))
				var ray := PhysicsRayQueryParameters3D.create(eye,anchor.to_global(Vector3(0,1.2,0)),1,[world.player.get_rid()])
				ray.hit_from_inside = true
				var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty() and leaf.is_ancestor_of(hit.collider):
					stance = Vector3(0,.05,side*distance); found = true; break
			if found: break
		check(found,identity+" has a clear rendered doorway view")
		if not found: continue
		world.player.global_position = anchor.to_global(stance)
		world.player.face_world_point(anchor.to_global(Vector3(0,1.2,0)))
		world.player.camera.make_current()
		await shot(identity)
	# Neutral close-up of an installed head/upright joint, separate from the
	# carried-lamp room views; source geometry is never substituted for runtime.
	var detail := world.adapter.resolve(capture_ids[0]) as Node3D
	var detail_leaf := detail.get_node(capture_ids[0]+"_Leaf") as DoorProp
	world.player.set_lamp_enabled(false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = detail.to_global(Vector3(detail_leaf.width*.33,detail_leaf.height+.07,-.8))
	camera.look_at(detail.to_global(Vector3(detail_leaf.width*.5+.025,detail_leaf.height,-half_depth)))
	camera.make_current()
	var fill := OmniLight3D.new()
	world.add_child(fill)
	fill.global_position = camera.global_position
	fill.light_energy = .35
	fill.omni_range = 3
	await shot("casing_joint_detail")
	if service_detail!=null:
		var screws := service_detail.get_node("FrameFasteners") as MultiMeshInstance3D
		var at := service_detail.to_global(screws.multimesh.get_instance_transform(2).origin)
		camera.global_position = at+service_detail.global_basis*Vector3(.03,.025,-.15)
		camera.look_at(at)
		fill.global_position = camera.global_position
		fill.light_energy = .03
		await shot("service_fastener_detail")
	print("DOOR CASINGS: openings=%d wall_contacts=%d failures=%d" % [openings,contacts,failures.size()])
	print("SERVICE FRAMES: openings=%d fasteners=%d failures=%d" % [service_openings,fasteners,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
