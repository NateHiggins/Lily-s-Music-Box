extends "res://tests/watch_station_hand_test.gd"
var register: NightRegisterProp
var committed_positions: Array[Dictionary]=[]

func record_commit() -> void:
	committed_positions.append(register.mechanism_snapshot().duplicate(true))

func acquire(key: String) -> bool:
	var part: Node3D=register._hand_controls.parts[key]
	var point: Vector3=part.global_position
	if key=="index": point+=register._card.global_basis*Vector3(0,.012,0)
	elif key=="pen": point+=register._desk.global_basis*Vector3(0,.005,0)
	else: point+=Vector3(.006,0,.008)
	player.camera.look_at(point)
	await get_tree().physics_frame
	await get_tree().physics_frame
	click()
	return player._grab.active() and register._hand_controls.held==key.trim_suffix("_return")

func write_stroke() -> void:
	for i in 12:
		if not player._grab.active(): return
		var point: Vector3=register._hand_controls.parts.pen.to_global(player._grab.contact)
		var next := point+register._desk.global_basis*Vector3(-.006,0,0)
		var motion := InputEventMouseMotion.new()
		motion.relative=player.camera.unproject_position(next)-player.camera.unproject_position(point)
		player._unhandled_input(motion)
		await get_tree().physics_frame

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var tracker := ObjectiveTracker.new();add_child(tracker)
	var orders := WorkOrders.new();orders.setup(tracker);orders.bind_job_library(MaintenanceJobLibrary.load_default());add_child(orders)
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.15,.17,.2)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7;add_child(environment)
	var light := OmniLight3D.new();light.position=Vector3(.6,.8,1);light.light_energy=1.1;add_child(light)
	register=NightRegisterProp.new();register.name="F01_NIGHT_REGISTER";register._work_orders=orders;add_child(register)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/service_instruments.json"))
	data.actors=data.actors.filter(func(a): return a.id=="F01_NIGHT_REGISTER")
	data.source_materials=[];data.work_lights=[];data.dumbwaiter_ropes=[]
	var file := FileAccess.open("user://night_register_hand_native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
	var factory := preload("res://scripts/building/orison_v2_native_service_instruments.gd").new()
	check(factory.mount(self,"user://night_register_hand_native.json"),"native night register mounts")
	player=PlayerController.new();add_child(player);player.set_physics_process(false)
	player.position=Vector3(.04,-1.02,.85);player.camera.current=true;player.set_lamp_enabled(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	check(register._hand_controls.grip("slip").is_empty(),"empty spindle cannot manufacture report")
	check(await acquire("pen"),"pen can be picked up before a report exists")
	await write_stroke()
	click()
	check(register.signed_lines==0,"writing motion cannot bypass filing guards")
	check(orders.issue_job("lena_radiator_round_2b","reported"),"original owner issues test report")
	register._refresh_board()
	check(await acquire("slip"),"pointer grabs printed native report")
	check(await move_to(.025),"paper follows partial lift")
	click()
	check(not register.slip_taken and orders.job_stage("lena_radiator_round_2b")=="issued","partial lift does not acknowledge report")
	var partial := register.mechanism_snapshot()
	check(register.valid_mechanism(partial),"partial paper snapshot validates")
	register._hand_controls.lifts.slip=0.0
	register.restore_mechanism(partial)
	check(is_equal_approx(register._hand_controls.lifts.slip,.025) and orders.job_stage("lena_radiator_round_2b")=="issued","restore preserves partial lift without acknowledging report")
	var invalid := partial.duplicate(true)
	invalid.pen_tip=[NAN,0]
	check(not register.valid_mechanism(invalid),"nonfinite pen position rejected")
	check(await acquire("slip") and await move_to(.065),"paper lifts fully from spindle")
	click()
	check(register.slip_taken and orders.job_stage("lena_radiator_round_2b")=="acknowledged","full lift calls original report authority")
	check(await acquire("apartment") and await move_to(.065),"apartment key lifts off hook")
	click()
	check(register.key_out("apartment"),"original key custody changes after full travel")
	var custody := register.mechanism_snapshot()
	register.keys_out.apartment=false
	register.restore_mechanism(custody)
	check(register.key_out("apartment") and register.slip_taken and register.round_open,"restore preserves report and key custody")
	check(await acquire("slip_return"),"spindle accepts held report presentation")
	var motion := InputEventMouseMotion.new();motion.relative=Vector2(0,180);player._unhandled_input(motion)
	click()
	check(register.slip_taken,"existing guard refuses report return while key is out")
	check(await acquire("apartment_return") and await move_to(0),"key can be rehung physically")
	click()
	check(not register.key_out("apartment"),"key custody returns through existing owner")
	check(await acquire("slip_return") and await move_to(0),"report lowers back onto spindle")
	click()
	check(not register.slip_taken and register.round_open,"return preserves open round until filing")
	check(await acquire("index"),"conclusion index is independently selectable")
	check(await move_to(.025),"index can remain between printed outcomes")
	click()
	check(not register.outcome_selected(),"between-detent position never chooses an outcome")
	check(await acquire("index") and await move_to(.056),"index slides onto third printed outcome")
	click()
	check(register.selected_outcome()=="no_fault_found","original selector owns chosen filing wording")
	check(register.signed_lines==0,"moving reports keys and selector cannot sign a line")
	check(not register.interact_control("index",player),"legacy click index cycle retired")
	var selected := register.mechanism_snapshot()
	register.restore_mechanism(selected)
	check(register.selected_outcome()=="no_fault_found" and register.signed_lines==0,"selector restore cannot file a line")
	RealityState.state_changed.connect(record_commit)
	check(await acquire("pen"),"pointer grabs pen for completed round")
	check(register.signed_lines==0,"pen acquisition alone cannot sign")
	await write_stroke()
	check(register.signed_lines==1 and register._stored_lines().size()==1,"writing motion uses original durable signature owner once")
	await write_stroke()
	check(register.signed_lines==1,"continuing same pen gesture cannot duplicate filing")
	click()
	check(register.index_detent==0 and is_equal_approx(register._hand_controls.index_z,-.06),"successful filing resets both original selection and visible index")
	check(not committed_positions.is_empty() and not committed_positions.back().round_open and is_equal_approx(committed_positions.back().index_z,-.06),"save capture observes closed round and blank index atomically")
	RealityState.state_changed.disconnect(record_commit)
	var filed := register.mechanism_snapshot()
	register.restore_mechanism(filed)
	check(register.signed_lines==1 and register._stored_lines().size()==1 and not register.round_open,"filed state restore never duplicates durable lines")
	check(not register.interact_control("book",player),"book click cannot sign native register")
	var out := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	player.camera.global_position=Vector3(.4,.5,.95);player.camera.look_at(Vector3(0,.22,.1))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("night_register.png"))
	print("NIGHT REGISTER HAND RESULT ",checks," checks ",failures," failures")
	player.cancel_manipulation();player.queue_free();register.queue_free();orders.queue_free();tracker.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
