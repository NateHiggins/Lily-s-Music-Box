extends Node
## One face controller per actor. It is the only writer of an actor's face
## shapes. Each frame it composes, in order, and writes each shape once:
##
##   1. expression   a named state at an intensity, eased, a little uneven
##                   from side to side in a way that is this actor's own
##   2. eyes         where the eyes are turned, ahead of the head
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
var _lean: Dictionary = {}
var _expression := "neutral"
var _intensity := 0.0
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
var _fallback := false
var _mouth: Dictionary = {}
var _talk := 0.0


## Find the face on a model. False when it has none of the shapes.
func bind(model: Node, seed_text: String) -> bool:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if document is not Dictionary or int(document.get("schema_version", 0)) != 1:
		return false
	_data = document
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
	return bound


func can_speak_shapes() -> bool:
	return targets.has("viseme_aa")


## Show a named expression at an intensity from 0 to 1.
func express(expression: String, intensity: float = 1.0) -> bool:
	if not (_data.get("expressions", {}) as Dictionary).has(expression):
		return false
	_expression = expression
	_intensity = clampf(intensity, 0.0, 1.0)
	return true


func expression() -> String:
	return _expression


## Turn the eyes: x is degrees toward the actor's left (negative, right), y up.
func look(degrees: Vector2) -> void:
	_eye_goal = degrees


func blink() -> void:
	if _blink_phase < 0.0:
		_blink_phase = 0.0


## Speak a line whose mouth timing is known: rows of start, end and a mouth
## shape letter, as the timing tool writes them.
func speak(cues: Array) -> void:
	_cues = cues
	_fallback = false
	_speech_clock = 0.0
	_speech_ends = 0.0
	for cue: Dictionary in cues:
		_speech_ends = maxf(_speech_ends, float(cue.get("end", 0.0)))


## Speak a line that is heard but has no timing: a restrained jaw, no shapes.
func speak_untimed(seconds: float) -> void:
	_cues = []
	_fallback = true
	_speech_clock = 0.0
	_speech_ends = maxf(seconds, 0.0)


## A written or silent line moves no mouth; an interrupted one stops here and
## the mouth eases shut.
func stop_speaking() -> void:
	_speech_clock = -1.0
	_cues = []
	_fallback = false


func is_speaking() -> bool:
	return _speech_clock >= 0.0


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
	_eye = Vector2(_toward(_eye.x, _eye_goal.x, delta, 0.07), _toward(_eye.y, _eye_goal.y, delta, 0.07))
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
	if _speech_clock >= 0.0:
		_speech_clock += delta
		if _speech_clock >= _speech_ends:
			stop_speaking()
		elif _fallback:
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
	_talk = _toward(_talk, 1.0 if _speech_clock >= 0.0 else 0.0, delta, 0.12)
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
