extends Node3D
## Nearby diagnostic: real region/actors/seat owner/motors, synthetic initial
## approach placements and graph street connector. No outside-world journey proof.
const Route := preload("res://scripts/characters/orison_v2_resident_route.gd")
const BarRoute := preload("res://scripts/characters/orison_v2_bar_route.gd")
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const Attendance := preload("res://tests/harukiya_attendance_test.gd")
const IDS := ["rhea_sato", "transient_guests"]
const SOURCES := ["res://tests/harukiya_balcony_departure_test.gd",
	"res://tests/HarukiyaBalconyDepartureTest.tscn", "res://tests/harukiya_attendance_test.gd",
	"res://scripts/characters/orison_v2_resident_route.gd",
	"res://scripts/characters/orison_v2_bar_route.gd", "res://scripts/characters/orison_v2_bar_visit.gd",
	"res://scripts/characters/orison_v2_resident_presentation.gd",
	"res://scripts/characters/animated_resident.gd",
	"res://scripts/building/orison_v2_bar_region.gd",
	"res://scripts/building/orison_v2_bar_destination.gd",
	"res://scripts/building/orison_v2_bar_resident_places.gd",
	"res://scripts/player/seat_gestures.gd", "res://tests/guide_bell_error_capture.gd",
	"res://scripts/player/player_controller.gd", "res://scripts/props/door_prop.gd", "res://data/orison_v2/harukiya_destination_layout.json",
	"res://data/orison_v2/rhea_sato_routine.json", "res://data/orison_v2/transient_guests_routine.json"]
class MiniWorld extends Node3D:
	var bar_region: OrisonV2BarRegion
	var player: PlayerController
	var campaign_clock := CampaignClock.new()
	var adapter: OrisonV2AnchorAdapter
	var seat_gestures: Node3D

var world: MiniWorld
var routes: Dictionary = {}
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var trace: Array[Dictionary] = []
var details: Dictionary = {}
var inputs: Dictionary = {}
var last: Dictionary = {}
var admissions := {"balcony_stair": [], "entry_descent": []}
var active_before: Dictionary = {}
var queues_before: Dictionary = {}
var watching := false
var due := 0.0
var stage := "setup"
var started := Time.get_ticks_msec()
var stable := 0.0
var anchors: Dictionary = {}
var directory := ""
var preview_owned := false
var prior_data: Dictionary
var prior_mode: int
var prior_mouse: int
var logger
var physical_inputs: Dictionary = {}

func _ready() -> void:
	process_physics_priority = 100
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "label": label})
	if not ok:
		failures.append(label)
		push_error("BALCONY DEPARTURE: " + label)
	return ok

func _hashes() -> Dictionary:
	var result := {}
	for path: String in SOURCES:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	return result

