extends Node
## Three existing production route owners in the real V2 world. Exactly one
## declared initial placement per body; thereafter no transform writes, speed
## changes, simulated collisions, substitute actors or forced seat transitions.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Motor := preload("res://tests/orison_v2_first_slice_contract_test.gd")
const STARTS := {"juno_kells": "seat_counter_01", "evelyn_marsh": "gallery_rear", "lena_ortiz": "stair_approach"}
const REQUIRED := ["attendance_arrivals", "attendance_opposing_fifo", "attendance_player_obstruction", "attendance_departure", "attendance_continuous_motion"]
var world: OrisonV2RuntimeRoot
var bar: OrisonV2BarRegion
var player: PlayerController
var motor: Node
var routes: Dictionary = {}
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var contracts: Dictionary = {}
var details: Dictionary = {}
var trace: Array[Dictionary] = []
var last: Dictionary = {}
var admissions := {"balcony_stair": [], "entry_descent": []}
var active_before := {}
var departed := {}
var watching := false
var sample_due := 0.0
var directory := ""
var started := Time.get_ticks_msec()
var initial_inputs: Dictionary
var prior_data: Dictionary
var prior_mode: int
var prior_mouse: int
var preview_owned := false

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	if not ok and label not in failures:
		failures.append(label); push_error("HARUKIYA ATTENDANCE: " + label)
	return ok

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if not _check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK, "explicit writable SHOT_DIR"):
		get_tree().quit(2); return
	initial_inputs = _inputs()
	prior_data = RealityState.data; prior_mode = GameBoot.launch_mode; prior_mouse = Input.mouse_mode
	preview_owned = RealityState.begin_preview_campaign(self)
	if not _check(preview_owned, "exclusive nonpersistent preview campaign"):
		await _finish(); return
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	_check(CampaignClock.new().configure_date(1929, 6, 14, 21 * 60), "declared private evening clock")
	if not _check(DisplayServer.get_name() != "headless", "windowed actual-world attendance proof"):
		await _finish(); return
	world = Runtime.instantiate(); add_child(world)
	if not _check(not world.startup_failed, "actual production world startup"):
		await _finish(); return
	bar = world.bar_region; player = world.player
	# Isolate three already composed owners; do not install or impersonate NPCs.
	var all_routes: Array = world.resident_routes.values()
	all_routes.append(world.mina_routine)
	for owner: Node3D in all_routes:
		owner.set_physics_process(false)
		if owner.get("_bar_route") != null: owner._bar_route.cancel()
	for body: Node3D in get_tree().get_nodes_in_group("animated_residents"): body.hide()
	player.set_physics_process(false)
	await get_tree().physics_frame; await get_tree().physics_frame
	if not _initialize():
		await _finish(); return
	motor = Motor.new(); motor.service_bench_only = true; add_child(motor)
	watching = true
	# Queue the descending resident first. The opposite arrival must wait for
	# that body's real descent and clearance, even if it reaches its slot first.
	routes.evelyn_marsh.set_physics_process(true)
	if not await _until(func(): return _queued("balcony_stair", "evelyn_marsh"), "descending resident requests real stair FIFO", 35):
		await _finish(); return
	routes.lena_ortiz.set_physics_process(true)
	routes.juno_kells.set_physics_process(true)
	if not await _until(func(): return _blocked_seating(), "real player obstructs counter seat transition", 35):
		await _finish(); return
	var blocked_at: Vector3 = routes.juno_kells.actor.global_position
	await get_tree().create_timer(.7).timeout
	var held := _check(routes.juno_kells.actor.global_position.distance_to(blocked_at) < .015
		and _phase("juno_kells") == "occupied" and world.seat_gestures.taken.has("counter_01"),
		"obstruction retains seat ownership without pushing through player")
	# Join the declared counter edge before following its westward route.
	# A generic .9 m retreat crosses the audience bench, not an aisle.
	var withdrawal := withdrawal_plan(bar, player.global_position)
	var walked := _check(not withdrawal.is_empty(), "authored counter-edge withdrawal plan")
	for index in withdrawal.size():
		if not walked: break
		var leg: Dictionary = withdrawal[index]
		walked = await motor._walk_service_player(player, bar, leg.at)
		if walked and index == 0:
			# Stay laterally clear while Juno finishes moving toward her cushion.
			# Crossing counter_w first would occupy her approach again.
			walked = await _until(func(): return (_phase("juno_kells") == "occupied"
				and str(routes.juno_kells._bar_route._transition).is_empty()),
				"Juno completes actual seating after player clears the cushion", 15)
	details.player_refuge = {"route": withdrawal, "reached": walked, "actual": bar.to_local(player.global_position)}
	contracts.attendance_player_obstruction = {"executed": true, "status": "PASS" if held and walked else "FAIL"}
	if not _check(walked, "player walks clear with collision and ordinary speed"):
		await _finish(); return
	var arrived := await _until(func(): return _all_seated(), "counter, floor and balcony residents finish actual arrivals", 150)
	contracts.attendance_arrivals = {"executed": true, "status": "PASS" if arrived else "FAIL"}
	var order: Array = admissions.balcony_stair
	var fifo := _check(order.size() >= 2 and order[0] == "evelyn_marsh" and order[1] == "lena_ortiz",
		"opposing actual stair crossings preserve request order")
	contracts.attendance_opposing_fifo = {"executed": true, "status": "PASS" if fifo else "FAIL"}
	if not arrived or not fifo:
		await _finish(); return
	await _capture("three_arrivals")
	for identity: String in routes: routes[identity].force_destination = "unit"
	var exited := await _until(func(): return departed.size() == routes.size(), "all three depart past the original bar exit", 150)
	var released := true
	for identity: String in routes:
		var place: Dictionary = bar.resident_places.preferred(identity)
		released = _check(_phase(identity).is_empty() and not world.seat_gestures.taken.has(str(place.seat_id)),
			"departure releases exact player seat " + identity) and released
	contracts.attendance_departure = {"executed": true, "status": "PASS" if exited and released else "FAIL"}
	contracts.attendance_continuous_motion = {"executed": true, "status": "PASS" if failures.is_empty() else "FAIL"}
	await _finish()

