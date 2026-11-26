extends "res://tests/companion_session_bench.gd"

const Lexicon = preload("res://scripts/device/companion_lexicon.gd")
var cues: Array[String] = []
var panel: CaseDialoguePanel
var echo_at_msec := -1

func exercise() -> void:
	diagnostic_scope = "Native recorded resident speech, heard-word save and companion playback"
	var session: Node = carrier.session
	var empty := Lexicon.new()
	check(empty.practice() == "" and not empty.can_say("offer"), "a fresh set has no English")
	check(not empty.learn("hello", "companion_output") and not empty.learn("help", "cd_open"), "self-output and words absent from the identified take are refused")
	var old: Dictionary = Campaign.fresh()
	old.erase("heard")
	old.version = 1
	check(Campaign.valid(old), "an existing correspondence save can open with an empty vocabulary")
	var forged := Campaign.fresh()
	forged.heard = {"hello":"cd_open"}
	check(not Campaign.valid(forged), "the save validator rejects invented heard-word provenance")
	for line: String in Lexicon.line_ids():
		var sample := PropAudio.get_stream("companion_say_" + line)
		check(sample != null and sample.get_length() > .1, "decoded LPC performance " + line)
	panel = CaseDialoguePanel.new()
	add_child(panel)
	var conversations := ResidentConversations.new()
	add_child(conversations)
	conversations.setup(panel)
	AudioPolicy.cue_presented.connect(func(id: StringName, _snapshot: Dictionary):
		cues.append(str(id))
		if id == &"companion_say_no": echo_at_msec = Time.get_ticks_msec())
	await wait_for(func(): return not carrier.device.teletype.printing)
	var recorder := AudioEffectRecord.new()
	var bus := AudioServer.get_bus_index("Dialogue")
	var effect := AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus, recorder)
	recorder.set_recording_active(true)
	check(conversations.start("cal_dwyer") and panel.current_node_id == "cd_open" and panel._spoken.playing, "Cal's real first conversation opens its matched locked take")
	check(session.lexicon.heard.is_empty(), "opening a dialogue and rendering all its text teaches nothing in advance")
	check(await wait_for(func(): return session.lexicon.heard.has("no"), 8.0), "Cal actually says no before the conversation is interrupted")
	check(not session.lexicon.heard.has("i") and not session.lexicon.heard.has("yes"), "the unheard tail and the player's response options stay unknown")
	await capture("cal-at-the-door.png")
	panel.close()
	panel._end_tree()
	var n: int = session.lexicon.heard.size()
	carrier.reading = true
	await get_tree().create_timer(.65).timeout
	check(echo_at_msec < 0, "Vantry gives the player silence while they read")
	carrier.reading = false
	var reading_ended := Time.get_ticks_msec()
	check(await wait_for(func(): return cues.has("companion_say_no"), 5.0), "in the first quiet moment Vantry tries Cal's no in his own spatial voice")
	check(echo_at_msec - reading_ended >= 480, "the echo waits for a continuous quiet beat after reading ends")
	await get_tree().create_timer(1.0).timeout
	recorder.set_recording_active(false)
	var waveform := recorder.get_recording()
	if waveform != null: waveform.save_to_wav(directory.path_join("cal-and-vantry.wav"))
	AudioServer.remove_bus_effect(bus, effect)
	check(n == session.lexicon.heard.size() and session.lexicon.heard.get("no") == "cd_open", "he cannot learn from his echo")
	var cal: Dictionary = conversations.trees["cal_dwyer"]
	panel.run_tree(cal, "cd_open", Callable())
	AudioServer.set_bus_mute(bus, true)
	await get_tree().create_timer(1.2).timeout
	panel.close()
	AudioServer.set_bus_mute(bus, false)
	check(session.lexicon.heard.size() == n, "muted replay adds no words")
	var cam: Dictionary = conversations.trees["cam_ortiz"]
	AudioServer.set_bus_mute(bus, true)
	panel.run_tree(cam, "co_slow", Callable())
	await get_tree().create_timer(1.7).timeout
	panel.close()
	AudioServer.set_bus_mute(bus, false)
	check(not session.lexicon.heard.has("crashed"), "a new resident speaking on a muted bus cannot teach")
	var changed: Dictionary = cal.duplicate(true)
	changed.nodes.cd_open.line += " Spoiled copy."
	panel.run_tree(changed, "cd_open", Callable())
	check(not panel._spoken.playing, "a changed line cannot use the archived voice or teach its words")
	panel.close()
	var sacha: Dictionary = conversations.trees["sacha_reed"]
	panel.run_tree(sacha, "sr_open", Callable())
	check(await wait_for(func(): return session.lexicon.heard.has("can"), 4.0), "another take contributes can")
	panel.close()
	panel.run_tree(sacha, "sr_faster", Callable())
	check(await wait_for(func(): return session.lexicon.heard.has("help") and session.lexicon.heard.has("i"), 8.0), "a second visit supplies the actual help and I in Sacha's voice")
	panel.close()
	check(session.lexicon.practice() == "correct" and session.lexicon.can_say("offer") and not session.lexicon.can_say("confident"), "only complete authored sentences unlock across visits")
	RealityState.save_path = "user://tests/vantry_voice.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	RealityState.persistence_enabled = true
	var captured: Dictionary = session.lexicon.heard.duplicate()
	check(RealityState.save_game(), "write the heard vocabulary to campaign storage")
	session.lexicon.heard.clear()
	RealityState.load_game()
	check(session.lexicon.heard == captured and session._echo == "", "Continue restores words and their sources and discards pending sounds")
	await joy(JOY_BUTTON_DPAD_DOWN)
	await wait_for(func(): return carrier.motion.steady_for_input() and not carrier.device.teletype.printing)
	await joy(JOY_BUTTON_A)
	if check(await wait_for(func(): return session.typing), "open Vantry's real keyboard"):
		await type_text("say something")
		await key(KEY_ENTER)
		check(await wait_for(func(): return cues.has("companion_say_correct"), 9.0), "an explicit practice request plays the unlocked self-correcting phrase")
		await capture("vantry-practising.png")
	check(session.lexicon.heard == captured, "typed requests and Vantry's English cannot teach him")
	finish()

var started_at := Time.get_ticks_msec()

func finish() -> void:
	if finished: return
	var failures := checks.filter(func(row: Dictionary): return not row.passed)
	var inputs := {}
	for path: String in ["res://scripts/audio/resident_heard_speech.gd", "res://scripts/device/companion_lexicon.gd",
			"res://scripts/device/companion_session.gd", "res://scripts/device/companion_campaign_state.gd",
			"res://scripts/ui/case_dialogue_panel.gd", "res://data/device/companion_speech.json", "res://tests/companion_speech_bench.gd"]:
		inputs[path] = FileAccess.get_sha256(path)
	var receipt := {"schema_version":2, "evidence_kind":"runtime_contract", "production_runtime":false, "selector":"v2",
		"scope":diagnostic_scope, "execution":{"completed":true, "exit_code":0 if failures.is_empty() else 1, "timed_out":false, "elapsed_s":(Time.get_ticks_msec()-started_at)/1000.0},
		"source":{"inputs":inputs}, "checks":checks, "failures":failures, "audio_cues":cues,
		"contracts":{"witnessed_english":{"executed":true, "status":"PASS" if failures.is_empty() else "FAIL"}}}
	FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE).store_string(JSON.stringify(receipt, "\t"))
	super.finish()
