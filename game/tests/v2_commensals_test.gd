extends Node
## The commensals in V2 (v1r_commensals_20261109): V1's census, night rule and
## once-a-shift roach scatter, with Blender bodies at V2's own lamps and 4B's
## kitchen. Moths gather at the two street lamps nearest the front door while
## the lamps burn, leave a lamp that goes out and come back when it is lit;
## the roaches scatter when 4B's kitchen light is switched on at night, once.
## With SHOT_DIR set (windowed), also photographs both.
const Commensals := preload("res://scripts/building/orison_v2_commensals.gd")
## V1's orbit: radius up to 0.62 m, the vertical wander 0.42 of it.
const ORBIT := 0.62 * 1.09 + 0.02

var _fails := 0
var _checks := 0
var _world: Node
var _stand := Vector3.ZERO
var _look := Vector3.ZERO
var _framing := false
var _quiet_failed: Dictionary = {}


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _check_quiet(ok: bool, label: String) -> void:
	if not ok and not _quiet_failed.has(label):
		_quiet_failed[label] = true
		_check(false, label)


func _ready() -> void:
	process_priority = 1000
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(_world)
	while not _world.startup_failed and _world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not _world.startup_failed, "the V2 world starts")
	if _world.startup_failed:
		_finish()
		return
	var blockout: Node3D = _world.get("_blockout")
	var node: Node = _world.get_node_or_null("Commensals")
	if node == null:
		node = Commensals.mount(_world, blockout, _world.layout, _world.adapter)
	_check(node.errors.is_empty(), "the mount reports no errors: %s" % [node.errors])
	_check(node.get_script() == Commensals and node is CommensalDirector, "the V2 commensals are V1's director, extended")
	if not node.errors.is_empty():
		_finish()
		return
	await _settle(node)
	_world.player.set_physics_process(false)
	_stand = _world.player.global_position
	_look = _stand + Vector3.FORWARD
	_framing = true
	_census_checks(node)
	_surface_checks(node)
	await _moth_checks(node)
	await _roach_checks(node, blockout)
	_finish()


func _process(_delta: float) -> void:
	if _framing and _world != null and _world.player != null:
		_world.player.global_position = _stand
		_world.player.camera.look_at(_look)


func _settle(node: Node) -> void:
	var calm := 0
	var last := Time.get_ticks_usec()
	for i in 1800:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		calm = calm + 1 if now - last < 250000 else 0
		last = now
		if calm >= 60 and node.can_process():
			return
	_check(false, "the world settles and the commensals process")


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _census_checks(node: Node) -> void:
	var seen: Dictionary = node.diagnostic_snapshot()
	_check(node.moths.size() == int(node.census.moths) and node.moths.size() >= 8 and node.moths.size() <= 12,
		"V1's census gives 8 to 12 moths (%d)" % node.moths.size())
	_check(node.roaches.size() == int(node.census.roaches) and node.roaches.size() >= 4 and node.roaches.size() <= 6,
		"V1's census gives 4 to 6 roaches (%d)" % node.roaches.size())
	_check(node.lamp_lights.size() == 2, "the moths have two street lamps (%s)" % [seen.anchors.get("lamps", [])])
	_check(int(seen.draw_batches) == 4, "four draws: moth bodies, two wing pairs, roaches (%d)" % int(seen.draw_batches))
	_check(int(seen.collision_nodes) == 0 and int(seen.lights) == 0 and int(seen.shadow_casters) == 0,
		"no collision, no lights and no shadows, as V1")
	_check(int(node.schedule.roach_scatters_per_shift) == 1, "V1's schedule: one scatter a shift")
	# The lamps chosen are the two nearest the front-door threshold.
	var clock: Node = get_tree().get_nodes_in_group("v2_street_lamp_clocks")[0]
	var threshold: Vector3 = (clock.get_parent().get_parent() as Node3D).global_position
	var chosen := 0.0
	for light: OmniLight3D in node.lamp_lights:
		chosen = maxf(chosen, light.global_position.distance_to(threshold))
	var nearer := 0
	for light: OmniLight3D in clock.lights:
		if light.global_position.distance_to(threshold) < chosen - 0.001:
			nearer += 1
	_check(nearer == 1, "they are the two lamps nearest the front door (farther one %.1f m off, of %d lamps)" % [chosen, clock.lights.size()])
	for light: OmniLight3D in node.lamp_lights:
		_check(_world.room_at_world(light.global_position).is_empty() and light.global_position.y > 2.5,
			"lamp %s is out in the street, overhead" % light.name)


