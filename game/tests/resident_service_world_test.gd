extends Node3D
## One actual Juno outbound trip through the authored F03 utility service leaf.
## Default: untouched 2C home, normal seeded lift intent, real arrival and haunt.
## Optional SERVICE_WORLD_SCOPE=adjacent: an explicitly bounded suffix of the
## same admitted landing-to-haunt route; no claim about the skipped home/lift leg.
## Neither mode changes navigation, targets, colliders, door state or animation.

const SLUG := "juno_kells"
const FLOOR := "F03"
const DOOR_ID := "F03_DOOR_01"
const ROOM_ID := "F03_UTILITY"

var world: Node3D
var output := ""
var failures := 0
var checks: Array = []
var evidence := {"schema": "orison.resident-service-world-test.v1", "transitions": [], "door_events": []}


func _ready() -> void:
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("ResidentServiceWorldTest requires fresh writable SHOT_DIR")
		get_tree().quit(2)
		return
	CampaignTime.set_frozen_for_tests(true)
	OS.set_environment("SCHEDULE", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE}
	_check("authored campaign clock is valid", CampaignClock.new().configure_date(1928, 11, 10, 180.0))
	world = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(world)
	var routines: ResidentRoutines = world.resident_routines
	_check("actual legacy routines navigation and elevator exist", routines != null and routines.nav != null and routines.elevator != null)
	if routines == null or routines.nav == null or routines.elevator == null:
		await _finish()
		return
	routines.inspection_hold = true
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	await get_tree().create_timer(1.6).timeout
	await get_tree().physics_frame
	await get_tree().physics_frame
	evidence["settle_scope"] = "Inherited 1.6 seconds and two physics frames after build; no complete-builder-ready claim"
	evidence["runtime_source_sha256"] = _source_hashes()
	evidence["hash_normalization"] = "UTF-8 text with CRLF and CR normalized to LF"
	await _run(routines)
	routines = null
	await _finish()


