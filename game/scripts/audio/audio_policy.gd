class_name OrisonAudioPolicy
extends Node
## Presentation policy for source-owned facts. Callers decide what happened;
## this node only resolves bus, voice, priority, cooldown and diagnostics.

signal cue_presented(cue_id: StringName, snapshot: Dictionary)
signal cue_refused(cue_id: StringName, reason: String)

const CATALOG_PATH := "res://data/audio_cues.json"
const VOICE_CAP := 16
const EVENT_HISTORY_CAP := 256
const REQUIRED_FIELDS := ["stream_key", "purpose", "bus", "priority",
		"volume_db", "unit_size", "max_distance", "cooldown",
		"max_instances", "caption", "graph_transmitted"]
const BUS_SPECS := [
	["Gameplay", "Master"],
	["Interaction", "Gameplay"],
	["State", "Gameplay"],
	["Navigation", "Gameplay"],
	["Hazard", "Gameplay"],
	["Voice", "Master"],
	["Dialogue", "Voice"],
	["Telephone", "Voice"],
	["World", "Master"],
	["RoomTone", "World"],
	["Architecture", "World"],
	["Weather", "World"],
	["Machinery", "World"],
	["Broadcast", "World"],
	["Music", "Master"],
	["Diegetic", "Music"],
	["Nondiegetic", "Music"],
	["UI", "Master"],
]
const MIX_STATES := {
	"normal": {},
	"dialogue": {"World":-5.0, "Music":-8.0, "Gameplay":-1.5},
	"telephone": {"World":-7.0, "Music":-10.0, "Gameplay":-3.0,
			"Telephone":1.5},
	"sleep_onset": {"World":-4.0, "Music":-9.0, "Navigation":-2.0},
	"dream_embrace": {"World":-8.0, "Music":-12.0, "Gameplay":-4.0,
			"Hazard":1.0},
	"paused": {"World":-10.0, "Gameplay":-10.0, "Music":-6.0},
}

var cues: Dictionary = {}
var errors: Array[String] = []
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_state: Array[Dictionary] = []
var _last_presented: Dictionary = {}
var _mix_requests: Dictionary = {}
var _event_history: Array[Dictionary] = []
var _clock := 0.0
var _presented := 0
var _refused := 0
var _stolen := 0
var _listener: Node3D


func _ready() -> void:
	name = "AudioPolicy"
	if not setup():
		for error in errors:
			push_error("AudioPolicy: %s" % error)


func setup(catalog_path := CATALOG_PATH, build_voices := true) -> bool:
	errors.clear()
	_load_catalog(catalog_path)
	ensure_bus_tree()
	if build_voices and _voices.is_empty():
		_build_voice_pool()
	return errors.is_empty()


func _process(delta: float) -> void:
	_clock += delta


func bind_listener(listener: Node3D) -> void:
	_listener = listener


func ensure_bus_tree() -> void:
	for spec in BUS_SPECS:
		var bus_name: String = spec[0]
		var parent_name: String = spec[1]
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, parent_name)


func present_3d(cue_id: StringName, at: Vector3, strength := 1.0,
		source_id := &"") -> bool:
	if not cues.has(cue_id):
		return _refuse(cue_id, "unknown_cue")
	if _voices.is_empty():
		return _refuse(cue_id, "no_voice_pool")
	var cue: Dictionary = cues[cue_id]
	var cooldown := float(cue.cooldown)
	var cooldown_key := "%s|%s" % [cue_id, source_id]
	if cooldown > 0.0 and _clock - float(_last_presented.get(
			cooldown_key, -INF)) < cooldown:
		return _refuse(cue_id, "cooldown")
	var active_same := 0
	for state in _voice_state:
		if float(state.until) > _clock and state.cue_id == cue_id:
			active_same += 1
	if active_same >= int(cue.max_instances):
		return _refuse(cue_id, "instance_limit")
	var slot := _choose_voice(int(cue.priority))
	if slot < 0:
		return _refuse(cue_id, "lower_than_active_budget")
	var voice := _voices[slot]
	var previous: Dictionary = _voice_state[slot]
	if float(previous.until) > _clock:
		voice.stop()
		_stolen += 1
	var stream := PropAudio.get_stream(str(cue.stream_key))
	if stream == null:
		return _refuse(cue_id, "missing_stream")
	voice.stream = stream
	voice.bus = str(cue.bus)
	voice.global_position = at
	voice.volume_db = float(cue.volume_db) + linear_to_db(
			clampf(strength, 0.05, 1.0))
	voice.unit_size = float(cue.unit_size)
	voice.max_distance = float(cue.max_distance)
	voice.pitch_scale = 1.0
	voice.play()
	var duration := maxf(0.05, stream.get_length())
	_voice_state[slot] = {"cue_id":cue_id, "priority":int(cue.priority),
			"until":_clock + duration, "source_id":source_id}
	_last_presented[cooldown_key] = _clock
	_presented += 1
	var snapshot := {"slot":slot, "cue_id":cue_id, "source_id":source_id,
			"purpose":str(cue.purpose), "bus":str(cue.bus), "at":at,
			"priority":int(cue.priority), "caption":str(cue.caption),
			"outcome":"presented", "at_second":_clock,
			"listener_distance":_listener.global_position.distance_to(at)
					if is_instance_valid(_listener) else -1.0}
	_record_event(snapshot)
	cue_presented.emit(cue_id, snapshot)
	return true


func advance_for_test(seconds: float) -> void:
	_clock += maxf(0.0, seconds)