func _surface_checks(node: Node) -> void:
	var triangles := 0
	for batch: MultiMeshInstance3D in node.draw_batches():
		var bad: Array[String] = []
		var mesh := batch.multimesh.mesh as ArrayMesh
		if mesh == null or mesh.get_surface_count() != 1:
			bad.append("not one authored surface")
		else:
			var arrays := mesh.surface_get_arrays(0)
			var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
			if uvs == null or (uvs as PackedVector2Array).is_empty() or arrays[Mesh.ARRAY_TANGENT] == null:
				bad.append("no authored UVs or tangents")
			var count := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			if count > 60:
				bad.append("%d triangles is not a few dozen" % count)
			triangles += count * batch.multimesh.instance_count
		var finish := batch.material_override as StandardMaterial3D
		if finish == null or finish.albedo_texture == null or finish.roughness_texture == null \
				or finish.normal_texture == null or finish.uv1_triplanar:
			bad.append("not a catalogue finish on its own UVs")
		if batch.visibility_range_end <= 0.0 or batch.visibility_range_end > 40.0:
			bad.append("no visibility range")
		_check(bad.is_empty(), "%s is Blender stock in a catalogue finish %s" % [batch.name, bad])
	print("  [V2 COMMENSALS] %d draws, %d triangles when every animal is out" % [node.draw_batches().size(), triangles])


func _lamps(minute: float) -> void:
	for clock in get_tree().get_nodes_in_group("v2_street_lamp_clocks"):
		clock.clock_override = {"valid": true, "month": 11, "minute_of_day": minute}
		clock.refresh()


## [nearest, farthest, how many present] over every moth and its own lamp.
func _moth_spread(node: Node) -> Array:
	var worst := 0.0
	var least := INF
	var present := 0
	for i in node.moths.size():
		var lamp: Vector3 = node.lamp_lights[int(node.moths[i].lamp)].global_position
		var away: float = node.moth_position(i).distance_to(lamp)
		worst = maxf(worst, away)
		least = minf(least, away)
		if node.moth_present(i):
			present += 1
	return [least, worst, present]