func _physical_hashes() -> Dictionary:
	var result := {}
	for path: String in ["res://assets/props/harukiya_destination.glb",
			"res://assets/building/floor_01_cells/shop_bar.gltf",
			"res://assets/building/floor_01_cells/shop_bar.bin"]:
		result[path] = FileAccess.get_sha256(path)
	return result

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if not _check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK, "explicit writable SHOT_DIR"):
		get_tree().quit(2); return
	inputs = _hashes()
	for path: String in SOURCES:
		_check(FileAccess.file_exists(path), "bound source exists " + path)
	physical_inputs = _physical_hashes()
	for path: String in physical_inputs:
		_check(not str(physical_inputs[path]).is_empty(), "bound native collision source exists " + path)
	logger = preload("res://tests/guide_bell_error_capture.gd").new()
	OS.add_logger(logger)
	prior_data = RealityState.data; prior_mode = GameBoot.launch_mode; prior_mouse = Input.mouse_mode
	preview_owned = RealityState.begin_preview_campaign(self)
	if not _check(preview_owned, "exclusive nonpersistent preview custody"):
		await _finish(); return
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	world = MiniWorld.new(); world.name = "NearbyWorld"; add_child(world)
	world.adapter = OrisonV2AnchorAdapter.new(world)
	_check(world.campaign_clock.configure_date(1929, 6, 14, 21 * 60), "valid preview clock; forced destinations own this diagnostic")
	world.bar_region = OrisonV2BarRegion.new(); world.bar_region.name = "ProductionHarukiya"; world.add_child(world.bar_region)
	if not _check(not world.bar_region.startup_failed and world.bar_region.destination != null, "ordinary native bar ready succeeds"):
		await _finish(); return
	world.player = PlayerController.new(); world.player.name = "Player"; world.add_child(world.player)
	world.player.set_physics_process(false); world.player.set_process_input(false)
	var stance := world.bar_region.destination.get_node("Navigation/pool_interaction") as Node3D
	world.player.global_position = stance.global_position + Vector3.UP * .02
	world.player.camera.make_current()
	details.player_initial = {"datum": str(stance.get_path()), "at": world.player.global_position,
		"declared_initial_placement": true, "physics_disabled": true, "collision_mask": world.player.collision_mask}
	world.seat_gestures = preload("res://scripts/player/seat_gestures.gd").new()
	world.seat_gestures.name = "SeatGestures"; world.add_child(world.seat_gestures)
	if not _check(world.seat_gestures.mount_bar(world.bar_region), "actual shared SeatGestures binds production registry"):
		await _finish(); return
	for identity: String in IDS:
		if not _create_route(identity): await _finish(); return
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(DisplayServer.get_name() != "headless", "windowed renderer required for this nearby actor diagnostic")
	details.graph = {}
	for identity: String in IDS:
		var route: Node3D = routes[identity]
		var nodes := {}
		for key: String in route.identities:
			nodes[key] = {"id": route.identities[key], "at": route.graph.get_point_position(route.identities[key]),
				"edges": Array(route.graph.get_point_connections(route.identities[key]))}
		details.graph[identity] = nodes
		last[identity] = {"at": route.actor.global_position, "transition": ""}
		anchors[identity] = route.actor.global_position
		_check(_body_clear(route), "initial full standing capsule clears native world " + identity)
	if not failures.is_empty(): await _finish(); return
	stage = "seating"; watching = true
	for identity: String in IDS: routes[identity].set_physics_process(true)
	await _until(Callable(self, "_both_seated"), 20.0, "both ordinary seat transitions complete")
	if failures.is_empty():
		stage = "departure"
		# Same frame, no actor/node/collision repositioning or path injection.
		for identity: String in IDS:
			routes[identity].force_destination = "bench_exit"
			routes[identity]._select_destination()
		await _until(Callable(self, "_both_departed"), 90.0, "both ordinary balcony departures clear the stair into distinct supported datums")
	if failures.is_empty():
		for identity: String in IDS:
			_check(admissions.balcony_stair.has(identity), "departure records actual balcony admission " + identity)
			_check(not world.bar_region.resident_places.has_admission("balcony_stair", identity, routes[identity].actor), "departure releases actual balcony admission " + identity)
		for identity: String in IDS:
			var seat := str(world.bar_region.resident_places.preferred(identity).seat_id)
			_check(not world.seat_gestures.taken.has(seat), "departure releases exact shared seat " + identity)
	await _finish()

func _create_route(identity: String) -> bool:
	var source_path := "res://data/orison_v2/%s_routine.json" % identity
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if not _check(Route.valid_route_header(source, identity), "real resident source header " + identity): return false
	var route := Route.new()
	route.name = "Route_" + identity; route.resident = identity; route.source_path = source_path
	route.world = world; route.set_physics_process(false); world.add_child(route)
	# Only this connector is test-owned. attach builds every interior graph edge,
	# holding node, passage and real door from installed production data.
	route._point("street", BarRoute.STREET_APPROACH[0])
	route._bar_route = BarRoute.new()
	if not _check(route._bar_route.attach(route), "production bar route attaches " + identity): return false
	# Stop just beyond the mechanism under test. These original, already
	# traversed datums are 2.30m apart; the lead body continues past the
	# follower's destination. Earlier remote fixture goals are retained failures.
	route.places["bench_exit"] = "bar_west_bypass" if identity == "rhea_sato" else "bar_stair_approach"
	route._capsule.radius = .28; route._capsule.height = 1.40
	route.force_destination = "harukiya_bar"; route._select_destination()
	route.current_id = route._bar_route._approach_id
	route.actor = Presentation.new()
	route.actor.setup(str(source.name), identity, str(source.unit), "res://assets/characters/%s/%s.gltf" % [identity, identity])
	route.actor.externally_driven = true; route.actor.face_interacting_player = true
	route.add_child(route.actor)
	route.actor.global_position = route.graph.get_point_position(route.current_id)
	routes[identity] = route
	return _check(route.actor._model != null and route._bar_route.bind_actor(), "real presentation and visit bind " + identity)

func _phase(route: Node3D) -> String:
	return str(route._bar_route.visit.phase())

