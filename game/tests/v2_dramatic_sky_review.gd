extends Node
## INERT actual-world art review. Authored showcase states, not random API
## occurrence, played movement, performance qualification or human acceptance.
const Runtime=preload("res://scenes/building/orison_v2_runtime.tscn")
const Service=preload("res://scripts/building/live_weather_service.gd")
var failures: Array[String]=[]
var captures: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func _ready() -> void:run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Sky review requires a windowed renderer");get_tree().quit(2);return
	var output:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,7,31,17*60+30)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=Runtime.instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"actual V2 world starts for sky review")
	if world.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	var player:=world.player
	player.set_physics_process(false);player.velocity=Vector3.ZERO;player.global_position=Vector3(0,.03,9.5)
	player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	world.service_set_carrier.set_capture_hidden(true)
	var atmosphere:=world.get_node("WakingAtmosphere")
	var manager: Node=atmosphere.weather_manager
	manager.set_process(false)
	var extension: RefCounted=manager.extreme_weather
	check(extension!=null,"integrated weather extension is installed")
	if extension==null:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	var sky: ShaderMaterial=atmosphere.sky_material
	check(world.find_children("StormCurtain_*","MeshInstance3D",true,false).is_empty(),"road-end fog cards are absent")
	check(world.get_node_or_null("StreetBoundaries/RetainedStreetEnds") == null,"retired street-end stock has no invisible road collider")
	for side in [-1.0,1.0]:
		var ray:=PhysicsRayQueryParameters3D.create(Vector3(side*19,1.2,9.5),Vector3(side*23,1.2,9.5),1<<20)
		check(world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"old road mouth is physically open")
		var ground:=PhysicsRayQueryParameters3D.create(Vector3(side*23,1.0,9.5),Vector3(side*23,-1.0,9.5),1)
		check(not world.get_world_3d().direct_space_state.intersect_ray(ground).is_empty(),"retained road grade continues beyond old fog")
	sky.set_shader_parameter("wx_vortex_center",Vector2(-3.5,.0095))
	sky.set_shader_parameter("wx_cyclone_center",Vector2(-6,.0095))
	sky.set_shader_parameter("wx_lens_center",Vector3(-5.5,3.0,.0095))
	# Static cinematic review station above the existing roofs. This is a
	# rendering composition, never evidence of player access to this height.
	player.global_position=Vector3(0,25.0,9.5)
	player.camera.fov=72.0;player.camera.make_current()
	for state: String in ["green_hail","cyclone_funnel","asperitas_amber","lenticular_dusk","nacreous_twilight"]:
		var preset:="hail_storm" if state=="green_hail" else ("storm" if state=="cyclone_funnel" else "scattered")
		manager.current=Service.presentation(Service.simulated_snapshot(preset))
		manager.current["pressure_hpa"]=1025.0
		manager.current["wind_speed_kmh"]=5.0 if preset=="scattered" else 35.0
		manager.current["cloud_total"]=.10 if state in ["lenticular_dusk","nacreous_twilight"] else .85
		manager.current["cloud_low"]=manager.current.cloud_total
		manager.current["cloud_high"]=.9 if state=="nacreous_twilight" else .12
		manager.target=manager.current.duplicate(true);manager.origin=manager.current.duplicate(true)
		manager.elapsed=manager.TRANSITION_SECONDS
		manager.set_extreme_event({"cyclone":.8,"tornado":1.0} if state=="cyclone_funnel" else {})
		var formation:="asperitas" if state=="asperitas_amber" else ("lenticular" if state=="lenticular_dusk" else ("nacreous" if state=="nacreous_twilight" else ""))
		OS.set_environment("WEATHER_FORMATION",formation)
		manager._publish();extension.advance(180.0);extension.advance(40.0)
		# Use the real ephemeris and campaign authority to choose the afternoon
		# or just-below-horizon light for this explicit authoring review.
		var best:=0;var error:=INF
		for minute in range(16*60,21*60,2):
			world.campaign_clock.configure_date(1928,7,31,minute)
			var sun: Vector3=preload("res://scripts/building/celestial_ephemeris.gd").sun_direction(world.campaign_clock.utc_datetime(),40.75,-73.92)
			var candidate:=absf(sun.y-(-.055 if state=="nacreous_twilight" else .13))
			if candidate<error:error=candidate;best=minute
		world.campaign_clock.configure_date(1928,7,31,best)
		manager._publish()
		extension.publish(sky,player.camera.global_position,world.get_node("WeatherFX").air_material)
		var pitch:=.32
		if state=="asperitas_amber":pitch=1.10
		elif state=="lenticular_dusk":pitch=.58
		elif state not in ["nacreous_twilight"]:pitch=.14
		var direction:=Vector3(-1,pitch,0)
		player.camera.look_at(player.camera.global_position+direction)
		for frame in 120:await RenderingServer.frame_post_draw
		var path:=output.path_join(state+".png")
		check(get_viewport().get_texture().get_image().save_png(path)==OK,"capture "+state)
		captures.append({"name":state,"file":path,"campaign_minute":best,"profile":world.day_night_director.resolved_profile(),"weights":str(extension.weights),"formation":extension.formation,"formation_strength":extension.formation_strength})
	FileAccess.open(output.path_join("sky_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual V2 renderer, explicit authored showcase weather, static street camera; no played route or performance qualification","captures":captures,"failures":failures},"\t"))
	world.shutdown_for_tests();world.free();await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