func stop_source(source_id: StringName, cue_id := StringName()) -> int:
	if source_id == &"":
		return 0
	var stopped := 0
	for i in _voice_state.size():
		var state: Dictionary = _voice_state[i]
		if float(state.until) <= _clock or state.source_id != source_id:
			continue
		if cue_id != &"" and state.cue_id != cue_id:
			continue
		_voices[i].stop()
		_voice_state[i] = {"cue_id":&"", "priority":-1, "until":_clock,
				"source_id":&""}
		stopped += 1
		_record_event({"cue_id":state.cue_id, "source_id":source_id,
				"outcome":"stopped", "at_second":_clock})
	return stopped


func cue(cue_id: StringName) -> Dictionary:
	return (cues.get(cue_id, {}) as Dictionary).duplicate(true)


func request_mix(owner_id: StringName, state_name: StringName,
		weight := 1.0) -> bool:
	if owner_id == &"" or not MIX_STATES.has(state_name):
		return false
	_mix_requests[owner_id] = {"state":state_name,
			"weight":clampf(weight, 0.0, 1.0)}
	_apply_mix()
	return true


func release_mix(owner_id: StringName) -> bool:
	if not _mix_requests.erase(owner_id):
		return false
	_apply_mix()
	return true


func mix_snapshot() -> Dictionary:
	var buses := {}
	for spec in BUS_SPECS:
		var bus_name: String = spec[0]
		var index := AudioServer.get_bus_index(bus_name)
		buses[bus_name] = AudioServer.get_bus_volume_db(index) if index >= 0 \
				else -INF
	return {"requests":_mix_requests.duplicate(true), "buses":buses}


func event_history() -> Array[Dictionary]:
	return _event_history.duplicate(true)


func clear_diagnostics() -> void:
	_event_history.clear()
	_presented = 0
	_refused = 0
	_stolen = 0


func census() -> Dictionary:
	var active := 0
	for state in _voice_state:
		if float(state.until) > _clock:
			active += 1
	return {"voices":_voices.size(), "active":active,
			"presented":_presented, "refused":_refused, "stolen":_stolen,
			"catalog_size":cues.size(), "mix_requests":_mix_requests.size(),
			"history":_event_history.size(),
			"errors":errors.duplicate()}


func _load_catalog(path: String) -> void:
	cues.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("catalog_missing:%s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
		errors.append("catalog_schema")
		return
	var records: Dictionary = parsed.get("cues", {})
	for raw_id in records:
		var cue_id := StringName(str(raw_id))
		var record: Variant = records[raw_id]
		if not record is Dictionary:
			errors.append("%s:not_dictionary" % cue_id)
			continue
		var missing: Array[String] = []
		for field in REQUIRED_FIELDS:
			if not record.has(field):
				missing.append(field)
		if not missing.is_empty():
			errors.append("%s:missing:%s" % [cue_id, ",".join(missing)])
			continue
		if not _known_bus(str(record.bus)):
			errors.append("%s:unknown_bus:%s" % [cue_id, record.bus])
			continue
		if int(record.max_instances) < 1 or float(record.max_distance) <= 0.0:
			errors.append("%s:invalid_limits" % cue_id)
			continue
		cues[cue_id] = (record as Dictionary).duplicate(true)


func _known_bus(bus_name: String) -> bool:
	for spec in BUS_SPECS:
		if spec[0] == bus_name:
			return true
	return false


func _build_voice_pool() -> void:
	for i in VOICE_CAP:
		var voice := AudioStreamPlayer3D.new()
		voice.name = "PolicyVoice%02d" % i
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.panning_strength = 1.0
		add_child(voice)
		_voices.append(voice)
		_voice_state.append({"cue_id":&"", "priority":-1, "until":0.0,
				"source_id":&""})


func _choose_voice(wanted_priority: int) -> int:
	for i in _voice_state.size():
		if float(_voice_state[i].until) <= _clock:
			return i
	var weakest := 0
	for i in range(1, _voice_state.size()):
		if int(_voice_state[i].priority) < int(_voice_state[weakest].priority):
			weakest = i
	if wanted_priority <= int(_voice_state[weakest].priority):
		return -1
	return weakest


func _apply_mix() -> void:
	var ducks := {}
	var boosts := {}
	for spec in BUS_SPECS:
		ducks[spec[0]] = 0.0
		boosts[spec[0]] = 0.0
	for request in _mix_requests.values():
		var state: Dictionary = MIX_STATES.get(request.state, {})
		var weight := float(request.weight)
		for bus_name in state:
			var wanted := float(state[bus_name]) * weight
			if wanted < 0.0:
				ducks[bus_name] = minf(float(ducks.get(bus_name, 0.0)), wanted)
			else:
				boosts[bus_name] = maxf(float(boosts.get(bus_name, 0.0)), wanted)
	for bus_name in ducks:
		var index := AudioServer.get_bus_index(str(bus_name))
		if index >= 0:
			var duck := float(ducks[bus_name])
			# A requested duck always wins over a focus boost on the same bus.
			AudioServer.set_bus_volume_db(index, duck if duck < 0.0 \
					else float(boosts[bus_name]))


func _refuse(cue_id: StringName, reason: String) -> bool:
	_refused += 1
	_record_event({"cue_id":cue_id, "outcome":"refused", "reason":reason,
			"at_second":_clock})
	cue_refused.emit(cue_id, reason)
	return false


func _record_event(event: Dictionary) -> void:
	_event_history.append(event.duplicate(true))
	if _event_history.size() > EVENT_HISTORY_CAP:
		_event_history.pop_front()