func _both_seated() -> bool:
	for identity: String in IDS:
		var route: Node3D = routes[identity]
		if _phase(route) != "occupied" or not str(route._bar_route._transition).is_empty(): return false
		var place: Dictionary = world.bar_region.resident_places.preferred(identity)
		if route.actor.global_position.distance_to(place.marker.global_position - Vector3.UP * BarRoute.PROVISIONAL_SEATED_SUPPORT) > .001: return false
	return true

func _both_departed() -> bool:
	for identity: String in IDS:
		var route: Node3D = routes[identity]
		if route.current_id != route.desired_id or not route.path.is_empty() or not _phase(route).is_empty() or not str(route._bar_route._transition).is_empty(): return false
		if route.actor.global_position.distance_to(route.graph.get_point_position(route.desired_id)) > .05: return false
	return true

func _until(predicate: Callable, seconds: float, label: String) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while failures.is_empty() and Time.get_ticks_msec() < deadline:
		if predicate.call(): _check(true, label); return
		await get_tree().physics_frame
	if failures.is_empty(): _check(false, label + " deadline")

func _body(route: Node3D) -> Dictionary:
	var seating := _phase(route) == "occupied" or not str(route._bar_route._transition).is_empty()
	return {"shape": route._bar_route._torso if seating else route._capsule,
		"center": route.actor.global_position + Vector3.UP * (.998 if seating else .95), "seated_envelope": seating}

