extends "res://tests/harukiya_mass_return_test.gd"
## Private proposal. Extends the completed original mass-return programme in its
## same world. Install only after the integration owner reviews current custody.
const ServiceRoutes := preload("res://tests/harukiya_destination_routes.gd")
const CounterGlass := preload("res://scripts/props/harukiya_counter_glass.gd")
const SERVICE_CONTRACTS := ["occupied_counter_response", "occupied_darts_scored_action",
	"occupied_pool_scored_action", "occupied_gallery_backstage_access", "occupied_service_custody"]
const SERVICE_SECONDS := 240.0
const GLASS_STEPS := 200
const SHOT_SECONDS := 12.0
var service_active := false
var service_started := 0
var service_people: Dictionary = {}
var service_civil: Dictionary = {}
var service_node := "pool_interaction"
var service_panel: Node
var service_conversation := false
var service_calls: Array[Dictionary] = []
var counter_signal: Callable
var panel_button_held := false
var panel_button_point := Vector2.ZERO

func _init() -> void:
	for identity: String in SERVICE_CONTRACTS:
		contracts[identity] = {"executed": false, "status": "NOT_RUN"}

func _opposition_programme() -> void:
	# This already-virtual parent entry point is the extension hook. Its
	# original departures, returns, deadlines and failures execute first.
	await super._opposition_programme()
	if not failures.is_empty(): return
	if not _check(_all_occupied() and _queue_drained(), "services begin only after original18 return and passage drain"): return
	service_started = Time.get_ticks_msec()
	service_active = true
	service_civil = clock.day_info().duplicate(true)
	for identity: String in routes:
		service_people[identity] = {"owner": routes[identity].get_instance_id(), "actor": routes[identity].actor.get_instance_id()}
	details.services = {"started_after_mass_return": true, "seconds_limit": SERVICE_SECONDS,
		"civil": service_civil, "minute": clock.minute_of_day(), "before": _crowd_snapshot(),
		"legs": [], "games": {}, "captures": [], "inputs": "real player handler for world grips; viewport-local ordinary dispatch for panels"}
	if _service_context(): await _counter_service()
	if failures.is_empty(): await _retained_game("darts")
	if failures.is_empty(): await _retained_game("pool")
	if failures.is_empty(): await _occupied_access()
	if failures.is_empty():
		_check(_service_context() and _queue_drained() and squeeze_witness.snapshot().active.is_empty(),
			"occupied services finish with original18, drained passage owners and no squeeze episode")
		details.services.after = _crowd_snapshot()
		_contract("occupied_service_custody", failures.is_empty())
	service_active = false

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not service_active or not failures.is_empty(): return
	if Time.get_ticks_msec() - service_started > int(SERVICE_SECONDS * 1000.0) \
			or Time.get_ticks_msec() - started > int(TOTAL_DEADLINE_SECONDS * 1000.0):
		_fail_safety("occupied service programme remains inside declared service and total deadlines", _crowd_snapshot())
		return
	if not _all_occupied(): _fail_safety("all18 retain original occupied places throughout services", _crowd_snapshot())

func _service_context() -> bool:
	if not _check(watching and service_active and _all_occupied(), "continuous original18 observer remains active during service"): return false
	if not _check(clock.day_info() == service_civil and absf(clock.minute_of_day() - 1260.0) < .00001
		and CampaignTime._frozen_for_tests, "original frozen pre-death Friday21:00 context retained"): return false
	if not _check(world.player.is_physics_processing() and PlayerMotor._service_collision_valid(world.player)
		and not world.player.noclip, "original active player retains production collision policy"): return false
	for identity: String in service_people:
		var route: Node3D = routes[identity]
		if not _check(route.get_instance_id() == int(service_people[identity].owner)
			and route.actor.get_instance_id() == int(service_people[identity].actor)
			and route.is_physics_processing() and route.can_process(), "exact original service witness owner " + identity): return false
	var cast: Node = world.harukiya_counter.cast
	if not _check(is_instance_valid(cast) and cast.actors.size() == 2, "single existing Lily/Stacy cast owner retained"): return false
	for identity: String in ["lily", "stacy"]:
		if not _check(cast.actors.has(identity) and cast.actors[identity].is_visible_in_tree(), "original staff visible during occupied services " + identity): return false
	return true

