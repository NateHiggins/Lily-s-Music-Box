extends Node3D
## Loop voice in the installed world, heard (doc408; Codex's request 2026-11-26). The actual V2 runtime with its
## own LoopVoicePlayback bound to a pinned pilot manifest (ORISON_LOOP_VOICE_MANIFEST), Evelyn's real routed body
## and room ambience, the player standing at an ordinary conversational distance looking at her. The OY01
## exchange is performed through the real conversation director; its Evelyn lines play through the Dialogue bus.
## The Master bus is recorded to a WAV for Lily's listening, with a timeline of each line's start and end, and
## Evelyn's face speech clock is sampled every frame against the AudioStreamPlayer's own position. Run with the
## Dummy audio driver: nothing reaches the owner's speakers. No judgement of intelligibility is made here; the
## WAV and its measured levels are for a listener. Pilot paths are injected (ORISON_LOOP_VOICE_MANIFEST,
## LOOP_VOICE_PILOT_SHA256, LOOP_VOICE_EXPECT_PETER_TAKES); nothing private is committed.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const OY01 := "OY01"
const LISTEN_DISTANCE := 1.8
const SCAN_DATE := [1929, 3, 12]

var world: OrisonV2RuntimeRoot
var voice: LoopVoicePlayback
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var details: Dictionary = {"timeline": [], "face_samples": [], "lines": []}
var output := ""
var started := 0
var lease := false
var prior_frozen := false
var prior_mode := 0
var record: AudioEffectRecord
var record_index := -1
var record_started_ms := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "label": label})
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)
	return ok


