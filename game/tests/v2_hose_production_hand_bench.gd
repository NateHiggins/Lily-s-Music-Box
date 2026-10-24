extends "res://tests/v2_unracked_hose_bench.gd"
## Actual input through production stock in an isolated cabinet fixture.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var adapter:=FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=Native.new()
	if not check(native.mount(adapter,{"levels":[{"y":0.}]}) and native.mount_hose_deployment(),"production native and deployment factories mount"):
		print(native.errors);get_tree().quit(1);return
	var actor: Node3D=native.stations.values()[0].get_ref()
	for reference: WeakRef in native.stations.values():
		var other: Node3D=reference.get_ref()
		if other!=actor:other.free()
	var hose: Node3D=actor._live_hose
	var joint: Node3D=actor._nozzle_joint
	# Repaired connection is an explicit fixture precondition, not assembly proof.
	actor.door_open=true;actor._refresh_cabinet();actor.nozzle_coupled=true;joint.restore_legacy(true)
	var lamp:=DirectionalLight3D.new();lamp.rotation_degrees=Vector3(-35,-25,0);lamp.light_energy=1.3;add_child(lamp)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.12,.12,.12)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.6
	player=PlayerController.new();add_child(player);player.set_physics_process(false)
	player.collision_layer=0;player.collision_mask=0
	player.global_position=actor.to_global(Vector3(-.3,.15,.70))-player.camera.position
	player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for frame in 8:await get_tree().physics_frame
	if not check(await _aim_nozzle_surface(actor,joint),"actual ray selects the fitted nozzle for extraction"):
		get_tree().quit(1);return
	var events: Dictionary={"count":0}
	actor.manipulation_changed.connect(func() -> void:events.count+=1)
	click()
	check(player._grab.active() and actor._hand=="hose" and not hose.deployed,"primary click latches the stored hose without toggling deployment")
	for step in 50:
		if hose.deployed:break
		var point: Vector3=player._grab.target.part.to_global(player._grab.contact)
		var axis: Vector3=actor.global_basis*Vector3.BACK
		var screen: Vector2=(player.camera.unproject_position(point+axis*.01)-player.camera.unproject_position(point))/.01
		if screen.length()<24.:screen=Vector2(0,axis.dot(player.camera.global_basis.z)*180.)
		var event:=InputEventMouseMotion.new();event.relative=screen*.008
		player._unhandled_input(event);await get_tree().physics_frame;player._grab.validate()
	check(hose.deployed and hose.model.visible and not actor.hose_racked,"actual pull replaces stored cloth with the separate native skin")
	check(player._grab.holding_pickup() and actor._hand=="hose" and events.count==0,"extraction continues into the same FPS grab without release or extra click")
	check(player.held_stock_body()==joint.body,"continued grab registers the original physical nozzle")
	for frame in 4:await get_tree().process_frame;player._grab.follow_holder()
	var errors: Array=[]
	hose.profile_motion=true
	for step in 24:
		var event:=InputEventMouseMotion.new();event.relative=Vector2(2. if step<12 else -2.,.5)
		player._unhandled_input(event);await get_tree().process_frame;player._grab.follow_holder()
		var direction: Vector3=joint.body.global_basis.y.normalized()
		errors.append(rad_to_deg(acos(clampf(direction.dot(-player.camera.global_basis.z),-1.,1.))))
	check(errors.max()<.1,"held nozzle follows reticle yaw and pitch within a tenth of a degree")
	check(hose.contact.broad_queries==0 and hose.contact.shell_queries==0 and not hose.is_processing(),"FPS visual follow runs no environment scan or cloth solver")
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory);await RenderingServer.frame_post_draw
		FileAccess.open(directory.path_join("held_projection.json"),FileAccess.WRITE).store_string(JSON.stringify(hand_projection(actor,hose),"\t"))
		check(get_viewport().get_texture().get_image().save_png(directory.path_join("production_fps_hold.png"))==OK,"continued FPS hose hold rendered")
	click()
	check(not player._grab.active() and actor._hand.is_empty() and events.count==1,"next click releases the same hand and publishes exactly one owner event")
	actor.door_open=false;actor._refresh_cabinet()
	check(hose.grip().get("kind")=="free","deployed hose remains operable when its distant cabinet is closed")
	actor.door_open=true;actor._refresh_cabinet()
	if failures.is_empty():await preload("res://tests/v2_hose_water_programme.gd").new().run(self,actor,hose)
	if failures.is_empty():await _release_support_checks(actor,hose,directory)
	player.cancel_manipulation()
	var original_exception: bool=player.get_collision_exceptions().has(actor._bodies.door)
	actor._door_motion.bind_holder(player);actor._door_motion.schedule()
	player.global_position+=actor.global_basis.z*3.
	var slow:=true
	for step in 800:
		var previous: float=actor._door_angle
		actor._door_motion.tick(1./60.)
		if previous-actor._door_angle>.20/60.+.00001:slow=false
	check(slow and actor._door_angle==actor._minimum("door") and not actor.door_open,"cabinet automatic closure stays slow and leaves the deployed hose exit clear")
	check(player.get_collision_exceptions().has(actor._bodies.door)==original_exception and actor._door_motion.exceptions.is_empty(),"automatic closure restores only its owned player collision exceptions")
	if failures.is_empty():await _case_gallery(actor,hose,directory)
	print("PRODUCTION HOSE HAND: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size()," setup_ms=",hose.setup_ms)
	if not directory.is_empty():
		FileAccess.open(directory.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Production factory in isolated fixture; camera physics and collision disabled. No world route or household reconstruction qualification.","checks":observations,"aim_errors_degrees":errors,"motion_calls":hose.motion_profile_records,"setup_ms":hose.setup_ms,"failures":failures},"\t"))
	get_tree().quit(0 if failures.is_empty() else 1)

func hand_projection(actor: Node3D,hose: Node3D) -> Dictionary:
	var joint: Node3D=actor._nozzle_joint
	var camera: Camera3D=player.camera
	var receiver: Vector3=actor.to_global(joint.receiver.origin)
	var muzzle: Vector3=actor._play_pipe.to_global(Vector3(0,.171,0))
	var screen: Vector2=camera.unproject_position(muzzle)
	var local: Vector3=camera.to_local(receiver)
	return {"evidence_class":"INERT","camera":var_to_str(camera.global_transform),"receiver_camera_m":[local.x,local.y,local.z],"muzzle_screen_px":[screen.x,screen.y],"muzzle_behind_camera":camera.is_position_behind(muzzle),"receiver_actor_m":var_to_str(joint.receiver.origin),"player_actor_m":var_to_str(actor.to_local(player.global_position)),"route_limited":hose.visual_route.limited,"hose_points":var_to_str(hose.rig.strand.points)}

func _release_support_checks(actor: Node3D,hose: Node3D,directory: String) -> void:
	var floor_body:=StaticBody3D.new();floor_body.name="DiagnosticSupportFloor";add_child(floor_body)
	var floor_y: float=actor.global_position.y-1.2
	floor_body.global_position=Vector3(actor.global_position.x,floor_y-.05,actor.global_position.z)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(6,.1,6);collision.shape=shape;floor_body.add_child(collision)
	var draw:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=shape.size;draw.mesh=mesh;floor_body.add_child(draw)
	for frame in 3:await get_tree().physics_frame
	if not check(await _aim_nozzle_surface(actor,actor._nozzle_joint),"supported release begins by targeting the specific nozzle"):return
	click()
	for frame in 3:await get_tree().process_frame;player._grab.follow_holder()
	var before: Transform3D=actor._nozzle_joint.receiver
	var previous: Dictionary=hose.release_support.last_result.duplicate(true)
	key(KEY_SPACE)
	check(player.inspecting() and actor._nozzle_joint.receiver.is_equal_approx(before) and hose.release_support.last_result==previous,"entering static inspection does not drop or reposition the carried nozzle")
	var closing_hand:=Hand.PatrolHand.new();closing_hand.player=player;add_child(closing_hand)
	check(await inspect_operate(closing_hand,actor._lever,actor._lever.to_global(Vector3(.07,0,0)),0.),"actual lever input closes the nozzle before the supported pickup regression")
	closing_hand.free()
	key(KEY_ESCAPE)
	for frame in 3:await get_tree().process_frame;player._grab.follow_holder()
	check(player._grab.holding_pickup(),"leaving static inspection returns nozzle to the same FPS hand")
	var water: Dictionary=hose.water.snapshot()
	click()
	check(hose.release_support.last_result.get("placed",false),"next click places the coupled nozzle on real support")
	if hose.release_support.last_result.get("placed",false):check(absf(float(hose.release_support.last_result.envelope_bottom_y)-floor_y-.002)<.00001,"physical nozzle and coupling envelope rests two millimetres above the floor")
	check(hose.water.snapshot()==water and not player._grab.active(),"release retains water authority and clears the hand")
	var resting: Transform3D=actor._nozzle_joint.receiver
	var result: Dictionary=hose.release_support.last_result.duplicate(true)
	for frame in 30:await get_tree().physics_frame
	check(actor._nozzle_joint.receiver==resting and hose.release_support.last_result==result and not hose.is_processing() and not hose.is_physics_processing(),"supported nozzle rests with no placement queries, cloth or fluid ticks")
	player.collision_layer=1
	if check(await _aim_nozzle_surface(actor,actor._nozzle_joint,false),"floor nozzle can be targeted with the player's real collision capsule"):
		click()
		for frame in 3:await get_tree().process_frame;player._grab.follow_holder()
		key(KEY_SPACE)
		var hand:=Hand.PatrolHand.new();hand.player=player;add_child(hand)
		check(await inspect_operate(hand,actor._lever,actor._lever.to_global(Vector3(.07,0,0)),-.95),"held floor pickup allows lever motion during inspection with the real player capsule")
		print("SUPPORTED INSPECTION OBSTRUCTION: ",actor.last_hand_obstruction)
		check(hose.inspection_control_exclusions()==[player.get_rid()],"borrowed nozzle inspection excludes only the original holder capsule")
		var blocker:=StaticBody3D.new();blocker.name="LeverObstructionControl";add_child(blocker);blocker.global_position=actor._lever.global_position
		var stop:=CollisionShape3D.new();var stop_box:=BoxShape3D.new();stop_box.size=Vector3(.5,.5,.5);stop.shape=stop_box;blocker.add_child(stop)
		for frame in 3:await get_tree().physics_frame
		check(actor._obstructed("lever",-.45) and actor.last_hand_obstruction.get("collider")==str(blocker.get_path()),"external solid still blocks the lever while holder capsule is excluded")
		blocker.free()
		key(KEY_ESCAPE);player.cancel_manipulation();hand.free()
		check(hose.inspection_control_exclusions().is_empty(),"ending borrowed inspection removes the holder exclusion")
	player.collision_layer=0
	if not directory.is_empty():
		FileAccess.open(directory.path_join("release_support.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
		await aim(actor._nozzle_joint.body.global_position)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("supported_nozzle.png"))

func _case_gallery(actor: Node3D,hose: Node3D,directory: String) -> void:
	# Staged geometry review after the actual-input programme, not walked proof.
	var camera:=Camera3D.new();add_child(camera);camera.fov=48.
	camera.global_position=actor.to_global(Vector3(-1.,.52,1.6));camera.look_at(actor.to_global(Vector3(0,.36,.15)));camera.make_current()
	var poses: Array=[]
	for pressure: float in [0.,1.]:
		hose.water.restore({"fill":pressure,"pressure":pressure})
		var index:=0
		for location: Vector3 in [Vector3(.17,.2,.9),Vector3(-2.,.25,.3),Vector3(2.,.25,.3),Vector3(.17,.2,-1.5),Vector3(.17,2.,.1),Vector3(.17,-.8,.1),Vector3(.17,.2,.1)]:
			var wanted: Transform3D=actor.global_transform*actor._nozzle_joint.receiver;wanted.origin=actor.to_global(location)
			hose._visual_receiver(wanted)
			var clear:=true
			for i in range(1,hose.rig.strand.points.size()-24):
				var a: Vector3=hose.model.transform*hose.rig.strand.points[i-1]
				var b: Vector3=hose.model.transform*hose.rig.strand.points[i]
				if hose.visual_route.CASE.intersects_segment(a,b)!=null:clear=false
			check(clear,"external cloth clears expanded cabinet bounds: "+str([pressure,index]))
			var name: String="case_%d_%d.png"%[int(pressure),index]
			await RenderingServer.frame_post_draw
			if not directory.is_empty():get_viewport().get_texture().get_image().save_png(directory.path_join(name))
			poses.append({"pressure":pressure,"target":str(location),"clear":clear,"image":name});index+=1
	if not directory.is_empty():FileAccess.open(directory.path_join("case_geometry.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Staged native geometry review at ajar stop. External centerlines tested against expanded case bounds; internal fixed exit visually reviewed. No new physics or walked acceptance.","poses":poses},"\t"))
	player.camera.make_current();camera.free()
