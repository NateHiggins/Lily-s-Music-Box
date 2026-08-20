extends Node
## Focused production proof for the F1 Dreamworld button. It starts with a
## completely unearned campaign, presses the real UI control, advances the real
## onset deterministically, crosses both world swaps, and proves the preview did
## not manufacture any golden-loop progress.

const FIXED_SEED_HEX := "d06f00d5cafef00d"

var failures := 0
var checks := 0
var shell: CampaignShell
var _finished := false
var _old_launch_mode: int
var _old_persistence := true


func _ready() -> void:
	print("[DEBUG DREAM BUTTON] START")
	_watchdog()
	_old_launch_mode = GameBoot.launch_mode
	_old_persistence = RealityState.persistence_enabled
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.dream_seed = FIXED_SEED_HEX

	shell = load("res://scenes/campaign/CampaignShell.tscn").instantiate()
	shell.sleep_manual_clock = true
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel := _find_debug(shell.active_world)
	var button := _find_button(panel, "Start Dreamworld sequence")
	_check("DEBUG waking world exposes the Dreamworld sequence button",
			panel != null and button != null and not button.disabled)
	if button == null:
		_finish()
		return

	button.emit_signal("pressed")
	_check("the button arms the authored production dream",
			shell.dream_director.phase() == "armed"
			and bool(shell.dream_director.dream_state().debug_preview)
			and str(shell.dream_director.context().case_id)
					== "mina_caption_crisis"
			and str(shell.dream_director.context().profile_id)
					== "mina_release_print")
	_check("preview arming hides the waking debug panel",
			panel._body != null and not panel._body.visible)
	_check("preview arming forges no golden-loop progress",
			shell.core_loop.boundary() == "idle"
			and RealityState.data.maintenance_jobs.is_empty())

	_check("the manual proof advances the real onset owner",
			shell.sleep_pressure.advance_for_test(3.0))
	await get_tree().process_frame
	await get_tree().process_frame
	_check("the button reaches the one production dream world",
			shell.dream_director.phase() == "active"
			and shell.world_kind() == "dream"
			and shell.world_child_count() == 1
			and shell.active_world is DreamMazeRoot)
	_check("a preview sees but does not consume the next decay night",
			int(shell.dream_director.context().night_index) == 0
			and int(RealityState.data.dreams_had) == 0)

	_check("the normal ending funnel accepts the preview",
			shell.dream_director.end_dream("capture"))
	await get_tree().process_frame
	await get_tree().process_frame
	var anchor := shell.core_loop.resolve_return_anchor()
	var player: Node3D = shell.active_world.get("player") as Node3D
	_check("preview ending rebuilds waking Orison and clears the transaction",
			shell.world_kind() == "waking"
			and shell.world_child_count() == 1
			and shell.dream_director.phase() == "awake"
			and not bool(shell.dream_director.dream_state().debug_preview))
	_check("preview wakes at the authored 4B bedside",
			player != null and not anchor.is_empty()
			and player.global_position.distance_to(anchor.position) < 0.5)
	_check("preview return leaves campaign owners untouched",
			shell.core_loop.boundary() == "idle"
			and RealityState.data.maintenance_jobs.is_empty()
			and int(RealityState.data.dreams_had) == 0
			and RealityState.data.waking_residues.is_empty())
	_finish()


func _find_debug(node: Node) -> BuildingDebug:
	if node == null:
		return null
	if node is BuildingDebug:
		return node
	for child in node.get_children():
		var found := _find_debug(child)
		if found != null:
			return found
	return null


func _find_button(node: Node, label: String) -> Button:
	if node == null:
		return null
	if node is Button and str((node as Button).text) == label:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, label)
		if found != null:
			return found
	return null


func _watchdog() -> void:
	await get_tree().create_timer(50.0, true, false, true).timeout
	if not _finished:
		printerr("[DEBUG DREAM BUTTON] WATCHDOG: run exceeded 50 seconds")
		get_tree().quit(1)


func _finish() -> void:
	_finished = true
	GameBoot.launch_mode = _old_launch_mode
	RealityState.persistence_enabled = _old_persistence
	print("DEBUG DREAM BUTTON TEST: %s (%d checks)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures, checks])
	get_tree().quit(failures)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [debug dream ok] ", label)
	else:
		failures += 1
		printerr("  [DEBUG DREAM FAIL] ", label)
