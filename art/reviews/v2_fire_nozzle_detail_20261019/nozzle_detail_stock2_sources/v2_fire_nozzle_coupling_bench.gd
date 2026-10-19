extends "res://tests/v2_fire_hand_bench.gd"
## Actual imported screw stock and real input. No room/route/human grant.
func _run() -> void:
	var library:=preload("res://scripts/props/fire_nozzle_joint_stock.gd").new()
	if not check(library.load_stock(),"native nozzle coupling library loads"):get_tree().quit(1);return
	var metrics: Node=preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for key: String in library.meshes:metrics._check_cap_mapping(library.meshes[key],true)
	for failure: String in metrics.failures:check(false,failure)
	metrics.free()
	check(library.finish.normal_enabled and not library.finish.uv1_triplanar,"new coupling uses authored UVs and active normal mapping")
	for texture: Texture2D in [library.finish.albedo_texture,library.finish.roughness_texture,library.finish.normal_texture]:check(texture.get_image().get_mipmap_count()>0,"actual loaded coupling map retains mip chain")
	if not failures.is_empty():get_tree().quit(1);return
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var floor:=StaticBody3D.new();add_child(floor)
	var collision:=CollisionShape3D.new();var plane:=BoxShape3D.new();plane.size=Vector3(25,.2,8);collision.shape=plane;collision.position=Vector3(9,-.1,0);floor.add_child(collision)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-25,0);sun.light_energy=1.4;add_child(sun)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.12,.12,.12);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;add_child(env)
	var adapter:=FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=Native.new()
	if not check(native.mount(adapter,{"levels":[{"y":0.}]}),"production installer accepts actual physical nozzle coupling"):
		print(native.errors);get_tree().quit(1);return
	var actor: Node3D=native.stations.values()[0].get_ref()
	var joint: Node3D=actor._nozzle_joint
	var facts: Dictionary=actor.maintenance_snapshot();facts.door_open=true;actor.restore_maintenance_snapshot(facts)
	for frame in range(15):await get_tree().physics_frame
	check(joint.loose and not actor.nozzle_coupled and joint.body.position.y<joint.receiver.origin.y-.01,"unthreaded original nozzle falls onto actual cabinet support")
	player=PlayerController.new();player.position=Vector3(-.1,.025,1.15);add_child(player);player.set_lamp_enabled(false);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame;await get_tree().physics_frame
	var hand: Node=Hand.PatrolHand.new();hand.player=player;add_child(hand)
	await aim(actor._tag.to_global(Vector3(0,0,.0035)));click();key(KEY_SPACE)
	if not check(player.inspecting() and player.inspect_owner==actor,"actual grabbed tag opens static service inspection"):get_tree().quit(1);return
	var eye: Transform3D=player.camera.global_transform
	var point: Vector3=actor._play_pipe.to_global(Vector3(0,.070,.017))
	var goal: Vector3=joint.body.position+Vector3(0,.060,.060)
	check(await carry_part(actor,actor._play_pipe,point,goal,.0001),"actual grab and depth wheel carry the separate original nozzle")
	check(joint.loose and not actor.nozzle_coupled and player.camera.global_transform.is_equal_approx(eye),"loose carrying leaves repair facts false and inspection camera static")
	var inlet: Transform3D=joint.seat.global_transform
	check(await inspect_operate(hand,joint.nut,joint.nut.to_global(Vector3(0,.020,.027)),1.1),"empty captured nut turns freely through actual mouse input")
	check(absf(joint.spin-1.1)<.000001 and joint.loose and joint.seat.global_transform.is_equal_approx(inlet),"empty nut rotation neither twists its hose seat nor joins the nozzle")
	point=actor._play_pipe.to_global(Vector3(0,.070,.017))
	check(await carry_part(actor,actor._play_pipe,point,joint.thread_pose(joint.stock.maximum_angle()).origin,.00009),"actual carrying returns nozzle spigot to the receiving thread")
	check(not joint.loose and not actor.nozzle_coupled and absf(joint.clocking-1.1)<.000001,"physical thread catch aligns actual clocking without tightening")
	check(await inspect_operate(hand,joint.nut,joint.nut.to_global(Vector3(0,.020,.027)),0.),"actual mouse screws whole nozzle along its native thread to the seal")
	check(actor.nozzle_coupled and not actor.gasket_seen and not actor.tag_signed,"only completed nozzle travel changes its coupling fact")
	check(joint.seat.global_transform.is_equal_approx(inlet),"screwing the nozzle preserves its actual fixed hose inlet")
	var saved: Dictionary=actor.mechanism_snapshot()
	check(actor.valid_mechanism(saved) and saved.size()==7,"seven-field household mechanism includes physical nozzle state")
	var bad: Dictionary=saved.duplicate(true);bad.nozzle.angle=joint.stock.maximum_angle()+1.
	check(not actor.valid_mechanism(bad),"saved overtravel cannot replace actual thread state")
	bad=saved.duplicate(true);bad.facts.nozzle_coupled=false
	check(not actor.valid_mechanism(bad),"saved nozzle fact cannot contradict actual sealing travel")
	check(await inspect_operate(hand,joint.nut,joint.nut.to_global(Vector3(0,.020,.027)),3.2),"actual mouse leaves a partial nozzle thread setting")
	check(not actor.nozzle_coupled and absf(joint.body.position.distance_to(joint.thread_pose(0.).origin)-float(joint.stock.data.dimensions.pitch_m)*3.2/TAU)<.000001,"partial physical withdrawal follows measured pitch")
	actor.restore_mechanism(saved)
	check(actor.mechanism_snapshot()==saved,"actual physical nozzle and all existing mechanism fields restore exactly")
	check(await inspect_operate(hand,joint.nut,joint.nut.to_global(Vector3(0,.020,.027)),joint.stock.maximum_angle()),"actual mouse clears the complete threaded stroke")
	check(joint.loose and not actor.nozzle_coupled,"releasing fully cleared thread frees the original nozzle")
	for frame in range(30):await get_tree().physics_frame
	var resting: Dictionary=actor.mechanism_snapshot()
	check(actor.valid_mechanism(resting),"resting loose nozzle retains a valid physical household record")
	actor.restore_mechanism(resting)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(actor.mechanism_snapshot()==resting,"restored supported loose nozzle retains its exact saved pose")
	if check(joint._support!=null and joint._support.get_ref()!=null,"restored nozzle identifies its actual physical support"):
		var support: Node3D=joint._support.get_ref().get_parent_node_3d()
		var initial: Vector3=support.position
		var before: float=joint.body.position.y
		support.position.y-=.03
		for frame in range(30):await get_tree().physics_frame
		check(joint.body.position.y<before-.01,"moving actual saved support wakes nozzle gravity")
		support.position=initial;actor.restore_mechanism(resting)
	player.set_lamp_enabled(false)
	env.environment.sky=Sky.new();env.environment.sky.sky_material=ProceduralSkyMaterial.new();env.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	var close:=Camera3D.new();close.fov=38.;add_child(close);close.global_position=actor.to_global(Vector3(-.04,.24,.58));close.look_at(actor.to_global(Vector3(-.04,.07,.112)));close.make_current()
	var directory: String=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory);await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join("physical_nozzle_coupling.png"))==OK,"actual physical nozzle frame saved")
	var parents: bool=true
	for original: Dictionary in native.source_records[actor.station_id]:
		var draw: MeshInstance3D=original.draw.get_ref();parents=parents and draw!=null and draw.get_parent().get_instance_id()==original.parent
	check(parents,"native screw and loose-body migration retain every original draw parent")
	print("V2 FIRE NOZZLE COUPLING: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	if not failures.is_empty():get_tree().quit(1);return
	key(KEY_ESCAPE)
	for child: Node in get_children():child.free()
	await get_tree().physics_frame
	# One engine launch: new actual coupling programme, all fitted stock, and
	# every retained cabinet/washer/door/valve input path.
	var folds: Node3D=load("res://tests/v2_fire_fold_bench.gd").new();add_child(folds)
