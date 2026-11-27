class_name LoopVoicePlayback
extends Node
## Plays an approved take for a performed loop line (loop voice pilot, doc408; Codex's runtime handoff
## 2026-11-26). It owns one AudioStreamPlayer on the Dialogue bus and nothing in the dialogue: it never closes,
## chooses, cancels or writes to the panel, and every failure path is silence.
##
## A take binds when a `loop_business` node of the active performance tree is shown, by the speaking resident
## and the SHA-256 of the exact line on screen (LoopVoiceManifest). The assembled line's audio is the clock: a
## speaker's face is given the aligned mouth cues and kept at the audio's own playback position, and an A/B line
## (one file with timed speaker segments) moves each body's mouth only inside its own segment. Bodies without a
## cast face (the transient guests) are heard only.
##
## Playback stops when the player advances or leaves, another tree or a standalone prompt replaces the node, the
## line turns silent (displayed_line().delivery == "silent"), the visit, phase or day changes, a save is loaded,
## or the scene goes (Continue). It is checked every frame and on each of those signals.

signal played(take: Dictionary)
signal stopped(reason: String)

const BUS := &"Dialogue"
const Face := preload("res://scripts/characters/face_controller.gd")

var manifest: LoopVoiceManifest
var conversations: Node
var loop: Node
## Test seam: turns an audio path into a stream. Defaults to the project loader or an .ogg read from disk.
var stream_loader: Callable
## Test seam: the playback clock in seconds. Defaults to the player's own position.
var clock_source: Callable
## Diagnostics are off in the game. A fixture turns them on to read what happened, in order:
## {"event": "play"|"stop"|"face", ...}, keeping only the last EVENT_LIMIT entries.
var diagnostics := false
var events: Array[Dictionary] = []
const EVENT_LIMIT := 64
## With diagnostics on, one row per frame a face was seeked: when the frame was produced (the seek) and the
## clock then, so a fixture can compare it with the same frame's presentation. Last FRAME_LIMIT rows only.
var frames: Array[Dictionary] = []
const FRAME_LIMIT := 512
## Runs before the faces it seeks, so each face steps on this frame's clock rather than the last one's.
const PRIORITY := -100

var _player: AudioStreamPlayer
var _panel: Node
var _take: Dictionary = {}
var _bound := {}
var _faces: Dictionary = {}  # resident id -> {"body": Node, "segment": Dictionary, "on": bool}
var _campaign: Variant = null
var _started_ms := 0
var _bind_pending := false
var _awaiting_draw := false
var _last_clock := 0.0


func _init() -> void:
	process_priority = PRIORITY


func setup(resident_conversations: Node, temporal_loop: Node, manifest_path := LoopVoiceManifest.RELEASE) -> bool:
	if resident_conversations == null or resident_conversations.get("dialogue") == null:
		return false
	conversations = resident_conversations
	loop = temporal_loop
	manifest = LoopVoiceManifest.load_from(manifest_path)
	_panel = conversations.get("dialogue")
	_player = AudioStreamPlayer.new()
	_player.name = "LoopVoice"
	_player.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
	add_child(_player)
	_panel.node_shown.connect(_on_node_shown)
	_panel.tree_ended.connect(func() -> void: stop("tree_ended"))
	if _panel.has_signal("tree_replaced"):
		_panel.tree_replaced.connect(func(_previous: Dictionary) -> void: stop("tree_replaced"))
	conversations.conversation_ended.connect(func(_resident: String) -> void: _check.call_deferred("conversation_ended"))
	if loop != null and loop.has_signal("changed"):
		loop.changed.connect(func() -> void: stop("loop_changed"))
	var state: Node = get_node_or_null("/root/RealityState")
	if state != null and state.has_signal("state_changed"):
		state.state_changed.connect(func(_a: Variant = null, _b: Variant = null) -> void: _check("state_changed"))
	add_to_group("loop_voice_playback")
	return true


func playing() -> bool:
	return not _take.is_empty() and _player != null and _player.playing


## Read-only foreground ownership for background presentation work. Missing or
## silent takes do not reserve it. No bind/start/stop, clock seek or signal
## subscription occurs here; replaced trees and loaded campaigns are rejected.
func has_foreground_take() -> bool:
	if not _bind_pending and not _awaiting_draw and not playing():return false
	var context := _recordable_context()
	if context.is_empty():return false
	if _take.is_empty():return _bind_pending
	return (_awaiting_draw or playing()) and is_same(_bound.get("tree"),context.tree) \
			and str(_bound.get("node",""))==context.node and is_same(_campaign,_reality_data())


