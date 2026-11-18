extends "res://tests/bodega_queue_motor_test.gd"
## Normal player input and the registered resident guide on the fitted pair.

func _snapshot() -> Dictionary:
	var result := super._snapshot()
	for source: String in ["res://tests/bodega_queue_motor_test.gd",
			"res://scripts/building/orison_v2_bodega_shop_door.gd",
			"res://scripts/building/orison_v2_arcade_shop_door.gd",
			"res://scripts/player/door_passage_guide.gd"]:
		result[source] = {"sha256":FileAccess.get_file_as_string(source).replace("\r\n", "\n").sha256_text()}
	return result

func _overflow_newcomer() -> void:
	var door := exterior.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF")
	# Clear the first departure's destination using her ordinary resident motor.
	# The parent fixture leaves her at the next departure's pavement destination.
	var first: Node3D = routes[0]
	var upstream: int = int(first.identities.upstream)
	first.force_destination = "upstream"
	var departure_deadline := Time.get_ticks_msec() + 30000
	while failures.is_empty() and Time.get_ticks_msec() < departure_deadline:
		if first.current_id == upstream and first.path.is_empty(): break
		await get_tree().physics_frame
	if not _check(first.current_id == upstream and first.path.is_empty(), "first resident clears the next departure's pavement destination"): return
	var resident: Node3D = routes[1]
	var outside: Vector3 = measured.exterior
	var inside: Vector3 = measured.interior
	player.global_position = outside
	player.rotation.y = door.global_rotation.y
	player.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await get_tree().physics_frame
	var start := door.to_local(player.global_position)
	var resident_start := door.to_local(resident.actor.global_position)
	var interior := door.to_local(inside)
	if not _check(start.z > 0.0 and resident_start.z < 0.0 and door.is_ready_for_passage(),
			"player and resident start on opposite sides of the actual open paired frame"): return
	var trace: Array[Dictionary] = []
	var minimum_spacing := INF
	var entered := false
	var exited := false
	var physical_leaves_enabled := true
	var yielded := false
	resident.force_destination = "alignment"
	Input.action_press("move_forward")
	var until := Time.get_ticks_msec() + 15000
	var frame := 0
	while failures.is_empty() and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		frame += 1
		var player_local := door.to_local(player.global_position)
		var resident_local := door.to_local(resident.actor.global_position)
		yielded = yielded or (player_local.z > 0.0 and resident.blocked_reason == "departure path occupied; retain waiting station")
		var offset := player_local - resident_local
		minimum_spacing = minf(minimum_spacing,Vector2(offset.x,offset.z).length())
		for leaf: Dictionary in door.motion_leaves():
			physical_leaves_enabled = physical_leaves_enabled and not player.get_collision_exceptions().has(leaf.body)
		if not entered and player_local.z <= interior.z and not player._door_passage.active():
			entered = true
			Input.action_release("move_forward")
			# Clear the diagonal from the counter to the center of the frame.
			Input.action_press("move_right")
		if entered and player_local.x >= door.width*.5+.95: Input.action_release("move_right")
		exited = exited or resident_local.z > .38
		if frame%15==0 or (entered and exited):
			trace.append({"frame":frame,"player_local":player_local,"resident_local":resident_local,
				"resident_state":resident.blocked_reason,"guided":player._door_passage.active()})
		if entered and exited: break
	Input.action_release("move_forward")
	Input.action_release("move_right")
	player.set_physics_process(false)
	details.mixed_passage={"scope":"Concurrent storefront approach after a departure and initial queue transfer. The player steps beyond the counter-to-door diagonal after crossing.",
		"entered":entered,"exited":exited,"yielded":yielded,"trace":trace,"minimum_horizontal_axis_distance_m":minimum_spacing}
	_check(entered and exited,"continuous player entry and opposite resident exit both complete through the installed bodega")
	_check(yielded,"the resident yields to the approaching player before trying to use the frame")
	_check(minimum_spacing >= player._capsule.radius+resident._capsule.radius-.001,"the two full body envelopes remain separated")
	_check(physical_leaves_enabled and door.is_ready_for_passage(),"both real collisions remain enabled and the pair stays open")
