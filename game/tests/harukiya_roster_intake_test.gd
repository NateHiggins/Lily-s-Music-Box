extends Node
## Registered Rhea/guest mechanical intake. No natural schedule claim.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Registration := preload("res://tests/harukiya_remaining_roster_checks.gd")
const RouteProbe := preload("res://tests/orison_v2_route_probe.gd")
const Attendance := preload("res://tests/harukiya_attendance_test.gd")
const IDS := ["rhea_sato", "transient_guests"]
const HOME_NODE := "bed"
const HOME_PLACE := "unit:bed"
const REQUIRED := ["roster_registration", "roster_route_preflight", "roster_mechanical_arrivals",
	"roster_mechanical_returns", "roster_continuous_motion", "roster_passage_admission", "roster_custody"]
const LEG_SECONDS := 300.0
var world: OrisonV2RuntimeRoot
var routes: Dictionary = {}
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var contracts: Dictionary = {}
var details := {"probe": [], "doors": [], "slope_skips": [], "trace": [], "admissions": [], "motion_failures": []}
var last: Dictionary = {}
var passage_before: Dictionary = {}
var watching := false
var sample_due := 0.0
var motion_frames := 0
var stage := "initialization"
var directory := ""
var started := Time.get_ticks_msec()
var initial_inputs: Dictionary = {}
var prior_data: Dictionary
var prior_mode: int
var prior_mouse: int
var prior_frozen := false
var preview_owned := false
var door_records: Array[Dictionary] = []
var door_book: Dictionary = {}
var inventory_book: Dictionary = {}
var door_book_existed := false
var doors_restored := true
var geometry_holds: Dictionary = {}

func _ready() -> void:
	# Observe after the normal route owners, using the same physics delta.
	process_physics_priority = 100
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	if not ok and label not in failures:
		failures.append(label); push_error("HARUKIYA ROSTER: " + label)
	return ok

func _contract(name: String, ok: bool) -> void:
	contracts[name] = {"executed": true, "status": "PASS" if ok else "FAIL"}
	print("HARUKIYA ROSTER CONTRACT: ", name, " = ", "PASS" if ok else "FAIL")

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("HARUKIYA ROSTER requires writable SHOT_DIR"); get_tree().quit(2); return
	prior_data = RealityState.data; prior_mode = GameBoot.launch_mode; prior_mouse = Input.mouse_mode
	prior_frozen = CampaignTime._frozen_for_tests
	initial_inputs = _inputs()
	if not failures.is_empty(): await _finish(); return
	preview_owned = RealityState.begin_preview_campaign(self)
	if not _check(preview_owned, "exclusive nonpersistent preview campaign"):
		await _finish(); return
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	if not _check(CampaignClock.new().configure_date(1929, 6, 14, 12 * 60), "private mechanical midday clock"):
		await _finish(); return
	world = Runtime.instantiate(); add_child(world)
	if not _check(not world.startup_failed, "actual production world starts"):
		await _finish(); return
	stage = "registration"
	var inspected: Dictionary = Registration.inspect(world)
	details.registration = inspected
	for row: Dictionary in inspected.checks: _check(bool(row.ok), str(row.label))
	_check(world.resident_routes.size() == 17 and is_instance_valid(world.mina_routine), "seventeen general routes plus existing Mina")
	_check(not world.resident_routes.has("mina_vale"), "Mina is not duplicated in general registry")
	_check(is_instance_valid(world.temporal_loop) and not world.temporal_loop.in_visit(), "ordinary preview has no historical visit override")
	_contract("roster_registration", failures.is_empty())
	if not failures.is_empty(): await _finish(); return
	# Isolate the two existing registered bodies, matching AttendanceTest.
	# Freeze and hide unrelated people; preserve the real player and native world.
	var owners: Array = world.resident_routes.values(); owners.append(world.mina_routine)
	for owner: Node3D in owners:
		owner.set_physics_process(false)
		if owner._bar_route != null: owner._bar_route.cancel()
	for body: Node3D in get_tree().get_nodes_in_group("animated_residents"):
		if str(body.get("resident_id")) not in IDS: body.hide()
	world.player.set_physics_process(false)
	for identity: String in IDS: routes[identity] = world.resident_routes[identity]
	await get_tree().physics_frame; await get_tree().physics_frame
	stage = "route_preflight"
	var probe_ok := await _preflight()
	_contract("roster_route_preflight", probe_ok)
	if not probe_ok: await _finish(); return
	stage = "declared_initial_home_placement"
	if not _initialize_home(): await _finish(); return
	watching = true
	for identity: String in IDS:
		routes[identity].force_destination = "harukiya_bar"
		routes[identity].set_physics_process(true)
	stage = "mechanical_arrival"
	var arrived := await _until(_all_seated, "both registered actors finish their assigned balcony seating", LEG_SECONDS)
	_contract("roster_mechanical_arrivals", arrived)
	if not arrived: await _finish(); return
	details.seated = _state()
	stage = "mechanical_return"
	for identity: String in IDS: routes[identity].force_destination = HOME_PLACE
	var returned := await _until(_all_home, "both registered actors physically return to bed and release venue custody", LEG_SECONDS)
	_contract("roster_mechanical_returns", returned)
	if not returned: await _finish(); return
	_contract("roster_continuous_motion", motion_frames > 0 and failures.is_empty())
	var admissions_ok := true
	for identity: String in IDS:
		for passage: String in ["entry_descent", "balcony_stair"]:
			for leg: String in ["mechanical_arrival", "mechanical_return"]:
				var count := 0
				for record: Dictionary in details.admissions:
					if record.resident == identity and record.passage == passage and record.stage == leg: count += 1
				admissions_ok = _check(count >= 1, "actual admission " + identity + "/" + passage + "/" + leg) and admissions_ok
	_contract("roster_passage_admission", admissions_ok and failures.is_empty())
	await _finish()

func _preflight() -> bool:
	var probe := RouteProbe.new() # Never add_child: _ready resets the real campaign.
	probe.suggest_detours = false
	var geometry_findings: Array[String] = []
	_check(not probe.is_inside_tree(), "route probe stays untree'd; unsafe _ready never runs")
	details.beds = []
	for name: String in ["3D_bed", "4D_bed"]:
		var body := world.find_child(name, true, false) as StaticBody3D
		if not _check(body != null, "installed native bed available for geometry witness " + name): continue
		var shapes: Array[Dictionary] = []
		for child in body.get_children():
			if child is CollisionShape3D:
				shapes.append({"type": child.shape.get_class(), "local_transform": child.transform})
		details.beds.append({"identity": name, "path": str(body.get_path()),
			"route_origin": world.adapter.root.to_local(body.global_position),
			"global_transform": body.global_transform, "layer": body.collision_layer,
			"mask": body.collision_mask, "native_shapes": shapes})
	door_book_existed = RealityState.data.has(DoorKeyring.KEY)
	door_book = (RealityState.data.get(DoorKeyring.KEY, {}) as Dictionary).duplicate(true)
	inventory_book = (RealityState.data.get(PersonInventory.KEY, {}) as Dictionary).duplicate(true)
	doors_restored = false
	for identity: String in IDS:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(routes[identity].source_path))
		var named: Array[DoorProp] = []
		var names: Array = source.doors.duplicate(); names.append_array(RouteProbe.SHARED_DOORS)
		for name: String in names:
			var door := world.find_child(name + "_Leaf", true, false) as DoorProp
			if door == null:
				details.doors.append({"resident": identity, "identity": name, "missing": true, "required_source_door": source.doors.has(name)})
				if source.doors.has(name): _check(false, "required source door installed " + name)
				continue
			named.append(door)
			var found := false
			for record: Dictionary in door_records:
				if record.door == door: found = true
			if not found:
				door_records.append({"door": door, "mechanism": door.mechanism_snapshot().duplicate(true),
					"leaf_state": door.leaf_state, "open": door.open, "layer": door._body.collision_layer,
					"mask": door._body.collision_mask})
			_check(door.passage_allowed(identity), "existing resident access permits named route door " + identity + "/" + name)
		if not failures.is_empty(): break
		for chain: Array in source.paths:
			for index in range(1, chain.size()):
				if absf(float(chain[index][2]) - float(chain[index - 1][2])) > .05:
					details.slope_skips.append({"resident": identity, "from": chain[index - 1][0], "to": chain[index][0],
						"reason": "original RouteProbe skips sloped-edge interiors; nodes still checked, actual stair walking required"})
		for opened: bool in [false, true]:
			_release_geometry_holds()
			var settled := await _settle_probe_doors(named, opened, identity)
			details.doors.append({"resident": identity, "requested_open": opened, "settled": settled,
				"observed": _probe_door_states(named), "player_feet": world.player.global_position})
			if not settled:
				geometry_findings.append("original leaves reach requested geometry-probe stop " + identity + "/" + str(opened) + " (deadline; actual leaf states retained)")
				break
			probe._open_doors = opened
			probe._file = str(routes[identity].source_path).get_file()
			# Collect both residents/leaf states in one composition. No expensive
			# detour search and no walking while any original geometry check fails.
			for index in source.paths.size():
				# Each chain is synchronous; renew before it, not by stopping the
				# closer or mutating its spring/hold-open hardware.
				for door: DoorProp in geometry_holds: door.hold_passage(geometry_holds[door])
				probe.failures.clear()
				var part := source.duplicate(true); part.paths = [source.paths[index]]
				probe._probe(world, part)
				for door: DoorProp in geometry_holds: door.hold_passage(geometry_holds[door])
				details.probe.append({"resident": identity, "open_leaves": opened, "chain": index,
					"findings": probe.failures.duplicate(), "scope": "original .30 x 1.40 capsule, mask 1, closed leaves ignored by original probe"})
				geometry_findings.append_array(probe.failures)
			if not failures.is_empty(): break
		if not failures.is_empty(): break
	probe.free()
	for finding: String in geometry_findings: _check(false, finding)
	await _restore_probe_doors()
	return failures.is_empty()

