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
	if OS.get_environment("WEATHER_RESOURCE_SCOPE_CONTROL")=="1":
		resource_scope_control()
		return
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
	if OS.get_environment("WEATHER_PRECIP_REVIEW")=="1":
		await precipitation_review(world,manager,output)
		world.shutdown_for_tests();world.free();await get_tree().process_frame
		print("PLAYABLE PRECIPITATION REVIEW: ","PASS" if failures.is_empty() else "FAIL")
		get_tree().quit(0 if failures.is_empty() else 1);return
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

func borrow_process_noise() -> void:
	var source:=preload("res://scripts/building/weather_noise.gd")
	if source.cached!=null:lifecycle_borrowed[source.cached.get_instance_id()]="process weather noise cache"
	# Exact resources owned by the production static cache, not every 3D texture.
	for key: String in ["base","curl"]:
		var volume:=source.fluid.get(key) as ImageTexture3D
		if volume==null:continue
		lifecycle_borrowed[volume.get_instance_id()]="process cloud-fluid noise cache: "+key

func resource_scope_control() -> void:
	var source:=preload("res://scripts/building/weather_noise.gd")
	source.load_volume();source.load_fluid();borrow_process_noise()
	track_resource(source.cached);track_resource(source.fluid)
	lifecycle_check(lifecycle_resources.is_empty() and lifecycle_borrowed.size()==3,"only the three exact production noise cache resources are borrowed")
	var owned:=ImageTexture3D.new()
	var slices: Array[Image]=[Image.create_empty(1,1,false,Image.FORMAT_R8)]
	lifecycle_check(owned.create(Image.FORMAT_R8,1,1,1,false,slices)==OK,"non-cache volume fixture uploads")
	track_resource(owned)
	lifecycle_check(remaining(lifecycle_resources)==1 and not lifecycle_borrowed.has(owned.get_instance_id()),"an unpathed volume outside the cache remains runtime-owned")
	owned=null
	lifecycle_check(remaining(lifecycle_resources)==0,"runtime-owned negative control retires when its owner releases it")
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("resource_scope.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":lifecycle_observations,"failures":failures,"borrowed":lifecycle_borrowed},"\t"))
	get_tree().quit(0 if failures.is_empty() else 1)

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
	borrow_process_noise()
	var plant: Resource=MatLib.get_mat("plant")
	lifecycle_borrowed[plant.get_instance_id()]="process material catalogue plant"
	track_weather_node(world.get_node("WakingAtmosphere"))
	track_weather_node(world.get_node("WeatherFX"))
	lifecycle_check(world.get_node("WeatherFX").gpu_emitters.size()==6,"all camera precipitation, contact-splash and physical frog emitters are tracked")
	track_weather_node(world.get_node("WeatherFX").precipitation_contact)
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
		"blood_rain":manager.extreme_weather.blood_rain,"frog_fall":manager.extreme_weather.frog_fall,"blood_deposit":manager.extreme_weather.blood_deposit,
		"seconds":CampaignWeather.clock_seconds(world.campaign_clock),
		"transport":Array(CampaignWeather.cloud_transport_at(CampaignWeather.clock_seconds(world.campaign_clock))),
		"timeline":CampaignWeather.timeline(world.campaign_clock.datetime_string()),"uniforms":{}}
	for key: String in ["wx_phase","wx_cyclone_phase","wx_texture_phase","wx_fluctus_phase","wx_cloud_drift","wx_asperitas_drift","wx_cirrus_drift","wx_cyclone","wx_hail","wx_whiteout","wx_blood_rain"]:
		state.uniforms[key]=manager.sky.get_shader_parameter(key)
	state["lightning_schedule"]=preload("res://scripts/building/deterministic_lightning_manager.gd").minute_strokes(float(state.seconds))
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
	var fallout_reload:=OS.get_environment("WEATHER_FALLOUT_RELOAD")=="1"
	lifecycle_check(CampaignClock.new().configure_date(1929,1,30,735) if fallout_reload else CampaignClock.new().configure_date(1929,11,7,720),"set authored weather save date")
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
		if generation==0 and OS.get_environment("SKY_LIGHTNING_WORLD")=="1":await lightning_world_review(world,output)
		if generation==0 and OS.get_environment("WEATHER_PRECIP_REVIEW")=="1":
			var saved_date: Dictionary=world.campaign_clock.local_datetime()
			var saved_seconds:=CampaignWeather.clock_seconds(world.campaign_clock)
			await precipitation_review(world,world.get_node("WakingAtmosphere").weather_manager,output)
			world.campaign_clock.configure_date(int(saved_date.year),int(saved_date.month),int(saved_date.day),int(saved_date.hour)*60+int(saved_date.minute))
			world.campaign_clock.advance_seconds(fposmod(saved_seconds,60.0));prepare_world(world)
			var restored_manager: Node=world.get_node("WakingAtmosphere").weather_manager
			restored_manager._calendar_check_left=0.0;restored_manager._phenomena_left=0.0;restored_manager._process(0.0)
		var state:=weather_state(world)
		lifecycle_states.append(state.duplicate(true))
		lifecycle_check(state.source=="campaign-calendar","actual campaign weather owner generation %d"%generation)
		lifecycle_check(float(state.uniforms.wx_cyclone)>.1,"active authored cyclone generation %d"%generation)
		if fallout_reload:lifecycle_check(float(state.blood_rain)>.99 and float(state.blood_deposit)>.9 and float(state.frog_fall)==0.0,"active crimson state reconstructs without stale frogs generation %d"%generation)
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
			"resource_scope":"Atmosphere/FX subtree stored unpathed resources, six camera GPU emitters including native frog stock, contact heightfield, lens canvas/material, extension/ramp, schedule and world clock; any audio playback in those subtrees. V2 installs no V1 AmbientSoundscape. Imported resources, exact process noise-cache identities (64-cube and fluid base/curl) and catalogue plant are borrowed. Not RenderingServer allocation accounting."}},
		"checks":lifecycle_observations,"failures":failures,"engine_errors":lifecycle_logger.get("errors"),"states":lifecycle_states,"authorities":authority_stages,"save_path":RealityState.save_path}
	FileAccess.open(output.path_join("weather_lifecycle_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	RealityState.save_path=old_path
	OS.remove_logger(lifecycle_logger)
	get_tree().quit(0 if status=="PASS" else 1)


func lightning_world_review(world: Node,output: String) -> void:
	var manager: Node=world.get_node("WakingAtmosphere").weather_manager
	var module:=preload("res://scripts/building/deterministic_lightning_manager.gd")
	var original: Dictionary=world.campaign_clock.local_datetime()
	var original_seconds:=CampaignWeather.clock_seconds(world.campaign_clock)
	var before:=authority_state()
	var row: Dictionary={}
	for candidate: Dictionary in module.minute_strokes(float(Time.get_unix_time_from_datetime_string("1929-06-25T18:01:00"))):
		if int(candidate.kind)==module.GROUND:row=candidate;break
	lifecycle_check(not row.is_empty(),"dated lightning fixture exists")
	if row.is_empty():return
	world.campaign_clock.configure_date(1929,6,25,18*60+1)
	world.campaign_clock.advance_seconds(fposmod(float(row.time),60.0)+.045)
	manager.set_process(false)
	manager._calendar_check_left=0.0;manager._phenomena_left=0.0
	manager._process(0.0);manager._publish()
	var camera: Camera3D=world.player.camera
	camera.look_at(Vector3(row.ground)+Vector3.UP*200.0)
	var weather: Dictionary=manager.current
	lifecycle_check(bool(weather.get("thunderstorm",false)),"installed weather resolves the dated thunderstorm")
	var samples: Dictionary={}
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	for phase: String in ["quiet","stroke"]:
		manager.lightning.sample(float(row.time)-1.0 if phase=="quiet" else float(row.time)+.045,weather,[])
		var frames: Array=[]
		var previous:=Time.get_ticks_usec()
		for frame in 180:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			if frame>=60:frames.append([(now-previous)/1000.0,RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())])
			previous=now
		samples[phase]=frames
		get_viewport().get_texture().get_image().save_png(output.path_join("lightning_world_"+phase+".png"))
	lifecycle_check(manager.lightning._bolt.visible and manager.lightning._light.visible,"native occupied world renders a ground bolt and one fog light")
	lifecycle_check(authority_state()==before,"lightning cannot mutate inventory, work, residents, cases or reading owners")
	var file:=FileAccess.open(output.path_join("lightning_world_frames.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"stationary occupied-world stress pair; 60 warmup +120 sampled frames each, held peak strike; not a movement route","columns":["wall_ms","render_cpu_ms","render_gpu_ms"],"frames":samples},"  "));file.close()
	world.campaign_clock.configure_date(int(original.year),int(original.month),int(original.day),int(original.hour)*60+int(original.minute))
	world.campaign_clock.advance_seconds(fposmod(original_seconds,60.0))
	manager._calendar_check_left=0.0;manager._phenomena_left=0.0;manager._process(0.0)
	manager.set_process(true)
	prepare_world(world)


func precipitation_review(world: Node,manager: Node,output: String) -> void:
	prepare_world(world);manager.set_process(false)
	var fx: Node=world.get_node("WeatherFX")
	fx.lens.get_parent().show()
	var camera: Camera3D=world.player.camera
	camera.look_at(camera.global_position+Vector3(-1,.12,.08))
	var original_authority:=authority_state()
	var samples: Array[Dictionary]=[]
	var pipeline_monitors: Dictionary={}
	for key: String in ClassDB.class_get_integer_constant_list("Performance"):
		if key.begins_with("PIPELINE_COMPILATIONS_"):
			pipeline_monitors[key]=ClassDB.class_get_integer_constant("Performance",key)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	for fixture: Dictionary in [{"name":"rain","year":1929,"month":1,"day":30,"minute":720},
		{"name":"snow","year":1928,"month":12,"day":12,"minute":720},
		{"name":"deluge_hail","year":1929,"month":8,"day":6,"minute":900},
		{"name":"blood","year":1929,"month":1,"day":30,"minute":735},
		{"name":"frogs","year":1929,"month":9,"day":12,"minute":690}]:
		var switch_started:=Time.get_ticks_usec()
		var pipeline_before: Dictionary={}
		for key: String in pipeline_monitors:pipeline_before[key]=Performance.get_monitor(pipeline_monitors[key])
		world.campaign_clock.configure_date(int(fixture.year),int(fixture.month),int(fixture.day),int(fixture.minute))
		manager._calendar_check_left=0.0;manager._phenomena_left=0.0
		manager._process(1.0);manager._publish()
		var publication_ms: float=(Time.get_ticks_usec()-switch_started)/1000.0
		if fixture.name=="blood":check(float(manager.extreme_weather.blood_rain)>.99 and float(manager.extreme_weather.blood_deposit)>.9,"crimson weather derives from its actual elapsed calendar window")
		if fixture.name=="frogs":check(float(manager.extreme_weather.frog_fall)>.99,"physical frog fallout derives from the authored waterspout window")
		var frames: Array=[];var activation_frames: Array=[];var previous:=switch_started
		for frame in 480:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			var timing: Array=[(now-previous)/1000.0,RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())]
			if frame>=360:frames.append(timing)
			var pipelines: Dictionary={}
			for key: String in pipeline_monitors:pipelines[key]=Performance.get_monitor(pipeline_monitors[key])-float(pipeline_before[key])
			activation_frames.append(timing+[Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,pipelines,fx.contact_updates,world.passage_region.residency.state])
			previous=now
		var emitters: Array=world.get_node("WeatherFX").gpu_emitters
		var emitter_states: Array=[];var visible: Array[bool]=[]
		for emitter: GPUParticles3D in emitters:
			emitter_states.append({"name":emitter.name,"emitting":emitter.emitting,"amount":emitter.amount,"ratio":emitter.amount_ratio})
			visible.append(emitter.visible);emitter.speed_scale=0.0
		check(emitters.size()>=4 and world.get_node("WeatherFX")._outdoor,"actual FPS camera uses exposed GPU precipitation: "+str(fixture.name))
		var was_processing:=fx.is_processing();fx.set_process(false)
		var lens_visible: bool=fx.lens.visible;fx.lens.hide()
		var taa:=get_viewport().use_taa;get_viewport().use_taa=false
		sky_parameter(manager,"temporal_phase",0.0)
		for emitter: GPUParticles3D in emitters:emitter.visible=false
		await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(str(fixture.name)+"_off.png"))
		for i in emitters.size():emitters[i].visible=visible[i]
		await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(str(fixture.name)+"_on.png"))
		get_viewport().use_taa=taa;fx.lens.visible=lens_visible;fx.set_process(was_processing)
		for emitter: GPUParticles3D in emitters:emitter.speed_scale=1.0
		var field_updates: int=fx.contact_updates
		if fixture.name!="snow":
			var saved_player: Transform3D=world.player.global_transform
			var saved_camera: Transform3D=camera.global_transform
			world.player.global_position=world.adapter.root.to_global(Vector3(3.0,19.25,-9.0))
			camera.look_at(camera.global_position+Vector3(-1,-.55,.08))
			for frame in 180:await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output.path_join(str(fixture.name)+"_roof_contact.png"))
			check(fx._outdoor and fx.contact_updates>0,"actual roof contact field is active: "+str(fixture.name))
			world.player.global_transform=saved_player;camera.global_transform=saved_camera
		samples.append({"date":world.campaign_clock.datetime_string(),"name":fixture.name,"conditions":manager.current.duplicate(true),"weights":str(manager.extreme_weather.weights),"blood":manager.extreme_weather.blood_rain,"frogs":manager.extreme_weather.frog_fall,"deposit":manager.extreme_weather.blood_deposit,"emitters":emitter_states,"frames":frames,"publication_ms":publication_ms,"activation_frames":activation_frames,"contact_field_updates_after_timing":field_updates,"lens_level":fx._lens_level})
	await precipitation_companion(world,manager,output)
	check(authority_state()==original_authority,"precipitation presentation preserves gameplay authorities")
	FileAccess.open(output.path_join("precipitation_review.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"actual occupied V2 with FPS-owned GPU emitters; native static rooftop camera; all 480 activation frames retained, final 120 also reported separately; existing on-disk shader cache retained, not a cold-cache qualification; off/on particles frozen for screen occupancy diagnostic; no movement route or human acceptance", "activation_columns":["wall_ms_including_publication_on_first_frame","render_cpu_ms","render_gpu_ms","process_ms","physics_ms","pipeline_deltas_since_switch","contact_field_updates","passage_residency"],"samples":samples,"failures":failures},"  "))

func precipitation_companion(world: Node,manager: Node,output: String) -> void:
	world.campaign_clock.configure_date(1929,1,30,735)
	manager._calendar_check_left=0.0;manager._phenomena_left=0.0;manager._process(1.0);manager._publish()
	var player: Node=world.player;var carrier: Node=world.service_set_carrier
	var fx: Node=world.get_node("WeatherFX")
	carrier.set_capture_hidden(false);carrier.screen_frame.layer.show()
	var pointer:=Input.mouse_mode;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for pressed in [true,false]:
		var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_DPAD_DOWN;event.pressed=pressed
		Input.parse_input_event(event);Input.flush_buffered_events()
		for frame in 3:await get_tree().process_frame
	var deadline:=Time.get_ticks_msec()+18000
	while Time.get_ticks_msec()<deadline and (not carrier.motion.steady_for_input() or carrier.device.teletype.printing):await get_tree().process_frame
	for pressed in [true,false]:
		var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_A;event.pressed=pressed
		Input.parse_input_event(event);Input.flush_buffered_events()
		for frame in 3:await get_tree().process_frame
	deadline=Time.get_ticks_msec()+18000
	while Time.get_ticks_msec()<deadline and not carrier.session.typing:await get_tree().process_frame
	check(carrier.session.typing,"native controller recall/accept opens physical keyboard during crimson rain")
	if carrier.session.typing:
		for character in "weather":
			for pressed in [true,false]:
				var event:=InputEventKey.new();event.keycode=character.to_upper().unicode_at(0);event.physical_keycode=event.keycode;event.unicode=character.unicode_at(0);event.pressed=pressed
				Input.parse_input_event(event);Input.flush_buffered_events();await get_tree().process_frame
		check(carrier.session.draft.ends_with("weather") and carrier.device.teletype._draft_ink.text.contains("weather"),"native typed draft reaches physical paper with lens moisture active")
		for frame in 60:await RenderingServer.frame_post_draw
		check(fx.lens.mouse_filter==Control.MOUSE_FILTER_IGNORE and fx.lens.get_parent().layer<carrier.screen_frame.layer.layer,"weather lens cannot own input or composite over companion paper")
		fx.set_process(false)
		for enabled in [false,true]:
			fx.lens.visible=enabled
			await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output.path_join("companion_lens_%s.png"%str(enabled)))
		fx.set_process(true)
		var cancel:=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.physical_keycode=KEY_ESCAPE;cancel.pressed=true
		Input.parse_input_event(cancel);Input.flush_buffered_events();await get_tree().process_frame
		check(not carrier.session.typing and carrier.session.draft.ends_with("weather") and player.text_input_owner==null,"native cancel preserves draft and releases only the companion input lease")
		cancel.pressed=false;Input.parse_input_event(cancel);Input.flush_buffered_events();await get_tree().process_frame
	Input.mouse_mode=pointer

func sky_parameter(manager: Node,key: String,value: Variant) -> void:
	manager.sky.set_shader_parameter(key,value)
