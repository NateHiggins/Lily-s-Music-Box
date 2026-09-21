extends Node
## Real selected CampaignShell + DreamMazeRoot, with isolated test storage.
## The public developer preview supplies the dream request; this proves scene
## reconstruction and save preservation, not an earned case or played maze.

const SEED := "d06f00d5cafef00d"
const FACT_KEYS := ["maintenance_jobs", "maintenance_items", "cases", "core_loop",
	"first_shift", "dreams_had", "waking_residues", "campaign_clock"]

var shell: CampaignShell
var checks: Dictionary = {}
var failures: Array[String] = []
var expected_facts: Dictionary = {}
var poses: Dictionary = {}
var test_save := ""
var original_save := ""
var original_bytes: PackedByteArray
var original_present := false
var original_mode: int
var finished := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_watchdog()
	original_save = RealityState.save_path
	original_present = FileAccess.file_exists(original_save)
	original_bytes = FileAccess.get_file_as_bytes(original_save) if original_present else PackedByteArray()
	original_mode = GameBoot.launch_mode
	if not _check("windowed pointer and render verification", DisplayServer.get_name() != "headless"):
		await _finish()
		return
	if not _check("session selector chooses V2 without a waking-scene override", BuildingRootSelector.selected_id() == "v2"):
		await _finish()
		return
	CampaignTime.set_frozen_for_tests(true)
	test_save = "user://tests/v2_wake_%s/campaign.json" % Crypto.new().generate_random_bytes(8).hex_encode()
	RealityState.save_path = test_save
	RealityState.persistence_enabled = true
	RealityState.load_game()
	RealityState.new_campaign_time_provider = func(): return {"hour": 13, "minute": 27}
	if not _check("isolated new campaign can be saved", RealityState.start_new_campaign()):
		await _finish()
		return
	RealityState.data.dream_seed = SEED
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _spawn_shell()
	if not _check_waking("initial"):
		await _finish()
		return
	_check("actual first-shift startup has completed before the preview", bool(RealityState.data.intro_complete))
	expected_facts = _semantic_facts()
	_check("preview starts with an unearned maintenance loop", shell.core_loop.boundary() == "idle"
		and RealityState.data.maintenance_jobs.is_empty() and int(RealityState.data.dreams_had) == 0)
	if not await _enter_preview("normal"):
		await _finish()
		return
	_check("normal ending commits before replacing the actual dream", shell.dream_director.end_dream("capture")
		and shell.dream_director.phase() == "return_pending" and shell.active_world is DreamMazeRoot)
	await _settle()
	await _verify_bedside("normal_return")
	_check("normal preview return preserves exact semantic loop facts", _semantic_facts() == expected_facts)

	if not await _enter_preview("checkpoint"):
		await _finish()
		return
	_check("second real dream commits return_pending", shell.dream_director.end_dream("contact")
		and shell.dream_director.phase() == "return_pending" and shell.active_world is DreamMazeRoot)
	_check("return_pending is written through production storage", RealityState.save_game())
	var committed: Variant = JSON.parse_string(FileAccess.get_file_as_string(test_save))
	_check("saved checkpoint retains its preview and pending-return identity", committed is Dictionary
		and str(committed.get("dream", {}).get("phase", "")) == "return_pending"
		and bool(committed.get("dream", {}).get("debug_preview", false)))
	# Simulate stopping between the committed transaction and its deferred swap.
	# Teardown queues the actual render world; freeing only the shell cancels its
	# queued callback without synchronously deleting that world graph.
	await _destroy_shell()
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	_check("real-file reload restores return_pending without a live world", str(RealityState.data.dream.get("phase", "")) == "return_pending"
		and _semantic_facts() == expected_facts and shell == null)
	await _spawn_shell()
	await _verify_bedside("saved_return_pending")
	_check("saved preview reconciliation preserves exact semantic loop facts", _semantic_facts() == expected_facts)
	_check("both returns leave the developer preview transaction awake", shell.dream_director.phase() == "awake"
		and not bool(shell.dream_director.dream_state().debug_preview))
	await _finish()


func _spawn_shell() -> void:
	shell = load("res://scenes/campaign/CampaignShell.tscn").instantiate() as CampaignShell
	shell.sleep_manual_clock = true
	shell.world_changed.connect(func(kind: String, world: Node):
		if kind == "dream" and world is DreamMazeRoot:
			(world as DreamMazeRoot).autonomous = false)
	add_child(shell)
	await _settle()


func _enter_preview(label: String) -> bool:
	var player := shell.active_world.get("player") as PlayerController
	for _i in 60:
		if player != null and player.sleep_entry_body_is_stable():
			break
		await get_tree().physics_frame
	if not _check(label + ": actual waking capsule is physically stable before onset", player != null and player.sleep_entry_body_is_stable()):
		return false
	if not _check(label + ": public debug request arms the production director", shell.debug_start_dream_sequence()
			and shell.dream_director.phase() == "armed" and bool(shell.dream_director.dream_state().debug_preview)):
		return false
	_check(label + ": production onset advances under the explicit test clock", shell.sleep_pressure.advance_for_test(3.0))
	await _settle()
	var dream := shell.active_world as DreamMazeRoot
	if not _check(label + ": actual DreamMazeRoot exclusively replaces selected V2", dream != null
			and shell.world_kind() == "dream" and shell.world_child_count() == 1
			and shell.dream_director.phase() == "active"):
		return false
	_check(label + ": actual dream receives the authored reconstruction identity", str(dream.dream_context.get("seed_hex", "")) == SEED
		and str(dream.dream_context.get("case_id", "")) == "mina_caption_crisis"
		and not dream.start_module_id().is_empty())
	_check(label + ": preview entry consumes no campaign progression", _semantic_facts() == expected_facts)
	await _capture(label + "_actual_dream")
	return true


