extends "res://tests/orison_v2_boiler_body_test.gd"
## Composed installation diagnostic. Does not publish a runtime contract.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed,"production world starts with heating fabric")
	if world.startup_failed or world.player==null:
		world.free();get_tree().quit(1);return
	world.player.set_physics_process(false)
	var root: Node3D=world.adapter.root
	var model := root.get_node_or_null("HeatingDistribution")
	check(model!=null,"native distribution is mounted in building coordinates")
	if model!=null:
		var parts := model.find_children("*","MeshInstance3D",true,false)
		check(parts.size()==7,"distribution retains seven level/shaft batches")
		for part: MeshInstance3D in parts:
			var material := part.material_override as StandardMaterial3D
			check(material!=null and not material.uv1_triplanar and material.uv1_scale==Vector3.ONE,"authored UVs remain active: "+str(part.name))
			if material!=null:
				for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
					check(texture!=null and texture.get_image()!=null and texture.get_image().has_mipmaps(),"loaded custom PBR mip chain: "+str(part.name))
	for layer in world.player.carried_device.get_children():
		if layer is CanvasLayer:layer.hide()
	var roster: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/heating.json"))
	for record: Dictionary in roster.installed:
		if int(record.sections)>=10:continue
		var radiator := world.adapter.resolve(str(record.id)) as RadiatorProp
		var casting := radiator._section_multimesh
		var faces := PackedVector3Array()
		for vertex: Vector3 in casting.multimesh.mesh.get_faces():
			faces.append(radiator.to_local(casting.to_global(casting.multimesh.get_instance_transform(0)*vertex)))
		var distance := _mesh_distance(faces,Vector3(-.60,-.56,-.055),Vector3.RIGHT)
		var reach := .60-float(int(record.sections)-1)*RadiatorProp.SECTION_PITCH*.5+.015
		check(is_finite(distance) and distance<reach,"tailpiece reaches actual first casting: "+str(record.id))
		var part := model.find_child("Heating_"+str(record.id).left(3),true,false) as MeshInstance3D
		check(part!=null,"native floor batch for tailpiece: "+str(record.id))
		if part!=null:
			var middle_x := (-.40+reach-.60)*.5
			var origin := part.to_local(radiator.to_global(Vector3(middle_x,-.49,-.055)))
			var direction := part.global_basis.inverse()*radiator.global_basis*Vector3.DOWN
			var actual := _mesh_distance(part.mesh.get_faces(),origin,direction)
			check(is_finite(actual) and absf(actual-.044)<.003,"loaded native tailpiece lies at its radiator elevation: "+str(record.id))
	var lobby := world.adapter.resolve("F01_LOBBY_RADIATOR_01") as RadiatorProp
	check(lobby!=null and lobby._balance==world.heat_balance,"lobby shares the original heat authority")
	if lobby!=null:
		var hand := preload("res://tests/heating_hand_driver.gd").new()
		hand.player=world.player;add_child(hand)
		await get_tree().process_frame
		await get_tree().process_frame
		world.player.set_physics_process(true)
		world.player.global_position=lobby.to_global(Vector3(-.53,-.73,-1.1))
		world.player.velocity=Vector3.ZERO
		world.player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var valve := lobby.get_node("TurnValveSurface") as Area3D
		for goal: float in [0.0,TAU*3.5]:
			world.player.camera.look_at(valve.global_position)
			await get_tree().physics_frame
			await get_tree().physics_frame
			hand.click()
			var grabbed: bool = world.player._grab.active() and world.player._grab.target.get("owner")==lobby
			check(grabbed,"player click grabs the actual lobby valve")
			if grabbed:
				var reached: bool = await hand.move_to(goal)
				print("LOBBY VALVE goal=",goal," actual=",lobby.supply_position*TAU*3.5," held=",world.player._grab.active()," camera=",lobby.to_local(world.player.camera.global_position))
				check(reached,"mouse motion turns lobby valve to stop: "+str(goal))
				hand.click()
				check(not world.player._grab.active() and absf(lobby.supply_position-goal/(TAU*3.5))<.01,"release retains the physical lobby valve position")
		check(hand.follows_cursor,"lobby handwheel follows projected mouse motion")
		hand.free();world.player.set_physics_process(false)
	# Use the restored-volume movement helper and the ordinary controller,
	# not just stock bounds: a seat inside its room can still block entry.
	var walk := preload("res://tests/v2_front_restoration_review.gd").new()
	add_child(walk);walk.world=world;walk.host=self;walk.player=world.player
	world.player.set_physics_process(true)
	world.player.global_position=root.to_global(Vector3(-4.85,.025,-8.4))
	world.player.velocity=Vector3.ZERO
	await get_tree().physics_frame
	for point: Vector3 in [Vector3(-4.85,0,-9.8),Vector3(-3.7,0,-10.7)]:
		check(await walk._walk(point),"ordinary controller reaches west waiting bay: "+str(point))
	walk.free();world.player.set_physics_process(false)
	var camera := Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=55
	var fill := OmniLight3D.new();camera.add_child(fill);fill.light_energy=.6;fill.omni_range=3
	var bench := root.find_child("WestBench",true,false) as Node3D
	check(bench!=null,"west entrance bench is retained")
	if bench!=null:
		var bay: Dictionary={}
		for space: Dictionary in world.adapter.root.layout.spaces:
			if space.id=="F01_FRONT_WEST_BAY":bay=space;break
		check(not bay.is_empty(),"restored waiting bay owns the seat location")
		if not bay.is_empty():
			for mesh: MeshInstance3D in bench.find_children("*","MeshInstance3D",true,false):
				var contained := true
				for vertex: Vector3 in mesh.mesh.get_faces():
					var point := root.to_local(mesh.to_global(vertex))
					contained=contained and point.x>float(bay.rect[0])+.07 and point.x<float(bay.rect[2])-.07 and point.z>float(bay.rect[1])+.07 and point.z<float(bay.rect[3])-.07
				check(contained,"actual bench stock sits inside restored bay: "+str(mesh.name))
		camera.global_position=root.to_global(Vector3(-2.5,1.5,-9.5));camera.look_at(bench.global_position+Vector3.UP*.45)
		await get_tree().create_timer(.3).timeout
		await shot("heating_lobby_bench")
	camera.global_position=root.to_global(Vector3(-2.8,1.6,-8.4));camera.look_at(root.to_global(Vector3(-5.0,.6,-8.5)))
	await get_tree().create_timer(.3).timeout
	await shot("heating_lobby_waiting_bay")
	camera.global_position=root.to_global(Vector3(9.275,-.9,-.9));camera.look_at(root.to_global(Vector3(8.675,-.55,.3)))
	await get_tree().create_timer(.3).timeout
	await shot("heating_receiver")
	for identity: String in ["F01_LOBBY_RADIATOR_01","F05_B_RADIATOR_01","F06_B_RADIATOR_01"]:
		var radiator := world.adapter.resolve(identity) as RadiatorProp
		check(radiator!=null,"installed radiator for supply review: "+identity)
		if radiator==null:continue
		var target := radiator.to_global(Vector3(-.67,-.745,0))
		camera.global_position=radiator.to_global(Vector3(-.55,-.30,-.65));camera.look_at(target)
		var query := PhysicsRayQueryParameters3D.create(camera.global_position,target,1,[world.player.get_rid()])
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and radiator.is_ancestor_of(hit.collider),"camera reaches radiator supply without wall obstruction: "+identity+" collider="+str(hit.get("collider")))
		await get_tree().create_timer(.3).timeout
		await shot("heating_"+identity)
	print("HEATING DISTRIBUTION failures=",failures.size())
	world.shutdown_for_tests();world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
