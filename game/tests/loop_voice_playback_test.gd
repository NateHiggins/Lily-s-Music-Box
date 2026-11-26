extends Node
## Loop voice pilot playback (doc408; Codex's runtime handoff 2026-11-26). The real conversation director and
## panel with authored trees; the five packed Evelyn takes injected from the external case (LOOP_VOICE_PILOT,
## a runtime_manifest.json) with the recording catalog (LOOP_VOICE_CATALOG) for the exact lines; a stub cast
## body that records its mouth; an injected clock so the jaw's alignment to the audio is checked without a sound
## device. Proves: quiet fallback, exact actor+digest binding, playback and face on the audio clock, and a stop on
## the same speaker's next line, a speaker switch, a foreign tree, immediate exit, a loaded save and Continue
## (the node leaving the tree), with the Dialogue bus left as it was. Writes a schema-2 runtime_contract.json to
## SHOT_DIR. No in-world body, render, or artistic or audio-quality acceptance.

const REQUIRED := ["quiet_fallback", "exact_binding", "audio_clock_face", "same_speaker_next", "speaker_switch",
		"foreign_replacement", "silent_delivery", "immediate_exit", "state_loaded", "continue_exit", "bus_stable"]

class StubFace extends RefCounted:
	var _speech_clock := -1.0
	func seek_speech(seconds: float) -> void:
		if _speech_clock >= 0.0:
			_speech_clock = seconds

class StubBody extends Node3D:
	var face := StubFace.new()
	var calls: Array[String] = []
	func speak_cues(cues: Array) -> void:
		calls.append("cues:%d" % cues.size()); face._speech_clock = 0.0
	func speak_untimed(_seconds: float) -> void:
		calls.append("untimed")
	func stop_speaking() -> void:
		calls.append("stop"); face._speech_clock = -1.0

class StubResident extends Node3D:
	var resident_id := ""
	var cast_body: Node3D

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var contracts: Dictionary = {}
var details: Dictionary = {}
var output := ""
var started := 0
var lease := false
var director: ResidentConversations
var panel: CaseDialoguePanel
var player: Node3D
var voice: LoopVoicePlayback
var lines: Dictionary = {}
var now := 0.0
var evelyn: StubResident


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "label": label})
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)
	return ok


func _contract(id: String, before: int) -> void:
	contracts[id] = {"executed": true, "status": "PASS" if failures.size() == before else "FAIL"}


func _frames(count := 2) -> void:
	for _i in count:
		await get_tree().process_frame