func _settle_probe_doors(doors: Array[DoorProp], opened: bool, identity: String) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	var actor: Node3D = routes[identity].actor
	while Time.get_ticks_msec() < deadline:
		for door: DoorProp in doors:
			if opened:
				geometry_holds[door] = actor
				door.hold_passage(actor)
				door.request_passage(actor, identity)
			elif not door._moving and not door._key_turning and door.open:
				door.npc_set_open(false, identity)
		if _doors_settled(doors, opened): return true
		await get_tree().physics_frame
	return false

func _probe_door_states(doors: Array[DoorProp]) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for door: DoorProp in doors:
		states.append({"path": str(door.get_path()), "angle": door.mechanism_snapshot(),
			"target_angle": door.motion_target_angle(true), "leaf_state": door.leaf_state,
			"open": door.open, "moving": door._moving, "key_turning": door._key_turning,
			"ready": door.is_ready_for_passage(), "opening_clear": door.opening_clear(),
			"passage_held": door.passage_held()})
	return states

func _release_geometry_holds() -> void:
	for door: DoorProp in geometry_holds:
		if is_instance_valid(door):
			var actor: Node3D = geometry_holds[door]
			door.release_passage(actor)
			_check(not door._passage_holds.has(actor.get_instance_id()), "temporary geometry hold released " + str(door.name))
	geometry_holds.clear()

func _doors_settled(doors: Array[DoorProp], opened: bool) -> bool:
	for door: DoorProp in doors:
		if door._moving or door._key_turning: return false
		if opened:
			if not door.is_ready_for_passage(): return false
		elif door.open or absf(float(door.mechanism_snapshot().angle)) > .001: return false
	return true

