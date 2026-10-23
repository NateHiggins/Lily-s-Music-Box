extends Node
## INERT paired occupied-world profile. Captures/readbacks are outside samples.
var world: Node3D
var carrier: ServiceSetCarrier
var player: PlayerController
var samples: Array=[]
var failures: Array[String]=[]
var mode := ""
var previous := 0
var directory := ""
var observations: Array=[]
var source_before := ""
var started := 0
const CARD := {"title":"HOT WATER / FIELD REPORT","body":"The hot valve turns freely. Water warms steadily; the drain clears without backing up.\n\nClean the strainer and oil the cabinet hinge before the next call.\n\nThe tenant mentioned a knocking pipe after midnight. Listen again when the upstairs shower stops.","condition":"SERVICE COPY / NORTH STACK"}

func check(ok: bool,label: String) -> void:
	print("HANDHELD PROFILE: ",label," = ",ok)
	if not ok:failures.append(label)

func _ready() -> void:
	set_process(false);_run.call_deferred()

func runtime_digest() -> String:
	var output: Array=[]
	var root:=ProjectSettings.globalize_path("res://..").simplify_path()
	if OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)!=0:return ""
	return str(output[0]).strip_edges() if not output.is_empty() else ""

func key(code: Key,pressed: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
	Input.parse_input_event(event)

func _process(_delta: float) -> void:
	var now:=Time.get_ticks_usec()
	var main:=get_viewport().get_viewport_rid();var held:=carrier._pass_view.get_viewport_rid()
	samples.append({"phase":mode,"wall_ms":(now-previous)/1000.,
		"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.,
		"main_render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(main),"main_render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(main),
		"held_render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(held),"held_render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(held),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"pipeline_draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),"pipeline_surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		"pipeline_specialization":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)})
	previous=now

func _run() -> void:
	started=Time.get_ticks_msec();source_before=runtime_digest()
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	world=load("res://scenes/building/orison_v2_runtime.tscn").instantiate();add_child(world)
	await get_tree().create_timer(1.).timeout
	player=world.player;carrier=world.service_set_carrier
	check(not world.startup_failed,"occupied world starts")
	if world.startup_failed:get_tree().quit(1);return
	player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	RenderingServer.viewport_set_measure_render_time(carrier._pass_view.get_viewport_rid(),true)
	for phase in ["first_print","steady_print","held_idle","lowered"]:
		player.global_position=world.adapter.root.to_global(Vector3(-8.5,3.2,0));player.velocity=Vector3.ZERO
		player.face_world_point(world.adapter.root.to_global(Vector3(-13.4,4.3,.75)))
		if carrier.reading!=(phase!="lowered"):
			key(KEY_E,true);key(KEY_E,false)
			await get_tree().process_frame
		check(carrier.reading==(phase!="lowered"),"actual E sets pose: "+phase)
		if phase in ["first_print","steady_print"]:check(carrier.print_telegram_card(CARD),"report accepted: "+phase)
		if phase=="held_idle":await get_tree().create_timer(9.).timeout
		var start:=player.global_position
		mode=phase;previous=Time.get_ticks_usec();set_process(true)
		# Fixed physics-tick route: short forward/back movement, then paired
		# turns, with identical stance and input sequence for every phase/run.
		for tick in 300:
			if tick==0:key(KEY_W,true)
			if tick==24:key(KEY_W,false);key(KEY_S,true)
			if tick==48:key(KEY_S,false)
			if tick>=60 and tick<108:
				var event:=InputEventMouseMotion.new();event.relative=Vector2(2. if tick<84 else -2.,0);Input.parse_input_event(event)
			await get_tree().physics_frame
		set_process(false)
		key(KEY_W,false);key(KEY_S,false)
		observations.append({"phase":phase,"start":str(start),"end":str(player.global_position),"geometry_nodes":carrier.device.find_children("*","MeshInstance3D",true,false).size(),"pages":carrier.device.teletype.pages.size(),"ink":carrier.device.teletype.ink.text})
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join(phase+".png"))==OK,"captured "+phase)
	var review: Node=preload("res://tests/v2_vantry_ceiling_review.gd").new();add_child(review)
	var detector: Dictionary=await review.run(world,directory)
	for failure: String in detector.failures:failures.append(failure)
	FileAccess.open(directory.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","settings":{"viewport":str(get_viewport().size),"vsync":"disabled","fps_limit":0,"fixed_route_ticks":300,"physics_hz":Engine.physics_ticks_per_second},"limitations":"Process/physics and render monitors overlap and lag; asset/streaming costs not independently instrumented. First-print is first held render in a warmed world, not a cleared driver cache.","observations":observations,"samples":samples,"detector":detector,"failures":failures},"\t"))
	var digest:=runtime_digest()
	check(not source_before.is_empty() and digest==source_before,"runtime inputs remain unchanged through composed check")
	var test_sources: Dictionary={}
	for path in ["v2_handheld_profile.gd","v2_vantry_ceiling_review.gd"]:test_sources["game/tests/"+path]=FileAccess.get_file_as_string("res://tests/"+path).replace("\r\n","\n").sha256_text()
	var status: String="PASS" if failures.is_empty() else "FAIL"
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify({"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,"scope":"One existing V2 Vantry ceiling backplate, standing click/motion, Space inspection and free-cursor closing/release; actual E paper deployment. Does not qualify all V2 spaces, legacy Vantry surface finish, saved intermediate grille travel or subjective audiovisual quality.","execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.},"source":{"test_path":"game/tests/v2_handheld_profile.gd","test_sha256":test_sources["game/tests/v2_handheld_profile.gd"],"runtime_inputs_sha256":digest,"test_sources":test_sources},"contracts":{"ceiling_mount":{"executed":detector.observations.size()==1,"status":status},"direct_manipulation":{"executed":detector.grabs==2,"status":status},"inspection_cursor":{"executed":detector.grabs==2,"status":status}},"checks":detector.checks,"failures":failures,"observations":detector.observations},"\t"))
	print("HANDHELD PROFILE: ","PASS" if failures.is_empty() else "FAIL"," samples=",samples.size())
	get_tree().quit(0 if failures.is_empty() else 1)
