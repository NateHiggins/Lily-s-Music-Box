extends Node3D
## Friday 19 July, the witnessed rescue branches (treatment section 6, WR-05; Lily's ruling
## adela_friday_witnessed_20261126). The actual V2 runtime on 19 July: a lobby choice's intent stages Adela at the
## parapet, at the enlarger, or in the shop with Miss Quell; the key book's attempt flag comes only from the
## player's own sight of that scene, before 21:01. Proves: the authored lobby nodes grant intents and the
## immediate refusals stay immediate; an ordinary Friday stages nothing; per branch no grant from the lobby,
## from out of reach, from behind a wall or looking away (and, in the shop, before 20:55); a real look grants
## exactly its attempt; Nadia is never visible twice; a loaded save keeps the scene; 21:01 retires every body
## and grants nothing; FRIDAY clears the intents and keeps the book. Player placement is declared (teleport and
## camera aim), not walked. No artistic acceptance; Mr. Ewald has no body yet (ruling ewald_body_20261126).
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const State := preload("res://scripts/game/prologue_state.gd")
const REQUIRED := ["authored_choices", "ordinary_friday", "roof_branch", "prints_branch", "shop_branch", "saved_scene",
		"blackout_boundary", "friday_reset"]
const INTENTS := ["m_o2_shop_agreed", "m_o2_roof_company", "m_o2_monday_sent"]
const ATTEMPTS := ["m_o2_kept_shop", "m_o2_refused_key", "m_o2_kept_envelope", "m_o2_brought_monday", "m_o2_stood_roof"]

var world: OrisonV2RuntimeRoot
var owner_node: Node3D
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var contracts: Dictionary = {}
var details: Dictionary = {"branches": {}, "captures": []}
var output := ""
var started := 0
var lease := false
var prior_frozen := false
var prior_mode := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "label": label})
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)
	return ok


func _contract(id: String, before: int) -> void:
	contracts[id] = {"executed": true, "status": "PASS" if failures.size() == before else "FAIL"}


