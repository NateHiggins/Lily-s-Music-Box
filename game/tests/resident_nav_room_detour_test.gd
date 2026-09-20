extends Node3D
## Independent split-room controls: every original node has a neighbour.
## A finite furniture obstacle needs a detour; a complete masonry divider
## must retain its disconnected components. Both cases run at two origins.

var checks: Array = []
var failures := 0
var measurements: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for origin in [Vector3.ZERO, Vector3(40.0, 6.4, 25.0)]:
		await _case(origin, false)
		await _case(origin, true)
		await _finish_support_cases(origin)
		await _portal_body_cases(origin)
	var folder := OS.get_environment("SHOT_DIR")
	if folder != "":
		if DirAccess.make_dir_recursive_absolute(folder) != OK:
			_check("requested proof directory can be created", false)
		else:
			var file := FileAccess.open(folder.path_join("resident_nav_room_detour.json"), FileAccess.WRITE)
			if file == null:
				_check("requested proof file can be opened", false)
			else:
				var stored := file.store_buffer(JSON.stringify({"checks": checks, "failures": failures,
					"measurements": measurements, "scope": "Synthetic bounded room detours, translated floor datum, finished support, masonry and body-width negatives. No composed performance acceptance."}, "\t").to_utf8_buffer())
				file.flush()
				var error := file.get_error()
				file.close()
				if not stored or error != OK: _check("requested proof bytes persist", false)
	print("[RESIDENT ROOM DETOUR] %d/%d passed" % [checks.size() - failures, checks.size()])
	get_tree().quit(failures)


