extends "res://tests/orison_v2_owner_service_finish_test.gd"
## One-world cloth contacts, physical reach and original pulley state exercise.
class ServiceWalker extends "res://tests/orison_v2_connected_exterior_route_test.gd":
	func _ready() -> void: pass

func _init() -> void:
	contract_key="wet_cloth"
	contract_scope="Native V2 airer original control, interrupted travel, suspension endpoints, cloth/tub clearance, original physical reach, repeated shower curtain poses, local residue deployment, live collision-controlled laundry/boiler service approaches and teardown. Save reconstruction and full building routes are not exercised."

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	contract_started=Time.get_ticks_msec()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_basement_airer.json"))
	check(FileAccess.get_sha256("res://assets/props/basement_airer.glb")==fixture.asset_sha256,"airer native export bound")
	var airer=world.adapter.resolve("B1_LAUNDRY_AIRER_01")
	check(airer is LaundryAirerProp and airer.has_meta("v2_native_airer"),"native presentation retains original airer class")
	if airer==null: return {"checks":checks,"failures":failures}
	retained.append(weakref(airer))
	var lowered: bool=airer.is_airer_lowered()
	var body: StaticBody3D=airer.get_node("RinseTubCollision")
	var shape: CollisionShape3D=body.get_child(0)
	check(shape.shape.size.is_equal_approx(Vector3(1.24,.82,.58)) and shape.position.is_equal_approx(Vector3(0,.41,0)),"original rinse collision retained")
	for id in ["RinseReach","AirerReach"]:
		var area: PropControlArea=airer.get_node(id)
		check(area!=null and area.get_child(0) is CollisionShape3D,"original physical reach area retained: "+id)
	# Follow the complete retained travel, including interrupted/reversed tween.
	for step in 17:
		airer._rack.position.y=lerpf(1.38,1.98,float(step)/16.)
		airer._update_suspension()
		for i in 2:
			var rope: Node3D=airer.suspension[i]
			var side: float=-1. if i==0 else 1.
			check((rope.transform*Vector3.ZERO).distance_to(Vector3(side*.56,airer._rack.position.y+.075,0))<.00001,"rope remains attached to rack over full travel")
			check((rope.transform*Vector3.UP).distance_to(Vector3(side*.52,2.42,0))<.00001,"rope remains attached to fixed tackle over full travel")
		for cloth: MeshInstance3D in airer._rack.find_children("Cloth?","MeshInstance3D",true,false):
			var bounds: AABB=airer.global_transform.affine_inverse()*cloth.global_transform*cloth.mesh.get_aabb()
			check(bounds.position.y>.805+.20,"lowered cloth clears retained tub lips")
	airer.set_airer_lowered(true,.10)
	await get_tree().process_frame
	airer.set_airer_lowered(false,.10)
	await airer._rack_tween.finished
	check(not airer.is_airer_lowered() and is_equal_approx(airer._rack.position.y,1.98),"cancelled descent follows original raised state")
	airer.interact_control("airer")
	await airer._rack_tween.finished
	check(airer.is_airer_lowered() and is_equal_approx(airer._rack.position.y,1.38),"original verb lowers complete rack")
	var approach: Vector3=world.adapter.root.to_global(Vector3(-5.3,-3.18,1.6))
	check(_city_clear_station(world,approach),"retained laundry approach has player clearance")
	var target: Vector3=airer.get_node("AirerReach").get_child(0).global_position
	var query:=PhysicsRayQueryParameters3D.create(approach+Vector3.UP*1.41,target)
	query.collide_with_areas=true
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and hit.collider==airer.get_node("AirerReach"),"original pulley control physically reachable from retained route")
	var cloth_count: int=airer._rack.find_children("Cloth?","MeshInstance3D",true,false).size()
	check(cloth_count==int(fixture.cloth_count),"three source cloths, no invented stock")
	if capture_enabled:
		await _city_capture(world,approach,airer.to_global(Vector3(0,1.1,0)),"airer_lowered","native wet-work stock lowered","B1_LAUNDRY_AIRER_01")
		airer.set_airer_lowered(false,0)
		await _city_capture(world,approach,airer.to_global(Vector3(0,1.25,0)),"airer_raised","native wet-work stock raised","B1_LAUNDRY_AIRER_01")
	airer.set_airer_lowered(lowered,0)
	for actor: TapProp in world.find_children("*","Node3D",true,false).filter(func(a):return a is TapProp and a.fixture=="shower"):
		var opened: bool=actor.is_curtain_open()
		for open in [true,false]:
			actor.set_curtain_open(open)
			check(actor._curtain_gathered.visible==open and actor._curtain_closed.visible!=open,"original curtain control selects native pose")
			var curtain: Node3D=actor._curtain_gathered if open else actor._curtain_closed
			var lowest:=INF
			for part: MeshInstance3D in curtain.find_children("*","MeshInstance3D",true,false):
				var pose:=actor.global_transform.affine_inverse()*part.global_transform
				for point: Vector3 in part.mesh.get_faces(): lowest=minf(lowest,(pose*point).y)
			check(lowest>=.1539 and lowest<.17,"physical curtain hem clears receptor in each pose")
		actor.set_curtain_open(opened)
		retained.append(weakref(actor))
	var local_slots:=0
	for actor in world.find_children("*","Node3D",true,false):
		if actor.has_meta("v2_local_residue_slots"): local_slots+=int(actor.get_meta("v2_local_residue_slots"))
	check(local_slots>20,"source-local wet-use masks deployed without new water owners")
	for room in ["B1_LAUNDRY","B1_BOILER_ROOM"]:
		var floor_draw: MeshInstance3D=world.adapter.root.get_node(room+"/Floor")
		var finish:=floor_draw.get_active_material(0) as ShaderMaterial
		check(floor_draw.has_meta("v2_service_floor_finish") and finish!=null and finish.get_shader_parameter("albedo_tex")!=null,"local floor history retains its real construction and catalogue: "+room)
		if finish==null:continue
		var patches: PackedVector4Array=finish.get_shader_parameter("service_patches")
		check(patches.size()==3,"three source-local work patches; no room-wide dirt: "+room)
	for x in [-.52,.52]:
		var top: Vector3=airer.to_global(Vector3(x,3.,0))
		# Ceilings are intentionally non-colliding; check their actual render plane.
		var ceiling: MeshInstance3D=world.adapter.root.get_node("B1_LAUNDRY/Ceiling")
		var bounds: AABB=ceiling.global_transform*ceiling.mesh.get_aabb()
		check(absf(top.y-bounds.position.y)<.00003,"native hanger plate bears on actual ceiling underside")
	var walker:=ServiceWalker.new();walker.world=world;walker.player=world.player;add_child(walker)
	world.player.set_physics_process(true)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for route in [[Vector3(-3.4,-3.18,-1.5),Vector3(-3.2,-3.2,-2.4),Vector3(-7,-3.2,-2.4),Vector3(-8.35,-3.2,-.15),Vector3(-7,-3.2,-.8),Vector3(-5.3,-3.2,1.6)],
			[Vector3(10.6,-3.18,-.4),Vector3(10.6,-3.2,2.4),Vector3(11.075,-3.2,2.4),Vector3(11.075,-3.2,3.1)]]:
		world.player.global_position=world.adapter.root.to_global(route[0]);world.player.velocity=Vector3.ZERO
		await get_tree().physics_frame
		for point: Vector3 in route.slice(1):
			if not await walker._walk(point):break
	check(walker.failures.is_empty(),"live collision-controlled laundry and boiler service approaches")
	for failure: String in walker.failures:failures.append(failure)
	var walked: Array=walker.trace.duplicate(true)
	Input.action_release("move_forward");world.player.set_physics_process(false);walker.free()
	if capture_enabled:
		for row in [["B1_LAUNDRY",Vector3(-3.4,-3.17,-2.4),Vector3(-6.5,-2.3,1.4)]]:
			await _city_capture(world,world.adapter.root.to_global(row[1]),world.adapter.root.to_global(row[2]),str(row[0])+"_finish","local service use and unchanged practicals",str(row[0]))
		var boiler: Node3D=world.adapter.resolve("B1_BOILER_01")
		await _city_capture(world,boiler.to_global(Vector3(.6,.03,-2.15)),boiler.to_global(Vector3(0,.55,0)),"B1_BOILER_ROOM_finish","firing approach and local service use","B1_BOILER_ROOM")
	validation_completed=true
	return {"checks":checks,"failures":failures,"cloth_count":cloth_count,"local_residue_slots":local_slots,"walked_service_approaches":walked,"views":discovery.duplicate(true)}

