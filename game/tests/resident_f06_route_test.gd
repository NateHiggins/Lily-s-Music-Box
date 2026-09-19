extends "res://tests/resident_lift_waiting_test.gd"
## Exact reported F06 departure against the actual legacy root.
## Replays production route selection and movement, checking the actual Body
## capsule independently. Door-leaf exclusions match the NPC door contract;
## masonry, switches, furniture, and authored support remain blocking.

const REPORTED_FROM := Vector3(-8.25416, 16.03, 4.251141)
const REPORTED_TO := Vector3(1.925, 16.03, 7.4)
const FLOOR := "F06"


func _ready() -> void:
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("ResidentF06RouteTest requires fresh writable SHOT_DIR")
		get_tree().quit(2)
		return
	# Same world-facing settings and campaign initialization as CritterTest._in_world.
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	OS.set_environment("DREAM_HERO", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	world = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(world)
	var routines: ResidentRoutines = world.resident_routines
	_check("actual legacy routines and navigation exist", routines != null and routines.nav != null)
	if routines == null or routines.nav == null:
		await _finish()
		return
	routines.inspection_hold = true
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	evidence["endpoints"] = {"from": _v(REPORTED_FROM), "to": _v(REPORTED_TO)}
	evidence["before_collision_graph"] = _graph(routines.nav, FLOOR)
	evidence["before_endpoint_components"] = _diagnose(routines.nav, false)
	await get_tree().create_timer(1.6).timeout
	await get_tree().physics_frame
	await get_tree().physics_frame
	evidence["after_collision_graph"] = _graph(routines.nav, FLOOR)
	evidence["after_endpoint_components"] = _diagnose(routines.nav, true)
	evidence["collision_audit"] = {"cut": routines.nav.collision_cut,
		"relinked": routines.nav.collision_relinked, "stairs_blocked": routines.nav.stair_blocked,
		"detour_nodes": routines.nav.get("collision_detour_nodes"), "detour_edges": routines.nav.get("collision_detour_edges")}
	evidence["removed_edge_obstructions"] = _removed_edges(routines.nav)
	evidence["endpoint_capsules"] = {
		"resident_from": _capsule(REPORTED_FROM, 0.28, 1.55),
		"resident_to": _capsule(REPORTED_TO, 0.28, 1.55),
		"conservative_from": _capsule(REPORTED_FROM, 0.33, 1.65),
		"conservative_to": _capsule(REPORTED_TO, 0.33, 1.65)}
	await _run(routines)
	routines = null
	await _finish()


func _run(routines: ResidentRoutines) -> void:
	var homes: Array = []
	for actor: Dictionary in routines.actors:
		if routines.nav.floor_at(actor.home.y) != FLOOR: continue
		homes.append({"slug": str(actor.slug), "unit": str(actor.unit), "home": _v(actor.home),
			"distance_to_reported": actor.home.distance_to(REPORTED_FROM)})
	homes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.distance_to_reported) < float(b.distance_to_reported))
	evidence["f06_homes_nearest_first"] = homes
	_check("closest actual home is Sacha Reed in6A", not homes.is_empty()
		and homes[0].slug == "sacha_reed" and homes[0].unit == "6A")
	var selected: Dictionary = {}
	for actor: Dictionary in routines.actors:
		if str(actor.slug) == "sacha_reed": selected = actor; break
	if selected.is_empty(): return
	var home: Vector3 = selected.home
	var delta := REPORTED_FROM - home
	_check("reported start is inside the authored home pacing envelope",
		absf(delta.x) <= 1.6 and absf(delta.z) <= 1.6 and absf(delta.y) < 0.001)
	var actual_wait := routines._lift_point(REPORTED_FROM.y)
	_check("actual public lift target equals recorded endpoint", actual_wait.distance_to(REPORTED_TO) < 0.001)
	evidence["home_and_old_goal_controls"] = {
		"home_to_public": _endpoint_pair(routines.nav, home, actual_wait),
		"recorded_to_old_goal": _endpoint_pair(routines.nav, REPORTED_FROM, Vector3(1.9, 16.03, 5.6))}
	var probe := RandomNumberGenerator.new()
	var chosen := -1
	for seed_value in 4096:
		probe.seed = seed_value
		if probe.randf() > 0.99:
			chosen = seed_value
			break
	_check("deterministic elevator choice seed exists", chosen >= 0)
	if chosen < 0: return
	evidence["routine_rng_seed"] = chosen
	var actor_node: Node3D = selected.node
	var initial_position := actor_node.global_position
	actor_node.global_position = REPORTED_FROM
	routines._rng.seed = chosen
	var route_began := Time.get_ticks_usec()
	routines._begin_trip(selected, false)
	evidence["departure_route_usec"] = Time.get_ticks_usec() - route_began
	evidence["production_departure"] = {"slug": selected.slug, "home": _v(home),
		"from": _v(REPORTED_FROM), "path": _path(selected.path), "stage": selected.stage,
		"vertical_mode": selected.vertical_mode, "target_floor": selected.target_floor,
		"unreachable_keys": routines.nav.unreachable_route_keys()}
	_check("normal departure chooses elevator stage", selected.vertical_mode == "elevator"
		and selected.stage == ResidentRoutines.Stage.TO_LIFT)
	_check("recorded departure reaches public waiting point", selected.path.size() > 1
		and selected.path[-1].distance_to(REPORTED_TO) < 0.001)
	var nav: ResidentNav = routines.nav
	var entry: Dictionary = nav.floors[FLOOR]
	var graph: AStar3D = entry.astar
	# These are the three furniture cuts recorded in the immutable original
	# failure, resolved by semantic tags rather than recomputed removed edges.
	var original_tags := ["door_approach:F06_DOOR_02:-1.0",
		"door_approach:F06_DOOR_02:1.0", "door:F06_DOOR_02"]
	var by_tag := {}
	for point: Dictionary in entry.points: by_tag[str(point.tag)] = int(point.id)
	var old_exits_preserved := by_tag.has("room:F06_A_MAIN")
	var old_exit_records: Array = []
	for tag in original_tags:
		if not by_tag.has(tag) or not by_tag.has("room:F06_A_MAIN"):
			old_exits_preserved = false
			continue
		var a := int(by_tag["room:F06_A_MAIN"])
		var b := int(by_tag[tag])
		var blocked := nav._ray_blocked(world.get_world_3d().direct_space_state,
			graph.get_point_position(a), graph.get_point_position(b))
		var connected := graph.are_points_connected(a, b)
		old_exits_preserved = old_exits_preserved and blocked and not connected
		old_exit_records.append({"from": "room:F06_A_MAIN", "to": tag,
			"actual_ray_blocked": blocked, "graph_connected": connected})
	evidence["original_furniture_exit_controls"] = old_exit_records
	_check("original three furniture-blocked exits remain refused", old_exits_preserved and old_exit_records.size() == 3)
	var detours: Array = []
	var detours_clear := true
	for point: Dictionary in entry.points:
		if not str(point.tag).begins_with("room_detour:"): continue
		detours.append(point.id)
		for other in graph.get_point_connections(point.id):
			var a := graph.get_point_position(point.id)
			var b := graph.get_point_position(other)
			detours_clear = detours_clear and nav.has_method("_room_link_clear") and bool(nav.call("_room_link_clear", entry,
				world.get_world_3d().direct_space_state, a, b))
	_check("F06 has body-proved room detours", not detours.is_empty() and detours_clear)
	evidence["detour_node_ids"] = detours
	var body_shape: CollisionShape3D
	for child in actor_node.get_node("Body").get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			body_shape = child
			break
	_check("actual Sacha Body capsule is available", body_shape != null)
	if body_shape == null:
		actor_node.global_position = initial_position
		return
	var exclusions: Array[RID] = []
	_collect_door_leaves(world, exclusions)
	var constants: Dictionary = nav.get_script().get_script_constant_map()
	if constants.has("RESIDENT_BODY_RADIUS"):
		_check("portal proof matches actual resident Body dimensions",
			absf(float(constants.RESIDENT_BODY_RADIUS) - body_shape.shape.radius) < 0.000001
			and absf(float(constants.RESIDENT_BODY_HEIGHT) - body_shape.shape.height) < 0.000001)
	evidence["body_contract"] = {"radius": body_shape.shape.radius, "height": body_shape.shape.height,
		"local_center": _v(body_shape.position), "door_leaf_rids_excluded": exclusions.size(),
		"exclusion_scope": "DoorProp._body moving leaf only in the actual World3D; fixed frames and other descendant bodies remain blocking"}
	var complete: bool = selected.path.size() > 1 and selected.path[-1].distance_to(REPORTED_TO) < 0.001
	var route_body_clear := complete
	var blocked_segments: Array = []
	for i in range(selected.path.size() - 1):
		var a: Vector3 = selected.path[i]
		var b: Vector3 = selected.path[i + 1]
		a.y = REPORTED_FROM.y
		b.y = REPORTED_FROM.y
		if not _body_clear(body_shape, a, b, exclusions) or not nav._segment_clear(entry, a, b):
			route_body_clear = false
			blocked_segments.append({"from": _v(a), "to": _v(b),
				"body_diagnostic": _body_diagnostic(body_shape, a, b, exclusions)})
	evidence["blocked_body_segments"] = blocked_segments
	_check("whole recorded route clears actual body, masonry and furniture", route_body_clear)
	# Neighbouring wall crossing must not become a detour or direct shortcut.
	var wall_from := Vector3(-8.25, 16.03, 4.0)
	var wall_to := Vector3(-7.35, 16.03, 4.0)
	_check("neighbouring bath masonry blocks the actual body", not _body_clear(body_shape, wall_from, wall_to, exclusions))
	_check("neighbouring bath masonry blocks detour and direct admission",
		(not nav.has_method("_room_link_clear") or not bool(nav.call("_room_link_clear", entry, world.get_world_3d().direct_space_state, wall_from, wall_to)))
		and not nav._direct_segment_clear(entry, wall_from, wall_to))
	_check("recorded switch contact retains conservative endpoint refusal",
		not _capsule(REPORTED_FROM, 0.33, 1.65).colliders.is_empty()
		and (not nav.has_method("_detour_endpoint_clear") or not bool(nav.call("_detour_endpoint_clear", entry, REPORTED_FROM, Vector3(-8.28, 16.0, 4.99)))))
	var arrived := false
	var movement_clear := route_body_clear
	var movement_steps := 0
	var door_opened := false
	var home_door: DoorProp = selected.home_door
	var movement_began := Time.get_ticks_msec()
	if route_body_clear:
		for _i in 2400:
			await get_tree().physics_frame
			var before := actor_node.global_position
			routines._step(selected, 1.0 / 60.0)
			arrived = int(selected.leg) >= selected.path.size()
			door_opened = door_opened or (is_instance_valid(home_door) and home_door.open)
			movement_steps += 1
			# Real time advances the actual DoorProp tween. No door RID is
			# excluded here: the NPC owner must have opened the actual leaf.
			if not _body_clear(body_shape, before, actor_node.global_position, []):
				var door_state := {}
				if is_instance_valid(home_door):
					door_state = {"path": str(home_door.get_path()), "open": home_door.open,
						"moving": home_door._moving, "swing_out": home_door.swing_out,
						"leaf_state": home_door.leaf_state, "hinge_position": _v(home_door.global_position),
						"leaf_position": _v(home_door._body.global_position),
						"leaf_rotation": _v(home_door._body.rotation),
						"leaf_world_rotation": _v(home_door._body.global_rotation)}
				evidence["movement_block"] = {"from": _v(before), "to": _v(actor_node.global_position),
					"body_diagnostic": _body_diagnostic(body_shape, before, actor_node.global_position, []),
					"home_door": door_state, "door_cycle": selected.door_cycle,
					"path_leg": selected.leg, "elapsed_ms": Time.get_ticks_msec() - movement_began}
				movement_clear = false
				break
			if arrived: break
	evidence["movement"] = {"steps": movement_steps, "arrived": arrived,
		"body_clear": movement_clear, "final_position": _v(actor_node.global_position),
		"elapsed_ms": Time.get_ticks_msec() - movement_began,
		"home_door": str(home_door.get_path()) if is_instance_valid(home_door) else "missing",
		"actual_home_door_opened": door_opened, "movement_collider_exclusions": 0}
	_check("actual NPC door owner opens its home leaf", door_opened)
	_check("production movement reaches waiting point without body collision", arrived and movement_clear
		and actor_node.global_position.distance_to(REPORTED_TO) < 0.17)
	_check("recorded departure adds no unreachable event", nav.unreachable_route_count() == 0)
	body_shape = null
	home_door = null
	actor_node.global_position = initial_position


