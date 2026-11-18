extends Node
## Nearby native integration: the installed route owners, bodies, capsules,
## physical doors and floor choose destinations from the real visit clock.
## Initial marks are declared fixtures, never claims of the complete stair trip.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const State := preload("res://scripts/game/prologue_state.gd")
const ErrorCapture := preload("res://tests/guide_bell_error_capture.gd")
const PAIRS := [
	{"anchor": "tea", "host": "mae_kessler", "guest": "nadia_quell", "place": "visit:6C", "entry": "F06_DOOR_06_Leaf", "minute": 10.0},
	{"anchor": "drama", "host": "cal_dwyer", "guest": "juno_kells", "place": "visit:5B", "entry": "F05_DOOR_03_Leaf", "minute": 0.0}]
const REQUIRED := ["tea_arrival", "tea_locked", "drama_arrival", "drama_locked", "native_continuity", "arrival_dialogue_gate", "campaign_restoration"]

var world: OrisonV2RuntimeRoot
var loop: Node
var performance: Node
var player: PlayerController
var camera: Camera3D
var logger
var directory := ""
var started := Time.get_ticks_msec()
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var contracts: Dictionary = {}
var details: Dictionary = {"cases": []}
var initial_inputs: Dictionary = {}
var prior_data: Dictionary = {}
var prior_mode := 0
var prior_mouse := 0
var clock_driver: Node
var prior_clock_frozen := false
var preview_owned := false
var finishing := false
var watchdog_expired := false
var watching := false
var routes: Dictionary = {}
var last: Dictionary = {}
var trace: Array[Dictionary] = []
var samples_due := 0.0
var case_label := ""
var case_started := 0
var blocked_case := false
var entry: DoorProp
var pair: Dictionary = {}
var host_wait_seen := false
var host_departed := false
var host_wait_arrived := false
var host_start := Vector3.ZERO
var guest_arrived_seen := false
var host_return_seen := false
var guest_prompt_early := false
var progress_due := 0.0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	if not ok and label not in failures: failures.append(label)
	print("LOOP WORLD: ", label, " = ", ok)
	return ok

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if not _check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK, "explicit writable SHOT_DIR"):
		get_tree().quit(2); return
	logger = ErrorCapture.new(); OS.add_logger(logger)
	initial_inputs = _inputs()
	prior_data = RealityState.data; prior_mode = GameBoot.launch_mode; prior_mouse = Input.mouse_mode
	preview_owned = RealityState.begin_preview_campaign(self)
	if not _check(preview_owned, "exclusive nonpersistent preview campaign"):
		await _finish(); return
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	_check(DisplayServer.get_name() != "headless", "windowed native world required")
	_check(CampaignClock.new().configure_date(1928, 11, 10, 1380), "private starting calendar")
	if not failures.is_empty(): await _finish(); return
	# A bounded watchdog also leaves a receipt if an awaited scene never settles.
	get_tree().create_timer(600.0).timeout.connect(_watchdog)
	print("LOOP WORLD: composing actual V2 world")
	world = Runtime.instantiate(); add_child(world)
	if not await _until(func(): return world.startup_failed or world.startup_ms > 0.0, "world startup completes", 120.0):
		await _finish(); return
	if not _check(not world.startup_failed, "actual V2 world starts"):
		await _finish(); return
	loop = world.temporal_loop; performance = world.loop_performances; player = world.player
	if not _check(loop != null and performance != null and performance.errors.is_empty(), "installed loop and performance owners"):
		await _finish(); return
	clock_driver = get_tree().get_first_node_in_group("campaign_time_owner")
	if clock_driver != null:
		prior_clock_frozen = bool(clock_driver.get("_frozen_for_tests"))
		clock_driver.set_frozen_for_tests(true)
	var opening := State.request_skip(State.initial())
	for index in State.PHASES.size() - 1:
		var phase: String = State.PHASES[index]
		if phase == "companion_crossing": opening = State.applied(opening, "companion_materialized")
		if phase == "temporal_command":
			opening = State.with_target(opening, {"utc_unix_seconds": 1856345696, "local_bias_minutes": -300, "local_zone": "Test"})
		if phase == "temporal_synchronization": break
		opening = State.advance(opening, State.PHASES[index + 1])
	RealityState.data.prologue = opening
	if not _check(world.campaign_clock.apply_prologue_destination(), "authored historical year adopted"):
		await _finish(); return
	# This fixture qualifies route/acting integration, not clue earning or fares.
	# The declared pinned notebook page admits the existing drama anchor.
	loop.ledger().items["jonah_page"] = {"pinned": true, "anchor": "notebook", "run": 1}
	loop.ledger().bank_cents = 5000
	loop.aide().quiet = true
	_freeze_routes()
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	camera = Camera3D.new(); camera.name = "LoopReviewCamera"
	camera.cull_mask = player.camera.cull_mask
	world.add_child(camera); camera.make_current()
	var companion: Variant = world.get("service_set_carrier")
	if companion is Node3D: companion.hide()
	await get_tree().physics_frame; await get_tree().physics_frame
	for spec: Dictionary in PAIRS:
		for locked: bool in [false, true]:
			if not await _case(spec, locked):
				await _finish(); return
	contracts.native_continuity = {"executed": true, "status": "PASS" if failures.is_empty() else "FAIL"}
	contracts.arrival_dialogue_gate = {"executed": true, "status": "PASS" if not guest_prompt_early and failures.is_empty() else "FAIL"}
	await _finish()

