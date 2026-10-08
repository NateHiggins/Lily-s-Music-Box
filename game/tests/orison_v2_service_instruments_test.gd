extends "res://tests/orison_v2_domestic_native_test.gd"
## Render and exercise the original instruments in one composed production world.
var contract_checks: Array[String] = []
var contract_started := 0
var retained: Array[WeakRef] = []

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	contract_started = Time.get_ticks_msec()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_service_instruments.json"))
	check(FileAccess.get_sha256(str(fixture.runtime.asset))==fixture.asset_sha256,"native instrument export bound")
	var factory: RefCounted = world.adapter.root.get_meta("v2_native_service_instruments")
	check(factory.installed.size()==fixture.runtime.actors.size(),"all source instruments fabricated")
	var work_lights: RefCounted = world.adapter.root.get_meta("v2_native_service_work_lights")
	check(work_lights.installed.size()==6,"four alley and two shed lights reuse fitted native cages")
	var captured_variants := {}
	for row: Dictionary in work_lights.installed:
		var lamp: LightFixtureProp = row.lamp.get_ref()
		retained.append(weakref(lamp))
		check(lamp.position.is_equal_approx(row.position) and lamp.light.transform.is_equal_approx(row.light_pose),"work-light source anchor and emitter pose retained")
		check(lamp.light.get_instance_id()==row.light and lamp.bounce.get_instance_id()==row.bounce and lamp._halo.get_instance_id()==row.halo and lamp._swing_node.get_instance_id()==row.swing and lamp._bulb_mat.get_instance_id()==row.bulb_material,"work-light original optical and motion owners retained")
		check(is_equal_approx(lamp._base_energy,row.energy) and is_equal_approx(lamp.light.omni_range,row.range) and lamp.navigation_light==row.navigation and is_equal_approx(lamp.standby_scale,row.standby),"work-light photometric settings retained")
		var at := lamp.to_global(row.seat)
		var normal: Vector3 = lamp.global_basis*row.normal
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at-normal*.004,at+normal*.004,1))
		# Jolt reports the imported alley triangle 0.100 mm from its exact
		# authored plane. Keep a 0.2 mm contact tolerance, below the bevel.
		check(not hit.is_empty() and hit.position.distance_to(at)<.0002 and hit.normal.dot(-normal)>.99,"native work-light mounting seat meets actual wall or roof")
		if capture_enabled and not captured_variants.has(row.variant):
			captured_variants[row.variant]=true
			var local := lamp.position+Vector3(-.6 if row.variant=="AlleyEast" else .6,0,.65)
			local.y=.03
			var position := (lamp.get_parent() as Node3D).to_global(local)
			var target := lamp.to_global(Vector3(0,-.49,0))
			await _city_capture(world,position,target,"work_light_"+str(row.variant),"original work light",str(lamp.name))
			var powered_before := lamp.powered
			lamp.set_powered(false)
			await _city_capture(world,position,target,"work_light_"+str(row.variant)+"_off","original work light unpowered",str(lamp.name))
			check(not lamp.powered and not lamp.light.visible and not lamp.bounce.visible and not lamp._halo.visible,"work light retains original power-off control")
			lamp.set_powered(powered_before)
	for id in ["F01_WATCHMAN_DETECTOR_BODY","F01_NIGHT_REGISTER_BODY","F01_SIGNAL_REGISTER_BODY","F01_TOUR_KEY_GUARD_BODY"]:
		check(not (world.find_child(id,true,false) as Node3D).visible,"mounted instrument retires its gray-box stand-in")
	for identity: String in factory.installed:
		var entry: Dictionary = factory.installed[identity]
		var actor: Node3D = entry.actor.get_ref()
		retained.append(weakref(actor))
		check(actor.get_script().resource_path==entry.script,"original instrument authority: "+identity)
		check(not actor.find_children("*","Area3D",true,false).is_empty(),"original reach controls retained: "+identity)
		actor.set_process(false)
		for original: Dictionary in entry.source:
			var draw: MeshInstance3D = original.draw.get_ref()
			check(draw!=null and draw.get_parent().get_instance_id()==original.parent,"original mesh owner and animation parent retained")
			if original.preserve_material: check(draw.material_override==original.material,"original dynamic material owner retained")
			if str(original.replacement).is_empty(): check(draw.mesh==null,"superseded fake opening or segmented cord retired")
			else:
				check(draw.mesh is ArrayMesh,"source primitive replaced by native stock")
				_check_cap_mapping(draw.mesh,true)
	# The campaign owner's first read initializes its canonical arrival record.
	# Prime that existing seam before measuring reversible instrument actions.
	world.first_shift_director.ritual_phase()
	var saved := var_to_bytes(RealityState.data)
	var call_board := world.find_child("LobbyPorterBoard",true,false) as OtisProp
	var call_before := call_board.maintenance_snapshot()
	call_board.restore_maintenance_snapshot({"stuck_flag":false,"contact_alignment":1.,"bank_reset":1.})
	check(is_equal_approx(call_board._flag_arms[0].rotation.x,deg_to_rad(-8.)),"native call flags follow original reset")
	call_board.restore_maintenance_snapshot(call_before)
	check(call_board.maintenance_snapshot()==call_before,"call board cancel restores state")
	contract_checks.append("annunciator reset and cancel")
	var detector := world.find_child("F01_WATCHMAN_DETECTOR",true,false) as WatchmanClockProp
	var detector_before := detector.maintenance_snapshot()
	detector.preview_maintenance_step({"id":"stop_the_movement"},0.)
	detector.preview_maintenance_step({"id":"seat_the_dial"},.44)
	detector.preview_maintenance_step({"id":"set_the_datum"},detector.correct_datum())
	check(detector.dial_seated and detector.datum_set and not detector.movement_running,"native detector retains seating and datum controls")
	detector.restore_maintenance_snapshot(detector_before)
	check(detector.maintenance_snapshot()==detector_before,"detector cancel restores paper and movement")
	contract_checks.append("detector stop, paper seating, datum and cancel")
	var register := world.find_child("F01_NIGHT_REGISTER",true,false) as NightRegisterProp
	var register_before := register.maintenance_snapshot()
	check(register.take_key("apartment") and register.key_out("apartment"),"night register key uses original custody")
	check(not register.take_key("apartment"),"duplicate register key refused")
	check(register.return_key("apartment"),"night register key returns")
	register.restore_maintenance_snapshot(register_before)
	check(register.maintenance_snapshot()==register_before,"night register cancel restores state")
	contract_checks.append("night register key custody, duplicate denial and cancel")
	var signal_register := world.find_child("F01_SIGNAL_REGISTER",true,false) as WatchRegisterProp
	var signal_before := signal_register.maintenance_snapshot()
	signal_register.set_line_closed(false)
	check(not signal_register.receive_signal({"station_number":2}),"open signal line cannot release a native shutter")
	signal_register.set_line_closed(true)
	check(signal_register.receive_signal({"station_number":2}) and signal_register.shows(2),"closed line releases original shutter owner")
	check(signal_register.last_indication().keys()==["station_number","sequence"],"register records station and sequence only")
	signal_register.restore_maintenance_snapshot(signal_before)
	check(signal_register.maintenance_snapshot()==signal_before,"signal register cancel restores state")
	contract_checks.append("signal circuit refusal, shutter release, indication fields and cancel")
	var guard := world.find_child("F01_TOUR_KEY_GUARD",true,false) as TourKeyGuardProp
	var guard_before := guard.maintenance_snapshot()
	check(guard.take_key() and guard.key_carried(),"native guard releases original tour key")
	check(not guard.take_key(),"duplicate tour key refused")
	check(guard.return_key(),"native guard accepts tour key return")
	guard.restore_maintenance_snapshot(guard_before)
	check(guard.maintenance_snapshot()==guard_before,"tour guard cancel restores custody")
	contract_checks.append("tour key custody, duplicate denial and cancel")
	var panel := world.find_child("B1_FUSE_PANEL",true,false) as FusePanelProp
	var panel_before := panel.maintenance_snapshot()
	panel.preview_maintenance_step({"id":"draw_the_plug"},.55)
	check(not panel.plug_out,"energized fuse withdrawal refused")
	panel.preview_maintenance_step({"id":"pull_the_main"},0.)
	panel.preview_maintenance_step({"id":"draw_the_plug"},.55)
	check(panel.main_open and panel.plug_out and is_equal_approx(panel._window.position.z,.185),"native blades and mica follow isolated plug withdrawal")
	panel.restore_maintenance_snapshot(panel_before)
	check(panel.maintenance_snapshot()==panel_before,"fuse service cancel restores state")
	contract_checks.append("fuse live denial, main isolation, plug withdrawal and cancel")
	var telephone := world.find_child("F01_HOUSE_TELEPHONE_BOARD",true,false) as HouseSwitchboardProp
	var line := telephone.network as HouseTelephoneNetwork
	check(line.state==HouseTelephoneNetwork.LineState.IDLE,"production house line initially idle")
	check(line.request(str(line.endpoints.keys()[0])),"original house endpoint requests line")
	check(telephone.interact().accepted and telephone.interact().accepted,"original board answers and carries line")
	check(telephone._cord.visible and not is_zero_approx(telephone._key.rotation.z),"native continuous cord and trunk key follow carrying state")
	check(telephone.interact().accepted and not telephone._cord.visible,"original board releases and conceals native cord")
	contract_checks.append("telephone request, answer, carry, visible cord and release")
	var dumbwaiter := world.find_child("LobbyServiceDumbwaiter",true,false) as DumbwaiterProp
	var lift_before := dumbwaiter.maintenance_snapshot()
	dumbwaiter.preview_maintenance_step({"id":"ease_pawl"},1.)
	check(dumbwaiter.pawl_lift==0. and dumbwaiter.slipping(),"unsupported dumbwaiter pawl release refused")
	dumbwaiter.restore_maintenance_snapshot(lift_before)
	dumbwaiter.preview_maintenance_step({"id":"take_strain"},1.)
	dumbwaiter.preview_maintenance_step({"id":"ease_pawl"},1.)
	dumbwaiter.preview_maintenance_step({"id":"prove_balance"},1.)
	check(is_equal_approx(dumbwaiter._car.position.y,.30) and is_equal_approx(dumbwaiter._counterweight.position.y,.27),"native open car and counterweight follow full original travel")
	var ropes:=dumbwaiter.get_node("NativeSuspensionRopes")
	ropes.refresh()
	check(ropes.endpoints[0].is_equal_approx(dumbwaiter._car.position+Vector3(-.179,.15,0)) and ropes.endpoints[1].is_equal_approx(dumbwaiter._counterweight.position+Vector3(0,.12,.013)),"native draft ropes stay attached at full source travel")
	if capture_enabled: await _capture_instrument(world,dumbwaiter,"dumbwaiter_full_travel")
	dumbwaiter.restore_maintenance_snapshot(lift_before)
	ropes.refresh()
	check(dumbwaiter.maintenance_snapshot()==lift_before,"dumbwaiter cancel restores mechanism")
	contract_checks.append("dumbwaiter unsupported denial, strain, pawl, full travel and cancel")
	var tank := world.find_child("ROOF_TANK_BALLCOCK",true,false) as RoofTankBallcockProp
	var tank_before := tank.maintenance_snapshot()
	tank.preview_maintenance_step({"id":"lift_the_float"},1.)
	check(tank.float_lift==tank_before.float_lift and tank.balking(),"live riser refuses float lift")
	tank.preview_maintenance_step({"id":"shut_the_riser"},0.)
	tank.preview_maintenance_step({"id":"lift_the_float"},1.)
	tank.preview_maintenance_step({"id":"set_the_weight"},1.)
	check(not tank.float_waterlogged and is_equal_approx(tank._weight.position.x,.36),"native float and captive weight follow original service extremes")
	tank.restore_maintenance_snapshot(tank_before)
	check(tank.maintenance_snapshot()==tank_before,"tank service cancel restores original hydraulic state")
	contract_checks.append("tank live denial, isolation, float lift, weight extreme and cancel")
	if var_to_bytes(RealityState.data)!=saved:
		var prior: Dictionary = bytes_to_var(saved)
		for key in RealityState.data:
			if RealityState.data[key]!=prior.get(key): print("INSTRUMENT STATE DIFFERENCE ",key," before=",prior.get(key)," after=",RealityState.data[key])
	check(var_to_bytes(RealityState.data)==saved,"visual service previews and ordinary line operation write no saved fact")
	if capture_enabled:
		signal_register.set_line_closed(true)
		signal_register.receive_signal({"station_number":2})
		await _capture_instrument(world,signal_register,"signal_received")
		signal_register.restore_maintenance_snapshot(signal_before)
		panel.preview_maintenance_step({"id":"pull_the_main"},0.)
		panel.preview_maintenance_step({"id":"draw_the_plug"},.55)
		await _capture_instrument(world,panel,"fuse_isolated")
		panel.restore_maintenance_snapshot(panel_before)
		line.request(str(line.endpoints.keys()[0]));telephone.interact();telephone.interact()
		await _capture_instrument(world,telephone,"telephone_carrying")
		telephone.interact()
		for entry: Dictionary in factory.installed.values():
			var actor: Node3D = entry.actor.get_ref()
			await _capture_instrument(world,actor,str(actor.name))
		await _capture_instrument(world,tank,"roof_valve_detail")
	return {"checks":checks,"failures":failures}