func _diagnose(nav: ResidentNav, physical: bool) -> Dictionary:
	var entry: Dictionary = nav.floors[FLOOR]
	var graph: AStar3D = entry.astar
	var components := {}
	var next_component := 0
	for id in graph.get_point_ids():
		if components.has(id): continue
		var pending: Array = [id]
		components[id] = next_component
		while not pending.is_empty():
			var current := int(pending.pop_back())
			for neighbour in graph.get_point_connections(current):
				if components.has(neighbour): continue
				components[neighbour] = next_component
				pending.append(neighbour)
		next_component += 1
	var starts := _all_visible(nav, REPORTED_FROM, components, physical)
	var goals := _all_visible(nav, REPORTED_TO, components, physical)
	var common_components: Array = []
	for start: Dictionary in starts:
		for goal: Dictionary in goals:
			if start.component == goal.component and start.component not in common_components:
				common_components.append(start.component)
	return {"component_count": next_component, "node_components": components,
		"all_visible_starts": starts, "all_visible_goals": goals,
		"all_visible_common_components": common_components,
		"production_top16_pair": _endpoint_pair(nav, REPORTED_FROM, REPORTED_TO)}


func _all_visible(nav: ResidentNav, at: Vector3, components: Dictionary, physical: bool) -> Array:
	var result: Array = []
	var entry: Dictionary = nav.floors[FLOOR]
	var graph: AStar3D = entry.astar
	for point: Dictionary in entry.points:
		var position := graph.get_point_position(point.id)
		if not nav._segment_clear(entry, at, position): continue
		var row := {"id": point.id, "tag": point.tag, "at": _v(position),
			"distance_squared": at.distance_squared_to(position), "component": components[point.id]}
		if physical:
			row["ray_blocked"] = nav._ray_blocked(world.get_world_3d().direct_space_state, at, position)
			row["ray_hits"] = _hits(at, position)
		result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.distance_squared) < float(b.distance_squared))
	return result