func _run(routines: ResidentRoutines) -> void:
	var actor: Dictionary = {}
	for row: Dictionary in routines.actors:
		if str(row.slug) == SLUG:
			actor = row
			break
	_check("actual Juno Kells owner is available", not actor.is_empty())
	if actor.is_empty(): return
	var node: Node3D = actor.node
	var home: Vector3 = actor.home
	var haunt: Vector3 = actor.haunt
	var door := world.find_child(DOOR_ID, true, false) as DoorProp
	var body := node.get_node_or_null("Body") as StaticBody3D
	var shape: CollisionShape3D
	if body != null:
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is CapsuleShape3D:
				shape = child
				break
	_check("actual resident Body capsule and authored service DoorProp exist", shape != null and door != null)
	if shape == null or door == null: return
	var capsule := shape.shape as CapsuleShape3D
	var relative := node.global_transform.affine_inverse() * shape.global_transform
	var authored: Dictionary = {}
	var room: Dictionary = {}
	for floor_data: Dictionary in world.layout.floors:
		if str(floor_data.id) != FLOOR: continue
		for marker: Dictionary in floor_data.markers:
			if str(marker.id) == DOOR_ID: authored = marker
		for record: Dictionary in floor_data.rooms:
			if str(record.id) == ROOM_ID: room = record
	_check("actual owner starts at untouched 2C home and unchanged authored F03 haunt",
		str(actor.unit) == "2C" and routines.nav.floor_at(home.y) == "F02"
		and node.global_position.distance_to(home) < 0.001
		and haunt == routines._haunt_point(SLUG) and haunt.distance_to(Vector3(0, 6.43, -5)) < 0.001)
	_check("actual target is the authored closed non-home service leaf", not authored.is_empty()
		and str(authored.get("leaf", "")) == "closed" and str(authored.get("subtype", "")) == "service"
		and ROOM_ID in authored.get("rooms", []) and door != actor.home_door
		and door.door_kind == "service" and door.leaf_state == "closed" and not door.open and not door._moving
		and door.global_position.distance_to(GameBoot.b2g(authored.get("pos", [0, 0, 0]))) < 0.001)
	_check("actual Body remains unchanged and queries have zero collider exclusions",
		is_equal_approx(capsule.radius, 0.28) and is_equal_approx(capsule.height, 1.55)
		and relative.origin.distance_to(Vector3(0, 0.775, 0)) < 0.001 and body.collision_layer == 0)
	evidence["owner"] = {"slug": SLUG, "unit": actor.unit, "home": _v(home), "haunt": _v(haunt),
		"home_door": str(actor.home_door.get_path()) if is_instance_valid(actor.home_door) else "missing"}
	evidence["actual_body"] = {"path": str(shape.get_path()), "radius": capsule.radius, "height": capsule.height,
		"relative_center": _v(relative.origin), "layer": body.collision_layer, "mask": body.collision_mask,
		"query_collider_exclusions": 0, "query_mask": 4294967295}
	evidence["authored_service_marker"] = authored
	evidence["authored_utility_room"] = room
	if failures > 0: return

	# This is exactly the destination-floor route requested by RIDING on arrival.
	# Record and refuse an empty/unreachable result; never invent a nearby target.
	var landing := routines._lift_point(haunt.y)
	var public_path: PackedVector3Array = routines.nav.route(landing, haunt)
	var entry: Dictionary = routines.nav.floors[FLOOR]
	var pair := routines.nav._connected_visible_pair(entry, landing, haunt)
	evidence["public_route"] = {"from": _v(landing), "to": _v(haunt), "path": _path(public_path),
		"unreachable_keys": routines.nav.unreachable_route_keys(), "connected_pair": [pair.x, pair.y],
		"visible_start_candidates": routines.nav._visible_candidates(entry, landing),
		"visible_goal_candidates": routines.nav._visible_candidates(entry, haunt),
		"landing_body": _sweep(shape.shape, Transform3D(Basis(), landing) * relative,
			Transform3D(Basis(), landing) * relative),
		"haunt_body": _sweep(shape.shape, Transform3D(Basis(), haunt) * relative,
			Transform3D(Basis(), haunt) * relative)}
	var admitted := public_path.size() > 1 and public_path[-1].distance_to(haunt) < 0.001
	_check("unchanged production navigation admits the real F03 landing-to-haunt route", admitted)
	if not admitted:
		evidence["stopped"] = "Production navigation refused the authored destination; no replacement target, path or movement was installed"
		return
	var crossing := _crossing(public_path, door)
	_check("admitted real route passes through the actual service aperture", not crossing.is_empty())
	if crossing.is_empty(): return
	evidence["service_crossing"] = crossing
	var index := int(crossing.segment)
	var from := Vector3(public_path[index].x, haunt.y, public_path[index].z)
	var to := Vector3(public_path[index + 1].x, haunt.y, public_path[index + 1].z)
	var closed_control := _sweep(shape.shape, Transform3D(Basis(), from) * relative,
		Transform3D(Basis(), to) * relative)
	evidence["closed_leaf_negative_control"] = closed_control
	_check("the actual closed leaf blocks the admitted crossing with no exclusions",
		not bool(closed_control.clear) and str(door._body.get_path()) in closed_control.colliders)
	if failures > 0: return

	var adjacent := OS.get_environment("SERVICE_WORLD_SCOPE") == "adjacent"
	evidence["mode"] = "adjacent" if adjacent else "outbound"
	if adjacent:
		# Explicit diagnostic mode only. All installed points are an unchanged
		# contiguous suffix of the real production route, including its target.
		# Include a preceding waypoint when possible to start outside leaf sweep.
		var start_index := maxi(0, index - 1)
		var suffix := public_path.slice(start_index)
		var start := Vector3(suffix[0].x, haunt.y, suffix[0].z)
		var start_probe := _sweep(shape.shape, Transform3D(Basis(), start) * relative,
			Transform3D(Basis(), start) * relative)
		evidence["adjacent_start"] = {"source_route_index": start_index, "path": _path(suffix),
			"position": _v(start), "body": start_probe}
		_check("the bounded suffix starts clear of every real collider", bool(start_probe.clear))
		if not bool(start_probe.clear): return
		node.global_position = start
		actor.path = suffix
		actor.leg = 0
		actor.stage = ResidentRoutines.Stage.AT_HAUNT
		actor.timer = float(ResidentRoutines.TEMPERAMENTS[SLUG].dwell[0])
		routines._keep_floor_parent(actor)
		evidence["scope"] = "Explicit door-adjacent suffix of the real F03 public arrival route to Juno's unchanged authored haunt. Fixture starts the actual owner at one existing route waypoint in AT_HAUNT. No home departure, lift ride, full autonomy or lifecycle acceptance."
	else:
		var rng := RandomNumberGenerator.new()
		var choice := -1
		for candidate in 4096:
			rng.seed = candidate
			if rng.randf() > 0.99:
				choice = candidate
				break
		_check("deterministic normal elevator intent seed exists", choice >= 0)
		if choice < 0: return
		routines._rng.seed = choice
		routines._begin_trip(actor, false)
		evidence["departure"] = {"seed": choice, "stage": actor.stage, "vertical_mode": actor.vertical_mode,
			"path": _path(actor.path), "unreachable_keys": routines.nav.unreachable_route_keys()}
		var departure_admitted: bool = actor.stage == ResidentRoutines.Stage.TO_LIFT and actor.vertical_mode == "elevator" \
			and actor.path.size() > 1 and actor.path[-1].distance_to(routines._lift_point(home.y)) < 0.001
		_check("normal outbound intent admits the untouched home-to-lift route", departure_admitted)
		if not departure_admitted:
			evidence["stopped"] = "Normal home departure was refused; no automatic adjacent fallback or lifecycle claim"
			return
		evidence["scope"] = "One real Juno outbound home/lift/authored-haunt trip and actual F03 service-leaf close. Other choices/player held, campaign clock frozen. Every visible walking frame queries the actual Body with zero collider exclusions. No return, all-resident, performance or runtime_contract admission."
	await _replay(routines, actor, door, shape, float(crossing.source_sign))


