extends Node
## GATE D: the shift and the dream, joined.
##
## Both halves of this have existed and passed for a while and have never been
## connected. `GoldenLoopTest` plays the whole Mina shift at 87/87 but
## instantiates `orison_root.tscn` DIRECTLY and answers the dream request with
## a test-only `DreamStub`; its own comment says "No production dream
## mechanics", and it predates N4. `DreamPursuitTest` runs the real
## CampaignShell, the real maze, the Tenant and a real capture through to wake
## — but reaches that state via `_seed_completed_shift()`, writing finished job
## facts straight into RealityState rather than earning them.
##
## So nothing walked the whole thing, and the gap was invisible because both
## tests are green and each looks complete from the inside.
##
## This harness earns the dream. The shift is played against the real owners,
## the case resolves, the production CoreLoopDirector arms the real
## DreamDirector, the real SleepPressureDirector runs its five gates and calls
## entry, the real maze is assembled, the passage ends through
## DreamMazeRoot's own outcome funnel, the real waking Orison is rebuilt from
## committed facts, and the body arrives at the authored 4B bedside.
##
## WHAT THIS DOES NOT PROVE, deliberately, because another harness owns it:
##   * the walked errand route — `GoldenLoopTest`, 87 checks. Between shift
##     beats this teleports to the literal terminal waypoints its routes end
##     at. Re-walking ~238 m costs ~23 wall seconds and buys coverage that is
##     already green.
##   * the engine-delta onset clock — `SleepPressureTest`. This drives onset
##     through `advance_for_test`, which runs the exact production `_advance`
##     body including all five gates and the real `enter_armed_dream()`. See
##     the note on the manual clock below; it is not a convenience.
##   * the pursuit timing curve — `DreamPursuitTest`, 39 checks.
##   * persistence breadth — `GoldenLoopTest` takes eight checkpoints. This
##     takes the two that bracket the join.
##
## WHY THE MANUAL SLEEP CLOCK IS REQUIRED, NOT PREFERRED. On the production
## clock the onset is 2.60 sim-seconds, which at SIM_SCALE is 0.74 wall
## seconds after the case resolves. Every gate passes at that moment — the
## body is parked at the 2A ceiling point, outside the elevator column and the
## traffic band, and `call_locked` is already false. So the dream enters in the
## middle of this harness's own post-arm assertions and CampaignShell frees the
## waking world under them. That is a use-after-free surfacing far from its
## cause, and it is deterministic rather than a race. `sleep_manual_clock`
## makes the harness say when.

const JOB := ChirpHunt.JOB_ID
const ITEM := "carbon_transmitter_capsule"
const CASE := "mina_caption_crisis"
## Sets the sign bit and sits outside JSON's exact-integer range, which is why
## every dream test uses this exact value.
const FIXED_SEED_HEX := "f123456789abcdef"
const SAVE_FILE := "user://tests/gate_d_join_save.json"
const SIM_SCALE := 3.5
## 70 on the capture run, 72 on the steered runs: steering adds the
## armed-hazard and Tenant-parked checks, and this file refuses to let a block
## quietly change size.
const EXPECTED_CHECKS := 69
const EXPECTED_BLOCKS: Array[String] = ["shell_boot", "origin_convergence",
		"boundary_idle",
		"complaint", "inspection", "acquisition", "repair",
		"first_conversation", "recurrence", "integration", "arm", "onset",
		"dream_entry", "dream_traverse", "wake", "rebuilt_world", "cleanup"]

var _checks := 0
var _fails := 0
var _blocks: Array[String] = []
var _finished := false
var trace: Array[String] = []

## Shell-owned and therefore immortal across both world swaps.
var shell: CampaignShell
var director: CoreLoopDirector
## World-owned and therefore dangling after every swap. Only ever written by
## _on_world_changed; never cached anywhere else.
var root: Node3D
var player: PlayerController
var work_orders: WorkOrders
var inventory: MaintenanceInventory
var maze: DreamMazeRoot

