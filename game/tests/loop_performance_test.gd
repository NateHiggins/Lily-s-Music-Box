extends Node
## Real visit/clock/dialogue/save owners with synthetic arrived route endpoints.
## This contract proves authored scheduling and presentation lifecycle, not world
## navigation, door access, native body clearance, artistic quality or clue earning.
const Performances := preload("res://scripts/characters/loop_performances.gd")
const Loop := preload("res://scripts/game/temporal_loop.gd")
const State := preload("res://scripts/game/prologue_state.gd")
const Economy := preload("res://scripts/game/caretaker_economy.gd")
const ErrorCapture := preload("res://tests/guide_bell_error_capture.gd")

class Attention extends Node:
	var staged_target: Variant = null

class TestPlayer extends Node:
	var call_locked := false

class Actor extends Node3D:
	var _walking := false
	var activity := ""
	var clears := 0
	func set_loop_activity(value: String) -> void: activity = value
	func clear_loop_activity() -> void:
		activity = ""
		clears += 1

class Route extends Node:
	var actor: Actor
	var outside := false
	var desired_id := 0
	var current_id := 0
	var path := PackedInt64Array()
	var force_destination := ""
	var destination := "unit:main"
	var graph := AStar3D.new()
	var identities := {"main": 0, "kitchen": 1, "studio": 2, "alcove": 3}
	var places := {"unit": "main", "unit:main": "main", "unit:kitchen": "kitchen",
		"unit:study": "studio", "visit:6C": "studio", "visit:5B": "alcove"}
	var _doors: Array[DoorProp] = []
	func arrive(place: String) -> void:
		destination = place
		desired_id = int(identities.get(str(places.get(place, "main")), 0))
		current_id = desired_id
		path = PackedInt64Array()
		outside = false
		force_destination = ""
		actor._walking = false
		actor.visible = true
		actor.global_position = graph.get_point_position(desired_id)

class Adapter extends RefCounted:
	var targets: Dictionary = {}
	func resolve(identity: String) -> Node: return targets.get(identity)

class World extends Node3D:
	var player: Node
	var resident_routes: Dictionary = {}
	var adapter := Adapter.new()
	var performer: Node
	var forced_blocks: Dictionary = {}
	func resident_whereabouts(resident: String) -> Dictionary:
		if forced_blocks.has(resident): return forced_blocks[resident]
		var override: Dictionary = performer.whereabouts(resident) if performer != null else {}
		return override if not override.is_empty() else {"place": "unit:main", "activity": "rest"}

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var clock: CampaignClock
var loop: Node
var performance: Node
var world: World
var conversations: ResidentConversations
var panel: CaseDialoguePanel
var player: Node
var started := Time.get_ticks_msec()
var phase_count := 0
var anchor_count := 0
var ordinary_lines := 0
var ordinary_encounters := 0
var ordinary_day := 0
var speaker_events: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "label": label})
	if not ok: failures.append(label)
	print("LOOP PERFORMANCE: ", label, " = ", ok)

func _ready() -> void: _run.call_deferred()