func _replay(routines: ResidentRoutines, actor: Dictionary, door: DoorProp,
		shape: CollisionShape3D, source_sign: float) -> void:
	var node: Node3D = actor.node
	var radius: float = shape.shape.radius
	var began := Time.get_ticks_msec()
	var opened_by_owner := false
	var closed_by_owner := false
	var moving_wait_frames := 0
	var crossed := false
	var arrived := false
	var movement_clear := true
	var readiness_clear := true
	var close_clear := true
	var frames := 0
	while Time.get_ticks_msec() - began < 120000:
		await get_tree().physics_frame
		var before := node.global_position
		var before_transform := shape.global_transform
		var was_visible := node.visible
		var was_open := door.open
		var was_moving := door._moving
		var ready_before := door.is_ready_for_passage()
		var stage_before: int = actor.stage
		# Includes stationary frames: a moving leaf may not hit a waiting body.
		if was_visible:
			var stationary := _sweep(shape.shape, before_transform, before_transform)
			if not bool(stationary.clear):
				evidence["movement_block"] = {"phase": "before_step", "at": _v(before), "probe": stationary,
					"door": _door_state(door), "stage": actor.stage, "leg": actor.leg}
				movement_clear = false
				break
		routines._step(actor, get_physics_process_delta_time())
		routines._keep_floor_parent(actor)
		frames += 1
		var after := node.global_position
		if stage_before != int(actor.stage) or was_visible != bool(node.visible):
			evidence.transitions.append({"from": stage_before, "to": actor.stage, "visible": node.visible,
				"at": _v(after), "elapsed_ms": Time.get_ticks_msec() - began})
		if not was_open and door.open:
			opened_by_owner = true
			evidence.door_events.append({"event": "open_accepted_during_step", "at": _v(after),
				"door": _door_state(door), "elapsed_ms": Time.get_ticks_msec() - began})
		if was_open and not door.open:
			closed_by_owner = true
			var far_side := door.to_local(after).z * source_sign < -(radius + 0.05)
			close_clear = close_clear and far_side and crossed
			evidence.door_events.append({"event": "close_accepted_during_step", "at": _v(after),
				"far_side_body_clear": far_side, "crossed_before_close": crossed,
				"door": _door_state(door), "elapsed_ms": Time.get_ticks_msec() - began})
		if was_visible and node.visible:
			var swept := _sweep(shape.shape, before_transform, shape.global_transform)
			if not bool(swept.clear):
				evidence["movement_block"] = {"phase": "walking_step", "from": _v(before), "to": _v(after),
					"probe": swept, "door": _door_state(door), "stage": actor.stage, "leg": actor.leg}
				movement_clear = false
				break
			if routines.nav.floor_at(after.y) == FLOOR:
				var local_before := door.to_local(before)
				var local_after := door.to_local(after)
				var before_side := local_before.z * source_sign
				var after_side := local_after.z * source_sign
				var in_width := local_after.x >= -radius and local_after.x <= door.width + radius
				var moved := before.distance_to(after) > 0.000001
				# Early acquisition on a bent route intentionally holds before the
				# actor lines up with the aperture. Observe the actual door hold;
				# retain all independent movement and crossing capsule checks.
				if was_moving and not ready_before and not moved \
						and bool(actor.get("door_waiting", false)) \
						and after.distance_to(door.global_position) < 2.0:
					moving_wait_frames += 1
					if not evidence.has("first_opening_wait"):
						evidence["first_opening_wait"] = {"at": _v(after), "door": _door_state(door)}
				if moved and in_width and before_side >= -(radius + 0.05) \
						and after_side <= radius + 0.05:
					readiness_clear = readiness_clear and ready_before
				if in_width and before_side >= 0.0 and after_side < 0.0:
					crossed = true
					evidence["crossed_at"] = {"from": _v(before), "to": _v(after), "ready_before": ready_before,
						"elapsed_ms": Time.get_ticks_msec() - began}
		arrived = actor.stage == ResidentRoutines.Stage.AT_HAUNT and int(actor.leg) >= actor.path.size() \
			and node.global_position.distance_to(actor.haunt) < 0.17
		if arrived and closed_by_owner and not door.open and not door._moving: break
		if not readiness_clear or not close_clear: break
	evidence["replay"] = {"frames": frames, "elapsed_ms": Time.get_ticks_msec() - began,
		"arrived": arrived, "crossed": crossed, "opened_by_owner": opened_by_owner,
		"closed_by_owner": closed_by_owner, "moving_wait_frames": moving_wait_frames,
		"movement_clear": movement_clear, "readiness_clear": readiness_clear, "close_clear": close_clear,
		"position": _v(node.global_position), "stage": actor.stage, "leg": actor.leg, "door": _door_state(door),
		"unreachable_keys": routines.nav.unreachable_route_keys(), "collider_exclusions": 0}
	_check("actual resident owner opens the actual service leaf during its step", opened_by_owner)
	_check("resident visibly waits during the actual opening tween", moving_wait_frames > 0)
	_check("resident crosses only after the actual leaf is unlocked open and settled", crossed and readiness_clear)
	_check("every observed real Body overlap and walking sweep clears all colliders", movement_clear)
	_check("actual owner reaches its unchanged authored haunt", arrived)
	_check("actual owner closes only after its whole Body clears the far side", closed_by_owner and close_clear)
	_check("actual closing tween settles behind the resident", closed_by_owner and not door.open and not door._moving)
	_check("replay records no unreachable routes", routines.nav.unreachable_route_count() == 0)


