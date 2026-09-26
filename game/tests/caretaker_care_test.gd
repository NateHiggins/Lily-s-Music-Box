extends Node
var failures: Array[String] = []
const Prep := preload("res://scripts/building/orison_v2_prep_cabinet.gd")
const Economy := preload("res://scripts/game/caretaker_economy.gd")

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name()=="headless": get_tree().quit(2); return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	CampaignClock.new().configure_date(1928,11,10,20*60)
	var world := preload("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(.5).timeout
	if world.startup_failed: get_tree().quit(2); return
	var care = world.get_node("Caretaking")
	var economy = world.get_node("CaretakerEconomy")
	var notebook = world.get_node("CaretakerNotebook")
	_check(care.subjects.size()>50,"fitted household roster mounted")
	var tap: TapProp
	var cabinet: MedicineCabinetProp
	for prop: Node in care.subjects.values():
		if prop is TapProp and prop.fixture=="shower" and prop.unit=="2A": tap=prop
		if prop is MedicineCabinetProp and prop.unit=="2A": cabinet=prop
	_check(tap!=null and cabinet!=null,"Mina has physical service subjects")
	if tap==null or cabinet==null: get_tree().quit(2); return
	tap.set_curtain_open(true)
	var player: PlayerController = world.player
	player.set_physics_process(false)
	player.camera.make_current()
	var control := tap.get_node("HotValveControl") as Node3D
	player.global_position = control.global_position-tap.global_basis.z*1.2-Vector3.UP*player.STANDING_EYE
	player.camera.global_position = player.global_position+Vector3.UP*player.STANDING_EYE
	player.camera.look_at(control.global_position)
	await get_tree().physics_frame
	_check(notebook.aimed_subject()==tap,"real interaction ray reaches shower service owner")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	_check(notebook.action_hint()=="[I] Inspect / care","reachable fixture advertises physical inspection")
	var set_carriers := world.find_children("*","ServiceSetCarrier",true,false)
	_check(not set_carriers.is_empty(),"physical paper carrier present")
	if not set_carriers.is_empty():
		var carrier = set_carriers[0]
		await get_tree().process_frame
		_check("[I] Inspect / care" in carrier.device.teletype.footer.text,"care control reaches physical paper")
	await _shot("care_discovery")
	await _pad(JOY_BUTTON_RIGHT_STICK)
	_check(notebook.opened and notebook.subject==tap and notebook.get_viewport().gui_get_focus_owner() is Button,
		"controller R3 opens aimed inspection with button focus")
	await _pad(JOY_BUTTON_A)
	_check(tap._hot,"controller accept operates the focused physical valve")
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_A)
	_check(tap._hot and tap._cold,"controller D-pad selects and operates a second control")
	await _pad(JOY_BUTTON_B)
	_check(not notebook.opened and not tap._hot and not tap._cold and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,
		"controller cancel restores valves and pointer ownership")
	_check(notebook.action_hint()=="[R3] Inspect / care","paper cue follows controller input family")
	await get_tree().process_frame
	_check("[R3]" in world.service_set_carrier.device.teletype.footer.text,"physical paper renders controller inspection cue")
	await _shot("controller_care_cue")
	await _pad(JOY_BUTTON_BACK)
	_check(notebook.opened and notebook.subject==null,"controller View opens pocket ledger")
	await _pad(JOY_BUTTON_B)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_I
	keyboard.pressed = true
	player._input(keyboard)
	var inspect := InputEventAction.new()
	inspect.action = "inspect_care"
	inspect.pressed = true
	notebook._unhandled_input(inspect)
	_check(notebook.subject==tap,"inspection shortcut opens aimed fixture")
	_check(notebook.action_hint().is_empty(),"modal inspection hides care cue")
	_check(player.call_locked and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"inspection owns pointer and movement")
	_check(care.service(tap,false).is_empty(),"untested service refused")
	var device = world.service_set_carrier.device
	var print_count: int = device.printed_count
	notebook._service()
	_check(device.printed_count==print_count,"untested care prints no completion slip")
	tap._water_level = .8
	notebook._test_water()
	_check(_test_controls_locked(notebook),"timed test owns its valves and service controls")
	var test_focus = notebook.get_viewport().gui_get_focus_owner()
	_check(test_focus is Button and test_focus.text=="Close / Escape" and not test_focus.disabled,
		"timed test leaves controller focus on enabled cancellation")
	await get_tree().create_timer(1.5).timeout
	await _shot("shower_running")
	await get_tree().create_timer(2.8).timeout
	_check(notebook.tested and not tap._hot and not tap._cold,"physical flow and drain test finishes safely")
	_check("drainage checked" in notebook.feedback.text,"healthy full basin judged by drainage rate rather than emptiness")
	_check(not _test_controls_locked(notebook),"completed test returns manual controls")
	# An interrupted test restores the entry controls and never permits care.
	notebook.close()
	tap.set_hot(true)
	tap.set_stopper(true)
	notebook.open(tap)
	notebook._test_water()
	await get_tree().create_timer(.3).timeout
	notebook.close()
	_check(tap._hot and not tap._cold and tap._stopper and not notebook.tested,
		"cancelled water test restores original settings without completion")
	tap.set_hot(false)
	tap.set_stopper(false)
	tap._water_level = 0
	notebook.open(tap)
	# Freeze only the production water simulation to model a missing sample.
	tap.set_process(false)
	notebook._test_water()
	await get_tree().create_timer(4.4).timeout
	_check(not notebook.tested and "test incomplete" in notebook.feedback.text,
		"missing water sample cannot claim a successful test")
	tap.set_process(true)
	notebook.close()
	notebook.open(tap)
	notebook._test_water()
	await get_tree().create_timer(1.5).timeout
	# Hold the measured pool still during observation: a blockage is diagnosed,
	# not mistaken for either good drainage or an untested fixture.
	tap.set_process(false)
	await get_tree().create_timer(2.9).timeout
	_check(notebook.tested and "No drainage observed" in notebook.feedback.text,
		"stationary water diagnoses blockage and allows clearing")
	await _shot("blocked_drain_diagnosis")
	tap.set_process(true)
	var old_due: float = economy.book().care[str(tap.name)].due
	var result: Dictionary = care.service(tap,notebook.tested)
	_check(not result.is_empty() and economy.book().care[str(tap.name)].due>old_due,"prevention postpones actual request")
	var affection: int = economy.affection("mina_vale")
	care.service(tap,true)
	_check(economy.affection("mina_vale")==affection and int(economy.book().cash)==100,"repeat care cannot farm goodwill or cash")
	await _shot("shower_inspection")
	notebook.close()
	_check(not player.call_locked and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"closing returns pointer ownership")
	_check(not tap._hot and not tap._cold,"inspection restores original valves")
	var look_before := player.camera.global_transform
	player.camera.look_at(player.camera.global_position+Vector3.UP,Vector3.FORWARD)
	await get_tree().physics_frame
	_check(notebook.action_hint().is_empty(),"empty aim has no care cue")
	notebook._unhandled_input(inspect)
	_check(not notebook.opened,"empty inspection does not open pocket ledger")
	player.camera.global_transform = look_before
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_check(notebook.action_hint().is_empty(),"released pointer hides inspection cue")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	notebook.open(tap)
	var debug := notebook.debug as BuildingDebug
	_check(debug!=null,"inspection binds the composed debug pointer owner")
	if debug==null:
		notebook.close()
		world.shutdown_for_tests()
		world.free()
		get_tree().quit(1)
		return
	debug._set_menu_open(true)
	notebook.close()
	_check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"closing inspection preserves F1 pointer ownership")
	debug._set_menu_open(false)
	_check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"F1 restores pre-inspection capture afterward")
	var due: float = economy.book().care[str(tap.name)].due
	economy.clock.advance_to(due+1)
	care.tick()
	var request: String = economy.book().care[str(tap.name)].request
	_check(not request.is_empty() and world.work_orders.status(request)=="issued","neglected drain creates real work order")
	_check(tap.drain_capacity<.5,"neglect restricts actual drainage")
	tap.set_cold(true)
	var level: float = tap._water_level
	await get_tree().create_timer(1).timeout
	_check(tap._water_level>level,"slow drain visibly retains running water")
	tap.set_cold(false)
	result = care.service(tap,true)
	_check(world.work_orders.status(request)=="closed" and int(result.tip)>0,"requested service closes order and pays tip")
	_check(tap.drain_capacity==1.0,"clearing restores drainage")
	var cash: int = economy.book().cash
	care.service(tap,true)
	_check(economy.book().cash==cash,"closed request cannot pay twice")
	player.camera.global_position = cabinet.to_global(Vector3(0,cabinet.CENTER_Y,-1.2))
	player.camera.look_at(cabinet.to_global(Vector3(.4,cabinet.CENTER_Y,0)))
	notebook.open(cabinet)
	notebook._test_cabinet()
	_check(not notebook.tested,"cabinet click alone does not certify travel")
	await get_tree().create_timer(1.5).timeout
	_check(notebook.tested and cabinet._swing>.999,"hinged cabinet completes physical open travel before care")
	print_count = device.printed_count
	notebook._service()
	var paper := "\n".join(device.teletype.pages)
	_check(device.printed_count==print_count+1 and "SERVICE COMPLETED" in paper and "Hinges oiled" in paper and "Tip:" in paper,
		"completed cabinet care prints one physical service and tip record")
	print_count = device.printed_count
	notebook._service()
	_check(device.printed_count==print_count,"repeat care prints no duplicate completion slip")
	_check("Quiet and free" in notebook.readout.text,"care updates the condition readout immediately")
	await get_tree().process_frame
	await _shot("cabinet_care")
	notebook.close()
	var sliding: Node
	for prop: Node in care.subjects.values():
		if prop is Prep and prop.unit==tap.unit: sliding = prop; break
	_check(sliding!=null,"household sliding cabinet available")
	if sliding!=null:
		sliding.restore_open_state(false)
		notebook.open(sliding)
		notebook._test_cabinet()
		await get_tree().create_timer(1.5).timeout
		_check(notebook.tested and absf(sliding._slide.position.x-sliding.TRAVEL)<.001,
			"sliding cabinet completes actual panel travel before care")
		notebook.close()
	# A stalled moving leaf cannot award a completed test.
	cabinet.set_door_open(false,0)
	cabinet.set_physics_process(false)
	notebook.open(cabinet)
	notebook._test_cabinet()
	await get_tree().create_timer(3.4).timeout
	_check(not notebook.tested and not notebook._testing and "incomplete" in notebook.feedback.text,
		"stalled hinge times out without certifying care")
	notebook.close()
	cabinet.set_physics_process(true)
	notebook.open(cabinet)
	notebook._test_cabinet()
	await get_tree().create_timer(.1).timeout
	notebook.close()
	await get_tree().create_timer(.6).timeout
	_check(not cabinet.is_door_open() and cabinet._swing<.001 and not notebook.tested,
		"cancelled cabinet test restores the entry door position")
	_check(cabinet.hinges_oiled,"cabinet care quiets real hinge mechanism")
	_check(economy.affection("mina_vale")==affection+2,"client goodwill capped across objects per day")
	var slow: int = economy.tip("test:slow","other_client",.35,0)
	var fast: int = economy.tip("test:fast","other_client",1,economy.clock.elapsed_minutes())
	_check(fast>slow,"prompt complete work pays more")
	var poor: Dictionary = economy.book().duplicate(true)
	poor.cash = -1
	_check(not Economy.valid(poor),"negative saved money refused")
	poor.cash = true
	_check(not Economy.valid(poor),"boolean saved money refused")
	var path := "user://tests/caretaker_"+str(Time.get_ticks_usec())+".json"
	RealityState.save_path = path
	_check(RealityState.save_game(),"real economy save writes")
	cash = economy.book().cash
	RealityState.load_game()
	care.tick()
	_check(economy.book().cash==cash and cabinet.hinges_oiled,"money and physical care survive disk reload")
	_check(economy.tip(request,"mina_vale",1,0)==0,"reload cannot replay a tip")
	var restored: Dictionary = economy.book().duplicate(true)
	RealityState.data.erase("caretaker_economy")
	RealityState.state_changed.emit()
	_check(economy.book().care.size()==care.subjects.size() and not cabinet.hinges_oiled,
		"legacy live-load notification restores a fresh physical care roster")
	RealityState.data.caretaker_economy = restored
	RealityState.state_changed.emit()
	notebook.open(null)
	print_count = device.printed_count
	notebook._pay_rent()
	_check("needs $5.00" in notebook.feedback.text and device.printed_count==print_count,
		"insufficient rent explains the shortfall and prints no receipt")
	economy.book().cash = 700
	notebook._pay_rent()
	paper = "\n".join(device.teletype.pages)
	_check(economy.book().cash==200 and device.printed_count==print_count+1 and "RENT RECEIPT" in paper and "$5.00" in paper,
		"rent payment debits cents and prints exactly one physical receipt")
	_check("$2.00" in notebook.readout.text,"rent immediately refreshes pocket balance")
	var rent_wait := 0.0
	while device.teletype.printing and rent_wait<15:
		await get_tree().create_timer(.1).timeout
		rent_wait += .1
	await _shot("rent_receipt")
	notebook._pay_rent()
	_check("already paid" in notebook.feedback.text and economy.book().cash==200 and device.printed_count==print_count+1,
		"advance limit explains paid rent without another debit or receipt")
	notebook.close()
	economy.clock.advance_to(float(economy.book().started)+Economy.MONTH*3)
	_check(economy.rent_cycles_due()==2 and economy.book().cash==200,"rent arrears accrue without fees or cash seizure")
	var entries: Array = care.request_entries()
	_check(entries.size()>1,"pending requests available for ordering")
	var chronological := true
	for index in range(1,entries.size()):
		if float(entries[index-1].issued)>float(entries[index].issued): chronological=false
	_check(chronological,"requests sorted by authoritative reporting time oldest first")
	var before_listing := JSON.stringify(RealityState.data)
	var first_lines: Array[String] = care.request_lines()
	_check(JSON.stringify(RealityState.data)==before_listing,"listing requests changes no save facts")
	_check(not first_lines.is_empty() and "waiting" in first_lines[0],"request lines expose client waiting time")
	economy.clock.advance_to(economy.clock.elapsed_minutes()+61)
	var aged: Array = care.request_entries()
	_check(not aged.is_empty() and aged[0].id==entries[0].id and aged[0].waiting>=entries[0].waiting+61,
		"waiting time advances without replacing the request identity")
	world.work_orders.activate(str(entries[0].id))
	_check(care.request_entries()[0].id==entries[0].id,"active request remains visible in its original priority")
	world.work_orders.close(str(entries[0].id),"test closure through work-order owner")
	var still_present := false
	for entry: Dictionary in care.request_entries():
		if entry.id==entries[0].id: still_present=true
	_check(not still_present,"closed owner request is absent even if fixture retains its reference")
	notebook.open(null)
	_check(notebook.readout.text.contains("POCKET") and notebook.readout.text.contains("$2.00"),"pocket presents balance and rent immediately")
	await _shot("pocket_ledger")
	var money_before := JSON.stringify(economy.book())
	print_count = device.printed_count
	notebook._print_pocket()
	paper = "\n".join(device.teletype.pages)
	_check(device.printed_count==print_count+1 and "POCKET COPY" in paper and "$2.00" in paper and "SERVICE REQUESTS" in paper and "oldest first" in paper and "waiting" in paper,
		"pocket print contains current cash rent and request page")
	_check(JSON.stringify(economy.book())==money_before,"printing pocket copy changes no money or requests")
	device.set_radio_powered(false)
	print_count = device.printed_count
	notebook._print_pocket()
	_check(device.printed_count==print_count and "Switch on" in notebook.feedback.text,
		"unpowered set refuses print without pretending delivery")
	device.set_radio_powered(true)
	notebook.close()
	var print_wait := 0.0
	while device.teletype.printing and print_wait<15:
		await get_tree().create_timer(.1).timeout
		print_wait += .1
	await _shot("physical_pocket_copy")
	notebook.open(null)
	economy.book().cash = 700
	var paid_before: int = economy.book().rent_paid
	device.set_radio_powered(false)
	print_count = device.printed_count
	notebook._pay_rent()
	_check(economy.book().rent_paid==paid_before+1 and economy.book().cash==200 and device.printed_count==print_count
		and "payment recorded, no slip printed" in notebook.feedback.text,
		"unpowered rent payment records money honestly without a phantom receipt")
	notebook.close()
	device.set_radio_powered(true)
	# The work-order owner can close a request before the fixture is serviced.
	# Physical preventative care remains available, but closure is not a tip.
	var stale_request: String = economy.book().care[str(tap.name)].request
	_check(not stale_request.is_empty() and world.work_orders.close(stale_request,"Closed outside fixture care"),
		"fixture retains a request closed through its authoritative owner")
	var pocket_before: int = economy.book().cash
	notebook.open(tap)
	notebook._test_water()
	await get_tree().create_timer(4.4).timeout
	notebook._service()
	_check(economy.book().cash==pocket_before and not economy.book().tips.has(stale_request),
		"care cannot pay a request already closed by its owner")
	_check(economy.book().care[str(tap.name)].request=="" and tap.drain_capacity==1.0
		and float(economy.book().care[str(tap.name)].due)>economy.clock.elapsed_minutes(),
		"stale request is cleared while physical prevention still completes")
	paper = "\n".join(device.teletype.pages)
	_check("No tip paid." in paper,"physical service slip honestly records unpaid prevention")
	var service_print_wait := 0.0
	while device.teletype.printing and service_print_wait<10:
		await get_tree().create_timer(.1).timeout
		service_print_wait += .1
	_check("No tip paid." in device.teletype.ink.text,"finished paper renders the unpaid service result")
	await _shot("closed_request_care")
	notebook.close()
	RealityState.save_path = RealityState.SAVE_PATH
	world.shutdown_for_tests()
	world.free()
	print("CARETAKER CARE: failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _shot(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func _check(ok: bool, label: String) -> void:
	print("CARETAKER ","PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)

func _test_controls_locked(notebook: Node) -> bool:
	var count := 0
	for child in notebook.box.get_children():
		if child is Button and child.text!="Close / Escape":
			if not child.disabled: return false
			count += 1
	return count>0

func _pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().physics_frame
	event = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame
