extends "res://tests/v2_golden_repair_profile.gd"
## INERT two actual street/passage round trips. No toggle/procurement proof.
var work_probe: Node
var residency_events: Array=[]
var cycles: Array=[]
var last_fit: Dictionary={}
var last_state: String=""
var owned_path: String
var old_path: String
var old_persistence:=false

func _move_front_entrance(identity: String,want_open: bool) -> bool:
	var anchor:=world.adapter.resolve(identity) as Node3D
	var door:=anchor.get_node(identity+"_Leaf") as DoorProp
	var goal:=door.motion_target_angle(want_open)
	if door.open==want_open and not door._moving and absf(door._body.rotation.y-goal)<.01:return true
	# A partly open leaf's outer third can be beyond the real2.1m ray. The
	# fixed gesture needs no long lever; select visible stock near its hinge.
	var contact_anchor:=Vector3(minf(.08,door.width/3.),1.1,door._hinge_offset)
	player.face_world_point(door._body.to_global(contact_anchor))
	player.set_mouse_released(false)
	var hand:=preload("res://tests/fixed_gesture_patrol_hand.gd").new();hand.player=player;add_child(hand)
	var operated: bool=await hand.operate(door._body.to_global(contact_anchor),goal,door)
	hand.queue_free()
	return _require(operated and door.open==want_open,identity+" reaches its stop through primary grab, fixed mouse travel and release")

func _init() -> void:route_label="V2 PLAYED STREAMING PROFILE"
func _run() -> void:
	# Construction time must not change the weather/agenda at route start.
	# This diagnostic measures rendering and residency, not clock advancement.
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings["weather_network_enabled"]=false
	seed(1928)
	await super._run()

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	work_probe=preload("res://tests/v2_frame_work_probe.gd").new();work_probe.host=self;add_child(work_probe)
	super._ready()

func _prepare_player_start() -> void:
	# Explicit interior starting precondition; this fixture does not qualify arrival.
	player.global_position=world.adapter.root.to_global(Vector3(1.925,.02,-3.5))
	player.velocity=Vector3.ZERO

func _process(delta: float) -> void:
	super._process(delta)
	if not profile_active or not is_instance_valid(world) or world.passage_region==null:return
	var residency: Node=world.passage_region.residency
	if residency.state!=last_state:
		residency_events.append({"kind":"state","usec":Time.get_ticks_usec(),"process_frame":Engine.get_process_frames(),"phase":profile_phase,"state":residency.state})
		last_state=residency.state
	var records: Array=residency.fit_records
	if records.is_empty() or is_same(records[-1],last_fit):return
	var first:=0
	for index in records.size():
		if is_same(records[index],last_fit):first=index+1;break
	for record: Dictionary in records.slice(first):
		residency_events.append({"kind":"fit_observed","usec":Time.get_ticks_usec(),"process_frame":Engine.get_process_frames(),"phase":profile_phase,"record":record.duplicate(true)})
	last_fit=records[-1]