func _run() -> void:
	started = Time.get_ticks_msec()
	output = OS.get_environment("SHOT_DIR")
	for id: String in REQUIRED:
		contracts[id] = {"executed": false, "status": "NOT_RUN"}
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("SHOT_DIR is required")
		get_tree().quit(2)
		return
	var pilot := OS.get_environment("LOOP_VOICE_PILOT")
	var catalog_path := OS.get_environment("LOOP_VOICE_CATALOG")
	if not _check(FileAccess.file_exists(pilot) and FileAccess.file_exists(catalog_path), "pilot manifest and catalog are given"):
		await _finish()
		return
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(catalog_path)).lines:
		lines[str(row.line_id)] = str(row.text)
	lease = RealityState.begin_preview_campaign(self)
	_check(lease, "exclusive nonpersistent preview")
	panel = CaseDialoguePanel.new()
	add_child(panel)
	director = ResidentConversations.new()
	add_child(director)
	director.setup(panel)
	player = Node3D.new()
	add_child(player)
	evelyn = StubResident.new()
	evelyn.resident_id = "evelyn_marsh"
	evelyn.cast_body = StubBody.new()
	evelyn.add_child(evelyn.cast_body)
	evelyn.add_to_group("animated_residents")
	add_child(evelyn)
	var bus := AudioServer.get_bus_index(&"Dialogue")
	var bus_before := [AudioServer.get_bus_volume_db(bus), AudioServer.is_bus_mute(bus)] if bus >= 0 else []

	# 1. Quiet fallback: the released (empty) manifest, a missing one and a malformed one each play nothing,
	# and the performance still advances and ends.
	var before := failures.size()
	var broken := output.path_join("broken_manifest.json")
	var file := FileAccess.open(broken, FileAccess.WRITE)
	file.store_string("{\"schema_version\": 1, \"entries\": [{\"owner_resident_id\": \"evelyn_marsh\", \"text_sha256\": \"nothex\"}]}")
	file.close()
	for manifest: String in [LoopVoiceManifest.RELEASE, output.path_join("missing.json"), broken]:
		var quiet := await _voice(manifest)
		_check(quiet.manifest.count() == 0, "no takes from " + manifest.get_file())
		_check(await _perform(["loop_profile_evelyn_marsh__loop_business"]), "performance starts with " + manifest.get_file())
		panel.choose(panel.offered_labels().size() - 1)
		await _frames()
		_check(not director.performance_active() and _plays(quiet) == 0, "quiet fallback: nothing plays and the line ends (%s)" % manifest.get_file())
		quiet.queue_free()
		await _frames()
	_check(not LoopVoiceManifest.load_from(broken).errors.is_empty(), "a malformed manifest is refused whole")
	_contract("quiet_fallback", before)

	voice = await _voice(pilot)
	_check(voice.manifest.count() == 5, "the five packed Evelyn takes load (%d)" % voice.manifest.count())

	# 2. Exact binding: actor and the exact line's digest, nothing else.
	before = failures.size()
	var line: String = lines["loop_profile_evelyn_marsh__loop_business"]
	_check(not voice.manifest.take_for("evelyn_marsh", line).is_empty(), "Evelyn's exact line finds its take")
	_check(voice.manifest.take_for("evelyn_marsh", line + " ").is_empty() and voice.manifest.take_for("evelyn_marsh", line.replace("correction", "corection")).is_empty(),
			"a one-character change finds no take")
	_check(voice.manifest.take_for("mae_kessler", line).is_empty(), "the same words from another resident find no take")
	_contract("exact_binding", before)

	# 3. Playback on the line, face on the audio's clock.
	before = failures.size()
	var body: StubBody = evelyn.cast_body
	body.calls.clear()
	_check(await _perform(["loop_profile_evelyn_marsh__loop_business"]), "Evelyn's performed line opens")
	_check(_plays(voice) == 1, "her take plays on the node that shows it")
	_check(voice._player.bus == (&"Dialogue" if bus >= 0 else &"Master"), "the take plays on the Dialogue bus")
	now = 1.25
	await _frames()
	_check(body.calls.has("cues:%d" % _cue_count(voice)) and is_equal_approx(body.face._speech_clock, 1.25),
			"her mouth gets the aligned cues and stands at the audio's position (%.2f s)" % body.face._speech_clock)
	now = 2.5
	await _frames()
	_check(is_equal_approx(body.face._speech_clock, 2.5), "the mouth follows the audio clock, not its own")
	panel.choose(panel.offered_labels().size() - 1)
	await _frames()
	_check(_last_stop(voice) == "tree_ended" and not voice.playing() and body.calls.has("stop"), "leaving ends the take and the mouth")
	_contract("audio_clock_face", before)

	# 4. The same speaker's next line: the first take stops and the second binds; the mouth is not stopped by us.
	before = failures.size()
	_reset(voice)
	_check(await _perform(["loop_profile_evelyn_marsh__loop_business", "loop_profile_evelyn_marsh__activity_rounds"]), "two Evelyn lines in one performance")
	var first := _plays(voice)
	body.calls.clear()
	panel.choose(0)
	await _frames(3)
	_check(_stops(voice).has("node_changed") and _plays(voice) == first + 1 and not body.calls.has("stop"),
			"her next line replaces the take without stopping the mouth")
	panel.choose(panel.offered_labels().size() - 1)
	await _frames()
	_contract("same_speaker_next", before)

	# 5. A speaker switch inside an exchange: Evelyn, then Peter (no take: silence), then Evelyn again.
	before = failures.size()
	_reset(voice)
	_check(await _perform(["loop_exchange_oy01__loop_business", "loop_exchange_oy01__loop_business_1", "loop_exchange_oy01__loop_business_2"]),
			"the OY01 exchange opens")
	panel.choose(0)
	await _frames(3)
	_check(not voice.playing() and _stops(voice).has("node_changed") and _plays(voice) == 1, "Peter's line, which has no take, is silent")
	panel.choose(0)
	await _frames(3)
	_check(_plays(voice) == 2, "Evelyn's next line in the exchange plays")
	panel.choose(panel.offered_labels().size() - 1)
	await _frames()
	_contract("speaker_switch", before)

	# 6. A foreign tree replaces the node.
	before = failures.size()
	_reset(voice)
	await _perform(["loop_profile_evelyn_marsh__loop_business"])
	panel.run_tree({"nodes": {"other": {"speaker": "Other", "line": "Another owner.", "choices": [{"label": "Continue."}]}}}, "other", Callable())
	await _frames()
	_check(not voice.playing() and _last_stop(voice) in ["tree_replaced", "node_changed"], "a foreign tree stops the take (%s)" % _last_stop(voice))
	panel.close()
	panel._end_tree()
	director.cancel_for_transition()
	await _frames()
	_contract("foreign_replacement", before)

	# 6b. A line that turns silent (the panel's authored silent delivery) stops the take at once.
	before = failures.size()
	_reset(voice)
	await _perform(["loop_profile_evelyn_marsh__loop_business"])
	var was_playing := _plays(voice) == 1
	panel._line_delivery = "silent"
	await _frames()
	_check(was_playing and not voice.playing() and _last_stop(voice) == "silent" and str(panel.displayed_line().get("delivery")) == "silent",
			"silent delivery stops a playing take (%s)" % _last_stop(voice))
	panel._line_delivery = "spoken"
	panel.choose(panel.offered_labels().size() - 1)
	await _frames()
	_contract("silent_delivery", before)

	# 7. Immediate exit.
	before = failures.size()
	_reset(voice)
	await _perform(["loop_profile_evelyn_marsh__loop_business"])
	panel.choose(panel.offered_labels().size() - 1)
	await _frames()
	_check(not voice.playing() and _last_stop(voice) == "tree_ended", "leaving at once stops the take")
	_contract("immediate_exit", before)

	# 8. A loaded save (a new campaign document).
	before = failures.size()
	_reset(voice)
	await _perform(["loop_profile_evelyn_marsh__loop_business"])
	var lease_data: Dictionary = RealityState.data
	RealityState.data = lease_data.duplicate(true)
	await _frames()
	_check(not voice.playing() and _last_stop(voice) == "state_loaded", "a loaded save stops the take")
	RealityState.data = lease_data
	director.cancel_for_transition()
	await _frames()
	_contract("state_loaded", before)

	# 9. Continue: the runtime tree goes away under a playing take.
	before = failures.size()
	_reset(voice)
	await _perform(["loop_profile_evelyn_marsh__loop_business"])
	var log: Array[Dictionary] = voice.events
	remove_child(voice)
	_check(log.back().get("reason") == "exit_tree", "leaving the scene stops the take")
	voice.free()
	director.cancel_for_transition()
	await _frames()
	_contract("continue_exit", before)

	before = failures.size()
	if bus >= 0:
		_check([AudioServer.get_bus_volume_db(bus), AudioServer.is_bus_mute(bus)] == bus_before, "the Dialogue bus volume and mute are untouched")
	else:
		_check(true, "no Dialogue bus in this project run; the take used Master")
	_contract("bus_stable", before)
	await _finish()