func _run() -> void:
	started = Time.get_ticks_msec()
	output = OS.get_environment("SHOT_DIR")
	for id: String in REQUIRED:
		contracts[id] = {"executed": false, "status": "NOT_RUN"}
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("SHOT_DIR is required")
		get_tree().quit(2)
		return
	lease = RealityState.begin_preview_campaign(self)
	if not _check(lease, "exclusive nonpersistent campaign preview"):
		await _finish()
		return
	prior_frozen = CampaignTime._frozen_for_tests
	prior_mode = GameBoot.launch_mode
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	# The completed prologue's loop calendar (as TemporalLoopTest and the shop check set it), then Friday at six.
	var clock := CampaignClock.new()
	clock.configure_date(1928, 11, 10, 1380)
	var opening := State.request_skip(State.initial())
	for index in State.PHASES.size() - 1:
		var phase: String = State.PHASES[index]
		if phase == "companion_crossing":
			opening = State.applied(opening, "companion_materialized")
		if phase == "temporal_command":
			opening = State.with_target(opening, {"utc_unix_seconds": 1856345696, "local_bias_minutes": -300, "local_zone": "Test"})
		if phase == "temporal_synchronization":
			break
		opening = State.advance(opening, State.PHASES[index + 1])
	RealityState.data.prologue = opening
	_check(clock.apply_prologue_destination() and clock.loop_calendar_active(), "the loop calendar from the normal prologue destination")
	RealityState.data.prologue = State.advance(State.advance(RealityState.data.prologue, "title_reveal"), "prologue_complete")
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE, "report_id": ChirpHunt.JOB_ID, "filing": "fault_corrected"}
	RealityState.data.core_loop = {"safe_return_anchor": "F04_B_BED", "boundary": "wake_complete", "active_job_id": "",
			"conversation_requested": false, "conversation_complete": false, "dream_pending": false}
	_check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 7, 19, 18 * 60)), "Friday 19 July at six on the loop calendar")
	world = Runtime.instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not _check(not world.startup_failed and world.player != null and world.adela_encounters != null, "complete actual runtime composition"):
		await _finish()
		return
	owner_node = world.adela_encounters

	var before := failures.size()
	_authored_choices()
	_contract("authored_choices", before)

	before = failures.size()
	_reset_flags()
	await _at(1086)
	await _settle(20.0, func() -> bool: return _thread() == "av_nineteen")
	_check(_thread() == "av_nineteen", "an ordinary Friday: the lobby encounter at 18:06 (%s; %s)" % [_thread(), world.resident_whereabouts("adela_voss")])
	await _at(1200)
	_check(_thread().is_empty() and owner_node.call("friday_branch").is_empty(), "an ordinary Friday stages nobody at 20:00 (%s)" % _thread())
	_check(str(world.resident_whereabouts("nadia_quell").get("activity", "")) != "visit", "Nadia keeps her own evening")
	_contract("ordinary_friday", before)

	before = failures.size()
	await _branch("roof", "m_o2_roof_company", "m_o2_stood_roof", "av_friday_roof", 1200, 1200, 2.5)
	_contract("roof_branch", before)

	before = failures.size()
	await _branch("prints", "m_o2_monday_sent", "m_o2_brought_monday", "av_friday_prints", 1200, 1200, 4.0)
	_contract("prints_branch", before)

	before = failures.size()
	await _branch("enlarger", "m_o2_shop_agreed", "m_o2_kept_shop", "av_friday_shop", 1200, 1256, 4.0)
	_contract("shop_branch", before)

	# A loaded save (a new campaign document with the same facts) keeps the staged scene and its fact.
	before = failures.size()
	var lease_data: Dictionary = RealityState.data
	RealityState.data = lease_data.duplicate(true)
	await _settle()
	_check(_thread() == "av_friday_shop" and RealityState.has_knowledge("m_o2_shop_agreed") and RealityState.has_knowledge("m_o2_kept_shop"),
			"a loaded save keeps the intent, the attempt and the staged body (%s)" % _thread())
	RealityState.data = lease_data
	_contract("saved_scene", before)

	# 21:01: the record stops. Every staged body retires and nothing more can be witnessed.
	before = failures.size()
	_reset_flags()
	RealityState.grant_knowledge("m_o2_roof_company")
	await _at(1260)
	await _settle(4.0, func() -> bool: return _thread() == "av_friday_roof")
	if _check(_thread() == "av_friday_roof", "the roof branch is staged at 21:00"):
		# A look 0.85 s old when the record stops at 21:01 is not finished by the next tick.
		var adela: Node3D = owner_node.get("actor")
		var spot: Variant = _viewpoint(adela, 1.4, 2.1, true, true)
		if _check(spot != null, "a clear roof viewpoint at 21:00"):
			await _look_from(spot, adela, false, 0.0, .85)
			world.campaign_clock.advance_seconds(60.0)
			await _hold(.6)
			_check(_thread().is_empty() and not is_instance_valid(owner_node.get("actor")),
					"at 21:01 every staged body is gone (%s %02d:%02d)" % [world.conversations.today(), int(world.campaign_clock.minute_of_day()) / 60, int(world.campaign_clock.minute_of_day()) % 60])
			_check(not RealityState.has_knowledge("m_o2_stood_roof"), "a look spanning 21:01 grants nothing")
	_contract("blackout_boundary", before)

	# FRIDAY again: the intents go with the attempts; the book already written stays.
	before = failures.size()
	var loop: Node = world.temporal_loop
	(loop.ledger().items as Dictionary)["route_leaf"] = {"pinned": false}
	var arc: Dictionary = loop.call("_arc_state")
	arc["book"] = ["STOOD BY A.V. AT THE PARAPET. VISIT ENDED AT 21:01."]
	var book_before: Array = (arc.book as Array).duplicate()
	for flag: String in INTENTS + ["m_o2_kept_shop"]:
		RealityState.grant_knowledge(flag)
	var friday: Dictionary = loop.call("go_friday")
	_check(bool(friday.get("ok", false)), "FRIDAY opens the evening (%s)" % friday)
	_check(INTENTS.all(func(f: String) -> bool: return not RealityState.has_knowledge(f)) and not RealityState.has_knowledge("m_o2_kept_shop"),
			"FRIDAY clears the intents with the attempts")
	_check(loop.call("_arc_state").get("book") == book_before, "the book written on earlier evenings is kept")
	_contract("friday_reset", before)
	await _finish()


func _authored_choices() -> void:
	var tree: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/mystery/adela_voss.json"))
	var nodes: Dictionary = tree.get("nodes", {})
	for row: Array in [["av_n4", "m_o2_shop_agreed"], ["av_n5", "m_o2_roof_company"], ["av_n6", "m_o2_monday_sent"],
			["av_n3", "m_o2_refused_key"], ["av_n2", "m_key_loan_19"]]:
		_check(str(nodes.get(row[0], {}).get("flag", "")) == row[1], "%s grants %s" % row)
	var anchors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/temporal/anchors.json"))
	var asks: Array = anchors.arc.rescue.asks_again
	_check(INTENTS.all(func(f: String) -> bool: return f in asks), "FRIDAY's asks_again names the three intents")


## Start each alternative before the first lobby conversation and seed only the
## prior clue that makes the requested reply available. The actor and panel
## must award the intent through the same interaction the player uses.
func _choose_lobby_intent(place: String, intent: String) -> bool:
	var known: Array = RealityState.data.knowledge_flags
	known.erase("mt:av_nineteen")
	var reply := "Let me come up with you."
	if place == "prints":
		RealityState.grant_knowledge("m_lease_read")
		reply = "Bring Miss Quell and Mr. Ewald tonight. Not Monday."
	elif place == "enlarger":
		RealityState.grant_knowledge("m_motive_known")
		reply = "Don't go up. Stay in the shop."
	await _at(1086)
	await _settle(4.0, func() -> bool: return _thread() == "av_nineteen")
	var adela := owner_node.get("actor") as Node3D
	if not _check(is_instance_valid(adela) and not RealityState.has_knowledge(intent), place + ": Adela awaits the lobby decision"):
		return false
	var mark: Variant = _viewpoint(adela, 1.0, 1.5, true, false)
	if not _check(mark is Vector3, place + ": clear standing place in front of Adela"):
		return false
	await _look_from(mark, adela, false, 0.0, .1)
	world.player.use_primary_interaction()
	var panel: CaseDialoguePanel = world.conversations.dialogue
	var topic := panel.offered_labels().find("Evening, Miss Voss.")
	if not _check(panel.attention_active() and topic >= 0, place + ": player primary opens Adela's actual Friday topic"):
		return false
	panel.choose(topic)
	var choice := panel.offered_labels().find(reply)
	if not _check(panel.current_node_id == "av_n1" and choice >= 0, place + ": the authored lobby reply is available"):
		return false
	panel.choose(choice)
	if not _check(RealityState.has_knowledge(intent) and _only_attempts([]), place + ": the chosen reply grants intent alone"):
		return false
	if place == "enlarger":
		if not _check(panel.offered_labels().has("Thank you."), "enlarger: Adela finishes her answer"):
			return false
		panel.choose(panel.offered_labels().find("Thank you."))
	panel.choose(0)
	return _check(not panel.attention_active() and not world.player.call_locked, place + ": the lobby releases the player")


