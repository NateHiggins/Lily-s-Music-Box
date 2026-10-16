extends "res://tests/watch_station_hand_test.gd"
var register: WatchRegisterProp

func acquire(key: String) -> bool:
	var part: Node3D=register._lever if key=="reset" else register._hand_controls.test_key
	var point: Vector3=part.to_global(Vector3(0,.062,.018) if key=="reset" else Vector3(0,.04,.03))
	player.camera.look_at(point)
	await get_tree().physics_frame
	await get_tree().physics_frame
	click()
	return player._grab.active() and register._hand_controls.held==key

func _run() -> void:
	RealityState.persistence_enabled=false
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.15,.17,.2)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
	add_child(environment)
	var light := OmniLight3D.new();light.position=Vector3(.6,.8,1);light.light_energy=1.1;add_child(light)
	register=WatchRegisterProp.new();register.name="F01_SIGNAL_REGISTER";add_child(register)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/service_instruments.json"))
	data.actors=data.actors.filter(func(a): return a.id=="F01_SIGNAL_REGISTER")
	data.source_materials=[];data.work_lights=[];data.dumbwaiter_ropes=[]
	var file := FileAccess.open("user://register_hand_native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
	var factory := preload("res://scripts/building/orison_v2_native_service_instruments.gd").new()
	check(factory.mount(self,"user://register_hand_native.json"),"native signal register mounts")
	check(register._hand_controls!=null,"physical test key is installed")
	if register._hand_controls==null: get_tree().quit(1);return
	var network := WatchStationNetwork.new();add_child(network);network.attach_receiver(register)
	player=PlayerController.new();add_child(player);player.set_physics_process(false)
	player.position=Vector3(.08,-1.2,.8);player.camera.current=true;player.set_lamp_enabled(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	check(register.receive_signal({"station_number":2}),"original receiver accepts signal on closed circuit")
	check(await acquire("reset"),"pointer grabs actual reset knob")
	check(register.shows(2),"grab alone retains indication")
	check(await move_to(.45),"lever raises shutters partway")
	click()
	check(register.shows(2) and is_equal_approx(register._shutters[2].position.y,.258),"partial stroke retains record and visibly lifts drop")
	var saved := register.mechanism_snapshot()
	register.restore_mechanism(JSON.parse_string(JSON.stringify(saved)))
	check(register.shows(2) and register.signals_taken==1,"restore cannot clear records or counter")
	check(await acquire("reset") and await move_to(.9),"full reset stroke")
	click()
	check(not register.shows(2) and register.signals_taken==1,"full stroke resets shutter through original owner without decrementing counter")
	check(await acquire("line"),"pointer grabs native line-test key")
	check(await move_to(PI/2),"test key opens local circuit")
	click()
	check(not register.line_closed and network.line_closed,"local switch does not rewrite upstream wire condition")
	check(not register.receive_signal({"station_number":3}),"open local contact refuses incoming signal")
	network.set_line_closed(false)
	check(await acquire("line") and await move_to(0),"test key returns to closed position")
	click()
	check(not register.line_closed,"closed local key cannot heal upstream break")
	register.restore_mechanism(register.mechanism_snapshot())
	check(not register.line_closed,"restoring closed key cannot heal upstream break")
	network.set_line_closed(true)
	check(register.line_closed,"upstream repair restores circuit when local key is closed")
	check(register.receive_signal({"station_number":3}) and register.signals_taken==2,"repaired circuit resumes original signal counter")
	check(not register.interact_control("reset",player),"native register rejects click reset")
	check(follows_cursor,"register controls follow pointer direction")
	var invalid := register.mechanism_snapshot();invalid.test=INF
	check(not register.valid_mechanism(invalid),"nonfinite physical save rejected")
	var out := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	player.camera.global_position=Vector3(.35,.3,.85);player.camera.look_at(Vector3(0,.23,.08))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("register.png"))
	print("REGISTER HAND RESULT ",checks," checks ",failures," failures")
	player.cancel_manipulation();player.queue_free();register.queue_free();network.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
