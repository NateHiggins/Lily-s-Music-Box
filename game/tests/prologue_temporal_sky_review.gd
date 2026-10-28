extends Node
## INERT occupied-world cinematic diagnostic. Earlier intro beats not played.
const Runtime:=preload("res://scenes/building/orison_v2_runtime.tscn")
const Opening:=preload("res://scripts/game/prologue_state.gd")
const Director:=preload("res://scripts/game/prologue_director.gd")
const TemporalSky:=preload("res://scripts/game/prologue_temporal_sky.gd")
var world:OrisonV2RuntimeRoot
var director:Node
var checks:Array[Dictionary]=[]
var directory:=""
var done:=false
var publications:=0

func check(ok:bool,label:String) -> bool:
	checks.append({"name":label,"passed":ok})
	print("TEMPORAL SKY ","PASS " if ok else "FAIL ",label)
	return ok

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	directory=OS.get_environment("SHOT_DIR")
	if directory.is_empty():get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	get_tree().create_timer(780).timeout.connect(func():
		if not done:check(false,"cinematic diagnostic deadline");finish())
	run.call_deferred()

func stage(target:Dictionary) -> bool:
	if is_instance_valid(director):director.shutdown();director.free()
	CampaignClock.new().configure_date(1928,11,10,18*60)
	var value:=Opening.request_skip(Opening.initial())
	while value.phase!="temporal_command":
		if value.phase=="companion_crossing":value=Opening.applied(value,"companion_materialized")
		value=Opening.advance(value,Opening.PHASES[Opening.PHASES.find(value.phase)+1])
	value=Opening.advance(Opening.with_target(value,target),"temporal_synchronization")
	RealityState.data.prologue=value
	director=Director.new();add_child(director)
	return director.configure(world)