func _capture_instrument(world: OrisonV2RuntimeRoot, actor: Node3D, label: String) -> void:
	var target := actor.to_global(Vector3(0,0 if actor is OtisProp else .25,0))
	var forward := actor.global_basis.z*(-1. if actor is HouseSwitchboardProp else 1.)
	var position := target+forward*(1.55 if actor is FusePanelProp else 1.05)
	if actor is DumbwaiterProp:
		target=actor.to_global(Vector3(0,.53,.20))
		position=actor.to_global(Vector3(0,0,1.05))
	position.y=world.adapter.root.to_global(Vector3(0,-3.17 if actor is FusePanelProp else .03,0)).y
	if actor is RoofTankBallcockProp:
		target=actor.to_global(Vector3(-.14,.75,.10))
		position=actor.to_global(Vector3(-.14,0,3.2))
		position.y=world.adapter.root.to_global(Vector3(0,19.23,0)).y
		if label=="roof_valve_detail":
			target=actor.to_global(Vector3(.03,.25,.12))
			position=actor.to_global(Vector3(.03,0,1.25))
			position.y=world.adapter.root.to_global(Vector3(0,19.23,0)).y
	var sight := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP*world.player.STANDING_EYE,target,1,[world.player.get_rid()]))
	check(sight.is_empty() or sight.position.distance_to(target)<.18,"clear actual instrument inspection: "+label)
	# Hold the same carried-lamp output for each plate; no new scene lights.
	var air := world.get_node("LampAtmosphere")
	var optical := preload("res://scripts/lamp/lamp_optical_state.gd").new()
	optical.configure(0x28A11CE,true);optical.advance(2.)
	air.driver.state.restore_state(optical.save_state());air.driver.apply_output()
	await _city_capture(world,position,target,label,"original mounted service instrument",str(actor.name))

func validate_after_teardown() -> Dictionary:
	for ref in retained: check(ref.get_ref()==null,"original instrument retires with production world")
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array=[];var digest: Array=[]
	check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"contract records repository head")
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"contract records runtime digest")
	var passed := failures.is_empty()
	var status := "PASS" if passed else "FAIL"
	var path: String=get_script().resource_path
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Native service instruments in the composed V2 world: original mechanism ownership, reversible service controls, transient custody, ordinary telephone line and world retirement. Player approach routing and save reconstruction are not exercised.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-contract_started)/1000.},
		"source":{"test_path":"game/"+path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(path),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},
		"contracts":{"production_composition":{"executed":true,"status":status},"premature_action_denial":{"executed":true,"status":status},"save_reconstruction":{"executed":false,"status":"NOT_EXECUTED"},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":retained.filter(func(r):return r.get_ref()!=null).size()}},"exercised_controls":contract_checks,"checks":checks,"failures":failures}
	var directory := OS.get_environment("SHOT_DIR").path_join("service_instruments")
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	return {"checks":checks,"failures":failures}
