extends "res://tests/v2_fire_hand_bench.gd"
## Actual imported screw stock and real input. No room/route/human grant.
func pickup_with_mouse(joint: Node3D) -> bool:
	# Use the same bounded visible-surface acquisition as other native parts.
	# A single projected pixel can miss delayed native cursor delivery; require
	# the real picker to identify this nut before sending the actual click.
	if not await acquire_surface(joint.nut,joint.nut.to_global(Vector3(0,.020,.027))):return false
	var before: Transform3D=joint.body.transform
	click()
	if not check(player._grab.active() and joint.body.transform==before and joint.loose,"grabbing inserted nut leaves nozzle pose and engagement unchanged"):return false
	for step in 64:
		if not player._grab.active() or not joint.loose:break
		var target: Dictionary=player._grab.target
		var point: Vector3=target.part.to_global(player._grab.contact)
		var axis: Vector3=target.frame.global_basis*target.axis
		var tangent: Vector3=axis.cross(point-target.part.global_position)
		if tangent.length()<.025:tangent=axis.cross(player.camera.global_basis.x)*.06
		var screen: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
		if screen.length()<24. and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5:screen=Vector2(0,tangent.dot(player.camera.global_basis.z)*180.)
		var motion:=InputEventMouseMotion.new();motion.relative=-screen*.12
		player._unhandled_input(motion);await get_tree().physics_frame
	print("NOZZLE MOUSE PICKUP: loose=",joint.loose," angle=",joint.angle," clocking=",joint.clocking," spin=",joint.spin," position=",joint.body.position)
	before=joint.body.transform
	if player._grab.active():click()
	return not joint.loose and joint.body.transform==before and not joint.actor.nozzle_coupled
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
	if OS.get_environment("ORISON_NOZZLE_WORLD_POSE")=="1":
		# Derive the real installed frame; a rounded PI/translation fixture
		# can hide precision-dependent contacts in these small moving parts.
		var connection=preload("res://scripts/building/orison_v2_world_connection.gd")
		var source: Dictionary=connection.read_object("res://data/orison_v2_blockout.json")
		var resolved: Dictionary=connection.prepare(source,connection.read_object("res://data/orison_v2/exterior/exterior_geometry.json"),preload("res://scripts/building/orison_v2_exterior_spatial_resolver.gd").load_default(),connection.read_object(connection.CONFIG_PATH))
		if not check(not resolved.is_empty(),"production world connection resolves for translated contact bench"):get_tree().quit(1);return
		var station: String=OS.get_environment("ORISON_NOZZLE_STATION")
		if station.is_empty():station="B1_FIRE_LINE_STAIR"
		var anchor: Dictionary=connection.unique_record(source.anchors,station)
		var level: Dictionary=connection.unique_record(source.levels,station.get_slice("_",0))
		var at:=Vector3(anchor.position[0],anchor.position[1]+level.y,anchor.position[2])
		var installed: Transform3D=resolved.interior_transform*Transform3D(Basis.IDENTITY,at)
		adapter.root.transform=Transform3D(installed.basis,installed.origin-installed.basis*Vector3(0,1.2,0))
		floor.position=installed.origin+Vector3(-9.,-1.2,0)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=Native.new()
	if not check(native.mount(adapter,{"levels":[{"y":0.}]}),"production installer accepts actual physical nozzle coupling"):
		print(native.errors);get_tree().quit(1);return
	var floor_metrics: Node=preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var coating_finish: StandardMaterial3D=native.meshes.F015.surface_get_material(0)
	for identity: String in ["F012","F013","F014","F015"]:
		floor_metrics._check_cap_mapping(native.meshes[identity],true)
		check(native.meshes[identity].surface_get_material(0)==coating_finish,"case coating shares original registered lining finish: "+identity)
	check(coating_finish.normal_enabled and not coating_finish.uv1_triplanar,"all native case coatings use authored UVs and active normal mapping")
	for texture: Texture2D in [coating_finish.albedo_texture,coating_finish.roughness_texture,coating_finish.normal_texture]:check(texture!=null and texture.get_image().get_mipmap_count()>0,"actual loaded case coating PBR map retains mip chain")
	for failure: String in floor_metrics.failures:check(false,failure)
	floor_metrics.free()
	if not failures.is_empty():get_tree().quit(1);return
	if OS.get_environment("ORISON_FIRE_FLOOR_PREFLIGHT")=="1":
		print("NATIVE CASE FLOOR LOADED UV: PASS");get_tree().quit(0);return
	var actor: Node3D=native.stations.values()[0].get_ref()
	var joint: Node3D=actor._nozzle_joint
	var initial_mechanism: Dictionary=actor.mechanism_snapshot()
	var seated: Dictionary=initial_mechanism.duplicate(true)
	seated.facts.nozzle_coupled=true
	var seated_origin: Vector3=joint.thread_pose(0.,0.).origin
	seated.nozzle={"angle":0.,"spin":0.,"clocking":0.,"loose":false,"position":[seated_origin.x,seated_origin.y,seated_origin.z]}
	if not check(actor.valid_mechanism(seated),"ancestor regression starts from a valid seated mechanism"):
		get_tree().quit(1);return
	actor.restore_mechanism(seated)
	var original_frame: Transform3D=adapter.root.global_transform
	for shifted in [true,false]:
		adapter.root.global_transform=original_frame*Transform3D(Basis(Vector3.UP,.13),Vector3(.11,0,.07)) if shifted else original_frame
		for frame in 3:await get_tree().physics_frame
		var published: Transform3D=PhysicsServer3D.body_get_state(joint.body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)
		check(published.is_equal_approx(joint.body.global_transform),"ancestor movement publishes the seated nozzle body to physics")
		for index: int in joint._lever_shapes:
			var lever_shape: CollisionShape3D=joint.body.get_child(index)
			var physical: Transform3D=published*PhysicsServer3D.body_get_shape_transform(joint.body.get_rid(),index)
			for row: Dictionary in joint._lever_rows:
				if row.shape==lever_shape:check(physical.is_equal_approx(row.draw.global_transform),"ancestor movement keeps original lever physics at its native draw")
	actor.restore_mechanism(initial_mechanism)
	var facts: Dictionary=actor.maintenance_snapshot();facts.door_open=true;actor.restore_maintenance_snapshot(facts)
	for frame in range(15):await get_tree().physics_frame
	check(joint.loose and not actor.nozzle_coupled and joint.body.position.y<joint.receiver.origin.y-.01,"unthreaded original nozzle starts at its authored rest pose")
	player=PlayerController.new();player.position=Vector3(-.1,.025,1.15);add_child(player);player.set_lamp_enabled(false);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if OS.get_environment("ORISON_NOZZLE_WORLD_POSE")=="1":player.global_position=actor.to_global(Vector3(-.1,-1.175,1.15))
	await get_tree().physics_frame;await get_tree().physics_frame
	var hand: Node=Hand.PatrolHand.new();hand.player=player;add_child(hand)
	# The standalone programme includes the installed review's actual valve
	# closure, after entering its supported inspection camera.
	OS.set_environment("ORISON_NOZZLE_CLOSED_VALVE","1")
	await exercise_nozzle(actor,hand)
	if not failures.is_empty():get_tree().quit(1);return
	await exercise_fps_carry(actor)
	if not failures.is_empty():get_tree().quit(1);return
	# Exercise the composed review's failed restoration rays in this small
	# fixture, including its exact installed frame when requested. A passing
	# isolated result does not qualify the full world's broadphase lifecycle.
	var capture_pose: Dictionary=actor.mechanism_snapshot()
	actor.restore_mechanism(initial_mechanism)
	await RenderingServer.frame_post_draw
	await get_tree().physics_frame;await get_tree().physics_frame
	check(actor.mechanism_snapshot()==initial_mechanism and not actor.door_open,"post-input fixture restores the original closed mechanism")
	var centre:=PhysicsRayQueryParameters3D.create(actor.to_global(Vector3(0,.390,.60)),actor.to_global(Vector3(0,.390,0)),1,[player.get_rid()])
	var patch:=PhysicsRayQueryParameters3D.create(actor._door_pivot.to_global(Vector3(-.4,.1,.035)),actor._door_pivot.to_global(Vector3(-.4,.1,-.035)),1,[player.get_rid()])
	for query: PhysicsRayQueryParameters3D in [centre,patch]:
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.collider==actor._bodies.door,"restored closed leaf answers the actual "+("assembly-centre" if query==centre else "exposed-patch")+" ray")
		if hit.is_empty() or hit.collider!=actor._bodies.door:
			print("ISOLATED CLOSED LEAF: actor=",actor.global_transform," leaf=",actor._door_pivot.global_transform," server=",PhysicsServer3D.body_get_state(actor._bodies.door.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)," hit=",hit)
	if not failures.is_empty():get_tree().quit(1);return
	actor.restore_mechanism(capture_pose)
	await RenderingServer.frame_post_draw
	await get_tree().physics_frame;await get_tree().physics_frame
	check(actor.mechanism_snapshot()==capture_pose,"closed-leaf diagnostic restores the original nozzle capture pose")
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
	for child: Node in get_children():child.free()
	await get_tree().physics_frame
	if OS.get_environment("ORISON_NOZZLE_PICKUP_ONLY")=="1":get_tree().quit(0);return
	# One engine launch: new actual coupling programme, all fitted stock, and
	# every retained cabinet/washer/door/valve input path.
	var folds: Node3D=load("res://tests/v2_fire_fold_bench.gd").new();add_child(folds)

