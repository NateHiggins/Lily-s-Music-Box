extends Node3D
## Prepared actual V1 regression. No timing, visual, or whole-day acceptance.
## The external runner owns native diagnostics after this scene has retired.

var world: Node3D
var checks: Array = []
var evidence := {}
var output := ""
var failures := 0


func _ready() -> void:
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("ResidentLiftWaitingTest requires a writable fresh SHOT_DIR")
		get_tree().quit(2)
		return
	CampaignTime.set_frozen_for_tests(true)
	OS.set_environment("SCHEDULE", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE}
	_check("authored campaign time configured", CampaignClock.new().configure_date(1928, 11, 10, 180.0))
	world = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(world)
	var routines: ResidentRoutines = world.resident_routines
	_check("real V1 routines and navigation exist", routines != null and routines.nav != null)
	if routines == null or routines.nav == null:
		await _finish()
		return
	# Hold autonomous choices, not the navigation collision pass or elevator.
	# Every route, movement step and request below uses the actual production API.
	routines.inspection_hold = true
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	evidence["before_collision_graph"] = _graph(routines.nav, "F04")
	await get_tree().create_timer(1.6).timeout
	await get_tree().physics_frame
	await get_tree().physics_frame
	evidence["after_collision_graph"] = _graph(routines.nav, "F04")
	evidence["collision_audit"] = {"cut": routines.nav.collision_cut,
		"relinked": routines.nav.collision_relinked, "stairs_blocked": routines.nav.stair_blocked,
		"readiness": "production two-physics-frame validator, then 1.6 seconds and two further physics frames"}
	await _run(routines)
	# Locals retaining the actual routines are gone before root retirement.
	routines = null
	await _finish()


func _run(routines: ResidentRoutines) -> void:
	var nav: ResidentNav = routines.nav
	var actor: Dictionary = {}
	for row in routines.actors:
		if str(row.slug) == "transient_guests":
			actor = row
			break
	_check("actual 4D Transient Guests owner exists", not actor.is_empty())
	if actor.is_empty(): return
	var node: Node3D = actor.node
	var home: Vector3 = actor.home
	_check("actual untouched 4D spawn is the recorded failure origin",
		home.distance_to(Vector3(9.7428, 9.63, 3.205)) < 0.001 and node.global_position.distance_to(home) < 0.001)
	var shaft: Array = world.layout.elevator.shaft
	var wait_at: Vector3 = routines._lift_point(home.y)
	var south_face := -minf(float(shaft[1]), float(shaft[3]))
	var center_x := (float(shaft[0]) + float(shaft[2])) * 0.5
	evidence["coordinates"] = {"shaft_blender_xy": shaft, "home_godot": _v(home), "wait_godot": _v(wait_at),
		"public_door_face_godot_z": south_face, "candidate_clearance": wait_at.z - south_face,
		"old_target_godot": [1.9, home.y, 5.6]}
	_check("waiting point preserves authored shaft center and current storey",
		absf(wait_at.x - center_x) < 0.001 and absf(wait_at.y - home.y) < 0.001)
	_check("waiting point is on public side with resident body and wall clearance", wait_at.z - south_face >= 0.62)
	var moved := ResidentRoutines.new()
	moved._layout = {"elevator": {"shaft": [10.0, -20.0, 14.0, -16.0]}}
	_check("waiting point follows a different authored shaft instead of a copied location",
		moved._lift_point(4.0).distance_to(Vector3(12.0, 4.0, 20.65)) < 0.001)
	moved.free()
	var lift: OrisonElevator = routines.elevator
	_check("real lift begins at F01 with F04 closed", lift != null and lift.current == "F01"
		and lift.is_ready_at("F01") and not lift.is_ready_at("F04") and lift.landing_door_open_fraction("F04") < 0.01)
	if lift == null: return
	evidence["endpoint_diagnostics"] = {
		"old": _endpoints(nav, home, Vector3(1.9, home.y, 5.6)),
		"actual": _endpoints(nav, home, wait_at)}
	evidence["removed_edge_obstructions"] = _removed_edges(nav)
	# The same unchanged assertions run against old and proposed _lift_point.
	var outbound: PackedVector3Array = nav.route(home, wait_at)
	var returning: PackedVector3Array = nav.route(wait_at, home)
	evidence["outbound"] = _path(outbound)
	evidence["returning"] = _path(returning)
	var outbound_complete := outbound.size() > 1 and outbound[-1].distance_to(wait_at) < 0.001
	var return_complete := returning.size() > 1 and returning[-1].distance_to(home) < 0.001
	_check("4D outbound route reaches public waiting point", outbound_complete)
	_check("return route reaches the actual 4D home", return_complete)
	_check("outbound route passes unchanged production wall and collider checks", outbound_complete and _clear(nav, outbound))
	_check("return route passes unchanged production wall and collider checks", return_complete and _clear(nav, returning))
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.33
	capsule.height = 1.524
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = capsule
	shape_query.transform = Transform3D(Basis(), wait_at + Vector3(0, 0.80, 0))
	shape_query.collide_with_areas = false
	var overlaps := world.get_world_3d().direct_space_state.intersect_shape(shape_query)
	evidence["waiting_body_overlaps"] = []
	for hit in overlaps:
		evidence.waiting_body_overlaps.append(str(hit.collider.get_path()))
	_check("resident capsule fits on the public landing", overlaps.is_empty())
	# Pick a repeatable elevator choice without changing authored temperament.
	var probe := RandomNumberGenerator.new()
	var seed_found := false
	for choice in 32:
		probe.seed = choice
		if probe.randf() > 0.5:
			routines._rng.seed = choice
			evidence["routine_rng_seed"] = choice
			seed_found = true
			break
	_check("deterministic normal elevator choice available", seed_found)
	if not seed_found: return
	routines._begin_trip(actor, false)
	_check("normal departure chooses actual elevator stage", actor.vertical_mode == "elevator" and actor.stage == ResidentRoutines.Stage.TO_LIFT)
	var lift_state_before: int = lift.state
	routines._step(actor, 0.0)
	_check("resident at home neither requests lift nor boards prematurely", lift.state == lift_state_before
		and actor.stage == ResidentRoutines.Stage.TO_LIFT and node.visible and node.global_position.distance_to(home) < 0.001)
	# A known blocked graph must remain an honest failed test. Do not simulate
	# arrival, teleport the actor, or proceed into boarding to hide it.
	if not outbound_complete or not return_complete or not _clear(nav, outbound): return
	var arrived := false
	for _i in 6000:
		if routines._follow(actor, node, 1.0 / 60.0):
			arrived = true
			break
	_check("production movement reaches the waiting point", arrived and node.global_position.distance_to(wait_at) < 0.17)
	if not arrived: return
	routines._step(actor, 0.0)
	_check("closed remote landing requests lift while resident stays visible", actor.stage == ResidentRoutines.Stage.TO_LIFT
		and node.visible and not lift.is_ready_at("F04") and lift.state != OrisonElevator.S.IDLE)
	routines._step(actor, 0.0)
	_check("a second wait step cannot board before arrival", actor.stage == ResidentRoutines.Stage.TO_LIFT and node.visible)
	var began := Time.get_ticks_msec()
	while not lift.is_ready_at("F04") and Time.get_ticks_msec() - began < 16000:
		await get_tree().physics_frame
	_check("actual cabin arrives and opens at F04", lift.is_ready_at("F04"))
	if lift.is_ready_at("F04"):
		routines._step(actor, 0.0)
		_check("only ready source landing admits boarding and departure", actor.stage == ResidentRoutines.Stage.RIDING
			and not node.visible and lift.state != OrisonElevator.S.IDLE)
	_check("normal routes recorded no unreachable events", nav.unreachable_route_count() == 0)