func _walk_service(goal: Vector3) -> bool:
	if not failures.is_empty(): return false
	var from := world.player.global_position
	if not await _walk_player(goal): return false
	var feet := world.player.global_position
	var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * .04, feet - Vector3.UP * .08, 1)
	ray.exclude = [world.player.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	var supported := not hit.is_empty() and absf(hit.position.y - feet.y) < .035 and absf(feet.y - goal.y) < .05
	details.services.legs.append({"from": from, "goal": goal, "actual": feet, "supported": supported})
	return _check(supported, "occupied service motor reaches the actual supported endpoint") and _service_context()

func _go_service(identity: String) -> bool:
	if not await ServiceRoutes.walk(world.bar_region, service_node, identity, Callable(self, "_walk_service"), Callable(self, "_check")): return false
	service_node = identity
	return true

func _player_click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	world.player._unhandled_input(event)
	await get_tree().physics_frame

func _counter_started(identity: String, entry: String) -> void:
	service_calls.append({"resident": identity, "entry": entry})

func _counter_service() -> void:
	stage = "occupied_counter_response"
	contracts[stage] = {"executed": true, "status": "FAIL"}
	if not await _go_service("counter_e"): return
	var counter: Node3D = world.harukiya_counter
	if not _check(is_instance_valid(counter) and counter.on_shift(), "original Friday staff clock has Stacy on shift"): return
	# Existing single-customer fixture offset is a walking target only.
	var approach := counter.glass.global_position + Vector3(0.0, -1.08, 1.25)
	if not await _walk_service(approach): return
	var player: PlayerController = world.player
	player.camera.look_at(counter.glass.global_position + Vector3.UP * .05)
	await get_tree().physics_frame
	player.camera.look_at(counter.glass.global_position + Vector3.UP * .05)
	var grip: Dictionary = player._grab.find_target()
	if not _check(grip.get("owner") == counter and grip.get("part") == counter.glass, "occupied approach real grip ray reaches counter glass"): return
	if not _check(not world.conversations.dialogue.attention_active(), "counter starts without another active dialogue"): return
	counter_signal = Callable(self, "_counter_started")
	world.conversations.conversation_started.connect(counter_signal)
	var home: Vector3 = counter.glass.global_position
	await _player_click()
	if not _check(player._grab.active() and is_zero_approx(float(grip.read.call())), "occupied click grabs the resting glass without moving it"): return
	var reach := 0.0
	for index in GLASS_STEPS:
		if not failures.is_empty() or not player._grab.active(): break
		reach = maxf(reach, float(grip.read.call()))
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(0, -6)
		player._unhandled_input(event)
		reach = maxf(reach, float(grip.read.call()))
		await get_tree().physics_frame
	service_conversation = world.conversations.dialogue.attention_active()
	if not _check(reach >= CounterGlass.SLIDE * CounterGlass.ACROSS_AT and service_calls.size() == 1
		and str(service_calls[0].resident) == "stacy", "actual occupied glass slide requests exactly one authored Stacy response"): return
	var dialogue: CaseDialoguePanel = world.conversations.dialogue
	var displayed: Dictionary = dialogue.displayed_line()
	if not _check(dialogue.attention_active() and str(displayed.get("speaker", "")).strip_edges().to_lower() == "stacy"
		and not str(displayed.get("text", "")).strip_edges().is_empty() and not player._grab.active(), "occupied counter displays Stacy authored line and releases hand"): return
	var cast: Node = counter.cast
	if not _check(cast.actors.stacy.face.is_speaking() and not cast.actors.lily.face.is_speaking(), "only displayed Stacy receives occupied dialogue face speech"): return
	details.services.counter = {"approach": approach, "actual_feet": player.global_position,
		"max_slide_m": reach, "calls": service_calls.duplicate(true), "displayed": displayed.duplicate(true)}
	await _capture_service("occupied_counter")
	# Same ordinary close authority as the qualified original counter test.
	dialogue.close()
	service_conversation = false
	if not await _wait_service(func(): return (counter.glass.global_position.distance_to(home) < .02
		and not cast.actors.stacy.face.is_speaking() and not player.call_locked), 3.0, "counter releases attention and returns glass home"): return
	world.conversations.conversation_started.disconnect(counter_signal)
	counter_signal = Callable()
	if not await _walk_service(_bar_point("counter_e")): return
	_contract("occupied_counter_response", failures.is_empty())

func _bar_point(identity: String) -> Vector3:
	var destination: Node3D = world.bar_region.destination
	return destination.get_node("Navigation/" + identity).global_position

func _open_game(owner: Node3D, label: String) -> bool:
	var player: PlayerController = world.player
	var offset := Vector3(0, .05, 0) if label == "darts" else Vector3(0, .018, 0)
	player.camera.look_at(owner.to_global(offset))
	await get_tree().process_frame
	var eye := player.camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(eye, eye - player.camera.global_basis.z * 2.1)
	ray.collide_with_areas = true
	ray.exclude = [player.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	var matched := false
	if not hit.is_empty():
		var node: Node = hit.collider
		while node != null:
			if node == owner: matched = true; break
			node = node.get_parent()
	player._update_prompt()
	if not _check(matched and not player._prompt.text.is_empty(), "occupied real camera ray and prompt reach " + label): return false
	await _player_click()
	await get_tree().process_frame
	service_panel = owner.get("_panel") as Node
	return _check(is_instance_valid(service_panel) and player.call_locked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"occupied ordinary primary input opens and locks original " + label)

func _panel_button(pressed: bool, point: Vector2) -> void:
	panel_button_held = pressed
	panel_button_point = point
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	await get_tree().physics_frame

func _panel_motion(from: Vector2, to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - from
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	await get_tree().physics_frame

func _escape_game(owner: Node3D, label: String) -> bool:
	# Same buffered keyboard route as the qualified nearby games preflight.
	await RenderingServer.frame_post_draw
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	service_panel = null
	return _check(owner.get("_panel") == null and not world.player.call_locked
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not world.player._grab.active(), "occupied Escape releases original " + label)

func _retained_game(label: String) -> void:
	stage = "occupied_" + label + "_scored_action"
	contracts[stage] = {"executed": true, "status": "FAIL"}
	if not await _go_service(label + "_interaction"): return
	var owner := world.bar_region.actors.get_node_or_null("F01_BAR_DARTS" if label == "darts" else "F01_BAR_POOL") as Node3D
	if not _check(is_instance_valid(owner), "original retained occupied game owner " + label): return
	if not await _open_game(owner, label): return
	var feet := world.player.global_position
	var result: Dictionary = await _darts_action() if label == "darts" else await _pool_action()
	if not failures.is_empty(): return
	if not _check(bool(result.get("resolved", false)) and world.player.global_position.distance_to(feet) < .025
		and world.player.call_locked and world.player.is_physics_processing(), "actual occupied game action resolves with locked standing player " + label): return
	details.services.games[label] = result
	await _capture_service("occupied_" + label)
	if not await _escape_game(owner, label): return
	if not await _open_game(owner, label): return
	if not await _escape_game(owner, label): return
	if not _service_context(): return
	_contract(stage, failures.is_empty())

func _darts_action() -> Dictionary:
	var panel := service_panel as DartsPanel
	if not _check(panel != null and panel.step == DartsPanel.Step.ASK and panel.trivia.thrown.is_empty(), "original occupied Rainbow Round starts a fresh question"): return {}
	var point := get_viewport().get_visible_rect().size * .35
	await _panel_button(true, point)
	if not _check(panel.holding, "viewport dispatch reaches original darts holding input"): return {}
	if not await _wait_service(func(): return panel.hold_t >= 1.05, 2.5, "original darts process steadies held input"): return {}
	await _panel_button(false, point)
	if not _check(panel.trivia.thrown.has(0) and panel._landed.size() >= 1, "actual release runs original dart scoring"): return {}
	var scored: Dictionary = panel.trivia.thrown[0]
	var landed: Vector2 = panel._landed[0]
	var points := int(scored.get("points", -1))
	var resolved := landed.is_finite() and points >= 0 and int(panel.trivia.players[0].score) == points
	_check(resolved, "original authored question evaluates finite landing and player score")
	return {"resolved": resolved, "question": panel.trivia.card.duplicate(true), "landing": landed,
		"scoring": scored.duplicate(true), "player_score": int(panel.trivia.players[0].score), "input": "viewport-local hold>=1.05s and release; original RNG retained"}

func _pool_action() -> Dictionary:
	var panel := service_panel as PointBallPanel
	if not _check(panel != null and panel.table.shots == 0 and panel.table.turn == 0 and not panel.table.moving, "original occupied Point Ball starts an untouched rack"): return {}
	var point := get_viewport().get_visible_rect().size * .35
	var pulled := point - Vector2(120, 0)
	await _panel_button(true, point)
	if not _check(panel.aiming, "viewport dispatch reaches original pool aiming input"): return {}
	await _panel_motion(point, pulled)
	if not _check(panel.drag_from.distance_to(panel.drag_to) > 8.0, "actual pool motion supplies a real shot pull"): return {}
	await _panel_button(false, pulled)
	if not _check(panel.table.shots == 1 and panel.table.moving, "actual pool release starts one original physics shot"): return {}
	if not await _wait_service(func(): return not panel.table.moving, SHOT_SECONDS, "original pool physics settles scored shot"): return {}
	var table: PointBall = panel.table
	var resolved := table.shots == 1 and table.turn == 1 and table.last_points >= 0
	resolved = resolved and int(table.players[0].score) == table.last_points and not table.log_lines.is_empty()
	for ball: Dictionary in table.balls:
		var position: Vector2 = ball.p
		var velocity: Vector2 = ball.v
		resolved = resolved and position.is_finite() and velocity.is_finite()
	_check(resolved, "original pool turn and score settle from actual shot without changing rack")
	return {"resolved": resolved, "shots": table.shots, "turn": table.turn, "last_points": table.last_points,
		"player_score": int(table.players[0].score), "potted": table.last_potted.duplicate(),
		"log": table.log_lines.duplicate(), "input": "viewport-local press,120px left pull,release; original physics/RNG retained"}

func _occupied_access() -> void:
	stage = "occupied_gallery_backstage_access"
	contracts[stage] = {"executed": true, "status": "FAIL"}
	for identity: String in ["backstage_entrance", "backstage_public_axis", "backstage", "stage_e", "stage_front",
		"stage_e", "backstage", "backstage_public_axis", "backstage_entrance", "stair_lower", "gallery_return", "stair_lower", "pool_interaction"]:
		if not await _go_service(identity): return
		if identity in ["stage_front", "gallery_return"]: await _capture_service("occupied_" + identity)
	if not _check(_queue_drained(), "occupied player access retains drained resident passage custody"): return
	_contract(stage, failures.is_empty())

func _wait_service(predicate: Callable, seconds: float, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while failures.is_empty() and Time.get_ticks_msec() < deadline:
		if bool(predicate.call()): return _check(true, label)
		await get_tree().physics_frame
	return _check(false, label + " within " + str(seconds) + "s")

func _capture_service(identity: String) -> void:
	await RenderingServer.frame_post_draw
	if not failures.is_empty(): return
	var image := get_viewport().get_texture().get_image()
	var path := directory.path_join(identity + ".png")
	var saved := image != null and not image.is_empty() and image.save_png(path) == OK
	_check(saved, "actual original-camera occupied service capture " + identity)
	if saved: details.services.captures.append({"path": path, "sha256": FileAccess.get_sha256(path), "size": image.get_size()})

func _finish() -> void:
	service_active = false
	if is_instance_valid(world):
		if is_instance_valid(service_panel) and service_panel.has_method("close"): service_panel.close()
		service_panel = null
		if panel_button_held:
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.pressed = false
			release.position = panel_button_point
			release.global_position = panel_button_point
			get_viewport().push_input(release, true)
			panel_button_held = false
		if counter_signal.is_valid() and world.conversations.conversation_started.is_connected(counter_signal):
			world.conversations.conversation_started.disconnect(counter_signal)
		if service_conversation and world.conversations.dialogue.attention_active(): world.conversations.dialogue.close()
	service_conversation = false
	if failures.is_empty():
		for identity: String in SERVICE_CONTRACTS:
			_check(bool(contracts[identity].executed) and str(contracts[identity].status) == "PASS", "required occupied service contract executed " + identity)
	await super._finish()

func _decorate_result(result: Dictionary) -> void:
	result.suite = "HarukiyaOccupiedServicesTest"
	result.scope = "Original18 mechanical bar owners complete inherited exterior departures and returns, then remain active and seated during actual player counter grab/slide/authored Stacy response, original darts/PointBall scored action and cancel/reopen, supported occupied stage/backstage/gallery walking and preview cleanup. One parent initial construction only. Local ordinary viewport input tests original panels. No natural attendance, staff mesh/cloth or physical-body qualification, audio listening, save/Continue, frame-time, play or artistic acceptance."
	result.fixture.service_limit_s = SERVICE_SECONDS
	result.fixture.service_total_deadline_s = TOTAL_DEADLINE_SECONDS