func _recordable_context() -> Dictionary:
	if manifest == null or manifest.count() == 0 or not is_instance_valid(conversations) or not is_instance_valid(_panel) \
			or not bool(conversations.get("_performance_active")) or not bool(_panel.call("attention_active")):
		return {}
	var tree: Dictionary = conversations.get("_performance_tree")
	var node_id := str(_panel.get("current_node_id"))
	if not is_same(_panel.get("_tree"), tree) or not node_id.begins_with("loop_business"):
		return {}
	var node: Dictionary = tree.get("nodes", {}).get(node_id, {})
	var actor := str(node.get("actor", ""))
	var line := str(node.get("line", ""))
	var shown: Dictionary = _panel.call("displayed_line")
	if actor.is_empty() or str(shown.get("text", "")) != line or str(shown.get("delivery", "")) == "silent" \
			or line.replace(".", "").strip_edges().is_empty() or _foreign_attention():
		return {}
	var take := manifest.take_for(actor, line)
	if take.is_empty():
		return {}
	for segment: Dictionary in take.segments:
		var span := line.substr(int(segment.get("start_char", 0)), int(segment.get("end_char", 0)) - int(segment.get("start_char", 0)))
		if span.strip_edges().is_empty():
			return {} # A segment that covers no words of this line: the take is not for it.
	return {"tree":tree,"node":node_id,"actor":actor,"text":line,"take":take}


func _on_node_shown(_node_id: String) -> void:
	# The old line ends with its node; faces are left to the conversation's own speech owner, which restarts or
	# ends them on this same signal. The new node may bind its own take once the speaker swap has finished.
	# Several advances before the next idle frame queue a single bind, which reads the panel as it then stands:
	# only the final node can play, and only once.
	if not _take.is_empty():
		stop("node_changed", false)
	if not _bind_pending:
		_bind_pending = true
		_bind.call_deferred()


func _bind() -> void:
	if not _bind_pending: return
	_bind_pending = false
	if not _take.is_empty():
		return
	if manifest == null or manifest.count() == 0 or not bool(conversations.call("performance_active")):
		return
	var context := _recordable_context()
	if context.is_empty(): return
	var tree: Dictionary = context.tree
	var node_id: String = context.node
	var actor: String = context.actor
	var line: String = context.text
	var take: Dictionary = context.take
	var stream: AudioStream = _load_stream(str(take.audio))
	if stream == null:
		return
	_take = take
	_bound = {"tree": tree, "node": node_id, "text": line, "actor": actor}
	_campaign = _reality_data()
	_player.stream = stream
	_start_faces(take, actor)
	_awaiting_draw = true
	if DisplayServer.get_name() == "headless":
		_start_prepared_take()
		return
	RenderingServer.frame_pre_draw.connect(_before_dialogue_draw)


func _before_dialogue_draw() -> void:
	var window := get_window()
	if window == null or not window.can_draw() or (_panel is CanvasLayer and not (_panel as CanvasLayer).visible):
		return
	RenderingServer.frame_pre_draw.disconnect(_before_dialogue_draw)
	RenderingServer.frame_post_draw.connect(_start_prepared_take, CONNECT_ONE_SHOT)


func _start_prepared_take() -> void:
	if _take.is_empty(): return
	if not _valid():
		stop(_why_invalid())
		return
	_awaiting_draw = false
	_started_ms = Time.get_ticks_msec()
	_last_clock = 0.0
	_player.play()
	_note({"event": "play", "actor": _bound.actor, "node": _bound.node, "line_id": _take.line_id})
	played.emit(_take)


func _start_faces(take: Dictionary, actor: String) -> void:
	_faces.clear()
	var cues: Array = Face.load_cues(str(take.cues)) if not str(take.cues).is_empty() else []
	if cues.is_empty():
		return # No aligned cues: the conversation's untimed jaw stays as it was.
	var segments: Array = take.segments if not take.segments.is_empty() else [{"profile_id": actor, "start": 0.0, "end": take.seconds}]
	for segment: Dictionary in segments:
		var who := str(segment.get("profile_id", actor))
		var body := _cast_body(who)
		if body == null:
			continue # Heard only (no cast face for this speaker).
		_faces[who] = {"body": body, "segment": segment, "on": false, "cues": cues}


func _process(_delta: float) -> void:
	if _take.is_empty():
		return
	if not _valid():
		stop(_why_invalid())
		return
	if _awaiting_draw: return
	var at := _clock()
	for who: String in _faces:
		var face_row: Dictionary = _faces[who]
		var body: Node = face_row.body
		if not is_instance_valid(body):
			continue
		var inside := at >= float(face_row.segment.get("start", 0.0)) and at < float(face_row.segment.get("end", INF))
		if inside and not face_row.on:
			body.call("speak_cues", face_row.cues)
			face_row.on = true
			_note({"event": "face", "actor": who, "on": true, "at": at})
		elif not inside and face_row.on:
			body.call("stop_speaking")
			face_row.on = false
			_note({"event": "face", "actor": who, "on": false, "at": at})
		if face_row.on:
			_seek_face(body, at)
			if diagnostics:
				_frame({"frame": Engine.get_process_frames(), "usec": Time.get_ticks_usec(), "actor": who, "clock": at})
	var ended := at >= float(_take.seconds) if float(_take.seconds) > 0.0 else false
	if not clock_source.is_valid() and not _player.playing and Time.get_ticks_msec() - _started_ms > 250:
		ended = true
	if ended:
		stop("finished")


