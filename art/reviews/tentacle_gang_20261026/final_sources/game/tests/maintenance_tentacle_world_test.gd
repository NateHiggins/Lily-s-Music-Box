extends Node
var failures: Array[String] = []
var checks := 0
var directory := ""
var started := 0
var diagnostics: Array = []

func _ready() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("GANG WORLD: ",label," = ",ok)

func operate_supply(player: PlayerController, radiator: RadiatorProp, value: float) -> bool:
	var pose := player.camera.global_transform
	var hand := preload("res://tests/maintenance_tentacle_test_hand.gd").new()
	add_child(hand)
	hand.player = player
	var point: Vector3 = radiator._wheel.global_position+radiator.global_basis*Vector3(0,0,-.045)
	var moved: bool = await hand.operate(point,value*TAU*3.5,radiator)
	hand.queue_free()
	player.camera.global_transform = pose
	return moved and absf(radiator.supply_position-value)<.00001

func _run() -> void:
	started = Time.get_ticks_msec()
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): directory = "user://tentacle_gang_world"
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityCases._ready()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase":FirstShiftDirector.PHASE_COMPLETE}
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var selector := preload("res://scripts/building/building_root_selector.gd")
	selector.reset_for_tests("v2")
	var world := (load(selector.scene_path()) as PackedScene).instantiate() as OrisonV2RuntimeRoot
	check(world != null,"production world script compiles and instantiates")
	if world == null:
		_finish(null)
		return
	add_child(world)
	for frame in 30: await get_tree().physics_frame
	check(not world.startup_failed,"production V2 starts")
	var observer := world.get_node_or_null("MaintenanceTentacleObserver")
	check(observer != null,"production mounts bounded observer")
	if observer == null or world.startup_failed:
		_finish(world)
		return
	observer.set_physics_process(false)
	observer.frequency_divisor = 1
	var warm_deadline := Time.get_ticks_msec()+15000
	while not observer.preparation_ready and Time.get_ticks_msec()<warm_deadline:
		await RenderingServer.frame_post_draw
	check(observer.preparation_ready,"installed rendering preparation completes before admission")
	if not observer.preparation_ready:
		_finish(world)
		return
	var radiator := world.find_child(ServiceRoundDirector.RADIATOR_ID,true,false) as RadiatorProp
	check(radiator != null,"authored maintenance target exists")
	if radiator == null:
		_finish(world)
		return
	var player: PlayerController = world.player
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	player.call_locked = false
	player.mouse_released = false
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var seed_id := ("lena_radiator_round_2b:"+str(radiator.name)).hash()
	var anchor := {}
	for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
		var start: Vector3 = radiator.global_position+radiator.global_basis*direction*1.25
		var ray := PhysicsRayQueryParameters3D.create(start+Vector3.UP,start-Vector3.UP*2.0)
		ray.exclude = [player.get_rid()]
		var support: Dictionary = radiator.get_world_3d().direct_space_state.intersect_ray(ray)
		if support.is_empty():
			diagnostics.append({"stance":str(start),"rejected":"no_support"})
			continue
		if absf(float(support.position.y)-(radiator.global_position.y-radiator.installation_drop))>.12:
			diagnostics.append({"stance":str(start),"support":str(support.position),"expected_floor":radiator.global_position.y-radiator.installation_drop,"rejected":"not_floor"})
			continue
		player.global_position = support.position+Vector3.UP*.025
		var standing := PhysicsShapeQueryParameters3D.new()
		standing.shape = player._capsule
		standing.transform = player._shape.global_transform
		standing.exclude = [player.get_rid()]
		var overlaps: Array = radiator.get_world_3d().direct_space_state.intersect_shape(standing,4)
		if not overlaps.is_empty():
			var paths: Array[String] = []
			for overlap in overlaps: paths.append(str(overlap.collider.get_path()))
			diagnostics.append({"stance":str(player.global_position),"rejected":"standing_overlap","paths":paths})
			continue
		player.camera.look_at(radiator.global_position)
		for frame in 3: await get_tree().physics_frame
		anchor = observer.choose_anchor(radiator,seed_id)
		diagnostics.append({"stance":str(player.global_position),"anchor_rejections":observer.anchor_diagnostics.duplicate(true)})
		if not anchor.is_empty(): break
	check(not anchor.is_empty(),"installed radiator has a safe reachable emergence anchor")
	if anchor.is_empty():
		_finish(world)
		return
	RealityState.data.maintenance_jobs = {"lena_radiator_round_2b":{"stage":"repairable"}}
	var mechanism: float = radiator.supply_position
	check(await operate_supply(player,radiator,.94),"installed valve works before emergence")
	check(await operate_supply(player,radiator,mechanism),"installed valve restored before emergence")
	var before := world.work_orders.job_state("lena_radiator_round_2b")
	observer._physics_process(1.0)
	check(is_instance_valid(observer.encounter),"installed target spawns through production observer")
	if not is_instance_valid(observer.encounter):
		_finish(world)
		return
	var gang: Node3D = observer.encounter
	var deadline := Time.get_ticks_msec()+15000
	while gang.phase != gang.Phase.INTERFERING and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	check(gang.phase==gang.Phase.INTERFERING,"installed encounter reaches interference")
	check(await operate_supply(player,radiator,.93),"installed valve works during interference")
	check(await operate_supply(player,radiator,mechanism),"installed valve restored during interference")
	check(world.work_orders.job_state("lena_radiator_round_2b")==before,"installed encounter preserves work order")
	player.camera.look_at(gang.global_position+Vector3.UP*.4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("installed_encounter.png"))
	var review_pose := player.camera.global_transform
	var point: Vector3 = gang.contacts[0].get_child(0).global_position
	var hand := preload("res://tests/maintenance_tentacle_test_hand.gd").new()
	add_child(hand)
	hand.player = player
	player.camera.look_at(point)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hand.click()
	var acquired: bool = player._grab.active() and player._grab.target.owner==gang
	for attempt in 12:
		if not acquired or gang.contact_count>0: break
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0,12)
		player._unhandled_input(motion)
		await get_tree().physics_frame
	if player._grab.active(): hand.click()
	check(acquired and gang.contact_count==1 and not player._grab.active(),"installed contact uses actual grab motion release")
	check(gang.contact_count==1,"installed contact latches once")
	deadline = Time.get_ticks_msec()+15000
	while gang.phase != gang.Phase.CLEARED and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	check(gang.phase==gang.Phase.CLEARED and gang.get_child_count()==0,"installed retreat releases all encounter nodes")
	check(await operate_supply(player,radiator,.95),"installed valve works after cleanup")
	check(await operate_supply(player,radiator,mechanism),"installed valve restored after cleanup")
	check(world.work_orders.job_state("lena_radiator_round_2b")==before,"work order survives full installed lifecycle")
	player.camera.global_transform = review_pose
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("installed_clean.png"))
	hand.queue_free()
	_finish(world)

func _finish(world: Node) -> void:
	var constructed := is_instance_valid(world)
	if constructed:
		var retired: WeakRef = weakref(world)
		world.shutdown_for_tests()
		world.free()
		for frame in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(retired.get_ref()==null,"world owner retires before renderer shutdown")
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":constructed,
		"scope":"Production V2 composition, installed radiator anchor, actual contact input and local cleanup. Repairable job and standing approach are explicit test preconditions; not campaign progression or full surface acceptance.",
		"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/tests/maintenance_tentacle_world_test.gd","test_sha256":get_script().source_code.replace("\r\n","\n").sha256_text()},
		"contracts":{"installed_encounter":{"executed":constructed,"status":"PASS" if failures.is_empty() else "FAIL"}},"checks":checks,"failures":failures,"diagnostics":diagnostics}
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	get_tree().quit(0 if failures.is_empty() else 1)
