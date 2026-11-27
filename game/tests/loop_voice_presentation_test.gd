extends Node3D
## Loop voice mouth timing at frame production and at presentation (Codex's #603 hitch, 2026-11-27). The actual
## V2 runtime with its own LoopVoicePlayback on a pinned pilot manifest, Evelyn's real routed body, the player
## standing in front of her. OY01 is opened through the real conversation director as soon as she is in view
## (a cold first exchange) and again after it ends (a warm one). Each frame is stamped three times:
##   seek   - LoopVoicePlayback sets her face's speech clock (frame production);
##   late   - the last node to process in that frame (any script stall after the seek);
##   drawn  - RenderingServer.frame_post_draw (presentation), with the pipeline compilation counters.
## The audible clock is read again at presentation, as the mailbox probe read it. A frame whose seek-to-drawn
## gap is long is a presentation stall; a face clock behind the audio at its own seek is drift. Both are
## reported; the presentation gate stays 0.12 s. Her mouth's blend weights must visibly move. Run windowed
## under the Dummy audio driver. Pilot paths are injected (ORISON_LOOP_VOICE_MANIFEST, LOOP_VOICE_PILOT_SHA256).
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const OY01 := "OY01"
const LISTEN_DISTANCE := 1.8
const SCAN_DATE := [1929, 3, 12]
const GATE := .12
const STALL := .1
const PIPELINES := {
	"canvas": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS,
	"mesh": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
	"surface": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,
	"draw": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
	"specialization": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION,
}

## Stamps the end of each frame's process step; runs after every other node.
class LateStamp extends Node:
	var rows: Array[Dictionary] = []
	var active := false
	var face: Object
	func _init() -> void:
		process_priority = 1 << 30
	func _process(_delta: float) -> void:
		if active:
			rows.append({"frame": Engine.get_process_frames(), "late_usec": Time.get_ticks_usec(),
					"face": float(face.get("_speech_clock")) if face != null else -1.0,
					"driven": bool(face.get("_audio_drives_speech")) if face != null else false})

var world: OrisonV2RuntimeRoot
var voice: LoopVoicePlayback
var late: LateStamp
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var details: Dictionary = {"runs": []}
var output := ""
var started := 0
var lease := false
var prior_frozen := false
var prior_mode := 0


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
	_check(DisplayServer.get_name() != "headless", "a rendering display, so presentation is real (%s)" % DisplayServer.get_name())
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
	if not _check(voice != null and voice.manifest.count() > 0, "the runtime's own playback loaded the pilot"):
		await _finish()
		return
	voice.diagnostics = true
	var minute := -1
	for m in range(420, 1320, 5):
		world.campaign_clock.configure_date(SCAN_DATE[0], SCAN_DATE[1], SCAN_DATE[2], m)
		if str(world.resident_whereabouts("evelyn_marsh").get("place", "")) in ["lobby", "mail_bank"]:
			minute = m
			break
	if not _check(minute >= 0, "Evelyn has a lobby or mail-bank minute (%d)" % minute):
		await _finish()
		return
	world.campaign_clock.configure_date(SCAN_DATE[0], SCAN_DATE[1], SCAN_DATE[2], minute)
	world.campaign_clock.bind_state()
	var lobby: Dictionary = world.layout.spaces.filter(func(row: Dictionary) -> bool: return row.id == "F01_LOBBY")[0]
	var rect: Array = lobby.rect
	world.player.global_position = world.adapter.root.to_global(Vector3((rect[0] + rect[2]) * .5, .025, (rect[1] + rect[3]) * .5))
	var evelyn := await _body("evelyn_marsh", 120.0)
	if not _check(evelyn != null, "Evelyn's real routed body is in the world"):
		await _finish()
		return
	var face: Object = evelyn.get("face")
	if not _check(face != null and face.has_method("seek_speech"), "her face controller follows an audio clock"):
		await _finish()
		return
	_check(voice.process_priority < (face as Node).process_priority,
			"playback seeks before her face steps in the same frame (%d < %d)" % [voice.process_priority, (face as Node).process_priority])
	var stand: Variant = _listening_place(evelyn)
	if not _check(stand != null, "a clear standing place %.1f m from her" % LISTEN_DISTANCE):
		await _finish()
		return
	world.player.global_position = stand
	world.player.camera.make_current()
	await get_tree().physics_frame
	world.player.camera.look_at(evelyn.global_position + Vector3.UP * 1.55, Vector3.UP)
	late = LateStamp.new()
	late.face = face
	add_child(late)
	RenderingServer.frame_post_draw.connect(_drawn)
	# Cold: the exchange opens on the second frame she is in view. Warm: the same exchange again.
	await get_tree().process_frame
	await get_tree().process_frame
	for label: String in ["cold", "warm"]:
		var run := await _perform(label, face)
		details.runs.append(run)
		await get_tree().create_timer(1.0).timeout
	RenderingServer.frame_post_draw.disconnect(_drawn)
	await _finish()


