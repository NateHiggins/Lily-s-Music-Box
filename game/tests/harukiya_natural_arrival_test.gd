extends "res://tests/harukiya_roster_intake_test.gd"
## Full live world; no fixture relocation/forced destination/hidden bystanders.
const PassageObservation := preload("res://tests/harukiya_passage_observation.gd")
const State := preload("res://scripts/game/prologue_state.gd")
const WATCH := ["rhea_sato", "transient_guests", "juno_kells"]
const TARGET := {"utc_unix_seconds": 1876273140, "local_bias_minutes": -300, "local_zone": "Fixed EST fixture"}
var clock := CampaignClock.new()
var selection: Array[Dictionary] = []
var trips: Dictionary = {}
var actor_owners: Dictionary = {}
var boundaries: Dictionary = {}
var observation_started := 0
var next_activity := 0
var activity_count := 0
var selected_places: Dictionary = {}
var log_capture
var original_hash := ""
var first_context: Dictionary = {}
var setup_only := false
var entry_probe := false
var entry_blocked_since := 0

func _run() -> void:
	setup_only = OS.get_environment("ORISON_NATURAL_SETUP_ONLY") == "1"
	entry_probe = OS.get_environment("ORISON_NATURAL_ENTRY_PROBE") == "1"
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK: get_tree().quit(2); return
	prior_data = RealityState.data; original_hash = JSON.stringify(prior_data).sha256_text()
	prior_mode = GameBoot.launch_mode; prior_mouse = Input.mouse_mode; prior_frozen = CampaignTime._frozen_for_tests
	log_capture = preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(log_capture)
	initial_inputs = _inputs()
	for key: String in ["SCHEDULE", "SCHEDULE_DAY", "SCHEDULE_DOY", "SCHEDULE_FIRST_SAT", "SCHEDULE_MINUTE", "AGENDA", "CAMPAIGN_TIME_FREEZE"]:
		_check(OS.get_environment(key).is_empty(), "no selection/time override " + key)
	if not failures.is_empty(): await _finish(); return
	preview_owned = RealityState.begin_preview_campaign(self)
	if not _check(preview_owned, "exclusive nonpersistent preview campaign"): await _finish(); return
	CampaignTime.set_frozen_for_tests(true); GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	# Existing owner-level completed-opening seam, not direct effect flag writes.
	var opening := State.request_skip(State.initial())
	for index in State.PHASES.size() - 1:
		var phase: String = State.PHASES[index]
		if phase == "companion_crossing": opening = State.applied(opening, "companion_materialized")
		if phase == "temporal_command": opening = State.with_target(opening, TARGET)
		if phase == "temporal_synchronization": break
		opening = State.advance(opening, State.PHASES[index + 1])
	RealityState.data.prologue = opening
	if not _check(clock.bind_state() and clock.apply_prologue_destination() and clock.loop_calendar_active(), "actual opening owner hands over annual clock"): await _finish(); return
	var info := clock.day_info()
	if not _check(int(info.year) == 1929 and int(info.month) == 6 and int(info.day_of_month) == 15 and info.day == "sat" and absf(clock.minute_of_day()-1319) < .00001, "immutable opening target maps June15Saturday21:59"):
		await _finish(); return
	first_context = {"opening_target": TARGET, "prologue": RealityState.data.prologue.duplicate(true),
		"clock": RealityState.data.campaign_clock.duplicate(true), "at": _stamp(), "scope": "completed-opening test context, no cinematic/prologue interaction proof"}
	world = Runtime.instantiate(); add_child(world)
	if not _check(not world.startup_failed and world.resident_agenda.enabled, "actual live world and agenda start"): await _finish(); return
	var inspected: Dictionary = Registration.inspect(world); details.registration = inspected
	for row: Dictionary in inspected.checks: _check(bool(row.ok), str(row.label))
	_check(world.resident_routes.size() == 17 and is_instance_valid(world.mina_routine), "all eighteen ordinary route owners retained")
	_check(not world.temporal_loop.in_visit(), "no loop performance visit override")
	for id: String in WATCH: routes[id] = world.resident_routes[id]
	for owner: Node3D in world.resident_routes.values():
		actor_owners[owner.actor.get_instance_id()] = owner
		_check(owner.is_physics_processing() and owner.force_destination.is_empty(), "ordinary active/unforced owner " + owner.resident)
	actor_owners[world.mina_routine.actor.get_instance_id()] = world.mina_routine
	details.initial_spawn = _snapshot()
	if setup_only:
		await _verify_grocery_reconstruction()
		await _finish(); return
	for id: String in WATCH: last[id] = {"at": routes[id].actor.global_position, "transition": str(routes[id]._bar_route._transition)}
	watching = true; stage = "pre_observation_withdrawal"
	# Only the campaign driver remains held; every world/controller/body runs.
	for frame in 2: await get_tree().process_frame; await RenderingServer.frame_post_draw
	if not _check(DisplayServer.get_name() != "headless", "windowed actual frame startup"): await _finish(); return
	if not await _clear_player_from_entry(): await _finish(); return
	details.pre_observation = _snapshot()
	_check(clock.minute_of_day() < 1320, "observation begins before22:00 after declared preparation hold")
	for id: String in IDS:
		var route: Node3D = routes[id]
		var at_bar: bool = _phase(id) == "occupied" or (route.destination == "harukiya_bar" and route.actor.global_position.distance_to(route.graph.get_point_position(route.desired_id)) < .05)
		trips[id] = {"outcome": "not_selected", "observed_arrival": false, "initial_at_bar": at_bar}
		_check(not at_bar, "target not initially spawned at bar " + id)
	if not failures.is_empty(): await _finish(); return
	CampaignTime.set_frozen_for_tests(false); observation_started = Time.get_ticks_msec(); stage = "natural_observation"
	while failures.is_empty() and Time.get_ticks_msec()-observation_started < 900000:
		if Time.get_ticks_msec() >= next_activity and _trip_active():
			_activity(); next_activity = Time.get_ticks_msec()+5000
		if boundaries.has(1350) and not _trip_active(): break
		await get_tree().physics_frame
	_check(boundaries.has(1320) and boundaries.has(1350), "ordinary clock/owners observed22:00 and22:30")
	if Time.get_ticks_msec()-observation_started >= 900000: _check(false, "natural observation900s deadline")
	await _finish()