func _moth_checks(node: Node) -> void:
	var lamp: Vector3 = node.lamp_lights[0].global_position
	var ground := lamp.y - 3.86
	# Stand on the pavement under the lamps, at night, with the lamps lit.
	_stand = Vector3(lamp.x + 2.4, ground, lamp.z + 2.4)
	_look = lamp
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928, 11, 10, 22 * 60)
	_lamps(1320.0)
	await _wait(1.5)
	node.tick_for_test()
	print("  [V2 COMMENSALS] the day-night director calls 22:00 %s" % ("night" if node._is_night() else "not night"))
	node.force_night_for_test(true)
	_check(node.lamp_lit(0) and node.lamp_lit(1), "both lamps burn at 22:00")
	_check(node.moth_batch.visible, "moths are out at night for a player in the street")
	await _wait(Commensals.GATHER_SECONDS + 0.5)
	var spread := _moth_spread(node)
	_check(int(spread[2]) == node.moths.size() and float(spread[1]) <= ORBIT,
		"every moth circles its lit lamp inside V1's orbit (farthest %.2f m, %d present)" % [spread[1], spread[2]])
	# They fly: positions change, and the wings beat on their roots.
	var before: Vector3 = node.moth_position(0)
	var lifts: Array[float] = []
	var worst_root := 0.0
	for i in 40:
		await get_tree().process_frame
		var body: Transform3D = node.moth_body_pose(0)
		var wing: Transform3D = node.moth_wing_pose(1, 0)
		lifts.append((body.basis.inverse() * wing.basis).get_euler().z)
		worst_root = maxf(worst_root, (body.affine_inverse() * wing.origin).distance_to(node._wing_roots[1]))
	_check(node.moth_position(0).distance_to(before) > 0.01, "a moth moves round its lamp")
	_check(worst_root < 0.001 and absf(node._wing_roots[1].x - 0.004) < 0.0001 and absf(node._wing_roots[0].x + 0.004) < 0.0001,
		"each wing pair stays on its root, 4 mm off the body's line (roots %s, worst slip %.2f mm)" % [node._wing_roots, worst_root * 1000.0])
	_check(lifts.max() - lifts.min() > 0.15 and lifts.min() >= -0.01 and lifts.max() <= acos(0.62) + 0.01,
		"the wings beat between flat and V1's 0.62 narrowing (%.2f to %.2f rad)" % [lifts.min(), lifts.max()])
	if not OS.get_environment("SHOT_DIR").is_empty():
		await _photograph_moths(node)
	# The lamp goes out: its moths leave.
	_lamps(720.0)
	_check(not node.lamp_lit(0) and not node.lamp_lit(1), "the lamp clock puts the lamps out")
	await _wait(Commensals.GATHER_SECONDS * 0.5)
	spread = _moth_spread(node)
	_check(float(spread[0]) > ORBIT, "every moth has left its dark lamp (nearest %.2f m)" % spread[0])
	await _wait(Commensals.GATHER_SECONDS * 0.5 + 0.5)
	spread = _moth_spread(node)
	_check(int(spread[2]) == 0, "no moth is left at a lamp that is out (%d present)" % int(spread[2]))
	# Lit again: they come back.
	_lamps(1320.0)
	await _wait(Commensals.GATHER_SECONDS + 0.5)
	spread = _moth_spread(node)
	_check(int(spread[2]) == node.moths.size() and float(spread[1]) <= ORBIT,
		"the moths come back to the relit lamp (farthest %.2f m)" % spread[1])
	# V1's own rules: none by day, none for a player upstairs indoors.
	node.force_night_for_test(false)
	_check(not node.moth_batch.visible and not node.moth_wing_batches[0].visible, "no moths by day")
	node.force_night_for_test(true)
	node.set_visibility_context(_world.adapter.resolve(str(node.anchor_ids.kitchen)).global_position + Vector3.UP)
	_check(not node.moth_batch.visible, "no moths drawn for a player upstairs")
	node.set_visibility_context(_stand)
	_check(node.moth_batch.visible, "moths again for a player in the street")