func _branch(place: String, intent: String, attempt: String, thread: String, early: int, minute: int, reach: float) -> void:
	var row := {"place": place}
	details.branches[place] = row
	_reset_flags()
	if not await _choose_lobby_intent(place, intent):
		return
	await _at(early)
	if place in ["enlarger", "prints"]:
		await _bring_shop()
	await _settle(4.0, func() -> bool: return _thread() == thread)
	if not _check(_thread() == thread and is_instance_valid(owner_node.get("actor")), "%s: the intent stages Adela (%s)" % [place, _thread()]):
		return
	var adela: Node3D = owner_node.get("actor")
	row.adela_at = adela.global_position
	_check(_only_attempts([]), "%s: the lobby choice alone writes no attempt" % place)
	if place == "prints":
		# Before Miss Quell's own body has arrived, a sustained look at Adela alone is not the scene.
		var early_look: Variant = _viewpoint(adela, 1.4, reach - .4, true, false)
		if owner_node.call("arrived_guests", owner_node.call("friday_branch")).is_empty() and early_look != null:
			await _look_from(early_look, adela, false, 0.0, 1.25)
			_check(not RealityState.has_knowledge(attempt), "prints: before Miss Quell arrives, a look at Adela grants nothing")
		await _settle(300.0, func() -> bool: return owner_node.call("arrived_guests", owner_node.call("friday_branch")).size() == 1)
		var arrived: Array = owner_node.call("arrived_guests", owner_node.call("friday_branch"))
		row.nadia_bodies = []
		for body: Node in get_tree().get_nodes_in_group("animated_residents"):
			if body is Node3D and str(body.get("resident_id")) == "nadia_quell":
				var routine: Node = body.get_parent()
				row.nadia_bodies.append({"path": str(body.get_path()), "at": str((body as Node3D).global_position),
						"visible": (body as Node3D).is_visible_in_tree(), "destination": str(routine.get("destination")) if routine != null else "",
						"blocked": str(routine.get("blocked_reason")) if routine != null else "", "travelled": routine.get("travelled_metres") if routine != null else 0})
		_check(arrived.size() == 1 and str(arrived[0].get("resident_id")) == "nadia_quell",
				"prints: Miss Quell's own routed body walked through the storefront to her photo_prints vertex inside, with Adela in sight")
		row.mark = str(owner_node.call("prints_mark", "nadia_quell"))
		_check(world.passage_region.prepared_shop_contains("shop_photo_supplies", (arrived[0] as Node3D).global_position + Vector3.UP * .8) if not arrived.is_empty() else false,
				"prints: she stands inside Photo Supplies")
		_check(_visible_bodies("nadia_quell") == 1, "prints: exactly one Nadia is visible (%d)" % _visible_bodies("nadia_quell"))
		var where: Dictionary = world.resident_whereabouts("nadia_quell")
		_check(str(where.get("place", "")) == "photo_supplies" and str(where.get("activity", "")) == "visit" and "photo:prints" in where.get("route", []),
				"prints: her whereabouts keep the shop place with the prints stop")
		row.nadia_at = (arrived[0] as Node3D).global_position if not arrived.is_empty() else null
	# Out of reach, looking at her.
	var far: Variant = _viewpoint(adela, reach + .3, reach + 1.5, true, place == "roof")
	if far != null:
		await _look_from(far, adela)
		_check(not RealityState.has_knowledge(attempt), "%s: looking from beyond %.1f m grants nothing" % [place, reach])
	# Close, looking away.
	# The shop scenes are seen from inside; the prints view keeps Miss Quell's face in the same picture.
	var nadia: Node3D = owner_node.call("routed_body", "nadia_quell") if place == "prints" else null
	var focus: Variant = null if nadia == null else (adela.global_position + nadia.global_position) * .5 + Vector3.UP * 1.55
	var near: Variant = _viewpoint(adela, 1.4, minf(reach - .4, 3.0), true, place == "roof", place != "roof", nadia)
	if not _check(near != null, "%s: a clear nearby viewpoint exists" % place):
		return
	await _look_from(near, adela, true)
	_check(not RealityState.has_knowledge(attempt), "%s: close but looking away grants nothing" % place)
	# Close, the face 45 degrees above the picture's centre: inside a 60-degree cone, outside the 72-degree picture.
	await _look_from(near, adela, false, 45.0)
	var head := adela.global_position + Vector3.UP * 1.55
	var camera: Camera3D = world.player.camera
	_check(not camera.is_position_in_frustum(head) and rad_to_deg((-camera.global_basis.z).angle_to(head - camera.global_position)) < 60.0,
			"%s: the face is above the top edge yet inside the old cone" % place)
	_check(not RealityState.has_knowledge(attempt), "%s: a face beyond the top edge grants nothing" % place)
	# A detached current camera looking right at her is not the player's sight.
	var detached := Camera3D.new()
	add_child(detached)
	detached.global_position = camera.global_position
	detached.look_at(head, Vector3.UP)
	detached.make_current()
	await _hold(1.6)
	_check(detached.is_position_in_frustum(head) and not RealityState.has_knowledge(attempt), "%s: a detached camera's view grants nothing" % place)
	detached.queue_free()
	camera.make_current()
	await get_tree().physics_frame
	# Close, a wall between.
	var hidden: Variant = _viewpoint(adela, .9, reach - .2, false, false)
	if hidden != null:
		await _look_from(hidden, adela)
		_check(not RealityState.has_knowledge(attempt), "%s: close with a wall between grants nothing" % place)
	row.hidden_viewpoint = hidden
	if early < minute:
		await _look_from(near, adela)
		_check(not RealityState.has_knowledge(attempt), "%s: a real look before %02d:%02d grants nothing" % [place, minute / 60, minute % 60])
		await _at(minute)
		await _settle(2.0, func() -> bool: return _thread() == thread)
		adela = owner_node.get("actor")
	# Sight is continuous and timed in real physics frames: a glance, or a look broken before a second, is not
	# enough; a sustained second is.
	await _look_from(near, adela, false, 0.0, .5, focus)
	await _look_from(near, adela, true, 0.0, .3)
	_check(not RealityState.has_knowledge(attempt), "%s: a half-second glance grants nothing" % place)
	await _look_from(near, adela, false, 0.0, .6, focus)
	await _look_from(near, adela, true, 0.0, .2)
	await _look_from(near, adela, false, 0.0, .6, focus)
	await _look_from(near, adela, true, 0.0, .3)
	_check(not RealityState.has_knowledge(attempt), "%s: two 0.6 s looks broken by a glance away grant nothing" % place)
	# The real look.
	await _look_from(near, adela, false, 0.0, 1.25, focus)
	_check(str(world.resident_whereabouts("adela_voss").get("place", "")) == ("roof" if place == "roof" else "photo_supplies"),
			"%s: her whereabouts name the staged place" % place)
	_check(RealityState.has_knowledge(attempt), "%s: a sustained look writes %s" % [place, attempt])
	_check(_only_attempts([attempt]), "%s: and no other attempt" % place)
	await _capture("friday_" + place)


