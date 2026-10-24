extends Node3D
## Focused mechanism bench; production player, leaves and fixture owners.
var failures: Array[String] = []
var checks := 0
var player: PlayerController

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("GRAB CHECK: ",label," = ",ok)

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	player._unhandled_input(event)

func drag(delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = delta
	player._unhandled_input(event)

func _run() -> void:
	RealityState.persistence_enabled = false
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.12,.13,.15)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.9,.94,1)
	environment.environment.ambient_light_energy = .65
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-25,0)
	sun.light_energy = 1.6
	add_child(sun)
	player = PlayerController.new()
	add_child(player)
	player.set_physics_process(false)
	player.position = Vector3(.4,0,-1.7)
	player.camera.current = true
	player.set_beam_mask_enabled(false)
	player.set_lamp_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var door := DoorProp.new()
	add_child(door)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var door_state := preload("res://scripts/building/orison_v2_household_state.gd").new()
	add_child(door_state)
	door_state._subjects={"bench_door":door}
	door_state._kinds={"bench_door":"mechanism"}
	door_state._defaults=door_state.snapshot()
	RealityState.data[door_state.KEY]=door_state._defaults.duplicate(true)
	door_state._restore(RealityState.data[door_state.KEY])
	door_state._bound=true
	door_state._connect(RealityState,"state_changed",door_state._on_state_changed)
	player.camera.look_at(Vector3(.4,1.1,0))
	print("GRAB TARGET: ",player._grab.find_target().keys()," mode=",Input.mouse_mode," lock=",player.call_locked)
	click()
	check(player._grab.active(),"mouse click acquires actual leaf hit")
	check(is_zero_approx(door._body.rotation.y),"acquire does not open leaf")
	var camera_pose := player.camera.global_transform
	for i in 8:
		drag(Vector2(8,0))
		await get_tree().physics_frame
	check(absf(door._body.rotation.y)>.01,"mouse displacement moves leaf")
	check(player.camera.global_transform.is_equal_approx(camera_pose),"hand motion leaves camera stable")
	var angle := door._body.rotation.y
	RealityState.commit()
	check(player._grab.active() and is_equal_approx(angle,door._body.rotation.y),"unrelated commit preserves held unsaved door position")
	click()
	check(not player._grab.active(),"second click releases")
	check(is_equal_approx(angle,door._body.rotation.y),"release retains partial angle")
	player.camera.look_at(door._body.to_global(Vector3(door.width*.5,1.1,0)))
	await get_tree().physics_frame
	click()
	check(player._grab.active(),"actual click reacquires leaf before document replacement")
	RealityState.data=RealityState.data.duplicate(true)
	check(not door_state.capture_now(),"snapshot during document replacement cannot overwrite incoming save")
	RealityState.state_changed.emit()
	await get_tree().physics_frame
	check(not player._grab.active() and is_zero_approx(door._body.rotation.y),"equal-valued replacement document restores saved position and releases hand")
	door_state.shutdown()
	door_state.queue_free()
	player.camera.look_at(Vector3(.4,1.1,0))
	door.restore_mechanism({"angle":0.0})
	await get_tree().physics_frame
	click()
	door.npc_set_open(true)
	check(is_zero_approx(door._body.rotation.y),"resident cannot take a held leaf")
	player.position.z=-4
	player._grab.validate()
	check(not player._grab.active() and not door._moving,"walking out of reach releases ownership")
	player.position.z=-1.7
	door.leaf_state="locked"
	await get_tree().physics_frame
	click();drag(Vector2(20,0));click()
	check(is_zero_approx(door._body.rotation.y) and door.leaf_state=="locked","locked leaf resists hand motion")
	door.leaf_state="closed"
	door.restore_mechanism({"angle":angle})
	_check_restore_revokes_hand(door)
	var fridge := FridgeProp.new()
	fridge.prop_type = "fridge"
	fridge.position = Vector3(3,0,0)
	add_child(fridge)
	check(fridge._door.get_node_or_null("ManipulationTarget")!=null,"food door has moving target")
	check(fridge._ice_door.get_node_or_null("ManipulationTarget")!=null,"ice door independently targetable")
	check(fridge._tray.get_node_or_null("ManipulationTarget")!=null,"drip tray independently targetable")
	var tap := preload("res://scripts/building/orison_v2_kitchen_sink.gd").new()
	tap.prop_type = "sink"
	tap.fixture = "kitchen_sink"
	tap.position = Vector3(-3,0,0)
	add_child(tap)
	check(preload("res://scripts/building/orison_v2_sink.gd").new().mount(tap),"installed sink collision mounts on bench")
	check(tap._handles.size()==2,"native tap retains two pivots")
	tap.set_valve_opening(0,.25)
	tap.set_valve_opening(1,.75)
	var flow: Dictionary = tap.get_flow_state()
	check(is_equal_approx(float(flow.hot_opening),.25) and is_equal_approx(float(flow.cold_opening),.75),"independent continuous valve values")
	check(is_equal_approx(float(flow.temperature),.175),"mix weighted by actual openings")
	tap.set_valve_opening(0,0)
	tap.set_valve_opening(1,.1)
	check(is_equal_approx(float(tap.get_flow_state().flow),.1),"partial valve produces trickle")
	check(tap._handles[0].get_node_or_null("ManipulationTarget")!=null,"tap targets real moving handle")
	var saved_door := door.mechanism_snapshot()
	door.restore_mechanism({"angle":0.0})
	door.restore_mechanism(saved_door)
	check(is_equal_approx(door._body.rotation.y,angle),"partial door reconstruction")
	var saved_tap: Dictionary = tap.mechanism_snapshot()
	tap.set_running(false)
	tap.restore_mechanism(saved_tap)
	check(is_equal_approx(tap._valve_openings.y,.1),"partial faucet reconstruction")
	check(not tap.valid_mechanism({"hot":NAN,"cold":0.0}),"nonfinite valve save refused")
	tap.set_running(false)
	tap.set_stopper(true)
	check(tap._stopper and tap._plug_hand.part.position.is_equal_approx(tap._plug_hand.seat),"plug seats in drain and seals actual water owner")
	player.position=tap.position+Vector3(0,0,-.7)
	player.camera.look_at(tap._kitchen_plug.global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var standing_floor:=StaticBody3D.new();standing_floor.position.y=-.1;add_child(standing_floor)
	var floor_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new();floor_box.size=Vector3(12,.2,12);floor_shape.shape=floor_box;standing_floor.add_child(floor_shape)
	player.velocity=Vector3.ZERO;player.set_physics_process(true)
	var plug_before: Vector3=tap._kitchen_plug.position
	click()
	check(player._grab.active() and tap._plug_hand.held,"mouse acquires visible loose plug")
	check(tap._kitchen_plug.position.is_equal_approx(plug_before),"plug acquisition has no automatic lift")
	drag(Vector2(0,-35))
	for frame in 8:await get_tree().physics_frame
	check(player._grab.holding_pickup(),"loose plug follows the physical FPS hand within its chain reach")
	check(tap._kitchen_plug.position.y>plug_before.y and not tap._stopper,"mouse lifts plug and opens drain")
	click()
	player.set_physics_process(false)
	await get_tree().create_timer(.3).timeout
	check(not tap._plug_hand.held and tap._plug_hand.resting,"released plug settles under gravity")
	check(is_equal_approx(tap._kitchen_plug.position.y,tap._plug_hand.support(tap._kitchen_plug.position)),"released plug rests on casting surface")
	tap._plug_hand.write_position(tap._plug_hand.seat+Vector3(.09,.10,-.04))
	var loose_saved: Dictionary=tap.mechanism_snapshot()
	tap.set_stopper(true);tap.restore_mechanism(loose_saved)
	check(tap._kitchen_plug.position.is_equal_approx(Vector3(loose_saved.plug[0],loose_saved.plug[1],loose_saved.plug[2])) and not tap._stopper,"loose plug reconstruction preserves position and open drain")
	var invalid_plug: Dictionary=loose_saved.duplicate(true);invalid_plug.plug[0]=100
	check(not tap.valid_mechanism(invalid_plug),"out-of-basin plug save rejected")
	var bath := preload("res://scripts/building/orison_v2_kitchen_sink.gd").new();bath.position=Vector3(-4.5,0,0);add_child(bath)
	check(preload("res://scripts/building/orison_v2_sink.gd").new().mount(bath),"installed bath collision mounts on bench")
	bath.set_stopper(true)
	var bath_grip: Dictionary=bath._plug_hand.grip()
	bath_grip.begin.call();bath_grip.write.call(bath._plug_hand.seat+Vector3(.08,.10,0))
	check(not bath._stopper and bath._plug_hand.held,"native bath plug follows hand independently of valve animation")
	bath_grip.end.call()
	await get_tree().create_timer(.3).timeout
	check(bath._plug_hand.resting and bath._bath_plug.position.y>=bath._plug_hand.support(bath._bath_plug.position)-.0001,"bath plug settles onto curved casting")
	var shower := TapProp.new();shower.fixture="shower";shower.prop_type="shower"
	shower.position=Vector3(-12,0,2);add_child(shower)
	player.position=shower.position+Vector3(0,-.35,-1.1)
	player.camera.look_at(shower.to_global(Vector3(0,1.25,-.32)))
	await get_tree().physics_frame
	await get_tree().physics_frame
	click()
	check(player._grab.active() and shower._curtain_hand.held,"mouse acquires actual shower cloth")
	check(is_zero_approx(shower._curtain_hand.travel),"curtain acquisition has no pose switch")
	for i in 5: drag(Vector2(-12,0))
	check(shower._curtain_hand.travel>.02 and shower._curtain_hand.travel<shower._curtain_hand.TRAVEL,"mouse gathers curtain continuously along rail")
	var curtain_saved: Dictionary=shower.mechanism_snapshot()
	click()
	check(not shower._curtain_hand.held and is_equal_approx(shower._curtain_hand.travel,curtain_saved.curtain),"curtain release keeps intermediate gathering")
	shower.set_curtain_open(true)
	check(shower._curtain_closed.visible and not shower._curtain_gathered.visible,"same authored cloth deforms through fully gathered pose")
	shower.restore_mechanism(curtain_saved)
	check(is_equal_approx(shower._curtain_hand.travel,curtain_saved.curtain),"partial curtain gathering restores")
	# Full travel should take the same gesture at different standing distances
	# and fields of view, including through the U rail's direction changes.
	for distance: float in [.85,1.55]:
		for fov: float in [55.,85.]:
			shower.set_curtain_open(false)
			player.position=shower.position+Vector3(0,-.35,-distance)
			player.camera.fov=fov;player.camera.look_at(shower.to_global(Vector3(0,1.25,-.32)))
			for frame in 2:await get_tree().physics_frame
			click()
			check(player._grab.active() and shower._curtain_hand.held,"uniform gesture acquires the real cloth")
			for step in 24:drag(Vector2(-12,0));await get_tree().physics_frame
			print("CURTAIN GESTURE: distance=",distance," fov=",fov," pixels=288 opening=",shower._curtain_hand.travel)
			check(is_equal_approx(shower._curtain_hand.travel,shower._curtain_hand.TRAVEL),"288-pixel gesture opens the complete rail")
			for step in 24:drag(Vector2(12,0));await get_tree().physics_frame
			check(is_zero_approx(shower._curtain_hand.travel),"matching reverse gesture closes the complete rail")
			click();check(not shower._curtain_hand.held,"next primary releases the gathered cloth")
	player.camera.fov=72.
	var prep := preload("res://scripts/building/orison_v2_prep_cabinet.gd").new()
	prep.position=Vector3(-6,0,0);add_child(prep);prep.setup("test")
	prep.restore_travel(.37)
	check(is_equal_approx(prep._slide.position.x,prep.TRAVEL*.37),"sliding cabinet restores partial travel")
	var blind := preload("res://scripts/building/orison_v2_window_treatment.gd").new()
	blind.position=Vector3(-8,2,0);add_child(blind)
	var blind_grip: Dictionary = blind.control_grip("tilt",blind._wand)
	check(blind_grip.begin.call(),"blind wand can be taken")
	blind_grip.write.call(deg_to_rad(31.0));blind_grip.end.call()
	check(is_equal_approx(blind.tilt_degrees,31.0),"slats retain continuous angle after release")
	var mirror := preload("res://scripts/building/orison_v2_medicine_cabinet.gd").new()
	mirror.position=Vector3(-10,0,0);add_child(mirror);mirror.restore_travel(.42)
	await get_tree().physics_frame
	check(is_equal_approx(mirror._swing,.42),"medicine cabinet does not tween away from hand pose")
	# Load the shared save owner and switch adapter in this focused batch too.
	var household := preload("res://scripts/building/orison_v2_household_state.gd").new()
	household.free()
	var switch := preload("res://scripts/building/switch_plate.gd").new()
	switch.free()
	var lamp := LampProp.new();lamp.position=Vector3(6,0,0);add_child(lamp)
	var lamp_grip: Dictionary=lamp._key_grip()
	check(lamp_grip.begin.call(),"task lamp key acquires without power change")
	lamp_grip.write.call(-.4);lamp_grip.end.call()
	check(not lamp.is_locally_enabled(),"task lamp key crosses physical off contact")
	var fan := BoxFanProp.new();fan.position=Vector3(8,0,0);add_child(fan)
	var fan_grip: Dictionary=fan._selector_grip()
	check(fan_grip.begin.call(),"fan selector can be taken")
	fan_grip.write.call(deg_to_rad(42));fan_grip.end.call()
	check(fan.speed_step()==3,"fan selector moves through speed contacts")
	var toaster := ToasterProp.new();toaster.position=Vector3(10,0,0);add_child(toaster)
	var lever_grip: Dictionary=toaster._toaster_grip("lever")
	check(lever_grip.begin.call(),"toaster lever acquisition")
	lever_grip.write.call(toaster.LEVER_TRAVEL*.4)
	check(toaster.state==FunctionalProp.PState.IDLE,"partial toaster stroke does not start cycle")
	lever_grip.write.call(toaster.LEVER_TRAVEL);lever_grip.end.call()
	check(toaster.state==FunctionalProp.PState.OPERATING,"full physical stroke latches toaster")
	var radiator := RadiatorProp.new();radiator.position=Vector3(12,0,0);add_child(radiator)
	var wheel_grip: Dictionary=radiator.supply_grip()
	check(wheel_grip.begin.call(),"radiator wheel acquisition")
	wheel_grip.write.call(TAU*3.5*.35);wheel_grip.end.call()
	check(is_equal_approx(radiator.supply_position,.35),"radiator wheel retains actual fractional turns")

	var stove := StoveProp.new();stove.position=Vector3(14,0,0);add_child(stove)
	var oven_grip: Dictionary=stove._range_grip(stove._door)
	check(oven_grip.begin.call(),"oven leaf acquisition")
	oven_grip.write.call(.63);oven_grip.end.call()
	stove.set_door_open(false,.3)
	check(oven_grip.begin.call(),"hand interrupts oven's previous motorless animation")
	oven_grip.write.call(.51);oven_grip.end.call()
	var working_ring: int = (stove.blocked_burner+1)%4
	var cold_ring: int = (working_ring+1)%4
	var gas: Dictionary = stove.gas_grip(working_ring)
	stove.set_burner_lit(working_ring,true,1.0)
	check(gas.begin.call(),"range gas cock acquisition")
	gas.write.call(deg_to_rad(58)*.35)
	check(is_equal_approx(stove._gas_openings[working_ring],.35) and stove._burner_on[working_ring],"lit ring follows fractional valve opening")
	check(not stove.set_burner_lit(working_ring,false),"director cannot overwrite held gas cock")
	gas.end.call()
	var cold_gas: Dictionary = stove.gas_grip(cold_ring)
	cold_gas.begin.call();cold_gas.write.call(deg_to_rad(58)*.6);cold_gas.end.call()
	check(not stove._burner_on[cold_ring] and not stove._flames[cold_ring].visible,"cold gas cock never invents ignition")
	var stove_saved: Dictionary = stove.mechanism_snapshot()
	stove._set_gas_opening(working_ring,0)
	check(not stove._burner_on[working_ring],"closing gas extinguishes ring")
	stove._set_gas_opening(working_ring,.5)
	check(not stove._burner_on[working_ring],"reopening extinguished ring needs ignition")
	stove.restore_mechanism(stove_saved)
	check(stove._burner_on[working_ring] and is_equal_approx(stove._gas_openings[working_ring],.35),"gas and existing flame restore together")
	var bad_stove: Dictionary = stove_saved.duplicate(true)
	bad_stove.gas[working_ring]=0.0
	check(not stove.valid_mechanism(bad_stove),"saved flame without gas rejected")
	player.position = stove.position + Vector3(0,-.25,-1.15)
	player.camera.look_at(stove._knobs[working_ring].global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	click()
	check(player._grab.active() and stove._hand_part==stove._knobs[working_ring],"mouse takes actual burner knob")
	var gas_before: float = stove._gas_openings[working_ring]
	drag(Vector2(14,0));drag(Vector2(0,14))
	check(not is_equal_approx(stove._gas_openings[working_ring],gas_before),"mouse motion adjusts gas cock")
	var gas_release: float = stove._gas_openings[working_ring]
	click()
	await get_tree().create_timer(1.1).timeout
	check(is_equal_approx(stove._gas_openings[working_ring],gas_release) and is_equal_approx(stove._burner_lights[working_ring].light_energy,.11*gas_release),"release retains gas and old light tween cannot overwrite flame")
	var washer := WasherProp.new();washer.position=Vector3(16,0,0);add_child(washer)
	washer.set_wringer_swing(90,0)
	var lid_grip: Dictionary=washer._washer_grip("lid")
	check(lid_grip.begin.call(),"washer lid acquisition")
	lid_grip.write.call(.7);lid_grip.end.call()
	var release_grip: Dictionary=washer._washer_grip("release")
	check(release_grip.begin.call(),"wringer release acquisition")
	release_grip.write.call(deg_to_rad(3))
	check(washer._roller_gap==0,"release bar partial travel does not trip safety")
	release_grip.write.call(deg_to_rad(8));release_grip.end.call()
	check(washer._roller_gap>=.04,"full release bar travel opens roller gap")
	var pressure_grip: Dictionary = washer.pressure_grip()
	check(pressure_grip.begin.call(),"wringer pressure screw acquisition")
	pressure_grip.write.call(TAU * 1.5);pressure_grip.end.call()
	check(is_equal_approx(washer._pressure_screw.position.y-washer._pressure_bridge.position.y,.0095),"pressure screw advances along its own thread axis")
	check(washer._roller_gap>=.04,"tightening cannot defeat tripped safety")
	washer.set_wringer_gap(0.0)
	check(is_equal_approx(washer._roller_gap,.0045),"pressure screw governs minimum roller clearance")
	var saved_washer: Dictionary = washer.mechanism_snapshot()
	washer._set_pressure_turn(0.0);washer.restore_mechanism(saved_washer)
	check(is_equal_approx(washer._pressure_turn,TAU*1.5) and is_equal_approx(washer._roller_gap,.0045),"thread position and roller clearance reconstruct together")
	check(not washer.valid_mechanism({"lid":0.0,"swing":0.0,"gap":0.0,"pressure":NAN}),"invalid pressure state refused")
	player.position = washer.position + Vector3(1.1,0,.2)
	var pressure_contact := washer._pressure_screw.to_global(Vector3(.07,.09,0))
	player.camera.look_at(pressure_contact)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before_pressure: float = washer._pressure_turn
	click()
	check(player._grab.active() and washer._hand_control=="pressure","mouse targets actual pressure handle")
	check(is_equal_approx(washer._pressure_turn,before_pressure),"pressure acquisition makes no adjustment")
	if player._grab.active():
		for step in 5:
			var point: Vector3 = washer._pressure_screw.to_global(player._grab.contact)
			var tangent := washer._yoke.global_basis.y.cross(point-washer._pressure_screw.global_position)
			var screen_tangent := player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point)
			drag(screen_tangent.normalized()*8.0)
			await get_tree().physics_frame
	check(washer._pressure_turn>before_pressure,"mouse turns pressure screw counterclockwise to loosen")
	var released_pressure: float = washer._pressure_turn
	click()
	await get_tree().process_frame
	check(not player._grab.active() and is_equal_approx(washer._pressure_turn,released_pressure),"pressure handle retains its setting on second click")
	var airer := preload("res://scripts/building/orison_v2_laundry_airer.gd").new()
	airer.position=Vector3(18,0,0);add_child(airer)
	var airer_grip: Dictionary=airer._airer_grip()
	check(airer_grip.begin.call(),"native laundry rack acquisition")
	airer_grip.write.call(1.67);airer_grip.end.call()
	await get_tree().create_timer(.4).timeout
	check(is_equal_approx(stove._door.rotation.x,-.51),"released oven retains partial pose after killed tween")
	check(is_equal_approx(washer._lid.rotation.x,.7),"washer lid retains partial pose")
	check(is_equal_approx(airer._rack.position.y,1.67),"native pulley airer retains intermediate height")
	check(stove.valid_mechanism(stove.mechanism_snapshot()) and washer.valid_mechanism(washer.mechanism_snapshot()) and airer.valid_mechanism(airer.mechanism_snapshot()),"range and laundry partial poses validate for household save")

	var boiler := BoilerProp.new();boiler.position=Vector3(20,0,0);add_child(boiler)
	for cock: Node3D in boiler._column_cocks:
		var grip: Dictionary=boiler._boiler_grip(cock)
		check(grip.begin.call(),"individual boiler column cock acquisition")
		grip.write.call(0.0);grip.end.call()
	var drain_grip: Dictionary=boiler._boiler_grip(boiler._blowdown_lever)
	check(drain_grip.begin.call(),"column drain lever acquisition")
	drain_grip.write.call(deg_to_rad(34))
	await get_tree().create_timer(1.5).timeout
	check(boiler._glass_level<.025 and boiler._drain_proved,"actual isolated column drains while lever held")
	check(is_equal_approx(boiler.water_level,.62),"column proof does not change boiler water quantity")
	drain_grip.end.call()
	for cock: Node3D in boiler._column_cocks:
		var grip: Dictionary=boiler._boiler_grip(cock)
		grip.begin.call();grip.write.call(deg_to_rad(82));grip.end.call()
	var witness_grip: Dictionary=boiler._boiler_grip(boiler._witness_marker)
	witness_grip.begin.call();witness_grip.write.call(.85);witness_grip.end.call()
	await get_tree().create_timer(1.6).timeout
	check(not boiler.column_proved,"wrong witness mark cannot certify returning water")
	witness_grip.begin.call();witness_grip.write.call(boiler._column_level_y(boiler.water_level));witness_grip.end.call()
	await get_tree().process_frame
	await get_tree().process_frame
	check(boiler.column_proved and not boiler.column_isolated,"physical drain, return and witness complete original service outcome "+str(boiler.mechanism_snapshot()))
	check(boiler.valid_mechanism(boiler.mechanism_snapshot()),"boiler partial mechanisms are durable")

	var obstacle := StaticBody3D.new();var obstruction := CollisionShape3D.new();var obstruction_box := BoxShape3D.new()
	obstruction_box.size=Vector3(.9,1.8,.08);obstruction.shape=obstruction_box;obstacle.add_child(obstruction)
	obstacle.position=fridge.position+Vector3(0,.9,-.55);add_child(obstacle)
	await get_tree().physics_frame;await get_tree().physics_frame
	var food_grip: Dictionary=fridge._part_grip(fridge._door)
	food_grip.begin.call();food_grip.write.call(1.2);food_grip.end.call()
	var stopped := fridge._door.rotation.y
	check(stopped<1.0,"fridge leaf sweep stops before external solid")
	obstacle.free();await get_tree().physics_frame
	food_grip.begin.call();food_grip.write.call(1.2);food_grip.end.call()
	check(fridge._door.rotation.y>stopped+.1,"removing obstruction permits fridge travel")
	var shot_dir := OS.get_environment("SHOT_DIR")
	if not shot_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(shot_dir)
		for subject: Node3D in [door,tap,bath,shower,lamp,fan,toaster,radiator,stove,washer,airer,boiler]:
			var target := subject.global_position+Vector3(0,.4,0)
			if subject==door:target.y=1.0
			if subject==shower:target.y=1.15
			if subject==tap or subject==bath:target.y=.79
			if subject==boiler:target.y=1.0
			if subject==washer:target.y=.75
			if subject==airer:target.y=1.3
			player.global_position=target+Vector3(.4,-player.camera.position.y,-2.4 if subject in [boiler,washer,airer,shower] else -1.25)
			if subject==tap or subject==bath: player.global_position=target+Vector3(.20,.65,-.62)-player.camera.position
			player.camera.look_at(target)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot_dir+"/"+str(subject.get_script().resource_path).get_file().get_basename()+ ("_shower" if subject==shower else "_bath" if subject==bath else "")+".png")
		player.global_position=shower.global_position+Vector3(.75,1.35-player.camera.position.y,-2.1)
		player.camera.look_at(shower.global_position+Vector3(0,1.15,0))
		for travel: float in [0.0,.89,1.78]:
			shower._curtain_hand.set_travel(travel)
			await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot_dir+"/curtain_"+str(travel)+".png")
	player._grab.release()
	door.free();fridge.free();tap.free();bath.free();shower.free();player.free();prep.free();blind.free();mirror.free()
	lamp.free();fan.free();toaster.free();radiator.free();stove.free();washer.free();airer.free();boiler.free();sun.free();environment.free()
	await get_tree().process_frame
	print("DIRECT MANIPULATION: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)

## Restoration is synchronous; no elapsed-time event grants custody.
func _check_restore_revokes_hand(door: DoorProp) -> void:
	var before := door.mechanism_snapshot()
	var old_grip: Dictionary=door.manipulation_target({"collider":door._body})
	old_grip.hit_position=door._body.to_global(Vector3(.4,1.0,0))
	check(player._grab.acquire(old_grip),"player can acquire leaf before state restoration")
	door.restore_mechanism({"angle":.2})
	player._grab.validate()
	check(not player._grab.active() and is_equal_approx(door._body.rotation.y,.2),"restoration revokes old hand ownership without overwriting new pose")
	door.restore_mechanism(before)
