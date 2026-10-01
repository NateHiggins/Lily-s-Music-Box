extends "res://tests/orison_v2_lift_joinery_test.gd"
## Imported fitting triangles meet existing duct bodies and rendered ceilings.
## Static inspection; continuous roof and service access use their own routes.

var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	super.check(ok, message)

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(world.player != null and not world.startup_failed,"production world initializes with static supports")
	if world.player == null:
		world.free()
		get_tree().quit(1)
		return
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false): layer.hide()
	var root: Node3D = world.adapter.root
	var ceiling_faces: Array[PackedVector3Array] = []
	for ceiling: MeshInstance3D in root.find_children("Ceiling","MeshInstance3D",true,false):
		var pose := root.global_transform.affine_inverse() * ceiling.global_transform
		ceiling_faces.append(pose * ceiling.mesh.get_faces())
	var total := 0
	var batches := 0
	var vertices := 0
	var roster := {}
	var ducts := root.get_node("VentilationDucts")
	for stack: StaticBody3D in ducts.get_children():
		var metal := stack.get_node_or_null("Hangers_metal") as MultiMeshInstance3D
		var iron := stack.get_node_or_null("Hangers_cast_iron") as MultiMeshInstance3D
		check(metal != null and iron != null,"both imported fitting partitions on " + str(stack.name))
		if metal == null or iron == null: continue
		for draw in [metal,iron]:
			check(draw.get_child_count()==0,"passive fittings introduce no duplicate collision owner")
			check(draw.material_override==MatLib.get_mat(str(draw.name).trim_prefix("Hangers_")),"catalogue material remains bound")
			check(draw.multimesh.mesh is ArrayMesh,"actual Blender fitting mesh imported")
			for surface in draw.multimesh.mesh.get_surface_count():
				var arrays: Array = draw.multimesh.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				var tangent: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
				check(points.size()>8 and normals.size()==points.size() and uv.size()==points.size() and tangent.size()==points.size()*4,"active UV, normals and tangent basis cover every imported vertex")
				var finite := true
				for i in points.size():
					finite = finite and points[i].is_finite() and normals[i].is_finite() and uv[i].is_finite() and absf(normals[i].length()-1)<.001
					if tangent.size()==points.size()*4:
						var direction := Vector3(tangent[i*4],tangent[i*4+1],tangent[i*4+2])
						finite = finite and direction.is_finite() and absf(direction.length()-1)<.001 and absf(direction.dot(normals[i]))<.001 and absf(absf(tangent[i*4+3])-1)<.001
				check(finite,"finite unit normals, orthogonal tangents and handedness")
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var metres := true
				var widest := 0.0
				for triangle in range(0,indices.size(),3):
					for edge in 3:
						var a := indices[triangle+edge]
						var b := indices[triangle+(edge+1)%3]
						var length := points[a].distance_to(points[b])
						var mapped := uv[a].distance_to(uv[b])
						metres = metres and mapped<=length+.00001
						if length>.03: widest = maxf(widest,mapped/length)
				check(metres and absf(widest-1)<.001,"active planar UVs retain one texture metre per model metre")
				vertices += points.size()
			batches += 1
		var faces := metal.multimesh.mesh.get_faces()
		var bearing := _mesh_distance(faces,Vector3(0,-.08,0),Vector3.DOWN)
		check(is_finite(bearing) and absf(bearing-.01)<.0001,"imported bearing flange touches 180 mm duct underside")
		for side in [-1.0,1.0]:
			var top := _mesh_distance(faces,Vector3(.02,.4,.128*side),Vector3.DOWN)
			check(is_finite(top) and absf(top-.09)<.0001,"both ceiling bearing plates terminate 310 mm above duct centre")
		check(metal.multimesh.instance_count==iron.multimesh.instance_count,"material partitions share each support station")
		roster[str(stack.name)] = metal.multimesh.instance_count
		for i in metal.multimesh.instance_count:
			var pose := metal.multimesh.get_instance_transform(i)
			var at := pose.origin
			var query := PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.DOWN*.15),root.to_global(at+Vector3.DOWN*.05),1,[world.player.get_rid()])
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
			check(hit.get("collider")==stack,"bearing rests against its existing physical duct stack")
			if not hit.is_empty(): check(absf(root.to_local(hit.position).y-(at.y-.09))<.001,"actual duct underside and exported flange share a datum")
			for side in [-1.0,1.0]:
				var contact := pose * Vector3(.02,.31,.128*side)
				var seated := false
				for surface: PackedVector3Array in ceiling_faces:
					var distance := _mesh_distance(surface,contact-Vector3.UP*.02,Vector3.UP)
					if is_finite(distance) and absf(distance-.02)<.001:
						seated = true
						break
				check(seated,"ceiling plate meets an actual existing rendered ceiling face")
			check(at.y-.117 > floorf(at.y/3.2)*3.2+2.5,"support remains above standing player headroom")
			total += 1
	check(total>23 and batches==8,"supports cover all four geographic stacks with eight instanced draws")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	var views := [
		["north_ground_branch",Vector3(-7.35,1.524,-10.9),Vector3(-6.8,2.7,-11.65)],
		["south_second_register",Vector3(1.05,4.724,5.1),Vector3(2.15,5.89,5.75)],
		["east_third_branch",Vector3(13.8,7.924,-10.5),Vector3(15.1,9.1,-11.5)],
		["west_fourth_branch",Vector3(-7.9,11.124,4.75),Vector3(-6.5,12.29,4.75)],
		["staff_branch",Vector3(7.15,1.524,-6),Vector3(8.5,2.69,-6.45)]]
	for view: Array in views:
		camera.global_position = root.to_global(view[1])
		camera.look_at(root.to_global(view[2]))
		world.player.global_position = camera.global_position - Vector3.UP*world.player.STANDING_EYE
		await shot(view[0])
	print("DUCT SUPPORTS: checks=%d stations=%d batches=%d imported_vertices=%d roster=%s failures=%d" % [checks,total,batches,vertices,str(roster),failures.size()])
	world.shutdown_for_tests()
	world.free()
	await get_tree().create_timer(.25).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
