extends "res://tests/v2_dramatic_sky_review.gd"
## Same real V2 world, production weather owner; the only weather input is its clock.
var lifecycle_nodes: Array[WeakRef]=[]
var lifecycle_resources: Array[WeakRef]=[]
var lifecycle_playbacks: Array[WeakRef]=[]
var lifecycle_seen: Dictionary={}
var lifecycle_borrowed: Dictionary={}
var lifecycle_observations: Array[Dictionary]=[]
var lifecycle_states: Array[Dictionary]=[]
var lifecycle_logger: Logger

func run() -> void:
	if OS.get_environment("WEATHER_LIFECYCLE_REVIEW")=="1":
		await run_lifecycle()
		return
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	GameBoot.settings.weather_network_enabled=false
	OS.set_environment("WEATHER_SIMULATE","")
	OS.set_environment("WEATHER_FORMATION","")
	OS.set_environment("WEATHER_SKY_BASELINE","")
	CampaignClock.new().configure_date(1929,8,6,15*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=Runtime.instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"occupied V2 starts under campaign weather")
	if world.startup_failed: world.shutdown_for_tests();world.free();get_tree().quit(1);return
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	var player:=world.player
	player.set_physics_process(false);player.velocity=Vector3.ZERO
	player.global_position=Vector3(0,25,9.5)
	player.camera.look_at(player.camera.global_position+Vector3(-1,.24,0));player.camera.make_current()
	player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	world.service_set_carrier.set_capture_hidden(true)
	var manager: Node=world.get_node("WakingAtmosphere").weather_manager
	var output:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	for sample: Dictionary in [{"name":"august_hail","year":1929,"month":8,"day":6,"minute":900},
		{"name":"september_cloud","year":1929,"month":9,"day":19,"minute":1080},
		{"name":"november_coastal_storm","year":1929,"month":11,"day":7,"minute":720},
		{"name":"christmas_snow","year":1928,"month":12,"day":24,"minute":1260}]:
		world.campaign_clock.configure_date(int(sample.year),int(sample.month),int(sample.day),int(sample.minute))
		manager._process(1.0)
		# Accelerate only existing effect settling for a still; never replace conditions.
		manager._publish()
		if manager.extreme_weather!=null:manager.extreme_weather.advance(120.0)
		for frame in 120:await RenderingServer.frame_post_draw
		check(manager.source=="campaign-calendar","production calendar owner: "+str(sample.name))
		var expected:=Service.presentation(CampaignWeather.snapshot(world.campaign_clock.local_datetime()))
		check(int(manager.current.weather_code)==int(expected.weather_code),"sky consumes the actual civil date: "+str(sample.name))
		if sample.name=="november_coastal_storm":
			check(manager.extreme_weather.cyclone>.1,"coastal-storm fixture has nonzero authored cyclone")
		var path:=output.path_join(str(sample.name)+".png")
		check(get_viewport().get_texture().get_image().save_png(path)==OK,"calendar-world capture: "+str(sample.name))
		captures.append({"date":world.campaign_clock.datetime_string(),"source":manager.source,
			"conditions":manager.current.duplicate(true),"cyclone":manager.extreme_weather.cyclone,"file":path})
	FileAccess.open(output.path_join("calendar_world_review.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"occupied world, production calendar weather, static cinematic camera and accelerated effect settling; no performance or played-route qualification",
		"calendar_sha256":FileAccess.get_sha256(CampaignWeather.PATH),"captures":captures,"failures":failures},"\t"))
	world.shutdown_for_tests();world.free();await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func lifecycle_check(ok: bool,label: String) -> void:
	lifecycle_observations.append({"ok":ok,"label":label})
	check(ok,label)
	print("[WEATHER LIFECYCLE] ","PASS " if ok else "FAIL ",label)

func remaining(refs: Array[WeakRef]) -> int:
	var count:=0
	for ref in refs:
		if ref.get_ref()!=null:count+=1
	return count

func track_resource(value: Variant) -> void:
	if value is Array:
		for item: Variant in value:track_resource(item)
	elif value is Dictionary:
		for item: Variant in value.values():track_resource(item)
	elif value is Resource:
		var id: int=value.get_instance_id()
		if lifecycle_seen.has(id) or lifecycle_borrowed.has(id):return
		lifecycle_seen[id]=true
		if not value.resource_path.is_empty():
			lifecycle_borrowed[id]="path:"+value.resource_path
			return
		lifecycle_resources.append(weakref(value))
		for property: Dictionary in value.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_STORAGE:track_resource(value.get(property.name))

