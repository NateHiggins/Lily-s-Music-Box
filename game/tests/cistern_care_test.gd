extends Node
const Cistern := preload("res://scripts/building/orison_v2_water_closet.gd")
const Economy := preload("res://scripts/game/caretaker_economy.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("CISTERN CARE: " + label)

func _ready() -> void: call_deferred("run")

func open_bathroom(world: Node) -> void:
	# Fixture setup delegates to the real door owner, separately from timed
	# observations of the cistern. It is not a simulated NPC action.
	var door := world.adapter.resolve("F02_A_BATH_DOOR").get_node("F02_A_BATH_DOOR_Leaf") as DoorProp
	door.npc_set_open(true)

func capture(label: String) -> void:
	var path := OS.get_environment("SHOT_DIR")
	if path.is_empty(): return
	DirAccess.make_dir_recursive_absolute(path)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path.path_join(label+".png"))

func run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	var world := preload("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(.5).timeout
	check(not world.startup_failed, "production V2 starts")
	var care = world.get_node("Caretaking")
	var economy = world.get_node("CaretakerEconomy")
	var notebook = world.get_node("CaretakerNotebook")
	var wc: Cistern
	var count := 0
	for prop: Node in care.subjects.values():
		if prop is Cistern:
			count += 1
			check(economy.book().care[str(prop.name)].kind == "cistern", "cistern registered with existing economy")
			if prop.unit == "2A": wc = prop
	check(count >= 12 and wc != null, "toilets throughout V2 include Mina's")
	if wc == null:
		get_tree().quit(1)
		return
	var player: PlayerController = world.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	open_bathroom(world)
	await get_tree().create_timer(.8).timeout
	var capsule := CapsuleShape3D.new()
	capsule.radius = .38
	capsule.height = 1.524
	var stance := PhysicsShapeQueryParameters3D.new()
	stance.shape = capsule
	stance.exclude = [player.get_rid()]
	stance.collision_mask = 1
	# Find a real standing approach in this compact bathroom, requiring both
	# capsule clearance and an unobstructed within-reach eye ray to the toilet.
	var approach_found := false
	for x: float in [.6,.4,0.0,-.4,-.6]:
		for z: float in [-.8,-1.1,-.5,0.0]:
			var feet: Vector3 = wc.to_global(Vector3(x,0,z))
			stance.transform = Transform3D(Basis.IDENTITY,feet+Vector3.UP*(capsule.height*.5+.025))
			if not player.get_world_3d().direct_space_state.intersect_shape(stance).is_empty(): continue
			var eye := feet+Vector3.UP*player.STANDING_EYE
			var target: Vector3 = wc.to_global(Vector3(0,.65,0))
			if eye.distance_to(target)>2.1: continue
			var ray := PhysicsRayQueryParameters3D.create(eye,target,1,[player.get_rid()])
			ray.collide_with_areas = true
			if player.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") != wc: continue
			player.global_position = feet
			player.camera.global_position = eye
			player.camera.look_at(target)
			approach_found = true
			print("CISTERN CLEAR APPROACH: ",Vector3(x,0,z))
			break
		if approach_found: break
	check(approach_found, "reachable cistern has a clear standing capsule and eye ray")
	if not approach_found:
		world.shutdown_for_tests()
		world.free()
		get_tree().quit(1)
		return
	player.camera.make_current()
	await get_tree().physics_frame
	check(notebook.aimed_subject() == wc, "physical eye ray resolves cistern care owner")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	check(notebook.action_hint() == "[I] Inspect / care", "carried-paper hint available")
	notebook.open(wc)
	check(player.call_locked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "inspection owns pointer and movement")
	check(care.service(wc,false).is_empty(), "untested service refused")
	var cash: int = economy.book().cash
	notebook._test_cistern()
	check(wc._refilling and notebook._testing, "test starts original flush mechanism")
	check(not care.service(wc,true).has("tip"), "service during refill refused")
	await get_tree().create_timer(2.8).timeout
	check(notebook.tested and not wc._refilling and not wc._water.playing, "healthy flush returns handle and stops water")
	# A slow UI need not sample the 80 ms peak; the mechanism records reaching it.
	notebook._test_cistern()
	notebook.set_process(false)
	await get_tree().create_timer(2.8).timeout
	notebook._process(2.8)
	check(notebook.tested and wc._flush_stroke_completed, "completed handle stroke survives skipped inspection frames")
	notebook.set_process(true)
	var before_print: int = world.service_set_carrier.device.printed_count
	notebook._service()
	check(economy.book().cash == cash, "preventative care awards no cash")
	check(world.service_set_carrier.device.printed_count == before_print+1, "care prints one physical service slip")
	check(economy.book().goodwill.has("mina_vale"), "preventative care quietly improves goodwill")
	var due: float = economy.book().care[str(wc.name)].due
	check(due > economy.clock.elapsed_minutes()+20000, "care postpones actual request")
	notebook._service()
	check(world.service_set_carrier.device.printed_count == before_print+1, "repeat care prints and pays nothing")
	notebook.close()
	check(not player.call_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "inspection restores pointer ownership")
	economy.clock.advance_to(due+1)
	care.tick()
	var request: String = economy.book().care[str(wc.name)].request
	check(not request.is_empty() and economy.orders.status(request) == "issued" and not wc.inlet_clear, "overdue inlet physically slows and creates ordinary request")
	notebook.open(wc)
	notebook._test_cistern()
	await get_tree().create_timer(2.8).timeout
	check(wc._refilling and not notebook.tested, "slow inlet cannot pass at healthy refill time")
	# Cancelling cannot manufacture a diagnosis or cancel an already-started flush.
	notebook.close()
	check(wc._refilling and not notebook.tested, "cancel leaves physical refill running and no proof")
	notebook.open(wc)
	notebook._test_cistern()
	check(not notebook._testing and not notebook.tested, "already-running refill cannot be claimed as a new test")
	await get_tree().create_timer(2.8).timeout
	notebook._test_cistern()
	await get_tree().create_timer(5.7).timeout
	check(notebook.tested and "slow" in notebook.feedback.text, "complete slow refill diagnosed from elapsed mechanism time")
	player.camera.look_at(wc.to_global(Vector3(-.32,.65,0)))
	player.set_lamp_enabled(false)
	var light := OmniLight3D.new()
	world.add_child(light)
	light.global_position = wc.to_global(Vector3(-.4,1.3,-.6))
	light.omni_range = 2.5
	light.light_energy = .55
	await get_tree().create_timer(.8).timeout
	await capture("cistern_slow_inspection")
	notebook._service()
	var paid: int = economy.book().cash-cash
	check(paid>0 and economy.orders.status(request)=="closed" and wc.inlet_clear, "tested request closes once with tip and restores inlet")
	await get_tree().create_timer(1.5).timeout
	await capture("cistern_serviced")
	notebook._service()
	check(economy.book().cash == cash+paid, "request cannot pay twice")
	notebook._test_cistern()
	await get_tree().create_timer(2.8).timeout
	check(notebook.tested and not wc._refilling and not "slow" in notebook.feedback.text, "service restores healthy refill duration")
	# A stalled mechanism must not pass on a timer alone.
	notebook._test_cistern()
	wc._flush_tween.pause()
	notebook._process(8.1)
	check(not notebook.tested and not notebook._testing, "stalled refill times out without granting service proof")
	wc._flush_tween.play()
	notebook.close()
	await get_tree().create_timer(2.8).timeout
	var save_path := "user://tests/cistern_care_"+Crypto.new().generate_random_bytes(8).hex_encode()+".json"
	RealityState.save_path = save_path
	check(RealityState.save_game(), "care and tip written to disk")
	RealityState.load_game()
	care.tick()
	check(wc.inlet_clear and economy.book().cash == cash+paid and economy.tip(request,"mina_vale",1,0)==0, "reload retains physical care and refuses duplicate tip")
	var book: Dictionary = economy.book().duplicate(true)
	for key: String in book.care.keys():
		if book.care[key].kind=="cistern": book.care.erase(key)
	check(Economy.valid(book), "older care book without cisterns remains valid")
	RealityState.data[Economy.KEY] = book
	RealityState.state_changed.emit()
	check(economy.book().care.has(str(wc.name)) and wc.inlet_clear, "live legacy load adds fresh cistern schedule")
	world.shutdown_for_tests()
	world.free()
	RealityState.save_path = RealityState.SAVE_PATH
	DirAccess.remove_absolute(save_path)
	print("CISTERN CARE: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