func _case(origin: Vector3, divider: bool) -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(64, 64)
	add_child(viewport)
	_box(viewport, "Support", origin + Vector3(0, -0.1, 0), Vector3(8, 0.2, 8))
	_box(viewport, "Masonry" if divider else "Furniture", origin + Vector3(0, 0.8, 0),
		Vector3(1, 1.6, 7 if divider else 2))
	var nav := ResidentNav.new()
	viewport.add_child(nav)
	var graph := AStar3D.new()
	var points: Array = []
	var originals := [Vector3(-2, 0, -0.2), Vector3(-2, 0, 0.2),
		Vector3(2, 0, -0.2), Vector3(2, 0, 0.2)]
	for i in originals.size():
		var at: Vector3 = origin + originals[i]
		graph.add_point(i, at)
		points.append({"id": i, "at": Vector2(at.x, -at.z), "tag": "fixture_room_node"})
	graph.connect_points(0, 1)
	graph.connect_points(2, 3)
	graph.connect_points(1, 2) # The real collider must cut this original edge.
	var rect := [origin.x - 3, -origin.z - 3, origin.x + 3, -origin.z + 3]
	var entry := {"astar": graph, "z": origin.y, "points": points, "walls": [],
		"rooms": [{"id": "ROOM", "kind": "living", "rect": rect}],
		"slabs": [{"rect": rect, "z_top": origin.y, "holes": []}]}
	if divider:
		entry.walls = [{"a": [origin.x, -origin.z - 3.5],
			"b": [origin.x, -origin.z + 3.5], "t": 1.0, "openings": []}]
	nav.floors = {"FIXTURE": entry}
	nav.level_order = ["FIXTURE"]
	await get_tree().physics_frame
	await get_tree().physics_frame
	var began := Time.get_ticks_usec()
	nav.validate_with_collision(viewport.find_world_3d())
	var elapsed := Time.get_ticks_usec() - began
	var detour_nodes := int(nav.get("collision_detour_nodes")) if nav.has_method("_repair_split_rooms") else 0
	var detour_edges := int(nav.get("collision_detour_edges")) if nav.has_method("_repair_split_rooms") else 0
	var label := ("masonry" if divider else "furniture") + " at " + str(origin)
	_check(label + " old blocked edge remains cut", not graph.are_points_connected(1, 2))
	var all_originals_have_neighbours := true
	for i in 4:
		all_originals_have_neighbours = all_originals_have_neighbours and not graph.get_point_connections(i).is_empty()
	_check(label + " originals were not single-node islands", all_originals_have_neighbours and nav.collision_relinked == 0)
	if divider:
		_check(label + " no route crosses complete masonry", graph.get_id_path(0, 3).is_empty())
		_check(label + " failed candidates do not proliferate graph", graph.get_point_count() == 4
			and detour_nodes == 0 and detour_edges == 0)
	else:
		_check(label + " split room has actual detour", not graph.get_id_path(0, 3).is_empty()
			and detour_nodes > 0 and detour_edges > 0)
		_check(label + " candidate budget is eight per room", graph.get_point_count() > 4 and graph.get_point_count() <= 12)
		var independently_clear := true
		for id in entry.get("detour_ids", {}):
			for other in graph.get_point_connections(id):
				if not _sweep(viewport, graph.get_point_position(id), graph.get_point_position(other)):
					independently_clear = false
		_check(label + " all added links independently clear conservative body", independently_clear)
		var count_before := graph.get_point_count()
		nav.validate_with_collision(viewport.find_world_3d())
		_check(label + " repeated validation adds no duplicates", graph.get_point_count() == count_before
			and (not nav.has_method("_repair_split_rooms") or int(nav.get("collision_detour_nodes")) == 0))
		# Ray-clear centreline beside a real obstacle is insufficient for a body.
		var a := origin + Vector3(-2, 0.03, 1.2)
		var b := origin + Vector3(2, 0.03, 1.2)
		_check(label + " nearby body-width collision remains refused",
			not nav._ray_blocked(viewport.find_world_3d().direct_space_state, a, b)
			and not _sweep(viewport, a - Vector3.UP * 0.03, b - Vector3.UP * 0.03)
			and (not nav.has_method("_room_link_clear") or not bool(nav.call("_room_link_clear", entry, viewport.find_world_3d().direct_space_state, a, b))))
		# Added nodes cannot be attached from the other side of the furniture
		# merely because the authored room's wall model permits that segment.
		_check(label + " endpoint attachment respects intervening furniture",
			not _sweep(viewport, origin + Vector3(-2, 0, 0), origin + Vector3(2, 0, 0))
			and (not nav.has_method("_detour_endpoint_clear") or not bool(nav.call("_detour_endpoint_clear", entry, origin + Vector3(-2, 0.03, 0), origin + Vector3(2, 0, 0)))))
		# On repeat validation a new ray-clear side obstruction must cut an
		# existing detour link; zero-neighbour repair cannot re-admit it by ray.
		var detour_ids: Dictionary = entry.get("detour_ids", {})
		if not detour_ids.is_empty():
			var first := int(detour_ids.keys()[0])
			var other := int(graph.get_point_connections(first)[0])
			var p := graph.get_point_position(first)
			var q := graph.get_point_position(other)
			var along := (q - p).normalized()
			var side := Vector3(-along.z, 0, along.x)
			_box(viewport, "LaterSideObstacle", p.lerp(q, 0.5) + side * 0.28 + Vector3.UP * 0.8, Vector3(0.04, 0.08, 0.04))
			await get_tree().physics_frame
			await get_tree().physics_frame
			_check(label + " later obstruction leaves centre rays clear", not nav._ray_blocked(viewport.find_world_3d().direct_space_state, p, q))
			nav.validate_with_collision(viewport.find_world_3d())
			_check(label + " repeat validation preserves full-body refusal", not graph.are_points_connected(first, other))
	measurements.append({"origin": [origin.x, origin.y, origin.z], "divider": divider,
		"validation_usec": elapsed, "original_nodes": 4, "final_nodes": graph.get_point_count(),
		"candidate_budget_per_room": 8})
	var retired: WeakRef = weakref(viewport.find_world_3d())
	viewport.queue_free()
	viewport = null
	nav = null
	for _i in 4: await get_tree().process_frame
	_check(label + " private world retires", retired.get_ref() == null)


