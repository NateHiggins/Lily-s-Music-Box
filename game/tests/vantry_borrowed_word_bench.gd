extends "res://tests/companion_speech_bench.gd"

func _ask() -> void:
	if not carrier.reading: await joy(JOY_BUTTON_DPAD_DOWN)
	await wait_for(func(): return carrier.motion.steady_for_input() and not carrier.device.teletype.printing)
	await joy(JOY_BUTTON_A)
	if not check(await wait_for(func(): return carrier.session.typing), "player opens the correspondence keyboard"): return
	await type_text("what do i say when someone is hurting")
	await key(KEY_ENTER)
	check(await wait_for(func(): return carrier.device.teletype.copy_delivered() and carrier.rig.keyboard_open < .05), "the answer clears the typebars")
	await frames(3)
	var page := " ".join(carrier.device.teletype.pages).replace("\n", " ")
	check("I can keep the light on." in page, "the promise appears on real paper")

func exercise() -> void:
	diagnostic_scope = "Native Cal speech, first borrowed cadence, later player-requested meaning"
	var session: Node = carrier.session
	AudioPolicy.cue_presented.connect(func(id: StringName, _snapshot: Dictionary): cues.append(str(id)))
	await _ask()
	check(not session.lexicon.heard.has("listen") and not cues.has("companion_say_listen"), "asking for advice before learning gives only the paper answer")
	if carrier.reading: await joy(JOY_BUTTON_DPAD_DOWN)
	panel = CaseDialoguePanel.new()
	add_child(panel)
	var conversations := ResidentConversations.new()
	add_child(conversations)
	conversations.setup(panel)
	var bus := AudioServer.get_bus_index("Dialogue")
	var slot := AudioServer.get_bus_effect_count(bus)
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(bus, recorder)
	recorder.set_recording_active(true)
	check(conversations.start("cal_dwyer"), "Cal starts the addressed radio story")
	check(await wait_for(func(): return session.lexicon.heard.get("listen") == "cd_open", 12), "the complete recorded word reaches Vantry")
	check(not cues.has("companion_echo_cal_listen"), "Vantry keeps quiet while Cal has the floor")
	panel.close()
	panel._end_tree()
	check(await wait_for(func(): return cues.has("companion_echo_cal_listen"), 8), "after the quiet beat the cabinet borrows Cal's inflection")
	await get_tree().create_timer(1.1).timeout
	var before: Dictionary = session.lexicon.heard.duplicate()
	await _ask()
	check(await wait_for(func(): return cues.has("companion_say_listen"), 4), "the same word returns in Vantry's own voice as an answer")
	check(cues.count("companion_echo_cal_listen") == 1 and cues.count("companion_say_listen") == 1 and session.lexicon.heard == before,
			"the two deliveries are distinct, each plays once, and neither teaches a word")
	await get_tree().create_timer(1.0).timeout
	recorder.set_recording_active(false)
	var take := recorder.get_recording()
	check(take != null and take.save_to_wav(directory.path_join("borrowed-and-owned.wav")) == OK, "capture the actual dialogue bus for both turns")
	AudioServer.remove_bus_effect(bus, slot)
	finish()
