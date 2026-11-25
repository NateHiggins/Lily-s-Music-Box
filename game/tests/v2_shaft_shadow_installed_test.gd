extends "res://tests/v2_performance_matrix.gd"
## Compare the running service-light policy against the authored maps.

const TARGET_SIZE := Vector2i(2560, 1440)
const CROSSING := "third_floor_crossing"
const YAW := TAU * 0.75
const SAMPLE_COUNT := 78


func _run() -> void:
	for action: StringName in InputMap.get_actions():
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion or event is InputEventJoypadButton:
				InputMap.action_erase_event(action, event)
				Input.action_release(action)
	get_window().borderless = true
	get_window().size = TARGET_SIZE
	await get_tree().process_frame
	await get_tree().process_frame
	var exact_size := Vector2i(get_viewport().get_visible_rect().size) == TARGET_SIZE
	if not exact_size or RenderingServer.get_current_rendering_method() != "forward_plus":
		push_error("The shaft shadow proof requires exact hidden 1440p Forward+")
		get_tree().quit(1)
		return
	OS.set_environment("ORISON_PERF_STATION", CROSSING)
	await super._run()


func _measure(station: Dictionary) -> Dictionary:
	var placed := _place(station)
	player.rotation.y = YAW
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not placed.ok or not await _settle():
		failures.append("The F03 service crossing did not settle")
		return {}
	var crossing_room := world.room_at_world(placed.position)
	if crossing_room.is_empty():
		failures.append("The matrix station is outside the installed room layout")
		return {}
	var budget: RefCounted = world.service_light_visibility.distance_budget
	var targets: Array[Dictionary] = []
	for row: Dictionary in budget.originals:
		if row.has("omni_mode"):
			targets.append({"row": row, "stock_mode": row.omni_mode})
	var ids: Array[String] = []
	for target: Dictionary in targets:
		ids.append(str(target.row.source.id))
	ids.sort()
	if ids.size() != 2:
		failures.append("Only the two measured shaft practicals may carry the cheaper map")
		return {}
	for target: Dictionary in targets:
		var light: OmniLight3D = target.row.source.light
		if not light.shadow_enabled or light.omni_shadow_mode != OmniLight3D.SHADOW_DUAL_PARABOLOID:
			failures.append("The actual F03 controller did not select dual-paraboloid shadows")
			return {}

	var arms: Array[Dictionary] = []
	for name: String in ["stock", "candidate", "stock_restored"]:
		for target: Dictionary in targets:
			var row: Dictionary = target.row
			var light: OmniLight3D = row.source.light
			if name == "candidate":
				row.omni_mode = target.stock_mode
			else:
				row.erase("omni_mode")
				light.omni_shadow_mode = target.stock_mode
		budget.tick()
		var sample := await _sample()
		sample.arm = name
		var shadow_mode := OmniLight3D.SHADOW_DUAL_PARABOLOID if name == "candidate" else OmniLight3D.SHADOW_CUBE
		for target: Dictionary in targets:
			var light: OmniLight3D = target.row.source.light
			if not light.is_visible_in_tree() or not light.shadow_enabled or light.omni_shadow_mode != shadow_mode:
				failures.append("The shaft light treatment did not hold in arm %s" % name)
		arms.append(sample)
		await _corridor_frame(name)
		var close_to_station := player.global_position.distance_to(placed.position) <= 0.05
		var still_in_room := world.room_at_world(player.global_position) == crossing_room
		var same_heading := absf(angle_difference(YAW, player.rotation.y)) <= 0.002
		if not (close_to_station and still_in_room and same_heading):
			failures.append("The F03 camera drifted in arm %s" % name)
		print("[SHAFT INSTALLED] %s shadows %.0f visible %.0f wall %.3f ms" % [
			name, sample.shadow_calls, sample.visible_calls, sample.wall_ms])
	for target: Dictionary in targets:
		target.row.omni_mode = target.stock_mode
	budget.tick()
	var stock_shadow_calls: float = (arms[0].shadow_calls + arms[2].shadow_calls) * 0.5
	if stock_shadow_calls - arms[1].shadow_calls < 1000.0:
		failures.append("The installed practicals did not reduce the shadow-call count")
	return {"name": CROSSING, "room": crossing_room, "yaw_degrees": 270,
		"practicals": ids, "arms": arms,
		"drift_m": player.global_position.distance_to(placed.position)}


func _sample() -> Dictionary:
	for frame in 36:
		await get_tree().process_frame
	_frame_usec = PackedInt64Array()
	_cpu_ms = PackedFloat64Array()
	_gpu_ms = PackedFloat64Array()
	_last_usec = 0
	var visible := PackedFloat64Array()
	var shadow := PackedFloat64Array()
	_sampling = true
	for frame in SAMPLE_COUNT:
		await get_tree().process_frame
		visible.append(RenderingServer.viewport_get_render_info(_viewport_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		shadow.append(RenderingServer.viewport_get_render_info(_viewport_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	_sampling = false
	return {"visible_calls": _median(visible), "shadow_calls": _median(shadow),
		"wall_ms": _summary_usec(_frame_usec).median, "cpu_ms": _median(_cpu_ms),
		"gpu_ms": _median(_gpu_ms), "sample_frames": _frame_usec.size()}


func _corridor_frame(name: String) -> void:
	var masked: Dictionary[Node3D, bool] = {}
	for member: Node in get_tree().get_nodes_in_group("animated_residents"):
		var actor := member as Node3D
		if actor != null and actor.global_position.distance_to(player.global_position) < 1.65:
			masked[actor] = actor.visible
			actor.visible = false
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var image := get_viewport().get_texture().get_image()
	if image.save_png(directory.path_join("shaft_%s.png" % name)) != OK:
		failures.append("The shaft comparison frame did not save")
	for actor: Node3D in masked:
		if is_instance_valid(actor):
			actor.visible = masked[actor]
	print("[SHAFT STILL] %s masked nearby residents=%d" % [name, masked.size()])


func _write(startup: Dictionary, rows: Array) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		failures.append("The shaft installed report destination is unavailable")
		return
	var output := FileAccess.open(directory.path_join("shaft_shadow_installed.json"), FileAccess.WRITE)
	if output == null:
		failures.append("The shaft installed report could not be opened")
		return
	output.store_string(JSON.stringify({
		"scope": "Production shaft shadow comparison at the F03 crossing, 270 degrees, 20:00.",
		"resolution": [TARGET_SIZE.x, TARGET_SIZE.y],
		"renderer": RenderingServer.get_current_rendering_method(),
		"startup": startup, "stations": rows, "failures": failures,
	}, "\t"))
	output.close()
