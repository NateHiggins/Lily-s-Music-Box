class_name AmbientSoundscape
extends Node
## Layered, zone-aware Orison ambience. Quiet beds establish space; sparse
## positional events leave silence available for the paranormal director.

var player: Node3D
var paranormal_focus := 0.0
var _beds: Dictionary = {}
var _event_players: Array[AudioStreamPlayer3D] = []
var _next_event := 8.0
var _event_index := 0
var _rng := RandomNumberGenerator.new()


func setup(target: Node3D) -> void:
	player = target


func _ready() -> void:
	name = "AmbientSoundscape"
	_rng.seed = 1928
	_ensure_bus()
	_add_bed("city", "ambient_city_loop")
	_add_bed("building", "ambient_building_loop")
	_add_bed("basement", "ambient_basement_loop")
	_add_bed("roof", "ambient_roof_loop")
	for i in 3:
		var event := AudioStreamPlayer3D.new()
		event.name = "AmbientEvent%d" % i
		event.bus = "Ambience"
		event.max_distance = 18.0
		event.unit_size = 5.0
		event.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(event)
		_event_players.append(event)
	RealityCases.case_changed.connect(_on_case_changed)


func _ensure_bus() -> void:
	if AudioServer.get_bus_index("Ambience") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Ambience")
	var bus := AudioServer.get_bus_index("Ambience")
	AudioServer.set_bus_volume_db(bus, -3.0)


func _add_bed(key: String, stream_key: String) -> void:
	var bed := AudioStreamPlayer.new()
	bed.name = key.capitalize() + "Bed"
	bed.bus = "Ambience"
	bed.stream = PropAudio.get_stream(stream_key)
	bed.volume_db = -60.0
	add_child(bed)
	bed.play()
	_beds[key] = bed


func set_paranormal_focus(amount: float) -> void:
	paranormal_focus = clampf(amount, 0.0, 1.0)


func _on_case_changed(_case_id: String, state: Dictionary) -> void:
	var stage: String = state.get("stage", "unseen")
	if stage in ["active", "reopened", "recognized", "resistant"]:
		set_paranormal_focus(float(
				state.get("manifestation_intensity", 0.35)))
	elif stage == "integration_ready":
		set_paranormal_focus(0.22)
	else:
		set_paranormal_focus(0.0)


func _process(delta: float) -> void:
	if player == null:
		return
	var outside := player.global_position.z > 9.72
	var basement := player.global_position.y < -1.2
	var roof := player.global_position.y > 18.5
	var duck := paranormal_focus * 10.0
	_fade("city", (-17.0 if outside else -33.0) - duck, delta)
	_fade("building", (-23.0 if not outside else -38.0) - duck, delta)
	_fade("basement", (-17.5 if basement else -60.0) - duck, delta)
	_fade("roof", (-16.5 if roof else -60.0) - duck, delta)
	_next_event -= delta
	if _next_event <= 0.0 and not outside:
		_play_event()
		_next_event = _rng.randf_range(9.0, 24.0)


func _fade(key: String, target_db: float, delta: float) -> void:
	var bed: AudioStreamPlayer = _beds[key]
	bed.volume_db = lerpf(bed.volume_db, target_db, minf(1.0, delta * 0.8))


func _play_event() -> void:
	var event := _event_players[_event_index % _event_players.size()]
	_event_index += 1
	var keys := ["creak", "knock", "tick"]
	event.stream = PropAudio.get_stream(keys[_rng.randi_range(0, keys.size() - 1)])
	event.pitch_scale = _rng.randf_range(0.82, 1.08)
	event.volume_db = _rng.randf_range(-21.0, -15.0) - paranormal_focus * 8.0
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(4.0, 11.0)
	event.global_position = player.global_position + Vector3(
			cos(angle) * distance, _rng.randf_range(-0.8, 2.2),
			sin(angle) * distance)
	event.play()
