extends Node
## Loaded production state owners with artificial places: no native geometry,
## authored route travel, calendar attendance, input, native clips or play claim.
## Lifecycle probes use synthetic actors and an empty isolated physics world.
const Registry := preload("res://scripts/building/orison_v2_bar_resident_places.gd")
const Visit := preload("res://scripts/characters/orison_v2_bar_visit.gd")
const Seats := preload("res://scripts/player/seat_gestures.gd")
const BarRoute := preload("res://scripts/characters/orison_v2_bar_route.gd")
const INPUTS := ["res://scripts/building/orison_v2_bar_resident_places.gd",
	"res://scripts/characters/orison_v2_bar_visit.gd", "res://scripts/props/bar_seat_zone.gd",
	"res://tests/orison_v2_bar_reservation_test.gd", "res://tests/OrisonV2BarReservationTest.tscn",
	"res://scripts/player/seat_gestures.gd", "res://scripts/characters/orison_v2_bar_route.gd",
	"res://scripts/characters/orison_v2_resident_route.gd"]

class LifecycleWorld extends Node3D:
	var bar_region: Node3D
	var player: Node3D

class LifecycleRegion extends Node3D:
	var destination: Node3D
	var resident_places: Node3D

class LifecycleActor extends Node3D:
	var model_path := "synthetic_lifecycle_actor"
	func _set_walking(_on: bool) -> void: pass
	func _play_named(_clip: String) -> void: pass
	func play_seated() -> bool: return true

class LifecycleRoute extends Node3D:
	var world: Node3D
	var graph := AStar3D.new()
	var actor: Node3D
	var resident := "rhea_sato"
	var destination := "harukiya_bar"
	var current_id := 0
	var desired_id := 0
	var path := PackedInt64Array()
	var identities := {"bar_fixture_approach": 0}
	var blocked_reason := ""

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var _initial: Dictionary
var _started := 0

func check(label: String, ok: bool) -> void:
	checks.append({"label": label, "passed": ok})
	if not ok: failures.append(label)
	print("BAR RESERVATION: ", label, " = ", ok)

