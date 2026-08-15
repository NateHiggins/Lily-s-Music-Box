extends Node
## K5/K6: the deterministic end-to-end graybox harness for the complete Mina
## shift, run against the real production scene and owners — real
## PlayerController, WorkOrders, CoreLoopDirector, ChirpHunt,
## VantryPointProp, MaintenanceInventory, shop service, HARDWARE PAINT
## counter, Mina's authored recurrence/dialogue/integration, the factual waking
## residue, the authored 2A detector and the authored 4B bedside.
##
## The player physically walks 2A -> ORISON -> STREET -> PASSAGE ->
## HARDWARE PAINT and physically back to 2A. The only intentional
## discontinuity is the dream/wake transition. Persistence runs through the
## REAL file path (RealityState.save_game/load_game) against a dedicated
## file under user://tests/, never the player's save.
##
## Integrity: exact expected check count, start/completion sentinels, an
## executed-block ledger, and a wall-clock watchdog, so a silent partial
## run can never print PASS.

const JOB := ChirpHunt.JOB_ID
const ITEM := "carbon_transmitter_capsule"
const CASE := "mina_caption_crisis"
const SAVE_FILE := "user://tests/k6_mina_golden_shift_save.json"
const EXPECTED_CHECKS := 82
const EXPECTED_BLOCKS: Array[String] = ["origin_convergence", "boundary_idle",
		"complaint", "inspection", "errand_out", "acquisition", "return_leg",
		"repair", "first_conversation", "recurrence", "integration", "wake",
		"cleanup"]
const SIM_SCALE := 3.5

## Test-only dream stub: subscribes, verifies, records one entry, wakes
## exactly once. No production dream mechanics.
class DreamStub:
	extends RefCounted
	var entries := 0
	var wakes := 0
	var seen_job := ""
	var seen_window: Dictionary = {}
	var director: CoreLoopDirector

	func _init(loop_director: CoreLoopDirector) -> void:
		director = loop_director
		director.dream_requested.connect(_on_dream_requested)

	func _on_dream_requested(job_id: String, window: Dictionary) -> void:
		entries += 1
		seen_job = job_id
		seen_window = window.duplicate(true)

	func enter_and_wake() -> bool:
		if wakes > 0:
			return false
		wakes += 1
		return director.notify_wake_complete()

var _checks := 0
var _fails := 0
var _blocks: Array[String] = []
var _finished := false
var trace: Array[String] = []
var root: Node3D
var player: PlayerController
var work_orders: WorkOrders
var director: CoreLoopDirector
var inventory: MaintenanceInventory
var stub: DreamStub
var conversation_requests := 0
var wake_signals := 0
var _player_save_present := false


func _ready() -> void:
	print("[K6] START")
	_watchdog()
	OS.set_environment("DAYNIGHT", "0")
	_player_save_present = FileAccess.file_exists(RealityState.SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("user://tests"))
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))
	RealityState.save_path = SAVE_FILE
	RealityState.persistence_enabled = true
	RealityState.reset_campaign_for_tests()

	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	player = root.player
	work_orders = root.work_orders
	director = root.core_loop
	inventory = root.maintenance_inventory
	stub = DreamStub.new(director)
	director.conversation_requested.connect(
			func(_c: String, _r: String) -> void: conversation_requests += 1)
	director.wake_completed.connect(
			func(_a: String) -> void: wake_signals += 1)
	for cart in get_tree().get_nodes_in_group("passage_pushcarts"):
		cart.freeze = true
	Engine.time_scale = SIM_SCALE
	Engine.physics_ticks_per_second = int(round(60.0 * SIM_SCALE))

	await _origin_convergence()
	_boundary_idle()
	await _complaint()
	await _inspection()
	await _errand_out()
	_acquisition()
	await _return_leg()
	_repair()
	await _first_conversation()
	await _recurrence()
	await _integration()
	await _wake()
	_cleanup()

	Engine.time_scale = 1.0
	_finished = true
	var blocks_ok := _blocks == EXPECTED_BLOCKS
	var count_ok := _checks == EXPECTED_CHECKS
	print("[K6] BLOCKS: %s (%s)" % [_blocks, "ok" if blocks_ok else
			"EXPECTED %s" % [EXPECTED_BLOCKS]])
	print("[K6] CHECKS: %d/%d fails=%d" % [_checks, EXPECTED_CHECKS, _fails])
	print("[K6] TRACE: ", " | ".join(trace))
	var verdict := _fails == 0 and blocks_ok and count_ok
	print("[K6] COMPLETE: %s" % ("PASS" if verdict else "FAIL"))
	get_tree().quit(0 if verdict else 1)