func _restore_probe_doors() -> void:
	if doors_restored: return
	_release_geometry_holds()
	# Exact private-preview cleanup, not a new permission or gameplay relock.
	# Return the probe's durable unlocks before testing the actual route owner.
	if door_book_existed: RealityState.data[DoorKeyring.KEY] = door_book.duplicate(true)
	else: RealityState.data.erase(DoorKeyring.KEY)
	for record: Dictionary in door_records:
		var door: DoorProp = record.door
		if not is_instance_valid(door): _check(false, "probe door survives until cleanup"); continue
		door.leaf_state = str(record.leaf_state)
		door.restore_mechanism(record.mechanism)
	await get_tree().physics_frame; await get_tree().physics_frame
	for record: Dictionary in door_records:
		var door: DoorProp = record.door
		if not is_instance_valid(door): continue
		details.doors.append({"path": str(door.get_path()), "before": record.mechanism, "after": door.mechanism_snapshot(),
			"leaf_before": record.leaf_state, "leaf_after": door.leaf_state})
		_check(door.leaf_state == record.leaf_state and door.open == record.open
			and absf(float(door.mechanism_snapshot().angle) - float(record.mechanism.angle)) < .00001
			and door._body.collision_layer == record.layer and door._body.collision_mask == record.mask,
			"probe restores exact leaf and original collision bits " + str(door.name))
	_check(RealityState.data.has(DoorKeyring.KEY) == door_book_existed
		and RealityState.data.get(DoorKeyring.KEY, {}) == door_book, "probe restores exact preview lock domain")
	_check(RealityState.data.get(PersonInventory.KEY, {}) == inventory_book, "probe grants or removes no carried keys")
	doors_restored = true

func _initialize_home() -> bool:
	details.initial_placements = []
	for identity: String in IDS:
		var route: Node3D = routes[identity]
		if not _check(route.identities.has(HOME_NODE) and str(route.places.get(HOME_PLACE, "")) == HOME_NODE
				and str(route._node_for(HOME_PLACE)) == HOME_NODE, "exact authored bed destination resolves " + identity): return false
		var bed_id := str(Registration.EXPECTED[identity].unit) + "_bed"
		var native_bed := world.find_child(bed_id, true, false) as StaticBody3D
		if not _check(native_bed != null and str(native_bed.get_meta("v2_furniture_id", "")) == bed_id
				and str(native_bed.get_meta("v2_furniture_kind", "")) == "bed", "exact original native bed registered " + identity): return false
		var home := int(route.identities[HOME_NODE])
		# Check the loaded route actually includes the repaired corner on its
		# ordinary shortest exit. No graph edits or forced intermediate stages.
		var planned: PackedInt64Array = route.graph.get_id_path(home, int(route.identities.street))
		if not _check(planned.size() >= 3 and int(planned[0]) == home
				and str(route.identities.find_key(int(planned[1]))) == "bed_approach"
				and str(route.identities.find_key(int(planned[2]))).ends_with("_main_bed_door_b"),
				"ordinary bed exit includes both repaired corner legs " + identity): return false
		route.current_id = home; route.desired_id = home; route.planned_id = -1; route.path.clear()
		route.force_destination = HOME_PLACE; route.destination = HOME_PLACE; route._sample = 0.0
		route._set_outside(false)
		route.actor.global_position = route.graph.get_point_position(home) # Only declared placement.
		if not _check(route._bar_route.bind_actor(), "rebind existing actor after frozen preflight " + identity): return false
		if not _check(is_equal_approx(route._capsule.radius, .28) and is_equal_approx(route._capsule.height, 1.40), "full unchanged route capsule " + identity): return false
		last[identity] = {"at": route.actor.global_position, "phase": "", "transition": ""}
		details.initial_placements.append({"resident": identity, "node": HOME_NODE, "at": route.actor.global_position})
		if not _check(_world_hits(route, false).is_empty(), "home placement has actual full-capsule clearance " + identity): return false
		var feet: Vector3 = route.actor.global_position
		var support := world.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(feet + Vector3.UP * .03, feet - Vector3.UP * .03, 1))
		if not _check(not support.is_empty() and absf(support.position.y - feet.y) <= .003,
				"declared bed initial feet have actual floor support " + identity): return false
	details.fixture = {"home_node": HOME_NODE, "home_place": HOME_PLACE, "actor_initial_placements": 2, "later_actor_reposition": false, "destination_selector": "force_destination mechanical hook only",
		"other_actors": "unrelated existing resident bodies frozen and hidden; native world collision and real player retained", "normal_speed_m_s": 1.05,
		"clock": "private fixed Friday midday", "natural_attendance": "NOT IMPLEMENTED OR CLAIMED"}
	return _check(not world.player.call_locked, "player call does not pause mechanical routes")

