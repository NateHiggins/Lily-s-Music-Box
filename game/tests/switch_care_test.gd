extends Node
const Switch := preload("res://scripts/building/switch_plate.gd")
const Economy := preload("res://scripts/game/caretaker_economy.gd")
const Household := preload("res://scripts/building/orison_v2_household_state.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("SWITCH CARE: " + label)

func _ready() -> void: call_deferred("run")

func fixture_for_probe(world: Node, probe: Dictionary) -> Switch:
	# Resolve the authored fixture separately from timed mechanism observation.
	return world.adapter.resolve(probe.switch) as Switch

func capture(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var world := preload("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(.5).timeout
	check(not world.startup_failed,"V2 starts")
	var care = world.get_node("Caretaking")
	var notebook = world.get_node("CaretakerNotebook")
	var economy = world.get_node("CaretakerEconomy")
	var roster := 0
	for prop: Node in care.subjects.values():
		if prop is Switch:
			roster += 1
			check(not prop.unit.is_empty() and economy.book().care[str(prop.name)].kind=="switch", "switch has stable care ownership")
	check(roster==133,"all installed V2 switches support care")
	var probes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/v2_upper_lighting_probes.json"))
	var probe: Dictionary = probes.rooms[0]
	var plate: Switch = fixture_for_probe(world,probe)
	check(plate.unit=="5A" and care.clients.has(plate.unit),"semantic room maps to its household client")
	check(care.subject_title(plate)=="LIVING ROOM SWITCH FACEPLATE", "service request identifies the room")
	var player: PlayerController = world.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.global_position = world.adapter.root.to_global(Vector3(probe.stance[0],12.8,probe.stance[1]))
	player.camera.global_position = player.global_position+Vector3.UP*player.STANDING_EYE
	player.camera.look_at(plate.global_position)
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	check(notebook.aimed_subject()==plate,"real eye ray reaches switch care owner")
	check(notebook.action_hint()=="[I] Inspect / care","paper advertises care within reach")
	var entry: Dictionary = plate.power_snapshot()
	var all_lights := {}
	for fixture in get_tree().get_nodes_in_group("light_fixtures"): all_lights[str(fixture.name)] = fixture.powered
	check(not entry.is_empty(),"room has complete native circuit")
	var invalid: Dictionary = entry.duplicate()
	invalid[invalid.keys()[0]] = 1
	check(not plate.restore_power(invalid) and plate.power_snapshot()==entry,"malformed restore changes no power")
	invalid = entry.duplicate()
	invalid["another_room"] = true
	check(not plate.restore_power(invalid) and plate.power_snapshot()==entry,"cross-room restore refused atomically")
	notebook.open(plate)
	check(care.service(plate,false).is_empty(),"untested service refused")
	notebook._test_switch()
	await get_tree().create_timer(.5).timeout
	check(notebook.tested and not notebook._testing and plate.power_snapshot()==entry,"both throws finish and restore entry circuit")
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		check(fixture.powered==all_lights[str(fixture.name)],"test changes no lasting room power")
	for identity: String in entry:
		check(RealityState.data[Household.KEY].records[identity].value==entry[identity],"restored power belongs to original save owner")
	var cash: int = economy.book().cash
	var print_count: int = world.service_set_carrier.device.printed_count
	notebook._service()
	check(economy.book().cash==cash and world.service_set_carrier.device.printed_count==print_count+1,"preventative service prints once without paying cash")
	check(economy.book().goodwill.has(care.clients[plate.unit]),"client goodwill uses existing owner")
	notebook._service()
	check(world.service_set_carrier.device.printed_count==print_count+1,"repeat service prints no duplicate")
	notebook._test_switch()
	notebook.close()
	await get_tree().create_timer(.2).timeout
	check(plate.power_snapshot()==entry and not notebook.tested and not player.call_locked and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"cancel restores circuit and pointer without a pass")
	notebook.open(plate)
	notebook._test_switch()
	plate._throw.pause()
	notebook._process(2.1)
	await get_tree().create_timer(.2).timeout
	check(not notebook.tested and not notebook._testing and plate.power_snapshot()==entry,"stalled toggle times out and restores circuit")
	notebook.close()
	var due: float = economy.book().care[str(plate.name)].due
	economy.clock.advance_to(due+1)
	care.tick()
	var request: String = economy.book().care[str(plate.name)].request
	check(not plate.mounting_secure and economy.orders.status(request)=="issued","neglect loosens mounting and creates ordinary request")
	plate.interact(player)
	plate._wobble.pause()
	plate._wobble.custom_step(.08)
	check(absf(plate._model.rotation.z)>.02,"loose faceplate moves physically under a throw")
	plate._wobble.play()
	plate.restore_power(entry)
	await get_tree().create_timer(.3).timeout
	notebook.open(plate)
	notebook._test_switch()
	await get_tree().create_timer(.5).timeout
	check(notebook.tested and "moves" in notebook.feedback.text,"complete circuit test reports loose faceplate")
	notebook._service()
	var paid: int = economy.book().cash-cash
	check(paid>0 and plate.mounting_secure and is_zero_approx(plate._model.rotation.z),"service secures mounting and pays tip")
	check(economy.orders.status(request)=="closed" and plate.power_snapshot()==entry,"completion closes existing request without changing power")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.near = .02
	camera.global_position = plate.to_global(Vector3(.20,.10,-.44))
	camera.look_at(plate.to_global(Vector3(-.07,0,0)))
	camera.make_current()
	player.set_lamp_enabled(false)
	var light := OmniLight3D.new()
	world.add_child(light)
	light.global_position = plate.to_global(Vector3(-.2,.2,-.4))
	light.omni_range = 1.5
	light.light_energy = .5
	await get_tree().create_timer(.8).timeout
	await capture("switch_care_completed")
	notebook._service()
	check(economy.book().cash==cash+paid,"request pays once")
	notebook.close()
	var save_path := "user://tests/switch_care_"+Crypto.new().generate_random_bytes(8).hex_encode()+".json"
	RealityState.save_path = save_path
	check(RealityState.save_game(),"service and tip write to disk")
	RealityState.load_game()
	care.tick()
	check(plate.mounting_secure and economy.book().cash==cash+paid and plate.power_snapshot()==entry,"reload retains mounting cash and circuit")
	check(economy.tip(request,str(care.clients[plate.unit]),1,0)==0,"reload cannot replay paid request")
	var legacy: Dictionary = economy.book().duplicate(true)
	for identity: String in legacy.care.keys():
		if legacy.care[identity].kind=="switch": legacy.care.erase(identity)
	check(Economy.valid(legacy),"prior save without switch care remains valid")
	RealityState.data[Economy.KEY] = legacy
	RealityState.state_changed.emit()
	check(economy.book().care.has(str(plate.name)) and plate.mounting_secure,"legacy load starts fresh switch schedule")
	world.shutdown_for_tests()
	world.free()
	RealityState.save_path = RealityState.SAVE_PATH
	DirAccess.remove_absolute(save_path)
	print("SWITCH CARE: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
