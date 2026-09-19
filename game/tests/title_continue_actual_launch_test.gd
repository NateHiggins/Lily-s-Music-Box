extends Node
## A real title button -> GameBoot -> SceneTree scene change -> CampaignShell.
## The observer is outside the retiring title scene, not a scene-change stub.

class LaunchObserver extends Node:
	var expected: Dictionary
	var expected_bytes: PackedByteArray
	var expected_absolute: float
	var elapsed := 0.0
	var done := false

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
		var clock := world.get("campaign_clock") as CampaignClock
		var actual := {}
		for key in expected:
			actual[key] = RealityState.data.get(key, {})
		actual = JSON.parse_string(JSON.stringify(actual))
		var checks := {
			"actual_scene_changed_to_campaign_shell": get_tree().current_scene == shell,
			"real_world_has_player": is_instance_valid(world.get("player")) and not bool(world.get("startup_failed")),
			"exact_calendar_and_semantic_facts_preserved": actual == expected,
			"real_destination_clock_bound": clock != null and clock.bind_state()
					and absf(clock.absolute_minutes() - expected_absolute) < 0.00001,
			"title_scene_retired": get_tree().root.find_child("PrimaryCampaignAction", true, false) == null,
		}
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
	RealityState.save_path = "user://tests/title_actual_continue/campaign.json"
	RealityState.persistence_enabled = true
	if FileAccess.file_exists(RealityState.save_path):
		get_tree().quit(2)
		return
	RealityState.load_game()
	RealityState.new_campaign_time_provider = func(): return {"hour": 13, "minute": 27}
	if not RealityState.start_new_campaign():
		get_tree().quit(2)
		return
	RealityState.new_campaign_time_provider = Callable()
	var clock := CampaignClock.new()
	if not clock.configure_date(1928, 11, 10, 1439) or not clock.advance_to(181.5):
		get_tree().quit(2)
		return
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE,
			"report_id": ChirpHunt.JOB_ID, "filing": "fault_corrected"}
	RealityState.data.core_loop = {"safe_return_anchor": "F04_B_BED", "boundary": "wake_complete",
			"active_job_id": "", "conversation_requested": false,
			"conversation_complete": false, "dream_pending": false}
	if not RealityState.save_game():
		get_tree().quit(2)
		return
	RealityState.load_game()
	var observer := LaunchObserver.new()
	observer.expected = JSON.parse_string(JSON.stringify({
			"campaign_clock": RealityState.data.campaign_clock,
			"first_shift": RealityState.data.first_shift, "core_loop": RealityState.data.core_loop}))
	observer.expected_absolute = clock.absolute_minutes()
	observer.expected_bytes = FileAccess.get_file_as_bytes(RealityState.save_path)
	get_tree().root.add_child.call_deferred(observer)
	var title := load("res://scenes/ui/title_screen.tscn").instantiate() as OrisonTitleScreen
	add_child(title)
	await get_tree().process_frame
	await get_tree().process_frame
	if title._primary_button.text != "CONTINUE":
		get_tree().quit(1)
		return
	# No GameBoot scene-operation override is installed in this process.
	title._primary_button.pressed.emit()