func _play_route() -> void:
	var viewport:=get_viewport()
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("settings.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"Observed rendering and clock controls for this diagnostic; not simulation-time qualification",
		"clock":RealityState.data.campaign_clock.duplicate(true),"clock_frozen":CampaignTime._frozen_for_tests,
		"weather_network_enabled":GameBoot.settings.get("weather_network_enabled",false),
		"rendering_method":RenderingServer.get_current_rendering_method(),"resolution":str(viewport.get_visible_rect().size),
		"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"msaa_3d":viewport.msaa_3d,
		"taa":viewport.use_taa,"scaling_3d_scale":viewport.scaling_3d_scale,"scaling_3d_mode":viewport.scaling_3d_mode},"\t"))
	old_path=RealityState.save_path;old_persistence=RealityState.persistence_enabled
	owned_path="user://v2_played_stream_%d.json"%Time.get_ticks_usec()
	RealityState.save_path=owned_path;RealityState.persistence_enabled=true
	world.household_state.profiling=true;player.profile_physics=true;player._grab.profiling=true
	for cycle in 2:
		profile_cycle="cycle_%d_"%cycle
		var before: Dictionary=world.passage_region.residency.snapshot()
		var started:=Time.get_ticks_usec()
		if not await _leave_front_entrance():break
		for point: Vector3 in [Vector3(0,0,3),Vector3(14,0,3),Vector3(14,0,4.2),Vector3(14,-.1,8),Vector3(14,-.1,13.6),Vector3(14,0,15)]:
			if not await _walk_world(point):break
		if not failures.is_empty():break
		var arrival: Dictionary=world.passage_region.residency.snapshot()
		_require(arrival.state=="RESIDENT","ordinary street approach completes passage reconstruction before gateway cycle "+str(cycle))
		profile_phase=profile_cycle+"gateway_wait"
		var wait_started:=Time.get_ticks_msec()
		while world.passage_region.residency.state=="LOADING" and Time.get_ticks_msec()-wait_started<180000:
			await get_tree().process_frame
		if not _require(world.passage_region.residency.state=="RESIDENT","passage eventually reaches resident state cycle "+str(cycle)):break
		for point: Vector3 in [Vector3(14,0,17.3),Vector3(14,0,20),Vector3(14,0,27.5),Vector3(14,0,32)]:
			if not await _walk_world(point):break
		if not failures.is_empty():break
		profile_phase=profile_cycle+"nave_turn"
		for turn in 16:
			var motion:=InputEventMouseMotion.new();motion.relative=Vector2(160,0)
			player._unhandled_input(motion)
			await get_tree().process_frame
		await _picture(profile_cycle+"nave")
		for point: Vector3 in [Vector3(14,0,27.5),Vector3(14,0,20),Vector3(14,0,17.3),Vector3(14,0,15),Vector3(14,-.1,13.6),Vector3(14,-.1,8),Vector3(14,0,4.2),Vector3(14,0,3),Vector3(0,0,3)]:
			if not await _walk_world(point):break
		if not failures.is_empty() or not await _enter_front_entrance():break
		if not await _walk(Vector3(1.925,0,-3.5)):break
		for frame in 4:await get_tree().process_frame
		var returned: Dictionary=world.passage_region.residency.snapshot()
		_require(returned.state=="DORMANT" and returned.pending_requests==0 and returned.retired_geometry_roots_alive==0 and returned.retired_mesh_resources_alive==0,"return retires imported passage roots and meshes cycle "+str(cycle))
		cycles.append({"cycle":cycle,"start_usec":started,"end_usec":Time.get_ticks_usec(),"before":before,"at_gateway":arrival,"returned":returned})
		if not failures.is_empty():break
	profile_active=false
	RealityState.flush_background_saves()
	work_probe.write(OS.get_environment("SHOT_DIR").path_join("work_trace.json"))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("streaming.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual primary-grab doors, standing walk and mouse turning over two street/passage residency cycles; no shop transaction, item manipulation, save reconstruction, runtime_contract or human acceptance.","timed_waypoints":trace.size(),"cycles":cycles,"events":residency_events,"final_residency":world.passage_region.residency.snapshot(),"checks":interaction_checks,"failures":failures,"owned_path":owned_path,"save_result":RealityState.last_save_result()},"\t"))
	print("STREAMING_TIMED_ROUTE_END")
	if OS.get_environment("V2_VERIFY_NO_HALOS")=="1":
		player.profile_physics=false
		if await _prepare_lighting_context():await _verify_no_halos()
	RealityState.persistence_enabled=old_persistence;RealityState.save_path=old_path
	var cleanup: Array=[]
	for suffix: String in ["",".bak",".tmp",".txn"]:
		var path:=ProjectSettings.globalize_path(owned_path+suffix)
		if FileAccess.file_exists(path):cleanup.append({"suffix":suffix,"error":DirAccess.remove_absolute(path)})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("cleanup.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","cleanup":cleanup},"\t"))

func _prepare_lighting_context() -> bool:
	# Ceiling attachment rays require resident support geometry. This third
	# prefetch is untimed; the two played cycles above are already frozen.
	if not await _leave_front_entrance():return false
	var started:=Time.get_ticks_msec()
	while world.passage_region.residency.state=="LOADING" and Time.get_ticks_msec()-started<180000:
		await get_tree().process_frame
	for frame in 2:await get_tree().physics_frame
	return _require(world.passage_region.residency.state=="RESIDENT","untimed lighting attachment checks have resident passage support geometry")

func _verify_no_halos() -> void:
	# Untimed source/power/geometry regression, not player switch qualification.
	var halo_draws: Array=[]
	for draw: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("surface_role",""))=="optical_halo":halo_draws.append(str(draw.get_path()))
	var fixtures:=0;var retired_slots:=true;var volume_energy:=true
	for node: Node in world.find_children("*","Node3D",true,false):
		if node is LightFixtureProp:
			fixtures+=1;retired_slots=retired_slots and node._halo==null
			volume_energy=volume_energy and is_instance_valid(node.light) and node.light.light_volumetric_fog_energy>0.
	_require(halo_draws.is_empty() and fixtures>0 and retired_slots,"all installed general fixtures have no optical halo billboard or texture node")
	_require(volume_energy,"installed fixture sources retain volumetric scattering energy")
	var environments: Array=[]
	for node: WorldEnvironment in world.find_children("*","WorldEnvironment",true,false):
		if node.environment!=null:environments.append({"path":str(node.get_path()),"volumetric_enabled":node.environment.volumetric_fog_enabled})
	var validator:=preload("res://tests/orison_v2_fixed_lighting_test.gd").new();validator.capture_enabled=false;add_child(validator)
	var result: Dictionary=await validator.validate_in_world(world)
	_require(result.failures.is_empty(),"native fixed lighting retains geometry, maps, mounts, photometry and circuit diagnostics after halo removal")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("no_halo_checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Untimed installed-mesh inventory and existing fixed-light geometry/photometry/circuit API regression. Circuit APIs are not primary-input qualification. No runtime_contract or human acceptance.","fixture_count":fixtures,"halo_draws":halo_draws,"retired_slots_null":retired_slots,"volumetric_energy_retained":volume_energy,"environments":environments,"fixed_lighting":result,"failures":failures},"\t"))
	validator.queue_free()

func _picture(label: String) -> void:
	var previous:=profile_phase;profile_phase="capture_excluded_"+label
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(label+".png"))
	await get_tree().process_frame;profile_phase=previous
