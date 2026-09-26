extends Node
## One continuous production CampaignShell, from arrival to natural dream and
## wake. The existing collision drivers supply actions, never case/save seeds.
class WakingDriver extends "res://tests/orison_v2_recurrence_route_test.gd":
	func _ready() -> void:
		pass
	func _begin_first_shift() -> bool:
		# CampaignShell's real deferred boot has already begun the arrival.
		return bool(RealityState.data.get("intro_complete", false)) \
				and world.first_shift_director.ritual_phase() == FirstShiftDirector.PHASE_ARRIVED
class DreamDriver extends "res://tests/orison_v2_played_dream_test.gd":
	func _ready() -> void:
		pass

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 20 * 60)
	var output := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var original_path := RealityState.save_path
	RealityState.save_path = output.path_join("full_shift_save.json")
	var shell := CampaignShell.new()
	shell.waking_scene_path = "res://scenes/building/orison_v2_runtime.tscn"
	add_child(shell)
	await _settle_player(shell)
	var route := WakingDriver.new()
	add_child(route)
	route.world = shell.active_world as OrisonV2RuntimeRoot
	route.player = route.world.player
	route.player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await route._route()
	Input.action_release("move_forward")
	var failures: Array[String] = route.failures.duplicate()
	var waypoints := route.trace.size()
	FileAccess.open(output.path_join("waking_route.json"), FileAccess.WRITE).store_string(
			JSON.stringify({"trace":route.trace, "failures":failures}, "\t"))
	route.free()
	var dream := DreamDriver.new()
	add_child(dream)
	dream.shell = shell
	dream.output = output
	if failures.is_empty():
		dream.check(shell.core_loop.boundary() == "dream_pending", "uninterrupted physical shift earns dream")
		if await dream.enter_earned_dream():
			dream.check(await dream.complete_dream(), "uninterrupted campaign returns naturally")
			await _settle_player(shell)
			if shell.world_kind() == "waking":
				var world := shell.active_world as OrisonV2RuntimeRoot
				dream.check(shell.core_loop.boundary() == "wake_complete"
						and world.work_orders.job_stage(ChirpHunt.JOB_ID) == "closed"
						and RealityState.has_waking_residue(MinaCaptionManifestation.RESIDUE_ID),
						"same campaign preserves completed work and factual residue")
				dream.check(world.player.global_position.distance_to(shell.core_loop.resolve_return_anchor().position) < .5,
						"same campaign wakes at its authored V2 bedside")
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(output.path_join("continuous_wake.png"))
				dream.check(RealityState.save_game(), "complete continuous shift saves through its owner")
		failures.append_array(dream.failures)
	dream.free()
	shell.free()
	RealityState.save_path = original_path
	await get_tree().process_frame
	await get_tree().process_frame
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(
			JSON.stringify({"waypoints":waypoints, "failures":failures}, "\t"))
	print("V2 FULL SHIFT: %d waypoints; %d failures" % [waypoints, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _settle_player(shell: CampaignShell) -> void:
	# Observe the real body's landing, not an assumed loading/settling delay.
	for frame in 120:
		await get_tree().physics_frame
		if frame > 1 and shell.active_world is OrisonV2RuntimeRoot \
				and shell.active_world.player.is_on_floor():
			return