var world_sequence: Array[String] = []
var conversation_requests := 0
var wake_signals := 0
var armed_count := 0
var entered_count := 0
var ended_count := 0
var entry_requests := 0
var residue_signals := 0
var ended_outcome := ""
var _player_save_present := false
## The profile the DISCOVERED origin converges on, compared at arm time
## against the one the REPORTED origin actually delivers.
var discovered_profile := ""
## Which ending this invocation drives. All three share one latched funnel,
## but "they share a latch" is an argument, not a measurement.
var want_outcome := "capture"


func _ready() -> void:
	print("[GATE D] START")
	_watchdog()

	# Order matters. commit() writes to whatever save_path currently holds, and
	# it defaults to the player's real save, so the redirect must land before
	# anything touches state. DAYNIGHT must precede world construction, and
	# under a shell the construction happens inside add_child.
	OS.set_environment("DAYNIGHT", "0")
	_player_save_present = FileAccess.file_exists(RealityState.SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("user://tests"))
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))
	RealityState.save_path = SAVE_FILE
	RealityState.persistence_enabled = true
	RealityState.reset_campaign_for_tests()
	# reset_campaign_for_tests re-rolls the dream seed every call, and
	# DreamDirector copies it into the context at ARM time. Pin it or the maze
	# is a different maze on every run and a capture time means nothing.
	RealityState.data.dream_seed = FIXED_SEED_HEX
	var asked := OS.get_environment("GATE_D_OUTCOME")
	if asked in DreamDirector.OUTCOMES:
		want_outcome = asked
	print("[GATE D] TARGET OUTCOME: %s" % want_outcome)

	await _spawn_shell()
	Engine.time_scale = SIM_SCALE
	Engine.physics_ticks_per_second = int(round(60.0 * SIM_SCALE))

	await _origin_convergence()
	_boundary_idle()
	await _complaint()
	await _inspection()
	await _acquisition()
	_repair()
	await _first_conversation()
	await _recurrence()
	await _integration()
	await _arm()
	_onset()
	await _dream_entry()
	await _dream_traverse()
	await _wake()
	_rebuilt_world()
	_cleanup()

	# GoldenLoopTest restores time_scale and never restores the tick rate.
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	_finished = true
	var blocks_ok := _blocks == EXPECTED_BLOCKS
	var expect := EXPECTED_CHECKS + (0 if want_outcome == "capture" else 2)
	var count_ok := _checks == expect
	print("[GATE D] BLOCKS: %s (%s)" % [_blocks, "ok" if blocks_ok else
			"EXPECTED %s" % [EXPECTED_BLOCKS]])
	print("[GATE D] CHECKS: %d/%d fails=%d" % [_checks, expect, _fails])
	print("[GATE D] TRACE: ", " | ".join(trace))
	print("[GATE D] WORLDS: ", " -> ".join(world_sequence))
	print("[GATE D] OUTCOME: %s" % ended_outcome)
	var verdict := _fails == 0 and blocks_ok and count_ok
	print("[GATE D] COMPLETE: %s" % ("PASS" if verdict else "FAIL"))
	get_tree().quit(0 if verdict else 1)


func _watchdog() -> void:
	# ignore_time_scale is MANDATORY. Without it a 52 s watchdog fires at 14.9
	# wall seconds under SIM_SCALE and every run reports a false timeout.
	await get_tree().create_timer(52.0, true, false, true).timeout
	if not _finished:
		printerr("[GATE D] WATCHDOG: run exceeded its budget — FAIL")
		get_tree().quit(1)


# --- the join itself --------------------------------------------------

## The entire join is three lines: a CampaignShell, its default
## waking_scene_path, and no stub. Everything else here is consequence.
func _spawn_shell() -> void:
	shell = CampaignShell.new()
	shell.name = "CampaignShellUnderTest"
	# All three must land between .new() and add_child: _ready copies
	# sleep_manual_clock once, and _restore_world builds the entire waking
	# world synchronously inside add_child, emitting world_changed before
	# add_child even returns.
	shell.sleep_manual_clock = true
	shell.world_changed.connect(_on_world_changed)
	add_child(shell)
	await get_tree().create_timer(1.6).timeout

	director = shell.core_loop
	director.conversation_requested.connect(
			func(_c: String, _r: String) -> void: conversation_requests += 1)
	director.wake_completed.connect(
			func(_a: String) -> void: wake_signals += 1)
	# Valid only because this harness spawns exactly ONE shell. A respawn
	# would own a fresh DreamDirector and these would watch a freed object.
	shell.dream_director.dream_armed.connect(
			func(_c: String, _p: String) -> void: armed_count += 1)
	shell.dream_director.dream_entered.connect(
			func(_c: String, _s: String) -> void: entered_count += 1)
	shell.dream_director.dream_ended.connect(
			func(_c: String, outcome: String) -> void:
				ended_count += 1
				ended_outcome = outcome)
	shell.sleep_pressure.sleep_entry_requested.connect(
			func(_c: String, _f: String) -> void: entry_requests += 1)
	RealityState.waking_residue_applied.connect(
			func(_id: String, _facts: Dictionary) -> void:
				residue_signals += 1)

	_block("shell_boot")
	# THE ASSERTION THAT DECIDES WHETHER THIS HARNESS TESTS ANYTHING. Under a
	# shell, BuildingRoot hands its coordinator to bind_waking_services; on its
	# own it builds a private one. If the fork went the wrong way no
	# dream_requested ever reaches DreamDirector and the run would die forty
	# seconds later as a watchdog timeout rather than as an assertion.
	_check("the production fork ran: the shell owns the coordinator",
			shell.world_kind() == "waking" and shell.world_child_count() == 1
			and root != null and root.name == "OrisonRoot"
			and root.get("core_loop") == shell.core_loop
			and shell.core_loop.get_parent() == shell)
	# A null elevator or traffic short-circuits its own gate and reads as a
	# clean pass, so prove the gates are actually bound to something.
	_check("the sleep gates are bound to a real body, lift and street",
			shell.sleep_pressure.player == player
			and shell.sleep_pressure.elevator != null
			and shell.sleep_pressure.traffic != null
			and shell.sleep_pressure.manual_clock)
	_check("the dream is quiet and the seed is pinned before any play",
			shell.dream_director.phase() == "awake" and armed_count == 0
			and str(RealityState.data.dream_seed) == FIXED_SEED_HEX
			and world_sequence == ["waking"])


## Every world-owned reference dies on each swap: CampaignShell removes and
## free()s immediately, not queue_free. One handler re-acquires them all.
func _on_world_changed(kind: String, world: Node) -> void:
	world_sequence.append(kind)
	if kind != "waking":
		maze = world as DreamMazeRoot
		return
	root = world as Node3D
	player = root.player
	work_orders = root.work_orders
	inventory = root.maintenance_inventory
	# Two determinism suppressions the rebuild silently undoes.
	for cart in get_tree().get_nodes_in_group("passage_pushcarts"):
		cart.freeze = true
	if root.get("resident_routines") != null:
		root.resident_routines.set_process(false)


## Gate D's third bullet: reported and discovered origins converge on the same
## dream profile. Played on a throwaway campaign that is then discarded.
##
## Precise about what this proves. It measures that both origins converge on
## the same job in the same stage, and that the profile is a fact READ FROM
## that job rather than derived from how the job started — so the origin
## cannot change it. `discovered_profile` is then compared at arm time against
## the id the reported origin actually delivers into the real transaction.
## What it does NOT do is play the discovered origin all the way to a second
## real entry; that would need a second full shift and would not fit the
## budget.
func _origin_convergence() -> void:
	_block("origin_convergence")
	RealityState.ensure_case(CASE, "mina_vale")
	_detector().interact(player)
	var state := work_orders.job_state(JOB)
	_check("the discovered origin issues, converges and diagnoses in place",
			str(state.origin) == "discovered"
			and str(state.stage) == "awaiting_part"
			and state.evidence.size() == 3)
	RealityCases.interact_with_resident("mina_vale")
	await _drain_dialogue()
	state = work_orders.job_state(JOB)
	_check("Mina's complaint recognizes it without duplicating the job",
			str(state.origin) == "discovered"
			and str(state.stage) == "awaiting_part")
	# The convergence that is actually measurable is the JOB: the discovered
	# path could in principle have issued a different one. The profile is then
	# a property of that job, read from the library by CoreLoopDirector, and
	# the origin has no way to influence it.
	discovered_profile = str(work_orders.job_library.job(JOB).get(
			"dream_profile_id"))
	_check("the discovered origin issued this job, and it names a profile",
			work_orders.job_stage(JOB) != "missing"
			and not discovered_profile.is_empty()
			and armed_count == 0)
	# Discard the throwaway campaign, then re-pin: reset_campaign_for_tests
	# re-rolls the dream seed on every call.
	RealityState.reset_campaign_for_tests()
	RealityState.data.dream_seed = FIXED_SEED_HEX


