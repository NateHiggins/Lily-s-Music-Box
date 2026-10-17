extends Node3D
## Installed emitter checks at teleported service positions, not access proof.
const Selector := preload("res://scripts/building/building_root_selector.gd")
const Hand := preload("res://tests/heating_hand_driver.gd")
const IDS := ["F02_D_RADIATOR_01", "F03_C_RADIATOR_01", "F05_D_RADIATOR_01", "F06_D_RADIATOR_01"]
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var pointer_grabs := 0
var worlds_ready := 0
var restored := 0
var started := 0
var source_before := ""

func check(passed: bool, label: String) -> void:
	checks += 1
	observations.append({"check":label,"passed":passed})
	print("PASS: " if passed else "FAIL: ", label)
	if not passed: failures.append(label)

func digest() -> String:
	var output: Array = []
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	if OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)!=0:return ""
	return str(output[0]).strip_edges() if not output.is_empty() else ""

func _ready() -> void:
	_run.call_deferred()

func capture(world: OrisonV2RuntimeRoot, radiator: RadiatorProp, name: String, detail: bool) -> void:
	var camera := Camera3D.new();world.add_child(camera);camera.fov=55;camera.make_current()
	var fill := OmniLight3D.new();camera.add_child(fill);fill.light_energy=.6;fill.omni_range=3
	camera.global_position=radiator.to_global(Vector3(-.55,-.30,-.65) if detail else Vector3(-.9,.5,-1.5))
	camera.look_at(radiator.to_global(Vector3(-.67,-.745,0) if detail else Vector3(0,-.35,0)))
	await get_tree().create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("SHOT_DIR").path_join(name+".png")
	check(get_viewport().get_texture().get_image().save_png(path)==OK,"capture actual installed emitter: "+name)
	camera.free()

func contract(out: String) -> void:
	var after := digest()
	check(not source_before.is_empty() and source_before==after,"runtime inputs remain frozen through physical operation and disk reconstruction")
	var sources := {}
	for name: String in ["heating_refit_installation_test.gd","heating_hand_driver.gd","watch_station_hand_test.gd"]:
		sources["game/tests/"+name]=FileAccess.get_file_as_string("res://tests/"+name).replace("\r\n","\n").sha256_text()
	var status := "PASS" if failures.is_empty() else "FAIL"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Four newly installed restricted-cell radiators: actual loaded bodies, seven fixed heating batches and real PBR mipmaps; twelve pointer grab/motion/release operations; nondefault partial valve states written through existing disk save authority and restored in a fresh production world. Service positions are teleported; no walking access or human visual acceptance.",
		"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":float(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/tests/heating_refit_installation_test.gd","test_sha256":sources["game/tests/heating_refit_installation_test.gd"],"runtime_inputs_sha256":after,"test_sources":sources},
		"contracts":{"production_composition":{"executed":worlds_ready==2,"status":status},"direct_manipulation":{"executed":pointer_grabs==12,"status":status},"save_reconstruction":{"executed":worlds_ready==2 and restored==4,"status":status}},
		"checks":checks,"failures":failures,"observations":observations}
	FileAccess.open(out.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))

