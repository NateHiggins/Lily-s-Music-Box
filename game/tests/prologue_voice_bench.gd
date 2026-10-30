extends "res://tests/companion_session_bench.gd"
## Live carrier/printer/audio fixture. Earlier scenes and occupied-world mix are separate.
const Opening := preload("res://scripts/game/prologue_state.gd")
const Director := preload("res://scripts/game/prologue_director.gd")
var occupied_world:OrisonV2RuntimeRoot

func _run() -> void:
	GameBoot.settings.fullscreen=true
	get_window().mode=Window.MODE_EXCLUSIVE_FULLSCREEN
	get_window().content_scale_size=Vector2i.ZERO
	get_window().size=DisplayServer.screen_get_size()
	if OS.get_environment("PROLOGUE_VOICE_WORLD")!="1":
		await super._run()
		return
	directory=OS.get_environment("SHOT_DIR")
	if directory.is_empty():get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	GameBoot.settings.weather_network_enabled=false
	CampaignTime.set_frozen_for_tests(true)
	occupied_world=preload("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(occupied_world)
	while not occupied_world.startup_failed and occupied_world.startup_ms<=0:await get_tree().process_frame
	if not check(not occupied_world.startup_failed,"occupied world starts for contact-only voice review"):finish();return
	# Composition can publish startup_ms before the first normal process/draw.
	# Await registration, not a wall-clock grace period inside that first frame.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	player=occupied_world.player;carrier=occupied_world.service_set_carrier
	player.set_physics_process(false)
	player.global_position=occupied_world.adapter.root.to_global(Vector3(-8.4,9.62,4.75))
	player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var paper:Node=carrier.device.teletype
	var pending:String=paper.pages[paper.page]
	FileAccess.open(directory.path_join("initial_paper.json"),FileAccess.WRITE).store_string(JSON.stringify({"serial":paper._serial,"text":pending,"characters":paper.printed_characters,"powered":paper.powered,"processing":paper.is_processing()}))
	# A test-only late start must let the actual startup field copy finish.
	# Derive the allowance from its remaining physical character/return work.
	var allowance:float=2.0+maxi(0,pending.length()-paper.printed_characters)*paper.CHARACTER_SECONDS+pending.count("\n")*paper.RETURN_SECONDS
	if not check(await _wait_startup_paper(paper,maxf(15.0,allowance)),"startup field copy naturally finishes before contact-only staging"):
		await capture("startup_paper_failure.png");finish();return
	await exercise()

func _wait_startup_paper(paper:Node,seconds:float) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	var next:=0
	var trace:Array=[]
	while Time.get_ticks_msec()<until:
		if Time.get_ticks_msec()>=next:
			var ancestors:Array=[]
			var ancestor:Node=paper
			while ancestor!=null:
				ancestors.append({"path":str(ancestor.get_path()),"mode":ancestor.process_mode,"can_process":ancestor.can_process(),"inside_tree":ancestor.is_inside_tree()})
				ancestor=ancestor.get_parent()
			trace.append({"ticks":Time.get_ticks_msec(),"frame":Engine.get_process_frames(),"printing":paper.printing,"characters":paper.printed_characters,"powered":paper.powered,"process_clock":paper._clock,"paused":get_tree().paused,"time_scale":Engine.time_scale,"ancestors":ancestors})
			next=Time.get_ticks_msec()+1000
		if paper.copy_delivered():break
		await get_tree().process_frame
	FileAccess.open(directory.path_join("paper_trace.json"),FileAccess.WRITE).store_string(JSON.stringify(trace,"\t"))
	return paper.copy_delivered()

func finish() -> void:
	if occupied_world!=null:
		occupied_world.shutdown_for_tests();remove_child(occupied_world);occupied_world.free();occupied_world=null
	super.finish()

func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(390.0).timeout.connect(func():
		if not finished:check(false,"voice diagnostic deadline");finish())

func exercise() -> void:
	get_window().mode=Window.MODE_EXCLUSIVE_FULLSCREEN
	get_window().content_scale_size=Vector2i.ZERO
	get_window().size=DisplayServer.screen_get_size()
	var director := Director.new()
	add_child(director)
	if occupied_world!=null:
		if not check(director.configure(occupied_world),"actual installed prologue supports configure"):finish();return
	else:
		director.world=self;director.player=player
	director._carrier=carrier
	var value:Dictionary=Opening.request_skip(Opening.initial())
	while value.phase!="first_contact":
		if value.phase=="companion_crossing":value=Opening.applied(value,"companion_materialized")
		value=Opening.advance(value,Opening.PHASES[Opening.PHASES.find(value.phase)+1])
	director.state=Opening.restore(value)
	RealityState.data.prologue=value.duplicate(true)
	director._document=RealityState.data
	var words:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Director.WORDS))
	for row:Dictionary in words.messages:director._messages[row.id]=row.text
	var draft:String=carrier.session.draft
	var bus:=AudioServer.get_bus_index("Dialogue")
	var capture_effect:=AudioEffectCapture.new()
	capture_effect.buffer_length=4.0
	AudioServer.add_bus_effect(bus,capture_effect)
	var effect_index:=AudioServer.get_bus_effect_count(bus)-1
	var deadline:=Time.get_ticks_msec()+15000
	while AudioPolicy.active_voice(director._voice_source())==null and Time.get_ticks_msec()<deadline:
		director._contact_tick(.016)
		await frames(1)
	var voice:AudioStreamPlayer3D=AudioPolicy.active_voice(director._voice_source())
	if not check(voice!=null and carrier.device.teletype.copy_delivered(),"delivered real contact paper triggers own babble"):
		var paper:Node=carrier.device.teletype
		FileAccess.open(directory.path_join("paper_failure.json"),FileAccess.WRITE).store_string(JSON.stringify({"serial":paper._serial,"owned_serial":director._contact_serial,"pages":paper.pages,"printed":paper.printed_characters,"powered":paper.powered,"processing":paper.is_processing(),"seen":director._voice_seen}))
		await capture("contact_paper_failure.png");director.shutdown();finish();return
	if voice!=null:
		check(voice.bus=="Dialogue" and voice.playing,"voice uses existing Dialogue/Voice mixer and real playback")
		await capture("first_contact_voice.png")
		var at_pause:=voice.get_playback_position()
		get_tree().paused=true
		await frames(12)
		check(absf(voice.get_playback_position()-at_pause)<.06,"pause suspends active voice playback")
		get_tree().paused=false
		await frames(90)
		var mixed:=capture_effect.get_buffer(capture_effect.get_frames_available())
		var energy:=0.0
		for sample:Vector2 in mixed:energy+=sample.length_squared()
		check(mixed.size()>0 and energy>.000001,"engine mixer receives nonzero original WAV audio")
		FileAccess.open(directory.path_join("audio_mix.json"),FileAccess.WRITE).store_string(JSON.stringify({"frames":mixed.size(),"stereo_energy":energy,"bus":"Dialogue","source":str(director._voice_source()),"scope":"Fixture mixer signal, not listening or occupied-world artistic acceptance"}))
	check(not director._contact_voice("contact_sorry"),"same witnessed message cannot chatter repeatedly")
	carrier.session.chatter_enabled=false
	check(not director._contact_voice("contact_murder"),"quiet preference drops optional babble")
	carrier.session.chatter_enabled=true
	check(not director._contact_voice("contact_murder"),"suppressed punchline does not replay after quiet ends")
	carrier.device.radio_powered=false
	check(not director._contact_voice("contact_bigger"),"radio power refusal preserves silence")
	carrier.device.radio_powered=true
	player.call_locked=true
	check(not director._contact_voice("contact_who"),"protected conversation refuses optional voice")
	player.call_locked=false
	director._voice_seen.erase("contact_bigger")
	get_tree().paused=true
	check(not director._contact_voice("contact_bigger"),"pause cannot start a new reaction")
	get_tree().paused=false
	director._voice_seen.erase("contact_bigger")
	var before_request:Dictionary=RealityState.data.duplicate(true)
	check(director._contact_voice("contact_bigger"),"questioning gesture plays from explicit current owner")
	check(RealityState.data==before_request,"voice request synchronously changes no authoritative game facts")
	if occupied_world==null:
		var prior_path:String=RealityState.save_path
		var prior_enabled:bool=RealityState.persistence_enabled
		RealityState.save_path=directory.path_join("voice_boundary.json")
		RealityState.persistence_enabled=true
		if not RealityState.state_changed.is_connected(director._restore):RealityState.state_changed.connect(director._restore)
		check(RealityState.save_game(),"validated campaign owner saves the vocal presentation boundary")
		RealityState.load_game()
		check(AudioPolicy.active_voice(director._voice_source())==null and director.state.phase=="first_contact","validated reload retires old voice and restores existing prologue facts")
		RealityState.save_path=prior_path;RealityState.persistence_enabled=prior_enabled
		director._contact_tick(0.0) # Reacquire only through the existing contact owner.
	director._contact_voice("contact_connect")
	check(AudioPolicy.active_voice(director._voice_source())==null,"final communicated line retires voice immediately")
	for phase_name:String in ["temporal_command","temporal_synchronization","title_reveal","prologue_complete"]:
		director.state.phase=phase_name;director._voice_seen.erase("contact_who")
		check(not director._contact_voice("contact_who"),"no voice in late phase "+phase_name)
	check(carrier.session.draft==draft and Opening.restore(RealityState.data.prologue)==Opening.restore(value),"vocal presentation preserves draft and validated prologue facts")
	AudioServer.remove_bus_effect(bus,effect_index)
	director.shutdown();director.queue_free()
	check(AudioPolicy.active_voice(director._voice_source())==null,"shutdown retires all owned voice playback")
	if occupied_world!=null:
		occupied_world.shutdown_for_tests();remove_child(occupied_world);occupied_world.free();occupied_world=null
	finish()
