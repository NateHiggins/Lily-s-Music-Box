extends "res://tests/orison_v2_lift_joinery_test.gd"
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.player.set_physics_process(false)
	var flue=world.adapter.root.get_node("BoilerFlue")
	var boiler := world.adapter.resolve("B1_BOILER_01") as BoilerProp
	check(flue.elbows.size()==3,"three actual bent elbows replace the sphere joints")
	var contacts := 0
	var triangles := 0
	for elbow: StaticBody3D in flue.elbows:
		var mesh := elbow.get_node("Elbow") as MeshInstance3D
		check(mesh.mesh is ArrayMesh,"elbow is the imported Blender fabrication")
		var faces := mesh.mesh.get_faces()
		triangles+=faces.size()/3
		# Each mouth is annular metal, with no old cylinder cap across the bore.
		for mouth in [[Vector3(0,-flue.BEND-.03,0),Vector3.UP], [Vector3(flue.BEND+.03,0,0),Vector3.LEFT]]:
			var d := _mesh_distance(faces,mouth[0],mouth[1])
			check(d>.10,"smoke mouth remains open beyond its rolled rim")
		for angle in [.13,.39,.65,.91,1.17,1.43]:
			var center := Vector3(flue.BEND-flue.BEND*cos(angle),-flue.BEND+flue.BEND*sin(angle),0)
			var origin := center+Vector3.BACK*.4
			var d := _mesh_distance(faces,origin,Vector3.FORWARD)
			check(is_finite(d),"elbow has a continuous fabricated wall")
			var ray := PhysicsRayQueryParameters3D.create(elbow.to_global(origin),elbow.to_global(center),1,[world.player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(hit.get("collider")==elbow,"bend has its own actual wall collision")
			if not hit.is_empty(): check(absf(d-origin.distance_to(elbow.to_local(hit.position)))<.001,"bend collision follows rendered triangles")
			contacts+=1
	var first: Node3D=flue.elbows[0]
	check(first.to_global(Vector3(0,-flue.BEND,0)).distance_to(boiler.smoke_outlet())<.001,"first open mouth seats on the actual horizontal collar")
	for part: MeshInstance3D in flue.find_children("*","MeshInstance3D",true,false):
		check(not part.mesh is SphereMesh,"no bulbous sphere joints remain")
	for section: Dictionary in flue.sections:
		var body: Node3D=section.body
		var pipe := body.get_node("Pipe") as MeshInstance3D
		check(pipe.scale.is_equal_approx(Vector3.ONE),"physical triplanar scale is baked into straight vertices")
		var faces := pipe.mesh.get_faces()
		var bounds := pipe.mesh.get_aabb()
		check(_mesh_distance(faces,Vector3(0,bounds.position.y-.01,0),Vector3.UP)>bounds.size.y,"straight bore has no hidden end cap")
		var ray := PhysicsRayQueryParameters3D.create(body.to_global(Vector3(.4,0,0)),body.to_global(Vector3.ZERO),1,[world.player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(hit.get("collider")==body,"straight run keeps its solid service envelope")
		if not hit.is_empty(): check(absf(_mesh_distance(faces,Vector3(.4,0,0),Vector3.LEFT)-Vector3(.4,0,0).distance_to(body.to_local(hit.position)))<.001,"straight collision meets the imported shell")
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=65
	for layer in world.player.carried_device.get_children():
		if layer is CanvasLayer: layer.hide()
	world.player.set_lamp_enabled(false)
	var target: Vector3=flue.to_global(flue.sections[1].to)
	camera.global_position=target+Vector3(-1,-.5,-1.4)
	camera.look_at(target)
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.global_position=camera.global_position; fill.omni_range=4; fill.light_energy=.35
	await shot("fabricated_breeching_detail")
	target=first.global_position
	camera.global_position=target+Vector3(-.1,.3,-1.2)
	camera.look_at(target); fill.global_position=camera.global_position
	await shot("smoke_collar_elbow")
	_write_census(world)
	print("BREECHING: elbows=%d collision_contacts=%d elbow_triangles=%d failures=%d" % [flue.elbows.size(),contacts,triangles,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)

func _write_census(world: Node3D) -> void:
	# Inspection work index only: hidden reservations/debug assets are listed,
	# never promoted to visible geometry or accepted fabrication by a count.
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	var records: Array=[]
	for node: Node in world.find_children("*","GeometryInstance3D",true,false):
		var mesh: Mesh=null
		var instances := 1
		if node is MeshInstance3D: mesh=node.mesh
		elif node is MultiMeshInstance3D and node.multimesh!=null:
			mesh=node.multimesh.mesh
			instances=node.multimesh.instance_count
		if mesh==null: continue
		var materials: Array=[]
		for surface in mesh.get_surface_count():
			var material: Material=node.material_override
			if material==null and node is MeshInstance3D: material=node.get_active_material(surface)
			if material==null: material=mesh.surface_get_material(surface)
			if material is StandardMaterial3D:
				materials.append({"type":"standard","triplanar":material.uv1_triplanar,
					"albedo":material.albedo_texture.resource_path if material.albedo_texture!=null else ""})
			elif material is ShaderMaterial:
				materials.append({"type":"shader","shader":material.shader.resource_path if material.shader!=null else ""})
			else: materials.append({"type":"none"})
		records.append({"path":str(world.get_path_to(node)),"visible":node.is_visible_in_tree(),
			"mesh":mesh.get_class(),"source":mesh.resource_path,"instances":instances,"materials":materials})
	var report := {"evidence_class":"INERT","acceptance":"unreviewed production discovery",
		"geometry":records,"render_draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
	var file := FileAccess.open(directory.path_join("production_geometry_inventory.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
