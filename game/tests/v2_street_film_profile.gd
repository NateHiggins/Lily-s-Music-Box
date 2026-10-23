extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Diagnostic distributions in the occupied world, without readback during sampling.
var _frames: Array = []
var _collect := false
var _previous_usec := 0
var _phase := "setup"

func _init() -> void:
	route_label = "V2 STREET FILM PROFILE"

func _prepare_player_start() -> void:
	# One placement; every subsequent route segment uses ordinary locomotion.
	player.global_position = Vector3(7, .02, 3)
	player.velocity = Vector3.ZERO

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _collect and _previous_usec > 0:
		var rid := get_viewport().get_viewport_rid()
		_frames.append([_phase, (now-_previous_usec)/1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS)*1000,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,
			RenderingServer.viewport_get_measured_render_time_cpu(rid),
			RenderingServer.viewport_get_measured_render_time_gpu(rid),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	_previous_usec = now

func _route() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await get_tree().create_timer(2.0).timeout
	_collect = true
	await _street_route()
	_collect = false
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":"orison.diagnostic.frames.v1",
		"columns":["phase","wall_ms","process_ms","physics_ms","render_cpu_ms","render_gpu_ms","draw_calls","primitives"],
		"settings":{"viewport":str(get_viewport().get_visible_rect().size),"fov":player.camera.fov,"vsync":false},
		"frames":_frames,"failures":failures,"traffic_present":world.street_traffic != null}, "  "))

func _street_route() -> void:
	for repeat in 2:
		_phase = "cross_south_%d" % repeat
		for point in [Vector3(7,0,4.2), Vector3(7,-.1,8), Vector3(7,-.1,13.6), Vector3(7,0,14.8)]:
			if not await _walk_world(point): return
		_phase = "bar_approach_%d" % repeat
		if not await _walk_world(Vector3(5.65,0,17.3)): return
		_phase = "turn_at_bar_%d" % repeat
		for step in 120:
			player.apply_look(Vector2(3,0))
			await get_tree().process_frame
		_phase = "cross_north_%d" % repeat
		for point in [Vector3(5.65,0,14.8),Vector3(7,0,14.8),Vector3(7,-.1,13.6),Vector3(7,-.1,8),Vector3(7,0,4.2),Vector3(7,0,3)]:
			if not await _walk_world(point): return

func _walk_world(target: Vector3) -> bool:
	# Retain the original standing capsule and tolerances. Low-step locomotion
	# can still be landing when horizontal travel finishes at the opposite kerb.
	var started := Time.get_ticks_msec()
	var budget := maxi(6000,int(player.global_position.distance_to(target)/player.WALK*1000)+2000)
	var contacts: Dictionary = {}
	while Time.get_ticks_msec()-started < budget:
		var delta := target-player.global_position
		delta.y=0
		if delta.length()<.1:break
		player.rotation.y=atan2(-delta.x,-delta.z)
		player.camera.rotation=Vector3.ZERO
		Input.action_press("move_forward",minf(1.,delta.length()/.35))
		await get_tree().physics_frame
		for index in player.get_slide_collision_count():
			var contact:=player.get_slide_collision(index)
			if absf(contact.get_normal().y)<.7:
				contacts[str(contact.get_collider().get_path())]=str(contact.get_position())
	Input.action_release("move_forward")
	var landing_deadline := Time.get_ticks_msec()+2000
	while Time.get_ticks_msec()<landing_deadline:
		await get_tree().physics_frame
		if player.is_on_floor() and absf(player.velocity.y)<.01:break
	var actual := player.global_position
	var ok := Vector2(actual.x-target.x,actual.z-target.z).length()<.18 and absf(actual.y-target.y)<.15 \
		and not player.noclip and (player.collision_mask&1)==1 and player.is_physics_processing()
	trace.append({"target":str(target),"actual":str(actual),"ok":ok,"wall_contacts":contacts})
	if not ok:
		failures.append("street target %s actual %s" % [target,actual])
	return ok
