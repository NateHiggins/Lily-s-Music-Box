extends Node
## One face controller per actor. It is the only writer of an actor's face
## shapes. Each frame it composes, in order, and writes each shape once:
##
##   1. expression   a named state at an intensity, eased, a little uneven
##                   from side to side in a way that is this actor's own
##   2. eyes         where the eyes are turned, ahead of the head, never
##                   fixed: small saccades about the target, a glance
##                   away as a spoken turn begins and back when it ends,
##                   and a blink with any large shift of gaze
##   3. blink        on its own clock; closes over anything
##   4. speech       mouth shapes from the timing of the line being spoken,
##                   or a restrained jaw when a line has no timing; speech
##                   quiets the expression's own mouth
##
## Who feels what, what is looked at and which line plays are decided
## elsewhere, from authored dialogue and behaviour. A body with no face shapes
## binds to nothing and every call is a quiet no-op, so the same code runs on
## the cast's old bodies and their new ones.

const DATA := "res://data/characters/face_performance.json"

var bound := false
## Shape name to an array of [MeshInstance3D, blend shape index].
var targets: Dictionary = {}
var writes_last_frame := 0
var _data: Dictionary = {}
var _random := RandomNumberGenerator.new()
## Gaze has its own stream, so it never shifts this actor's blink timing.
var _gaze_random := RandomNumberGenerator.new()
var _micro_seed := 0
var _capture_eye: Variant = null
var _saccade := Vector2.ZERO
var _saccade_at := 0.0
var _avert := Vector2.ZERO
var _avert_until := -1.0
var _down_left_until := -1.0
var _last_gaze := Vector2.ZERO
var _lean: Dictionary = {}
var _expression := "neutral"
var _intensity := 0.0
var _breath_by_expression := {}
var _shown: Dictionary = {}
var _values: Dictionary = {}
var _eye := Vector2.ZERO
var _eye_goal := Vector2.ZERO
var _blink_at := 3.0
var _blink_phase := -1.0
var _blinks_owed := 0
var _clock := 0.0
var _cues: Array = []
var _speech_clock := -1.0
var _speech_ends := 0.0
var _audio_drives_speech := false
var _fallback := false
var _mouth: Dictionary = {}
var _talk := 0.0


## Find the face on a model. False when it has none of the shapes.
func bind(model: Node, seed_text: String) -> bool:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if document is not Dictionary or int(document.get("schema_version", 0)) != 1:
		return false
	_data = document
	# The file keeps rows; the controller works from tables.
	for row: Dictionary in document.expressions:
		_breath_by_expression[str(row.name)] = float(row.get("breath_arousal", 0.0))
	_data["expressions"] = _table(document.get("expressions", []), "name")
	_data["mouth_shapes"] = _table(document.get("mouth_shapes", []), "letter")
	_random.seed = hash(seed_text)
	targets.clear()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for index in mesh.get_blend_shape_count():
			var shape := str(mesh.mesh.get_blend_shape_name(index))
			if not targets.has(shape):
				targets[shape] = []
			(targets[shape] as Array).append([mesh, index])
	bound = targets.has("eyeBlinkLeft") or targets.has("viseme_aa")
	# How this face is uneven: fixed for the actor, small.
	for shape: String in targets:
		_lean[shape] = _random.randf_range(0.86, 1.0)
	_blink_at = _random.randf_range(0.6, 3.0)
	_gaze_random.seed = hash(seed_text + ":gaze")
	_micro_seed = hash(seed_text + ":microsaccades")
	_saccade_at = 0.0
	return bound


static func _table(rows: Variant, key: String) -> Dictionary:
	var table: Dictionary = {}
	if rows is Array:
		for row: Dictionary in rows:
			var shapes: Dictionary = {}
			for pair: Array in row.get("shapes", []):
				shapes[str(pair[0])] = float(pair[1])
			table[str(row.get(key, ""))] = shapes
	return table


func can_speak_shapes() -> bool:
	return targets.has("viseme_aa")