## Keeps the mouth on the audio: the face's speech clock is set to the line's playback position each frame.
func _seek_face(body: Node, at: float) -> void:
	var face: Object = body.get("face")
	if face is Face and not clock_source.is_valid() and DisplayServer.get_name() != "headless":
		(face as Face).seek_speech(at, _clock)
	elif face != null and face.has_method("seek_speech"):
		face.call("seek_speech", at)


## The line's audible position. The mixer advances in whole buffers and the time since the last mix is an
## estimate, so the raw sum can step back when a buffer lands late; a mouth never replays a shape, so the clock
## holds instead of running backwards within a take.
func _clock() -> float:
	if clock_source.is_valid():
		return float(clock_source.call())
	if not _player.playing:
		return 0.0
	var raw := maxf(0.0, _player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())
	_last_clock = maxf(_last_clock, raw)
	return _last_clock


func _check(reason: String) -> void:
	if not _take.is_empty() and not _valid():
		stop(reason)


func _valid() -> bool:
	if _panel == null or not is_instance_valid(_panel) or not bool(_panel.call("attention_active")):
		return false
	if not bool(conversations.call("performance_active")) or not is_same(_panel.get("_tree"), _bound.tree):
		return false
	if str(_panel.get("current_node_id")) != str(_bound.node):
		return false
	var shown: Dictionary = _panel.call("displayed_line")
	if str(shown.get("text", "")) != str(_bound.text) or str(shown.get("delivery", "")) == "silent":
		return false
	return is_same(_reality_data(), _campaign) and not _foreign_attention()


func _why_invalid() -> String:
	if _panel == null or not is_instance_valid(_panel) or not bool(_panel.call("attention_active")):
		return "panel_closed"
	if not is_same(_panel.get("_tree"), _bound.tree) or not bool(conversations.call("performance_active")):
		return "tree_replaced"
	if str(_panel.get("current_node_id")) != str(_bound.node):
		return "node_changed"
	if str(_panel.call("displayed_line").get("delivery", "")) == "silent":
		return "silent"
	if not is_same(_reality_data(), _campaign):
		return "state_loaded"
	return "other_panel" if _foreign_attention() else "text_changed"


## Stops the line. `faces` false leaves the mouths to the conversation's own speech owner (a node change).
func stop(reason: String, faces := true) -> void:
	_bind_pending = false
	if RenderingServer.frame_pre_draw.is_connected(_before_dialogue_draw):
		RenderingServer.frame_pre_draw.disconnect(_before_dialogue_draw)
	if RenderingServer.frame_post_draw.is_connected(_start_prepared_take):
		RenderingServer.frame_post_draw.disconnect(_start_prepared_take)
	var was_pending := _awaiting_draw
	_awaiting_draw = false
	if _take.is_empty():
		return
	if _player != null:
		_player.stop()
	if faces:
		for who: String in _faces:
			var body: Node = _faces[who].body
			if _faces[who].on and is_instance_valid(body):
				body.call("stop_speaking")
	if not was_pending:
		_note({"event": "stop", "reason": reason, "actor": str(_bound.get("actor", ""))})
	_take = {}
	_bound = {}
	_faces.clear()
	if not was_pending: stopped.emit(reason)


func _note(event: Dictionary) -> void:
	if not diagnostics:
		return
	events.append(event)
	if events.size() > EVENT_LIMIT:
		events = events.slice(events.size() - EVENT_LIMIT)


func _frame(row: Dictionary) -> void:
	frames.append(row)
	if frames.size() > FRAME_LIMIT:
		frames = frames.slice(frames.size() - FRAME_LIMIT)


func _exit_tree() -> void:
	stop("exit_tree")


func _foreign_attention() -> bool:
	for other: Node in get_tree().get_nodes_in_group("attention_people"):
		if other != _panel and other.has_method("attention_active") and bool(other.call("attention_active")):
			return true
	return false


func _cast_body(resident: String) -> Node:
	for actor: Node in get_tree().get_nodes_in_group("animated_residents"):
		if str(actor.get("resident_id")) != resident or not actor is Node3D or not actor.is_visible_in_tree():
			continue
		# Harukiya staff are the cast presentation. Routed residents wrap one.
		var body: Node3D = actor if actor.has_method("speak_cues") else actor.get("cast_body")
		if is_instance_valid(body) and body.is_visible_in_tree() and body.has_method("speak_cues"):
			return body
	return null


func _reality_data() -> Variant:
	var state: Node = get_node_or_null("/root/RealityState")
	return state.get("data") if state != null else null


func _load_stream(path: String) -> AudioStream:
	if stream_loader.is_valid():
		return stream_loader.call(path)
	if path.begins_with("res://") and ResourceLoader.exists(path):
		return load(path) as AudioStream
	if path.get_extension().to_lower() == "ogg" and FileAccess.file_exists(path):
		return AudioStreamOggVorbis.load_from_file(path)
	return null