func _run() -> void:
	started = Time.get_ticks_msec()
	output = OS.get_environment("SHOT_DIR")
	var manifest := OS.get_environment("ORISON_LOOP_VOICE_MANIFEST")
	var pin := OS.get_environment("LOOP_VOICE_PILOT_SHA256").to_lower()
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("SHOT_DIR is required")
		get_tree().quit(2)
		return
	_check(AudioServer.get_driver_name() == "Dummy", "Dummy audio driver: nothing reaches the speakers (%s)" % AudioServer.get_driver_name())
	if not _check(FileAccess.file_exists(manifest) and FileAccess.get_sha256(manifest) == pin, "the pinned pilot manifest"):
		await _finish()
		return
	lease = RealityState.begin_preview_campaign(self)
	if not _check(lease, "exclusive nonpersistent campaign preview"):
		await _finish()
		return
	prior_frozen = CampaignTime._frozen_for_tests
	prior_mode = GameBoot.launch_mode
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	_check(CampaignClock.new().configure_date(SCAN_DATE[0], SCAN_DATE[1], SCAN_DATE[2], 600), "a civil weekday")
	world = Runtime.instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not _check(not world.startup_failed and world.player != null, "complete actual runtime composition"):
		await _finish()
		return
	voice = world.get_node_or_null("LoopVoicePlayback") as LoopVoicePlayback
	if not _check(voice != null and voice.manifest.count() > 0, "the runtime's own playback loaded the pilot (%d takes)" % (voice.manifest.count() if voice != null else 0)):
		await _finish()
		return
	voice.diagnostics = true

	# A minute when Evelyn is in the lobby or at the mail bank (OY01's places), her real body present.
	var minute := -1
	for m in range(420, 1320, 5):
		world.campaign_clock.configure_date(SCAN_DATE[0], SCAN_DATE[1], SCAN_DATE[2], m)
		if str(world.resident_whereabouts("evelyn_marsh").get("place", "")) in ["lobby", "mail_bank"]:
			minute = m
			break
	if not _check(minute >= 0, "Evelyn has a lobby or mail-bank minute on %s (%d)" % [str(SCAN_DATE), minute]):
		await _finish()
		return
	world.campaign_clock.configure_date(SCAN_DATE[0], SCAN_DATE[1], SCAN_DATE[2], minute)
	world.campaign_clock.bind_state()
	details.minute = minute
	# Stand in the lobby, where her body is routed and streamed, and wait for her to be there.
	var lobby: Dictionary = world.layout.spaces.filter(func(row: Dictionary) -> bool: return row.id == "F01_LOBBY")[0]
	var rect: Array = lobby.rect
	world.player.global_position = world.adapter.root.to_global(Vector3((rect[0] + rect[2]) * .5, .025, (rect[1] + rect[3]) * .5))
	var evelyn := await _body("evelyn_marsh", 120.0)
	details.evelyn_bodies = []
	for actor: Node in get_tree().get_nodes_in_group("animated_residents"):
		if actor is Node3D and str(actor.get("resident_id")) == "evelyn_marsh":
			details.evelyn_bodies.append({"path": str(actor.get_path()), "at": str((actor as Node3D).global_position),
					"visible": (actor as Node3D).is_visible_in_tree(), "cast_body": actor.get("cast_body") != null})
	details.evelyn_whereabouts = world.resident_whereabouts("evelyn_marsh")
	if not _check(evelyn != null, "Evelyn's real routed body is in the world"):
		await _finish()
		return
	var face: Object = evelyn.get("face")
	_check(face != null and face.has_method("seek_speech"), "her face controller follows an audio clock")

	# The player at an ordinary distance, looking at her.
	var stand: Variant = _listening_place(evelyn)
	if not _check(stand != null, "a clear standing place %.1f m from her" % LISTEN_DISTANCE):
		await _finish()
		return
	world.player.global_position = stand
	await get_tree().physics_frame
	world.player.camera.look_at(evelyn.global_position + Vector3.UP * 1.55, Vector3.UP)
	details.player_at = stand
	details.evelyn_at = evelyn.global_position
	details.listen_distance = (stand as Vector3).distance_to(evelyn.global_position)

	# Record the game mix from the Master bus: ambience first, then the exchange.
	var master := AudioServer.get_bus_index(&"Master")
	record = AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(master, record)
	record_index = AudioServer.get_bus_effect_count(master) - 1
	record.set_recording_active(true)
	record_started_ms = Time.get_ticks_msec()
	_mark("ambience_start")
	await get_tree().create_timer(3.0).timeout
	_mark("ambience_end")

	var encounter := _oy01()
	var rows: Array = []
	for line: Dictionary in encounter.get("lines", []):
		rows.append({"speaker": str(line.speaker), "text": str(line.text), "choice": str(line.get("choice", "Listen."))})
	if not _check(world.conversations.start_performance_sequence("evelyn_marsh", rows, world.player), "the OY01 exchange opens with her"):
		await _finish()
		return
	var panel: CaseDialoguePanel = world.conversations.dialogue
	for i in rows.size():
		await get_tree().physics_frame
		await get_tree().process_frame
		var shown := str(panel.displayed_line().get("text", ""))
		var take := voice.manifest.take_for(str(rows[i].speaker), str(rows[i].text))
		var row := {"index": i, "speaker": rows[i].speaker, "text": rows[i].text, "shown": shown == str(rows[i].text),
				"has_take": not take.is_empty(), "seconds": float(take.get("seconds", 0.0))}
		_mark("line_%d_shown" % i)
		var deadline := Time.get_ticks_msec() + int((float(take.get("seconds", 0.0)) + 1.5) * 1000.0)
		while Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			if voice.playing() and str(rows[i].speaker) == "evelyn_marsh":
				var audio_at := voice._player.get_playback_position()
				details.face_samples.append({"line": i, "audio": audio_at, "face": float(face.get("_speech_clock"))})
			if not take.is_empty() and not voice.playing() and Time.get_ticks_msec() > deadline - 1200:
				break
		row.played = voice.events.any(func(e: Dictionary) -> bool: return e.event == "play" and str(e.get("node", "")) == str(panel.current_node_id))
		details.lines.append(row)
		_mark("line_%d_end" % i)
		await get_tree().create_timer(.6).timeout
		if i + 1 < rows.size():
			panel.choose(0)
	panel.choose(panel.offered_labels().size() - 1)
	await get_tree().create_timer(1.0).timeout
	_mark("exchange_end")
	record.set_recording_active(false)
	var wav := record.get_recording()
	var wav_path := output.path_join("oy01_game_mix.wav")
	if _check(wav != null and wav.save_to_wav(wav_path) == OK, "the game mix is saved for listening"):
		details.wav = {"path": wav_path, "sha256": FileAccess.get_sha256(wav_path), "mix_rate": wav.mix_rate, "stereo": wav.stereo}

	# Evelyn's lines played on her body; her mouth tracked the advancing audio clock.
	var evelyn_lines: Array = details.lines.filter(func(r: Dictionary) -> bool: return r.speaker == "evelyn_marsh")
	_check(not evelyn_lines.is_empty() and evelyn_lines.all(func(r: Dictionary) -> bool: return r.shown and r.has_take and r.played),
			"each of Evelyn's three lines is shown and plays its take")
	# Whatever the cohort holds: a line with a take plays it (Peter's handoff in the 39-take cohort), a line
	# without one stays silent (Peter in the 27-take cohort).
	_check(details.lines.all(func(r: Dictionary) -> bool: return r.shown and bool(r.played) == bool(r.has_take)),
			"every line with a take plays it and every line without one is silent")
	details.peter_takes = details.lines.filter(func(r: Dictionary) -> bool: return r.speaker == "peter_wren" and r.has_take).size()
	var expected_peter := OS.get_environment("LOOP_VOICE_EXPECT_PETER_TAKES")
	if not expected_peter.is_empty():
		_check(int(details.peter_takes) == int(expected_peter), "the cohort's Peter takes (%d of %s)" % [details.peter_takes, expected_peter])
	var quiet: Array = details.lines.filter(func(r: Dictionary) -> bool: return r.text == "On the back.")
	_check(quiet.size() == 1 and bool(quiet[0].played), "\"On the back.\" plays in the installed world")
	var worst := 0.0
	var advancing := 0
	var last := -1.0
	for sample: Dictionary in details.face_samples:
		if float(sample.face) >= 0.0:
			worst = maxf(worst, absf(float(sample.face) - float(sample.audio)))
		if float(sample.audio) > last:
			advancing += 1
		last = float(sample.audio)
	details.face_audio_max_error_s = worst
	details.face_sample_count = details.face_samples.size()
	_check(details.face_samples.size() > 20 and advancing > 10, "the audio clock advanced through her lines (%d samples)" % details.face_samples.size())
	_check(worst < .12, "her mouth stayed within 0.12 s of the audio position (worst %.3f s)" % worst)
	await _finish()