# --- the shift, played, minus the walked errand -----------------------

func _boundary_idle() -> void:
	_block("boundary_idle")
	_check("the loop opens idle with no job and a silent ledger",
			director.boundary() == "idle"
			and work_orders.job_stage(JOB) == "missing"
			and conversation_requests == 0 and armed_count == 0)


func _complaint() -> void:
	_block("complaint")
	RealityState.ensure_case(CASE, "mina_vale")
	RealityCases.interact_with_resident("mina_vale")
	_check("the complaint conversation genuinely locks the player",
			player.call_locked)
	await _drain_dialogue()
	var state := work_orders.job_state(JOB)
	_check("Mina's complaint issues the job reported and opens the loop",
			not player.call_locked
			and str(state.stage) == "issued" and str(state.origin) == "reported"
			and director.boundary() == "job_open")


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
	_check("the corridor walk reaches the flat", await _walk_route(
			[Vector2(-7.0, 1.65), Vector2(-9.5, 1.55), Vector2(-10.4, 1.7),
			Vector2(-10.4, 3.1), Vector2(-9.45, 3.05)], "into 2A"))
	_aim_and_interact(_detector().global_position + Vector3(0, -0.05, 0))
	var state := work_orders.job_state(JOB)
	_check("the production ray inspects the ceiling point",
			str(state.stage) == "awaiting_part" and state.evidence.size() == 3
			and root.chirp_hunt.fault_active()
			and not _detector().is_repaired())


func _acquisition() -> void:
	_block("acquisition")
	var hardware = root.find_child("SITE_SHOP_DOOR_HARDWARE_PAINT", true, false)
	if hardware is DoorProp:
		hardware.npc_set_open(true)
	# GoldenLoopTest owns the walked route. Land on the literal terminal
	# waypoint its outbound leg ends at, then prove the body is actually
	# standing on the shop's customer floor before claiming to buy anything.
	_check("the teleport lands a settled body on HARDWARE PAINT's floor",
			await _settle_at(Vector3(10.0, 0.3, 58.1))
			and player.global_position.y < 1.0)
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
	_check("the return teleport reaches 2A with the capsule intact",
			await _settle_at(Vector3(-9.45, 3.35, 3.05))
			and player.global_position.y > 2.9 and inventory.has_item(ITEM))


func _repair() -> void:
	_block("repair")
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


func _first_conversation() -> void:
	_block("first_conversation")
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
	_check("the first talk cannot close the repair or arm a dream",
			work_orders.job_stage(JOB) == "repaired"
			and director.boundary() == "conversation_pending"
			and armed_count == 0)


func _recurrence() -> void:
	_block("recurrence")
	root.mina_gameplay.shift_clock.interact(player)
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
	root.mina_gameplay.console.interact(player)
	state = RealityState.case_state(CASE)
	_check("the recurrence calibration supplies the second stabilization",
			root.mina_gameplay._inspection_count(state) == 3
			and str(state.stage) == "stabilized"
			and int(state.repair_count) == 2
			and bool(state.recurrence_pending))


