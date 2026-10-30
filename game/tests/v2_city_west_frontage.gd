extends "res://tests/orison_v2_street_crossing_test.gd"
## Played frontage/crossing plus unfiltered visibility and ground diagnostics.
## Does not grant new routes into the passive city or artistic acceptance.
var city_checks := 0
var city_observations: Dictionary = {}
var source_before := ""

func _ready() -> void:
	OS.set_environment("DAYNIGHT_FORCE", "12:00")
	GameBoot.settings.weather_network_enabled = false
	route_label = "V2 WEST FRONTAGE"
	capture_street_line = false
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	city_checks += 1
	if not ok:
		failures.append(label)
		push_error("WEST FRONTAGE: " + label)

func _digest() -> String:
	var result: Array = []
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	if OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], result) != 0: return ""
	return str(result[0]).strip_edges() if not result.is_empty() else ""

func _evidence_scope() -> String:
	return "Actual controller frontage walk and retained street crossing/door manipulation; unfiltered west-view, 115 fitted foundation contacts, vacated-grade and restored blocker controls. No passive-lot access, save reconstruction, full city, weather or artistic acceptance."

func _evidence_file() -> String:
	return "west_frontage_contract.json"

func _run() -> void:
	source_before = _digest()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928, 11, 10, 720)
	world = Runtime.instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed and world.player != null, "production composition starts")
	if not world.startup_failed and world.player != null:
		player = world.player
		_prepare_player_start()
		player.camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		check(world.passage_region.cell_nodes.size() == 13, "initial thirteen arcade cells retain their owner")
		check(world.bar_region.actors.get_child_count() > 0, "bar actors retain their owner")
		city_observations["initial_passage_residency"] = world.passage_region.residency.snapshot()
		# Preserve the cold first-frame stalls as startup diagnostics. Do not
		# charge renderer publication to a controller's bounded travel deadline.
		var startup_frames: Array = []
		var previous := Time.get_ticks_usec()
		for frame in 40:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			startup_frames.append((now-previous)/1000.)
			previous = now
		city_observations["startup_settle_wall_ms"] = startup_frames
		city_observations["settled_passage_residency"] = world.passage_region.residency.snapshot()
		await _route()
	Input.action_release("move_forward")
	world.shutdown_for_tests()
	world.free()
	await get_tree().physics_frame
	var source_after := _digest()
	check(not source_after.is_empty() and source_before == source_after, "frozen source across the executed route")
	var directory := OS.get_environment("SHOT_DIR")
	check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK, "writable evidence directory")
	if not directory.is_empty():
		var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
			"scope":_evidence_scope(),
			"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false},
			"source":{"test_path":"game/"+get_script().resource_path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"runtime_inputs_sha256":source_after},
			"contracts":{"production_composition":{"executed":true,"passed":failures.is_empty()},"frontage_and_crossing":{"executed":not trace.is_empty(),"passed":not trace.is_empty() and failures.is_empty(),"waypoints":trace.size()},"world_root_retirement":{"executed":true,"passed":not is_instance_valid(world)}},
			"checks":city_checks,"failures":failures,"trace":trace,"observations":city_observations}
		FileAccess.open(directory.path_join(_evidence_file()),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t")+"\n")
	print("%s: %d checks; %d waypoints; %d failures" % [route_label,city_checks,trace.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _west_ray() -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,1.41,3),Vector3(-130,4,3),1,[player.get_rid()]))