func _crossing(path: PackedVector3Array, door: DoorProp) -> Dictionary:
	for i in range(path.size() - 1):
		var a := door.to_local(path[i])
		var b := door.to_local(path[i + 1])
		if absf(a.z - b.z) < 0.000001 or a.z * b.z > 0.0: continue
		var t := -a.z / (b.z - a.z)
		var at := a.lerp(b, t)
		if at.x < 0.0 or at.x > door.width: continue
		var source_sign := signf(a.z)
		if source_sign == 0.0: source_sign = -signf(b.z)
		return {"segment": i, "source_sign": source_sign, "local_at": _v(at),
			"world_at": _v(door.to_global(at)), "door_path": str(door.get_path())}
	return {}


func _sweep(shape: Shape3D, from: Transform3D, to: Transform3D) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = from
	query.margin = 0.001
	query.collide_with_areas = false
	query.collision_mask = 4294967295
	# query.exclude stays empty, including every moving leaf and fixed frame.
	var space := world.get_world_3d().direct_space_state
	var colliders: Array = []
	for hit in space.intersect_shape(query, 64): colliders.append(str(hit.collider.get_path()))
	query.transform = to
	for hit in space.intersect_shape(query, 64):
		var identity := str(hit.collider.get_path())
		if identity not in colliders: colliders.append(identity)
	query.transform = from
	query.motion = to.origin - from.origin
	var fractions := PackedFloat32Array([1.0, 1.0])
	if not query.motion.is_zero_approx():
		fractions = space.cast_motion(query)
		if fractions.size() == 2 and fractions[0] < 1.0:
			query.transform.origin += query.motion * minf(1.0, fractions[1] + 0.001)
			for hit in space.intersect_shape(query, 64):
				var identity := str(hit.collider.get_path())
				if identity not in colliders: colliders.append(identity)
	return {"clear": colliders.is_empty() and fractions.size() == 2 and fractions[0] >= 1.0 and fractions[1] >= 1.0,
		"colliders": colliders, "fractions": Array(fractions), "exclusions": 0}