func _reset_flags() -> void:
	var known: Variant = RealityState.data.get("knowledge_flags")
	if known is Array:
		for flag: String in INTENTS + ATTEMPTS:
			(known as Array).erase(flag)


func _only_attempts(wanted: Array) -> bool:
	for flag: String in ATTEMPTS:
		if RealityState.has_knowledge(flag) != (flag in wanted):
			return false
	return true


func _thread() -> String:
	return str(owner_node.get("_current_thread"))


func _at(minute: int) -> void:
	_check(world.campaign_clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 7, 19, float(minute))), "clock at %02d:%02d" % [minute / 60, minute % 60])
	await _settle()


func _hold(seconds: float) -> void:
	for tick in ceili(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _settle(seconds := .6, until := Callable()) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if until.is_valid() and bool(until.call()):
			break
	await get_tree().physics_frame


## The shop's cell streams in with the player: stand at the shop window's inside stance until the enlarger is
## resident.
func _bring_shop() -> void:
	var vestibule: Dictionary = world.layout.spaces.filter(func(row: Dictionary) -> bool: return row.id == "F01_VESTIBULE")[0]
	var rect: Array = vestibule.rect
	world.player.global_position = world.adapter.root.to_global(Vector3((rect[0] + rect[2]) * .5, .025, (rect[1] + rect[3]) * .5))
	world.player.velocity = Vector3.ZERO
	await _settle(90.0, func() -> bool: return owner_node.call("enlarger_point") != null)
	_check(owner_node.call("enlarger_point") != null, "the shop is resident with its mounted enlarger")


## A standing place `low`..`high` metres from the person, with floor and room for the player, whose eye line to
## the person's head is clear (or, for `clear` false, blocked by something that is not the person).
func _viewpoint(person: Node3D, low: float, high: float, clear: bool, roof: bool, shop := false, also: Node3D = null) -> Variant:
	var head := person.global_position + Vector3.UP * 1.55
	var space := get_world_3d().direct_space_state
	for step in 6:
		var distance := lerpf(low, high, step / 5.0)
		for turn in 24:
			var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * turn / 24.0)
			var floor: Dictionary = owner_node.call("_stand_floor", person.global_position + direction * distance + Vector3.UP * 1.0)
			if floor.is_empty() or absf(floor.position.y - person.global_position.y) > .3 or not bool(owner_node.call("_clear", floor.position)):
				continue
			if roof and not str(world.room_at_world(floor.position + Vector3.UP * .8)).begins_with("ROOF_DECK_"):
				continue
			if shop and not world.passage_region.prepared_shop_contains("shop_photo_supplies", floor.position + Vector3.UP * .8):
				continue
			var eye: Vector3 = floor.position + Vector3.UP * 1.6
			if also != null:
				var other := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, also.global_position + Vector3.UP * 1.55, 1, [world.player.get_rid()]))
				if not other.is_empty() and not (other.collider is Node and also.is_ancestor_of(other.collider)):
					continue
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, head, 1, [world.player.get_rid()]))
			var open := hit.is_empty() or (hit.collider is Node and person.is_ancestor_of(hit.collider))
			if open == clear:
				return floor.position
	return null