func run() -> void:
	if DisplayServer.get_name()=="headless":check(false,"windowed rendering required");finish();return
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	GameBoot.settings.weather_network_enabled=false
	CampaignClock.new().configure_date(1928,11,10,18*60)
	world=Runtime.instantiate();add_child(world)
	while not world.startup_failed and world.startup_ms<=0:await get_tree().process_frame
	if not check(not world.startup_failed,"actual occupied V2 world starts"):finish();return
	var player:=world.player
	player.global_position=world.adapter.root.to_global(Vector3(-8.4,9.62,4.75))
	player.velocity=Vector3.ZERO;player.camera.make_current();player.camera.fov=78
	player.camera.look_at(world.adapter.root.to_global(Vector3(-5.9,11.5,4.75)))
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	# Let the real player camera/observer-owned mirror render before borrowing
	# another camera. The earlier cold diagnostic did not exercise that view.
	for frame in 120:await frames(1)
	var target:=Opening.sample_destination()
	if not check(stage(target),"historical 4B wall and finale owners bind"):finish();return
	var clock:=CampaignClock.new()
	var before:Dictionary=RealityState.data.campaign_clock.duplicate(true)
	var projection:=TemporalSky.RenderClock.new()
	check(projection.seek_utc(float(target.utc_unix_seconds)) and not projection.apply_prologue_destination() and not projection.configure_date(1928,11,10),"detached sky clock can project dates but cannot apply or configure campaign time")
	check(RealityState.data.campaign_clock==before,"render clock projection leaves the actual clock unchanged")
	var source:=float(Time.get_unix_time_from_datetime_dict(clock.utc_datetime()))
	var previous:=source;var monotone:=true
	for step in 1025:
		var stamp:float=TemporalSky.time_at(float(step)/32,source,float(target.utc_unix_seconds))
		monotone=monotone and stamp>=previous;previous=stamp
	check(monotone and TemporalSky.time_at(0,source,float(target.utc_unix_seconds))==source and TemporalSky.time_at(32,source,float(target.utc_unix_seconds))==float(target.utc_unix_seconds),"continuous clip traverses monotonically to the exact destination")
	var manager:Node=world.get_node("WakingAtmosphere").weather_manager
	manager.conditions_changed.connect(func(_conditions:Dictionary):publications+=1)
	var mode:int=world.process_mode
	var conditions:String=JSON.stringify(manager.current)
	player.acquire_text_input(self)
	check(not director.begin_temporal_sky() and world.process_mode==mode and player.text_input_owner==self,"foreign text ownership refuses the cinematic without freezing the world")
	player.release_text_input(self)
	if not check(director.begin_temporal_sky(),"actual window-to-sky cinematic starts"):finish();return
	var clip:Node=director.temporal_sky
	var frozen:Dictionary=RealityState.data.campaign_clock.duplicate(true)
	for stamp:float in [0.0,3.5,4.5,6.5,9.0,15.0,24.0,29.8]:
		clip.seek(stamp)
		await frames(3)
		await capture("sky_%02d.png"%int(stamp*10))
	# Isolate the observed centre seam at a fixed sky/camera/time.
	clip.seek(24);clip.set_process(false)
	var mask:int=clip.camera.cull_mask
	clip.camera.cull_mask=0
	await frames(12);await capture("sky_only_seam_control.png")
	clip.camera.cull_mask=mask
	await frames(12);await capture("sky_geometry_seam_control.png")
	FileAccess.open(directory.path_join("seam_context.json"),FileAccess.WRITE).store_string(JSON.stringify({"camera_basis":str(clip.camera.global_basis),"outward":str(clip._outward),"clock":clip.view_clock.utc_datetime(),"panorama_a":str(manager.sky.get_shader_parameter("panorama_a")),"panorama_b":str(manager.sky.get_shader_parameter("panorama_b")),"sky_blend":manager.sky.get_shader_parameter("sky_blend")},"\t"))
	var taa:bool=get_viewport().use_taa
	get_viewport().use_taa=false
	await frames(12);await capture("sky_no_taa_seam_control.png")
	get_viewport().use_taa=taa
	await frames(12)
	clip.set_process(true)
	check(RealityState.data.campaign_clock==frozen and JSON.stringify(manager.current)==conditions and publications==0,"intermediate optical dates cannot advance gameplay time or publish weather observations")
	get_tree().paused=true
	var age:float=clip.age
	await frames(3)
	check(clip.age==age and player.text_input_owner==clip,"pause holds cinematic time and its input lease")
	get_tree().paused=false
	clip.cancel()
	check(world.process_mode==mode and player.text_input_owner==null and player.camera.is_current() and not world.service_set_carrier.is_story_absent(),"cancellation restores world, player camera, input and companion visibility")
	# Repeat the actual full32-second clip without screenshot stalls.
	if not check(director.begin_temporal_sky(),"cancelled clip can restart without a new destination"):finish();return
	clip=director.temporal_sky;clip.profile_samples=true
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var began:=Time.get_ticks_msec()
	var frame_times:Array=[];var last:int=Time.get_ticks_usec()
	while clip.active and Time.get_ticks_msec()-began<50000:
		await frames(1)
		var now:int=Time.get_ticks_usec()
		frame_times.append([clip.age,(now-last)/1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),
			RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE)]);last=now
	check(not clip.active and director.state.phase=="title_reveal" and director.state.effects.clock_applied,"natural cinematic finishes through the real clock-owner callback")
	check(int(Time.get_unix_time_from_datetime_dict(clock.utc_datetime()))>=int(target.utc_unix_seconds),"completed scene reaches the fixed destination UTC instant")
	check(world.process_mode==mode and player.text_input_owner==null and player.camera.is_current(),"natural completion returns camera/input/world control")
	FileAccess.open(directory.path_join("publication_costs.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","samples":clip.sample_costs,"finish":clip.finish_costs,"scope":"synchronous cinematic publication cost; not a playable movement profile"},"\t"))
	FileAccess.open(directory.path_join("frame_times.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","samples":frame_times,"viewport":str(get_viewport().size),"msaa_3d":get_viewport().msaa_3d,"taa":get_viewport().use_taa,"fps_cap":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"engine":Engine.get_version_info(),"target":target,"scope":"uninterrupted optical cinematic only; no PNG readback within this trace; main-viewport CPU/GPU times exclude private viewports"},"\t"))
	# Accessible presentation hides fast cycles, but uses the same final state.
	var previous_quiet:bool=bool(GameBoot.settings.get("reduce_flashing",false))
	GameBoot.settings.reduce_flashing=true
	if check(stage(target) and director.begin_temporal_sky(),"reduced-flash cinematic starts through the same owner"):
		clip=director.temporal_sky;clip.seek(15)
		check(clip._veil.color.a>.99,"reduced-flash path masks the rapid day/night cycles")
		await capture("reduced_flash_midpoint.png")
		clip.seek(31);await frames(3);await capture("reduced_flash_destination.png")
		check(clip._veil.color.a<.01,"reduced-flash path reveals the settled destination")
		clip.cancel()
	GameBoot.settings.reduce_flashing=previous_quiet
	# Reload through real validated storage during an accelerated frame.
	if not check(stage(target),"reload control rebinds the historical opening"):finish();return
	RealityState.save_path=directory.path_join("sky_reload.json");RealityState.persistence_enabled=true
	check(RealityState.save_game(),"validated storage saves the fixed pre-transition destination")
	if not check(director.begin_temporal_sky(),"reload interruption control begins"):finish();return
	clip=director.temporal_sky;clip.seek(15)
	RealityState.load_game();await frames(2)
	check(not clip.active and world.process_mode==mode and player.text_input_owner==null and player.camera.is_current(),"validated reload cancels borrowed sky/camera/input state")
	check(Opening.restore(RealityState.data.prologue).target==target and not RealityState.data.prologue.effects.clock_applied,"reload retains destination without applying an uncompleted jump")
	if check(director.begin_temporal_sky(),"reloaded transition resumes with its original target"):
		var press:=InputEventAction.new();press.action="ui_accept";press.pressed=true
		Input.parse_input_event(press);Input.flush_buffered_events();await frames(2)
		check(director.state.phase=="title_reveal" and director.temporal_sky.was_skipped and player.text_input_owner==null,"actual skip input lands through the same clock owner and releases its lease")
	finish()

func frames(count:int) -> void:
	for index in count:await get_tree().process_frame

func capture(name:String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name))

func finish() -> void:
	if done:return
	done=true;get_tree().paused=false;RealityState.persistence_enabled=false
	if is_instance_valid(director):director.shutdown();director.free()
	if is_instance_valid(world):world.shutdown_for_tests();world.free()
	var failures:=checks.filter(func(row:Dictionary):return not row.passed)
	FileAccess.open(directory.path_join("review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures},"\t"))
	get_tree().quit(0 if failures.is_empty() else 1)