func _finish_support_cases(origin: Vector3) -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(64, 64)
	add_child(viewport)
	var nav := ResidentNav.new()
	viewport.add_child(nav)
	var rect := [origin.x - 3, -origin.z - 3, origin.x + 3, -origin.z + 3]
	nav.build({"floors": [{"id": "FINISH", "z": origin.y,
		"rooms": [{"id": "FINISHED_ROOM", "kind": "living", "rect": rect}],
		"walls": [], "markers": [], "slabs": [{"rect": rect, "z_top": origin.y, "holes": []}]}]})
	var entry: Dictionary = nav.floors.FINISH
	var a := origin + Vector3(-0.5, 0.03, 0)
	var b := origin + Vector3(0.5, 0.03, 0)
	var datum_a := a - Vector3.UP * 0.03
	var datum_b := b - Vector3.UP * 0.03
	var label := "finished floor at " + str(origin)
	for top in [0.017, 0.021, 0.05, -0.025]:
		var holder := Node3D.new()
		viewport.add_child(holder)
		_box(holder, "PhysicalFloor", origin + Vector3(0, float(top) - 0.1, 0), Vector3(8, 0.2, 8))
		await get_tree().physics_frame
		await get_tree().physics_frame
		nav.validate_with_collision(viewport.find_world_3d())
		var admitted := nav.has_method("_room_link_clear") and bool(nav.call("_room_link_clear", entry,
			viewport.find_world_3d().direct_space_state, a, b))
		if float(top) > 0.0 and float(top) < 0.03:
			_check(label + " thin finish independently clears full body " + str(top), _sweep(viewport, datum_a, datum_b))
			_check(label + " below-foot finish admits detour " + str(top), admitted)
			_check(label + " direct-route datum policy stays unchanged " + str(top), not nav._direct_segment_clear(entry, a, b))
		elif float(top) > 0.03:
			_check(label + " above-foot step remains body-blocked", not _sweep(viewport, datum_a, datum_b) and not admitted)
		else:
			_check(label + " below-datum support remains refused", _sweep(viewport, datum_a, datum_b) and not admitted)
		holder.queue_free()
		holder = null
		await get_tree().physics_frame
		await get_tree().physics_frame
	var support := Node3D.new()
	viewport.add_child(support)
	_box(support, "FinishForPlanControls", origin + Vector3(0, 0.017 - 0.1, 0), Vector3(8, 0.2, 8))
	await get_tree().physics_frame
	await get_tree().physics_frame
	entry.slabs[0].holes = [[origin.x - 0.02, -origin.z - 0.02, origin.x + 0.02, -origin.z + 0.02]]
	_check(label + " finish cannot fill authored hole", not _room_admits(nav, entry, viewport, a, b))
	entry.slabs[0].holes = []
	_check(label + " authored outer rim still blocks body footprint", not _room_admits(nav, entry, viewport,
		origin + Vector3(2, 0.03, 0), origin + Vector3(2.8, 0.03, 0)))
	support.queue_free()
	support = null
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(label + " absent physical support remains refused", not _room_admits(nav, entry, viewport, a, b))
	# The authored slab remains continuous while actual collision has a 10cm
	# gap under the route. An elevated finish cannot waive sampled support.
	_box(viewport, "FinishBeforeGap", origin + Vector3(-1.93, 0.017 - 0.1, 0), Vector3(4, 0.2, 8))
	_box(viewport, "FinishAfterGap", origin + Vector3(2.13, 0.017 - 0.1, 0), Vector3(4, 0.2, 8))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(label + " physical gap under finish remains refused", not _room_admits(nav, entry, viewport, a, b))
	viewport.queue_free()
	viewport = null
	nav = null
	for _i in 4: await get_tree().process_frame


func _room_admits(nav: ResidentNav, entry: Dictionary, viewport: SubViewport,
		from: Vector3, to: Vector3) -> bool:
	return nav.has_method("_room_link_clear") and bool(nav.call("_room_link_clear", entry,
		viewport.find_world_3d().direct_space_state, from, to))