func _graph(nav: ResidentNav, fid: String) -> Array:
	var rows: Array = []
	var entry: Dictionary = nav.floors[fid]
	var graph: AStar3D = entry.astar
	for point in entry.points:
		rows.append({"id": point.id, "tag": point.tag, "at": _v(graph.get_point_position(point.id)),
			"connections": Array(graph.get_point_connections(point.id))})
	return rows


func _endpoints(nav: ResidentNav, from: Vector3, to: Vector3) -> Dictionary:
	var entry: Dictionary = nav.floors.F04
	var starts: Array = nav._visible_candidates(entry, from)
	var goals: Array = nav._visible_candidates(entry, to)
	var pair: Vector2i = nav._connected_visible_pair(entry, from, to)
	return {"from": _v(from), "to": _v(to), "starts": starts, "goals": goals, "pair": [pair.x, pair.y]}


func _removed_edges(nav: ResidentNav) -> Array:
	var out: Array = []
	var graph: AStar3D = nav.floors.F04.astar
	for row in evidence.before_collision_graph:
		for other in row.connections:
			if int(other) <= int(row.id) or graph.are_points_connected(int(row.id), int(other)): continue
			var a := graph.get_point_position(int(row.id))
			var b := graph.get_point_position(int(other))
			out.append({"a": row.id, "b": other, "from": _v(a), "to": _v(b), "blocking_hits": _hits(a, b)})
	return out


func _hits(a: Vector3, b: Vector3) -> Array:
	var hits: Array = []
	for h in [0.35, 1.15]:
		var target := b + Vector3(0, h, 0)
		var origin := a + Vector3(0, h, 0)
		for _i in 8:
			var query := PhysicsRayQueryParameters3D.create(origin, target)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): break
			var owner: Node = hit.collider.get_parent() if hit.collider is Node else null
			var excused: bool = hit.collider is DoorProp or owner is DoorProp or (owner != null and owner.get_parent() is DoorProp)
			hits.append({"height": h, "collider": str(hit.collider.get_path()), "at": _v(hit.position), "door_excused": excused})
			if not excused: break
			origin = hit.position + (target - origin).normalized() * 0.06
	return hits


func _clear(nav: ResidentNav, path: PackedVector3Array) -> bool:
	for i in range(path.size() - 1):
		if not nav._segment_clear(nav.floors.F04, path[i], path[i + 1]) or nav._ray_blocked(world.get_world_3d().direct_space_state, path[i], path[i + 1]):
			return false
	return true


func _v(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _path(path: PackedVector3Array) -> Array:
	var result: Array = []
	for point in path: result.append(_v(point))
	return result


func _check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed: failures += 1
	print("[RESIDENT LIFT WAIT] %s %s" % ["PASS" if passed else "FAIL", label])


func _finish() -> void:
	var retired: WeakRef = weakref(world)
	if is_instance_valid(world): world.queue_free()
	world = null
	for _i in 4: await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	_check("actual V1 root retired", retired.get_ref() == null)
	evidence["checks"] = checks
	evidence["failures"] = failures
	evidence["scope"] = "Actual 4D outbound/return navigation, public waiting body clearance and real elevator source readiness; movement advanced through production _follow at fixed1/60 without claiming elapsed travel time. No full haunt arrival or gameplay acceptance."
	var file := FileAccess.open(output.path_join("resident_lift_waiting.json"), FileAccess.WRITE)
	if file == null:
		push_error("Resident lift waiting receipt could not be written")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	print("[RESIDENT LIFT WAIT] RESULT %d passed, %d failed" % [checks.size() - failures, failures])
	get_tree().quit(0 if failures == 0 else 1)