func _drawn() -> void:
	if late == null or not late.active or late.rows.is_empty():
		return
	var row: Dictionary = late.rows[-1]
	if row.has("drawn_usec"):
		return
	row.drawn_usec = Time.get_ticks_usec()
	row.drawn_frame = Engine.get_process_frames()
	# Audio-driven faces can resample after LateStamp, just before submission.
	row.face_at_drawn = float(late.face.get("_speech_clock"))
	var raw := 0.0
	if voice.playing():
		raw = maxf(0.0, voice._player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())
	row.audible_at_drawn = raw if voice.playing() else -1.0
	row.mixer_at_drawn = voice._player.get_playback_position() if voice.playing() else -1.0
	var compiled := {}
	for key: String in PIPELINES:
		compiled[key] = RenderingServer.get_rendering_info(PIPELINES[key])
	row.pipelines = compiled
	row.texture_mem = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	row.buffer_mem = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)


func _perform(label: String, face: Object) -> Dictionary:
	var encounter := _oy01()
	var rows: Array = []
	for line: Dictionary in encounter.get("lines", []):
		rows.append({"speaker": str(line.speaker), "text": str(line.text)})
	voice.frames.clear()
	late.rows.clear()
	late.active = true
	var run := {"label": label}
	if not _check(world.conversations.start_performance_sequence("evelyn_marsh", rows, world.player), label + ": the OY01 exchange opens with her"):
		late.active = false
		return run
	var panel: CaseDialoguePanel = world.conversations.dialogue
	var excursion := {}
	var moved := 0.0
	for i in rows.size():
		await get_tree().process_frame
		var take := voice.manifest.take_for(str(rows[i].speaker), str(rows[i].text))
		var deadline := Time.get_ticks_msec() + int((float(take.get("seconds", 0.0)) + 1.5) * 1000.0)
		while Time.get_ticks_msec() < deadline:
			await RenderingServer.frame_post_draw
			if voice.playing() and str(rows[i].speaker) == "evelyn_marsh":
				for shape: String in face.get("_mouth"):
					for target: Array in face.targets.get(shape, []):
						var mesh := target[0] as MeshInstance3D
						if not mesh.is_visible_in_tree():
							continue
						var key := str(mesh.get_instance_id()) + "/" + shape
						var weight := mesh.get_blend_shape_value(int(target[1]))
						var span: Vector2 = excursion.get(key, Vector2(weight, weight))
						span = Vector2(minf(span.x, weight), maxf(span.y, weight))
						excursion[key] = span
						moved = maxf(moved, span.y - span.x)
			if not take.is_empty() and not voice.playing() and Time.get_ticks_msec() > deadline - 1200:
				break
		await get_tree().create_timer(.3).timeout
		if i + 1 < rows.size():
			panel.choose(0)
	panel.choose(panel.offered_labels().size() - 1)
	await get_tree().process_frame
	late.active = false
	return _measure(label, run, moved)


