extends "res://tests/orison_v2_golden_repair_route_test.gd"
## Continues the earned physical repair into the resident's first conversation.
## Does not seed repaired facts, skip the errand, or declare dream/wake complete.

func _init() -> void:
	route_label = "V2 EARNED CONVERSATION"

func _route() -> void:
	await super._route()
	if not failures.is_empty(): return
	for point in [Vector3(-10.5,3.2,2.5),Vector3(-13.4,3.2,2.5),Vector3(-13.4,3.2,1.95)]:
		if not await _walk(point): return
	var mina: AnimatedResident = world.mina_routine.actor
	if not await _use(mina,mina.global_position+Vector3.UP*1.15,"earned_mina_conversation"): return
	if not _require(world.mina_gameplay.dialogue._panel.visible and player.call_locked,
			"repaired head earns the physical resident conversation"): return
	await get_tree().create_timer(.4).timeout
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("earned_conversation.png"))
	for i in 30:
		if not world.mina_gameplay.dialogue._panel.visible: break
		world.mina_gameplay.dialogue.choose(0)
		await get_tree().process_frame
	var state := RealityState.case_state(MinaCaseGameplay.CASE_ID)
	var flags: Array = state.get("conversation_flags",[])
	_require(not world.mina_gameplay.dialogue._panel.visible and not player.call_locked,
			"earned conversation releases the player")
	_require("first_silence_named" in flags or "first_silence_misread" in flags,
			"authored first-stable conversation persists its interpretation")
	_require(state.repair_count == 1 and state.recurrence_pending and not state.get("resolved",false),
			"first conversation preserves temporary repair and unresolved recurrence")
