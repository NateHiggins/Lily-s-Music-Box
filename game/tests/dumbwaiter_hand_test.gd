extends Node3D
var tank: DumbwaiterProp
var player: PlayerController
var failures := 0
var checks := 0
var results: Array[Dictionary] = []
var wheel_follows_cursor := true
var out := ""
var batch_mode := false

func check(ok: bool,label: String) -> void:
	checks+=1
	results.append({"ok":ok,"label":label})
	if not ok: failures+=1
	print("DUMBWAITER HAND CHECK: ",label," = ",ok)

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	player._unhandled_input(event)

func acquire(key: String) -> bool:
	var hand = tank._hand_controls
	var part: MeshInstance3D=hand.grips[0 if key=="left" else 1] if key in ["left","right"] else (hand.brake if key=="brake" else tank._pawl)
	var local_point := part.get_aabb().get_center()
	if key=="brake": local_point.x+=.029
	if key=="pawl": local_point.x-=.015
	var point := part.to_global(local_point)
	if player.inspecting(): Input.warp_mouse(player.camera.unproject_position(point))
	else: player.camera.look_at(point)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var candidate: Dictionary=player._grab.find_target()
	if candidate.get("owner")!=tank:
		var query := PhysicsRayQueryParameters3D.create(player.camera.global_position,point,1,[player.get_rid()])
		query.collide_with_areas=true
		print("DUMBWAITER PICK DIAGNOSTIC: ",key," point=",point," camera=",player.camera.global_position," candidate=",candidate," cursor=",get_viewport().get_mouse_position()," projected=",player.camera.unproject_position(point)," hit=",get_world_3d().direct_space_state.intersect_ray(query))
	click()
	return player._grab.active() and tank._hand_controls.held==key

func move_to(goal: float) -> bool:
	for i in 180:
		if not player._grab.active(): return false
		var target: Dictionary=player._grab.target
		var value: float=target.read.call()
		if absf(goal-value)<.001: return true
		var point: Vector3=target.part.to_global(player._grab.contact)
		var axis: Vector3=target.frame.global_basis*target.axis
		var tangent: Vector3=axis
		if target.kind=="hinge":
			tangent=axis.cross(point-target.part.global_position)
			if tangent.length()<.025:
				tangent=axis.cross(player.camera.global_basis.x)*.06
				if tangent.length()<.01: tangent=axis.cross(player.camera.global_basis.y)*.06
		var screen: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
		if screen.length()<24.0 and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5:
			screen=Vector2(0,tangent.dot(player.camera.global_basis.z)*180.0)
		var event := InputEventMouseMotion.new()
		event.relative=screen*clampf(goal-value,-.15 if target.kind=="hinge" else -.04,.15 if target.kind=="hinge" else .04)
		var before_screen: Vector2=player.camera.unproject_position(point)
		player._unhandled_input(event)
		await get_tree().physics_frame
		if target.kind=="hinge" and tank.brake_bite>=tank.BAND_HOME and absf(float(target.read.call())-value)>.001:
			var after_screen: Vector2=player.camera.unproject_position(target.part.to_global(player._grab.contact))
			if (after_screen-before_screen).dot(event.relative)<0: wheel_follows_cursor=false
	print("MOTION LIMIT: goal=",goal," value=",player._grab.target.read.call() if player._grab.active() else -999)
	return false

func _ready() -> void:
	if not batch_mode: _run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled=false
	out=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.12,.14,.17)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.7
	add_child(environment)
	var light := OmniLight3D.new()
	light.position=Vector3(1,1,2);light.light_energy=2
	add_child(light)
	tank=DumbwaiterProp.new();tank.name="LobbyServiceDumbwaiter";add_child(tank)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/service_instruments.json"))
	data.actors=data.actors.filter(func(a): return a.id=="LobbyServiceDumbwaiter")
	data.work_lights=[]
	var file := FileAccess.open("user://dumbwaiter_hand_native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
	var factory := preload("res://scripts/building/orison_v2_native_service_instruments.gd").new()
	check(factory.mount(self,"user://dumbwaiter_hand_native.json"),"native dumbwaiter geometry binds")
	if tank._hand_controls==null:
		print(factory.errors);get_tree().quit(1);return
	player=PlayerController.new()
	add_child(player)
	player.set_physics_process(false)
	player.position=Vector3(0,-1.1,1.45)
	player.camera.current=true;player.set_lamp_enabled(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await exercise()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("dumbwaiter_repaired.png"))
	print("DUMBWAITER HAND RESULT: ",checks," checks, ",failures," failures")
	player.cancel_manipulation();player.queue_free();tank.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures==0 else 1)