func _body_clear(route: Node3D) -> bool:
	var body := _body(route)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body.shape; query.collision_mask = 1
	query.transform.origin = body.center; query.exclude = [world.player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _entry(entry: Dictionary) -> Dictionary:
	var owner: Node = entry.owner.get_ref() if entry.get("owner") is WeakRef else null
	return {"resident": str(entry.get("resident", "")), "owner_id": owner.get_instance_id() if owner != null else 0, "slot": entry.get("slot", -1)}

func _physics_process(delta: float) -> void:
	if not watching or not failures.is_empty(): return
	due -= delta
	if world.player.global_position != details.player_initial.at:
		_check(false, "declared clear player stance stays fixed")
	var sample := {"elapsed_s": (Time.get_ticks_msec() - started) / 1000.0, "stage": stage, "actors": {}, "passages": {}}
	var all_waiting := stage == "departure"
	for identity: String in IDS:
		var route: Node3D = routes[identity]
		var at: Vector3 = route.actor.global_position
		var transition := str(route._bar_route._transition)
		var motion := Attendance.motion_witness(world.get_world_3d().direct_space_state, last[identity].at, at, delta,
			not transition.is_empty() or not str(last[identity].transition).is_empty())
		if not motion.clear: _check(false, "ordinary continuous supported motion " + identity)
		if _phase(route).is_empty() and transition.is_empty():
			var support := PhysicsRayQueryParameters3D.create(at + Vector3.UP * .03, at - Vector3.UP * .03, 1)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(support)
			if hit.is_empty() or absf(hit.position.y - at.y) > .003:
				_check(false, "standing feet remain on actual native floor " + identity)
		if not _body_clear(route): _check(false, "current full body clears native collision " + identity)
		if absf(route.route_speed - 1.05) > .00001: _check(false, "unchanged walking speed " + identity)
		var seat := str(world.bar_region.resident_places.preferred(identity).seat_id)
		if not _phase(route).is_empty():
			var record: Dictionary = world.seat_gestures.taken.get(seat, {})
			if record.get("owner") is not WeakRef or record.owner.get_ref() != route.actor:
				_check(false, "exact shared seat owner " + identity)
		sample.actors[identity] = {"at": at, "actor_id": route.actor.get_instance_id(), "phase": _phase(route),
			"transition": transition, "current": route.current_id, "desired": route.desired_id, "path": Array(route.path),
			"gate": route._bar_route._gate.duplicate(true), "blocked": route.blocked_reason, "metres": route.travelled_metres,
			"floor": route.last_floor, "motion": motion, "body": {"radius": _body(route).shape.radius,
			"height": _body(route).shape.height, "center": _body(route).center}}
		if at.distance_to(anchors[identity]) > .002:
			stable = 0.0
			for other: String in IDS: anchors[other] = routes[other].actor.global_position
		if not str(route.blocked_reason).contains("waiting for a person in the bar route"): all_waiting = false
		var player_at: Vector3 = world.player.global_position
		if absf(player_at.y - at.y) < 1.4 and Vector2(player_at.x - at.x, player_at.z - at.z).length() < .61:
			_check(false, "actual player and resident retain full capsule separation " + identity)
		last[identity] = {"at": at, "transition": transition}
	# Exact capsule/capsule separation, including vertical segment clearance.
	var a := _body(routes[IDS[0]]); var b := _body(routes[IDS[1]])
	var offset: Vector3 = a.center - b.center
	var axial := maxf(0, absf(offset.y) - (a.shape.height * .5 - a.shape.radius) - (b.shape.height * .5 - b.shape.radius))
	if Vector3(offset.x, axial, offset.z).length() + .00001 < a.shape.radius + b.shape.radius:
		_check(false, "real resident capsules never overlap")
	for passage: String in admissions:
		var state: Dictionary = world.bar_region.resident_places._passages[passage]
		var active := _entry(state.active)
		var queue: Array = []
		for item: Dictionary in state.queue: queue.append(_entry(item))
		if not str(active.resident).is_empty() and str(active.resident) != str(active_before.get(passage, "")):
			admissions[passage].append(active.resident)
			if not queues_before.get(passage, []).is_empty():
				_check(queues_before[passage][0].resident == active.resident, "observed admission preserves preceding FIFO head " + passage)
		active_before[passage] = active.resident; queues_before[passage] = queue
		sample.passages[passage] = {"active": active, "queue": queue}
		# A body within the stair interior must hold its exact live admission.
		for identity: String in IDS:
			var route: Node3D = routes[identity]
			for span: Dictionary in route._bar_route._passages:
				if str(span.id) != passage: continue
				var at: Vector3 = route.actor.global_position
				var low: Vector3 = route.graph.get_point_position(span.a)
				var high: Vector3 = route.graph.get_point_position(span.b)
				if at.y <= minf(low.y, high.y) + .35 or at.y >= maxf(low.y, high.y) - .35: continue
				for i in span.path.size() - 1:
					if Geometry3D.get_closest_point_to_segment(at, route.graph.get_point_position(span.path[i]), route.graph.get_point_position(span.path[i + 1])).distance_to(at) < .45:
						_check(world.bar_region.resident_places.has_admission(passage, identity, route.actor), "stair body holds exact admission " + identity + " " + passage)
	stable = stable + delta if all_waiting else 0.0
	if due <= 0 or stable >= 3.0 or not failures.is_empty():
		sample.mutual_stationary_seconds = stable; trace.append(sample); due = .2
	if stable >= 3.0:
		details.deadlock = sample
		_check(false, "mutual person-block remains stationary for three actual physics seconds")

func _finish() -> void:
	watching = false
	for route: Node3D in routes.values():
		route.set_physics_process(false)
		if route._bar_route != null: route._bar_route.cancel()
	_check(physical_inputs == _physical_hashes(), "native collision sources stable through diagnostic")
	_check(inputs == _hashes(), "LF-normalized bound sources stable through diagnostic")
	if is_instance_valid(world):
		remove_child(world); world.free()
	await get_tree().process_frame
	if preview_owned:
		_check(RealityState.end_preview_campaign(self), "preview owner releases custody")
		_check(is_same(RealityState.data, prior_data), "prior save data restored")
	GameBoot.launch_mode = prior_mode; Input.mouse_mode = prior_mouse
	# Test assertion errors are recorded above; unrelated engine errors remain failures.
	var unexpected: Array = []
	for error: String in logger.errors:
		if not error.contains("BALCONY DEPARTURE:"): unexpected.append(error)
	_check(unexpected.is_empty(), "no unexpected engine errors")
	OS.remove_logger(logger)
	var contract := {"schema_version": 2, "evidence_kind": "diagnostic", "suite": "HarukiyaBalconyDepartureTest",
		"status": "PASS" if failures.is_empty() else "FAIL", "production_runtime": false,
		"scope": "standalone production Harukiya; two real residents from declared initial seat approaches through balcony descent to original stair_approach/west_bypass datums; no backstage, outside-world, schedule, art-fit or general crowd acceptance",
		"physical_source_sha256": physical_inputs, "source_hash_algorithm": "sha256 LF-normalized text", "source_hashes": inputs,
		"checks": checks, "failures": failures, "details": details, "trace": trace, "admissions": admissions,
		"unexpected_engine_errors": unexpected, "completion": "all listed checks and preview restoration precede serialization"}
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(contract, "\t")); file.flush()
	var written := file.get_error() == OK; file.close()
	print("BALCONY DEPARTURE: %s (%d failures)" % [contract.status, failures.size()])
	get_tree().quit(0 if failures.is_empty() and written else 1)
