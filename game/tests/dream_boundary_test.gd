extends Node
## N4: real-file proof of the persistent CampaignShell/DreamDirector boundary.
## Every checkpoint destroys the shell and RealityState, reloads the JSON and
## reconstructs forward. No production save path is touched.

const SAVE_FILE := "user://tests/n4_dream_boundary_save.json"
const JOB := ChirpHunt.JOB_ID
const ITEM := "carbon_transmitter_capsule"
const CASE := "mina_caption_crisis"
const PROFILE := "mina_release_print"
const RESIDUE := DreamBoundaryWakingStub.RESIDUE_ID
## Deliberately exceeds JSON's exact integer range and sets the sign bit. The
## hex save contract must preserve all 64 bits byte-for-byte.
const FIXED_SEED_HEX := "f123456789abcdef"

var failures := 0
var checks := 0
var residue_signals := 0
var shell: CampaignShell
var _player_save_present := false
var _finished := false


func _ready() -> void:
	print("[N4] START")
	_watchdog()
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

	await _spawn_test_shell()
	_check("the restored K6 request arms once in the waking world",
			shell.dream_director.phase() == "armed"
			and _exclusive("waking") and _facts_intact(false))
	_check("the request carries the ruled release-print identity",
			str(shell.dream_director.dream_state().case_id) == CASE
			and str(shell.dream_director.dream_state().profile_id) == PROFILE
			and str(shell.dream_director.dream_state().seed_hex)
					== FIXED_SEED_HEX
			and int(shell.dream_director.dream_state().maze_revision) == 1)
	await _reload("armed", "armed")
	_check("armed restore neither enters nor duplicates state",
			shell.dream_director.phase() == "armed"
			and _exclusive("waking") and _facts_intact(false))

	_check("entry commits before the waking world is replaced",
			shell.dream_director.enter_armed_dream()
			and shell.dream_director.phase() == "entered"
			and shell.world_kind() == "waking")
	# OWNER RULING 2026-08-18: the place the player wakes in the fractal holds
	# still until a case is solved, and then moves. The anchor is therefore
	# the resolved-case count, stamped onto the passage at entry -- not read
	# live, or a case resolving mid-dream would move the floor under them.
	var anchor := int(shell.dream_director.context().spawn_anchor)
	_check("entry stamps the waking place from the resolved-case count "
			+ "(anchor %d, %d resolved)" % [anchor,
			RealityState.cases_resolved()],
			anchor == RealityState.cases_resolved() and anchor >= 1)
	# Two clocks, not one. They agree only while every dream resolves a case,
	# and collapsing them on that coincidence is the bug this check exists to
	# catch: a retried passage must wake in the same room and yet find the
	# building a night more forgotten.
	_check("the waking place and the decay clock are separate facts",
			shell.dream_director.context().has("night_index")
			and shell.dream_director.context().has("spawn_anchor"))
	await _reload("entered", "active")
	_check("the waking place survives a reload unchanged",
			int(shell.dream_director.context().spawn_anchor) == anchor)
	_check("entered restore reconstructs the dream as the only world",
			_exclusive("dream") and _dream_restarts_identically()
			and _facts_intact(false))
	var first_dream_id := shell.active_world.get_instance_id()
	await _reload("active", "active")
	_check("active restore rebuilds the same identity in the same room, not a chase frame",
			_exclusive("dream") and _dream_restarts_identically()
			and shell.active_world.get_instance_id() != first_dream_id
			and str(shell.dream_director.dream_state().seed_hex)
					== FIXED_SEED_HEX)

	_check("capture commits return-pending while dream remains sole world",
			shell.dream_director.end_dream("capture")
			and shell.dream_director.phase() == "return_pending"
			and shell.world_kind() == "dream"
			and str(shell.dream_director.dream_state().outcome) == "capture")
	await _reload("return_pending", "awake")
	_check("return-pending restore reconciles forward through the waking world",
			_exclusive("waking")
			and shell.core_loop.boundary() == "wake_complete"
			and _facts_intact(true))
	_check("wake applies exactly one stable residue",
			residue_signals == 1
			and RealityState.data.waking_residues.size() == 1
			and RealityState.has_waking_residue(RESIDUE))
	await _reload("awake", "awake")
	_check("awake restore resurrects no dream, work or consumed item",
			_exclusive("waking") and _facts_intact(true)
			and residue_signals == 1)

	await _production_shell_smoke()
	_cleanup()
	_finished = true
	print("DREAM BOUNDARY TEST: %s (%d checks)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures, checks])
	get_tree().quit(failures)


func _watchdog() -> void:
	await get_tree().create_timer(50.0, true, false, true).timeout
	if not _finished:
		printerr("[N4] WATCHDOG: run exceeded 50 seconds — FAIL")
		get_tree().quit(1)


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


func _spawn_test_shell() -> void:
	shell = CampaignShell.new()
	shell.name = "CampaignShellUnderTest"
	shell.waking_scene_path = "res://tests/DreamBoundaryWakingStub.tscn"
	shell.dream_scene_path = "res://scenes/dream/DreamMazeRoot.tscn"
	# N4 proves the boundary transaction, not N5's onset clock.
	shell.sleep_manual_clock = true
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame


func _destroy_shell() -> void:
	if shell != null and is_instance_valid(shell):
		remove_child(shell)
		shell.free()
	shell = null


func _reload(saved_phase: String, expected_after_spawn: String) -> void:
	_check("%s checkpoint writes the real file" % saved_phase,
			RealityState.save_game()
			and _saved_phase() == saved_phase)
	_destroy_shell()
	RealityState.reset_campaign_for_tests()
	_check("%s checkpoint destroys live campaign facts" % saved_phase,
			RealityState.data.maintenance_jobs.is_empty()
			and RealityState.data.dream.is_empty())
	RealityState.load_game()
	_check("%s checkpoint restores its exact committed phase" % saved_phase,
			str(RealityState.data.dream.get("phase")) == saved_phase
			and _facts_intact(saved_phase == "awake"))
	await _spawn_test_shell()
	_check("%s checkpoint reconciles to %s" % [saved_phase,
			expected_after_spawn],
			shell.dream_director.phase() == expected_after_spawn)


func _saved_phase() -> String:
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(SAVE_FILE))
	if parsed is not Dictionary:
		return ""
	return str((parsed as Dictionary).get("dream", {}).get("phase", ""))