func _cue_count(node: LoopVoicePlayback) -> int:
	var take := node.manifest.take_for("evelyn_marsh", lines["loop_profile_evelyn_marsh__loop_business"])
	return LoopVoicePlayback.Face.load_cues(str(take.cues)).size()


func _voice(manifest: String) -> LoopVoicePlayback:
	var node := LoopVoicePlayback.new()
	add_child(node)
	node.clock_source = func() -> float: return now
	node.setup(director, null, manifest)
	await _frames(1)
	return node


func _perform(ids: Array) -> bool:
	now = 0.0
	var rows: Array = []
	for id: String in ids:
		var speaker := "peter_wren" if "__loop_business_1" in id or "__loop_business_3" in id else "evelyn_marsh"
		rows.append({"speaker": speaker, "text": lines[id]})
	var ok := director.start_performance_sequence(str(rows[0].speaker), rows, player)
	await _frames(3)
	return ok


func _reset(node: LoopVoicePlayback) -> void:
	node.events.clear()


func _plays(node: LoopVoicePlayback) -> int:
	return node.events.filter(func(e: Dictionary) -> bool: return e.event == "play").size()


func _stops(node: LoopVoicePlayback) -> Array:
	return node.events.filter(func(e: Dictionary) -> bool: return e.event == "stop").map(func(e: Dictionary) -> String: return str(e.reason))


func _last_stop(node: LoopVoicePlayback) -> String:
	var all := _stops(node)
	return str(all.back()) if not all.is_empty() else ""


func _finish() -> void:
	if is_instance_valid(director):
		director.cancel_for_transition()
	if lease:
		_check(RealityState.end_preview_campaign(self), "preview returned")
	for id: String in REQUIRED:
		_check(bool(contracts[id].executed) and str(contracts[id].status) == "PASS", "required contract " + id)
	var passed := failures.is_empty()
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "production_runtime": false, "selector": "v2",
			"suite": "LoopVoicePlaybackTest", "status": "PASS" if passed else "FAIL",
			"scope": "Real conversation director and panel with authored trees; five packed Evelyn pilot takes injected from the external case; stub cast body and injected clock. No in-world body, render, audible check, or artistic or audio-quality acceptance.",
			"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
			"source": {"test_path": "game/" + get_script().resource_path.trim_prefix("res://"), "test_sha256": FileAccess.get_sha256(get_script().resource_path),
					"pilot_manifest": OS.get_environment("LOOP_VOICE_PILOT"), "pilot_manifest_sha256": FileAccess.get_sha256(OS.get_environment("LOOP_VOICE_PILOT"))},
			"contracts": contracts, "checks": checks, "failures": failures, "details": details}
	var out := FileAccess.open(output.path_join("runtime_contract.json"), FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(result, "\t"))
		out.close()
	print("[LOOP VOICE PLAYBACK] RESULT: %s (%d checks, %d failures)" % ["PASS" if passed else "FAIL", checks.size(), failures.size()])
	get_tree().quit(0 if passed else 1)