## Joins the seek rows (production) with the late and drawn stamps of the same frame.
func _measure(label: String, run: Dictionary, moved: float) -> Dictionary:
	var by_frame := {}
	for row: Dictionary in late.rows:
		by_frame[int(row.frame)] = row
	var samples: Array = []
	var worst_drawn := 0.0
	var worst_seek := 0.0
	var stalls: Array = []
	var prev_drawn := -1
	var frame_gaps: Array = []
	for row: Dictionary in late.rows:
		if row.has("drawn_usec"):
			if prev_drawn >= 0:
				frame_gaps.append((int(row.drawn_usec) - prev_drawn) / 1e6)
			prev_drawn = int(row.drawn_usec)
	for seek: Dictionary in voice.frames:
		if str(seek.actor) != "evelyn_marsh":
			continue
		var frame: Dictionary = by_frame.get(int(seek.frame), {})
		if frame.is_empty() or not frame.has("drawn_usec") or float(frame.audible_at_drawn) < 0.0:
			continue
		var clock := float(seek.clock)
		var face_clock := float(frame.face)
		if not bool(frame.driven) or clock < .04 or face_clock < clock - .0005:
			continue # Not yet driven, or held at the end of her cues.
		var script_gap := (int(frame.late_usec) - int(seek.usec)) / 1e6
		var render_gap := (int(frame.drawn_usec) - int(frame.late_usec)) / 1e6
		var drawn_error := absf(float(frame.audible_at_drawn) - float(frame.face_at_drawn))
		var seek_error := absf(face_clock - clock)
		worst_drawn = maxf(worst_drawn, drawn_error)
		worst_seek = maxf(worst_seek, seek_error)
		var sample := {"frame": seek.frame, "clock_at_seek": clock, "face": face_clock, "face_at_drawn": frame.face_at_drawn, "audible_at_drawn": frame.audible_at_drawn,
				"mixer_at_drawn": frame.mixer_at_drawn, "script_gap": script_gap, "render_gap": render_gap, "drawn_error": drawn_error}
		samples.append(sample)
		if script_gap + render_gap > STALL or drawn_error > GATE:
			var row := sample.duplicate()
			row.pipelines = frame.pipelines
			row.texture_mem = frame.texture_mem
			row.buffer_mem = frame.buffer_mem
			var before: Dictionary = by_frame.get(int(seek.frame) - 1, {})
			if before.has("pipelines"):
				var grew := {}
				for key: String in PIPELINES:
					grew[key] = int(frame.pipelines[key]) - int(before.pipelines[key])
				row.pipelines_added = grew
				row.texture_mem_added = int(frame.texture_mem) - int(before.texture_mem)
			stalls.append(row)
	frame_gaps.sort()
	run.merge({"samples": samples.size(), "worst_error_at_presentation": worst_drawn, "worst_error_at_seek": worst_seek,
			"stalls": stalls, "visible_shape_range": moved, "frames": late.rows.size(),
			"frame_gap_median": frame_gaps[frame_gaps.size() / 2] if not frame_gaps.is_empty() else 0.0,
			"frame_gap_max": frame_gaps[-1] if not frame_gaps.is_empty() else 0.0, "clock_samples": samples})
	_check(samples.size() > 20, label + ": her audio-driven frames were stamped at seek and at presentation (%d)" % samples.size())
	_check(moved > .015, label + ": her visible mouth meshes move (%.3f)" % moved)
	_check(worst_seek < .001, label + ": at production her face holds the audio clock (worst %.4f s)" % worst_seek)
	_check(stalls.is_empty(), label + ": no presentation stall over %.2f s during her speech (%d)" % [STALL, stalls.size()])
	_check(worst_drawn <= GATE, label + ": at presentation her mouth is within %.2f s of the audio (worst %.3f s)" % [GATE, worst_drawn])
	return run


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
			"suite": "LoopVoicePresentationTest", "status": "PASS" if passed else "FAIL",
			"scope": "Actual V2 runtime and its own LoopVoicePlayback on a pinned pilot manifest; Evelyn's real routed body; OY01 through the real director, cold and warm; each speech frame stamped at the face seek, at the end of process and at frame_post_draw with pipeline compilation counters; audible clock re-read at presentation. Windowed, Dummy audio driver. Declared player placement.",
			"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
			"source": {"test_path": "game/" + get_script().resource_path.trim_prefix("res://"), "test_sha256": FileAccess.get_sha256(get_script().resource_path),
					"playback_sha256": FileAccess.get_sha256("res://scripts/audio/loop_voice_playback.gd"),
					"pilot_manifest": OS.get_environment("ORISON_LOOP_VOICE_MANIFEST"), "pilot_manifest_sha256": OS.get_environment("LOOP_VOICE_PILOT_SHA256")},
			"checks": checks, "failures": failures, "details": details}
	var out := FileAccess.open(output.path_join("runtime_contract.json"), FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(result, "\t"))
		out.close()
	print("[LOOP VOICE PRESENTATION] RESULT: %s (%d checks, %d failures)" % ["PASS" if passed else "FAIL", checks.size(), failures.size()])
	get_tree().quit(0 if passed else 1)
