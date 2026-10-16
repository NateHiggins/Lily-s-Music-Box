extends "res://tests/watch_station_hand_test.gd"
var detector: WatchmanClockProp

func check_cable_fit() -> void:
	var wire := detector.get_node("M03_PunchCableWire") as MeshInstance3D
	var bounds := wire.mesh.get_aabb()
	var end_at: Vector3=wire.transform*(bounds.position+Vector3(0,0,bounds.size.z))
	var start_at: Vector3=wire.transform*bounds.position
	var punch_bounds := detector._punch_head.mesh.get_aabb()
	var punch_end: Vector3=detector._punch_head.transform*Vector3(0,punch_bounds.end.y,0)
	check(absf(end_at.z-.183)<.0002 and absf(start_at.z-punch_end.z)<.0002,"native cable stays joined to sheath and moving punch")

func acquire(key: String) -> bool:
	var part: Node3D=detector._hand_controls.parts[key]
	var point: Vector3
	match key:
		"cover": point=detector.to_global(Vector3(.145,.2,.225)) if detector._hand_controls.cover_angle==0 else part.to_global(Vector3(.30,0,.02))
		"datum": point=detector._paper.to_global(Vector3(.085,0,.008))
		"seat": point=detector._spindle.global_position+Vector3(0,0,.02)
		_: point=part.global_position+Vector3(.014,0,.016)
	if player.inspecting(): Input.warp_mouse(player.camera.unproject_position(point))
	else: player.camera.look_at(point)
	await get_tree().physics_frame
	await get_tree().physics_frame
	click()
	return player._grab.active() and detector._hand_controls.held==key

