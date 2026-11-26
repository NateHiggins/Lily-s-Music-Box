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
## What happened, in order, for tests and evidence: {"event": "play"|"stop"|"face", ...}.
var events: Array[Dictionary] = []

var _player: AudioStreamPlayer
var _panel: Node
var _take: Dictionary = {}
var _bound := {}
var _faces: Dictionary = {}  # resident id -> {"body": Node, "segment": Dictionary, "on": bool}
var _campaign: Variant = null
var _started_ms := 0


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


func _on_node_shown(_node_id: String) -> void:
	# The old line ends with its node; faces are left to the conversation's own speech owner, which restarts or
	# ends them on this same signal. The new node may bind its own take once the speaker swap has finished.
	if not _take.is_empty():
		stop("node_changed", false)
	_bind.call_deferred()


func _bind() -> void:
	if manifest == null or manifest.count() == 0 or not bool(conversations.call("performance_active")):
		return
	var tree: Dictionary = conversations.get("_performance_tree")
	var node_id := str(_panel.get("current_node_id"))
	if not is_same(_panel.get("_tree"), tree) or not node_id.begins_with("loop_business"):
		return
	var node: Dictionary = tree.get("nodes", {}).get(node_id, {})
	var actor := str(node.get("actor", ""))
	var line := str(node.get("line", ""))
	var shown: Dictionary = _panel.call("displayed_line")
	if actor.is_empty() or str(shown.get("text", "")) != line or str(shown.get("delivery", "")) == "silent" \
			or line.replace(".", "").strip_edges().is_empty() or _foreign_attention():
		return
	var take := manifest.take_for(actor, line)
	if take.is_empty():
		return
	for segment: Dictionary in take.segments:
		var span := line.substr(int(segment.get("start_char", 0)), int(segment.get("end_char", 0)) - int(segment.get("start_char", 0)))
		if span.strip_edges().is_empty():
			return # A segment that covers no words of this line: the take is not for it.
	var stream: AudioStream = _load_stream(str(take.audio))
	if stream == null:
		return
	_take = take
	_bound = {"tree": tree, "node": node_id, "text": line, "actor": actor}
	_campaign = _reality_data()
	_player.stream = stream
	_player.play()
	_started_ms = Time.get_ticks_msec()
	_start_faces(take, actor)
	events.append({"event": "play", "actor": actor, "node": node_id, "line_id": take.line_id})
	played.emit(take)


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
			events.append({"event": "face", "actor": who, "on": true, "at": at})
		elif not inside and face_row.on:
			body.call("stop_speaking")
			face_row.on = false
			events.append({"event": "face", "actor": who, "on": false, "at": at})
		if face_row.on:
			_seek_face(body, at)
	var ended := at >= float(_take.seconds) if float(_take.seconds) > 0.0 else false
	if not clock_source.is_valid() and not _player.playing and Time.get_ticks_msec() - _started_ms > 250:
		ended = true
	if ended:
		stop("finished")


## Keeps the mouth on the audio: the face's speech clock is set to the line's playback position each frame.
func _seek_face(body: Node, at: float) -> void:
	var face: Object = body.get("face")
	if face == null:
		return
	if face.has_method("seek_speech"):
		face.call("seek_speech", at)
	else:
		face.set("_speech_clock", at)


func _clock() -> float:
	if clock_source.is_valid():
		return float(clock_source.call())
	if not _player.playing:
		return 0.0
	return maxf(0.0, _player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())


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
	if _take.is_empty():
		return
	if _player != null:
		_player.stop()
	if faces:
		for who: String in _faces:
			var body: Node = _faces[who].body
			if _faces[who].on and is_instance_valid(body):
				body.call("stop_speaking")
	events.append({"event": "stop", "reason": reason, "actor": str(_bound.get("actor", ""))})
	_take = {}
	_bound = {}
	_faces.clear()
	stopped.emit(reason)


func _exit_tree() -> void:
	stop("exit_tree")


func _foreign_attention() -> bool:
	for other: Node in get_tree().get_nodes_in_group("attention_people"):
		if other != _panel and other.has_method("attention_active") and bool(other.call("attention_active")):
			return true
	return false


func _cast_body(resident: String) -> Node:
	for actor: Node in get_tree().get_nodes_in_group("animated_residents"):
		if str(actor.get("resident_id")) == resident:
			var body: Node = actor.get("cast_body")
			return body if body != null and body.has_method("speak_cues") else null
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
