extends "res://tests/v2_dramatic_sky_review.gd"
## Same real V2 world, production weather owner; the only weather input is its clock.
func run() -> void:
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