func _phase(identity: String) -> String:
	return str(routes[identity]._bar_route.visit.phase())

func _all_seated() -> bool:
	for identity: String in IDS:
		var route: Node3D = routes[identity]
		if _phase(identity) != "occupied" or not str(route._bar_route._transition).is_empty(): return false
		if route.actor._animation_player.current_animation != "clip_06": return false
		var seat: String = str(Registration.EXPECTED[identity].seat)
		var claim: Dictionary = world.seat_gestures.taken.get(seat, {})
		if not _exact_owner(claim, route.actor): return false
		var place: Dictionary = world.bar_region.resident_places.preferred(identity)
		var target: Vector3 = place.marker.global_position - Vector3.UP * route._bar_route.PROVISIONAL_SEATED_SUPPORT
		# Reservation precedes the physical transition; prove the body got there.
		if route.actor.global_position.distance_to(target) > .001: return false
	return true

func _all_home() -> bool:
	for identity: String in IDS:
		var route: Node3D = routes[identity]
		if route.current_id != int(route.identities[HOME_NODE]) or route.desired_id != int(route.identities[HOME_NODE]) \
				or route.destination != HOME_PLACE or not route.path.is_empty(): return false
		var offset: Vector3 = route.actor.global_position - route.graph.get_point_position(int(route.identities[HOME_NODE]))
		if Vector2(offset.x, offset.z).length() > .05 or absf(offset.y) > .3: return false
		var feet: Vector3 = route.actor.global_position
		var support := world.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(feet + Vector3.UP * .03, feet - Vector3.UP * .03, 1))
		if support.is_empty() or absf(support.position.y - feet.y) > .003: return false
		if not _phase(identity).is_empty() or not str(route._bar_route._transition).is_empty(): return false
		if world.seat_gestures.taken.has(str(Registration.EXPECTED[identity].seat)): return false
		if not route._door_passages.is_empty(): return false
		for passage: Dictionary in world.bar_region.resident_places._passages.values():
			if _exact_owner(passage.active, route.actor): return false
			for queued: Dictionary in passage.queue:
				if _exact_owner(queued, route.actor): return false
	return true

func _exact_owner(record: Dictionary, actor: Node3D) -> bool:
	return record.get("owner") is WeakRef and record.owner.get_ref() == actor

func _until(predicate: Callable, label: String, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline and failures.is_empty():
		if predicate.call(): return _check(true, label)
		await get_tree().physics_frame
	details["failure_state"] = _state()
	return _check(false, label + " (stopped at first failure/deadline)")

func _world_hits(route: Node3D, seated: bool) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = route._bar_route._torso if seated else route._capsule
	query.collision_mask = 1
	query.transform.origin = route.actor.global_position + Vector3.UP * (
		route._bar_route.PROVISIONAL_SEATED_SUPPORT + .52 if seated else .25 + route._capsule.height * .5)
	# This is the production world's static-body query. Player spacing is
	# independently checked below; mask 1 does not establish NPC separation.
	query.exclude = [world.player.get_rid()]
	var result: Array[Dictionary] = []
	for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query, 8):
		result.append({"path": str(hit.collider.get_path()) if hit.collider is Node else str(hit.collider), "rid": str(hit.rid)})
	return result

func _capsule_overlap(a: Vector3, radius_a: float, height_a: float,
		b: Vector3, radius_b: float, height_b: float) -> bool:
	var half_a := maxf(0.0, height_a * .5 - radius_a)
	var half_b := maxf(0.0, height_b * .5 - radius_b)
	var gap := maxf(0.0, absf(a.y - b.y) - half_a - half_b)
	return Vector2(a.x-b.x, a.z-b.z).length_squared() + gap * gap < pow(radius_a + radius_b - .00001, 2)