func exercise() -> void:
	check(await acquire("right"),"click grabs right rope grip")
	check(is_zero_approx(tank.car_travel) and tank._service_panel==null,"grab neither moves car nor opens minigame")
	check(await move_to(.10),"downward hand rope motion raises car")
	click()
	var raised: float=tank.car_travel
	await get_tree().create_timer(.3).timeout
	check(is_equal_approx(tank.car_travel,raised),"engaged pawl holds released car")
	check(tank._hand_controls.pawl_pivot.basis.is_equal_approx(Basis.IDENTITY),"released pawl seats instead of retaining ratchet cam lift")
	var event := InputEventKey.new()
	event.keycode=KEY_SPACE;event.physical_keycode=KEY_SPACE;event.pressed=true
	check(await acquire("right"),"rope can be regrabbed")
	player._unhandled_input(event)
	check(player.inspecting(),"Space provides static mechanism inspection")
	if player._grab.active(): click()
	await RenderingServer.frame_post_draw
	await get_tree().physics_frame
	check(await acquire("pawl"),"cursor selects actual pawl")
	check(await move_to(.15),"small physical pawl lift clears tooth envelope")
	click()
	await get_tree().create_timer(.4).timeout
	check(tank.car_travel<raised,"unsupported car descends after releasing pawl")
	check(await acquire("pawl"),"pawl can be returned")
	check(await move_to(0),"mouse seats pawl")
	click()
	check(await acquire("right"),"rope remains available in inspection")
	check(await move_to(.12),"car can be raised again")
	click()
	check(await acquire("brake"),"cursor grabs tension wheel")
	check(await move_to(TAU*3),"clockwise wheel tightens brake")
	click()
	var state: Dictionary=tank.mechanism_snapshot()
	check(tank.valid_mechanism(state),"partial physical state is saveable")
	var bad: Dictionary=state.duplicate();bad.brake_bite=NAN
	check(not tank.valid_mechanism(bad),"nonfinite state rejected")
	check(await acquire("right"),"braked rope remains grabbable")
	var before: float=tank.car_travel
	# Send a real attempted pull, without expecting a locked part to reach a target.
	var motion := InputEventMouseMotion.new();motion.relative=Vector2(0,45)
	player._unhandled_input(motion);click()
	check(is_equal_approx(before,tank.car_travel),"tight brake resists rope pull")
	check(await acquire("pawl"),"pawl remains independent of brake")
	check(await move_to(.8),"pawl lifts clear of braked car")
	click()
	await get_tree().create_timer(2.1).timeout
	check(tank.band_seated,"released brake proves hold through original repair authority")
	check(is_equal_approx(before,tank.car_travel),"repair does not snap car to bottom")
	check(wheel_follows_cursor,"visible hinged parts follow mouse direction")
	check(await acquire("brake"),"repair leaves brake adjustable")
	check(await move_to(5.0),"brake can be loosened after repair")
	click()
	check(await acquire("right"),"hand can support car with released brake and pawl")
	var held_state: Dictionary=tank.mechanism_snapshot()
	check(held_state.rope_strain==1.0,"live hand carries actual rope strain")
	tank.restore_mechanism(held_state)
	player._grab.validate()
	check(is_zero_approx(tank.rope_strain) and tank._hand_controls.held.is_empty(),"restoration does not invent a supporting hand")
	var saved_height: float=tank.car_travel
	await get_tree().create_timer(.25).timeout
	check(tank.car_travel<saved_height,"restored unsupported car resumes descent")
	check(await acquire("pawl"),"pawl is still selectable after restore")
	check(await move_to(0),"pawl can arrest restored car")
	click()
	var partial: Dictionary=tank.mechanism_snapshot()
	tank.restore_mechanism(partial)
	check(tank.mechanism_snapshot()==partial,"released partial brake and pawl state round-trips")
	var camera_before := player.camera.global_transform
	var look := InputEventMouseMotion.new();look.relative=Vector2(30,20)
	player._unhandled_input(look)
	check(player.camera.global_transform.is_equal_approx(camera_before),"inspection cursor leaves camera fixed")