func _roach_checks(node: Node, blockout: Node3D) -> void:
	var switches := _world.get_node("V2RoomSwitches") as SwitchSystem
	var sink: Vector3 = _world.adapter.resolve(str(node.anchor_ids.kitchen)).global_position
	var floor_y := blockout.to_global(Vector3(0, 9.6, 0)).y
	var centre := Vector3.ZERO
	for roach: Dictionary in node.roaches:
		centre += (roach.at as Vector3) / float(node.roaches.size())
	var out := ((centre - sink) * Vector3(1, 0, 1)).normalized()
	_stand = Vector3(centre.x, floor_y, centre.z) + out * 1.3
	_look = centre
	await _wait(0.3)
	node.tick_for_test()
	var room: String = _world.room_at_world(centre + Vector3.UP * 0.3)
	_check(room == Commensals.KITCHEN_ROOM, "the roaches wait in 4B's kitchen (%s)" % room)
	var off: float = (centre - sink).slide(Vector3.UP).length()
	_check(absf(off - 0.46) < 0.05, "0.46 m in front of the sink, as V1 (%.2f m)" % off)
	var lit := [false]
	var heard := func(toggled: String, on: bool) -> void:
		if toggled == Commensals.KITCHEN_ROOM:
			lit[0] = on
	switches.room_toggled.connect(heard)
	# Put the kitchen dark first.
	switches.toggle_room(Commensals.KITCHEN_ROOM)
	if lit[0]:
		switches.toggle_room(Commensals.KITCHEN_ROOM)
	_check(not lit[0], "4B's kitchen light is off")
	# By day, switching the light on scatters nothing.
	node.reset_habituation_for_test()
	node.force_night_for_test(false)
	switches.toggle_room(Commensals.KITCHEN_ROOM)
	_check(lit[0] and node.roach_scatter_count == 0 and not node.roach_batch.visible, "no roaches by day")
	switches.toggle_room(Commensals.KITCHEN_ROOM)
	# At night the switch sends them running, once.
	node.force_night_for_test(true)
	_check(not node.roach_batch.visible, "unseen in the dark")
	switches.toggle_room(Commensals.KITCHEN_ROOM)
	_check(lit[0] and node.roach_scatter_count == 1 and node.roach_batch.visible,
		"switching the kitchen light on at night scatters the roaches")
	var start: Array[Vector3] = []
	var grounded := 0
	for i in node.roaches.size():
		start.append(node.roach_position(i))
		var query := PhysicsRayQueryParameters3D.create(start[i] + Vector3.UP * 0.2, start[i] + Vector3.DOWN * 0.2)
		var hit: Dictionary = node.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and absf((hit.position as Vector3).y - start[i].y) < 0.004:
			grounded += 1
	_check(grounded == node.roaches.size(), "every roach stands on the kitchen floor (%d of %d)" % [grounded, node.roaches.size()])
	if not OS.get_environment("SHOT_DIR").is_empty():
		await _photograph_roaches(node, centre, floor_y)
	await _wait(Commensals.ROACH_RUN_SECONDS + 0.05)
	var ran_ok := 0
	for i in node.roaches.size():
		var ran: float = node.roach_position(i).distance_to(start[i])
		var outward: bool = (node.roach_position(i) - centre).length() > (start[i] - centre).length() + 0.3
		if ran > 0.76 * 0.55 - 0.02 and ran < 1.49 * 0.55 + 0.02 and outward:
			ran_ok += 1
	_check(ran_ok == node.roaches.size(), "each runs outward by V1's distance in V1's 1.2 s (%d of %d)" % [ran_ok, node.roaches.size()])
	await _wait(0.4)
	node.tick_for_test()
	_check(not node.roach_batch.visible, "they are gone after V1's 1.35 s")
	switches.toggle_room(Commensals.KITCHEN_ROOM)
	switches.toggle_room(Commensals.KITCHEN_ROOM)
	_check(lit[0] and node.roach_scatter_count == 1 and not node.roach_batch.visible,
		"a second switching the same shift scatters nothing")
	switches.room_toggled.disconnect(heard)


func _prepare_shots() -> String:
	var dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	for layer in _world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	if _world.service_set_carrier != null:
		_world.service_set_carrier.visible = false
	_world.player.set_lamp_enabled(false)
	return dir


func _photograph_moths(node: Node) -> void:
	var dir := _prepare_shots()
	var lamp: Vector3 = node.lamp_lights[0].global_position
	var ground := lamp.y - 3.86
	var keep := _stand
	_stand = Vector3(lamp.x + 3.2, ground, lamp.z + 2.0)
	_look = lamp
	await _shoot(dir + "/moths_street.png")
	_stand = Vector3(lamp.x + 1.1, lamp.y - 1.9, lamp.z + 0.7)
	await _shoot(dir + "/moths_close.png")
	var fov: float = _world.player.camera.fov
	_world.player.camera.fov = 28.0
	await _shoot(dir + "/moths_closer.png")
	_world.player.camera.fov = fov
	_stand = keep


func _photograph_roaches(node: Node, centre: Vector3, floor_y: float) -> void:
	var dir := _prepare_shots()
	# Hold the scatter at its first instant for the pictures.
	node.set_process(false)
	await _shoot(dir + "/roaches_standing.png")
	var keep := _stand
	_stand = Vector3(lerpf(centre.x, keep.x, 0.45), floor_y - 1.05, lerpf(centre.z, keep.z, 0.45))
	await _shoot(dir + "/roaches_close.png")
	_stand = keep
	node.set_process(true)
	node._roach_started = node._clock


func _shoot(path: String) -> void:
	for i in 30:
		await get_tree().process_frame
	for i in 10:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _finish() -> void:
	var ok := _fails == 0
	print("[V2 COMMENSALS] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	_framing = false
	if _world != null:
		if _world.has_method("shutdown_for_tests"):
			_world.shutdown_for_tests()
		remove_child(_world)
		_world.free()
		_world = null
	get_tree().quit(0 if ok else 1)