func _endpoint_pair(nav: ResidentNav, from: Vector3, to: Vector3) -> Dictionary:
	var entry: Dictionary = nav.floors[FLOOR]
	var pair := nav._connected_visible_pair(entry, from, to)
	return {"from": _v(from), "to": _v(to), "starts": nav._visible_candidates(entry, from),
		"goals": nav._visible_candidates(entry, to), "pair": [pair.x, pair.y]}


func _removed_edges(nav: ResidentNav) -> Array:
	var out: Array = []
	var graph: AStar3D = nav.floors[FLOOR].astar
	for row: Dictionary in evidence.before_collision_graph:
		for other in row.connections:
			if int(other) <= int(row.id) or graph.are_points_connected(int(row.id), int(other)): continue
			var a := graph.get_point_position(int(row.id))
			var b := graph.get_point_position(int(other))
			out.append({"a": row.id, "b": other, "from": _v(a), "to": _v(b), "blocking_hits": _hits(a, b)})
	return out


func _capsule(at: Vector3, radius: float, height: float) -> Dictionary:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.margin = 0.001
	query.collide_with_areas = false
	query.transform = Transform3D(Basis(), at + Vector3.UP * height * 0.5)
	var hits: Array = []
	for hit in world.get_world_3d().direct_space_state.intersect_shape(query, 64):
		hits.append(str(hit.collider.get_path()))
	return {"foot": _v(at), "radius": radius, "height": height, "colliders": hits}