func _freeze_routes() -> void:
	watching = false
	var all_routes: Array = world.resident_routes.values()
	if world.mina_routine != null: all_routes.append(world.mina_routine)
	for owner: Node3D in all_routes:
		owner.set_physics_process(false)
		if owner.get("_bar_route") != null: owner._bar_route.cancel()
		if owner.get("actor") != null:
			owner.actor._set_walking(false); owner.actor.hide()
	for body: Node3D in get_tree().get_nodes_in_group("animated_residents"): body.hide()

func _case(spec: Dictionary, locked: bool) -> bool:
	_freeze_routes()
	if loop.in_visit() and not _check(loop.go_home().ok, "previous fixture visit returns home"): return false
	pair = spec.duplicate(); blocked_case = locked
	case_label = str(spec.anchor) + ("_locked" if locked else "_arrival")
	print("LOOP WORLD: starting ", case_label)
	trace.clear(); routes.clear(); last.clear()
	host_wait_seen = false; guest_arrived_seen = false; host_return_seen = false
	host_departed = false; host_wait_arrived = false
	if not _check(loop.jump(str(spec.anchor)).ok, case_label + " actual jump admitted"): return false
	if float(spec.minute) > 0.0:
		if not _check(world.campaign_clock.advance_to(world.campaign_clock.elapsed_minutes() + float(spec.minute)), case_label + " declared phase minute"): return false
	var host: Node3D = world.resident_routes.get(str(spec.host))
	var guest: Node3D = world.resident_routes.get(str(spec.guest))
	entry = world.find_child(str(spec.entry), true, false) as DoorProp
	if not _check(host != null and guest != null and host.actor != null and guest.actor != null and entry != null, case_label + " native pair and entry present"): return false
	var host_vertex := int(host.identities.get("main", -1))
	var host_entry := int(host.identities.get("entry_out", -1))
	if not _check(host_vertex >= 0 and host_entry >= 0, case_label + " authored host main and threshold vertices"): return false
	var guest_vertex := -1
	var wanted: Vector3 = host.graph.get_point_position(host_entry)
	for point: int in guest.graph.get_point_ids():
		if guest.graph.get_point_position(point).distance_squared_to(wanted) < 0.000001:
			guest_vertex = point; break
	if not _check(guest_vertex >= 0 and guest.places.has(str(spec.place)), case_label + " copied host graph connects actual guest"): return false
	# Reconstruct initial physical door/lock state through the existing owners.
	# No key is lent or added to the visitor, and no door is touched after start.
	entry.restore_mechanism({"angle": 0.0})
	DoorKeyring.remember_lock(entry, locked)
	entry.leaf_state = DoorKeyring.initial_state(entry, "closed")
	entry._relock_after_close = false
	_check(entry.leaf_state == ("locked" if locked else "closed") and not entry.open, case_label + " declared real entry state")
	_check(not DoorKeyring.resident_has_key(str(spec.guest), entry), case_label + " visitor has no host key")
	_check(DoorKeyring.resident_has_key(str(spec.host), entry), case_label + " host retains original key")
	_place(host, host_vertex); _place(guest, guest_vertex)
	host_start = host.actor.global_position
	routes[str(spec.host)] = host; routes[str(spec.guest)] = guest
	# Keep the real player's full capsule outside this isolated indoor route.
	# Its controller is paused, never shrunk or excluded by this fixture's logic.
	player.global_position = world.adapter.root.to_global(Vector3(0, 0.02, -8.5))
	player.velocity = Vector3.ZERO
	var starts := {}
	for identity: String in routes:
		var route: Node3D = routes[identity]
		starts[identity] = {"vertex": route.current_id, "at": route.actor.global_position,
			"source_path": route.source_path, "model": route.actor.model_path, "route_speed": route.route_speed}
		last[identity] = route.actor.global_position
		_check(is_equal_approx(float(route.route_speed), 1.05), case_label + " production speed " + identity)
	await get_tree().physics_frame; await get_tree().physics_frame
	_check(performance.conversation_prompt(str(spec.guest)).is_empty(), case_label + " no visitor reply before arrival")
	var host_block: Dictionary = world.resident_whereabouts(str(spec.host))
	host_wait_seen = str(host_block.get("place", "")) == "unit:kitchen"
	_check(host_wait_seen, case_label + " host clears shared approach first")
	if not failures.is_empty(): return false
	case_started = Time.get_ticks_msec(); samples_due = 0.0; progress_due = 0.0; watching = true
	host.set_physics_process(true); guest.set_physics_process(true)
	var reached := false
	if locked:
		reached = await _until(func(): return host_wait_arrived and host_departed and _host_at_phase(), case_label + " physical host wait and bounded solo return arrive", 90.0)
		if reached:
			_check(not performance._arrived(str(spec.guest)) and entry.leaf_state == "locked" and not entry.open,
				case_label + " locked guest remains refused without key or leaf bypass")
			_check(guest.actor.global_position.distance_to(guest.graph.get_point_position(int(guest.identities[str(spec.place) + ":arrival"]))) > 0.5,
				case_label + " no remote arrival")
			_check(performance.conversation_prompt(str(spec.guest)).is_empty(), case_label + " no locked guest dialogue")
	else:
		reached = await _until(func(): return host_departed and guest_arrived_seen and _host_at_phase(),
			case_label + " real pair arrives by ordinary route", 90.0)
		if reached:
			_check(not performance.conversation_prompt(str(spec.guest)).is_empty(), case_label + " arrived guest has authored optional line")
			_check(_speak(str(spec.guest)), case_label + " arrived guest line uses actual dialogue owner")
	if reached:
		_check(not performance.conversation_prompt(str(spec.host)).is_empty(), case_label + " host work remains speakable")
		_check(_speak(str(spec.host)), case_label + " host optional line leaves case and knowledge intact")
	watching = false; host.set_physics_process(false); guest.set_physics_process(false)
	if reached:
		await _capture(str(spec.host), "host_front", false)
		await _capture(str(spec.host), "host_side", true)
		if not locked:
			await _capture(str(spec.guest), "guest_front", false)
			await _capture(str(spec.guest), "guest_side", true)
	var okay := reached and failures.is_empty()
	contracts[case_label] = {"executed": true, "status": "PASS" if okay else "FAIL"}
	details.cases.append({"id": case_label, "elapsed_s": (Time.get_ticks_msec() - case_started) / 1000.0,
		"starts": starts, "clock_phase": loop.loop_minutes(), "entry_lock": entry.leaf_state,
		"host_wait_seen": host_wait_seen, "guest_arrived": guest_arrived_seen, "host_return_seen": host_return_seen,
		"host_departed": host_departed, "host_wait_arrived": host_wait_arrived,
		"final": _route_details(), "trace": trace.duplicate(true)})
	return okay