func _exclusive(expected: String) -> bool:
	var waking := get_tree().get_nodes_in_group("waking_world").size()
	var dream := get_tree().get_nodes_in_group("dream_world").size()
	return shell.world_child_count() == 1 and shell.world_kind() == expected \
			and waking == (1 if expected == "waking" else 0) \
			and dream == (1 if expected == "dream" else 0)


## The room a restored dream restarts in must be THE SAME ROOM, every time,
## and never a live chase frame.
##
## This used to read `start_module_id() == "D00_4B_THRESHOLD"`. Owner ruling
## 2026-08-18 retired that: "each new game start at a random seed location in
## the maze until a case is solved and a new start position is chosen." There
## is no entrance to name any more.
##
## What the boundary contract actually needed was never the literal D00 -- it
## was RECONSTRUCTION: reload the same committed transaction and you must get
## the same world back. So the first answer is remembered and every later one
## is held to it, which is a strictly stronger check than comparing against a
## constant, and it is the same check on both worlds.
var _restart_room := ""


func _dream_restarts_identically() -> bool:
	var root := shell.active_world as DreamMazeRoot
	if root == null:
		return false
	var room := root.start_module_id()
	if room.is_empty():
		return false
	if _restart_room.is_empty():
		_restart_room = room
	return room == _restart_room \
			and str(root.dream_context.get("case_id")) == CASE \
			and str(root.dream_context.get("profile_id")) == PROFILE \
			and str(root.dream_context.get("seed_hex")) == FIXED_SEED_HEX


func _facts_intact(expect_residue: bool) -> bool:
	var job: Dictionary = RealityState.data.maintenance_jobs.get(JOB, {})
	var item: Dictionary = RealityState.data.maintenance_items.get(ITEM, {})
	var case: Dictionary = RealityState.data.cases.get(CASE, {})
	return str(job.get("stage")) == "closed" \
			and str(job.get("repair_result", {}).get("quality")) == "good" \
			and bool(item.get("consumed", false)) \
			and bool(case.get("resolved", false)) \
			and RealityState.has_waking_residue(RESIDUE) == expect_residue


func _production_shell_smoke() -> void:
	_destroy_shell()
	shell = load("res://scenes/campaign/CampaignShell.tscn").instantiate()
	add_child(shell)
	await get_tree().create_timer(1.6).timeout
	var root = shell.active_world
	_check("the production shell builds Orison under its one waking slot",
			shell.world_kind() == "waking" and shell.world_child_count() == 1
			and root != null and root.name == "OrisonRoot")
	_check("production BuildingRoot binds the shell's persistent coordinator",
			root != null and root.get("core_loop") == shell.core_loop
			and shell.core_loop.get_parent() == shell)
	_check("production traffic owns the authored carriageway sleep gate",
			root != null
			and root.street_traffic.blocks_sleep_entry(
					GameBoot.b2g([0.0, -19.0, 0.2]))
			and not root.street_traffic.blocks_sleep_entry(
					GameBoot.b2g([0.0, -13.5, 0.2])))
	_check("production elevator owns its car and threshold sleep gate",
			root != null
			and root.elevator.blocks_sleep_entry(
					root.elevator.global_position + Vector3(0.0, 0.2, 0.0))
			and not root.elevator.blocks_sleep_entry(
					root.elevator.global_position + Vector3(2.0, 0.2, 0.0)))
	_check("the production waking smoke preserves the completed facts",
			_facts_intact(true) and residue_signals == 1)
	_destroy_shell()


func _cleanup() -> void:
	var resolved := ProjectSettings.globalize_path(SAVE_FILE)
	var test_dir := ProjectSettings.globalize_path("user://tests")
	if resolved.begins_with(test_dir) \
			and resolved.ends_with("n4_dream_boundary_save.json"):
		DirAccess.remove_absolute(resolved)
	RealityState.save_path = RealityState.SAVE_PATH
	_check("the contained test save is removed and player save untouched",
			not FileAccess.file_exists(SAVE_FILE)
			and FileAccess.file_exists(RealityState.SAVE_PATH)
					== _player_save_present)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [dream boundary ok] ", label)
	else:
		failures += 1
		printerr("  [DREAM BOUNDARY FAIL] ", label)