func _collect_door_leaves(node: Node, exclusions: Array[RID]) -> void:
	var door := node as DoorProp
	if door != null and door.get_world_3d() == world.get_world_3d() and is_instance_valid(door._body):
		exclusions.append(door._body.get_rid())
	for child in node.get_children(): _collect_door_leaves(child, exclusions)


func _body_clear(collider: CollisionShape3D, from: Vector3, to: Vector3, exclusions: Array[RID]) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.margin = 0.001
	query.collide_with_areas = false
	query.exclude = exclusions
	query.transform = Transform3D(Basis(), from + collider.position)
	var space := world.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	query.transform.origin = to + collider.position
	if not space.intersect_shape(query, 1).is_empty(): return false
	query.transform.origin = from + collider.position
	query.motion = to - from
	var fractions := space.cast_motion(query)
	return fractions.size() == 2 and fractions[0] >= 1.0 and fractions[1] >= 1.0


func _body_diagnostic(collider: CollisionShape3D, from: Vector3, to: Vector3,
		exclusions: Array[RID]) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.margin = 0.001
	query.collide_with_areas = false
	query.exclude = exclusions
	query.transform = Transform3D(Basis(), from + collider.position)
	var space := world.get_world_3d().direct_space_state
	var start_hits: Array = []
	for hit in space.intersect_shape(query, 64): start_hits.append(str(hit.collider.get_path()))
	query.transform.origin = to + collider.position
	var end_hits: Array = []
	for hit in space.intersect_shape(query, 64): end_hits.append(str(hit.collider.get_path()))
	query.transform.origin = from + collider.position
	query.motion = to - from
	var fractions := space.cast_motion(query)
	var motion_hits: Array = []
	if fractions.size() == 2 and fractions[0] < 1.0:
		var motion := query.motion
		var advance := 0.01 / maxf(motion.length(), 0.01)
		query.transform.origin += motion * minf(float(fractions[1]) + advance, 1.0)
		query.motion = Vector3.ZERO
		for hit in space.intersect_shape(query, 64): motion_hits.append(str(hit.collider.get_path()))
	return {"start_overlaps": start_hits, "end_overlaps": end_hits,
		"motion_fraction": Array(fractions), "motion_hits": motion_hits}


func _finish() -> void:
	var retired: WeakRef = weakref(world) if is_instance_valid(world) else null
	if is_instance_valid(world): world.queue_free()
	world = null
	for _i in 4: await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	_check("actual legacy root retired", retired == null or retired.get_ref() == null)
	evidence["checks"] = checks
	evidence["failures"] = failures
	evidence["scope"] = "Deterministic recorded F06 departure using actual graph, collision validator, Body capsule and physics-frame production movement. NPC-managed leaves excluded only from static path proof; actual movement has zero collider exclusions and uses the real NPC door owner. No whole-autonomy or composed performance acceptance."
	var file := FileAccess.open(output.path_join("resident_f06_route.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write F06 route diagnostic")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	print("[F06 ROUTE PROBE] %d passed, %d failed" % [checks.size() - failures, failures])
	get_tree().quit(0 if failures == 0 else 1)