func _verify_grocery_reconstruction() -> void:
	# Bounded actual RuntimeRoot/Route.setup check before the long observation.
	# Clock remains frozen; every ordinary resident controller remains active.
	for frame in 10: await get_tree().physics_frame
	var owner: Node3D=world.bodega_admission
	if not _check(is_instance_valid(owner), "production root installed grocery admission owner"): return
	var snapshot: Dictionary=owner.debug_snapshot(); details.grocery_reconstruction=snapshot
	var assigned: Dictionary={}
	if not snapshot.service_owner.is_empty(): assigned[str(snapshot.service_owner.resident)]="service_stance"
	for entry: Dictionary in snapshot.service.queue: assigned[str(entry.resident)]=str(entry.holding)
	var shoppers: Array[Node3D]=[]
	for id: String in ["jonah_price","rhea_sato","teresa_vale"]:
		var controller: Node3D=world.resident_routes.get(id)
		if not _check(is_instance_valid(controller) and controller.destination=="bodega", "original repro shopper naturally selects grocery "+id): continue
		shoppers.append(controller)
		_check(controller.force_destination.is_empty() and controller.is_physics_processing(), "actual unforced active grocery controller "+id)
		_check(controller.desired_id==int(controller.identities.bodega), "semantic grocery destination preserved "+id)
		if not _check(assigned.has(id), "actual shopper has distinct owned reconstruction station "+id): continue
		var marker: Node3D=owner.position_marker(assigned[id]); var gap: Vector3=controller.actor.global_position-marker.global_position
		_check(Vector2(gap.x,gap.z).length()<.06 and absf(gap.y)<.3, "actual registered body occupies its own station "+id)
		_check(controller._bodega_route.errors.is_empty(), "no route-guide refusal during actual setup "+id)
	for a in shoppers.size():
		for b in range(a+1,shoppers.size()):
			var gap: Vector3=shoppers[a].actor.global_position-shoppers[b].actor.global_position
			_check(Vector2(gap.x,gap.z).length()>=.60, "original shared-service overlap is absent in actual setup")
	details.grocery_reconstruction_scope="actual full RuntimeRoot and all ordinary registered controllers, ten frozen-clock physicsframes; no attendance/travel/player-input/crowd acceptance"