func _route() -> void:
	# Retain the original crossing, arcade stance and real door hands first.
	await super._route()
	if not failures.is_empty(): return
	if not await _leave_front_entrance(): return
	for point: Vector3 in [Vector3(0,0,3),Vector3(-8,0,3),Vector3(-16,0,3),Vector3(-19.2,0,3),Vector3(-16,0,3),Vector3(0,0,3)]:
		if not await _walk(world.adapter.root.to_local(point)): return
	check(_west_ray().is_empty(), "unfiltered 130-metre westward sightline from the front walk")
	await _open_footway_control()
	if not await _walk(world.adapter.root.to_local(Vector3(0,0,3))): return
	var city := world.get_node("CityShells") as Node3D
	# Restore one former blocker, including real physical backing. This must
	# close the same view; then restore the exact poses before continuing.
	var controls: Array[Dictionary] = []
	for draw: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
		if not draw.get_meta("retained_city_shell",false) or not str(draw.name).begins_with("site_nw1__"): continue
		var body := draw.get_parent().get_node(str(draw.name)+"Collision") as StaticBody3D
		var shape := body.get_child(0) as CollisionShape3D
		controls.append({"draw":draw,"pose":draw.transform,"shape":shape,"physical_pose":shape.transform})
		draw.position -= draw.get_meta("city_assembly_translation",Vector3.ZERO)
		shape.transform = draw.transform
	await get_tree().physics_frame
	await get_tree().physics_frame
	var blocked := _west_ray()
	check(not controls.is_empty() and not blocked.is_empty() and city.is_ancestor_of(blocked.collider), "original west-row blocker closes the same unfiltered sightline")
	city_observations["negative_control_owner"] = str(blocked.collider.get_path()) if not blocked.is_empty() else ""
	var control_directory := OS.get_environment("SHOT_DIR")
	if not control_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(control_directory)
		player.face_world_point(Vector3(-130,4,3))
		await get_tree().create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(control_directory.path_join("west_restored_blocker_control.png"))
	for control: Dictionary in controls:
		control.draw.transform = control.pose
		control.shape.transform = control.physical_pose
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(_west_ray().is_empty(), "exact restoration reopens the view")
	var foundation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_foundations_construction.json"))
	check(FileAccess.get_sha256("res://assets/props/city_foundations.glb")==foundation.source_native_sha256, "installed foundations bind their newly fitted native export")
	var foundation_contacts := 0
	var base_observations: Array = []
	for profile: Dictionary in foundation.profiles:
		var r: Array = profile.underside
		var actual_base := _actual_base_triangle(city,str(profile.id).trim_suffix("_base0"),world.adapter.root.to_global(Vector3((r[0]+r[2])*.5,0,(r[1]+r[3])*.5)))
		check(not actual_base.is_empty(), "current imported body has a real underside: "+str(profile.id))
		if actual_base.is_empty(): continue
		var fifth: Vector3 = world.adapter.root.to_local(actual_base.point)
		# Courtyards and hollow interiors are not body feet. Keep all four
		# original perimeter probes, then use the closest real bottom triangle.
		for at: Vector3 in [Vector3(r[0]+.1,0,r[1]+.1),Vector3(r[2]-.1,0,r[1]+.1),Vector3(r[0]+.1,0,r[3]-.1),Vector3(r[2]-.1,0,r[3]-.1),fifth]:
			var point: Vector3 = world.adapter.root.to_global(at)
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point-Vector3.UP*.03,point+Vector3.UP*.06,1,[player.get_rid()]))
			check(not hit.is_empty() and city.is_ancestor_of(hit.collider) and hit.position.distance_to(point)<.0001, "installed city underside retains its fitted foundation contact: "+str(profile.id))
			base_observations.append({"building":profile.id,"point":str(point),"hit":str(hit.position) if not hit.is_empty() else "","owner":str(hit.collider.get_path()) if not hit.is_empty() else "","basis":"imported bottom triangle" if at==fifth else "retained perimeter"})
			foundation_contacts += 1
	check(foundation_contacts==115, "five contact points on all 23 retained city bases")
	city_observations["foundation_contacts"] = foundation_contacts
	city_observations["foundation_probes"] = base_observations
	var ground: Node3D = world.adapter.root.get_node("Ground")
	var grade_samples: Array = []
	# Keep the original rays at y=-10: they lie in the authored 4 mm slab
	# joints and must hit the soil 2 cm below the walk, not invented concrete.
	# Adjacent field rays separately require the real full-height sidewalk.
	for source: Vector2 in [Vector2(-20.6,-10),Vector2(-26.5,-10),Vector2(-35.2,-10),Vector2(-45.25,-10),Vector2(-56.25,-10),Vector2(-20.6,-10.1),Vector2(-26.5,-10.1),Vector2(-35.2,-10.1),Vector2(-45.25,-10.1),Vector2(-56.25,-10.1),Vector2(-21,20),Vector2(-93,-1)]:
		var public_walk := source.y < -10.
		var expected_owner: Node = city.get_node("ContinuousStreetBlock") if public_walk else ground
		var expected_height := preload("res://scripts/building/orison_v2_city_streets.gd").surface_height(source.x)+(0. if public_walk else -.02)
		var point := city.to_global(Vector3(source.x,expected_height,-source.y))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.3,point-Vector3.UP*.3,1,[player.get_rid()]))
		var valid := not hit.is_empty() and expected_owner.is_ancestor_of(hit.collider) and absf(hit.position.y-point.y)<.0001
		check(valid, "vacated site has its actual sidewalk field, open joint or retained grade: "+str(source))
		grade_samples.append({"source":str(source),"role":"sidewalk_field" if public_walk else ("open_slab_joint" if source.y == -10. else "retained_grade"),"height":hit.position.y if not hit.is_empty() else null,"expected_world_height":point.y,"owner":str(hit.collider.get_path()) if not hit.is_empty() else ""})
	city_observations["vacated_grade"] = grade_samples
	await _paired_view_cost(city)
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		player.face_world_point(Vector3(-130,4,3))
		await get_tree().create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("west_from_front_walk.png"))
		city_observations["resolution"] = str(get_viewport().get_visible_rect().size)
		city_observations["msaa"] = get_viewport().msaa_3d
		city_observations["taa"] = get_viewport().use_taa
	if not await _enter_front_entrance(): return