func _mark(label: String) -> void:
	details.timeline.append({"label": label, "seconds": (Time.get_ticks_msec() - record_started_ms) / 1000.0})


func _oy01() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/temporal/ordinary_performances.json"))
	for encounter: Dictionary in data.get("encounters", []):
		if str(encounter.id) == OY01:
			return encounter
	return {}


func _body(id: String, seconds: float) -> Node3D:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		for actor: Node in get_tree().get_nodes_in_group("animated_residents"):
			if actor is Node3D and str(actor.get("resident_id")) == id and (actor as Node3D).is_visible_in_tree():
				var body: Node3D = actor if actor.has_method("speak_cues") else actor.get("cast_body")
				if is_instance_valid(body) and body.is_visible_in_tree():
					return body
		await get_tree().create_timer(.25).timeout
	return null


func _listening_place(person: Node3D) -> Variant:
	var space := get_world_3d().direct_space_state
	var head := person.global_position + Vector3.UP * 1.55
	for turn in 24:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * turn / 24.0)
		var origin := person.global_position + direction * LISTEN_DISTANCE + Vector3.UP * 1.0
		var floor := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin - Vector3.UP * 3.0, 1, [world.player.get_rid()]))
		if floor.is_empty() or floor.normal.y < .85 or absf(floor.position.y - person.global_position.y) > .3:
			continue
		var capsule := CapsuleShape3D.new()
		capsule.radius = .43
		capsule.height = 1.72
		var clearance := PhysicsShapeQueryParameters3D.new()
		clearance.shape = capsule
		clearance.collision_mask = 1
		clearance.exclude = [world.player.get_rid()]
		clearance.transform.origin = floor.position + Vector3.UP * .885
		if not space.intersect_shape(clearance, 1).is_empty():
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(floor.position + Vector3.UP * 1.6, head, 1, [world.player.get_rid()]))
		if hit.is_empty() or (hit.collider is Node and person.is_ancestor_of(hit.collider)):
			return floor.position
	return null


func _finish() -> void:
	if record_index >= 0:
		AudioServer.remove_bus_effect(AudioServer.get_bus_index(&"Master"), record_index)
	if is_instance_valid(world):
		world.conversations.cancel_for_transition()
		world.shutdown_for_tests()
		world.free()
	if lease:
		_check(RealityState.end_preview_campaign(self), "preview returned")
	CampaignTime.set_frozen_for_tests(prior_frozen)
	GameBoot.launch_mode = prior_mode
	var passed := failures.is_empty()
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "production_runtime": true, "selector": "v2",
			"suite": "LoopVoiceWorldMixTest", "status": "PASS" if passed else "FAIL",
			"scope": "Actual V2 runtime and its own LoopVoicePlayback on a pinned pilot manifest; Evelyn's real routed body and room ambience; OY01 performed through the real director; Master bus recorded under the Dummy driver; face speech clock sampled against the player position. Declared player placement. No intelligibility judgement; the WAV is for a listener.",
			"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
			"source": {"test_path": "game/" + get_script().resource_path.trim_prefix("res://"), "test_sha256": FileAccess.get_sha256(get_script().resource_path),
					"pilot_manifest": OS.get_environment("ORISON_LOOP_VOICE_MANIFEST"), "pilot_manifest_sha256": OS.get_environment("LOOP_VOICE_PILOT_SHA256")},
			"checks": checks, "failures": failures, "details": details}
	var out := FileAccess.open(output.path_join("runtime_contract.json"), FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(result, "\t"))
		out.close()
	print("[LOOP VOICE WORLD MIX] RESULT: %s (%d checks, %d failures)" % ["PASS" if passed else "FAIL", checks.size(), failures.size()])
	get_tree().quit(0 if passed else 1)