func _clear_player_from_entry() -> bool:
	var leaf := world.find_child("F01_DOOR_06_Leaf", true, false) as DoorProp
	var outbound: Dictionary = world.exterior_cell.route("ROUTE_ORISON_TO_SHOP_BODEGA")
	if not _check(leaf != null and outbound.get("nodes", []).size() >= 2 and str(outbound.nodes[1].id) == "PAVEMENT_TURN", "existing first sidewalk stance resolves"): return false
	var motor := PlayerMotor.new(); motor.service_bench_only = true; add_child(motor)
	var before := _stamp(); var station: Dictionary = outbound.nodes[1]
	var walked: bool = await motor._walk_service_player(world.player, world, world.to_local(station.placement.position))
	details.player_withdrawal = {"before": before, "after": _stamp(), "travel": motor.service_travel.duplicate(true),
		"feet": world.player.global_position, "entry_clear": leaf.opening_clear(), "driver_failures": motor.failures,
		"scope": "one actual motor trip to authored PAVEMENT_TURN; no transform/mask relocation, all residents active"}
	var ok := walked and int(motor.failures) == 0 and leaf.opening_clear(); motor.queue_free()
	world.player.set_physics_process(true) # Service helper pauses at endpoints; restore ordinary player owner.
	return _check(ok, "real player clears entry through native motor")

func _stamp() -> Dictionary:
	return {"real_s": (Time.get_ticks_msec()-started)/1000.0, "civil_minute": clock.minute_of_day(), "civil": clock.day_info(),
		"elapsed_minutes": clock.elapsed_minutes(), "pace_rate": CampaignTime.pace.rate, "pace_reason": CampaignTime.pace.reason,
		"pace_goal": str(CampaignTime.pace.goal()), "idle_seconds": world.temporal_loop._idle if is_instance_valid(world) else -1.0}

func _activity() -> void:
	var before := _stamp(); var event := InputEventMouseMotion.new()
	event.relative = Vector2(2 if activity_count % 2 == 0 else -2, 0)
	get_viewport().push_input(event)
	var after := _stamp(); activity_count += 1
	if not details.has("activity"): details.activity = []
	details.activity.append({"before": before, "after": after, "relative": event.relative})
	_check(world.temporal_loop._idle <= .00001, "viewport mouse input actually resets ordinary idle owner")

func _trip_active() -> bool:
	for id: String in IDS:
		if str(trips.get(id, {}).get("outcome", "")) == "travelling": return true
		# Do not end between a real agenda selection and the route's ordinary0.5s sample.
		if str(trips.get(id, {}).get("outcome", "")) == "not_selected" and selected_places.get(id, "") == "harukiya_bar": return true
	return false

func _snapshot() -> Dictionary:
	var row := {"stamp": _stamp(), "actors": {}}
	if not is_instance_valid(world): return row
	var info := clock.day_info()
	for id: String in WATCH:
		if not routes.has(id): continue
		var route: Node3D = routes[id]
		var raw := world.resident_presence.resolve(id, str(info.day), clock.minute_of_day(), int(info.doy), bool(info.first_sat))
		var selected := world.resident_whereabouts(id)
		selected_places[id] = str(selected.get("place", ""))
		row.actors[id] = {"raw": raw, "selected": selected, "destination": route.destination,
			"feet": route.actor.global_position, "current": route.current_id, "desired": route.desired_id, "path": Array(route.path),
			"phase": _phase(id), "transition": route._bar_route._transition, "outside": route.outside, "visible": route.actor.visible,
			"blocked": route.blocked_reason, "blocked_seconds": route.blocked_seconds, "metres": route.travelled_metres,
			"nearby_blockers": _blocking_people(route),
			"selected_window_expired": selected.has("end_min") and float(selected.end_min) < clock.minute_of_day()}
	return row