func _integration() -> void:
	_block("integration")
	RealityCases.interact_with_resident("mina_vale")
	_check("the actual real-talk entry opens under protection",
			player.call_locked and _dialogue().current_node_id == "rt_open")
	_dialogue().choose(0) # two captions are guesses -> rt_guess
	_dialogue().choose(0) # assumptions are not facts -> rt_afact
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
	_checkpoint("conversation_complete")
	_check("restore at conversation-complete still waits, and never arms",
			work_orders.job_stage(JOB) == "closed"
			and director.boundary() == "conversation_complete"
			and bool(director.loop_state().conversation_complete)
			and armed_count == 0)
	_dialogue().choose(0) # end rt_earned
	await get_tree().process_frame
	_check("the real-talk panel releases without arming the dream",
			not player.call_locked and armed_count == 0)

	RealityCases.interact_with_resident("mina_vale")
	_check("the authored integration exchange is still a protected action",
			player.call_locked and _dialogue().current_node_id == "int_open")
	_dialogue().choose_silence() # int_beat, invokes quiet_beat
	_check("Mina and the player leave the deliberate quiet beat unfilled",
			_dialogue().current_node_id == "int_beat"
			and root.mina_gameplay._feedback != "")
	_dialogue().choose(0)
	await get_tree().process_frame
	root.mina_gameplay.console.interact(player)
	state = RealityState.case_state(CASE)
	_check("the final silent calibration resolves Mina and arms punctuation",
			bool(state.resolved)
			and "Silence does not require annotation" in
					RealityState.data.portal_rules
			and work_orders.job_stage(JOB) == "closed"
			and director.boundary() == "dream_pending")


# --- the seam ---------------------------------------------------------

## Everything from here is what GoldenLoopTest replaces with a stub.
func _arm() -> void:
	_block("arm")
	# CoreLoopDirector emits dream_requested from _process, not from the
	# resolve call itself, so the arm is one frame behind the shift.
	await get_tree().process_frame
	await get_tree().process_frame
	_check("the played shift armed the REAL DreamDirector, exactly once",
			armed_count == 1 and shell.dream_director.phase() == "armed"
			and entered_count == 0)
	var ctx := shell.dream_director.context()
	_check("the transaction carries the authored identity, not a guess",
			str(ctx.case_id) == CASE
			and str(ctx.profile_id) == str(work_orders.job_library.job(
					JOB).get("dream_profile_id"))
			and ctx.window == work_orders.job_library.job(JOB).get(
					"dream_window")
			and str(ctx.seed_hex) == FIXED_SEED_HEX
			# NOT a separate check: comparing ctx.profile_id to
			# discovered_profile would be an identity, since both resolve to
			# the same job-library field. The convergence proved above is the
			# job; the profile following from it is structural.
			and str(ctx.profile_id) == discovered_profile)
	# Assert the wake precondition now, while it is still cheap to diagnose:
	# if this is ever false, notify_wake_complete() refuses much later and the
	# failure reads as a dream bug rather than a loop-state bug.
	_check("the loop is genuinely dream-pending, so the wake can land",
			bool(director.loop_state().dream_pending))
	_checkpoint("dream_pending")
	_check("restore does not duplicate or lose the armed dream",
			armed_count == 1 and shell.dream_director.phase() == "armed"
			and shell.world_kind() == "waking")


func _onset() -> void:
	_block("onset")
	_check("the body is where the shift left it, and eligible",
			not player.call_locked and player.sleep_entry_body_is_stable()
			and player.global_position.y > 2.9)
	# Guards the silent zero-duration path: if _arm() bailed, _duration_s
	# stays 0.0, the elapsed < duration early return is false on the first
	# tick, and entry fires having skipped the entire warning.
	_check("the authored gradual warning is armed with real duration",
			shell.sleep_pressure.onset_form() == "gradual"
			and is_equal_approx(shell.sleep_pressure.pressure(), 0.0))
	_check("half the warning elapses and reads as half",
			shell.sleep_pressure.advance_for_test(1.3)
			and is_equal_approx(shell.sleep_pressure.pressure(), 0.5)
			and shell.dream_director.phase() == "armed"
			and shell.world_kind() == "waking")