func _run() -> void:
	var logger := ErrorCapture.new()
	OS.add_logger(logger)
	var old_path: String = RealityState.save_path
	var old_persistence: bool = RealityState.persistence_enabled
	var old_data: Dictionary = RealityState.data
	var test_path := "user://tests/loop_performance_%d.json" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	RealityState.persistence_enabled = false
	RealityState.save_path = test_path
	RealityState.start_new_campaign()
	clock = CampaignClock.new()
	check(clock.configure_date(1928, 11, 10, 1380), "fixture calendar configured")
	var opening := State.request_skip(State.initial())
	for index in State.PHASES.size() - 1:
		var phase: String = State.PHASES[index]
		if phase == "companion_crossing": opening = State.applied(opening, "companion_materialized")
		if phase == "temporal_command":
			opening = State.with_target(opening, {"utc_unix_seconds": 1856345696, "local_bias_minutes": -300, "local_zone": "Test"})
		if phase == "temporal_synchronization": break
		opening = State.advance(opening, State.PHASES[index + 1])
	RealityState.data.prologue = opening
	check(clock.apply_prologue_destination(), "fixture adopts the authored historical year")
	var economy := Economy.new()
	add_child(economy)
	loop = Loop.new()
	add_child(loop)
	loop.set_process(false)
	check(loop.setup(clock, economy), "real temporal table loads")
	panel = CaseDialoguePanel.new()
	add_child(panel)
	conversations = ResidentConversations.new()
	add_child(conversations)
	conversations.setup(panel, func(): return "6C", func(_resident): return true)
	check(conversations.errors.is_empty(), "real ordinary dialogue trees load")
	player = TestPlayer.new()
	add_child(player)
	player.add_to_group("player_controller")
	world = World.new()
	world.player = player
	add_child(world)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Performances.SOURCE))
	for resident: String in source.profiles:
		if resident in ["stacy", "rhea_sato", "transient_guests"]: continue
		var route := Route.new()
		world.add_child(route)
		for i in 4: route.graph.add_point(i, Vector3(world.resident_routes.size() * 5.0, 0, i * 0.6))
		route.actor = Actor.new()
		route.add_child(route.actor)
		var attention := Attention.new()
		attention.name = "Attention"
		route.actor.add_child(attention)
		route.arrive("unit:main")
		world.resident_routes[resident] = route
	performance = Performances.new()
	world.add_child(performance)
	world.performer = performance
	check(performance.setup(world, loop, conversations), "all authored profiles and phases validate")
	performance.set_process(false)
	await get_tree().process_frame
	if performance.errors.is_empty():
		_boundary_matrix()
		_dialogue_lifecycle()
		_transition_dialogue()
		_gaze_and_activity()
		_save_reload()
		_move_yield()
		_interrupted_guest_wait()
		_strict_fault()
		await _ordinary_exchanges()
	if loop.in_visit(): loop.go_home()
	world.free()
	conversations.free()
	panel.free()
	player.free()
	loop.free()
	economy.free()
	RealityState.flush_background_saves()
	RealityState.persistence_enabled = false
	for suffix: String in ["", ".bak", ".tmp"]:
		var absolute := ProjectSettings.globalize_path(test_path + suffix)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	RealityState.save_path = old_path
	RealityState.data = old_data
	RealityState.persistence_enabled = old_persistence
	check(logger.errors.is_empty(), "no engine script errors")
	check(phase_count >= 47 and anchor_count == 11, "nonempty complete anchor and phase coverage")
	check(ordinary_encounters == 7 and ordinary_lines == 33, "all seven ordinary exchanges and thirty-three lines executed")
	_write_contract(logger.errors)
	OS.remove_logger(logger)
	print("[LOOP PERFORMANCE] RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _tick() -> void:
	performance._process(0.3)

## Pre-earned wall fixture, explicitly not evidence that a player earned clues.
func _unlock_fixture() -> void:
	loop.ledger().bank_cents = 100000
	for anchor: String in loop.table.anchors:
		loop.ledger().items[str(loop.table.anchors[anchor].clue.id)] = {"pinned": true, "anchor": anchor, "dated": true, "placed": true}
	loop.ledger().deductions = loop.table.deductions.keys()

func _jump(anchor: String) -> void:
	if loop.in_visit(): check(bool(loop.go_home().ok), "leave previous fixture visit")
	_unlock_fixture()
	check(bool(loop.jump(anchor).ok), "real jump to " + anchor)
	_tick()

func _advance(minutes: float) -> void:
	check(clock.advance_to(clock.elapsed_minutes() + minutes), "advance real loop clock %.3f minutes" % minutes)
	_tick()

func _boundary_matrix() -> void:
	for anchor: String in performance.data.anchors:
		anchor_count += 1
		var actors: Dictionary = performance.data.anchors[anchor].actors
		if actors.is_empty():
			_jump(anchor)
			check(performance.phase_for("mae_kessler").is_empty(), anchor + " keeps ordinary agendas")
		for resident: String in actors:
			_jump(anchor)
			var phases: Array = actors[resident]
			for i in phases.size():
				phase_count += 1
				var expected: Dictionary = phases[i]
				var actual: Dictionary = performance.phase_for(resident)
				check(str(actual.get("phase_id", "")) == "%s:%s:%d" % [anchor, resident, i], "phase start %s/%s/%d" % [anchor, resident, i])
				check(str(actual.get("line", "")) == str(expected.line), "authored line selected without rewriting")
				if str(expected.place).is_empty():
					check(performance.whereabouts(resident).is_empty(), "empty phase destination inherits the agenda")
				var remaining: float = float(expected.until) - loop.loop_minutes()
				_advance(maxf(0.0, remaining - 0.001))
				check(str(performance.phase_for(resident).get("phase_id", "")) == str(actual.get("phase_id", "")), "phase holds until exclusive endpoint")
				# Six milliseconds past the endpoint avoids a false boundary caused
				# by binary subtraction of large elapsed campaign values.
				_advance(0.0011)
			check(performance.phase_for(resident).is_empty(), "no phase survives visit endpoint")
	_jump("tea")

func _dialogue_lifecycle() -> void:
	var route: Route = world.resident_routes.mae_kessler
	route.arrive("unit:main")
	check(not performance.conversation_prompt("mae_kessler").is_empty(), "arrived resident offers authored topic")
	for state: String in ["walking", "outside", "forced", "path", "not_at_vertex", "wrong_vertex", "hidden", "wrong_destination"]:
		route.arrive("unit:main")
		match state:
			"walking": route.actor._walking = true
			"outside": route.outside = true
			"forced": route.force_destination = "unit:main"
			"path": route.path = PackedInt64Array([1])
			"not_at_vertex": route.actor.position += Vector3(0.2, 0, 0)
			"wrong_vertex": route.current_id = 1
			"hidden": route.actor.visible = false
			"wrong_destination": route.destination = "unit:kitchen"
		check(performance.conversation_prompt("mae_kessler").is_empty(), "arrival refuses " + state)
	route.arrive("unit:main")
	world.forced_blocks.mae_kessler = {"place": "unit:main", "activity": "sleeping"}
	check(not performance.try_conversation("mae_kessler", player), "sleep retains its owner")
	world.forced_blocks.clear()
	check(not performance.try_conversation("mina_vale", player), "Mina golden-shift owner is excluded")
	var before: Dictionary = RealityState.data.duplicate(true)
	check(performance.try_conversation("mae_kessler", player), "actual dedicated conversation starts")
	check(panel.attention_active() and panel.current_node_id == "loop_business", "actual panel shows the performance")
	panel.choose(0)
	check(not conversations.performance_active() and not panel.attention_active(), "reply releases panel and performance")
	check(RealityState.data == before, "performance grants no trust knowledge visits inventory or economy")
	check(not performance.try_conversation("mae_kessler", player), "same phase reply does not repeat")
	check(conversations.start("mae_kessler") and not conversations.performance_active(), "next interaction reaches ordinary conversation")
	var ordinary := panel.current_node_id
	_tick()
	check(panel.current_node_id == ordinary and panel.attention_active(), "ordinary conversation survives performance polling")
	panel.close(); panel._end_tree()
	check(bool(loop.reset_loop().ok), "same-minute rerun accepted")
	check(performance.try_conversation("mae_kessler", player), "new rerun releases the one-shot reply")
	_advance(10.0)
	check(not panel.attention_active() and not conversations.performance_active(), "phase boundary cancels old dedicated reply")
	check(bool(loop.reset_loop().ok), "reset for foreign dialogue ownership")
	check(performance.try_conversation("mae_kessler", player), "dedicated line precedes foreign takeover")
	var foreign := {"nodes": {"foreign": {"speaker": "Other", "line": "Another owner.", "choices": [{"label": "Continue."}]}}}
	panel.run_tree(foreign, "foreign", Callable())
	conversations.cancel_performance()
	check(panel.attention_active() and panel.current_node_id == "foreign", "cancel does not close a successor's dialogue")
	panel.close(); panel._end_tree()
	check(bool(loop.reset_loop().ok), "reset for admitted counter")
	check(performance.try_entry("stacy", player), "route-less existing counter can admit its baseline line")
	check(bool(loop.go_home().ok), "home succeeds with a dedicated line active")
	check(not panel.attention_active() and not conversations.performance_active(), "home releases dedicated line")
	check(not performance.conversation_prompt("mae_kessler").is_empty(), "ordinary authored reply remains available at home")
	_jump("tea")

func _gaze_and_activity() -> void:
	var route: Route = world.resident_routes.mae_kessler
	route.arrive("unit:main")
	var phase: Dictionary = performance.data.anchors.tea.actors.mae_kessler[0]
	var focus := Node3D.new()
	world.add_child(focus)
	focus.global_position = route.actor.global_position + Vector3(0, 1, 1)
	world.adapter.targets["test_focus"] = focus
	var old_focus := str(phase.focus)
	phase.focus = "test_focus"
	_tick()
	var attention: Attention = route.actor.get_node("Attention")
	check(not route.actor.activity.is_empty() and attention.staged_target == focus.global_position, "arrived actor receives activity and authored gaze")
	var successor := Vector3(999, 5, 4)
	attention.staged_target = successor
	_tick()
	check(attention.staged_target == successor, "poll does not reclaim a successor's gaze")
	route.actor._walking = true
	_tick()
	check(route.actor.activity.is_empty() and attention.staged_target == successor, "movement releases activity while preserving foreign gaze")
	attention.staged_target = null
	route.arrive("unit:main")
	_tick()
	check(attention.staged_target == focus.global_position, "unowned gaze may be acquired again")
	check(bool(loop.go_home().ok), "home releases authored actor presentation")
	check(route.actor.activity.is_empty() and attention.staged_target == null, "home clears only the held activity and gaze")
	phase.focus = old_focus
	focus.free()
	_jump("tea")

func _transition_dialogue() -> void:
	var route: Route = world.resident_routes.mae_kessler
	route.arrive("unit:main")
	check(conversations.start("mae_kessler"), "ordinary tree opens before HOME")
	var knowledge: Variant = RealityState.data.get("knowledge_flags", {}).duplicate(true)
	check(bool(loop.go_home().ok), "HOME interrupts an ordinary resident tree")
	check(not panel.attention_active() and conversations._active_resident.is_empty(), "ordinary dated offers close on transition")
	check(RealityState.data.get("knowledge_flags", {}) == knowledge, "transition grants no first-conversation note or knowledge")
	_jump("tea")
	_advance(10.0)
	check(conversations.start_mystery("mae_kessler"), "date-limited tea mystery menu opens in its hour")
	check(panel.current_node_id == ResidentConversations.MYSTERY_MENU and not RealityState.has_knowledge("mt:mk_tea"), "opening the menu has not heard its thread")
	knowledge = RealityState.data.get("knowledge_flags", {}).duplicate(true)
	check(bool(loop.go_home().ok), "HOME interrupts a dated mystery menu")
	check(not panel.attention_active() and RealityState.data.get("knowledge_flags", {}) == knowledge, "stale mystery choices close without being granted")
	_jump("tea")
	_advance(10.0)
	check(conversations.start_mystery("mae_kessler"), "tea thread can be entered on a fresh visit")
	panel.choose(0)
	check(RealityState.has_knowledge("mt:mk_tea"), "existing mystery owner still grants heard on actual root entry")
	knowledge = RealityState.data.get("knowledge_flags", {}).duplicate(true)
	check(bool(loop.go_home().ok), "HOME interrupts a heard mystery root")
	check(not panel.attention_active() and RealityState.data.get("knowledge_flags", {}) == knowledge, "already granted mystery knowledge survives without extra grants")
	_jump("tea")
	check(conversations.start("mae_kessler"), "ordinary tree precedes a foreign successor")
	var foreign := {"nodes": {"successor": {"line": "An independent owner.", "choices": [{"label": "Continue."}]}}}
	panel.run_tree(foreign, "successor", Callable())
	check(bool(loop.go_home().ok), "HOME after foreign takeover")
	check(panel.attention_active() and panel.current_node_id == "successor", "transition preserves a foreign ordinary successor")
	panel.close(); panel._end_tree()
	_jump("tea")

func _save_reload() -> void:
	var route: Route = world.resident_routes.mae_kessler
	route.arrive("unit:main")
	RealityState.persistence_enabled = true
	check(RealityState.save_game(), "validated isolated save accepts current visit")
	check(performance.try_conversation("mae_kessler", player), "dedicated line active before reload")
	var identity: String = performance._identity
	RealityState.load_game()
	check(clock.bind_state() and loop.in_visit(), "validated load restores real clock and visit")
	_tick()
	check(performance._identity == identity, "loaded visit has the same calendar identity")
	check(not panel.attention_active() and not conversations.performance_active(), "same-visit load cancels stale presentation")
	check(not performance.conversation_prompt("mae_kessler").is_empty(), "load rebuilds transient heard state")
	RealityState.flush_background_saves()
	RealityState.persistence_enabled = false

func _move_yield() -> void:
	_jump("tea")
	_advance(10.0)
	var a: Route = world.resident_routes.mae_kessler
	var b: Route = world.resident_routes.nadia_quell
	a.arrive("unit:main"); b.arrive("unit:main")
	var saved := b.actor.global_position
	b.actor.global_position = a.actor.global_position + Vector3(0.6, 0, 0)
	check(not performance.allow_step("mae_kessler", a.actor.global_position + Vector3(0.1, 0, 0)), "approach yields before neighboring body")
	check(performance.allow_step("mae_kessler", a.actor.global_position - Vector3(0.1, 0, 0)), "moving apart remains permitted")
	b.outside = true
	check(performance.allow_step("mae_kessler", a.actor.global_position + Vector3(0.1, 0, 0)), "absent body does not block a route")
	b.outside = false
	b.actor.global_position = saved
	var unrelated: Route = world.resident_routes.cal_dwyer
	var saved_other := unrelated.actor.global_position
	unrelated.actor.global_position = a.actor.global_position + Vector3(0.6, 0, 0)
	check(performance.allow_step("mae_kessler", a.actor.global_position + Vector3(0.1, 0, 0)), "uncoordinated residents retain their existing route owner")
	check(performance.allow_step("cal_dwyer", unrelated.actor.global_position - Vector3(0.1, 0, 0)), "unrelated corridor traffic does not acquire symmetric deadlock")
	unrelated.actor.global_position = saved_other

func _interrupted_guest_wait() -> void:
	_jump("tea")
	_advance(10.0)
	var guest: Route = world.resident_routes.nadia_quell
	guest.arrive("unit:main"); guest.actor._walking = true
	check(str(performance.whereabouts("mae_kessler").place) == "unit:kitchen", "host initially makes room for arriving guest")
	player.call_locked = true
	performance._process(35.0)
	check(str(performance.whereabouts("mae_kessler").place) == "unit:kitchen", "long conversation preserves host yielding opportunity")
	player.call_locked = false
	performance._process(15.0)
	check(str(performance.whereabouts("mae_kessler").place) == "unit:kitchen", "host still yields before thirty movement seconds")
	performance._process(15.0)
	check(str(performance.whereabouts("mae_kessler").place) == "unit:main", "blocked visitor fallback uses movement time")
	guest.actor._walking = false

func _strict_fault() -> void:
	_jump("drama")
	var route: Route = world.resident_routes.cal_dwyer
	route.arrive("unit:main")
	world.resident_routes.juno_kells.arrive("visit:5B")
	check(performance.try_conversation("cal_dwyer", player), "strict-room performance starts")
	panel.choose(0)
	var identity: String = performance._identity
	var fault_object := ""
	for step: Dictionary in loop.table.anchors.drama.steps:
		if str(step.kind) == "shift": fault_object = str(step.object); break
	check(not fault_object.is_empty() and loop.report_shift(fault_object) == "fault", "real out-of-order strict shift faults")
	check(performance._identity == identity and performance.conversation_prompt("cal_dwyer").is_empty(), "strict fault is not a new visit or repeatable dialogue")
	var elapsed := clock.elapsed_minutes()
	check(bool(loop.reset_loop().ok) and is_equal_approx(clock.elapsed_minutes(), elapsed), "real same-minute rerun leaves elapsed time unchanged")
	check(not performance.conversation_prompt("cal_dwyer").is_empty(), "rerun identity permits a fresh performance")

func _ordinary_clock(minute := 600) -> void:
	if loop.in_visit(): check(bool(loop.go_home().ok), "ordinary fixture returns home")
	ordinary_day += 1
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 5, 5, float(minute)) + ordinary_day * 1440.0), "ordinary fixture changes authoritative civil day")
	_tick()