func _look_from(at: Vector3, person: Node3D, away := false, pitch_down := 0.0, hold := 1.6, focus: Variant = null) -> void:
	world.player.global_position = at
	await get_tree().physics_frame
	var camera: Camera3D = world.player.camera
	var head: Vector3 = person.global_position + Vector3.UP * 1.55 if focus == null else focus
	var toward := head - camera.global_position
	if pitch_down != 0.0:
		var right := toward.cross(Vector3.UP).normalized()
		toward = toward.rotated(right, deg_to_rad(-pitch_down))  # look below: the face rises in the picture
	var target := camera.global_position + (toward if not away else -toward)
	camera.look_at(target, Vector3.UP)
	# Held in simulated time: the owner accumulates physics delta, so the fixture counts physics ticks.
	for tick in ceili(hold * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _visible_bodies(id: String) -> int:
	var count := 0
	for body: Node in get_tree().get_nodes_in_group("animated_residents"):
		if body is Node3D and str(body.get("resident_id")) == id and (body as Node3D).is_visible_in_tree():
			count += 1
	return count


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	var path := output.path_join(label + ".png")
	if picture != null and not picture.is_empty() and picture.save_png(path) == OK:
		details.captures.append({"path": path, "sha256": FileAccess.get_sha256(path)})


func _finish() -> void:
	if is_instance_valid(world):
		world.shutdown_for_tests()
		world.free()
	if lease:
		_check(RealityState.end_preview_campaign(self), "preview returned")
	CampaignTime.set_frozen_for_tests(prior_frozen)
	GameBoot.launch_mode = prior_mode
	for id: String in REQUIRED:
		_check(bool(contracts[id].executed) and str(contracts[id].status) == "PASS", "required contract " + id)
	var passed := failures.is_empty()
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "production_runtime": true, "selector": "v2",
			"suite": "AdelaFridayWitnessTest", "status": "PASS" if passed else "FAIL",
			"scope": "Actual V2 runtime on 19 July 1929: intent-staged Adela at parapet, enlarger and shop with Nadia; witness by the player's own unobstructed forward view within reach; declared teleported player placement and camera aim; loaded-save, 21:01 and FRIDAY reset. No walking arrival, artistic acceptance or Mr. Ewald body.",
			"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
			"source": {"test_path": "game/" + get_script().resource_path.trim_prefix("res://"), "test_sha256": FileAccess.get_sha256(get_script().resource_path),
					"owner_sha256": FileAccess.get_sha256("res://scripts/characters/adela_dated_encounters.gd")},
			"contracts": contracts, "checks": checks, "failures": failures, "details": details}
	var out := FileAccess.open(output.path_join("runtime_contract.json"), FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(result, "\t"))
		out.close()
	print("[ADELA FRIDAY WITNESS] RESULT: %s (%d checks, %d failures)" % ["PASS" if passed else "FAIL", checks.size(), failures.size()])
	get_tree().quit(0 if passed else 1)