func _initialize() -> bool:
	if not _check(bar != null and bar.destination != null and world.seat_gestures != null, "real destination and shared seat owner mounted"): return false
	var starts := {}
	for identity: String in STARTS:
		var owner := world.resident_routes.get(identity) as Node3D
		if not _check(owner != null and owner.actor != null and owner._bar_route != null, "existing live route owner " + identity): return false
		var node_id := "bar_" + str(STARTS[identity])
		if not _check(owner.identities.has(node_id), "production graph start " + node_id): return false
		owner.current_id = int(owner.identities[node_id]); owner.path.clear(); owner.planned_id = -1
		owner.force_destination = "harukiya_bar"; owner._sample = 0.0; owner._set_outside(false)
		owner.actor.global_position = owner.graph.get_point_position(owner.current_id)
		if not _check(owner._bar_route.bind_actor(), "explicitly rebind retired visit " + identity): return false
		routes[identity] = owner
		last[identity] = {"at": owner.actor.global_position, "phase": "", "transition": ""}
		starts[identity] = {"node": node_id, "world_feet": owner.actor.global_position, "source_path": owner.source_path,
			"model": owner.actor.model_path, "route_speed": owner.route_speed}
	# Test only nearby positions derived from this installed socket/approach.
	# Keep the full player capsule and an initially clear NPC approach.
	var place: Dictionary = bar.resident_places.preferred("juno_kells")
	var occupied_starts: Array[Vector3] = [routes.juno_kells.actor.global_position]
	for identity: String in routes:
		if identity != "juno_kells": occupied_starts.append(routes[identity].actor.global_position)
	var placement := blocking_stance(bar, player, place, occupied_starts, routes.juno_kells._capsule.radius)
	details.initial_stance = placement
	var candidate: Vector3 = placement.candidate
	if not _check(candidate != Vector3.INF, "full player capsule has a real blocking stance beside counter cushion"): return false
	player.global_position = candidate; player.velocity = Vector3.ZERO; player.camera.make_current()
	player.enable_low_step_probe(); player.set_mouse_released(false)
	details.fixture = {"starts": starts, "player_initial": candidate,
		"other_residents": "Existing other route owners frozen; animated bodies hidden for isolated three-body diagnostic.",
		"destination_selector": "Existing force_destination test hook only; no timetable qualification.",
		"initial_placement_count": 4, "actor_reposition_after_start": false, "speed_multiplier": 1.0}
	return true