func _dream_entry() -> void:
	_block("dream_entry")
	# The second advance reaches enter_armed_dream() synchronously, which
	# commits "entered" and asks the shell to swap. The shell DEFERS the swap,
	# so there is a real intermediate state and it is worth pinning.
	_check("finishing the warning enters before the world has changed",
			shell.sleep_pressure.advance_for_test(1.3)
			and shell.dream_director.phase() == "entered"
			and shell.world_kind() == "waking"
			and entry_requests == 1)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("the deferred swap installs the real maze as the only world",
			shell.dream_director.phase() == "active"
			and shell.world_kind() == "dream"
			and shell.world_child_count() == 1
			and entered_count == 1
			and world_sequence == ["waking", "dream"])
	# The literal D00 was retired by the owner ruling of 2026-08-18 -- the
	# waking room is now wherever the campaign seed put this case, and there
	# is no entrance to name. What this check was ever really asking is that
	# a REAL maze got built rather than a boundary payload: a named starting
	# room, a Tenant, a hazard field and a run ceiling.
	_check("the dream that built is the production maze, not a payload",
			maze != null and maze.maze_built
			and not maze.start_module_id().is_empty()
			and maze.pursuer != null and maze.hazards != null
			and maze.run_cap_s > 0.0)
	_check("the maze was assembled from the shift's own committed seed",
			str(RealityState.data.dream.seed_hex) == FIXED_SEED_HEX
			and str(RealityState.data.dream.case_id) == CASE)
	# dream_boundary_test's _exclusive() counts the "waking_world" group, which
	# only the boundary STUB joins — the real OrisonRoot joins "building_root".
	# Copying it here would report a false failure on a correct join.
	_check("no waking world survives alongside the dream",
			get_tree().get_nodes_in_group("dream_world").size() == 1
			and get_tree().get_nodes_in_group("building_root").is_empty())


func _dream_traverse() -> void:
	_block("dream_traverse")
	# maze.autonomous is left alone deliberately. DreamMazeRoot's own
	# _physics_process drives the pursuer, the hazards and the run ceiling,
	# and its group+ancestor lookup calls shell.dream_director.end_dream() —
	# THAT call is the seam Gate D exists to prove. Forcing an outcome from
	# outside would prove the plumbing while skipping the thing under test.
	for i in range(30):
		await get_tree().physics_frame
	_check("the dream body stands on real dream floor",
			maze != null and maze.player != null
			and maze.player.is_on_floor())
	if want_outcome != "capture":
		await _steer_to_hazard()
	var reached := false
	for i in range(2200):
		await get_tree().physics_frame
		if shell.dream_director.phase() in ["return_pending", "awake"]:
			reached = true
			break
	if not reached:
		printerr("  [GATE D debug] want=%s phase=%s worlds=%s"
				% [want_outcome, shell.dream_director.phase(),
				world_sequence])
		if maze != null and maze.pursuer != null:
			printerr("  [GATE D debug] captured=%s elapsed=%.2f cap=%.2f"
					% [maze.pursuer.is_captured, maze.run_elapsed_s,
					maze.run_cap_s])
	_check("the passage ends on its own through the production seam",
			reached and ended_count == 1
			and ended_outcome in DreamDirector.OUTCOMES)
	_check("the ending reached is the one this run set out to reach",
			ended_outcome == want_outcome)
	_check("the committed outcome is the one the dream actually reached",
			str(RealityState.data.dream.outcome) == ended_outcome)