func _blocking_people(route: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if route.path.is_empty(): return result
	var at: Vector3=route.actor.global_position
	var target: Vector3=route.graph.get_point_position(route.path[0])
	var next: Vector3=at+Vector3(target.x-at.x,0,target.z-at.z).limit_length(get_physics_process_delta_time()*route.route_speed)
	for body: Node3D in route._bar_route._people():
		if body==route.actor or absf(body.global_position.y-next.y)>1.6: continue
		var separation:=.65 if body is PlayerController else .60
		var gap:=Vector2(next.x-body.global_position.x,next.z-body.global_position.z).length()
		var before:=Vector2(at.x-body.global_position.x,at.z-body.global_position.z).length()
		if gap<separation and gap<=before+.00001:
			var controller: Node3D=actor_owners.get(body.get_instance_id())
			result.append({"body":str(body.get_path()),"at":body.global_position,"gap_before":before,"gap_next":gap,
				"separation":separation,"resident":str(controller.resident) if controller!=null else "player_or_nonroute",
				"destination":str(controller.destination) if controller!=null else "", "blocked":str(controller.blocked_reason) if controller!=null else ""})
	return result

func _body(owner: Node3D) -> Dictionary:
	var seated: bool = owner._bar_route.visit != null and str(owner._bar_route.visit.phase()) == "occupied" or not str(owner._bar_route._transition).is_empty()
	var shape: CapsuleShape3D = owner._bar_route._torso if seated else owner._capsule
	return {"center": owner.actor.global_position + Vector3.UP * (.998 if seated else .25+shape.height*.5), "shape": shape, "seated": seated}

func _physics_process(delta: float) -> void:
	if not watching or not failures.is_empty(): return
	motion_frames += 1; sample_due -= delta
	if entry_probe and stage=="natural_observation" and routes.has("transient_guests"):
		var guest: Node3D=routes.transient_guests
		if guest.blocked_reason=="waiting for a person in the bar route" and absf(guest.actor.global_position.x)<1 and absf(guest.actor.global_position.y)<.3 and guest.actor.global_position.z>2 and guest.actor.global_position.z<3.5 and not _blocking_people(guest).is_empty():
			if entry_blocked_since==0: entry_blocked_since=Time.get_ticks_msec()
			elif Time.get_ticks_msec()-entry_blocked_since>2000:
				details.entry_blocker_reproduction={"scope":"early failure probe only; not attendance acceptance","state":_snapshot()}
				_check(false,"actual entry blockage reproduced with exact peer identities")
		else: entry_blocked_since=0
	for id: String in WATCH:
		var route: Node3D = routes[id]; var at: Vector3 = route.actor.global_position; var transition := str(route._bar_route._transition)
		var witness := Attendance.motion_witness(world.get_world_3d().direct_space_state, last[id].at, at, delta,
			not transition.is_empty() or not str(last[id].transition).is_empty())
		if not witness.clear: details.motion_failures.append({"resident": id, "witness": witness}); _check(false, "supported actual continuous motion " + id)
		if not route.force_destination.is_empty(): _check(false, "ordinary unforced destination " + id)
		if absf(route.route_speed-1.05) > .00001: _check(false, "ordinary route speed1.05 " + id)
		last[id] = {"at": at, "transition": transition}
		if route.outside or not route.actor.visible: continue # Record real off-map abstraction; never call it arrival.
		var body := _body(route); var hits := _world_hits(route, body.seated)
		if not hits.is_empty(): details.motion_failures.append({"resident": id, "hits": hits, "at": at}); _check(false, "full native capsule " + id)
		if _capsule_overlap(body.center, body.shape.radius, body.shape.height, world.player._shape.global_position, world.player._capsule.radius, world.player._capsule.height):
			_check(false, "target/player full-body separation " + id)
		for other: Node3D in get_tree().get_nodes_in_group("animated_residents"):
			if other == route.actor or not other.visible: continue
			var peer: Dictionary = {}
			if actor_owners.has(other.get_instance_id()): peer = _body(actor_owners[other.get_instance_id()])
			else:
				var collision := other.get_node_or_null("Body/CollisionShape3D") as CollisionShape3D
				if collision == null:
					for child in other.find_children("*", "CollisionShape3D", true, false):
						if child.get_parent().name == "Body" and child.shape is CapsuleShape3D: collision = child; break
				if collision == null: _check(false, "actual bystander body profile available " + str(other.get_path())); continue
				peer = {"center": collision.global_position, "shape": collision.shape}
			if _capsule_overlap(body.center, body.shape.radius, body.shape.height, peer.center, peer.shape.radius, peer.shape.height):
				details.motion_failures.append({"resident": id, "other": str(other.get_path()), "at": at, "other_at": other.global_position})
				_check(false, "target/bystander full-body separation " + id)
		if not _phase(id).is_empty():
			var seat := str(world.bar_region.resident_places.preferred(id).seat_id)
			if not _exact_owner(world.seat_gestures.taken.get(seat, {}), route.actor): _check(false, "actual shared seat owner " + id)
		for passage: Dictionary in route._bar_route._passages:
			var passage_points := PackedVector3Array()
			for point: int in passage.path: passage_points.append(route.graph.get_point_position(point))
			var observation := PassageObservation.classify(at, passage_points)
			if not bool(observation.valid): _check(false, "actual passage observation has valid geometry " + str(passage.id))
			if bool(observation.requires_admission) and not world.bar_region.resident_places.has_admission(str(passage.id), id, route.actor):
				var next_id: int = int(route.path[0]) if not route.path.is_empty() else -1
				if PassageObservation.is_released_departure(at, int(route.current_id), next_id, passage.path, route.graph):
					if not details.has("released_departures"): details.released_departures = {}
					var key := id + ":" + str(passage.id) + ":" + str(route.current_id)
					if not details.released_departures.has(key):
						details.released_departures[key] = {"stamp": _stamp(), "resident": id, "passage": str(passage.id),
							"current": route.current_id, "next": next_id, "feet": at, "observation": observation}
				else:
					details.passage_failure = {"resident": id, "passage": str(passage.id), "feet": at,
						"current": route.current_id, "path": Array(route.path), "observation": observation}
					_check(false, "actual passage body holds exact admission " + id + "/" + str(passage.id))
	for name: String in world.bar_region.resident_places._passages:
		var value: Dictionary = world.bar_region.resident_places._passages[name]; var active := str(value.active.get("resident", ""))
		var old: Dictionary = passage_before.get(name, {"active": "", "queue": []}); var queue: Array = []
		for item: Dictionary in value.queue: queue.append(str(item.resident))
		if not active.is_empty() and active != old.active:
			if not old.queue.is_empty(): _check(active == old.queue[0], "actual all-crowd FIFO promotion " + name)
			var owner: Node3D = world.resident_routes.get(active, world.mina_routine if active == "mina_vale" else null)
			_check(owner != null and _exact_owner(value.active, owner.actor), "admission exact live registered owner " + name)
			details.admissions.append({"resident": active, "passage": name, "stamp": _stamp(), "previous_queue": old.queue})
		passage_before[name] = {"active": active, "queue": queue}
	if sample_due > 0: return
	sample_due = .5
	var sample := _snapshot(); selection.append(sample)
	if stage != "natural_observation": return
	for minute: int in [1320, 1350]:
		if not boundaries.has(minute) and clock.minute_of_day() >= minute and world.resident_agenda.live_minute >= minute:
			boundaries[minute] = sample
	for id: String in IDS:
		var route: Node3D = routes[id]; var trip: Dictionary = trips[id]
		if trip.outcome == "not_selected" and route.destination == "harukiya_bar":
			trip.outcome = "travelling"; trip.started = Time.get_ticks_msec(); trip.from = sample; trip.metres_before = route.travelled_metres
		if trip.outcome != "travelling": continue
		if route.destination != "harukiya_bar": trip.outcome = "legitimate_retarget"; trip.ended = sample; continue
		var place: Dictionary = world.bar_region.resident_places.preferred(id)
		if _phase(id) == "occupied" and str(route._bar_route._transition).is_empty() and route.actor.global_position.distance_to(place.marker.global_position-Vector3.UP*.478) < .001:
			var crossed := true
			for name: String in ["entry_descent", "balcony_stair"]:
				var found := false
				for entry: Dictionary in details.admissions:
					if entry.resident == id and entry.passage == name and entry.stamp.real_s >= trip.from.stamp.real_s: found = true
				crossed = crossed and found
			trip.observed_arrival = crossed and route.travelled_metres > float(trip.metres_before)+.5 and not trip.initial_at_bar
			trip.outcome = "observed_arrival" if trip.observed_arrival else "arrival_not_demonstrated"; trip.ended = sample
		if Time.get_ticks_msec()-int(trip.started) >= 300000 and trip.outcome == "travelling":
			trip.outcome = "arrival_deadline"; trip.ended = sample; _check(false, "ordinary natural trip300s deadline " + id)

func _finish() -> void:
	watching = false
	if is_instance_valid(world):
		details.final_state = _snapshot(); world.shutdown_for_tests(); remove_child(world); world.free(); world = null
	await get_tree().process_frame
	if preview_owned: _check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, prior_data), "exact original preview/protection context restored")
	GameBoot.launch_mode = prior_mode; Input.mouse_mode = prior_mouse; CampaignTime.set_frozen_for_tests(prior_frozen)
	_check(JSON.stringify(prior_data).sha256_text() == original_hash, "original campaign unchanged")
	_check(CampaignTime._frozen_for_tests == prior_frozen, "original freeze custody restored")
	_check(_inputs() == initial_inputs, "runtime/physical/transitive source bindings stable")
	var errors: Array = []
	for error: String in log_capture.errors:
		if not error.contains("HARUKIYA ROSTER:"): errors.append(error)
	_check(errors.is_empty(), "no unexpected engine errors"); OS.remove_logger(log_capture)
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "production_runtime": true, "selector": "v2",
		"status": "PASS" if failures.is_empty() else "FAIL", "scope": "full all-active registered setup and grocery reconstruction only, ten frozen-clock physicsframes; no attendance claim" if setup_only else "full all-active world, completed-opening fixture context, actual natural owner selections; arrival claims only per explicit observed_arrival fields, no forced destinations or body relocation",
		"execution": {"completed": true, "exit_code": 0 if failures.is_empty() else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec()-started)/1000.0},
		"source": {"test_path": "game/tests/harukiya_natural_arrival_test.gd", "test_sha256": FileAccess.get_sha256(get_script().resource_path), "test_scene_path": "game/tests/HarukiyaNaturalArrivalTest.tscn", "test_scene_sha256": FileAccess.get_sha256(scene_file_path), "runtime_inputs_sha256": initial_inputs.get("runtime", ""), "physical_inputs_sha256": initial_inputs.get("physical", ""), "test_dependencies": initial_inputs.get("dependencies", {})},
		"contracts": {"grocery_reconstruction": {"executed": setup_only, "status": ("PASS" if failures.is_empty() else "FAIL") if setup_only else "NOT_RUN"}, "natural_observation": {"executed": not setup_only, "status": ("PASS" if failures.is_empty() else "FAIL") if not setup_only else "NOT_RUN"}, "guest_natural_arrival": {"executed": bool(trips.get("transient_guests", {}).get("observed_arrival", false)), "status": "PASS" if bool(trips.get("transient_guests", {}).get("observed_arrival", false)) and failures.is_empty() else "FAIL"}, "rhea_natural_arrival": {"executed": bool(trips.get("rhea_sato", {}).get("observed_arrival", false)), "status": "PASS" if bool(trips.get("rhea_sato", {}).get("observed_arrival", false)) and failures.is_empty() else "FAIL"}},
		"diagnostic_mode": "entry_fast_failure" if entry_probe else ("setup_only" if setup_only else "default_attendance"), "initial_context": first_context, "source_inputs": initial_inputs, "details": details, "selection_trace": selection,
		"boundary_observations": boundaries, "natural_arrivals": trips, "checks": checks, "failures": failures, "engine_errors": errors,
		"claim_limit": "PASS validates completed observation/guards; a not_selected, legitimate_retarget or arrival_not_demonstrated result never proves attendance. Initial selected-endpoint spawns are preparation facts, never observed arrivals."}
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush(); var written := file.get_error() == OK; file.close()
	get_tree().quit(0 if failures.is_empty() and written else 1)