func _run() -> void:
	started=Time.get_ticks_msec();source_before=digest()
	var out := OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":push_error("Heating installation needs windowed SHOT_DIR");get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC;Selector.reset_for_tests("v2")
	var packed := load(Selector.scene_path()) as PackedScene
	var world := packed.instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"production V2 starts with all emitter additions")
	if world.startup_failed:world.free();contract(out);get_tree().quit(1);return
	worlds_ready+=1
	var roster: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/heating.json"))
	check(roster.network.size()==23 and roster.installed.size()==23,"all twenty-three original thermal demands have installed consumers")
	var model: Node3D = world.adapter.root.get_node("HeatingDistribution")
	var parts: Array[Node] = model.find_children("*","MeshInstance3D",true,false)
	check(parts.size()==7,"fixed heating fabric remains seven render batches")
	# Exercise the real retained shell colliders. Nearby solid controls prevent
	# missing collision geometry from falsely proving an open service passage.
	var shell: Node3D = world.adapter.root
	var physics := world.get_world_3d().direct_space_state
	for offset: Vector2 in [Vector2.ZERO,Vector2(.02,0),Vector2(-.02,0),Vector2(0,.02),Vector2(0,-.02)]:
		var query := PhysicsRayQueryParameters3D.create(shell.to_global(Vector3(8.74+offset.x,12.5,.59+offset.y)),shell.to_global(Vector3(8.74+offset.x,12.9,.59+offset.y)))
		check(physics.intersect_ray(query).is_empty(),"extended H-D main passes through actual shared slab: "+str(offset))
	var solid := PhysicsRayQueryParameters3D.create(shell.to_global(Vector3(8.85,12.5,.59)),shell.to_global(Vector3(8.85,12.9,.59)))
	check(not physics.intersect_ray(solid).is_empty(),"solid shaft/slab beside main aperture retains collision")
	var masonry := PhysicsRayQueryParameters3D.create(shell.to_global(Vector3(7.6,5.947,7.55)),shell.to_global(Vector3(6.9,5.947,7.55)))
	check(physics.intersect_ray(masonry).is_empty(),"3C supply passes through actual masonry and inner leaf")
	var masonry_solid := PhysicsRayQueryParameters3D.create(shell.to_global(Vector3(7.6,6.067,7.55)),shell.to_global(Vector3(6.9,6.067,7.55)))
	check(not physics.intersect_ray(masonry_solid).is_empty(),"masonry beside 3C service aperture retains collision")
	for part: MeshInstance3D in parts:
		var material := part.material_override as StandardMaterial3D
		check(material!=null and not material.uv1_triplanar and material.uv1_scale==Vector3.ONE,"native metric UVs remain active: "+str(part.name))
		if material!=null:
			for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
				check(texture!=null and texture.get_image()!=null and texture.get_image().has_mipmaps(),"actual loaded custom PBR mip chain: "+str(part.name))
	var hand := Hand.new();hand.player=world.player;add_child(hand)
	var expected := {}
	for index in IDS.size():
		var identity: String=IDS[index]
		var radiator := world.adapter.resolve(identity) as RadiatorProp
		check(radiator!=null and radiator._balance==world.heat_balance and radiator.graph_node_id==identity,"retained radiator and heat authority: "+identity)
		if radiator==null:continue
		var sections: int=8 if index<3 else 9
		check(radiator.section_count==sections and radiator._section_multimesh.multimesh.instance_count==sections,"actual native cast section instances: "+identity)
		world.player.set_physics_process(true);world.player.global_position=radiator.to_global(Vector3(-.53,-.73,-1.1));world.player.velocity=Vector3.ZERO
		world.player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var valve := radiator.get_node("TurnValveSurface") as Area3D
		var partial := .25+float(index)*.15
		for goal: float in [0.0,TAU*3.5,TAU*3.5*partial]:
			world.player.camera.look_at(valve.global_position)
			await get_tree().physics_frame;await get_tree().physics_frame
			hand.click()
			var grabbed: bool=world.player._grab.active() and world.player._grab.target.get("owner")==radiator
			check(grabbed,"primary click grabs the installed valve: "+identity)
			if grabbed:
				pointer_grabs+=1
				check(await hand.move_to(goal),"mouse movement turns the installed valve: "+identity)
				hand.click()
				check(not world.player._grab.active() and absf(radiator.supply_position-goal/(TAU*3.5))<.01,"release retains physical valve position: "+identity)
		if world.player._grab.active():hand.click()
		expected[identity]=partial
		check(absf(radiator.supply_position-partial)<.01,"distinct partial valve state: "+identity)
		world.player.set_physics_process(false)
		for layer in world.player.carried_device.get_children():
			if layer is CanvasLayer:layer.hide()
		await capture(world,radiator,identity+"_body",false)
		await capture(world,radiator,identity+"_supply",true)
	check(hand.follows_cursor,"installed valves follow projected pointer motion")
	hand.free()
	var original_save := RealityState.save_path
	var save_path := "user://tests/heating_refit_%s.json"%Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path).get_base_dir())
	RealityState.save_path=save_path;RealityState.persistence_enabled=true
	check(RealityState.save_game(),"existing save authority writes a real disk document")
	var disk_text := FileAccess.get_file_as_string(save_path)
	FileAccess.open(out.path_join("disk_save.json"),FileAccess.WRITE).store_string(disk_text)
	var disk: Dictionary=JSON.parse_string(disk_text)
	var records: Dictionary=disk.get("v2_household_controls",{}).get("records",{})
	for identity: String in expected:check(absf(float(records.get(identity,{}).get("value",-1))-expected[identity])<.01,"disk records the actual partial valve: "+identity)
	RealityState.persistence_enabled=false;world.shutdown_for_tests();world.free();packed=null
	await get_tree().process_frame;await get_tree().process_frame
	PropAudio.clear_cache();RealityState.reset_campaign_for_tests();RealityState.load_game()
	check(RealityState.can_continue(),"existing save authority loads the real disk document")
	Selector.reset_for_tests("v2");packed=load(Selector.scene_path()) as PackedScene;world=packed.instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"fresh production V2 reconstructs the heating installation")
	if not world.startup_failed:
		worlds_ready+=1
		for identity: String in expected:
			var radiator := world.adapter.resolve(identity) as RadiatorProp
			var preserved: bool = radiator!=null and absf(radiator.supply_position-expected[identity])<.01 and radiator._balance==world.heat_balance
			check(preserved,"fresh emitter preserves partial state and heat authority: "+identity)
			if preserved:restored+=1
	world.shutdown_for_tests();world.free();RealityState.save_path=original_save;RealityState.persistence_enabled=false
	contract(out)
	print("HEATING REFIT: ",checks," checks; ",failures.size()," failures; pointer_grabs=",pointer_grabs)
	get_tree().quit(0 if failures.is_empty() else 1)