## Show a named expression at an intensity: 1 is the expression as written,
## up to 2 for a stage-sized performance (ruling npc_face_mood_source_20261124).
## Each shape still stops at its own full extent.
func express(expression: String, intensity: float = 1.0) -> bool:
	if not (_data.get("expressions", {}) as Dictionary).has(expression):
		return false
	_expression = expression
	_intensity = clampf(intensity, 0.0, 2.0)
	return true


func expression() -> String:
	return _expression


## The already-authored expression drives the speed of the ordinary breath.
func breath_arousal() -> float:
	return clampf(float(_breath_by_expression.get(_expression, 0.0)) * _intensity, 0.0, 1.0)


## Turn the eyes: x is degrees toward the actor's left (negative, right), y up.
func look(degrees: Vector2) -> void:
	_eye_goal = degrees


## An explicit acting direction. It supplies no clue, judgement or campaign fact.
func glance_down_left() -> void:
	_down_left_until = _clock + 0.65


## A jittered event per cell gives a bounded interval and random access at any
## film frame. The actor and take alone select the marks, without replaying RNG.
func _microsaccade(seconds: float, take_seed: int) -> Dictionary:
	var gaze: Dictionary = _data.gaze
	var shortest := float(gaze.saccade_least_seconds)
	var period := (shortest + float(gaze.saccade_most_seconds)) * 0.5
	var cell := floori(seconds / period)
	var start := _gaze_mark(cell, take_seed, period, shortest)
	var next := start
	if seconds < start:
		cell -= 1
	else:
		next = _gaze_mark(cell + 1, take_seed, period, shortest)
	# A point in an ellipse keeps diagonal movements small, too.
	var angle := TAU * _fraction(cell, take_seed, 1)
	var direction := Vector2(cos(angle) * float(gaze.saccade_degrees),
			sin(angle) * float(gaze.saccade_pitch_degrees))
	return {"offset": direction * sqrt(_fraction(cell, take_seed, 2)), "next": next}


func _gaze_mark(cell: int, take_seed: int, period: float, shortest: float) -> float:
	return cell * period + (period - shortest) * _fraction(cell, take_seed, 0)


func _fraction(cell: int, take_seed: int, channel: int) -> float:
	return float(hash([_micro_seed, take_seed, cell, channel]) & 65535) / 65536.0


## Render the eyes for a fixed film frame. The caller supplies the head-relative
## target for that frame; speech, the expression, and the lid clock stay owned
## by this face. No wall time, prior samples or random draws enter the eye pose.
func pose_gaze_for_frame(frame_number: int, fps: int, take_seed: int, degrees: Vector2) -> bool:
	if not bound or frame_number < 0 or fps <= 0 or not degrees.is_finite():
		return false
	_capture_eye = degrees + Vector2(_microsaccade(float(frame_number) / fps, take_seed).offset)
	step(0.0)
	_capture_eye = null
	return true


func blink() -> void:
	if _blink_phase < 0.0:
		_blink_phase = 0.0


## Speak a line whose mouth timing is known: rows of start, end and a mouth
## shape letter, as the timing tool writes them.
func speak(cues: Array) -> void:
	_audio_drives_speech = false
	_cues = cues
	_fallback = false
	_speech_clock = 0.0
	_speech_ends = 0.0
	for cue: Dictionary in cues:
		_speech_ends = maxf(_speech_ends, float(cue.get("end", 0.0)))
	_begin_turn()


## Speak a line that is heard but has no timing: a restrained jaw, no shapes.
func speak_untimed(seconds: float) -> void:
	_audio_drives_speech = false
	_cues = []
	_fallback = true
	_speech_clock = 0.0
	_speech_ends = maxf(seconds, 0.0)
	_begin_turn()


## A written or silent line moves no mouth; an interrupted one stops here and
## the mouth eases shut.
func stop_speaking() -> void:
	_audio_drives_speech = false
	_speech_clock = -1.0
	_cues = []
	_fallback = false
	# The turn is over: the eyes come back to whoever they were on.
	_avert = Vector2.ZERO
	_avert_until = -1.0
	_down_left_until = -1.0