## Sweep the actual production path against the installed native room, in
## both directions. Retain the original straight-path failure as a control.
## No actor, clip, authority or body is moved by this geometry diagnostic.
static func seat_torso_trajectory(region: OrisonV2BarRegion, place: Dictionary) -> Dictionary:
	var owner = preload("res://scripts/characters/orison_v2_bar_route.gd")
	var start: Vector3 = region.resident_places.to_global(place.approach)
	var target: Vector3 = place.marker.global_position - Vector3.UP * owner.PROVISIONAL_SEATED_SUPPORT
	var result := {"clear": true, "directions": {},
		"original_straight": _seat_torso_segment(region, start, target)}
	for direction: String in ["seating", "leaving"]:
		var points: PackedVector3Array = owner.seat_transition_points(start, target) if direction == "seating" else owner.seat_transition_points(target, start)
		var legs: Array[Dictionary] = []
		for index in range(1, points.size()):
			var leg := _seat_torso_segment(region, points[index - 1], points[index])
			legs.append(leg)
			result.clear = bool(result.clear) and bool(leg.clear)
		result.directions[direction] = legs
	return result

static func _seat_torso_segment(region: OrisonV2BarRegion, start: Vector3, target: Vector3) -> Dictionary:
	var support: float = preload("res://scripts/characters/orison_v2_bar_route.gd").PROVISIONAL_SEATED_SUPPORT
	# Explicitly bound to production bind_actor's dimensions; runtime inputs
	# bind this diagnostic to that exact owner source, not a smaller test torso.
	var shape := CapsuleShape3D.new(); shape.radius = .28; shape.height = 1.0
	var lift := Vector3.UP * (support + .52)
	var space := region.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape; query.collision_mask = 1
	query.transform.origin = start + lift
	var initial_hits := space.intersect_shape(query, 16)
	query.motion = target - start
	var sweep := space.cast_motion(query)
	var result := {"radius_m": shape.radius, "height_m": shape.height,
		"center_above_root_m": lift.y, "support_m": support, "collision_mask": 1, "exclusions": [],
		"source_owner": "res://scripts/characters/orison_v2_bar_route.gd:bind_actor/_transition_clear",
		"start_bar_feet": region.to_local(start), "target_bar_feet": region.to_local(target),
		"sweep": sweep, "initial_colliders": _stance_hit_rows(initial_hits), "contact_probes": []}
	query.motion = Vector3.ZERO
	query.transform.origin = target + lift
	var end_hits := space.intersect_shape(query, 16)
	result.endpoint_colliders = _stance_hit_rows(end_hits)
	var clear: bool = initial_hits.is_empty() and sweep.size() == 2 and sweep[0] >= 1.0 and end_hits.is_empty()
	result.clear = clear
	if not initial_hits.is_empty():
		result.first_collision = {"lerp_fraction": 0.0, "bar_feet": region.to_local(start), "colliders": _stance_hit_rows(initial_hits)}
	elif sweep.size() == 2 and sweep[0] < 1.0:
		# Query the actual unsafe point, then tiny later points on the SAME
		# original path if a boundary contact lacks a manifold. No shape margin,
		# radius, mask or exclusion changes are used to obtain collider names.
		for advance: float in [0.0, .0001, .001, .01]:
			var fraction: float = minf(1.0, sweep[1] + advance)
			var at := start.lerp(target, fraction)
			query.transform.origin = at + lift
			var hits := space.intersect_shape(query, 16)
			var rest := space.get_rest_info(query)
			var sample := {"lerp_fraction": fraction, "bar_feet": region.to_local(at), "colliders": _stance_hit_rows(hits)}
			if not rest.is_empty():
				var collider: Object = instance_from_id(int(rest.collider_id))
				sample.rest = {"path": str(collider.get_path()) if collider is Node else str(collider),
					"point": rest.point, "normal": rest.normal, "shape": rest.shape}
			result.contact_probes.append(sample)
			if not hits.is_empty() or not rest.is_empty():
				result.first_collision = sample
				break
		if not result.has("first_collision"): result.unresolved = "cast blocked but contact identity unavailable; remains FAIL"
	elif not end_hits.is_empty():
		result.first_collision = {"lerp_fraction": 1.0, "bar_feet": region.to_local(target), "colliders": _stance_hit_rows(end_hits)}
	return result