func _actual_base_triangle(city: Node3D, identity: String, target: Vector3) -> Dictionary:
	var result: Dictionary = {}
	var best := INF
	for draw: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
		if not draw.get_meta("retained_city_shell",false) or not str(draw.name).begins_with(identity+"__"): continue
		var faces := draw.mesh.get_faces()
		for index in range(0,faces.size(),3):
			var a: Vector3=draw.global_transform*faces[index]
			var b: Vector3=draw.global_transform*faces[index+1]
			var c: Vector3=draw.global_transform*faces[index+2]
			if maxf(absf(a.y),maxf(absf(b.y),absf(c.y)))>.00001: continue
			if (b-a).cross(c-a).length_squared()<.000000000001: continue
			var point := (a+b+c)/3.
			var distance := point.distance_squared_to(target)
			if distance<best:
				best=distance
				result={"point":point,"draw":str(draw.name)}
	return result


func _paired_view_cost(city: Node3D) -> void:
	# ABBA source-placement control in one warmed world/current grade. This is
	# not the historical whole-world baseline; keep that separate route result.
	var moved: Array[Dictionary] = []
	for draw: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
		var offset: Vector3 = draw.get_meta("city_assembly_translation",Vector3.ZERO)
		if offset.is_zero_approx(): continue
		var row: Dictionary = {"draw":draw,"pose":draw.transform,"offset":offset}
		if draw.get_meta("retained_city_shell",false):
			var body := draw.get_parent().get_node(str(draw.name)+"Collision") as StaticBody3D
			row["shape"] = body.get_child(0) as CollisionShape3D
			row["physical_pose"] = row.shape.transform
		moved.append(row)
	check(moved.size()>50, "placement control includes bodies and roof equipment")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var viewport := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	player.face_world_point(Vector3(-130,4,3))
	var blocks: Array = []
	for placed: bool in [false,true,true,false]:
		for row: Dictionary in moved:
			row.draw.transform = row.pose
			if not placed: row.draw.position -= row.offset
			if row.has("shape"): row.shape.transform = row.draw.transform
		for frame in 30: await get_tree().process_frame
		var samples: Array = []
		var previous := Time.get_ticks_usec()
		for frame in 240:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			samples.append([(now-previous)/1000.,RenderingServer.viewport_get_measured_render_time_cpu(viewport),RenderingServer.viewport_get_measured_render_time_gpu(viewport),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
			previous = now
		blocks.append({"placed":placed,"samples":samples})
	for row: Dictionary in moved:
		row.draw.transform = row.pose
		if row.has("shape"): row.shape.transform = row.physical_pose
	await get_tree().physics_frame
	await get_tree().physics_frame
	RenderingServer.viewport_set_measure_render_time(viewport,false)
	check(_west_ray().is_empty(), "paired placement cost control restores the actual open view")
	city_observations["placement_cost_control"] = {"scope":"Same-process warmed ABBA west-facing placement control on current grade; live NPC/traffic and driver caches uncontrolled. Screenshot readback excluded. Main-viewport GPU excludes private viewports; engine rendering counters retain their global scope. No whole-world improvement or causal CPU attribution.","moved_draws":moved.size(),"columns":["wall_ms","main_render_cpu_ms","main_render_gpu_ms","engine_draws","engine_primitives","engine_objects"],"blocks":blocks}


func _open_footway_control() -> void:
	check(world.get_node_or_null("StreetBoundaries/RetainedStreetEnds") == null, "retired short street-end limits stay outside V2")
	for point: Vector3 in [Vector3(-21.5,0,3),Vector3(-25,0,3),Vector3(-19.2,0,3)]:
		if not await _walk(world.adapter.root.to_local(point)): return
	city_observations["open_footway"] = {"crossed_former_west_limit":true,"normal_collision":not player.noclip}
