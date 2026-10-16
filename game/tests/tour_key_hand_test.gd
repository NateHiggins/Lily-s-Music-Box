extends "res://tests/watch_station_hand_test.gd"
var guard: TourKeyGuardProp
var taken := 0
var returned := 0

func acquire(key: String) -> bool:
	var part: Node3D=guard._latch if key=="latch" else (guard._check if key=="return" else guard._key)
	var point: Vector3=part.to_global(Vector3(-.030,0,.012) if key=="latch" else Vector3(0,-.028,.01))
	if key=="return": point=part.to_global(Vector3(0,0,.01))
	if player.inspecting(): Input.warp_mouse(player.camera.unproject_position(point))
	else: player.camera.look_at(point)
	await get_tree().physics_frame
	await get_tree().physics_frame
	click()
	return player._grab.active() and guard._hand_controls.held==key

func _run() -> void:
	RealityState.persistence_enabled=false
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.15,.17,.20)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.7
	add_child(environment)
	var light := OmniLight3D.new();light.position=Vector3(.5,.5,1);light.light_energy=1.2;add_child(light)
	guard=TourKeyGuardProp.new();guard.name="F01_TOUR_KEY_GUARD";add_child(guard)
	guard.tour_key_taken.connect(func(_number): taken+=1)
	guard.tour_key_returned.connect(func(): returned+=1)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/service_instruments.json"))
	data.actors=data.actors.filter(func(a): return a.id=="F01_TOUR_KEY_GUARD")
	data.source_materials=[];data.work_lights=[];data.dumbwaiter_ropes=[]
	var file := FileAccess.open("user://tour_key_native_test.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
	var factory := preload("res://scripts/building/orison_v2_native_service_instruments.gd").new()
	check(factory.mount(self,"user://tour_key_native_test.json"),"native key guard mounts")
	player=PlayerController.new();add_child(player);player.set_physics_process(false)
	player.position=Vector3(.08,-1.35,.55);player.camera.current=true;player.set_lamp_enabled(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	check(await acquire("key"),"actual pointer grabs hanging key")
	var motion := InputEventMouseMotion.new();motion.relative=Vector2(0,-90)
	player._unhandled_input(motion)
	check(is_zero_approx(guard._hand_controls.key_lift) and not guard.key_carried(),"closed latch physically refuses key lift")
	click()
	check(await acquire("latch"),"latch is independently selectable")
	check(await move_to(1.3),"mouse swings latch clear")
	click()
	check(not guard.key_carried() and taken==0,"opening latch cannot take key")
	check(await acquire("key"),"unlatched key can be grabbed")
	check(await move_to(.025),"key lifts partway over hook")
	click()
	check(not guard.key_carried() and taken==0,"partial lift retains original custody")
	var partial: Dictionary=guard.maintenance_snapshot()
	guard.restore_maintenance_snapshot(partial)
	check(is_equal_approx(guard._hand_controls.key_lift,.025),"maintenance restoration retains physical lift")
	check(await acquire("key"),"partial key can be reacquired")
	check(await move_to(.065),"key lifts fully clear")
	check(guard.key_carried() and taken==1,"full travel publishes custody once")
	check(await move_to(0),"same held key can be lowered back without releasing")
	check(not guard.key_carried() and returned==1,"reversal returns original key through custody owner")
	check(await move_to(.065),"same held key can be lifted again")
	check(taken==2,"repeated full removal is one new custody event")
	click()
	check(not guard._key.visible and guard._check.visible,"released carried key leaves numbered check")
	check(await acquire("return"),"check hook accepts carried key for rehanging")
	check(returned==1 and guard.key_carried(),"grab alone does not return key")
	player.cancel_manipulation()
	check(guard.key_carried() and not guard._key.visible,"interrupted rehanging retains custody and clears presentation")
	check(await acquire("return"),"carried key can be presented again after interruption")
	check(await move_to(0),"mouse lowers carried key onto hook")
	check(not guard.key_carried() and returned==2,"seating publishes return once")
	click()
	check(await acquire("latch"),"latch can be closed after rehanging")
	check(await move_to(0),"mouse seats retaining latch")
	click()
	check(follows_cursor,"latch follows mouse direction")
	check(not guard.interact_control("tour_key",player),"native guard retires click custody toggle")
	var invalid := guard.mechanism_snapshot();invalid.key_lift=.025
	check(not guard.valid_mechanism(invalid),"impossible closed latch and lifted key save rejected")
	var out := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	player.camera.global_position=Vector3(.15,.22,.45);player.camera.look_at(Vector3(0,.13,.04))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("guard.png"))
	file=FileAccess.open(out.path_join("bench_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "));file.close()
	print("TOUR KEY HAND RESULT ",checks," checks ",failures," failures")
	player.cancel_manipulation();player.queue_free();guard.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
