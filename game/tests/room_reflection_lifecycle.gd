extends "res://tests/room_reflection_review.gd"
## INERT real-world cache/lifecycle diagnostics. Camera placement is a fixture,
## not traversal/input proof; no production enable or runtime-contract claim.
const REVIEW_ROOMS: Array[String]=["F01_WATCH","F02_B_MAIN","B1_BOILER_ROOM","F02_A_MAIN","F03_B_MAIN","F04_B_MAIN"]
var samples: Array[Dictionary]=[]
var retired: Array[Dictionary]=[]
var baseline_only := false

func _run() -> void:
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	baseline_only=OS.get_environment("REFLECTION_BASELINE_ONLY")=="1"
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	for generation in range(2):
		var world := await _world()
		if world.startup_failed or world.player==null:world.free();break
		var manager := world.get_node_or_null("V2RoomReflections")
		check(manager!=null,"production world owns its capture cache")
		if manager==null:world.free();break
		manager.process_mode=Node.PROCESS_MODE_ALWAYS
		manager.set_reflections_enabled(false)
		world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
		await get_tree().create_timer(1.).timeout
		var original_layers: int=manager._lamp_layers_before
		var parked := world.player.camera.global_position
		var camera := Camera3D.new();camera.name="DetachedReflectionReviewCamera"
		world.add_child(camera);camera.make_current()
		check(not manager.rooms.is_empty(),"generation %d derives its real room layout"%generation)
		manager.set_reflections_enabled(false)
		for cycle in range(3):
			for identity in REVIEW_ROOMS:
				get_tree().paused=false;manager.set_reflections_enabled(false)
				var bounds := _bounds(manager,identity)
				check(bounds.size.length()>0,"authored review room exists: "+identity)
				if bounds.size.length()==0:continue
				camera.global_position=manager.frame.to_global(bounds.get_center())
				await get_tree().physics_frame
				var origin: Vector3=manager._clear_origin(bounds)
				check(origin.is_finite(),"review camera has clear physical origin: "+identity)
				if not origin.is_finite():continue
				camera.global_position=manager.frame.to_global(origin)
				camera.look_at(camera.global_position+manager.frame.global_basis*Vector3.FORWARD)
				await get_tree().create_timer(.3).timeout
				get_tree().paused=true
				var baseline := await _profile_frames(35)
				manager.set_reflections_enabled(not baseline_only)
				var acquisition := await _profile_frames(35)
				var steady := await _profile_frames(35)
				if baseline_only:
					check(manager.probes.is_empty(),"control allocates no candidate captures: "+identity)
				else:
					check(manager.active_id==identity and manager.probes.has(identity),"capture follows actual detached camera: "+identity)
				check(world.player.camera.global_position.is_equal_approx(parked),"controller camera remains parked")
				check(manager.probes.size()<=manager.CACHE_LIMIT,"capture cache stays bounded during turnover")
				samples.append({"generation":generation,"cycle":cycle,"room":identity,"cached":manager.probes.size(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"baseline_frames":baseline,"acquisition_frames":acquisition,"steady_frames":steady,"refreshes":manager.refresh_count})
				if generation==0 and cycle==2:await _save_lifecycle_capture(identity)
			if cycle==0 and not baseline_only:
				await _refresh_controls(manager,world)
		check(manager.errors.is_empty(),"no clear-origin errors in reviewed cache sweep")
		var before_exit := manager.refresh_count
		camera.global_position=manager.frame.to_global(Vector3(500,100,500))
		await _render_frames(35)
		check(manager.active_id.is_empty() and manager.refresh_count==before_exit,"leaving authored rooms creates no exterior capture")
		var weak_probes: Array[WeakRef]=[]
		for probe: ReflectionProbe in manager.probes.values():weak_probes.append(weakref(probe))
		manager.free()
		for probe in weak_probes:check(probe.get_ref()==null,"retiring capture owner frees cached probe node")
		check(world.player.flashlight.layers==original_layers,"capture retirement restores exact original carried-light layers")
		world.player.camera.make_current();camera.free();get_tree().paused=false
		world.free();await _render_frames(12)
		retired.append({"generation":generation,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
	if retired.size()==2:check(retired[1].nodes==retired[0].nodes,"second production reconstruction leaves no extra scene nodes")
	_finish_lifecycle()

func _bounds(manager: Node3D,identity: String) -> AABB:
	for room: Dictionary in manager.rooms:
		if room.id==identity:return room.bounds
	return AABB()

func _refresh_controls(manager: Node3D,world: OrisonV2RuntimeRoot) -> void:
	check(manager.probes.size()==manager.CACHE_LIMIT,"first sweep fills the three-entry cache")
	var keys: Array=manager.probes.keys()
	if keys.size()<2:return
	var a: ReflectionProbe=manager.probes[keys[0]]
	for repeat in range(4):
		var before := a.transform
		manager._refresh(keys[0]);manager._refresh(keys[1])
		check(a.transform!=before,"interleaved room refresh really changes each probe transform")
	var switches := world.get_node("V2RoomSwitches") as SwitchSystem
	var snapshot := switches.room_snapshot("F04_B_MAIN")
	check(not snapshot.is_empty(),"reviewed room has its real circuit authority")
	var count: int=manager.refresh_count
	check(switches.restore_room("F04_B_MAIN",snapshot),"actual circuit verdict emits refresh invalidation")
	await _render_frames(35)
	check(manager.refresh_count>count,"active capture refreshes after its real circuit signal")
	for identity: String in manager.probes:
		if identity!=manager.active_id:check(int(manager._refresh_due[identity])==0,"other cached rooms retain pending circuit invalidation")

func _render_frames(count: int) -> void:
	for index in range(count):await RenderingServer.frame_post_draw

func _profile_frames(count: int) -> Dictionary:
	var values: Array[float]=[]
	var before := Time.get_ticks_usec()
	for index in range(count):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		values.append(float(now-before)/1000.);before=now
	var total := 0.
	for value in values:total+=value
	values.sort()
	return {"mean_ms":total/count,"p95_ms":values[int(floor((count-1)*.95))],"max_ms":values.back(),"frame_count":count}

func _save_lifecycle_capture(identity: String) -> void:
	var picture := get_viewport().get_texture().get_image()
	check(picture.save_png(out.path_join(identity+"_detached_camera.png"))==OK,"actual cache-sweep room captured: "+identity)

func _finish_lifecycle() -> void:
	get_tree().paused=false
	FileAccess.open(out.path_join("room_reflection_lifecycle.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","baseline_only":baseline_only,"checks":checks,"failures":failures,"samples":samples,"retired":retired,"scope":"Two actual production worlds; detached-camera/cache/interleaved refresh/circuit/owner-retirement diagnostics. Baseline mode leaves candidate captures disabled. Memory samples are observations, not a clean engine-lifecycle or performance acceptance. No traversal/input/runtime contract or production enable."},"\t"))
	print("ROOM REFLECTION LIFECYCLE: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",failures)
	terminal=true;get_tree().quit(0 if failures.is_empty() else 1)