func _place(route: Node3D, vertex: int) -> void:
	route.current_id = vertex; route.path.clear(); route.planned_id = -1; route.desired_id = -1
	route.force_destination = ""; route._sample = 0.0
	route._door_passages.clear()
	route.blocked_seconds = 0.0; route.blocked_reason = ""
	route._set_outside(false); route.actor.show()
	route.actor.global_position = route.graph.get_point_position(vertex)
	route.actor._set_walking(false)

func _host_at_phase() -> bool:
	var host: String = pair.host
	var phase: Dictionary = performance.phase_for(host)
	# A new requested block does not mean the route's half-second sampler has
	# accepted it yet. Arrival at the old kitchen target is not return to work.
	return host_return_seen and str(routes[host].destination) == str(phase.get("place", "")) and performance._arrived(host)

func _speak(identity: String) -> bool:
	var before := _consequence_snapshot()
	if not performance.try_conversation(identity, player): return false
	var panel: CaseDialoguePanel = world.conversations.dialogue
	var shown := panel.attention_active() and world.conversations.performance_active()
	panel.choose(0)
	return shown and not panel.attention_active() and before == _consequence_snapshot()

func _consequence_snapshot() -> Dictionary:
	var result := {}
	for key: String in ["knowledge_flags", "conversation_visits", "resident_trust", "cases", "inventories", "temporal"]:
		var value: Variant = RealityState.data.get(key)
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func _until(predicate: Callable, label: String, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline and failures.is_empty() and not finishing:
		if bool(predicate.call()): return _check(true, label)
		await get_tree().physics_frame
	print("LOOP WORLD BLOCKER: ", JSON.stringify(_route_details()))
	return _check(false, label)

func _route_details() -> Dictionary:
	var result := {}
	for identity: String in routes:
		var route: Node3D = routes[identity]
		if not is_instance_valid(route) or route.actor == null: continue
		result[identity] = {"at": route.actor.global_position, "destination": route.destination,
			"current": route.current_id, "desired": route.desired_id, "path": Array(route.path),
			"blocked": route.blocked_reason, "blocked_s": route.blocked_seconds, "metres": route.travelled_metres,
			"arrived": performance._arrived(identity)}
	return result

func _physics_process(delta: float) -> void:
	if not watching or finishing: return
	samples_due -= delta; progress_due -= delta
	var host: String = pair.host; var guest: String = pair.guest
	host_departed = host_departed or routes[host].actor.global_position.distance_to(host_start) > 0.4
	host_wait_arrived = host_wait_arrived or (str(routes[host].destination) == "unit:kitchen" and performance._arrived(host))
	guest_arrived_seen = guest_arrived_seen or performance._arrived(guest)
	var block: Dictionary = world.resident_whereabouts(host)
	host_wait_seen = host_wait_seen or str(block.get("place", "")) == "unit:kitchen"
	var phase: Dictionary = performance.phase_for(host)
	host_return_seen = host_return_seen or (str(block.get("place", "")) == str(phase.get("place", "")) and host_wait_seen)
	if not performance._arrived(guest) and not performance.conversation_prompt(guest).is_empty():
		guest_prompt_early = true; _check(false, case_label + " visitor speech must wait for physical arrival")
	for identity: String in routes:
		var route: Node3D = routes[identity]
		var at: Vector3 = route.actor.global_position
		if at.distance_to(last[identity]) > 1.1 * delta + .035:
			_check(false, case_label + " continuous unforced movement " + identity)
		if not str(route.force_destination).is_empty() or not is_equal_approx(float(route.route_speed), 1.05):
			_check(false, case_label + " phase selects normal-speed route " + identity)
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = route._capsule; query.collision_mask = 1
		query.transform.origin = at + Vector3.UP * (.25 + route._capsule.height * .5)
		query.exclude = [player.get_rid()]
		var hits: Array = world.get_world_3d().direct_space_state.intersect_shape(query, 1)
		if not hits.is_empty():
			_check(false, case_label + " native capsule/leaf clearance " + identity + ": " + str(hits[0].collider.get_path()))
		last[identity] = at
	var a: Vector3 = routes[host].actor.global_position
	var b: Vector3 = routes[guest].actor.global_position
	if absf(a.y - b.y) < 1.4 and Vector2(a.x - b.x, a.z - b.z).length() < .56:
		_check(false, case_label + " native pair capsule separation")
	if samples_due <= 0.0:
		trace.append({"seconds": (Time.get_ticks_msec() - case_started) / 1000.0, "actors": _route_details(), "entry_open": entry.open, "entry_locked": entry.leaf_state == "locked"})
		samples_due = .25
	if progress_due <= 0.0:
		print("LOOP WORLD PROGRESS ", case_label, " ", JSON.stringify(_route_details()))
		progress_due = 5.0

func _capture(identity: String, suffix: String, side: bool) -> void:
	var body: Node3D = routes[identity].actor
	var at: Vector3 = body.global_position
	var offset := Vector3(1.65, 1.55, 0.20) if side else Vector3(0.15, 1.55, 1.85)
	if side and identity == "nadia_quell": offset.x = -1.65
	camera.global_position = at + world.adapter.root.global_basis * offset
	camera.look_at(at + Vector3.UP * 1.05); camera.fov = 58.0; camera.make_current()
	for frame in 3: await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(directory.path_join(case_label + "_" + suffix + ".png")) == OK,
		case_label + " native capture " + suffix)

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