## The routes are synthetic supported endpoints. Both the graph and visible
## body agree, so a distance/sight failure is not accidentally an arrival miss.
func _arrange_encounter(item: Dictionary) -> void:
	for value: Variant in world.resident_routes.values():
		(value as Route).outside = true
	for i in item.actors.size():
		var route: Route = world.resident_routes[str(item.actors[i])]
		var place := str(item.places[0])
		route.places[place] = "main"
		route.graph.set_point_position(0, Vector3(1000, 0, i * 1.1))
		route.arrive(place)

func _move_endpoint(route: Route, offset: Vector3) -> void:
	route.graph.set_point_position(route.desired_id, route.actor.global_position + offset)
	route.actor.global_position += offset

func _ordinary_exchanges() -> void:
	conversations.conversation_started.connect(func(identity: String, _entry: String): speaker_events.append(identity))
	check(performance.ordinary.errors.is_empty() and performance.ordinary.encounters.size() == 7, "ordinary encounter reader admits the seven authored exchanges")
	for item: Dictionary in performance.ordinary.encounters:
		_ordinary_clock()
		_arrange_encounter(item)
		check(performance.ordinary.eligible(item, ""), str(item.id) + " both real endpoints admit the encounter")
		var before: Dictionary = RealityState.data.duplicate(true)
		var first := str(item.actors[0])
		check(performance.try_conversation(first, player), str(item.id) + " starts through resident interaction")
		ordinary_encounters += 1
		for i in item.lines.size():
			var line: Dictionary = item.lines[i]
			ordinary_lines += 1
			check(panel.attention_active() and panel._line.text == str(line.text), "%s line%d retains exact authored text" % [item.id, i])
			check(conversations._active_resident == str(line.speaker) and not speaker_events.is_empty() \
					and speaker_events.back() == str(line.speaker), "%s line%d speaker owns conversation signals" % [item.id, i])
			var offered: Array = panel.offered_labels()
			check(not offered.is_empty() and str(offered.back()) == "I'll let you get on.", "%s line%d allows departure" % [item.id, i])
			if i + 1 < item.lines.size():
				check(str(offered[0]) == str(line.get("choice", "Listen.")), "%s line%d retains its authored reply" % [item.id, i])
			panel.choose(0)
		check(not panel.attention_active() and not conversations.performance_active(), str(item.id) + " ends and releases its last speaker")
		check(RealityState.data == before, str(item.id) + " dialogue has no gameplay/save consequences")
		check(performance.ordinary.for_resident(first, "", performance._heard).is_empty(), str(item.id) + " cannot repeat in the same day")
	var pair: Dictionary = performance.ordinary.encounters[0]
	var first := str(pair.actors[0])
	_ordinary_clock()
	_arrange_encounter(pair)
	var before: Dictionary = RealityState.data.duplicate(true)
	check(performance.try_conversation(first, player), "pair starts for early departure")
	panel.choose(panel.offered_labels().size() - 1)
	check(not panel.attention_active() and not conversations.performance_active() and RealityState.data == before, "early departure releases speakers without granting anything")
	check(performance.ordinary.for_resident(first, "", performance._heard).is_empty(), "departed exchange remains heard for this day")
	_ordinary_clock()
	check(not performance.ordinary.for_resident(first, "", performance._heard).is_empty(), "next civil day renews ordinary exchange")
	check(performance.try_conversation(first, player), "renewed exchange starts")
	panel.choose(panel.offered_labels().size() - 1)
	RealityState.persistence_enabled = true
	check(RealityState.save_game(), "ordinary-day campaign saves through validated owner")
	RealityState.load_game()
	check(clock.bind_state(), "ordinary-day campaign reload binds real clock")
	_tick()
	check(not performance.ordinary.for_resident(first, "", performance._heard).is_empty(), "validated reload rebuilds transient ordinary heard state")
	RealityState.flush_background_saves()
	RealityState.persistence_enabled = false
	for bad: String in ["outside", "hidden", "moving", "unarrived", "wrong_floor", "overlap", "far", "unsupported", "sleeping", "transit"]:
		_ordinary_clock()
		_arrange_encounter(pair)
		check(performance.try_conversation(first, player), "pair live before " + bad)
		var other: Route = world.resident_routes[str(pair.actors[1])]
		match bad:
			"outside": other.outside = true
			"hidden": other.actor.visible = false
			"moving": other.actor._walking = true
			"unarrived": other.current_id = 1
			"wrong_floor": _move_endpoint(other, Vector3(0, 0.5, 0))
			"overlap": _move_endpoint(other, Vector3(0, 0, -0.8))
			"far": _move_endpoint(other, Vector3(0, 0, 2.0))
			"unsupported": other.destination = "out"
			"sleeping", "transit": world.forced_blocks[str(pair.actors[1])] = {"place": str(pair.places[0]), "activity": bad}
		check(not performance.ordinary.eligible(pair, ""), "pair eligibility rejects " + bad)
		_tick()
		check(not panel.attention_active() and not conversations.performance_active(), "live encounter cancels when partner becomes " + bad)
		world.forced_blocks.clear()
	# A real collision surface, independent from the actor/route stubs, is the
	# negative control for the line-of-sight query and live cancellation.
	_ordinary_clock()
	_arrange_encounter(pair)
	check(performance.try_conversation(first, player), "unobscured pair starts before blocker")
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 0.1)
	collider.shape = box
	blocker.add_child(collider)
	world.add_child(blocker)
	blocker.global_position = Vector3(1000, 1.35, 0.55)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not performance.ordinary.eligible(pair, ""), "real wall blocks the ordinary pair's sightline")
	_tick()
	check(not panel.attention_active(), "new real obstruction cancels a live exchange")
	blocker.free()
	await get_tree().physics_frame
	check(performance.ordinary.eligible(pair, ""), "removing the real blocker restores eligibility")
	for item: Dictionary in performance.ordinary.encounters:
		_ordinary_clock()
		_arrange_encounter(item)
		check(performance.ordinary.eligible(item, ""), str(item.id) + " eligibility positive control before time exclusions")
		for excluded: String in item.excluded_anchors:
			check(not performance.ordinary.eligible(item, excluded), str(item.id) + " preserves historical anchor " + excluded)
		for excluded: String in item.get("exclude_dates", []):
			var parts := excluded.split("-")
			check(clock.rebase_calendar(CampaignClock.calendar_minute_of(int(parts[0]), int(parts[1]), int(parts[2]), 600)), "fixture reaches excluded historical day")
			check(not performance.ordinary.eligible(item, ""), str(item.id) + " refuses its excluded historical date")
		if item.has("hours"):
			_ordinary_clock(int(item.hours[0]) - 1)
			check(not performance.ordinary.eligible(item, ""), str(item.id) + " refuses before its hour")
			_ordinary_clock(int(item.hours[0]))
			check(performance.ordinary.eligible(item, ""), str(item.id) + " admits opening minute")
			_ordinary_clock(int(item.hours[1]))
			check(not performance.ordinary.eligible(item, ""), str(item.id) + " closes at exclusive end minute")

