extends Node
## A real title button -> GameBoot -> SceneTree scene change -> CampaignShell.
## The observer is outside the retiring title scene, not a scene-change stub.

class LaunchObserver extends Node:
	var expected: Dictionary
	var expected_bytes: PackedByteArray
	var expected_absolute: float
	var elapsed := 0.0
	var done := false
	var action := "continue"

	func _process(delta: float) -> void:
		if done:
			return
		elapsed += delta
		var shell := get_tree().current_scene as CampaignShell
		if shell != null and shell.active_world != null:
			done = true
			_verify(shell)
		elif elapsed > 30.0:
			done = true
			push_error("Actual title Continue never published a CampaignShell world")
			get_tree().quit(1)

	func _verify(shell: CampaignShell) -> void:
		var world := shell.active_world
		await get_tree().physics_frame
		await get_tree().physics_frame
		var clock := world.get("campaign_clock") as CampaignClock
		var actual := {}
		for key in expected:
			actual[key] = RealityState.data.get(key, {})
		actual = JSON.parse_string(JSON.stringify(actual))
		var checks := {
			"selected_waking_root_matches_session": world.scene_file_path == BuildingRootSelector.scene_path(),
			"actual_scene_changed_to_campaign_shell": get_tree().current_scene == shell,
			"real_world_has_player": is_instance_valid(world.get("player")) and not bool(world.get("startup_failed")),
			"exact_calendar_and_semantic_facts_preserved": actual == expected,
			"real_destination_clock_bound": clock != null and clock.bind_state()
					and (action != "continue" or absf(clock.absolute_minutes() - expected_absolute) < 0.00001),
			"title_scene_retired": get_tree().root.find_child("PrimaryCampaignAction", true, false) == null,
		}
		if action != "continue":
			checks["fresh_campaign_has_no_previous_job_or_item"] = RealityState.data.maintenance_jobs.is_empty() \
					and RealityState.data.maintenance_items.is_empty()
			checks["new_campaign_clock_starts_at_injected_time"] = clock != null \
					and int(RealityState.data.campaign_clock.start_minute_of_day) == 13 * 60 + 27
			checks["normal_title_launch_starts_first_shift"] = bool(RealityState.data.intro_complete) \
					and world.get("first_shift_director").ritual_phase() == FirstShiftDirector.PHASE_ARRIVED
		var directory := OS.get_environment("SHOT_DIR")
		if not directory.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(directory)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join("title_" + action + "_arrival.png"))
		# Real world initialization may commit additive facts. Primary bytes are
		# retained as evidence, but a byte-identity claim would overstate scope.
		var failures := 0
		for key in checks:
			print("[TITLE ACTUAL CONTINUE] %s %s" % ["PASS" if checks[key] else "FAIL", key])
			if not checks[key]:
				failures += 1
		var receipt := {"checks": checks, "expected_facts": expected, "actual_facts": actual,
				"selected_root": world.scene_file_path, "source_primary_bytes": expected_bytes.size(),
				"post_world_primary_bytes": FileAccess.get_file_as_bytes(RealityState.save_path).size(),
				"scope": "actual title button and scene transition with explicit campaign-time freeze; no human traversal"}
		var path := OS.get_environment("TITLE_ACTUAL_RECEIPT")
		if not path.is_empty():
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(receipt, "\t"))
				file.close()
			else:
				failures += 1
		shell.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
		print("[TITLE ACTUAL CONTINUE] checks=%d failures=%d" % [checks.size(), failures])
		get_tree().quit(0 if failures == 0 else 1)


func _ready() -> void:
	CampaignTime.set_frozen_for_tests(true)
	OS.set_environment("TITLE_SCREEN_SILENT", "1")
	var action := OS.get_environment("TITLE_ACTUAL_ACTION")
	if action.is_empty(): action = "continue"
	if action not in ["continue", "begin", "new"]:
		get_tree().quit(2)
		return
	RealityState.save_path = "user://tests/title_actual_%s_%s/campaign.json" % [
			action, Crypto.new().generate_random_bytes(8).hex_encode()]
	RealityState.persistence_enabled = true
	if FileAccess.file_exists(RealityState.save_path):
		get_tree().quit(2)
		return
	RealityState.load_game()
	RealityState.new_campaign_time_provider = func(): return {"hour": 13, "minute": 27}
	if action != "begin" and not RealityState.start_new_campaign():
		get_tree().quit(2)
		return
	var clock := CampaignClock.new()
	if action != "begin" and (not clock.configure_date(1928, 11, 10, 1439) or not clock.advance_to(181.5)):
		get_tree().quit(2)
		return
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE,
			"report_id": ChirpHunt.JOB_ID, "filing": "fault_corrected"}
	RealityState.data.core_loop = {"safe_return_anchor": "F04_B_BED", "boundary": "wake_complete",
			"active_job_id": "", "conversation_requested": false,
			"conversation_complete": false, "dream_pending": false}
	if action != "begin" and not RealityState.save_game():
		get_tree().quit(2)
		return
	RealityState.load_game()
	var observer := LaunchObserver.new()
	observer.action = action
	observer.expected = JSON.parse_string(JSON.stringify({
			"campaign_clock": RealityState.data.campaign_clock,
			"first_shift": RealityState.data.first_shift, "core_loop": RealityState.data.core_loop})) if action == "continue" else {}
	observer.expected_absolute = clock.absolute_minutes() if action == "continue" else 13 * 60 + 27
	observer.expected_bytes = FileAccess.get_file_as_bytes(RealityState.save_path) if action != "begin" else PackedByteArray()
	get_tree().root.add_child.call_deferred(observer)
	var title := load("res://scenes/ui/title_screen.tscn").instantiate() as OrisonTitleScreen
	add_child(title)
	await get_tree().process_frame
	await get_tree().process_frame
	if title._primary_button.text != ("BEGIN THE NIGHT" if action == "begin" else "CONTINUE"):
		get_tree().quit(1)
		return
	# No GameBoot scene-operation override is installed in this process.
	if action == "new":
		title._new_campaign_button.pressed.emit()
		title._replacement_confirm.pressed.emit()
	else:
		title._primary_button.pressed.emit()
