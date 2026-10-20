extends "res://tests/orison_v2_roof_bulkhead_caps_test.gd"
## Imported surface/actual mouse/loose-pose bench; composed routes are separate.
var player: PlayerController
func click() -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;player._unhandled_input(event)
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var factory:=preload("res://scripts/building/orison_v2_kitchen_prep.gd").new()
	factory.source=JSON.parse_string(FileAccess.get_file_as_string(factory.PATH))
	var model: Node3D=load(factory.source.asset).instantiate();add_child(model)
	for part: Dictionary in factory.source.parts:
		var draw:=model.find_child(part.name,true,false) as MeshInstance3D
		check(draw!=null,"native partition imported: "+str(part.name))
		if draw==null:continue
		factory.meshes[part.name]=draw.mesh;_check_cap_mapping(draw.mesh,true)
	model.free()
	var floor:=StaticBody3D.new();add_child(floor)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(6,.2,6);shape.shape=box;shape.position.y=-.1;floor.add_child(shape)
	var station:=preload("res://scripts/building/orison_v2_kitchen_prep_station.gd").new();add_child(station);station.record={"tint":[.9,.87,.8]}
	var table:=StaticBody3D.new();station.add_child(table);factory._visuals(table,"Oak120",station.record.tint,true)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,145,0);sun.light_energy=1.2;add_child(sun)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.5;add_child(environment)
	player=PlayerController.new();player.position=Vector3(0,.025,-1.1);add_child(player);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if player.carried_device!=null:player.carried_device.set_capture_hidden(true)
	player.set_lamp_enabled(false)
	for assembly: String in ["Breadboard","RollingPin","MixingBowl","SinkBridge"]:
		factory._loose(station,assembly,Vector3(0,.94,0),0.)
		var body: RigidBody3D=station.tools[assembly]
		for frame in 90:await get_tree().physics_frame
		var old:=body.position
		var point: Vector3=body.to_global(Vector3(0,.015,-.07) if assembly=="MixingBowl" else Vector3(0,.015,0))
		player.camera.look_at(point);await get_tree().physics_frame;await get_tree().physics_frame;player.camera.look_at(point)
		check(player._grab.find_target().get("owner")==station,"native tool is ray selected: "+assembly)
		click();check(player._grab.active() and station.held==body,"click grabs without toggling: "+assembly)
		for step in 8:
			var motion:=InputEventMouseMotion.new();motion.relative=Vector2(4,-12);player._unhandled_input(motion);await get_tree().physics_frame
		check(body.position.distance_to(old)>.025,"mouse moves constrained loose tool: "+assembly)
		click();check(not player._grab.active() and station.held==null,"next click releases the tool: "+assembly)
		var released_y:=body.position.y
		for frame in 40:await get_tree().physics_frame
		check(body.position.y<released_y-.01,"released tool falls onto an actual native bearing: "+assembly)
		var snapshot: Dictionary=station.mechanism_snapshot();check(station.valid_mechanism(snapshot),"loose pose validates: "+assembly)
		var bad:=snapshot.duplicate(true);bad[assembly].rotation=[0.,0.,0.,0.];check(not station.valid_mechanism(bad),"invalid rotation rejected: "+assembly)
		var saved_pose:=body.transform
		station.restore_mechanism(snapshot);check(body.transform.is_equal_approx(saved_pose),"loose pose restores without quaternion round-trip drift: "+assembly)
		for draw: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
			var material:=draw.get_active_material(0) as StandardMaterial3D
			check(material!=null and not material.uv1_triplanar and material.normal_enabled,"authored UV and normals active: "+assembly)
			for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
				var image: Image=texture.get_image() if texture!=null else null
				check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(maxi(image.get_width(),image.get_height()))/log(2.))),"complete loaded custom PBR mips: "+assembly)
		station.tools.erase(assembly);body.free()
	# A second physical tool on the board must not immobilise the held board.
	factory._loose(station,"Breadboard",Vector3(0,.9,0),0.)
	factory._loose(station,"RollingPin",Vector3(0,.95,0),0.)
	for frame in 120:await get_tree().physics_frame
	var board: RigidBody3D=station.tools.Breadboard;var pin: RigidBody3D=station.tools.RollingPin
	player.camera.look_at(board.to_global(Vector3(0,.02,-.11)));await get_tree().physics_frame;await get_tree().physics_frame
	player.camera.look_at(board.to_global(Vector3(0,.02,-.11)))
	var board_pose:=board.position;var pin_pose:=pin.position
	click();check(player._grab.active() and station.payload.has(pin),"native support ray includes the resting rolling pin")
	for step in 8:
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(0,-12);player._unhandled_input(motion);await get_tree().physics_frame
	check(board.position.distance_to(board_pose)>.025 and (pin.position-pin_pose).distance_to(board.position-board_pose)<.0001,"board and actually supported pin move together without overlap")
	click();check(not player._grab.active() and station.payload.is_empty(),"releasing the board releases its supported pin")
	for frame in 60:await get_tree().physics_frame
	check(absf(board.position.y-.9)<.00004 and absf(pin.position.y-.95)<.00004,"released board and pin meet their actual native bearings without sinking")
	player.camera.look_at(board.to_global(Vector3(0,.02,-.11)));click()
	for step in 8:
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(0,20);player._unhandled_input(motion);await get_tree().physics_frame
	check(board.position.y>=.9-.00004,"downward hand motion cannot push the thin board into its worktop")
	click()
	var airborne:=station.mechanism_snapshot();airborne.Breadboard.position=[0.,1.3,0.];airborne.RollingPin.position=[0.,1.35,0.]
	station.restore_mechanism(airborne)
	for frame in 120:await get_tree().physics_frame
	check(absf(board.position.y-.9)<.00004 and absf(pin.position.y-.95)<.00004,"restoring airborne poses resumes gravity and finds native bearings")
	var sink:=preload("res://scripts/building/orison_v2_kitchen_sink.gd").new();sink.fixture="kitchen_sink";sink.unit="5A";sink.prop_type="sink";sink.position.x=2.;add_child(sink)
	check(preload("res://scripts/building/orison_v2_sink.gd").new().mount(sink),"actual hollow sink collision mounted for the narrow rolled-rim bearing")
	var bridge_station:=preload("res://scripts/building/orison_v2_kitchen_prep_station.gd").new();bridge_station.position.x=2.;bridge_station.record=station.record;add_child(bridge_station)
	factory._loose(bridge_station,"SinkBridge",Vector3(0,.9125,-.035),0.)
	for frame in 120:await get_tree().physics_frame
	var bridge: RigidBody3D=bridge_station.tools.SinkBridge
	check(absf(bridge.position.y-.9125)<.00004,"bridge face actually bears on the native rolled sink rim instead of falling between vertex samples")
	bridge_station.free();sink.free()
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("bench.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Isolated imported native surfaces, actual player mouse input and loose pose restore; no installed spatial acceptance","checks":checks,"failures":failures},"\t"))
	print("KITCHEN PREP BENCH: failures=",failures.size())
	player.free();station.free();floor.free();sun.free();environment.free()
	get_tree().quit(0 if failures.is_empty() else 1)
