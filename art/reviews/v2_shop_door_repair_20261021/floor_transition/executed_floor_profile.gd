extends "res://tests/v2_golden_repair_profile.gd"
## Repeat first upper-floor appearance with the real controller and all blockers.
func _prepare_player_start() -> void:
	player.global_position=world.adapter.root.to_global(Vector3(1.925,.02,-3.5));player.velocity=Vector3.ZERO

func _play_route() -> void:
	for cycle in 3:
		profile_cycle="cycle%d_"%cycle
		for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.975,3.2,-3.4),Vector3(1.925,3.2,-3.4)]:
			if not await _walk(target):return
		profile_phase=profile_cycle+"upper_turn"
		for frame in 120:
			var motion:=InputEventMouseMotion.new();motion.relative=Vector2(6,0);player._unhandled_input(motion)
			await get_tree().process_frame
		for target: Vector3 in [Vector3(3.975,3.2,-3.4),Vector3(3.975,1.6,1.3),Vector3(1.925,1.6,1.3),Vector3(1.925,0,-3.5)]:
			if not await _walk(target):return