func _watchdog() -> void:
	if finishing: return
	watchdog_expired = true
	_check(false, "bounded world fixture watchdog expired")
	await _finish()

func _finish() -> void:
	if finishing: return
	finishing = true; watching = false
	if is_instance_valid(world):
		world.shutdown_for_tests(); remove_child(world); world.free(); world = null
	await get_tree().process_frame
	if is_instance_valid(clock_driver): clock_driver.set_frozen_for_tests(prior_clock_frozen)
	if preview_owned:
		var restored := RealityState.end_preview_campaign(self) and is_same(RealityState.data, prior_data)
		_check(restored, "original campaign context restored")
		contracts.campaign_restoration = {"executed": true, "status": "PASS" if restored else "FAIL"}
	GameBoot.launch_mode = prior_mode; Input.mouse_mode = prior_mouse
	var final_inputs := _inputs()
	_check(final_inputs == initial_inputs, "executed runtime, physical and test inputs remain frozen")
	if logger != null:
		_check(logger.errors.is_empty(), "no native script/runtime errors: " + str(logger.errors))
		OS.remove_logger(logger)
	for contract: String in REQUIRED:
		if not contracts.has(contract): contracts[contract] = {"executed": false, "status": "FAIL"}
		_check(bool(contracts[contract].executed) and str(contracts[contract].status) == "PASS", "required contract " + contract)
	var head: Array = []; var root := ProjectSettings.globalize_path("res://..").simplify_path()
	_check(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head) == 0 and not head.is_empty(), "repository provenance")
	var passed := failures.is_empty()
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": true,
		"scope": "Actual V2 world and installed Mae/Nadia/Cal/Juno bodies after declared nearby initial placements at host main and mapped entry_out. Real visit phases select normal-speed routes, actual floor/capsules/doors, host waiting/return, blocked-guest solo fallback, arrival-gated optional dialogue. Other residents hidden/frozen; clock held at declared phase. No full stair journey, timetable reconstruction, puzzle earning, save/load or new-body/artistic qualification. Captures inspect each actual participant from two viewpoints; no fabricated same-room marks.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": watchdog_expired, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": {"test_path": "game/tests/loop_performance_world_test.gd", "test_sha256": FileAccess.get_sha256(get_script().resource_path),
			"test_scene_path": "game/tests/LoopPerformanceWorldTest.tscn", "test_scene_sha256": FileAccess.get_sha256(scene_file_path),
			"repository_head": str(head[0]).strip_edges() if not head.is_empty() else "",
			"runtime_inputs_sha256": final_inputs.runtime, "physical_inputs_sha256": final_inputs.physical, "test_dependencies": final_inputs.dependencies},
		"contracts": contracts, "checks": checks, "failures": failures, "details": details}
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush()
	var written := file.get_error() == OK; file.close()
	print("LOOP PERFORMANCE WORLD: ", "PASS" if passed and written else "FAIL", " checks=", checks.size(), " failures=", failures.size())
	get_tree().quit(0 if passed and written else 1)
