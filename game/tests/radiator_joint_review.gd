extends RefCounted
## Loaded rim geometry and installed appearance; no pressure certification.
func run(world: OrisonV2RuntimeRoot,suite: Node) -> void:
	var source: Dictionary=RadiatorNativeParts._load_family("mechanisms")["CastSectionThreeColumnCandidate"]
	var mesh: Mesh=source.mesh
	var points:=RadiatorNativeParts.stock_points("mechanisms","CastSectionThreeColumnCandidate")
	var rows: Array=[]
	for height in [.085,.615]:
		for side in [-1.,1.]:
			var count:=0;var largest:=0.;var smallest:=INF
			for point: Vector3 in points:
				var radius:=Vector2(point.y-height,point.z+.055).length()
				if absf(point.x-side*.046)>.0000001 or radius<.0268 or radius>.0341:continue
				count+=1;largest=maxf(largest,radius);smallest=minf(smallest,radius)
			suite.check(count>=48 and largest>.0331 and largest<.03325 and smallest>.0268 and smallest<.0271,"loaded port retains its bore and modelled outer rim round")
			rows.append({"height":height,"side":side,"vertices":count,"maximum_face_radius_m":largest,"minimum_face_radius_m":smallest})
	var inspector:=preload("res://tests/radiator_native_review.gd").new()
	var installations: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/heating.json"))
	var installed:=0
	for record: Dictionary in installations.installed:
		var radiator:=world.adapter.resolve(str(record.id)) as RadiatorProp
		suite.check(radiator!=null and radiator.native_rig!=null,"rim detail reaches installed radiator: "+str(record.id))
		if radiator==null or radiator.native_rig==null:continue
		var sections:=radiator.native_rig.body.get_node("SharedCastSections") as MultiMeshInstance3D
		suite.check(sections.multimesh.mesh==mesh and sections.multimesh.instance_count==int(record.sections),"installed sections share the current casting and preserve roster count")
		installed+=1
	suite.check(installed==23,"all 23 installed bodies use the current rim stock")
	var actor:=world.adapter.resolve("F02_B_RADIATOR_01") as RadiatorProp
	if actor==null:inspector.free();return
	var sections:=actor.native_rig.body.get_node("SharedCastSections") as MultiMeshInstance3D
	for surface in mesh.get_surface_count():inspector._check_surface(mesh,surface,sections.material_override)
	for failure: String in inspector.failures:suite.check(false,failure)
	suite.batch_checks+=inspector.checks;inspector.free()
	var player:=world.player
	var camera_before:=suite.get_viewport().get_camera_3d()
	var player_pose:=player.global_transform;var velocity_before:=player.velocity
	var camera_pose:=player.camera.global_transform;var fov_before:=player.camera.fov
	var physics_before:=player.is_physics_processing();var lamp_before:=player.lamp_is_enabled()
	var switches:=world.get_node("V2RoomSwitches") as SwitchSystem
	var circuit:=switches.room_snapshot("F02_B_MAIN").duplicate(true)
	var lit:=circuit.duplicate(true)
	for key: String in lit:lit[key]=true
	suite.check(not lit.is_empty() and switches.restore_room("F02_B_MAIN",lit),"existing room circuit powers the diagnostic; not switch-input proof")
	player.set_physics_process(false)
	player.global_position=actor.native_rig.to_global(Vector3(-.25,.04,-.95));player.velocity=Vector3.ZERO
	player.camera.global_position=actor.native_rig.to_global(Vector3(-.25,.73,-1.0))
	player.camera.look_at(actor.native_rig.to_global(Vector3(-.12,.38,-.04)));player.camera.fov=60.;player.camera.make_current()
	player.set_lamp_enabled(false)
	var deadline:=Time.get_ticks_msec()+5000
	while player.flashlight.visible and Time.get_ticks_msec()<deadline:await suite.get_tree().create_timer(.05).timeout
	suite.check(not player.flashlight.visible,"room-only radiator review has no carried-light tail")
	await suite.get_tree().create_timer(.8).timeout
	await _shot(suite,"radiator_joints_room")
	player.set_lamp_enabled(true);await suite.get_tree().create_timer(.8).timeout
	await _shot(suite,"radiator_joints_carried")
	player.set_lamp_enabled(false);deadline=Time.get_ticks_msec()+5000
	while player.flashlight.visible and Time.get_ticks_msec()<deadline:await suite.get_tree().create_timer(.05).timeout
	var half:=float(actor.section_count-1)*.092*.5
	var shift:=maxf(0.,half-.322)
	var joint_x: float=-half+shift+(floori(actor.section_count/2.)-.5)*.092
	var target:=actor.native_rig.body.to_global(Vector3(joint_x,.72,-.085))
	player.camera.global_position=target+actor.native_rig.body.global_basis*Vector3(.025,.055,-.235)
	player.camera.look_at(target);player.camera.fov=48.
	await _shot(suite,"radiator_joint_room_detail")
	var light:=OmniLight3D.new();light.name="TestOnlyRadiatorJointLight"
	light.light_color=Color.WHITE;light.light_energy=.025;light.omni_range=.65;light.shadow_enabled=true
	# The existing carried-light layer keeps this temporary diagnostic out of
	# room reflection captures without changing direct-light receiver masks.
	light.layers=player.flashlight.layers;world.add_child(light)
	for setup in [["diffuse",Vector3(.01,.08,-.22)],["grazing",Vector3(-.20,.015,-.09)]]:
		light.global_position=target+actor.native_rig.body.global_basis*setup[1]
		await suite.get_tree().create_timer(.25).timeout
		await _shot(suite,"radiator_joint_"+str(setup[0]))
	light.free()
	suite.check(switches.restore_room("F02_B_MAIN",circuit),"diagnostic restores original room circuit")
	player.global_transform=player_pose;player.velocity=velocity_before
	player.camera.global_transform=camera_pose;player.camera.fov=fov_before
	player.set_lamp_enabled(lamp_before);player.set_physics_process(physics_before)
	if is_instance_valid(camera_before):camera_before.make_current()
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("radiator_joint_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","installed":installed,"loaded_ports":rows,"scope":"Loaded cast rim, retained port datums, roster and PBR/mips; room/carried light and declared temporary lights. No pressure, disk reconstruction, human or whole-V2 acceptance."},"\t"))

func _shot(suite: Node,label: String) -> void:
	await RenderingServer.frame_post_draw
	var directory:=OS.get_environment("SHOT_DIR")
	suite.check(suite.get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"radiator joint frame: "+label)