func track_weather_node(node: Node) -> void:
	lifecycle_nodes.append(weakref(node))
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		if node.has_stream_playback():lifecycle_playbacks.append(weakref(node.get_stream_playback()))
	for property: Dictionary in node.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_STORAGE:track_resource(node.get(property.name))
	for child: Node in node.get_children():track_weather_node(child)

func track_world_weather(world: Node) -> void:
	var noise: Resource=preload("res://scripts/building/weather_noise.gd").load_volume()
	lifecycle_borrowed[noise.get_instance_id()]="process weather noise cache"
	var plant: Resource=MatLib.get_mat("plant")
	lifecycle_borrowed[plant.get_instance_id()]="process material catalogue plant"
	track_weather_node(world.get_node("WakingAtmosphere"))
	track_weather_node(world.get_node("WeatherFX"))
	lifecycle_check(world.get_node("WeatherFX").gpu_emitters.size()==4,"all four camera precipitation emitters are tracked")
	for emitter: Node in world.get_node("WeatherFX").gpu_emitters:track_weather_node(emitter)
	var manager: Node=world.get_node("WakingAtmosphere").weather_manager
	# Non-Resource RefCounteds are explicit; never retain the actual owners here.
	for owner: RefCounted in [manager.extreme_weather,manager.schedule,world.campaign_clock]:
		lifecycle_resources.append(weakref(owner))
	track_resource(manager.extreme_weather.get("_ramp"))

func weather_state(world: Node) -> Dictionary:
	var manager: Node=world.get_node("WakingAtmosphere").weather_manager
	manager.set_process(false)
	manager._publish()
	manager._publish_extreme_motion(world.campaign_clock.local_datetime())
	var state: Dictionary={"source":manager.source,"conditions":manager.current.duplicate(true),
		"wetness":manager.extreme_weather.wetness,
		"seconds":CampaignWeather.clock_seconds(world.campaign_clock),
		"transport":Array(CampaignWeather.cloud_transport_at(CampaignWeather.clock_seconds(world.campaign_clock))),
		"timeline":CampaignWeather.timeline(world.campaign_clock.datetime_string()),"uniforms":{}}
	for key: String in ["wx_phase","wx_cyclone_phase","wx_texture_phase","wx_fluctus_phase","wx_cloud_drift","wx_asperitas_drift","wx_cirrus_drift","wx_cyclone","wx_hail","wx_whiteout"]:
		state.uniforms[key]=manager.sky.get_shader_parameter(key)
	return state

func authority_state() -> Dictionary:
	var state: Dictionary={}
	for key: String in ["maintenance_items","maintenance_jobs","work_orders","resident_trust","conversation_visits","cases","current_case_id","knowledge_flags","newspapers_collected"]:
		state[key]=RealityState.data.get(key).duplicate(true) if RealityState.data.get(key) is Dictionary or RealityState.data.get(key) is Array else RealityState.data.get(key)
	# JSON reload deliberately represents integral numbers as floats. Compare
	# exact persisted values, not Dictionary's int-versus-float type identity.
	return JSON.parse_string(JSON.stringify(state,"",true,true))

func prepare_world(world: Node) -> void:
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	world.player.set_physics_process(false)
	world.player.velocity=Vector3.ZERO
	world.player.global_position=world.adapter.root.to_global(preload("res://scripts/building/roof_weather_preview.gd").ROOF_STANCE)
	world.player.camera.look_at(world.player.camera.global_position+Vector3(-1,.24,0))
	world.player.camera.make_current()
	world.player.set_lamp_enabled(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()

func normalized_hash(path: String) -> String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_string(path).replace("\r\n","\n").to_utf8_buffer())
	return hash.finish().hex_encode()

func lifecycle_inputs() -> Dictionary:
	var root:=ProjectSettings.globalize_path("res://..").simplify_path()
	var output: Array=[]
	var head: Array=[]
	lifecycle_check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"record repository provenance")
	lifecycle_check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)==0,"bind runtime inputs")
	return {"runtime":str(output[0]).strip_edges() if not output.is_empty() else "","head":str(head[0]).strip_edges() if not head.is_empty() else "",
		"test":normalized_hash(get_script().resource_path),"logger":normalized_hash("res://tests/guide_bell_error_capture.gd"),"sky":normalized_hash("res://shaders/queens_weather_sky.gdshader")}