func _physics_process(delta: float) -> void:
	if not watching or not failures.is_empty(): return
	motion_frames += 1; sample_due -= delta
	for identity: String in IDS:
		var route: Node3D = routes[identity]
		var phase := _phase(identity); var transition := str(route._bar_route._transition)
		var old: Dictionary = last[identity]; var at: Vector3 = route.actor.global_position
		var moving_seat := not transition.is_empty() or not str(old.transition).is_empty()
		var witness := Attendance.motion_witness(world.get_world_3d().direct_space_state, old.at, at, delta, moving_seat)
		if not bool(witness.clear):
			witness.resident = identity; details.motion_failures.append(witness)
			_check(false, "continuous supported movement " + identity)
		if float(route.blocked_seconds) > 3.0:
			details.motion_failures.append({"resident": identity, "at": at, "reason": route.blocked_reason, "last_floor": route.last_floor})
			_check(false, "actual route obstruction " + identity + ": " + str(route.blocked_reason))
		if absf(float(route.route_speed) - 1.05) > .0001: _check(false, "unchanged walking speed " + identity)
		if not route.actor.visible or route.outside: _check(false, "actor remains physically present on home/bar route " + identity)
		# Previous transition is relevant to motion bounds, not current posture.
		var seated := phase == "occupied" or not transition.is_empty()
		var hits := _world_hits(route, seated)
		if not hits.is_empty():
			details.motion_failures.append({"resident": identity, "at": at, "colliders": hits, "seated_torso": seated})
			_check(false, "actual world capsule clearance " + identity)
		var body_shape: CapsuleShape3D = route._bar_route._torso if seated else route._capsule
		var center: Vector3 = at + Vector3.UP * (route._bar_route.PROVISIONAL_SEATED_SUPPORT + .52 if seated else .25 + body_shape.height * .5)
		if _capsule_overlap(center, body_shape.radius, body_shape.height, world.player._shape.global_position,
			world.player._capsule.radius, world.player._capsule.height): _check(false, "full player body clearance " + identity)
		for other_id: String in IDS:
			if other_id <= identity: continue
			var other: Node3D = routes[other_id]
			var other_seated := _phase(other_id) == "occupied" or not str(other._bar_route._transition).is_empty()
			var other_shape: CapsuleShape3D = other._bar_route._torso if other_seated else other._capsule
			var other_center: Vector3 = other.actor.global_position + Vector3.UP * (
				other._bar_route.PROVISIONAL_SEATED_SUPPORT + .52 if other_seated else .25 + other_shape.height * .5)
			if _capsule_overlap(center, body_shape.radius, body_shape.height, other_center, other_shape.radius, other_shape.height):
				_check(false, "two actual registered bodies retain full separation")
		if not phase.is_empty():
			var seat := str(Registration.EXPECTED[identity].seat)
			if not _exact_owner(world.seat_gestures.taken.get(seat, {}), route.actor): _check(false, "seat retains exact live actor owner " + identity)
		for passage: Dictionary in route._bar_route._passages:
			var inside := false
			for index in range(passage.path.size() - 1):
				var a: Vector3 = route.graph.get_point_position(passage.path[index])
				var b: Vector3 = route.graph.get_point_position(passage.path[index + 1])
				var nearest := Geometry3D.get_closest_point_to_segment(at, a, b)
				if nearest.distance_to(at) < .30 and at.distance_to(route.graph.get_point_position(passage.a)) > .4 \
						and at.distance_to(route.graph.get_point_position(passage.b)) > .4: inside = true
			if inside and not world.bar_region.resident_places.has_admission(str(passage.id), identity, route.actor):
				_check(false, "actual passage body holds admission " + identity + "/" + str(passage.id))
		last[identity] = {"at": at, "phase": phase, "transition": transition}
	for name: String in world.bar_region.resident_places._passages:
		var value: Dictionary = world.bar_region.resident_places._passages[name]
		var active_id := str(value.active.get("resident", ""))
		var previous: Dictionary = passage_before.get(name, {"active": "", "queue": []})
		if not active_id.is_empty() and active_id != previous.active:
			if not previous.queue.is_empty() and str(previous.queue[0]) != active_id:
				_check(false, "observed passage promotion keeps FIFO order " + name)
			if not routes.has(active_id) or not _exact_owner(value.active, routes[active_id].actor):
				_check(false, "passage admission belongs to exact registered actor " + name)
			details.admissions.append({"passage": name, "resident": active_id, "stage": stage, "previous_queue": previous.queue})
		var queue: Array[String] = []
		for record: Dictionary in value.queue: queue.append(str(record.resident))
		passage_before[name] = {"active": active_id, "queue": queue}
	if sample_due <= 0.0 or not failures.is_empty():
		details.trace.append(_state()); sample_due = .5