func _portal_body_cases(origin: Vector3) -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(64, 64)
	add_child(viewport)
	_box(viewport, "PortalSupport", origin + Vector3(0, -0.1, 0), Vector3(8, 0.2, 8))
	var door := DoorProp.new()
	door.name = "FixtureManagedDoor"
	door.position = origin + Vector3(-0.405, 0, 0)
	viewport.add_child(door)
	var nav := ResidentNav.new()
	viewport.add_child(nav)
	var graph := AStar3D.new()
	var points: Array = []
	for i in 3:
		var at := origin + Vector3(0, 0, float(i - 1))
		graph.add_point(i, at)
		points.append({"id": i, "at": Vector2(at.x, -at.z),
			"tag": "door:fixture" if i == 1 else "fixture_room_node"})
	graph.connect_points(0, 1)
	graph.connect_points(1, 2)
	var rect := [origin.x - 3, -origin.z - 3, origin.x + 3, -origin.z + 3]
	var entry := {"astar": graph, "z": origin.y, "points": points,
		"rooms": [{"id": "PORTAL_ROOM", "kind": "living", "rect": rect}],
		"slabs": [{"rect": rect, "z_top": origin.y, "holes": []}],
		"walls": [{"a": [origin.x - 3, -origin.z], "b": [origin.x + 3, -origin.z],
			"t": 0.12, "openings": [{"type": "door", "at": 3.0, "w": 0.81, "leaf": "closed"}]}]}
	nav.floors = {"PORTAL": entry}
	nav.level_order = ["PORTAL"]
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav.validate_with_collision(viewport.find_world_3d())
	var a := origin + Vector3(0, 0.03, -1)
	var b := origin + Vector3(0, 0.03, 1)
	var label := "portal body at " + str(origin)
	_check(label + " real closed leaf is an actual collision", not _sweep(viewport, a - Vector3.UP * 0.03, b - Vector3.UP * 0.03))
	_check(label + " managed leaf retains original portal ownership", graph.are_points_connected(0, 1) and graph.are_points_connected(1, 2))
	_check(label + " conservative new detour does not waive closed leaf", not _room_admits(nav, entry, viewport, a, b))
	var fixed_holder := Node3D.new()
	door._fixed.add_child(fixed_holder)
	# Off-centre and between the old shin/chest rays, but in the actual Body.
	_box(fixed_holder, "FixedJambControl", Vector3(0.405 + 0.24, 0.8, 0), Vector3(0.04, 0.08, 0.04))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(label + " fixed-jamb control escapes legacy rays", not nav._ray_blocked(viewport.find_world_3d().direct_space_state, a, b))
	nav.validate_with_collision(viewport.find_world_3d())
	_check(label + " fixed frame under DoorProp is not a leaf exception", not graph.are_points_connected(0, 1) and not graph.are_points_connected(1, 2))
	fixed_holder.queue_free()
	fixed_holder = null
	var panel_holder := Node3D.new()
	viewport.add_child(panel_holder)
	_box(panel_holder, "UnmanagedLiftPanel", origin + Vector3(0, 1, 0), Vector3(1.2, 2, 0.06))
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav.validate_with_collision(viewport.find_world_3d())
	var portal_admitted := false
	for candidate: Dictionary in nav._visible_candidates(entry, b):
		if int(candidate.id) == 1: portal_admitted = true
	_check(label + " closed unmanaged panel cannot become an endpoint", not portal_admitted)
	viewport.remove_child(nav)
	add_child(nav)
	_check(label + " body endpoint proof cannot cross World3D ownership",
		(not nav.has_method("_resident_endpoint_clear") or not bool(nav.call("_resident_endpoint_clear", entry, b, origin)))
		and (not nav.has_method("_index_managed_leaves") or nav.get("_managed_leaf_rids").is_empty()))
	nav.queue_free()
	nav = null
	door = null
	panel_holder = null
	viewport.queue_free()
	viewport = null
	for _i in 4: await get_tree().process_frame


func _sweep(viewport: SubViewport, from: Vector3, to: Vector3) -> bool:
	# Independent fixture dimensions, not ResidentNav's admission helper.
	var shape := CapsuleShape3D.new()
	shape.radius = 0.33
	shape.height = 1.65
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.margin = 0.001
	query.collide_with_areas = false
	query.transform = Transform3D(Basis(), from + Vector3.UP * (0.03 + 1.65 / 2))
	var space := viewport.find_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	query.transform.origin = to + Vector3.UP * (0.03 + 1.65 / 2)
	if not space.intersect_shape(query, 1).is_empty(): return false
	query.transform.origin = from + Vector3.UP * (0.03 + 1.65 / 2)
	query.motion = to - from
	var fractions := space.cast_motion(query)
	return fractions.size() == 2 and fractions[0] >= 1.0 and fractions[1] >= 1.0


func _box(parent: Node, label: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	parent.add_child(body)


func _check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed: failures += 1
	print("[RESIDENT ROOM DETOUR] %s %s" % ["PASS" if passed else "FAIL", label])