## Walk the dream body into the hazard this run is proving.
##
## Capture needs no steering: stand still and the Tenant arrives. The other
## two endings sit at authored sockets the body has to actually reach, so
## this teleports NEAR the socket and then WALKS IN under the production
## controller — the same split the waking half of this harness uses, where
## travel between beats is a teleport but every interaction is real.
##
## The Tenant is parked at the chain's START first, not at its own spawn.
## Capture and the hazards share one latch, so whichever arrives first wins,
## and this run has to be able to reach the ending it was asked for — capture
## is already proven three ways over.
##
## Parking it at its own spawn was the first attempt and it was exactly wrong:
## `_far_spawn` places the Tenant in the LAST chain module, and the trunk's
## D05_SERVICE_RISER is at that end of the chain. The approach point came out
## 0.80 m from the Tenant against a 0.75 m capture radius, so the run was
## captured on the first physics frame after the teleport, every time. D00 is
## the other end of the chain and the only reliably distant place to put it.
func _steer_to_hazard() -> void:
	var target_id := "vantry_signal_trunk" if want_outcome == "contact" 			else "open_lift_void"
	var hazard: DreamHazard = null
	for h in maze.hazards.hazards:
		if h.id == target_id:
			hazard = h
	_check("the hazard this run is proving is armed in the built maze",
			hazard != null and maze.hazards.hazards.size() == 3)
	if hazard == null:
		return
	var start: Array = maze.plan.spawn_player
	maze.pursuer.reset_run(Vector3(start[0], 0.0, start[1]))
	# The trunk's arc reaches for the beam, so contact requires the lamp on;
	# the dream body already carries it lit from the threshold. The void
	# needs no light at all — it needs gravity.
	maze.player.set_lamp_enabled(want_outcome == "contact")
	# A fixed offset is not safe: +X from the trunk lands inside D05's wall,
	# so the body walks into plaster until the run ceiling folds the pursuit
	# and the Tenant takes the run instead. Probe for an approach that is
	# actually inside the hazard's own module.
	var approach := _walkable_approach(hazard)
	maze.player.global_position = Vector3(approach.x,
			maze.player.global_position.y, approach.z)
	maze.player.velocity = Vector3.ZERO
	# The Tenant must be far enough that it cannot decide this run. Assert it
	# rather than hope: a capture radius is 0.75 m and this is the check that
	# would have caught the first attempt immediately.
	_check("the Tenant is parked clear of the hazard under test",
			maze.pursuer.position.distance_to(maze.player.global_position)
					> 8.0)
	for i in range(20):
		await get_tree().physics_frame
		if shell.dream_director.phase() != "active":
			printerr("  [steer] dream ended during settle at frame %d" % i)
			return
	var into := (hazard.position - maze.player.global_position).normalized()
	maze.player.autopilot = Vector3(into.x, 0.0, into.z)



## A standing point 1.7 m from the socket that is still real floor in the
## hazard's own module, so the walk in crosses room rather than wall.
func _walkable_approach(hazard: DreamHazard) -> Vector3:
	var home := DreamMazeBuilder.nav_module_at(maze.plan,
			hazard.position.x, hazard.position.z)
	for step in range(16):
		var a := TAU * float(step) / 16.0
		var probe := hazard.position + Vector3(cos(a), 0.0, sin(a)) * 1.7
		if DreamMazeBuilder.nav_module_at(maze.plan, probe.x, probe.z) == home:
			return probe
	return hazard.position


func _wake() -> void:
	_block("wake")
	var woke := false
	for i in range(120):
		await get_tree().physics_frame
		if shell.dream_director.phase() == "awake":
			woke = true
			break
	# ignore_time_scale is mandatory: a plain 1.6 here is 0.46 wall seconds,
	# nowhere near enough for a second full eight-floor Orison build.
	await get_tree().create_timer(1.6, true, false, true).timeout
	_check("the waking Orison is rebuilt as the sole world",
			woke and world_sequence == ["waking", "dream", "waking"]
			and shell.world_kind() == "waking"
			and shell.world_child_count() == 1
			and root.name == "OrisonRoot"
			and get_tree().get_nodes_in_group("dream_world").is_empty())
	_check("the loop completed its wake exactly once",
			shell.dream_director.phase() == "awake"
			and director.boundary() == "wake_complete"
			and ended_count == 1 and wake_signals == 1)
	var anchor := director.resolve_return_anchor()
	_check("the body arrives at the authored 4B bedside in the NEW world",
			not anchor.is_empty()
			and player.global_position.distance_to(anchor.position) < 0.5
			and player.global_position.y > 9.0)
	var parked := player.global_position
	await get_tree().process_frame
	await get_tree().process_frame
	_check("nothing teleports the rebuilt body away from the bedside",
			player.global_position.distance_to(parked) < 0.5
			and not bool(RealityState.data.get("intro_complete", false)))
	_check("a duplicate wake is refused without mutation",
			not director.notify_wake_complete() and wake_signals == 1)


