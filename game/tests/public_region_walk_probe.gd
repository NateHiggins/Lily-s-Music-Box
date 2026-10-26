extends "res://tests/v2_front_restoration_review.gd"
## INERT diagnostic. Actual played spatial acceptance requires its own contract.
var checks:=0
var failures: Array[String]=[]
var externally_managed:=false
var out:=""

func _ready() -> void:
	if not externally_managed:_run.call_deferred()

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
	if host!=null and host!=self:host.check(value,label)

func shot(label: String) -> void:
	for frame in 5:await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))==OK,"saved public programme view: "+label)

func _run() -> void:
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	OS.set_environment("ORISON_BUILDING_ROOT","v2")
	CampaignTime.set_frozen_for_tests(true);CampaignClock.new().configure_date(1928,10,15,750)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	world=preload("res://scenes/building/orison_v2_runtime.tscn").instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and world.player!=null,"production world composes every public geometry provider")
	if world.startup_failed or world.player==null:world.free();_finish();return
	if OS.get_environment("ORISON_PREFLIGHT_STREET_AND_PUBLIC")=="1":
		var street:=preload("res://tests/orison_v2_street_crossing_test.gd").new()
		street.externally_managed=true;street.world=world;street.player=world.player;add_child(street)
		world.player.set_physics_process(true);world.player.set_process_unhandled_input(true)
		world.player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		street._prepare_player_start();await get_tree().process_frame;await get_tree().process_frame
		await street._route()
		check(street.failures.is_empty() and street.trace.size()>=18,"ordinary entrance, street crossing and return preflight")
		for failure: String in street.failures:print("STREET PREFLIGHT FAILURE: ",failure)
		if OS.get_environment("ORISON_PREFLIGHT_STREET_ONLY")=="1":
			trace.append_array(street.trace)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("entrance_street_last.png"))
			street.free()
			var retired_only: WeakRef=weakref(world)
			world.shutdown_for_tests();world.free();await get_tree().process_frame
			check(retired_only.get_ref()==null,"focused street world retires")
			_finish();return
		street.free()
	await run(world,self)
	var retired: WeakRef=weakref(world)
	world.shutdown_for_tests();world.free();await get_tree().process_frame
	check(retired.get_ref()==null,"public region owner graph retires with the world")
	_finish()

func run(current: OrisonV2RuntimeRoot,suite: Node) -> void:
	world=current;host=suite;player=world.player
	if out.is_empty():out=OS.get_environment("SHOT_DIR")
	var prior_position:=player.global_position;var prior_rotation:=player.rotation;var prior_camera:=player.camera.rotation
	var prior_physics:=player.is_physics_processing()
	var programmes: Variant=world.public_regions
	player.set_physics_process(true);player.set_lamp_enabled(false);player.carried_device.set_capture_hidden(true)
	var first: Dictionary=programmes.route("ROUTE_STREET_TO_ARCADE").nodes[0].placement
	player.global_position=(first.position as Vector3)+Vector3.UP*.025;player.velocity=Vector3.ZERO
	# Distant streamed cells may be dormant at the street arrival. Require each
	# physical module to become resident during the actual approach and walk.
	var states: Array=programmes.snapshot()
	var visited_resident: Dictionary={}
	check(states.size()==4,"four programme regions have actual module owners")
	for state: Dictionary in states:
		check(state.owner!=null,"actual region has its retained physical owner: "+str(state.region_id))
	var route_failed:=false
	for identity: String in ["ROUTE_STREET_TO_ARCADE","ROUTE_ARCADE_TO_STREET","ROUTE_STREET_TO_CONSTRUCTION","ROUTE_CONSTRUCTION_TO_STREET"]:
		var route: Dictionary=programmes.route(identity)
		check(not route.is_empty(),"played route resolves: "+identity)
		for node: Dictionary in route.get("nodes",[]):
			var target: Vector3=node.placement.position
			if not await _walk(world.adapter.root.to_local(target)):
				route_failed=true
				break
			for state: Dictionary in programmes.snapshot():
				if bool(state.resident):visited_resident[str(state.region_id)]=true
		if route_failed:break
	for state: Dictionary in states:
		check(visited_resident.has(str(state.region_id)),"actual region geometry is resident during the walked programme: "+str(state.region_id))
	player.set_physics_process(false)
	var portal: Vector3=world._exterior_resolver.instance_world_transform("ARCADE_PORTAL_01").origin
	var hall: Vector3=world._exterior_resolver.resolve_placement("ARCADE_HALL_01","arrival").position
	for station: Dictionary in [{"name":"public_arcade_portal","eye":portal+Vector3(0,1.65,-5),"target":portal+Vector3(0,3,0)},{"name":"public_arcade_hall","eye":hall+Vector3.UP*1.65,"target":hall+Vector3(0,1.3,12)},{"name":"public_construction_dogleg","eye":Vector3(24,1.65,2.8),"target":Vector3(24,1.7,-2)}]:
		await _capture(str(station.name),world.adapter.root.to_local(station.eye),world.adapter.root.to_local(station.target))
	player.global_position=prior_position;player.rotation=prior_rotation;player.camera.rotation=prior_camera;player.velocity=Vector3.ZERO
	player.set_physics_process(prior_physics)
	_write_diagnostic()

func _write_diagnostic() -> void:
	FileAccess.open(out.path_join("public_region_walk_diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual production-owner, ordinary controller walking and rendered diagnosis. One explicit outside-street arrival fixture; no lobby, traffic-safety, spatial ledger, human or whole-V2 acceptance.","checks":checks,"failures":failures,"trace":trace},"\t"))

func _finish() -> void:
	_write_diagnostic()
	print("PUBLIC REGION WALK PROBE ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