func _door_state(door: DoorProp) -> Dictionary:
	return {"open": door.open, "moving": door._moving, "leaf_state": door.leaf_state,
		"ready": door.is_ready_for_passage(), "leaf_position": _v(door._body.global_position),
		"leaf_rotation": _v(door._body.global_rotation)}


func _source_hashes() -> Dictionary:
	var result := {}
	for path in ["res://scripts/characters/resident_route_doors.gd",
			"res://scripts/characters/resident_routines.gd",
			"res://scripts/characters/resident_nav.gd", "res://scripts/props/door_prop.gd",
			"res://scripts/building/building_root.gd", "res://data/building_layout.json",
			"res://tests/resident_service_world_test.gd", "res://tests/ResidentServiceWorldTest.tscn"]:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").replace("\r", "\n").sha256_text()
	return result


func _v(point: Vector3) -> Array:
	return [point.x, point.y, point.z]


func _path(points: PackedVector3Array) -> Array:
	var result: Array = []
	for point in points: result.append(_v(point))
	return result


func _check(label: String, ok: bool) -> void:
	checks.append({"label": label, "ok": ok})
	if not ok: failures += 1
	print("[RESIDENT SERVICE WORLD] %s %s" % ["PASS" if ok else "FAIL", label])


func _finish() -> void:
	var retired: WeakRef = weakref(world) if is_instance_valid(world) else null
	if is_instance_valid(world): world.queue_free()
	world = null
	for _i in 4: await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	_check("actual legacy root retired", retired == null or retired.get_ref() == null)
	evidence["checks"] = checks
	evidence["failures"] = failures
	evidence["evidence_class"] = "Scoped diagnostic; not a schema-2 runtime_contract receipt"
	var file := FileAccess.open(output.path_join("resident_service_world.json"), FileAccess.WRITE)
	if file == null:
		push_error("Resident service world evidence could not be written")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(evidence, "\t"))
	file.flush()
	var written := file.get_error() == OK
	file.close()
	if not written:
		push_error("Resident service world evidence could not be flushed")
		get_tree().quit(2)
		return
	print("[RESIDENT SERVICE WORLD] RESULT %d/%d" % [checks.size() - failures, checks.size()])
	get_tree().quit(0 if failures == 0 else 1)