func exercise_fps_carry(actor: Node3D) -> void:
	var joint: Node3D=actor._nozzle_joint
	var saved_player: Transform3D=player.global_transform
	var saved_camera: Transform3D=player.camera.transform
	await aim(actor._play_pipe.to_global(Vector3(0,.155,.014)));click()
	if not check(player._grab.active() and player._grab.holding_pickup(),"primary FPS click holds the detached nozzle in hand"):return
	for frame in 30:await get_tree().physics_frame
	var start: Vector3=player.global_position
	Input.action_press("move_right")
	for frame in 30:await get_tree().physics_frame
	Input.action_release("move_right")
	for frame in 30:await get_tree().physics_frame
	check(player.global_position.distance_to(start)>.75,"actual movement carries the player away from the cabinet")
	var held: bool=player._grab.active()
	var distance: float=INF
	if held:distance=actor._play_pipe.to_global(player._grab.contact).distance_to(player.camera.to_global(Vector3(.17,-.16,-.48)))
	print("FPS NOZZLE FOLLOW: held=",held," hand_error=",distance," player=",player.global_position)
	check(held and distance<.03,"loose nozzle follows the FPS hand while walking instead of remaining tethered to its socket")
	if held:click()
	check(joint.body.transform.is_equal_approx(joint.rest_pose()) and not actor.nozzle_coupled,"second FPS click returns the loose part to its authored rest without repairing it")
	player.global_transform=saved_player;player.camera.transform=saved_camera;player.velocity=Vector3.ZERO