func _write_contract(engine_errors: Array[String]) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): directory = "user://tests/loop_performance"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var sources: Dictionary = {}
	for path: String in ["res://scripts/characters/loop_performances.gd", "res://scripts/characters/loop_encounters.gd", "res://scripts/game/temporal_loop.gd", "res://scripts/game/resident_conversations.gd", "res://scripts/ui/case_dialogue_panel.gd", "res://data/temporal/performances.json", "res://data/temporal/ordinary_performances.json", "res://data/temporal/anchors.json"]:
		sources[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": false,
		"scope": "Production authored-visit, clock, conversation and validated-save owners against synthetic route endpoints; no world navigation, cast fit, input optics or clue-earning qualification",
		"execution": {"completed": true, "exit_code": 0 if failures.is_empty() else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": {"test_path": "game/tests/loop_performance_test.gd", "test_sha256": get_script().source_code.replace("\r\n", "\n").sha256_text(), "inputs": sources},
		"contracts": {"loop_performance_lifecycle": {"executed": true, "status": "PASS" if failures.is_empty() else "FAIL"}},
		"checks": checks, "failures": failures, "engine_errors": engine_errors, "anchors": anchor_count, "phases": phase_count,
		"ordinary_encounters": ordinary_encounters, "ordinary_lines": ordinary_lines}
	FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