## A speaker often looks away as a turn begins, gathering it, and back to the
## listener before it ends. Not every turn, and never for long.
func _begin_turn() -> void:
	var gaze: Dictionary = _data.get("gaze", {})
	if gaze.is_empty() or _gaze_random.randf() >= float(gaze.aversion_chance):
		return
	var side := -1.0 if _gaze_random.randf() < 0.5 else 1.0
	var yaw: Array = gaze.aversion_yaw_degrees
	var pitch: Array = gaze.aversion_pitch_degrees
	_avert = Vector2(side * _gaze_random.randf_range(float(yaw[0]), float(yaw[1])),
			_gaze_random.randf_range(float(pitch[0]), float(pitch[1])))
	_avert_until = _clock + _gaze_random.randf_range(float(gaze.aversion_least_seconds), float(gaze.aversion_most_seconds))


## Absolute seconds in the recorded line. Once playback supplies a position,
## it owns this timed line until stop or replacement. The ordinary face step
## still blends the sampled viseme with the eyes and expression in one write.
func seek_speech(seconds: float) -> void:
	if not bound or _cues.is_empty() or not is_finite(seconds) or seconds < 0.0:
		return
	_audio_drives_speech = true
	_speech_clock = minf(seconds, _speech_ends)


func is_speaking() -> bool:
	return _speech_clock >= 0.0 and (not _audio_drives_speech or _speech_clock < _speech_ends)