func _check_waking(label: String) -> bool:
	return _check(label + ": selected V2 is the sole real waking world", is_instance_valid(shell)
		and shell.active_world is OrisonV2RuntimeRoot and shell.world_child_count() == 1
		and shell.world_kind() == "waking" and not shell.active_world.startup_failed
		and shell.waking_scene_path.is_empty()
		and shell.active_world.scene_file_path == BuildingRootSelector.scene_path())


func _verify_bedside(label: String) -> void:
	if not _check_waking(label):
		return
	var world := shell.active_world as OrisonV2RuntimeRoot
	var anchor := shell.core_loop.resolve_return_anchor()
	if not _check(label + ": V2 resolves its real bedside anchor", not anchor.is_empty()
			and str(anchor.get("id", "")) == "F04_B_BED"):
		return
	# FirstShiftDirector's deferred resume used to replace the correctly placed
	# bedside player with the street arrival. Sample well beyond that boundary.
	for _i in 90:
		await get_tree().physics_frame
	var player := world.player
	poses[label] = {"player": var_to_str(player.global_position), "bedside": var_to_str(anchor.position),
		"arrival": var_to_str(world.arrival_placement().position), "on_floor": player.is_on_floor()}
	_check(label + ": deferred first-shift startup keeps the player at the V2 bedside", player.global_position.distance_to(anchor.position) < 0.35
		and player.global_position.distance_to(world.arrival_placement().position) > 5.0
		and player.is_on_floor())
	_check(label + ": wake restores actual gameplay camera and processing", get_viewport().get_camera_3d() == player.camera
		and player.is_processing() and player.is_physics_processing()
		and player.is_processing_unhandled_input() and not player.call_locked)
	_check(label + ": authored bed remains the actual view target", (-player.camera.global_basis.z).dot(
		(anchor.facing_position - player.camera.global_position).normalized()) > 0.97)
	_check(label + ": wake retains gameplay pointer capture", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	await _key(KEY_QUOTELEFT)
	_check(label + ": backtick still releases the pointer after reconstruction", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	await _key(KEY_QUOTELEFT)
	_check(label + ": backtick recaptures after reconstruction", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	await _capture(label + "_bedside")


func _semantic_facts() -> Dictionary:
	var result := {}
	for key: String in FACT_KEYS:
		result[key] = RealityState.data.get(key)
	return JSON.parse_string(JSON.stringify(result)) as Dictionary


func _settle() -> void:
	for _i in 4:
		await get_tree().process_frame
	for _i in 4:
		await get_tree().physics_frame


func _destroy_shell() -> void:
	if is_instance_valid(shell):
		_check("public world teardown " + str(checks.size()), bool(shell.teardown_active_world().get("ok", false)))
		remove_child(shell)
		shell.free()
	shell = null
	await _settle()


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	event.pressed = false
	get_viewport().push_input(event, true)
	await get_tree().process_frame


func _capture(stem: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_check("capture " + stem, get_viewport().get_texture().get_image().save_png(directory.path_join(stem + ".png")) == OK)


func _check(label: String, passed: bool) -> bool:
	checks[label] = passed
	if not passed:
		failures.append(label)
	print("[V2 WAKE] %s %s" % ["PASS" if passed else "FAIL", label])
	return passed


func _watchdog() -> void:
	await get_tree().create_timer(150.0, true, false, true).timeout
	if not finished:
		push_error("V2 wake reconstruction exceeded 150 seconds")
		get_tree().quit(1)


func _finish() -> void:
	await _destroy_shell()
	_check("original player save is byte-identical", FileAccess.file_exists(original_save) == original_present
		and (not original_present or FileAccess.get_file_as_bytes(original_save) == original_bytes))
	var receipt := {"schema": "orison.v2-wake-reconstruction.diagnostic.v1", "checks": checks, "failures": failures,
		"selector": BuildingRootSelector.selected_id(), "poses": poses, "test_save": test_save,
		"scope": "Actual selected V2, public debug arm, production onset/DreamMazeRoot/end transaction, normal and real-file return_pending reconstruction. Frozen campaign clock; no earned-case or played-maze claim."}
	var output := OS.get_environment("V2_WAKE_RECEIPT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(receipt, "\t"))
			file.close()
		else:
			failures.append("cannot write requested diagnostic")
	RealityState.persistence_enabled = false
	RealityState.save_path = original_save
	RealityState.new_campaign_time_provider = Callable()
	GameBoot.launch_mode = original_mode
	finished = true
	print("V2 WAKE RECONSTRUCTION: %d checks; %d failures" % [checks.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
