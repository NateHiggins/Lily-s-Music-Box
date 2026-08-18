extends Node
## N6: Mina's release-print pursuit in the real DreamMazeRoot.
##
## Four proofs, in the production scene: the borrowed silhouette never enters
## the beauty pass; opaque module collision blocks acquisition; lamp state
## changes pursuit through the existing public owner; capture reaches
## DreamDirector's existing outcome seam without inventing a failure state.
## N2's graph, N3's light binary, N4's transaction and N5's onset ownership
## are consumed, not modified.
##
## Harness integrity: the exact check count is asserted, every block ends on
## a counted sentinel, and the process exits nonzero on any failure.

const SAVE_FILE := "user://tests/n6_dream_pursuit_save.json"
const JOB := ChirpHunt.JOB_ID
const ITEM := "carbon_transmitter_capsule"
const CASE := "mina_caption_crisis"
const PROFILE := "mina_release_print"
const RESIDUE := DreamBoundaryWakingStub.RESIDUE_ID
const FIXED_SEED_HEX := "f123456789abcdef"
const ALT_SEED_HEX := "f123456789abcdee"
const CHAIN := ["D00_4B_THRESHOLD", "D01_F04_LONG_HALL", "D03_LIFT_VOID",
		"D04_BATHROOM_PROCESSION", "D05_SERVICE_RISER"]
const EDGES := ["E00", "E01_LIFT", "E03", "E04"]
const EXPECTED_CHECKS := 39
const DT := 1.0 / 120.0
const RUN_CAP_S := 30.0

var failures := 0
var checks := 0
var residue_signals := 0
var ended_outcomes: Array[String] = []
var shell: CampaignShell
var root: DreamMazeRoot
var _player_save_present := false
var _finished := false
var _route_violations := 0


