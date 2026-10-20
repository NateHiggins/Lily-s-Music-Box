extends "res://tests/orison_v2_roof_bulkhead_caps_test.gd"
## Imported surfaces, actual hand turns, supplied water and mechanism restore.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var factory:=preload("res://scripts/building/orison_v2_kitchen_plumbing.gd").new()
	check(factory.load_source(),"native plumbing source and partitions loaded")
	for mesh: Mesh in factory.meshes.values():_check_cap_mapping(mesh,true)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-25,145,0);sun.light_energy=1.3;add_child(sun)
	var player:=PlayerController.new();add_child(player);player.set_physics_process(false);player.set_lamp_enabled(false);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if player.carried_device!=null:player.carried_device.set_capture_hidden(true)
	var hand:=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand.new();add_child(hand);hand.player=player
	var materials: Dictionary={}
	for identity: String in ["Standard410","Compact430Timber"]:
		var template:=factory.template_for(identity)
		var sink:=preload("res://scripts/building/orison_v2_kitchen_sink.gd").new();sink.fixture="kitchen_sink";sink.prop_type="sink";sink.unit="2A";sink.compact_kitchen=bool(template.compact);sink.has_drainboard=not bool(template.compact);add_child(sink)
		check(preload("res://scripts/building/orison_v2_sink.gd").new().mount(sink),"retained hollow bowl collision mounted: "+identity)
		var owner: Node3D=factory.install(sink,template)
		player.position=Vector3(0,-1.02,-.9);player.camera.look_at(owner.to_global(Vector3(0,.345,.17)))
		await get_tree().physics_frame;await get_tree().physics_frame
		sink.set_boiler_temperature(.8);sink.set_stopper(true);sink.set_hot(true);sink.set_cold(true)
		var upper: Dictionary=sink.mechanism_snapshot()
		check(is_equal_approx(sink.get_flow_state().temperature,.4),"both supplied valves mix retained boiler temperature")
		for index in 2:
			var wheel: Node3D=owner.wheels[index]
			var point: Vector3=wheel.to_global(Vector3(.021,0,-.004))
			check(await hand.operate(point,0.,sink),"actual mouse closes two-turn service stop: "+str(index)+identity)
			check(is_zero_approx(owner.openings[index]),"stop reaches closed mechanical end")
			check(sink.mechanism_snapshot().hot==upper.hot and sink.mechanism_snapshot().cold==upper.cold,"service stop does not turn the faucet knobs")
			if index==0:check(sink.get_flow_state().hot==false and sink.get_flow_state().cold and is_zero_approx(sink.get_flow_state().temperature),"hot isolation leaves only cold flow")
		check(is_zero_approx(sink.get_flow_state().flow) and not sink._stream.visible,"both service stops close stream and supplied flow")
		var water: float=sink._water_level
		await get_tree().create_timer(.15).timeout
		check(is_equal_approx(sink._water_level,water),"closed supplied stops cannot fill plugged basin")
		var snapshot: Dictionary=owner.mechanism_snapshot();check(owner.valid_mechanism(snapshot),"stop positions validate for existing household mechanism domain")
		var invalid:=snapshot.duplicate();invalid.hot=NAN;check(not owner.valid_mechanism(invalid),"nonfinite service position rejected")
		owner.restore_mechanism({"hot":.5,"cold":.25})
		check(is_equal_approx(sink.get_flow_state().hot_opening,.5) and is_equal_approx(sink.get_flow_state().cold_opening,.25),"fractional supplies restore through retained faucet authority")
		check(is_equal_approx(sink.get_flow_state().temperature,.8*.5/.75),"fractional supplied mixture follows actual hot/cold flow")
		owner.restore_mechanism(snapshot)
		for index in 2:
			var point: Vector3=owner.wheels[index].to_global(Vector3(.021,0,-.004))
			check(await hand.operate(point,owner.TRAVEL,sink),"actual mouse reopens service stop: "+str(index)+identity)
		check(is_equal_approx(sink.get_flow_state().flow,1.) and sink._stream.visible,"opening supplies restores flow without another faucet gesture")
		check(hand.follows_cursor,"handwheel follows the visible mouse direction")
		var wheel: Node3D=owner.wheels[0];player.camera.look_at(wheel.to_global(Vector3(.021,0,-.004)))
		await get_tree().physics_frame;await get_tree().physics_frame;hand.click()
		check(player._grab.active() and player._grab.target.owner==sink,"service wheel retains the original faucet hand context before inspection")
		check(player.begin_inspection(),"existing static-camera inspect function admits under-sink service pose")
		var anchor:=player.camera.global_transform
		await get_tree().physics_frame
		check(player.inspecting() and player.camera.global_transform.is_equal_approx(anchor) and not player._grab.active(),"inspection releases hand and retains static camera with cursor")
		player.end_inspection();check(not player.inspecting(),"backing out restores normal hand mode")
		for draw: MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
			var material:=draw.get_active_material(0) as StandardMaterial3D
			check(material!=null and not material.uv1_triplanar and material.normal_enabled,"plumbing uses authored UV and normal maps")
			if materials.has(material.albedo_texture.resource_path):continue
			materials[material.albedo_texture.resource_path]=true
			for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
				var image: Image=texture.get_image() if texture!=null else null
				check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(maxi(image.get_width(),image.get_height()))/log(2.))),"loaded custom plumbing map has complete mip chain")
		player.camera.global_position=sink.to_global(Vector3(.65,.6,-1.3));player.camera.look_at(sink.to_global(Vector3(0,.58,.1)))
		await RenderingServer.frame_post_draw;await shot("plumbing_"+identity)
		sink.free()
	hand.free();player.free();sun.free();env.free()
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("bench.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Imported surface/mip and actual mouse/supplied-flow/inspect/restore bench; not composed runtime acceptance","checks":checks,"failures":failures},"\t"))
	print("KITCHEN PLUMBING BENCH: checks=",checks," failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