func _run() -> void:
	RealityState.persistence_enabled=false
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.15,.17,.2)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
	add_child(environment)
	var light := OmniLight3D.new();light.position=Vector3(.6,.8,1);light.light_energy=1.1;add_child(light)
	detector=WatchmanClockProp.new();detector.name="F01_WATCHMAN_DETECTOR";add_child(detector)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/service_instruments.json"))
	data.actors=data.actors.filter(func(a): return a.id=="F01_WATCHMAN_DETECTOR")
	data.source_materials=[];data.work_lights=[];data.dumbwaiter_ropes=[]
	var file := FileAccess.open("user://detector_hand_native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
	var factory := preload("res://scripts/building/orison_v2_native_service_instruments.gd").new()
	check(factory.mount(self,"user://detector_hand_native.json"),"native detector mounts")
	check(detector._hand_controls!=null,"native hinged frame enables physical controls")
	if detector._hand_controls==null: get_tree().quit(1);return
	player=PlayerController.new();add_child(player);player.set_physics_process(false)
	player.position=Vector3(.08,-1.25,.8);player.camera.current=true;player.set_lamp_enabled(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	check(detector._hand_controls.grip("datum").is_empty(),"closed glass blocks dial manipulation")
	check(await acquire("cover"),"pointer grabs native cover pull")
	check(await move_to(1.65),"glass and timber frame swing together")
	click()
	check(await acquire("stop"),"exposed stop lever selectable")
	check(await move_to(.62),"mouse stops clockwork")
	click()
	check(not detector.movement_running,"stop controls original movement state")
	check(await acquire("seat"),"spindle retainer selectable")
	check(await move_to(0),"paper seats onto drive pin")
	click()
	check(detector.dial_seated,"seating changes original mechanism")
	check(await acquire("datum"),"paper dial can be turned")
	check(await move_to(detector.correct_datum()*TAU),"dial setting follows mouse rotation")
	click()
	check(detector.datum_set,"correct datum reads against house clock")
	check(await acquire("stop"),"stop lever can be restored")
	check(await move_to(0),"movement restarts physically")
	click()
	check(await acquire("key"),"station key can be grabbed")
	check(await move_to(.6),"partial key stroke stays below punch")
	var partial := detector.mechanism_snapshot()
	check_cable_fit()
	check(detector.valid_mechanism(partial),"partial detector save validates")
	var proof_before := detector.proof_first
	detector.restore_mechanism(JSON.parse_string(JSON.stringify(partial)))
	check(detector._hand_controls.held.is_empty() and is_equal_approx(detector._hand_controls.key_angle,.6),"restore clears hand and retains partial key angle")
	check(detector.proof_first==proof_before,"restoring half stroke cannot punch")
	player.cancel_manipulation()
	check(await acquire("key"),"restored half stroke can be resumed")
	check(await move_to(1.18),"full key stroke drives punch")
	check_cable_fit()
	click()
	check(detector.proof_first>=0 and detector.proof_second<0,"first full stroke creates one actual proof mark")
	check(await acquire("key"),"key reacquires at stroke end")
	check(await move_to(0),"return stroke rearms punch")
	check(await move_to(1.18),"second full key stroke")
	click()
	check(not detector.marks_prove_movement() and not detector.detector_honest,"same-time physical punches do not certify repair")
	check(not detector.interact_control("detector",player),"native detector no longer opens minigame")
	check(follows_cursor,"rotating detector parts follow mouse")
	var invalid := detector.mechanism_snapshot();invalid.physical_controls.key_armed=true
	check(not detector.valid_mechanism(invalid),"completed stroke cannot reload armed")
	invalid=detector.mechanism_snapshot();invalid.movement_running=false
	check(not detector.valid_mechanism(invalid),"inconsistent stop and movement save rejected")
	invalid=detector.mechanism_snapshot();invalid.datum=NAN
	check(not detector.valid_mechanism(invalid),"nonfinite detector state rejected")
	var shift := FirstShiftDirector.new()
	detector.bind_first_shift(shift)
	RealityState.data.first_shift={"phase":FirstShiftDirector.PHASE_ARRIVED}
	RealityState.data.intro_complete=false
	check(await acquire("key"),"key grabs with arrival guard active")
	check(await move_to(0) and await move_to(1.18),"guarded arrival stroke remains physically movable")
	click()
	check(shift.ritual_phase()==FirstShiftDirector.PHASE_ARRIVED,"stroke cannot bypass arrival guard")
	RealityState.data.intro_complete=true
	check(await acquire("key"),"key grabs for clock-in")
	check(await move_to(0) and await move_to(1.18),"clock-in requires return and full key stroke")
	click()
	check(shift.ritual_phase()==FirstShiftDirector.PHASE_CLOCKED_IN,"physical stroke calls original clock-in owner")
	RealityState.data.first_shift={"phase":FirstShiftDirector.PHASE_FILED}
	shift.observe_tour_key_taken(3)
	check(await acquire("key"),"key grabs with carried tour key")
	check(await move_to(0) and await move_to(1.18),"clock-out stroke with carried key")
	click()
	check(shift.ritual_phase()==FirstShiftDirector.PHASE_FILED,"original custody guard refuses clock-out")
	shift.observe_tour_key_returned()
	check(await acquire("key"),"key grabs after custody return")
	check(await move_to(0) and await move_to(1.18),"fresh physical stroke after custody return")
	click()
	check(shift.ritual_phase()==FirstShiftDirector.PHASE_COMPLETE,"original clock-out owner completes only after return")
	var finished := detector.mechanism_snapshot()
	detector.restore_mechanism(finished)
	check(shift.ritual_phase()==FirstShiftDirector.PHASE_COMPLETE and not detector._hand_controls.key_armed,"completed-stroke restore never replays ritual")
	detector.bind_first_shift(null);shift.free()
	var out := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	player.camera.global_position=Vector3(.4,.3,.85);player.camera.look_at(Vector3(0,.2,.12))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("detector_open.png"))
	var audio_references := observe_audio(detector)
	player.cancel_manipulation();player.queue_free();detector.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(.1).timeout
	check(audio_retired(audio_references),"detector retirement releases owned players and decoders after audio settles")
	print("DETECTOR HAND RESULT ",checks," checks ",failures," failures")
	get_tree().quit(1 if failures else 0)