## The mouth timing for a recorded line, or an empty array.
static func load_cues(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if document is Dictionary and document.get("mouthCues") is Array:
		return document.mouthCues
	return []


func value_of(shape: String) -> float:
	return float(_values.get(shape, 0.0))


func _process(delta: float) -> void:
	step(delta)


func _toward(now: float, goal: float, delta: float, seconds: float) -> float:
	return lerpf(now, goal, 1.0 - exp(-delta * 3.0 / maxf(seconds, 0.001)))


func _add(frame: Dictionary, shape: String, amount: float) -> void:
	frame[shape] = clampf(float(frame.get(shape, 0.0)) + amount, 0.0, 1.0)


func step(delta: float) -> void:
	if not bound:
		return
	_clock += delta
	var frame: Dictionary = {}

	# 1. Expression, eased so a feeling arrives and leaves.
	var wanted: Dictionary = (_data.expressions as Dictionary).get(_expression, {})
	var names: Dictionary = {}
	for shape: String in wanted:
		names[shape] = true
	for shape: String in _shown:
		names[shape] = true
	for shape: String in names:
		var goal := float(wanted.get(shape, 0.0)) * _intensity * float(_lean.get(shape, 1.0))
		var now := _toward(float(_shown.get(shape, 0.0)), goal, delta, 0.32)
		if now < 0.002 and goal <= 0.0:
			_shown.erase(shape)
		else:
			_shown[shape] = now
			_add(frame, shape, now)

	# 2. Eyes.
	var eyes: Dictionary = _data.eyes
	var gaze: Dictionary = _data.get("gaze", {})
	var aim := _eye_goal
	if _capture_eye is Vector2:
		_eye = _capture_eye
	elif not gaze.is_empty():
		if _clock >= _saccade_at:
			var mark := _microsaccade(_clock, 0)
			_saccade = mark.offset
			_saccade_at = mark.next
		if _avert_until >= 0.0 and _clock >= _avert_until:
			_avert = Vector2.ZERO
			_avert_until = -1.0
		aim += _saccade + (Vector2(12.0, -6.0) if _clock < _down_left_until else _avert)
		# A large shift of gaze carries a blink with it.
		if _blink_phase < 0.0 and aim.distance_to(_last_gaze) > float(gaze.blink_with_shift_degrees):
			_blink_phase = 0.0
			_blinks_owed = 0
		_last_gaze = aim
	if _capture_eye == null:
		var limits := Vector2(float(eyes.yaw_degrees), float(eyes.pitch_degrees))
		_eye = _eye.move_toward(aim.clamp(-limits, limits), rad_to_deg(12.0) * delta)
	var yaw := clampf(_eye.x / float(eyes.yaw_degrees), -1.0, 1.0)
	var pitch := clampf(_eye.y / float(eyes.pitch_degrees), -1.0, 1.0)
	if yaw > 0.0:
		_add(frame, str(eyes.left_out), yaw)
		_add(frame, str(eyes.right_in), yaw)
	elif yaw < 0.0:
		_add(frame, str(eyes.left_in), -yaw)
		_add(frame, str(eyes.right_out), -yaw)
	for shape: String in (eyes.up if pitch > 0.0 else eyes.down):
		_add(frame, shape, absf(pitch))

	# 3. Blink.
	var blinking: Dictionary = _data.blink
	if _blink_phase < 0.0 and _clock >= _blink_at:
		_blink_phase = 0.0
		_blinks_owed = 1 if _random.randf() < float(blinking.double_chance) else 0
	if _blink_phase >= 0.0:
		_blink_phase += delta
		var closing := float(blinking.close_seconds)
		var opening := float(blinking.open_seconds)
		var lid := _blink_phase / closing if _blink_phase < closing else 1.0 - (_blink_phase - closing) / opening
		if _blink_phase >= closing + opening:
			lid = 0.0
			if _blinks_owed > 0:
				_blinks_owed -= 1
				_blink_phase = 0.0
			else:
				_blink_phase = -1.0
				_blink_at = _clock + _random.randf_range(float(blinking.least_seconds), float(blinking.most_seconds))
		for shape: String in blinking.shapes:
			frame[shape] = maxf(float(frame.get(shape, 0.0)), clampf(lid, 0.0, 1.0))

	# 4. Speech.
	var mouth_goal: Dictionary = {}
	if _speech_clock >= 0.0 and not _audio_drives_speech:
		_speech_clock += delta
		if _speech_clock >= _speech_ends:
			stop_speaking()
	if is_speaking():
		if _fallback:
			var jaw: Dictionary = _data.fallback_jaw
			var beat := _speech_clock * float(jaw.syllables_per_second) * TAU
			# Two rhythms that do not line up, so the jaw does not tick.
			var open := maxf(0.0, 0.55 * sin(beat) + 0.45 * sin(beat * 0.37 + 1.3))
			mouth_goal[str(jaw.shape)] = open * float(jaw.most)
		else:
			# A little ahead of the sound: a mouth forms a shape before it is heard.
			var at := _speech_clock + 0.04
			for cue: Dictionary in _cues:
				if at >= float(cue.get("start", 0.0)) and at < float(cue.get("end", 0.0)):
					mouth_goal = (_data.mouth_shapes as Dictionary).get(str(cue.get("value", "X")), {})
					break
	_talk = _toward(_talk, 1.0 if is_speaking() else 0.0, delta, 0.12)
	var mouth_names: Dictionary = {}
	for shape: String in mouth_goal:
		mouth_names[shape] = true
	for shape: String in _mouth:
		mouth_names[shape] = true
	if _talk > 0.01:
		for shape: String in _data.speech_quiets:
			if frame.has(shape):
				frame[shape] = float(frame[shape]) * (1.0 - 0.7 * _talk)
	for shape: String in mouth_names:
		var now := _toward(float(_mouth.get(shape, 0.0)), float(mouth_goal.get(shape, 0.0)), delta, 0.055)
		if now < 0.002 and not mouth_goal.has(shape):
			_mouth.erase(shape)
		else:
			_mouth[shape] = now
			_add(frame, shape, now)

	# One write per shape, and a shape let go is written once more, to zero.
	writes_last_frame = 0
	for shape: String in _values:
		if not frame.has(shape):
			frame[shape] = 0.0
	var kept: Dictionary = {}
	for shape: String in frame:
		var amount := float(frame[shape])
		if targets.has(shape):
			for target: Array in targets[shape]:
				(target[0] as MeshInstance3D).set_blend_shape_value(int(target[1]), amount)
			writes_last_frame += 1
		if amount > 0.0:
			kept[shape] = amount
	_values = kept