func exercise_nozzle(actor: Node3D,hand: Node) -> void:
	var joint: Node3D=actor._nozzle_joint
	var original: Dictionary=actor.mechanism_snapshot()
	await aim(actor._tag.to_global(Vector3(0,0,.0035)));click();key(KEY_SPACE)
	if not check(player.inspecting() and player.inspect_owner==actor,"actual grabbed tag opens static service inspection"):return
	if OS.get_environment("ORISON_VISIBLE_UNION_PROBE")=="1":await surface_pick_controls(actor._joint_nut)
	if OS.get_environment("ORISON_NOZZLE_CLOSED_VALVE")=="1":
		if not check(await inspect_operate(hand,actor._lever,actor._lever.to_global(Vector3(.07,0,0)),0.),"actual input closes nozzle valve before carrying review"):return
	var eye: Transform3D=player.camera.global_transform
	var point: Vector3=actor._play_pipe.to_global(Vector3(0,.155,.014))
	check(await carry_part(actor,actor._play_pipe,point,joint.body.position+Vector3(.08,.06,.08),.0001),"actual grab and depth wheel move the separate nozzle")
	check(joint.body.transform.is_equal_approx(joint.rest_pose()) and joint.loose and not actor.nozzle_coupled,"release parks the loose nozzle without sealing the joint")
	if await acquire_surface(actor._play_pipe,actor._play_pipe.to_global(Vector3(0,.155,.014))):
		click()
		var before: Basis=joint.body.basis
		var rotate:=InputEventMouseButton.new();rotate.button_index=MOUSE_BUTTON_RIGHT;rotate.pressed=true;player._unhandled_input(rotate)
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(18,-12);player._unhandled_input(motion)
		rotate.pressed=false;player._unhandled_input(rotate)
		check(player._grab.active() and not joint.body.basis.is_equal_approx(before),"actual right-drag rotates the grabbed nozzle in two directions")
		if player._grab.active():click()
		check(joint.body.transform.is_equal_approx(joint.rest_pose()),"release restores the authored resting orientation")
	else:check(false,"rotation acquires the actual nozzle surface")
	var inlet: Transform3D=joint.seat.global_transform
	check(await inspect_operate(hand,joint.nut,joint.nut.to_global(Vector3(0,.020,.027)),1.1),"empty captured nut turns through actual mouse input")
	check(joint.loose and not actor.nozzle_coupled and joint.seat.global_transform.is_equal_approx(inlet),"empty nut movement leaves the fixed inlet and repair authority alone")
	point=actor._play_pipe.to_global(Vector3(0,.155,.014))
	var approach: Vector3=joint.guide_pose().origin+Vector3(.003,.004,.003)
	if not check(await carry_part(actor,actor._play_pipe,point,approach,.00009),"actual mouse reaches an intentionally imprecise fitting approach"):return
	check(joint.body.transform.is_equal_approx(joint.guide_pose()) and joint._on_pilot(),"release snaps and aligns the spigot at its receiving brass fitting")
	check(joint.loose and not actor.nozzle_coupled,"snapped placement does not engage the thread or certify repair")
	var piloted: Dictionary=actor.mechanism_snapshot()
	check(actor.valid_mechanism(piloted),"snapped loose pose passes the existing household schema")
	actor.restore_mechanism(piloted)
	for frame in 30:await get_tree().physics_frame
	check(actor.mechanism_snapshot()==piloted,"snapped saved pose stays exact without a simulation pass")
	if not check(await pickup_with_mouse(joint),"actual tightening gesture engages the original thread after snapped placement"):return
	check(await inspect_operate(hand,joint.nut,joint.nut.to_global(Vector3(0,.020,.027)),0.),"actual mouse screws the nozzle along the native pitch to the seal")
	check(actor.nozzle_coupled and not actor.tag_signed,"completed thread travel alone changes the nozzle coupling fact")
	check(joint.seat.global_transform.is_equal_approx(inlet),"thread travel preserves the fixed hose inlet")
	var saved: Dictionary=actor.mechanism_snapshot()
	check(actor.valid_mechanism(saved),"coupled pose and existing fields pass save validation")
	var fault: Dictionary=actor.maintenance_snapshot().duplicate(true)
	fault.nozzle_coupled=false;actor.restore_maintenance_snapshot(fault)
	check(joint.loose and joint.body.transform.is_equal_approx(joint.rest_pose()),"restored disconnected fact parks the nozzle immediately without simulation")
	actor.restore_mechanism(saved)
	check(actor.mechanism_snapshot()==saved,"original coupled record restores after the disconnected fixture")
	var bad: Dictionary=saved.duplicate(true);bad.nozzle.angle=joint.stock.maximum_angle()+1.
	check(not actor.valid_mechanism(bad),"saved overtravel remains invalid")
	bad=saved.duplicate(true);bad.facts.nozzle_coupled=false
	check(not actor.valid_mechanism(bad),"saved repair facts cannot contradict the actual seal")
	check(await inspect_operate(hand,joint.nut,joint.nut.to_global(Vector3(0,.020,.027)),3.2),"actual mouse leaves a partial thread")
	check(not actor.nozzle_coupled and absf(joint.body.position.distance_to(joint.thread_pose(0.).origin)-float(joint.stock.data.dimensions.pitch_m)*3.2/TAU)<.000001,"partial withdrawal retains measured thread pitch")
	actor.restore_mechanism(saved)
	check(actor.mechanism_snapshot()==saved,"coupled pose and original mechanism fields restore exactly")
	check(await inspect_operate(hand,joint.nut,joint.nut.to_global(Vector3(0,.020,.027)),joint.stock.maximum_angle()),"actual input fully unthreads the nozzle")
	point=actor._play_pipe.to_global(Vector3(0,.155,.014))
	check(await carry_part(actor,actor._play_pipe,point,joint.rest_pose().origin+Vector3(.005,-.004,.005),.00009),"actual grab removes and parks the same nozzle")
	var parked: Dictionary=actor.mechanism_snapshot()
	actor.restore_mechanism(parked)
	for frame in 30:await get_tree().physics_frame
	check(joint.loose and joint.body.transform.is_equal_approx(joint.rest_pose()) and actor.mechanism_snapshot()==parked,"restored parked nozzle stays fixed without gravity or support searches")
	check(player.camera.global_transform.is_equal_approx(eye),"all translation, rotation and snapping preserve the inspection camera")
	actor.restore_mechanism(original)
	key(KEY_ESCAPE)