static func _stance_hit_rows(hits: Array[Dictionary]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for hit: Dictionary in hits:
		var collider: Object = hit.collider
		rows.append({"path": str(collider.get_path()) if collider is Node else str(collider), "shape": hit.shape})
	return rows

## Join an existing counter edge, then use only declared navigation edges.
## The initial join is a movement target, never a body placement or graph edit.
static func withdrawal_plan(region: OrisonV2BarRegion, initial: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var navigation := region.destination.get_node("Navigation")
	var east := navigation.get_node_or_null("counter_e") as Node3D
	var west := navigation.get_node_or_null("counter_w") as Node3D
	if east == null or west == null: return result
	var spec: Dictionary = region.destination.get("spec")
	var edges: Array = spec.navigation.edges
	if ["counter_e", "counter_w"] not in edges and ["counter_w", "counter_e"] not in edges: return result
	var join := Geometry3D.get_closest_point_to_segment(initial, east.global_position, west.global_position)
	result.append({"id": "counter_edge_join", "at": region.to_local(join)})
	var previous := "counter_w"
	for identity: String in ["counter_w", "under_landing_e", "under_landing_w",
			"west_bypass", "pool_approach_s", "pool_interaction"]:
		var marker := navigation.get_node_or_null(identity) as Node3D
		if marker == null: return []
		if identity != previous and [previous, identity] not in edges and [identity, previous] not in edges: return []
		result.append({"id": identity, "at": region.to_local(marker.global_position)})
		previous = identity
	return result

## Shared with the nearby geometry preflight; this selects a declared initial
## fixture placement only. It does not move a body or prove NPC attendance.
static func blocking_stance(region: OrisonV2BarRegion, body: PlayerController,
		place: Dictionary, occupied_starts: Array[Vector3], resident_radius: float = .28) -> Dictionary:
	var result := {"candidate": Vector3.INF, "attempts": [],
		"radius_m": PlayerController.BODY_RADIUS, "height_m": PlayerController.STANDING_HEIGHT,
		"resident_radius_m": resident_radius}
	if occupied_starts.is_empty(): return result
	var socket: Marker3D = place.marker
	var approach: Vector3 = region.resident_places.to_global(place.approach)
	var toward := Vector3(approach.x-socket.global_position.x, 0, approach.z-socket.global_position.z).normalized()
	if toward.length_squared() < .99: return result
	var sideways := Vector3.UP.cross(toward).normalized()
	var space := region.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = PlayerController.BODY_RADIUS; shape.height = PlayerController.STANDING_HEIGHT
	# Log the original pair unchanged. Accepted pairs keep physical-radius
	# separation even during straight retreat, yet trigger the .65 m courtesy
	# stop. Values are (lateral, aisleward), measured from the installed socket.
	for offsets: Vector2 in [Vector2(.58, .10), Vector2(.62, .40), Vector2(.62, .35), Vector2(.62, .45)]:
		for side: float in [-1.0, 1.0]:
			var at := socket.global_position + sideways * offsets.x * side + toward * offsets.y
			at.y = approach.y + .02
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape; query.collision_mask = 1
			query.transform.origin = at + Vector3.UP * (shape.height * .5)
			query.exclude = [body.get_rid()]
			var hits := space.intersect_shape(query, 16)
			var colliders: Array[Dictionary] = []
			for hit: Dictionary in hits:
				var collider: Object = hit.collider
				colliders.append({"path": str(collider.get_path()) if collider is Node else str(collider), "shape": hit.shape})
			var floor_query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * .2, at - Vector3.UP * .15, 1)
			floor_query.exclude = [body.get_rid()]
			var floor_hit := space.intersect_ray(floor_query)
			var floor_ok: bool = not floor_hit.is_empty() and floor_hit.normal.y > .8 \
				and at.y-floor_hit.position.y >= 0.0 and at.y-floor_hit.position.y <= .05
			var nearest_start := INF
			for initial: Vector3 in occupied_starts:
				if absf(initial.y-at.y) < 1.6:
					nearest_start = minf(nearest_start, Vector2(initial.x-at.x, initial.z-at.z).length())
			var segment_start := Vector3(occupied_starts[0].x, at.y, occupied_starts[0].z)
			var segment_end := Vector3(socket.global_position.x, at.y, socket.global_position.z)
			var near := Geometry3D.get_closest_point_to_segment(at, segment_start, segment_end)
			var future_gap := near.distance_to(at)
			# Same .65 m player separation as production _people_clear. A later
			# approach point must be blocked, while all initial bodies stay clear.
			var radial_clear := future_gap >= shape.radius + resident_radius
			var accepted: bool = hits.is_empty() and floor_ok and nearest_start >= .65 and radial_clear and future_gap < .65
			var attempt := {"world_feet": at, "bar_feet": region.to_local(at),
				"aisle_offset_m": offsets.y, "lateral_offset_m": offsets.x * side,
				"colliders": colliders, "floor_supported": floor_ok, "nearest_start_m": nearest_start,
				"future_approach_gap_m": future_gap, "physical_radii_clear": radial_clear, "accepted": accepted}
			if not floor_hit.is_empty():
				attempt.floor_point = floor_hit.position
				attempt.floor_path = str(floor_hit.collider.get_path()) if floor_hit.collider is Node else str(floor_hit.collider)
			result.attempts.append(attempt)
			if accepted:
				result.candidate = at
				return result
	return result

func _phase(identity: String) -> String:
	return str(bar.resident_places.phase(identity, routes[identity].actor))

func _queued(passage: String, identity: String) -> bool:
	for entry: Dictionary in bar.resident_places._passages[passage].queue:
		if str(entry.resident) == identity: return true
	return false

func _blocked_seating() -> bool:
	var route: Node3D = routes.juno_kells
	return str(route._bar_route._transition) == "seating" and str(route.blocked_reason) == "seat transition waiting for physical clearance"

func _all_seated() -> bool:
	for identity: String in routes:
		var route: Node3D = routes[identity]
		if _phase(identity) != "occupied" or not str(route._bar_route._transition).is_empty(): return false
		if route.actor._animation_player == null or route.actor._animation_player.current_animation != "clip_06": return false
	return true

func _until(predicate: Callable, label: String, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline and failures.is_empty():
		if predicate.call(): return _check(true, label)
		await get_tree().physics_frame
	return _check(false, label)

## Walking has bounded horizontal travel and an independently supported floor
## correction. Discrete native treads are not a diagonal movement impulse.
## Seating keeps its existing three-dimensional bound. No actor is moved here.
static func motion_witness(space: PhysicsDirectSpaceState3D, before: Vector3,
		after: Vector3, delta: float, transitioning: bool) -> Dictionary:
	var offset := after - before
	var horizontal := Vector2(offset.x, offset.z).length()
	var vertical := absf(offset.y)
	var limit := (4.0 if transitioning else 1.1) * delta + .03
	var result := {"before": before, "after": after, "delta_s": delta,
		"horizontal_m": horizontal, "vertical_m": vertical, "limit_m": limit,
		"transitioning": transitioning, "support": {}, "clear": false}
	if transitioning:
		result.clear = offset.length() <= limit
		return result
	if horizontal > limit or vertical > .25001: return result
	if vertical > .00001:
		# A short ray at the actual new feet cannot accept a nearby lower floor
		# as support for a body floating above it. Do not trust last_floor alone.
		var query := PhysicsRayQueryParameters3D.create(after + Vector3.UP * .03,
			after - Vector3.UP * .03, 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty(): return result
		result.support = {"point": hit.position, "normal": hit.normal,
			"path": str(hit.collider.get_path()) if hit.collider is Node else str(hit.collider)}
		if absf(hit.position.y-after.y) > .003 or (hit.normal.y < .45 and vertical > .06): return result
	result.clear = true
	return result

func _physics_process(delta: float) -> void:
	if not watching: return
	sample_due -= delta
	var sample := {"elapsed_s": (Time.get_ticks_msec()-started)/1000.0, "actors": {}, "tokens": {}}
	for identity: String in routes:
		var route: Node3D = routes[identity]
		var at: Vector3 = route.actor.global_position
		var phase := _phase(identity); var transition := str(route._bar_route._transition)
		var old: Dictionary = last[identity]
		var motion := motion_witness(world.get_world_3d().direct_space_state, old.at, at, delta,
			not transition.is_empty() or not str(old.transition).is_empty())
		if not motion.clear or (not motion.transitioning and motion.vertical_m > .00001):
			if not details.has("motion_witnesses"): details.motion_witnesses = []
			motion.resident = identity; motion.elapsed_s = sample.elapsed_s; motion.motor_floor = route.last_floor
			details.motion_witnesses.append(motion)
		if not motion.clear: _check(false, "continuous movement without teleport " + identity)
		if absf(float(route.route_speed)-1.05) > .0001: _check(false, "unchanged production walking speed " + identity)
		if route.blocked_seconds > 3.0: _check(false, "route blocked by actual world " + identity + ": " + str(route.blocked_reason))
		if phase.is_empty() and transition.is_empty():
			var query := PhysicsShapeQueryParameters3D.new(); query.shape = route._capsule; query.collision_mask = 1
			query.transform.origin = at + Vector3.UP * (.25 + route._capsule.height * .5)
			query.exclude = [player.get_rid()]
			if not world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				_check(false, "standing route capsule clears actual world " + identity)
		for passage: Dictionary in route._bar_route._passages:
			if str(passage.id) != "balcony_stair": continue
			var lower: Vector3 = route.graph.get_point_position(int(passage.a))
			var upper: Vector3 = route.graph.get_point_position(int(passage.b))
			if at.y <= lower.y + .35 or at.y >= upper.y - .35: continue
			for index in passage.path.size() - 1:
				var a: Vector3 = route.graph.get_point_position(passage.path[index])
				var b: Vector3 = route.graph.get_point_position(passage.path[index+1])
				if Geometry3D.get_closest_point_to_segment(at, a, b).distance_to(at) < .45:
					if not bar.resident_places.has_admission("balcony_stair", identity, route.actor):
						_check(false, "actual stair body holds admission " + identity)
		if not phase.is_empty():
			var seat := str(bar.resident_places.preferred(identity).seat_id)
			var record: Dictionary = world.seat_gestures.taken.get(seat, {})
			if record.get("owner") is not WeakRef or record.owner.get_ref() != route.actor: _check(false, "shared seat exact owner " + identity)
		if str(route.destination) == "unit" and int(route.current_id) == int(route.identities.bar_street_5) and phase.is_empty(): departed[identity] = true
		if sample_due <= 0 or phase != old.phase or transition != old.transition:
			sample.actors[identity] = {"at": at, "phase": phase, "transition": transition,
				"current": route.current_id, "next": route.path[0] if not route.path.is_empty() else -1,
				"blocked": route.blocked_reason, "metres": route.travelled_metres}
		last[identity] = {"at": at, "phase": phase, "transition": transition}
	var ids: Array = routes.keys()
	for first in ids.size():
		for second in range(first + 1, ids.size()):
			var a: Vector3 = routes[ids[first]].actor.global_position
			var b: Vector3 = routes[ids[second]].actor.global_position
			var full_width: float = routes[ids[first]]._capsule.radius + routes[ids[second]]._capsule.radius
			if absf(a.y-b.y) < 1.4 and Vector2(a.x-b.x, a.z-b.z).length() + .00001 < full_width:
				_check(false, "actual resident bodies retain separation " + str(ids[first]) + "/" + str(ids[second]))
	for passage: String in admissions:
		var active: Dictionary = bar.resident_places._passages[passage].active
		var identity := str(active.get("resident", ""))
		if not identity.is_empty() and identity != str(active_before.get(passage, "")): admissions[passage].append(identity)
		active_before[passage] = identity; sample.tokens[passage] = identity
	if not sample.actors.is_empty(): trace.append(sample)
	if sample_due <= 0: sample_due = .2

func _capture(label: String) -> void:
	player.camera.look_at(routes.juno_kells.actor.global_position + Vector3.UP)
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "rendered attendance capture")

func _inputs() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var runtime: Array = []; var physical: Array = []
	_check(OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], runtime) == 0, "runtime input signature")
	_check(OS.execute("python", [root.path_join("tools/v2_physical_inputs.py"), "--root", root], physical) == 0, "physical input signature")
	var dependencies := {}; var pending: Array[String] = [get_script().resource_path, scene_file_path]
	var references := RegEx.new(); references.compile("res://tests/[A-Za-z0-9_/.-]+\\.[A-Za-z0-9]+(?=[\"'])")
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if dependencies.has(path): continue
		var source := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
		dependencies[path] = source.sha256_text()
		for found: RegExMatch in references.search_all(source): pending.append(found.get_string())
	return {"runtime": str(runtime[0]).strip_edges() if not runtime.is_empty() else "",
		"physical": str(physical[0]).strip_edges() if not physical.is_empty() else "", "dependencies": dependencies}