## The strongest new proof in the harness. These facts are not simply still
## present — the world that produced them no longer exists. ChirpHunt.setup()
## on the REBUILT world reconciled the point to repaired from the job stage
## alone, so this is the committed record reconstructing the building.
func _rebuilt_world() -> void:
	_block("rebuilt_world")
	var state := work_orders.job_state(JOB)
	_check("the rebuilt world recovers every committed job fact",
			str(state.stage) == "closed" and state.evidence.size() == 3
			and str(state.repair_result.quality) == "good"
			and inventory.is_consumed(ITEM))
	_check("the rebuilt point is quiet because the record says it was fixed",
			_detector().is_repaired()
			and float(_detector().get_service_state().grille_open) == 0.0
			and not root.chirp_hunt.fault_active())
	_check("Mina's case survives the passage resolved",
			bool(RealityState.case_state(CASE).resolved)
			and "Silence does not require annotation" in
					RealityState.data.portal_rules)
	var residue := RealityState.waking_residue(
			MinaCaptionManifestation.RESIDUE_ID)
	_check("the passage left exactly one factual residue, at its anchor",
			residue_signals == 1
			and RealityState.data.waking_residues.size() == 1
			and RealityState.has_waking_residue(
					MinaCaptionManifestation.RESIDUE_ID)
			and str(residue.get("case_id")) == CASE
			and str(residue.get("anchor_id"))
					== MinaCaptionManifestation.RESIDUE_ANCHOR_ID
			and root.mina_manifestation._resolved_residue.visible)
	_checkpoint("wake_complete")
	_check("restore after the whole passage resurrects nothing",
			director.boundary() == "wake_complete"
			and work_orders.job_stage(JOB) == "closed"
			and inventory.is_consumed(ITEM)
			and not root.chirp_hunt.fault_active()
			and armed_count == 1 and entered_count == 1 and ended_count == 1
			and RealityState.data.waking_residues.size() == 1)


func _cleanup() -> void:
	_block("cleanup")
	var resolved := ProjectSettings.globalize_path(SAVE_FILE)
	var test_dir := ProjectSettings.globalize_path("user://tests")
	var contained := resolved.begins_with(test_dir) \
			and resolved.ends_with("gate_d_join_save.json") \
			and FileAccess.file_exists(SAVE_FILE)
	_check("the test save resolved inside the dedicated test directory",
			contained)
	if contained:
		DirAccess.remove_absolute(resolved)
	# Disarm BEFORE re-aiming at the player's real save. quit() only requests
	# an exit at end of frame, so any commit() from a still-live node between
	# these two lines would overwrite a real save with test campaign state.
	RealityState.persistence_enabled = false
	RealityState.save_path = RealityState.SAVE_PATH
	_check("the test save file is removed and the player save untouched",
			not FileAccess.file_exists(SAVE_FILE)
			and FileAccess.file_exists(RealityState.SAVE_PATH)
					== _player_save_present)


# --- helpers, ported from golden_loop_test.gd -------------------------

## Only ever called before the dream. reset_campaign_for_tests blanks
## data.dream, and CampaignShell reconciles a saved phase exactly once inside
## its own _ready — so a checkpoint taken while a dream world is live would
## desynchronise the shell from the record with no way back.
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
	trace.append(label)


## Teleports replace GoldenLoopTest's walked legs. A body dropped onto
## geometry is not standing on it yet, and an interact() aimed from a falling
## body silently tests nothing, so every teleport settles and proves contact.
func _settle_at(at: Vector3) -> bool:
	player.global_position = at
	player.velocity = Vector3.ZERO
	for i in range(16):
		await get_tree().physics_frame
		if player.is_on_floor():
			return true
	return player.is_on_floor()


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


func _block(name: String) -> void:
	_blocks.append(name)
	print("[GATE D BLOCK] ", name)


func _check(label: String, ok: bool) -> void:
	_checks += 1
	if ok:
		print("  [gate d ok] ", label)
	else:
		_fails += 1
		printerr("  [GATE D FAIL] ", label)