func _ready() -> void:
	print("[N6] START")
	_watchdog()
	await _block_a_assembly()
	await _block_b_world()
	await _block_c_silhouette()
	await _block_d_occlusion()
	await _block_e_light_binary()
	await _block_f_outcome_seam()
	if checks != EXPECTED_CHECKS:
		failures += 1
		printerr("[N6] HARNESS FAIL: %d checks ran, %d expected"
				% [checks, EXPECTED_CHECKS])
	_finished = true
	print("DREAM PURSUIT TEST: %s (%d checks)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures, checks])
	get_tree().quit(failures)


func _watchdog() -> void:
	await get_tree().create_timer(50.0, true, false, true).timeout
	if not _finished:
		printerr("[N6] WATCHDOG: run exceeded 50 seconds — FAIL")
		get_tree().quit(1)


# --- Block A: deterministic assembly of N2's graph -------------------------

func _block_a_assembly() -> void:
	var catalog := DreamMazeBuilder.load_catalog()
	var plan := DreamMazeBuilder.assemble(catalog, FIXED_SEED_HEX, 1)
	var plan_again := DreamMazeBuilder.assemble(catalog, FIXED_SEED_HEX, 1)
	var plan_alt := DreamMazeBuilder.assemble(catalog, ALT_SEED_HEX, 1)
	var ids: Array[String] = []
	for entry in plan.modules:
		ids.append(str(entry.id))
	_check("slot-1 assembly is exactly Mina's ruled exposure chain",
			(plan.defects as Array).is_empty() and ids == CHAIN)
	_check("the assembly consumes exactly the slot-1 catalog edges",
			plan.edges == EDGES)
	_check("one seed rebuilds one byte-identical plan",
			JSON.stringify(plan) == JSON.stringify(plan_again))
	_check("the seed's one freedom is handedness, and both hands assemble",
			bool(plan.mirrored) != bool(plan_alt.mirrored)
			and (plan_alt.defects as Array).is_empty())
	_check("no two clear footprints overlap in either hand",
			_overlap_free(plan) and _overlap_free(plan_alt))
	var doors_ok := (plan.doors as Array).size() == 4
	for door in plan.doors:
		var a: Array = door.aperture
		var width: float = (a[2] - a[0]) if door.axis == "x" else (a[3] - a[1])
		doors_ok = doors_ok and absf(width - 0.91) < 0.0001 \
				and absf(float(door.height) - 2.13) < 0.0001
	_check("every chain door keeps the authored 0.91 x 2.13 m opening",
			doors_ok)
	_check("every door aperture spans its pair's real shared wall gap",
			_doors_span_gaps(plan))
	_check("nothing beyond unlock slot 1 leaks into the assembly",
			_slot_gated(catalog, ids, plan.edges, 1))
	_end_block("A", 8)


# --- Block B: the production dream world builds ----------------------------

func _block_b_world() -> void:
	root = await _spawn_root(FIXED_SEED_HEX)
	var first_stringify := JSON.stringify(root.plan)
	var first_parameters := JSON.stringify(root.pursuer.run_parameters())
	# The literal D00 is retired (owner ruling 2026-08-18): the passage begins
	# wherever the case's seed put it. What this always meant is that the
	# marker and the plan agree about where the body starts -- disagreement
	# there puts the player somewhere the world was not built for.
	_check("the production scene assembles the maze at its own waking room",
			root.maze_built and not root.start_module_id().is_empty()
			and root.start_marker.position.distance_to(Vector3(
					root.plan.spawn_player[0], 0.0,
					root.plan.spawn_player[1])) < 0.001)
	_check("the dream body is the real controller with the lamp lit",
			root.player is PlayerController and root.player.lamp_is_enabled()
			and _inside_module(root.plan, root.start_module_id(),
					root.player.position))
	var parameters: Dictionary = root.pursuer.run_parameters()
	# "DEEP IN THE TERMINAL MODULE" IS RETIRED, and by construction rather than
	# by concession. Owner ruling 2026-08-18: "the building is a fractal so
	# they are always deep in it." There is no terminal room to be deep in and
	# no shallow end to be at -- every room is arbitrarily far inside an
	# infinite building, so naming a module was only ever a proxy for the two
	# things that actually matter, and both are asserted directly here: the
	# Tenant starts inside real architecture rather than nowhere, and it starts
	# far enough away that the lit/dark speed difference still decides the
	# passage rather than the spawn doing it.
	_check("the pursuer spawns inside the building, far off, with N3's numbers",
			_pursuer_start_is_sound()
			and absf(float(parameters.lit_speed_mps) - 6.35) <= 0.12001
			and absf(float(parameters.dark_speed_mps) - 3.35) <= 0.08001
			and absf(float(parameters.hearing_period_s) - 0.72) <= 0.08001
			and absf(float(parameters.capture_radius_m) - 0.75) < 0.0001)
	var architecture := root.get_node_or_null("ModuleArchitecture")
	# Counted by DESCENDANT, not by immediate child. The chain hung every wall,
	# floor and lintel directly off this node; the pocket hangs a node per room
	# and the bodies inside those. Immediate children therefore counted the
	# building on one path and counted the ROOMS on the other, which is five --
	# and the check reported that no architecture existed. It was always asking
	# how much opaque collision there is, so it now counts that.
	var solids := 0
	if architecture != null:
		solids = _count_bodies(architecture)
	_check("real opaque architecture exists, floor to lintel (%d bodies)"
			% solids, architecture != null and solids > 20)
	for i in range(30):
		await get_tree().physics_frame
	_check("the dream body stands on the module floor",
			root.player.is_on_floor())
	var rebuilt := await _spawn_root(FIXED_SEED_HEX)
	_check("a rebuild is the same maze and the same seeded pursuit",
			JSON.stringify(rebuilt.plan) == first_stringify
			and JSON.stringify(rebuilt.pursuer.run_parameters())
					== first_parameters)
	root.queue_free()
	await get_tree().process_frame
	root = rebuilt
	_end_block("B", 14)


# --- Block C: the silhouette never enters beauty ---------------------------

func _block_c_silhouette() -> void:
	await get_tree().process_frame
	var geometry: Array[GeometryInstance3D] = []
	var lights := 0
	var playing := 0
	_collect(root.pursuer, geometry)
	for node in _descendants(root.pursuer):
		if node is Light3D:
			lights += 1
		if node is AnimationPlayer and (node as AnimationPlayer).is_playing():
			playing += 1
	_check("the pursuer wears Mina's own borrowed silhouette",
			root.pursuer.silhouette_source == "mina_vale"
			and geometry.size() >= 1)
	var all_shadows_only := true
	for instance in geometry:
		all_shadows_only = all_shadows_only and instance.cast_shadow \
				== GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_check("every borrowed surface is shadows-only, outside the beauty pass",
			all_shadows_only)
	_check("the body carries no light and no playing animation",
			lights == 0 and playing == 0)
	var outside_silhouette := 0
	for instance in geometry:
		if instance.name == "BorrowedSilhouette":
			continue
		var ancestor := instance.get_parent()
		var inside := false
		while ancestor != null and ancestor != root.pursuer:
			if ancestor.name == "BorrowedSilhouette":
				inside = true
				break
			ancestor = ancestor.get_parent()
		if not inside:
			outside_silhouette += 1
	_check("every rendered surface belongs to the borrowed silhouette alone",
			outside_silhouette == 0)
	_end_block("C", 18)


# --- Block D: opaque module collision blocks acquisition -------------------

func _block_d_occlusion() -> void:
	root.autonomous = false
	# From here the body is scripted: measurement owns every transform.
	root.player.set_physics_process(false)
	# ANY SHARED WALL WILL DO. This used to name D01 and D03 and take the door
	# between them, which does not exist in a building whose rooms are named by
	# path -- _door_between returned an empty dictionary and the block ERRORED
	# on the next line rather than failing, taking its remaining checks with it
	# and tripping the block sentinel. What is under test is that opaque
	# collision blocks acquisition, and one real wall proves that as well as a
	# named one. The axis matters and is asserted rather than assumed: the
	# geometry below offsets both bodies along x and separates them along z, so
	# it needs a join cut along x.
	var door := _joined_pair(root.plan)
	if door.is_empty():
		# Not a _check: block D pins its own count at 23 and an extra
		# assertion here would trip the sentinel on every healthy run. Both
		# builders always produce an x-cut join, so this is a shout, not a
		# branch the suite is expected to take.
		printerr("  [N6] no x-cut join in the plan; block D cannot run")
		failures += 1
		return
	var d01 := _rect(root.plan, str(door.from))
	var d03 := _rect(root.plan, str(door.to))
	var aperture: Array = door.aperture
	var door_x: float = (aperture[0] + aperture[2]) * 0.5
	var toward_d03: float = signf((d03[1] + d03[3]) * 0.5
			- (d01[1] + d01[3]) * 0.5)
	# Blocked: both bodies laterally offset from the opening, so the line
	# crosses the solid shared wall, not the aperture.
	root.pursuer.reset_run(Vector3(door_x - 1.6, 0.0,
			(d01[1] + d01[3]) * 0.5))
	root.player.position = Vector3(door_x - 1.6,
			0.0, clampf((d03[1] + d03[3]) * 0.5, d03[1] + 0.4, d03[3] - 0.4))
	root.player.set_lamp_enabled(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("a lit target behind real module wall is not acquired",
			not root.pursuer.scan_light_once())
	# Clear: both bodies on the door axis; the only path is the aperture.
	root.pursuer.reset_run(Vector3(door_x, 0.0,
			clampf((d01[1] + d01[3]) * 0.5, d01[1] + 0.4, d01[3] - 0.4)))
	root.player.position = Vector3(door_x, 0.0,
			(aperture[1] + aperture[3]) * 0.5 + toward_d03 * 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("the same lamp through the open connector acquires",
			root.pursuer.scan_light_once())
	root.pursuer.reset_run(root.pursuer.position)
	root.player.toggle_lamp()
	_check("the public owner turns acquisition off",
			not root.player.lamp_is_enabled()
			and not root.pursuer.scan_light_once())
	root.player.toggle_lamp()
	_check("the same public owner turns it back on",
			root.player.lamp_is_enabled() and root.pursuer.scan_light_once())
	_check("the owner is the real service lamp, not a shadow flag",
			root.player.flashlight.visible == root.player.lamp_is_enabled())
	_end_block("D", 23)


# --- Block E: lamp state changes pursuit, deterministically ----------------

func _block_e_light_binary() -> void:
	var parameters := JSON.stringify(root.pursuer.run_parameters())
	var capture_on := _measured_run(true, -1.0)
	var capture_off := _measured_run(false, -1.0)
	var capture_ext := _measured_run(true, 0.15)
	print("  [N6 measured] lamp-on %.3f s, lamp-off %.3f s, "
			% [capture_on, capture_off]
			+ "extinguished %.3f s, route violations %d"
			% [capture_ext, _route_violations])
	_check("the lit maze run captures", capture_on > 0.0)
	_check("the dark maze run still always captures", capture_off > 0.0)
	_check("light-on shortens capture by at least one third in the real maze",
			capture_on <= capture_off * 0.667)
	_check("extinguishing after acquisition buys real audible time",
			capture_ext > 0.0 and capture_ext - capture_on >= 3.0)
	_check("paired runs reuse one seeded parameter set, unrerolled",
			JSON.stringify(root.pursuer.run_parameters()) == parameters)
	_check("the body never leaves the validated graph space",
			_route_violations == 0)
	_end_block("E", 29)


# --- Block F: capture reaches the existing outcome seam --------------------

func _block_f_outcome_seam() -> void:
	root.queue_free()
	root = null
	await get_tree().process_frame
	_player_save_present = FileAccess.file_exists(RealityState.SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("user://tests"))
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))
	RealityState.save_path = SAVE_FILE
	RealityState.persistence_enabled = true
	RealityState.reset_campaign_for_tests()
	_seed_completed_shift()
	RealityState.waking_residue_applied.connect(
			func(_id: String, _facts: Dictionary) -> void:
				residue_signals += 1)
	await _spawn_shell()
	_check("the completed shift arms in the waking world",
			shell.dream_director.phase() == "armed"
			and shell.world_kind() == "waking")
	shell.dream_director.enter_armed_dream()
	await get_tree().process_frame
	await get_tree().process_frame
	var live := shell.active_world as DreamMazeRoot
	_check("entry builds the production maze as the sole world",
			shell.world_kind() == "dream" and shell.world_child_count() == 1
			and shell.dream_director.phase() == "active"
			and live != null and live.maze_built and live.pursuer != null)
	_check("a mid-pursuit save restores at D00, never a chase frame",
			await _reload_restores_at_d00())
	live = shell.active_world as DreamMazeRoot
	# The pursuit itself must reach the seam: hand it a target it will
	# catch within a bounded real-time window.
	live.pursuer.reset_run(live.player.position + Vector3(2.0, 0.0, 0.0))
	var reached := false
	for i in range(600):
		await get_tree().physics_frame
		if shell.dream_director.phase() == "return_pending" \
				or shell.dream_director.phase() == "awake":
			reached = true
			break
	if not reached:
		print("  [N6 debug] phase=%s captured=%s pursuer=%s player=%s t=%.2f"
				% [shell.dream_director.phase(),
				live.pursuer.is_captured, live.pursuer.position,
				live.player.position, live.pursuer.elapsed_s])
	_check("capture commits the existing outcome, not an invented state",
			reached and str(RealityState.data.dream.outcome) == "capture")
	for i in range(20):
		await get_tree().physics_frame
		if shell.dream_director.phase() == "awake":
			break
	_check("the shell returns to one waking world and completes the return",
			shell.world_kind() == "waking" and shell.world_child_count() == 1
			and shell.dream_director.phase() == "awake"
			and ended_outcomes == ["capture"])
	_check("wake crosses the existing boundary with one stable residue",
			shell.core_loop.boundary() == "wake_complete"
			and residue_signals == 1
			and RealityState.has_waking_residue(RESIDUE))
	_check("the outcome vocabulary is unchanged",
			DreamDirector.OUTCOMES == ["capture", "fall", "contact"])
	_check("no committed waking fact was disturbed by the pursuit",
			_facts_intact())
	RealityState.save_game()
	_destroy_shell()
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	await _spawn_shell()
	_check("an awake reload resurrects no dream and no second residue",
			shell.dream_director.phase() == "awake"
			and shell.world_kind() == "waking"
			and residue_signals == 1 and _facts_intact())
	_destroy_shell()
	var resolved := ProjectSettings.globalize_path(SAVE_FILE)
	if resolved.ends_with("n6_dream_pursuit_save.json"):
		DirAccess.remove_absolute(resolved)
	RealityState.save_path = RealityState.SAVE_PATH
	_check("the contained test save is removed and the player save untouched",
			not FileAccess.file_exists(SAVE_FILE)
			and FileAccess.file_exists(RealityState.SAVE_PATH)
					== _player_save_present)
	_end_block("F", 39)


# --- Measured runs ---------------------------------------------------------

## One deterministic paired run: the dream body runs the chain at the
## catalog's 4.60 m/s through door waypoints while the pursuit is stepped at
## a fixed 120 Hz. extinguish_after >= 0 turns the lamp off through the
## public owner that long after first acquisition.
func _measured_run(lamp_on: bool, extinguish_after: float) -> float:
	var plan: Dictionary = root.plan
	var d01 := _rect(plan, CHAIN[1])
	root.player.set_lamp_enabled(lamp_on)
	root.player.position = Vector3(d01[0] + 8.0, 0.0, (d01[1] + d01[3]) * 0.5)
	root.pursuer.reset_run(Vector3(d01[0] + 0.3, 0.0,
			(d01[1] + d01[3]) * 0.5))
	var goal := Vector3(plan.spawn_pursuer[0], 0.0, plan.spawn_pursuer[1])
	var extinguished := extinguish_after < 0.0
	var elapsed := 0.0
	while elapsed < RUN_CAP_S and not root.pursuer.is_captured:
		elapsed += DT
		_advance_player_toward(goal, 4.6 * DT)
		root.pursuer.advance_fixed(DT)
		if not extinguished and root.pursuer.acquired \
				and root.pursuer.elapsed_s \
						>= root.pursuer.acquisition_time_s + extinguish_after:
			root.player.toggle_lamp()
			extinguished = true
		_audit_route_position()
	return root.pursuer.capture_time_s


func _advance_player_toward(goal: Vector3, budget: float) -> void:
	var plan: Dictionary = root.plan
	var here: Vector3 = root.player.position
	var my_module := DreamMazeBuilder.nav_module_at(plan, here.x, here.z)
	var goal_module := DreamMazeBuilder.nav_module_at(plan, goal.x, goal.z)
	var waypoints: Array = []
	if my_module != "" and goal_module != "" and my_module != goal_module:
		waypoints = DreamMazeBuilder.chain_route(plan, my_module, goal_module)
	waypoints.append(goal)
	while waypoints.size() >= 2:
		var w0: Vector3 = waypoints[0]
		var w1: Vector3 = waypoints[1]
		if Vector3(here.x, 0.0, here.z).distance_to(
				Vector3(w1.x, 0.0, w1.z)) \
				<= Vector3(w0.x, 0.0, w0.z).distance_to(
				Vector3(w1.x, 0.0, w1.z)) + 0.01:
			waypoints.pop_front()
		else:
			break
	for waypoint in waypoints:
		if budget <= 0.0:
			break
		var leg: Vector3 = Vector3(waypoint.x, 0.0, waypoint.z) \
				- Vector3(here.x, 0.0, here.z)
		var length := leg.length()
		if length <= 0.05:
			continue
		var step := minf(budget, length)
		root.player.position += leg.normalized() * step
		here = root.player.position
		budget -= step


func _audit_route_position() -> void:
	var at: Vector3 = root.pursuer.position
	if DreamMazeBuilder.module_at(root.plan, at.x, at.z) != "":
		return
	for door in root.plan.doors:
		var a: Array = door.aperture
		if at.x >= a[0] - 0.05 and at.x <= a[2] + 0.05 \
				and at.z >= a[1] - 0.05 and at.z <= a[3] + 0.05:
			return
	_route_violations += 1


# --- Shared helpers --------------------------------------------------------

func _spawn_root(seed_hex: String) -> DreamMazeRoot:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	var next := scene.instantiate() as DreamMazeRoot
	next.autonomous = false
	next.configure_dream({
		"case_id": CASE, "profile_id": PROFILE, "window": {},
		"seed_hex": seed_hex, "maze_revision": 1, "outcome": "",
	})
	add_child(next)
	await get_tree().process_frame
	return next


func _spawn_shell() -> void:
	shell = CampaignShell.new()
	shell.name = "CampaignShellUnderTest"
	shell.waking_scene_path = "res://tests/DreamBoundaryWakingStub.tscn"
	shell.dream_scene_path = "res://scenes/dream/DreamMazeRoot.tscn"
	shell.sleep_manual_clock = true
	add_child(shell)
	# Every respawned shell owns a fresh director; the outcome listener must
	# follow it or the seam proof watches a freed object.
	shell.dream_director.dream_ended.connect(
			func(_case: String, outcome: String) -> void:
				ended_outcomes.append(outcome))
	await get_tree().process_frame
	await get_tree().process_frame


func _destroy_shell() -> void:
	if shell != null and is_instance_valid(shell):
		remove_child(shell)
		shell.free()
	shell = null


func _reload_restores_at_d00() -> bool:
	# ESTABLISH THE PREMISE FIRST. Saving two frames after entry and then
	# observing a body near spawn proves nothing -- it never left. Run real
	# physics until the Tenant is demonstrably mid-pursuit, and assert that,
	# so the reload has an actual chase frame to refuse to restore.
	var live := shell.active_world as DreamMazeRoot
	var spawn := Vector3(live.plan.spawn_pursuer[0], 0.0,
			live.plan.spawn_pursuer[1])
	for i in range(220):
		await get_tree().physics_frame
		if live.pursuer.elapsed_s > 2.0 				and live.pursuer.position.distance_to(spawn) > 2.0:
			break
	if live.pursuer.elapsed_s <= 2.0 			or live.pursuer.position.distance_to(spawn) <= 2.0:
		print("    [N6] premise not met: clock %.2f, drift %.2f"
				% [live.pursuer.elapsed_s,
				live.pursuer.position.distance_to(spawn)])
		return false

	print("    [N6] premise ok: clock=%.2f drift=%.2f"
			% [live.pursuer.elapsed_s,
			live.pursuer.position.distance_to(spawn)])
	if not RealityState.save_game():
		print("    [N6] save_game refused")
		return false
	_destroy_shell()
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	await _spawn_shell()
	live = shell.active_world as DreamMazeRoot
	if shell.world_kind() != "dream" 			or shell.dream_director.phase() != "active" 			or live == null or not live.maze_built 			or live.player.position.distance_to(
					live.start_marker.position) >= 0.35:
		print("    [N6] restore gate: kind=%s phase=%s built=%s body=%.2f"
				% [shell.world_kind(), shell.dream_director.phase(),
				live != null and live.maze_built,
				999.0 if live == null else live.player.position.distance_to(
						live.start_marker.position)])
		return false
	# THE ACTUAL INVARIANT: the restored world reconstructed the pursuit from
	# the plan rather than resuming a serialized chase. A fresh run has a
	# near-zero clock, has acquired nobody, and stands at the plan's spawn.
	#
	# An earlier version bounded the drift by `elapsed_s * top_speed`, which
	# is precisely the pursuer's own displacement bound -- so it could not
	# fail, and a coherently serialized chase frame would have passed it
	# silently. The clock is the falsifiable part and it carries the check.
	var fresh_spawn := Vector3(live.plan.spawn_pursuer[0], 0.0,
			live.plan.spawn_pursuer[1])
	print("    [N6] restored clock=%.3f acquired=%s captured=%s drift=%.3f"
			% [live.pursuer.elapsed_s, live.pursuer.acquired,
			live.pursuer.is_captured,
			fresh_spawn.distance_to(live.pursuer.position)])
	# The CLOCK is what makes this falsifiable, and it carries the check: the
	# chase frame measured above ran 2.02 s, so a restore that resumed one
	# would read seconds here rather than a sixth of one.
	#
	# The drift bound is then a plain constant, deliberately not derived from
	# elapsed_s -- deriving it was the previous mistake, because
	# `elapsed_s * top_speed` IS the pursuer's own displacement bound and can
	# never be exceeded. 1.60 m is the most a body can cover in the 0.20 s the
	# clock permits at the 6.27 m/s lit speed, plus slack; the real chase frame
	# above sat 6.74 m out and would fail this on its own.
	return live.pursuer.elapsed_s < 0.20 \
			and not live.pursuer.acquired \
			and not live.pursuer.is_captured \
			and live.pursuer.capture_time_s < 0.0 \
			and fresh_spawn.distance_to(live.pursuer.position) < 1.60


func _seed_completed_shift() -> void:
	RealityState.data.dream_seed = FIXED_SEED_HEX
	RealityState.data.maintenance_jobs[JOB] = {
		"stage": "closed", "origin": "reported",
		"evidence": ["chirping_point_located", "no_battery_bay",
				"carbon_capsule_failed"],
		"repair_result": {"quality": "good", "note": "test"},
		"issued_at": 1,
	}
	RealityState.data.maintenance_items[ITEM] = {
		"shop_id": "hardware_paint", "consumed": true,
		"acquired_at": 2, "consumed_at": 3,
	}
	RealityState.data.cases[CASE] = {
		"resident_id": "mina_vale", "stage": "resolved",
		"repair_count": 2, "recurrence_count": 1,
		"manifestation_intensity": 0.0, "trust": 3,
		"conversation_flags": ["assumptions_are_not_facts",
				"silence_can_be_blank"],
		"apartment_changes": [], "recurrence_pending": false,
		"resolved": true,
	}
	RealityState.data.core_loop = {
		"active_job_id": JOB, "boundary": "dream_pending",
		"conversation_requested": true, "conversation_complete": true,
		"dream_pending": true, "safe_return_anchor": "F04_B_BED",
	}
	RealityState.data.dream = {}
	RealityState.commit()


func _facts_intact() -> bool:
	var job: Dictionary = RealityState.data.maintenance_jobs.get(JOB, {})
	var item: Dictionary = RealityState.data.maintenance_items.get(ITEM, {})
	var case: Dictionary = RealityState.data.cases.get(CASE, {})
	return str(job.get("stage")) == "closed" \
			and bool(item.get("consumed", false)) \
			and bool(case.get("resolved", false))


func _overlap_free(plan: Dictionary) -> bool:
	var rects: Array = []
	for entry in plan.modules:
		rects.append(entry.rect)
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			var a: Array = rects[i]
			var b: Array = rects[j]
			if a[0] < b[2] - 0.0005 and b[0] < a[2] - 0.0005 \
					and a[1] < b[3] - 0.0005 and b[1] < a[3] - 0.0005:
				return false
	return true


func _doors_span_gaps(plan: Dictionary) -> bool:
	for door in plan.doors:
		var a := _rect(plan, str(door.from))
		var b := _rect(plan, str(door.to))
		var aperture: Array = door.aperture
		if door.axis == "z":
			var gap_lo := minf(a[2], b[2])
			var gap_hi := maxf(a[0], b[0])
			if absf(aperture[0] - gap_lo) > 0.0001 \
					or absf(aperture[2] - gap_hi) > 0.0001 \
					or absf(gap_hi - gap_lo - 0.2) > 0.0001:
				return false
		else:
			var gap_lo2 := minf(a[3], b[3])
			var gap_hi2 := maxf(a[1], b[1])
			if absf(aperture[1] - gap_lo2) > 0.0001 \
					or absf(aperture[3] - gap_hi2) > 0.0001 \
					or absf(gap_hi2 - gap_lo2 - 0.2) > 0.0001:
				return false
	return true


func _slot_gated(catalog: Dictionary, ids: Array[String], edges: Array,
		slot: int) -> bool:
	for id in ids:
		if int(catalog.modules[id].get("unlock_slot", 99)) > slot:
			return false
	for edge_id in edges:
		for edge in catalog.topology:
			if str(edge.id) == str(edge_id) \
					and int(edge.get("unlock_slot", 99)) > slot:
				return false
	return true


func _rect(plan: Dictionary, id: String) -> Array:
	for entry in plan.modules:
		if str(entry.id) == id:
			return entry.rect
	return [0.0, 0.0, 0.0, 0.0]


func _door_between(plan: Dictionary, a: String, b: String) -> Dictionary:
	for door in plan.doors:
		if str(door.from) == a and str(door.to) == b:
			return door
	return {}


func _inside_module(plan: Dictionary, id: String, at: Vector3) -> bool:
	return DreamMazeBuilder.module_at(plan, at.x, at.z) == id


## What "spawns deep" was ever really guaranteeing, now that there is no
## terminal room to name. Two things, and neither mentions a module id:
##
##   1. The Tenant starts INSIDE real architecture. A body outside every room
##      resolves to no room, and DreamPursuer treats an empty route as licence
##      to walk a straight line to the player, through whatever is in the way.
##   2. It starts far enough off that the passage is decided by the lamp and
##      the chase, not by the spawn. Well outside the 0.75 m capture radius,
##      and not in the player's own room.
func _pursuer_start_is_sound() -> bool:
	var at := root.pursuer.position
	var mine := DreamMazeBuilder.nav_module_at(root.plan,
			root.player.position.x, root.player.position.z)
	var theirs := DreamMazeBuilder.nav_module_at(root.plan, at.x, at.z)
	if theirs.is_empty():
		return false
	return theirs != mine \
			and at.distance_to(root.player.position) > 0.75 * 4.0


## The first door in the plan cut along x -- a join between two rooms stacked
## along z -- with both of its rooms present. Path-agnostic: on the chain it
## finds the same kind of joint the old CHAIN[1]/CHAIN[2] pair named.
func _joined_pair(plan: Dictionary) -> Dictionary:
	for door in plan.get("doors", []):
		if str(door.get("axis", "")) != "x":
			continue
		# _rect answers a miss with a zero rect rather than an empty array,
		# so presence is measured by area.
		var a := _rect(plan, str(door.from))
		var b := _rect(plan, str(door.to))
		if float(a[2]) - float(a[0]) <= 0.0 or float(b[2]) - float(b[0]) <= 0.0:
			continue
		return door
	return {}


## Every opaque body under a node, however deep. The two builders nest
## differently and neither nesting is wrong.
func _count_bodies(node: Node) -> int:
	var n := 1 if node is StaticBody3D else 0
	for child in node.get_children():
		n += _count_bodies(child)
	return n


func _collect(node: Node, into: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		into.append(node)
	for child in node.get_children():
		_collect(child, into)


func _descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out


func _end_block(label: String, expected_total: int) -> void:
	if checks != expected_total:
		failures += 1
		printerr("[N6] BLOCK %s SENTINEL FAIL: %d checks, %d expected"
				% [label, checks, expected_total])
	else:
		print("[N6] block %s complete (%d/%d)" % [label, checks,
				EXPECTED_CHECKS])


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [dream pursuit ok] ", label)
	else:
		failures += 1
		printerr("  [DREAM PURSUIT FAIL] ", label)