func _ready() -> void:
	_started = Time.get_ticks_msec()
	_initial = _inputs()
	var registry := Registry.new()
	add_child(registry)
	var seat := BarSeatZone.new()
	add_child(seat)
	registry.places = {"mina_vale": {"player_socket": seat},
		"lena_ortiz": {"furniture": "fixture_lena"}, "rhea_sato": {"furniture": "fixture_rhea"}}
	var mina := _body()
	var lena := _body()
	var rhea := _body()
	var impostor := _body()
	check("cannot occupy without reserving", not registry.occupy("mina_vale", mina))
	check("unknown resident refused", not registry.reserve("missing", mina))
	seat.seated = true
	check("player seat wins; failed reserve has no claim or mark", not registry.reserve("mina_vale", mina)
		and registry.claims.is_empty() and seat.occupied_by.is_empty())
	seat.seated = false
	seat.occupied_by = "foreign"
	check("foreign seat ownership is preserved", not registry.reserve("mina_vale", mina) and seat.occupied_by == "foreign")
	seat.occupied_by = ""
	check("reserve atomically excludes the player", registry.reserve("mina_vale", mina)
		and registry.phase("mina_vale", mina) == "reserved" and seat.occupied_by == "mina_vale")
	check("same body retry is idempotent", registry.reserve("mina_vale", mina) and registry.claims.size() == 1)
	check("another body cannot impersonate resident", not registry.reserve("mina_vale", impostor))
	check("one body cannot take another resident's place", not registry.reserve("lena_ortiz", mina))
	check("wrong owner cannot occupy or release", not registry.occupy("mina_vale", impostor)
		and not registry.release("mina_vale", impostor) and seat.occupied_by == "mina_vale")
	seat.seated = true # Deliberately invalidate the socket between reserve and arrival.
	check("arrival rechecks player occupancy", not registry.occupy("mina_vale", mina)
		and registry.phase("mina_vale", mina) == "reserved")
	seat.seated = false
	check("arrival occupies reservation", registry.occupy("mina_vale", mina) and registry.phase("mina_vale", mina) == "occupied")
	check("departure retains exclusion", registry.begin_departure("mina_vale", mina)
		and registry.phase("mina_vale", mina) == "departing" and seat.occupied_by == "mina_vale")
	check("departing claim cannot rewind", not registry.reserve("mina_vale", mina) and not registry.occupy("mina_vale", mina))
	check("cleared approach releases exact claim", registry.release("mina_vale", mina)
		and registry.claims.is_empty() and seat.occupied_by.is_empty())
	check("bench immediate claim remains supported", registry.claim("mina_vale", mina) and registry.phase("mina_vale", mina) == "occupied")
	registry.release("mina_vale", mina)

	var holds: Array[Node3D] = [_body(), _body()]
	check("empty and duplicate holding layouts refused", not registry.configure_passage("", holds)
		and not registry.configure_passage("entry", [holds[0], holds[0]]))
	check("layout supplied holding slots configured", registry.configure_passage("entry", holds))
	check("holding node cannot be shared between passages", not registry.configure_passage("stairs", [holds[0]]))
	check("first waiter gets first slot", registry.enqueue_passage("entry", "mina_vale", mina) == holds[0])
	check("second waiter gets a distinct stable slot", registry.enqueue_passage("entry", "lena_ortiz", lena) == holds[1])
	check("full queue refuses without overflow position", registry.enqueue_passage("entry", "rhea_sato", rhea) == null)
	check("duplicate identity and actor alias cannot queue", registry.enqueue_passage("entry", "mina_vale", impostor) == null
		and registry.enqueue_passage("entry", "rhea_sato", mina) == null)
	check("busy passage cannot reconfigure", not registry.configure_passage("entry", holds))
	check("unclear passage and out of order entry refused", not registry.try_admit("entry", "mina_vale", mina, false)
		and not registry.try_admit("entry", "lena_ortiz", lena, true))
	check("head waiter enters with physical clearance", registry.try_admit("entry", "mina_vale", mina, true))
	check("admission retry and holding identity stable", registry.has_admission("entry", "mina_vale", mina)
		and registry.try_admit("entry", "mina_vale", mina, true) and registry.enqueue_passage("entry", "mina_vale", mina) == holds[0])
	check("blocked clearance does not revoke active token", not registry.try_admit("entry", "mina_vale", mina, false)
		and registry.has_admission("entry", "mina_vale", mina))
	check("active passage excludes follower", not registry.try_admit("entry", "lena_ortiz", lena, true))
	check("wrong body cannot release token", not registry.leave_passage("entry", "mina_vale", impostor))
	check("active owner releases token", registry.leave_passage("entry", "mina_vale", mina))
	check("follower's waiting position does not shift", registry.enqueue_passage("entry", "lena_ortiz", lena) == holds[1])
	check("later waiter reuses free slot without jumping queue", registry.enqueue_passage("entry", "rhea_sato", rhea) == holds[0]
		and not registry.try_admit("entry", "rhea_sato", rhea, true))
	check("next FIFO owner enters", registry.try_admit("entry", "lena_ortiz", lena, true))
	lena.free()
	check("freed crossing owner releases token", registry.try_admit("entry", "rhea_sato", rhea, true))
	registry.leave_passage("entry", "rhea_sato", rhea)
	check("cancel waiter removes its queue entry", registry.enqueue_passage("entry", "mina_vale", mina) == holds[0]
		and registry.leave_passage("entry", "mina_vale", mina) and not registry.try_admit("entry", "mina_vale", mina, true))
	check("reuse validates exact holding nodes without resetting FIFO", registry.matches_passage("entry", holds)
		and not registry.matches_passage("entry", [holds[1], holds[0]]))
	check("opposite-side waiter uses only its authored side", registry.enqueue_passage("entry", "rhea_sato", rhea, [1]) == holds[1])
	check("same owner cannot move a stable slot across passage", registry.enqueue_passage("entry", "rhea_sato", rhea, [0]) == null)
	check("full side cannot spill into opposite free slot", registry.enqueue_passage("entry", "mina_vale", mina, [1]) == null)
	check("other side can wait while global FIFO remains ordered", registry.enqueue_passage("entry", "mina_vale", mina, [0]) == holds[0]
		and not registry.try_admit("entry", "mina_vale", mina, true))
	check("invalid side indices do not allocate a slot", registry.enqueue_passage("entry", "lena_ortiz", impostor, [99]) == null)
	check("opposing head enters first", registry.try_admit("entry", "rhea_sato", rhea, true))
	registry.leave_passage("entry", "rhea_sato", rhea)
	check("opposite follower enters after exact release", registry.try_admit("entry", "mina_vale", mina, true))
	registry.leave_passage("entry", "mina_vale", mina)

	check("weak claim starts", registry.reserve("mina_vale", mina))
	mina.queue_free()
	await get_tree().create_timer(.65).timeout
	check("normal cleanup retires dead claim and player mark", registry.claims.is_empty() and seat.occupied_by.is_empty())
	check("replacement actor can claim retired identity", registry.reserve("mina_vale", impostor))
	registry.release("mina_vale", impostor)
	check("weak holding fixture queued", registry.enqueue_passage("entry", "rhea_sato", rhea) == holds[0])
	holds[0].free()
	check("deleted waiting point cannot admit its waiter", not registry.try_admit("entry", "rhea_sato", rhea, true))
	check("remaining valid slot can be requested", registry.enqueue_passage("entry", "rhea_sato", rhea) == holds[1])
	registry.cancel_visit("rhea_sato", rhea)
	check("cancellation releases queue as well as seat", not registry.try_admit("entry", "rhea_sato", rhea, true))

	var visit := Visit.new()
	check("adapter refuses a plain node and missing identity", not visit.bind(rhea, "rhea_sato", rhea)
		and not visit.bind(registry, "missing", rhea))
	check("adapter binds existing body only once", visit.bind(registry, "rhea_sato", rhea) and not visit.bind(registry, "lena_ortiz", impostor))
	var pose := rhea.transform
	var child_count := get_child_count()
	check("adapter requires departure before release", visit.reserve() and visit.occupy() and not visit.finish_departure())
	check("adapter departure completes", visit.begin_departure() and visit.finish_departure() and visit.phase().is_empty())
	check("adapter queue uses same registry", visit.wait_at("entry") == holds[1] and visit.try_enter("entry", true))
	visit.cancel()
	check("adapter cancellation releases token", not registry.has_admission("entry", "rhea_sato", rhea))
	check("adapter did not move or spawn a body", rhea.transform == pose and get_child_count() == child_count)
	check("foreign mark survives cancelled claim", registry.reserve("mina_vale", impostor))
	seat.occupied_by = "foreign"
	registry.release("mina_vale", impostor)
	check("release does not erase foreign socket owner", seat.occupied_by == "foreign")
	seat.occupied_by = ""
	check("registry shutdown fixture claimed", registry.reserve("mina_vale", impostor))
	registry.queue_free()
	await get_tree().process_frame
	check("registry teardown releases its player socket", seat.occupied_by.is_empty())
	check("retired registry makes adapter fail closed", not visit.reserve() and visit.wait_at("entry") == null)
	visit.cancel()
	_direct_seat_authority()
	_missing_bar_attach()
	for scenario: String in ["normal_revisit", "cancel_seating", "cancel_departure"]:
		await _route_lifecycle(scenario)
	var route_adapter := BarRoute.new()
	check("route adapter loads without creating an actor or authority", route_adapter.route == null and route_adapter.visit == null)
	check("executed source stayed frozen", _inputs() == _initial)
	_write_contract()
	print("BAR RESERVATION TEST: ", checks.size(), " checks; ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func _direct_seat_authority() -> void:
	var registry := Registry.new(); add_child(registry)
	var seats := Seats.new(); add_child(seats)
	var marker := _body()
	var actor := _body()
	var other := _body()
	seats.seats = {"fixture_seat": {"area": marker, "yaw": 0.0, "streamed": false}}
	registry.places = {"mina_vale": {"seat_id": "fixture_seat"}}
	check("destination reservation fails before shared hand owner binds", not registry.reserve("mina_vale", actor))
	check("destination binds the hand's real seat dictionary", registry.bind_seat_gestures(seats))
	seats.seat_id = "fixture_seat"; seats.held = true
	check("player mid-grip excludes NPC atomically", not registry.reserve("mina_vale", actor) and seats.taken.is_empty())
	seats.held = false
	check("player settled or returning still excludes NPC", not registry.reserve("mina_vale", actor))
	seats.seat_id = ""
	check("NPC reserves hand authority", registry.reserve("mina_vale", actor) and seats.taken.has("fixture_seat"))
	check("previously offered player grip refuses after NPC reserve", not seats._begin("fixture_seat", null) and not seats.held)
	check("different body cannot release hand reservation", not seats.release("fixture_seat", "mina_vale", other))
	check("occupation and departure retain the hand reservation", registry.occupy("mina_vale", actor)
		and registry.begin_departure("mina_vale", actor) and seats.taken.has("fixture_seat"))
	check("registry release clears hand reservation", registry.release("mina_vale", actor) and seats.taken.is_empty())
	seats.taken["fixture_seat"] = "external_owner"
	check("legacy foreign taken entries stay authoritative", not registry.reserve("mina_vale", actor))
	seats.prune_taken()
	check("weak cleanup preserves external taken entry", seats.taken.get("fixture_seat") == "external_owner")
	seats.taken.clear()
	check("weak hand reservation starts", registry.reserve("mina_vale", actor))
	actor.free(); registry.prune_stale()
	check("dead owner clears both registry and hand authority", registry.claims.is_empty() and seats.taken.is_empty())
	check("replacement body takes the same identity", registry.reserve("mina_vale", other))
	marker.free()
	check("retired physical socket rejects occupation", not registry.occupy("mina_vale", other))
	registry.cancel_visit("mina_vale", other)
	check("cancel still releases missing socket's reservation", seats.taken.is_empty())
	registry.free(); seats.free(); other.free()

func _missing_bar_attach() -> void:
	var owner := LifecycleRoute.new(); add_child(owner)
	owner.graph.add_point(0, Vector3.ZERO)
	var absent_world := Node3D.new(); add_child(absent_world)
	owner.world = absent_world
	check("attach refuses a world without a bar property", not BarRoute.new().attach(owner))
	var world := LifecycleWorld.new(); add_child(world)
	owner.world = world
	check("attach refuses an absent optional bar", not BarRoute.new().attach(owner))
	var region := LifecycleRegion.new(); world.add_child(region); world.bar_region = region
	check("installed bar without destination remains a hard refusal", not BarRoute.new().attach(owner))
	region.destination = Node3D.new(); region.add_child(region.destination)
	check("installed destination without registry remains a hard refusal", not BarRoute.new().attach(owner))
	check("rejected attachments leave graph untouched", owner.graph.get_point_count() == 1)
	owner.free(); absent_world.free(); world.free()


func _route_lifecycle(scenario: String) -> void:
	# Production interpolation, visit and reservation owners; only the actor's
	# clip API and room geometry are replaced. This is no native seating proof.
	var viewport := SubViewport.new(); viewport.own_world_3d = true; add_child(viewport)
	var world := LifecycleWorld.new(); viewport.add_child(world)
	world.player = Node3D.new(); world.add_child(world.player); world.player.position = Vector3(20, 0, 0)
	var owner := LifecycleRoute.new(); world.add_child(owner); owner.world = world
	owner.actor = LifecycleActor.new(); owner.add_child(owner.actor)
	owner.graph.add_point(0, Vector3.ZERO)
	var registry := Registry.new(); world.add_child(registry)
	var marker := Marker3D.new(); world.add_child(marker)
	marker.position = Vector3(0, BarRoute.PROVISIONAL_SEATED_SUPPORT, -.6)
	var socket := BarSeatZone.new(); world.add_child(socket); socket.position = marker.position
	var seats := Seats.new(); world.add_child(seats)
	seats.seats = {"lifecycle_seat": {"area": marker, "yaw": 0.0, "streamed": false}}
	registry.places[owner.resident] = {"player_socket": socket, "marker": marker,
		"seat_id": "lifecycle_seat", "furniture": "synthetic_lifecycle_seat", "npc_yaw": 0.0,
		"approach": Vector3.ZERO, "approach_node": "fixture_approach", "floor_y": 0.0}
	check(scenario + " binds the single shared seat owner", registry.bind_seat_gestures(seats))
	var adapter := BarRoute.new()
	adapter.route = owner; adapter.graph = owner.graph; adapter.registry = registry
	adapter._place = registry.preferred(owner.resident); adapter._approach_id = 0
	await get_tree().physics_frame; await get_tree().physics_frame
	check(scenario + " binds a fresh visit", adapter.bind_actor())
	check(scenario + " refuses accidental duplicate bind", not adapter.bind_actor())
	var visit_before = adapter.visit
	adapter.update_place(0.01)
	adapter.update_place(.25)
	var midpoint: Vector3 = owner.actor.global_position
	check(scenario + " actually moves partway into seat", midpoint.z < -.01 and midpoint.z > -.59
		and registry.phase(owner.resident, owner.actor) == "occupied"
		and _lifecycle_seat_owned_by(seats, owner.resident, owner.actor))
	if scenario != "cancel_seating":
		adapter.update_place(.75)
		check(scenario + " reaches synthetic seat", owner.actor.global_position.is_equal_approx(Vector3(0, 0, -.6)))
		owner.destination = "unit"
		adapter.update_place(.25)
		midpoint = owner.actor.global_position
		check(scenario + " actually moves partway out with reservation", midpoint.z < -.01 and midpoint.z > -.59
			and registry.phase(owner.resident, owner.actor) == "departing" and socket.occupied_by == owner.resident
			and _lifecycle_seat_owned_by(seats, owner.resident, owner.actor))
	if scenario == "normal_revisit":
		adapter.update_place(.75)
		check("normal departure releases at approach", owner.actor.global_position.is_equal_approx(Vector3.ZERO)
			and registry.phase(owner.resident, owner.actor).is_empty() and socket.occupied_by.is_empty()
			and seats.taken.is_empty())
		owner.destination = "harukiya_bar"
		# Advance through the real retry interval before the new seat transition.
		for tick in 8: adapter.update_place(.25)
		check("normal return reuses live visit without rebind", adapter.visit == visit_before
			and registry.phase(owner.resident, owner.actor) == "occupied"
			and _lifecycle_seat_owned_by(seats, owner.resident, owner.actor)
			and owner.actor.global_position.is_equal_approx(Vector3(0, 0, -.6)))
	else:
		var hold := Marker3D.new(); world.add_child(hold)
		check(scenario + " acquires a real registry token before cancel", registry.configure_passage("lifecycle", [hold])
			and adapter.visit.wait_at("lifecycle") == hold and adapter.visit.try_enter("lifecycle", true))
		var cancelled_pose: Transform3D = owner.actor.transform
		adapter.cancel(); adapter.cancel()
		check(scenario + " cancellation releases seat and passage", registry.phase(owner.resident, owner.actor).is_empty()
			and socket.occupied_by.is_empty() and seats.taken.is_empty() and not registry.has_admission("lifecycle", owner.resident, owner.actor))
		# An unchanged or resampled bar destination cannot revive retired work.
		owner.destination = "harukiya_bar"
		var inert := true
		for tick in 4:
			inert = not adapter.update_place(.5) and inert
			adapter.guide_path()
		check(scenario + " later ticks neither move nor resurrect", inert and owner.actor.transform == cancelled_pose
			and registry.phase(owner.resident, owner.actor).is_empty() and socket.occupied_by.is_empty()
			and seats.taken.is_empty())
		check(scenario + " retired bar crossing requires rebind", not adapter.clear_step(owner.actor.global_position))
		var replacement := LifecycleActor.new(); world.add_child(replacement)
		check(scenario + " released seat can have a new exact owner", registry.reserve(owner.resident, replacement)
			and registry.occupy(owner.resident, replacement))
		adapter.update_place(1.0); adapter.cancel()
		check(scenario + " retired owner cannot move or erase replacement", owner.actor.transform == cancelled_pose
			and registry.phase(owner.resident, replacement) == "occupied"
			and _lifecycle_seat_owned_by(seats, owner.resident, replacement))
		registry.release(owner.resident, replacement)
		check(scenario + " explicit rebind creates a fresh idle handle", adapter.bind_actor()
			and adapter.visit != visit_before and registry.phase(owner.resident, owner.actor).is_empty())
	adapter.cancel()
	viewport.free()


func _lifecycle_seat_owned_by(seats: Node3D, resident: String, actor: Node3D) -> bool:
	var record: Variant = seats.taken.get("lifecycle_seat")
	return record is Dictionary and str(record.get("resident", "")) == resident \
		and record.get("owner") is WeakRef and record.owner.get_ref() == actor


func _body() -> Node3D:
	var body := Node3D.new()
	add_child(body)
	return body

func _inputs() -> Dictionary:
	var result := {}
	for path: String in INPUTS:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	return result

func _write_contract() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty():
		failures.append("SHOT_DIR required for state contract")
		return
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		failures.append("contract directory unavailable")
		return
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if file == null:
		failures.append("contract output unavailable")
		return
	var passed := failures.is_empty()
	file.store_string(JSON.stringify({"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2",
		"production_runtime": false, "scope": "Loaded production reservation/visit owners and route lifecycle in artificial state fixtures. Synthetic actor clip API and empty isolated physics world exercise seat/departure interpolation, cancellation and normal revisit. No native geometry, authored route travel, input, calendar, save, native animation, performance or artistic acceptance.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false,
			"elapsed_s": (Time.get_ticks_msec() - _started) / 1000.0},
		"source": {"test_path": "game/tests/orison_v2_bar_reservation_test.gd",
			"test_sha256": _initial[INPUTS[3]], "test_scene_path": "game/tests/OrisonV2BarReservationTest.tscn",
			"test_scene_sha256": _initial[INPUTS[4]], "test_dependencies": _initial},
		"contracts": {"reservation_state_fixture": {"executed": true, "status": "PASS" if passed else "FAIL"}},
		"checks": checks, "failures": failures}, "\t"))
	file.flush()
	if file.get_error() != OK: failures.append("contract flush failed")