func run_lifecycle() -> void:
	var started:=Time.get_ticks_msec()
	lifecycle_logger=preload("res://tests/guide_bell_error_capture.gd").new()
	OS.add_logger(lifecycle_logger)
	var pointer:=Input.mouse_mode
	var initial_taa:=get_viewport().use_taa
	var initial:=lifecycle_inputs()
	var old_path:=RealityState.save_path
	var output:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	RealityState.persistence_enabled=false
	var fixture:="user://tests/weather-lifecycle/%d_%d"%[OS.get_process_id(),get_instance_id()]
	lifecycle_check(not DirAccess.dir_exists_absolute(fixture),"isolated save fixture is new")
	if DirAccess.dir_exists_absolute(fixture):
		OS.remove_logger(lifecycle_logger);get_tree().quit(1);return
	RealityState.save_path=fixture.path_join("campaign.json")
	DirAccess.make_dir_recursive_absolute(RealityState.save_path.get_base_dir())
	RealityState.reset_campaign_for_tests()
	RealityState.data.intro_complete=true
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled=false
	for key: String in ["WEATHER_SIMULATE","WEATHER_FORMATION","WEATHER_SKY_BASELINE","WEATHER_PHENOMENON"]:OS.set_environment(key,"")
	lifecycle_check(CampaignClock.new().configure_date(1929,11,7,720),"set authored coastal-storm date")
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var before: Dictionary={}
	var authority: Dictionary={}
	var authority_stages: Array[Dictionary]=[]
	var reconstructed:=false
	var denial:=false
	for generation in 2:
		var world:=Runtime.instantiate() as OrisonV2RuntimeRoot
		add_child(world)
		await get_tree().physics_frame;await get_tree().physics_frame
		lifecycle_check(not world.startup_failed,"production V2 starts generation %d"%generation)
		if world.startup_failed:world.shutdown_for_tests();world.free();break
		prepare_world(world)
		if generation==0:
			world.campaign_clock.advance_seconds(.75)
			# Public-owner fixtures, not claims of played acquisitions or dialogue.
			lifecycle_check(world.maintenance_inventory.grant("fire_hose_spare_gasket","hardware_paint"),"seed real catalogue stock through inventory owner")
			lifecycle_check(world.work_orders.issue_job("vantry_chirp_2a","reported"),"seed an authored job through WorkOrders")
			lifecycle_check(RealityCases.activate_case("mina_caption_crisis"),"seed an authored active case through RealityCases")
			RealityState.add_resident_trust("mina_vale",2)
			RealityState.record_conversation_visit("mina_vale")
			lifecycle_check(world.newspapers.collect("record","1928-11-10"),"seed a historical edition through collection owner")
		var state:=weather_state(world)
		lifecycle_states.append(state.duplicate(true))
		lifecycle_check(state.source=="campaign-calendar","actual campaign weather owner generation %d"%generation)
		lifecycle_check(float(state.uniforms.wx_cyclone)>.1,"active authored cyclone generation %d"%generation)
		lifecycle_check(Input.mouse_mode==pointer,"inactive saved world leaves pointer unchanged generation %d"%generation)
		for frame in 30:await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("lifecycle_%d.png"%generation))
		if generation==0:
			var manager: Node=world.get_node("WakingAtmosphere").weather_manager
			var events: Dictionary=manager._extreme_events.duplicate(true)
			denial=not manager.set_extreme_event({"cyclone":2.0}) and manager._extreme_events==events
			lifecycle_check(denial,"invalid extreme-event request is refused without mutation")
			for bulletin: Dictionary in state.timeline:lifecycle_check(str(bulletin.issued_at)<=world.campaign_clock.datetime_string(),"timeline excludes future issues")
			lifecycle_check(RealityState.save_game(),"validated campaign writes actual isolated disk save")
			before=state;authority=authority_state()
			authority_stages.append({"stage":"saved","state":authority.duplicate(true)})
		else:
			reconstructed=state==before
			for key: String in state:
				if state[key]!=before[key]:print("[WEATHER RELOAD DIFFERENCE] ",key," before=",before[key]," after=",state[key])
			lifecycle_check(reconstructed,"disk reconstruction retains fractional time, transport, storm uniforms and issued timeline")
			var rebuilt_authority:=authority_state()
			authority_stages.append({"stage":"rebuilt","state":rebuilt_authority})
			for key: String in authority:
				if rebuilt_authority[key]!=authority[key]:print("[AUTHORITY RELOAD DIFFERENCE] ",key," before=",authority[key]," after=",rebuilt_authority[key])
			lifecycle_check(rebuilt_authority==authority,"weather rebuild preserves inventory, work orders, residents, cases and reading authorities")
		track_world_weather(world)
		world.shutdown_for_tests();world.free()
		await get_tree().process_frame;await get_tree().process_frame
		lifecycle_check(get_tree().get_nodes_in_group("weather_manager").is_empty(),"weather owner retires generation %d"%generation)
		lifecycle_check(remaining(lifecycle_nodes)==0,"tracked weather nodes retire generation %d"%generation)
		lifecycle_check(remaining(lifecycle_resources)==0,"tracked weather resources retire generation %d"%generation)
		lifecycle_check(remaining(lifecycle_playbacks)==0,"tracked weather playbacks retire generation %d"%generation)
		lifecycle_check(get_viewport().use_taa==initial_taa,"weather restores prior viewport TAA generation %d"%generation)
		if generation==0:
			RealityState.reset_campaign_for_tests();RealityState.load_game()
			var loaded_authority:=authority_state()
			authority_stages.append({"stage":"loaded","state":loaded_authority})
			for key: String in authority:
				if loaded_authority[key]!=authority[key]:print("[AUTHORITY DISK DIFFERENCE] ",key," before=",authority[key]," after=",loaded_authority[key])
			lifecycle_check(not RealityState.save_write_blocked and RealityState.data.intro_complete,"validated disk load restores arrived campaign")
	var final_inputs:=lifecycle_inputs()
	lifecycle_check(initial==final_inputs,"test, runtime and sky shader unchanged during run")
	lifecycle_check(lifecycle_logger.get("errors").is_empty(),"no engine, script or shader errors during lifecycle")
	var status:="PASS" if failures.is_empty() and reconstructed and denial else "FAIL"
	var receipt: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Actual V2 child-world composition, arrived campaign disk save/load and rebuild, fractional calendar weather, invalid event denial and exact tracked weather ownership. No CampaignShell, native manipulation, performance route or whole-game acceptance.",
		"execution":{"completed":true,"exit_code":0 if status=="PASS" else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/"+get_script().resource_path.trim_prefix("res://"),"test_sha256":initial.test,"repository_head":initial.head,"runtime_inputs_sha256":initial.runtime,"sky_shader_lf_sha256":initial.sky,"error_capture_lf_sha256":initial.logger},
		"contracts":{"production_composition":{"executed":not before.is_empty(),"status":status,"identities":["WakingAtmosphere/WeatherManager","WeatherFX","CampaignClock"]},"save_reconstruction":{"executed":reconstructed,"status":status},"premature_action_denial":{"executed":denial,"status":status},
			"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":remaining(lifecycle_nodes),"retained_resources":remaining(lifecycle_resources),"retained_playbacks":remaining(lifecycle_playbacks),
			"tracked_nodes":lifecycle_nodes.size(),"tracked_resources":lifecycle_resources.size(),"tracked_playbacks":lifecycle_playbacks.size(),"borrowed":lifecycle_borrowed,
			"resource_scope":"Atmosphere/FX subtree stored unpathed resources, four camera GPU emitters, extension/ramp, schedule and world clock; any audio playback in those subtrees. V2 installs no V1 AmbientSoundscape. Imported resources, process noise and catalogue plant are borrowed. Not RenderingServer allocation accounting."}},
		"checks":lifecycle_observations,"failures":failures,"engine_errors":lifecycle_logger.get("errors"),"states":lifecycle_states,"authorities":authority_stages,"save_path":RealityState.save_path}
	FileAccess.open(output.path_join("weather_lifecycle_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	RealityState.save_path=old_path
	OS.remove_logger(lifecycle_logger)
	get_tree().quit(0 if status=="PASS" else 1)