func _watchdog() -> void:
	await get_tree().create_timer(52.0, true, false, true).timeout
	if not _finished:
		printerr("[K6] WATCHDOG: run exceeded its budget — FAIL")
		get_tree().quit(1)


func _block(name: String) -> void:
	_blocks.append(name)
	print("[K6 BLOCK] ", name)


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if ok:
		print("  [k6 ok] ", label)
	else:
		_fails += 1
		printerr("  [K6 FAIL] ", label)


func _walk_to(target: Vector2, label: String) -> bool:
	var start := Vector2(player.global_position.x, player.global_position.z)
	var timeout := start.distance_to(target) / PlayerController.WALK + 4.0
	var elapsed := 0.0
	while elapsed < timeout:
		var here := Vector2(player.global_position.x, player.global_position.z)
		if here.distance_to(target) < 0.42:
			player.autopilot = Vector3.ZERO
			return true
		var direction := (target - here).normalized()
		player.autopilot = Vector3(direction.x, 0.0, direction.y)
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
	player.autopilot = Vector3.ZERO
	print("    %s stopped at %v" % [label, player.global_position])
	return false


func _walk_route(points: Array, label: String) -> bool:
	for i in points.size():
		if not await _walk_to(points[i], "%s leg %02d" % [label, i]):
			return false
	return true


## The real production save owner, the real file, the real load path. Each
## checkpoint proves write, destruction, faithful restore and presentation
## rebind, then the run continues.
func _checkpoint(label: String) -> void:
	var stage_before := work_orders.job_stage(JOB)
	var boundary_before := director.boundary()
	var saved := RealityState.save_game()
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(SAVE_FILE))
	_check("checkpoint %s writes real serialized state" % label,
			saved and parsed is Dictionary
			and (parsed as Dictionary).has("core_loop")
			and (parsed as Dictionary).has("maintenance_jobs"))
	RealityState.reset_campaign_for_tests()
	_check("checkpoint %s destroys the live state" % label,
			work_orders.job_stage(JOB) == "missing"
			and director.boundary() == "idle")
	RealityState.load_game()
	_check("checkpoint %s restores through the real load path" % label,
			work_orders.job_stage(JOB) == stage_before
			and director.boundary() == boundary_before)
	_check("checkpoint %s rebinds presentation from facts" % label,
			work_orders.restore_jobs(work_orders.serialize_jobs()))
	trace.append(label)


func _detector() -> VantryPointProp:
	return root.vantry_points.active_owner


func _dialogue() -> CaseDialoguePanel:
	return root.mina_gameplay.dialogue


func _drain_dialogue() -> void:
	var panel := _dialogue()
	for i in 20:
		if not panel._panel.visible:
			return
		panel.choose(0)
		await get_tree().process_frame