func _state() -> Dictionary:
	var state := {"stage": stage, "elapsed_s": (Time.get_ticks_msec()-started)/1000.0, "actors": {}}
	if not is_instance_valid(world): return state
	for identity: String in routes:
		var route: Node3D = routes[identity]
		var doors: Array = []
		for door: DoorProp in route._door_passages:
			doors.append({"path": str(door.get_path()), "leaf": door.leaf_state, "angle": door.mechanism_snapshot(), "ready": door.is_ready_for_passage()})
		state.actors[identity] = {"feet": route.actor.global_position, "current": route.current_id, "desired": route.desired_id,
			"path": Array(route.path), "force_destination": route.force_destination, "destination": route.destination,
			"blocked_reason": route.blocked_reason, "blocked_seconds": route.blocked_seconds,
			"last_floor": route.last_floor, "metres": route.travelled_metres, "door_passages": doors,
			"phase": _phase(identity) if route._bar_route.visit != null else "retired", "transition": route._bar_route._transition}
	return state

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
	watching = false
	if is_instance_valid(world):
		for route: Node3D in routes.values(): route.set_physics_process(false)
		if not doors_restored: await _restore_probe_doors()
		details.final_state = _state()
		world.shutdown_for_tests(); remove_child(world); world.free(); world = null
	await get_tree().process_frame
	var custody := true
	if preview_owned:
		custody = _check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, prior_data), "original campaign identity and protection context restored")
	GameBoot.launch_mode = prior_mode; Input.mouse_mode = prior_mouse
	CampaignTime.set_frozen_for_tests(prior_frozen)
	_check(CampaignTime._frozen_for_tests == prior_frozen, "original clock driver test-freeze restored")
	var final_inputs := _inputs()
	custody = _check(final_inputs == initial_inputs, "runtime physical and transitive test inputs remain frozen") and custody
	_contract("roster_custody", custody)
	for name: String in REQUIRED:
		if not contracts.has(name): contracts[name] = {"executed": false, "status": "FAIL"}
		_check(bool(contracts[name].executed) and contracts[name].status == "PASS", "required contract " + name)
	var root := ProjectSettings.globalize_path("res://..").simplify_path(); var head: Array = []
	_check(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head) == 0 and not head.is_empty(), "repository provenance")
	var passed := failures.is_empty()
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": true,
		"scope": "Actual registered Rhea/guest owners, original closed/open flat route probes, one declared bed-node placement each, normal-speed forced unit:bed-bar-unit:bed travel, exact seat and passage custody. Unrelated resident controllers frozen and bodies hidden; actual player and all native world collision retained. No natural attendance, crowd stress, slope probe, actor pose-fit, rendered/artistic or save-reload acceptance.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec()-started)/1000.0},
		"source": {"test_path": "game/tests/harukiya_roster_intake_test.gd", "test_sha256": FileAccess.get_sha256(get_script().resource_path),
			"test_scene_path": "game/tests/HarukiyaRosterIntakeTest.tscn", "test_scene_sha256": FileAccess.get_sha256(scene_file_path),
			"repository_head": str(head[0]).strip_edges() if not head.is_empty() else "", "runtime_inputs_sha256": final_inputs.runtime,
			"physical_inputs_sha256": final_inputs.physical, "test_dependencies": final_inputs.dependencies},
		"contracts": contracts, "checks": checks, "failures": failures, "details": details}
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush()
	var written := file.get_error() == OK; file.close()
	print("HARUKIYA ROSTER: ", "PASS" if passed and written else "FAIL", " checks=", checks.size(), " failures=", failures.size())
	get_tree().quit(0 if passed and written else 1)