func _finish() -> void:
	watching = false; Input.action_release("move_forward")
	details.admissions = admissions; details.departed = departed; details.trace = trace
	if motor != null: details.player_motor = motor.service_travel
	if is_instance_valid(world):
		world.shutdown_for_tests(); remove_child(world); world.free(); world = null
	await get_tree().process_frame
	if preview_owned:
		_check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, prior_data), "original campaign context restored")
	GameBoot.launch_mode = prior_mode; Input.mouse_mode = prior_mouse
	var final_inputs := _inputs()
	_check(final_inputs == initial_inputs, "executed runtime, physical and test inputs remain frozen")
	for name: String in REQUIRED:
		if not contracts.has(name): contracts[name] = {"executed": false, "status": "FAIL"}
		_check(contracts[name].executed and contracts[name].status == "PASS", "required contract " + name)
	var passed := failures.is_empty()
	var head: Array = []; var root := ProjectSettings.globalize_path("res://..").simplify_path()
	_check(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head) == 0 and not head.is_empty(), "repository provenance")
	passed = failures.is_empty()
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": true,
		"scope": "Actual V2 world and three existing ResidentRoute owners after declared nearby initial placement. Normal-pace counter/floor/balcony arrival, opposing stair FIFO, real player obstruction and motor withdrawal, seat ownership through departure. Other residents hidden/frozen. No timetable selection, full home/street journey, save reconstruction, whole-cast performance or artistic/pose-fit acceptance.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec()-started)/1000.0},
		"source": {"test_path": "game/tests/harukiya_attendance_test.gd", "test_sha256": FileAccess.get_sha256(get_script().resource_path),
			"test_scene_path": "game/tests/HarukiyaAttendanceTest.tscn", "test_scene_sha256": FileAccess.get_sha256(scene_file_path),
			"repository_head": str(head[0]).strip_edges() if not head.is_empty() else "",
			"runtime_inputs_sha256": final_inputs.runtime, "physical_inputs_sha256": final_inputs.physical, "test_dependencies": final_inputs.dependencies},
		"contracts": contracts, "checks": checks, "failures": failures, "details": details}
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush()
	var written := file.get_error() == OK; file.close()
	print("HARUKIYA ATTENDANCE: ", "PASS" if passed and written else "FAIL", " checks=", checks.size(), " failures=", failures.size())
	get_tree().quit(0 if passed and written else 1)
