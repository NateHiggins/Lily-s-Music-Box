extends Node
var _fails := 0

func _check(label: String, ok: bool) -> void:
	print("FIELD COPY: ", label, " = ", ok)
	if not ok: _fails += 1

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	await _check_conversation_field_copy()
	print("FIELD COPY CONVERSATION: %d failures" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _check_conversation_field_copy() -> void:
	var hud := TelegramHud.new()
	add_child(hud)
	var dialogue := CaseDialoguePanel.new()
	add_child(dialogue)
	var campaign_before := var_to_bytes(RealityState.data)
	hud.present({"title":"REPAIR", "body":"THE TRANSMITTER IS QUIET STOP"})
	await get_tree().create_timer(.25).timeout
	_check("field copy appears before conversation", hud.visible and hud._paper.visible)
	dialogue.present("MINA", "It stopped.", [{"text":"Listen", "action":func(): pass}])
	await get_tree().process_frame
	await get_tree().process_frame
	var elapsed := hud._life.get_total_elapsed_time()
	await get_tree().create_timer(.3).timeout
	_check("dialogue hides paper and pauses reading without taking pointer ownership",
			not hud.visible and is_equal_approx(elapsed, hud._life.get_total_elapsed_time())
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	hud.present({"title":"FOLLOWUP", "body":"THE LINE REMAINS QUIET STOP"})
	var serial := hud.serial
	await get_tree().create_timer(.2).timeout
	_check("replacement field copy waits behind an already open conversation",
			not hud.visible and is_zero_approx(hud._life.get_total_elapsed_time()))
	dialogue.close()
	await get_tree().create_timer(.25).timeout
	_check("closing dialogue restores the latest copy once with its reading time",
			hud.visible and hud._paper.visible and hud.serial == serial
			and hud.last_card.title == "FOLLOWUP" and hud._life.get_total_elapsed_time() > 0)
	dialogue.present("MINA", "Thank you.", [{"text":"Listen", "action":func(): pass}])
	await get_tree().process_frame
	await get_tree().process_frame
	hud.dismiss()
	dialogue.close()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("dismissed field copy cannot return after conversation",
			hud.visible and not hud._paper.visible and hud.serial == serial)
	hud.hide()
	dialogue.present("MINA", "Good night.", [{"text":"Listen", "action":func(): pass}])
	await get_tree().process_frame
	await get_tree().process_frame
	dialogue.close()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("conversation preserves a field-copy layer hidden by its caller", not hud.visible)
	_check("presentation overlap handling leaves campaign facts unchanged",
			var_to_bytes(RealityState.data) == campaign_before)
	dialogue.free()
	hud.free()
