extends Node3D
## Actual V1 lobby inspection views, with teleported camera. These frames
## prove composition/legibility only; they are not a walked route or acceptance.

const RUNTIME := preload("res://scenes/building/orison_root.tscn")
var shots := ShotHarness.new()
var clock := CampaignClock.new()


func _ready() -> void:
	OS.set_environment("CAMPAIGN_TIME_FREEZE", "1")
	OS.set_environment("DAYNIGHT_FORCE", "night")
	OS.set_environment("SCHEDULE", "0")
	OS.set_environment("TELEGRAM_REDUCED_TYPEWRITER", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE}
	clock.configure_date(1928, 11, 10, 23 * 60 + 59)
	var world := RUNTIME.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().physics_frame
	var control := world.find_child("WirelessNoticeInspection", true, false) as Area3D
	if control == null:
		push_error("Actual V1 lobby has no wireless notice consumer")
		get_tree().quit(2)
		return
	var board := control.get_parent() as Node3D
	var player: PlayerController = world.player
	player.set_physics_process(false)
	player.call_locked = false
	player.telegram_hud.reduced_typewriter = true
	var target := control.global_position
	var forward := board.global_transform.basis.z.normalized()
	player.global_position = target + forward * 1.0 - Vector3.UP * 1.6
	player.camera.global_position = target + forward * 1.0
	player.camera.look_at(target)
	player.camera.current = true
	if not shots.setup(self, "HISTORICAL-RADIO-V1-LOBBY", 3):
		get_tree().quit(2)
		return
	await shots.settle(1.0, "actual_lobby_ready")
	await shots.capture("01_physical_hand_copy")
	var before: Dictionary = control.call("interact", player)
	player._present_interaction_telegram(control, before)
	await shots.settle(0.3, "pending_notice_printed")
	await shots.capture("02_pending_field_copy")
	clock.advance_to(181.0) # November 11, exactly 03:00 EST.
	var after: Dictionary = control.call("interact", player)
	player._present_interaction_telegram(control, after)
	await shots.settle(0.3, "effective_notice_printed")
	await shots.capture("03_effective_field_copy")
	var receipt := {"capture_kind": "actual_v1_lobby_teleported_inspection",
			"walked_route_proven": false, "human_accepted": false,
			"control": str(control.get_path()), "before": before, "after": after,
			"presented": player.telegram_hud.last_card,
			"clock": RealityState.data.campaign_clock.duplicate(true)}
	var file := FileAccess.open(shots.output_dir.path_join("lobby_observations.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(receipt, "\t"))
		file.close()
	var okay: bool = shots.finish() and file != null \
			and before.get("notice_phase") == "BEFORE" and after.get("notice_phase") == "AFTER" \
			and player.telegram_hud.last_card.get("notice_phase") == "AFTER"
	remove_child(world)
	world.free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if okay else 2)
