extends Node3D
var tank: RoofTankBallcockProp
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
	print("TANK HAND CHECK: ",label," = ",ok)

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	player._unhandled_input(event)

func acquire(key: String) -> bool:
	var part: MeshInstance3D=tank._hand_controls.parts[key]
	var local_point := part.get_aabb().get_center()
	if key=="stop": local_point.x+=.066
	var point := part.to_global(local_point)
	if player.inspecting(): Input.warp_mouse(player.camera.unproject_position(point))
	else: player.camera.look_at(point)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var candidate: Dictionary=player._grab.find_target()
	if candidate.get("owner")!=tank:
		var query := PhysicsRayQueryParameters3D.create(player.camera.global_position,point,1,[player.get_rid()])
		query.collide_with_areas=true
		print("TANK PICK DIAGNOSTIC: ",key," point=",point," camera=",player.camera.global_position," candidate=",candidate," cursor=",get_viewport().get_mouse_position()," projected=",player.camera.unproject_position(point)," hit=",get_world_3d().direct_space_state.intersect_ray(query))
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
			if tangent.length()<.025: tangent=axis.cross(player.camera.global_basis.x)*.06
		var screen: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
		var event := InputEventMouseMotion.new()
		event.relative=screen*clampf(goal-value,-.15 if target.kind=="hinge" else -.04,.15 if target.kind=="hinge" else .04)
		var before_screen: Vector2=player.camera.unproject_position(point)
		player._unhandled_input(event)
		await get_tree().physics_frame
		if target.kind=="hinge" and absf(float(target.read.call())-value)>.001:
			var after_screen: Vector2=player.camera.unproject_position(target.part.to_global(player._grab.contact))
			if (after_screen-before_screen).dot(event.relative)<0: wheel_follows_cursor=false
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
	tank=RoofTankBallcockProp.new();tank.name="ROOF_TANK_BALLCOCK";add_child(tank)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/service_instruments.json"))
	data.actors=data.actors.filter(func(a): return a.id=="ROOF_TANK_BALLCOCK")
	data.source_materials=[];data.work_lights=[];data.dumbwaiter_ropes=[]
	var file := FileAccess.open("user://tank_hand_native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
	var factory := preload("res://scripts/building/orison_v2_native_service_instruments.gd").new()
	check(factory.mount(self,"user://tank_hand_native.json"),"native tank geometry binds")
	if tank._hand_controls==null:
		print(factory.errors);get_tree().quit(1);return
	player=PlayerController.new()
	add_child(player)
	player.set_physics_process(false)
	player.position=Vector3(.35,-.75,1.45)
	player.camera.current=true;player.set_lamp_enabled(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await exercise()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("tank_repaired.png"))
	print("TANK HAND RESULT: ",checks," checks, ",failures," failures")
	player.cancel_manipulation();player.queue_free();tank.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures==0 else 1)


func exercise() -> void:
	check(await acquire("stop"),"click acquires actual stop wheel")
	check(tank.riser_open and tank._service_panel==null,"grab does not toggle or open overlay")
	var event := InputEventKey.new()
	event.keycode=KEY_SPACE;event.physical_keycode=KEY_SPACE;event.pressed=true
	player._unhandled_input(event)
	check(player.inspecting(),"Space inspects the exposed mechanism")
	if player._grab.active(): click()
	# Let the changed inspection lens reach a rendered frame before projecting
	# small targets into cursor coordinates. Camera motion itself is synchronous.
	await RenderingServer.frame_post_draw
	await get_tree().physics_frame
	var camera_before := player.camera.global_transform
	check(await acquire("weight"),"weight remains movable before repairing float")
	check(await move_to(.46),"full weight travel is physical even with waterlogged float")
	click()
	check(tank.overflow_running() and not tank.valve_holds(),"maximum leverage cannot hide the buoyancy fault")
	check(await acquire("float"),"float can be selected independently")
	await move_to(.12)
	check(tank.float_waterlogged and is_zero_approx(tank.float_lift),"live riser refuses float withdrawal")
	if player._grab.active(): click()
	check(await acquire("stop"),"wheel can be reacquired")
	check(await move_to(2.0),"wheel preserves intermediate rotation")
	click()
	var saved := tank.mechanism_snapshot()
	check(tank.valid_mechanism(saved),"partial state validates")
	tank.restore_mechanism(JSON.parse_string(JSON.stringify(saved)))
	check(is_equal_approx(tank._hand_controls.stop_angle,2.0),"partial rotation survives serialization")
	check(await acquire("stop"),"restored wheel selectable")
	check(await move_to(TAU*2),"clockwise turns close the riser")
	click()
	check(not tank.riser_open and not tank.ballcock_serviced,"isolation does not certify repair")
	check(await acquire("float"),"isolated float selectable")
	check(await move_to(.14),"mouse lifts float along guide")
	check(not tank.float_waterlogged,"held-clear float drains")
	check(await move_to(0),"float returned to working position")
	click()
	check(await acquire("weight"),"captive lever weight selectable")
	check(await move_to(.46*.8),"weight slides along lever")
	click()
	check(tank.valve_holds() and not tank.ballcock_serviced,"leverage alone cannot certify isolated tank")
	check(await acquire("indicator"),"indicator is an independently selectable slide")
	check(await move_to(.9),"indicator follows hand along its gauge")
	click()
	var indicator: float=tank.tell_tale
	check(await acquire("stop"),"supply wheel selectable for reopening")
	check(await move_to(0),"counterclockwise turns restore supply")
	click()
	await get_tree().create_timer(1.9).timeout
	check(tank.ballcock_serviced and not tank.overflow_running(),"sustained physical hold publishes repair")
	check(is_equal_approx(tank.tell_tale,indicator),"repair publication does not snap the physical indicator")
	check(wheel_follows_cursor,"wheel rim follows the direction of mouse travel")
	check(player.camera.global_transform.is_equal_approx(camera_before),"inspection camera remains fixed")
	var invalid := tank.mechanism_snapshot();invalid.stop_angle=NAN
	check(not tank.valid_mechanism(invalid),"nonfinite save rejected")
	player.end_inspection()
	check(is_equal_approx(player.camera.fov,72.0),"inspection restores ordinary lens")