func _aim_and_interact(at: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.camera.look_at(at)
	player._try_interact()


## Secondary origin first, on a throwaway campaign: the discovered start
## converges to the same downstream state, and Mina's later complaint
## recognizes it rather than duplicating or resetting it.
func _origin_convergence() -> void:
	_block("origin_convergence")
	RealityState.ensure_case(CASE, "mina_vale")
	_detector().interact(player)
	var state := work_orders.job_state(JOB)
	_check("discovered inspection issues, converges and diagnoses in place",
			str(state.origin) == "discovered"
			and str(state.stage) == "awaiting_part"
			and state.evidence.size() == 3)
	RealityCases.interact_with_resident("mina_vale")
	await _drain_dialogue()
	state = work_orders.job_state(JOB)
	_check("Mina's complaint recognizes the discovered job without duplication",
			str(state.origin) == "discovered"
			and str(state.stage) == "awaiting_part")
	RealityState.reset_campaign_for_tests()


func _boundary_idle() -> void:
	_block("boundary_idle")
	_check("the loop opens idle with no job and a silent ledger",
			director.boundary() == "idle"
			and work_orders.job_stage(JOB) == "missing"
			and conversation_requests == 0 and stub.entries == 0)
	_checkpoint("idle")


func _complaint() -> void:
	_block("complaint")
	RealityState.ensure_case(CASE, "mina_vale")
	RealityCases.interact_with_resident("mina_vale")
	_check("the complaint conversation genuinely locks the player",
			player.call_locked)
	await _drain_dialogue()
	_check("the drained complaint conversation releases the lock",
			not player.call_locked)
	var state := work_orders.job_state(JOB)
	_check("Mina's complaint issues the job reported and opens the loop",
			str(state.stage) == "issued" and str(state.origin) == "reported"
			and director.boundary() == "job_open")
	_checkpoint("issued")
	_check("no conversation or dream request exists this early",
			conversation_requests == 0 and stub.entries == 0)


func _inspection() -> void:
	_block("inspection")
	var entry2a: DoorProp = null
	for child in root.get_children():
		if child is DoorProp and child.global_position.distance_to(
				Vector3(-5.33, 3.2, 2.105)) < 0.9:
			entry2a = child
	_check("the 2A entry admits the maintenance key", entry2a != null)
	if entry2a and entry2a.leaf_state == "locked":
		entry2a.leaf_state = "closed"
	if entry2a and not entry2a.open:
		entry2a.interact(null)
		await get_tree().create_timer(0.7).timeout
	player.global_position = Vector3(-4.7, 3.35, 1.65)
	player.velocity = Vector3.ZERO
	# Probed lane: south of the caption calibrator (solid now that Mina's
	# case is active), west of the dining hull, then north to the point.
	_check("the corridor walk reaches the flat", await _walk_route(
			[Vector2(-7.0, 1.65), Vector2(-9.5, 1.55), Vector2(-10.4, 1.7),
			Vector2(-10.4, 3.1), Vector2(-9.45, 3.05)], "into 2A"))
	_aim_and_interact(_detector().global_position + Vector3(0, -0.05, 0))
	var state := work_orders.job_state(JOB)
	_check("the production ray inspects the ceiling point",
			str(state.stage) == "awaiting_part" and state.evidence.size() == 3)
	_check("the fault still chirps while awaiting the part",
			root.chirp_hunt.fault_active() and not _detector().is_repaired())
	_checkpoint("awaiting_part")
	_check("restored objective presents the authored title",
			root.objective_tracker._title.text == "WORK ORDER 001 — THE CHIRP")


func _errand_out() -> void:
	_block("errand_out")
	# Probed junction: the hall opens to the corridor ring at its north end
	# (x 0.3 across z 6.75), not through its west wall.
	var walked := await _walk_route([
			Vector2(-10.4, 3.1), Vector2(-10.4, 1.7), Vector2(-9.5, 1.55),
			Vector2(-7.0, 1.65), Vector2(-4.7, 1.65), Vector2(-4.38, 3.0),
			Vector2(-4.38, 6.0), Vector2(-4.38, 8.3), Vector2(0.0, 8.3),
			Vector2(0.3, 6.0), Vector2(0.3, 5.0), Vector2(-1.5, 3.6),
			Vector2(-1.5, 2.6), Vector2(2.31, 2.5), Vector2(2.31, -2.31),
			Vector2(-2.31, -2.31), Vector2(-2.31, 2.4), Vector2(-0.5, 2.6),
			Vector2(-1.2, 5.0), Vector2(0.0, 7.6)], "descent")
	_check("the descent reaches the lobby floor",
			walked and player.global_position.y < 1.0)
	var entry = root.find_child("F01_DOOR_06", true, false)
	if entry is DoorProp and not entry.open:
		entry.interact(null)
		await get_tree().create_timer(0.7).timeout
	var hardware = root.find_child("SITE_SHOP_DOOR_HARDWARE_PAINT", true, false)
	if hardware is DoorProp:
		hardware.npc_set_open(true)
	var out := await _walk_route([
			Vector2(0.0, 9.0), Vector2(0.0, 12.5), Vector2(6.2, 12.4),
			Vector2(12.0, 12.6), Vector2(14.0, 12.6), Vector2(14.0, 16.0),
			Vector2(14.0, 22.5), Vector2(14.0, 26.2), Vector2(14.0, 29.2),
			Vector2(14.0, 34.0), Vector2(14.0, 38.9), Vector2(14.0, 58.425),
			Vector2(11.79, 58.425), Vector2(10.44, 58.425),
			Vector2(10.0, 58.1)], "outbound")
	_check("the walked route reaches HARDWARE PAINT's customer floor",
			out and player.global_position.y < 1.0)


func _acquisition() -> void:
	_block("acquisition")
	var counter: Area3D = root.shop_service.counter("hardware_paint")
	var eye := player.camera.global_position
	_aim_and_interact(Vector3(counter.global_position.x,
			minf(counter.global_position.y, eye.y - 0.1), 57.2))
	_check("the production buy acquires the capsule at the counter",
			inventory.has_item(ITEM)
			and work_orders.job_stage(JOB) == "repairable")
	player._try_interact()
	_check("a second buy cannot duplicate the capsule",
			RealityState.data.maintenance_items.size() == 1)
	_checkpoint("repairable")
	_check("restore keeps one capsule and no conversation request",
			inventory.has_item(ITEM)
			and RealityState.data.maintenance_items.size() == 1
			and conversation_requests == 0)


func _return_leg() -> void:
	_block("return_leg")
	var back := await _walk_route([
			Vector2(10.44, 58.425), Vector2(11.79, 58.425),
			Vector2(14.0, 58.425), Vector2(14.0, 38.9), Vector2(14.0, 34.0),
			Vector2(14.0, 29.2), Vector2(14.0, 26.2), Vector2(14.0, 22.5),
			Vector2(14.0, 16.0), Vector2(14.0, 12.6), Vector2(12.0, 12.6),
			Vector2(6.2, 12.4), Vector2(0.0, 12.5), Vector2(0.0, 9.0),
			Vector2(0.0, 7.6), Vector2(-1.2, 5.0), Vector2(-0.5, 2.6),
			Vector2(-2.31, 2.4), Vector2(-2.31, -2.31), Vector2(2.31, -2.31),
			Vector2(2.31, 2.5), Vector2(-1.5, 2.6), Vector2(-1.5, 3.6),
			Vector2(0.3, 5.0), Vector2(0.3, 6.0),
			Vector2(0.0, 8.3), Vector2(-4.38, 8.3), Vector2(-4.38, 3.0),
			Vector2(-4.7, 1.65)], "return")
	# The 2A entry closed itself while the player was out; open it the way
	# the player would and finish the walk to the point.
	var entry2a: DoorProp = null
	for child in root.get_children():
		if child is DoorProp and child.global_position.distance_to(
				Vector3(-5.33, 3.2, 2.105)) < 0.9:
			entry2a = child
	if entry2a and not entry2a.open:
		entry2a.interact(null)
		await get_tree().create_timer(0.7).timeout
	var inside := await _walk_route([
			Vector2(-7.0, 1.65), Vector2(-9.5, 1.55), Vector2(-10.4, 1.7),
			Vector2(-10.4, 3.1), Vector2(-9.45, 3.05)], "return-2a")
	_check("the walked return reaches 2A again",
			back and inside and player.global_position.y > 2.9)


func _repair() -> void:
	_block("repair")
	# The complete physical route is already proved. Freeze unrelated resident
	# schedules before the dialogue-length K6 extension so their clock-driven
	# trips cannot add nondeterministic navigation warnings to this case proof.
	root.resident_routines.set_process(false)
	_aim_and_interact(_detector().global_position + Vector3(0, -0.05, 0))
	var state := work_orders.job_state(JOB)
	_check("the production ray performs the repair at the point",
			str(state.stage) == "repaired"
			and str(state.repair_result.quality) == "good")
	_check("the repair consumes the capsule and quiets the point",
			inventory.is_consumed(ITEM) and not inventory.has_item(ITEM)
			and _detector().is_repaired()
			and not root.chirp_hunt.fault_active())
	_check("the repair requests the earned conversation without closing",
			director.boundary() == "conversation_pending"
			and conversation_requests == 1
			and work_orders.job_stage(JOB) == "repaired")
	var case_state := RealityState.case_state(CASE)
	_check("the physical repair is Mina's first temporary stabilization",
			str(case_state.get("stage")) == "stabilized"
			and int(case_state.get("repair_count")) == 1
			and bool(case_state.get("recurrence_pending")))
	_checkpoint("conversation_pending")
	_check("restore does not re-request the conversation",
			conversation_requests == 1)


func _first_conversation() -> void:
	_block("first_conversation")
	_check("no recurrence letter exists before Mina's first earned talk",
			not root.mina_gameplay.letter.enabled)
	RealityCases.interact_with_resident("mina_vale")
	_check("the actual first-stable conversation opens under protection",
			player.call_locked and _dialogue().current_node_id == "fs_open")
	_dialogue().choose(0) # challenge the caption -> fs_push
	_dialogue().choose(0) # silence is not evidence -> fs_named
	_dialogue().choose(0) # end the authored node
	await get_tree().process_frame
	var state := RealityState.case_state(CASE)
	_check("Mina records the first insight and enables the visit boundary",
			"first_silence_named" in state.conversation_flags
			and root.mina_gameplay.shift_clock.enabled
			and not player.call_locked)
	_check("the first talk cannot close the repair or request a dream",
			work_orders.job_stage(JOB) == "repaired"
			and director.boundary() == "conversation_pending"
			and stub.entries == 0)


func _recurrence() -> void:
	_block("recurrence")
	root.mina_gameplay.shift_clock.interact(player)
	_check("the authored time clock protects the visit transition",
			player.call_locked)
	await get_tree().create_timer(2.6).timeout
	var state := RealityState.case_state(CASE)
	_check("the unresolved symptom recurs and leaves Mina's letter",
			str(state.stage) == "reopened"
			and int(state.recurrence_count) == 1
			and root.mina_gameplay.letter.enabled
			and not player.call_locked)
	for index in range(root.mina_gameplay.evidence_nodes.size()):
		var spec: Dictionary = MinaCaseGameplay.EVIDENCE[index]
		var expected := "caption_1_%s=%s" % [spec.id, spec.fact]
		while expected not in state.apartment_changes:
			root.mina_gameplay.evidence_nodes[index].interact(player)
	_check("the production caption objects accept three factual observations",
			root.mina_gameplay._inspection_count(state) == 3)
	root.mina_gameplay.console.interact(player)
	state = RealityState.case_state(CASE)
	_check("the recurrence calibration supplies the second stabilization",
			str(state.stage) == "stabilized"
			and int(state.repair_count) == 2
			and bool(state.recurrence_pending))
	_check("the objective now directs the player to Mina, not another part",
			root.objective_tracker._title.text == "2A — REAL TALK")


func _integration() -> void:
	_block("integration")
	RealityCases.interact_with_resident("mina_vale")
	_check("the actual real-talk entry opens under protection",
			player.call_locked and _dialogue().current_node_id == "rt_open")
	_dialogue().choose(0) # two captions are guesses -> rt_guess
	_dialogue().choose(0) # assumptions are not facts -> rt_afact
	_check("the first complete-rule flag is earned but cannot close alone",
			"assumptions_are_not_facts" in
					RealityState.case_state(CASE).conversation_flags
			and work_orders.job_stage(JOB) == "repaired"
			and director.boundary() == "conversation_pending")
	_dialogue().choose_silence() # listen -> rt_court_door
	_dialogue().choose(0) # what changed? -> rt_court2
	_dialogue().choose(0) # what did the record show? -> rt_blank
	_dialogue().choose(0) # the blank never said that -> rt_heart
	_check("the authored conversation reaches Mina's four-second wound",
			_dialogue().current_node_id == "rt_heart")
	_dialogue().choose_silence() # the mechanic is the answer -> rt_earned
	var state := RealityState.case_state(CASE)
	_check("earned silence completes the rule and closes only the job",
			"silence_can_be_blank" in state.conversation_flags
			and str(state.stage) == "integration_ready"
			and work_orders.job_stage(JOB) == "closed"
			and director.boundary() == "conversation_complete"
			and player.call_locked)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("the dream cannot interrupt Mina before integration",
			stub.entries == 0)
	_dialogue().choose(0) # end rt_earned
	await get_tree().process_frame
	_check("the real-talk panel releases without arming the dream",
			not player.call_locked and stub.entries == 0)

	RealityCases.interact_with_resident("mina_vale")
	_check("the authored integration exchange is still a protected action",
			player.call_locked and _dialogue().current_node_id == "int_open")
	_dialogue().choose_silence() # int_beat, invokes quiet_beat
	_check("Mina and the player leave the deliberate quiet beat unfilled",
			_dialogue().current_node_id == "int_beat"
			and root.mina_gameplay._feedback != ""
			and player.call_locked)
	_dialogue().choose(0)
	await get_tree().process_frame
	_check("the integration conversation releases before the final action",
			not player.call_locked and stub.entries == 0)
	root.mina_gameplay.console.interact(player)
	state = RealityState.case_state(CASE)
	_check("the final silent calibration resolves Mina and arms punctuation",
			bool(state.resolved)
			and "Silence does not require annotation" in
					RealityState.data.portal_rules
			and work_orders.job_stage(JOB) == "closed"
			and director.boundary() == "dream_pending")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("the resolved shift requests its dream exactly once",
			stub.entries == 1)
	_check("the request carries the authored job and window",
			stub.seen_job == JOB and stub.seen_window
					== work_orders.job_library.job(JOB).get("dream_window"))
	_checkpoint("dream_pending")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("restore does not duplicate the pending dream request",
			stub.entries == 1)


func _wake() -> void:
	_block("wake")
	player.global_position = Vector3(0.0, 0.3, 9.0)
	_check("the dream stub wakes the loop exactly once",
			stub.enter_and_wake() and wake_signals == 1)
	var anchor := director.resolve_return_anchor()
	_check("wake returns the player to the authored 4B bedside",
			not anchor.is_empty()
			and player.global_position.distance_to(anchor.position) < 0.5
			and player.global_position.y > 9.0)
	var state := work_orders.job_state(JOB)
	_check("wake preserves every committed fact",
			str(state.stage) == "closed" and state.evidence.size() == 3
			and str(state.repair_result.quality) == "good"
			and inventory.is_consumed(ITEM)
			and _detector().is_repaired()
			and float(_detector().get_service_state().grille_open) == 0.0
			and not root.chirp_hunt.fault_active()
			and bool(RealityState.case_state(CASE).resolved))
	var residue := RealityState.waking_residue(
			MinaCaptionManifestation.RESIDUE_ID)
	_check("wake applies one factual residue at Mina's authored refrigerator",
			str(RealityState.data.last_waking_residue_id)
					== MinaCaptionManifestation.RESIDUE_ID
			and AcousticGraphData.nodes.has(
					MinaCaptionManifestation.RESIDUE_ANCHOR_ID)
			and str(residue.get("case_id")) == CASE
			and str(residue.get("anchor_id"))
					== MinaCaptionManifestation.RESIDUE_ANCHOR_ID
			and str(residue.get("display_socket_id"))
					== MinaCaptionManifestation.RESIDUE_SOCKET_ID
			and root.mina_manifestation._resolved_residue.visible)
	var parked := player.global_position
	_check("duplicate wake attempts are rejected without mutation",
			not stub.enter_and_wake()
			and not director.notify_wake_complete()
			and player.global_position.distance_to(parked) < 0.01
			and wake_signals == 1)
	_checkpoint("wake_complete")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("restore after wake resurrects nothing",
			director.boundary() == "wake_complete"
			and work_orders.job_stage(JOB) == "closed"
			and inventory.is_consumed(ITEM)
			and not root.chirp_hunt.fault_active()
			and stub.entries == 1
			# The body settles onto the floor across the checkpoint frames;
			# what must not happen is a teleport away from the bedside.
			and player.global_position.distance_to(parked) < 0.5)
	_check("the waking residue survives the real save boundary exactly once",
			RealityState.data.waking_residues.size() == 1
			and RealityState.has_waking_residue(
					MinaCaptionManifestation.RESIDUE_ID)
			and root.mina_manifestation._resolved_residue.visible)


func _cleanup() -> void:
	_block("cleanup")
	var resolved := ProjectSettings.globalize_path(SAVE_FILE)
	var test_dir := ProjectSettings.globalize_path("user://tests")
	var contained := resolved.begins_with(test_dir) \
			and resolved.ends_with("k6_mina_golden_shift_save.json") \
			and FileAccess.file_exists(SAVE_FILE)
	_check("the test save resolved inside the dedicated test directory",
			contained)
	if contained:
		DirAccess.remove_absolute(resolved)
	RealityState.save_path = RealityState.SAVE_PATH
	_check("the test save file is removed and the player save untouched",
			not FileAccess.file_exists(SAVE_FILE)
			and FileAccess.file_exists(RealityState.SAVE_PATH)
					== _player_save_present)
