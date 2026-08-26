class_name DreamCellularAudioPool
extends Node
## MBIO-5: one bounded positional voice layer for one Dream encroachment.
##
## Biology publishes an accepted cellular event first. This layer only
## presents that fact: it has no director reference, cannot emit mechanics,
## and never allocates a player per organelle. Four reusable voices are the
## complete simultaneous budget for the encroachment.

const VOICE_CAP := 4
const MAX_DISTANCE_M := 14.0
const UNIT_SIZE_M := 2.4
const KIND_KEYS := {
	&"channel": "cellular_channel",
	&"cilia": "cellular_cilia",
	&"relay": "cellular_relay",
	&"vesicle": "cellular_vesicle",
}

var _voices: Array[AudioStreamPlayer3D] = []
var _busy_until: Array[float] = []
var _clock := 0.0
var _presented := 0
var _stolen := 0
var _unknown := 0
var _by_kind: Dictionary = {}


func setup() -> void:
	name = "DreamCellularAudioPool"
	if _voices.is_empty():
		for i in VOICE_CAP:
			var voice := AudioStreamPlayer3D.new()
			voice.bus = "Hazard"
			voice.name = "CellularVoice%d" % i
			voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			voice.unit_size = UNIT_SIZE_M
			voice.max_distance = MAX_DISTANCE_M
			voice.max_db = -5.0
			voice.panning_strength = 1.35
			add_child(voice)
			_voices.append(voice)
			_busy_until.append(0.0)
	reset_state()


func reset_state() -> void:
	_clock = 0.0
	_presented = 0
	_stolen = 0
	_unknown = 0
	_by_kind.clear()
	for i in _voices.size():
		_voices[i].stop()
		_busy_until[i] = 0.0


func _process(delta: float) -> void:
	_clock += delta


## Signal packets are already cellular outputs. Raw MECHANICAL packets are
## deliberately absent from this mapping, so a footstep cannot sonify itself
## before a receptor accepts it and emits a biological answer.
func present_signal(src_class: int, _function: int, family: int, at: Vector3,
		strength: float) -> bool:
	var kind := StringName()
	match family:
		DreamEcologyDirector.Chem.ELECTRIC:
			kind = &"channel"
		DreamEcologyDirector.Chem.VASCULAR:
			kind = &"cilia" if src_class == DreamEcologyDirector.SrcClass.CILIA \
					else &"relay"
		DreamEcologyDirector.Chem.SECRETION:
			kind = &"vesicle"
		_:
			return false
	return present(kind, at, strength)


func present(kind: StringName, at: Vector3, strength := 1.0) -> bool:
	var key := str(KIND_KEYS.get(kind, "cellular_%s" % str(kind)))
	var stream := PropAudio.get_stream(key)
	if stream == null:
		_unknown += 1
		return false
	if _voices.is_empty():
		setup()
	var slot := -1
	for i in _voices.size():
		if _busy_until[i] <= _clock:
			slot = i
			break
	if slot < 0:
		# A fifth simultaneous event reuses the voice that will finish first.
		# This is a deterministic steal, never a fifth voice.
		slot = 0
		for i in range(1, _voices.size()):
			if _busy_until[i] < _busy_until[slot]:
				slot = i
		_stolen += 1
	var voice := _voices[slot]
	voice.stop()
	voice.stream = stream
	voice.global_position = at
	voice.volume_db = lerpf(-17.0, -7.0, clampf(strength, 0.0, 1.0))
	voice.pitch_scale = 0.94 + float((_presented + slot) % 5) * 0.025
	voice.play()
	_busy_until[slot] = _clock + maxf(0.05,
			stream.get_length() / maxf(0.1, voice.pitch_scale))
	_presented += 1
	_by_kind[kind] = int(_by_kind.get(kind, 0)) + 1
	return true


func census() -> Dictionary:
	var busy := 0
	for until in _busy_until:
		if until > _clock:
			busy += 1
	return {"voices": _voices.size(), "capacity": VOICE_CAP, "busy": busy,
			"presented": _presented, "stolen": _stolen,
			"unknown": _unknown, "by_kind": _by_kind.duplicate()}
