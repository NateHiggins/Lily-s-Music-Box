class_name AmbientSoundscape
extends Node
## Source-aware building sound director. Beds establish the broad zone; every
## discrete sound now originates at architecture, a fixture, or a radiator.
## SanityDirector can bias the timing and nominate the object that "speaks."

var player: Node3D
var sanity: SanityDirector
var paranormal_focus := 0.0
var _beds: Dictionary = {}
var _event_players: Array[AudioStreamPlayer3D] = []
var _next_event := 8.0
var _next_radiator := 5.0
var _next_signature := 11.0
var _stagger_guard := 0.0
var _event_index := 0
var _last_radiator: Node3D
var _rng := RandomNumberGenerator.new()


func setup(target: Node3D) -> void:
	player = target


func bind_sanity(director: SanityDirector) -> void:
	sanity = director
	if not sanity.intruded.is_connected(_on_sanity_intruded):
		sanity.intruded.connect(_on_sanity_intruded)


func _ready() -> void:
	name = "AmbientSoundscape"
	_rng.seed = 1928
	_ensure_bus()
	_add_bed("city", "ambient_city_loop")
	_add_bed("building", "ambient_building_loop")
	_add_bed("basement", "ambient_basement_loop")
	_add_bed("roof", "ambient_roof_loop")
	for i in 5:
		var event := AudioStreamPlayer3D.new()
		event.name = "ArchitecturalEvent%d" % i
		event.bus = "Ambience"
		event.max_distance = 24.0
		event.unit_size = 4.2
		event.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(event)
		_event_players.append(event)
	RealityCases.case_changed.connect(_on_case_changed)


func _ensure_bus() -> void:
	if AudioServer.get_bus_index("Ambience") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Ambience")
	var bus := AudioServer.get_bus_index("Ambience")
	AudioServer.set_bus_send(bus, "World")
	AudioServer.set_bus_volume_db(bus, -6.0)


func _add_bed(key: String, stream_key: String) -> void:
	var bed := AudioStreamPlayer.new()
	bed.name = key.capitalize() + "Bed"
	bed.bus = "Ambience"
	bed.stream = PropAudio.get_stream(stream_key)
	bed.volume_db = -60.0
	add_child(bed)
	if bed.stream:
		bed.play()
	_beds[key] = bed


func set_paranormal_focus(amount: float) -> void:
	paranormal_focus = clampf(amount, 0.0, 1.0)


## CommensalDirector schedules ordinary animal presence; this acoustic owner
## retains source selection, pool priority, bus routing and ducking.  C1 is a
## single sparse wall-scrape, never a cadence and never a new audio player.
func request_commensal_cue(kind: String, at: Vector3) -> bool:
	if kind != "mouse_riser" or _event_players.is_empty() \
			or _stagger_guard > 0.0:
		return false
	_play_at("creak", at, -35.0, 1.58)
	_stagger_guard = 5.0
	return true


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
	var roof := player.global_position.y > 18.5
	var outside := player.global_position.z > 9.72 or roof
	var basement := player.global_position.y < -1.2
	var pressure := sanity.pressure if sanity and sanity.enabled else 0.0
	var duck := maxf(paranormal_focus, pressure * 0.7) * 9.0
	_fade("city", (-17.0 if outside else -33.0) - duck, delta)
	_fade("building", (-23.0 if not outside else -38.0) - duck, delta)
	_fade("basement", (-17.5 if basement else -60.0) - duck, delta)
	_fade("roof", (-16.5 if roof else -60.0) - duck, delta)
	_next_event -= delta
	_next_radiator -= delta
	_next_signature -= delta
	_stagger_guard = maxf(0.0, _stagger_guard - delta)
	# All three clocks share a guard. The building takes turns speaking instead
	# of landing a pipe, a door and a resident signature in the same second.
	if _next_signature <= 0.0 and not outside and _stagger_guard <= 0.0:
		_cue_nearby_signature()
		_next_signature = _rng.randf_range(14.0, 31.0)
		_stagger_guard = 3.5
	elif _next_radiator <= 0.0 and not outside and _stagger_guard <= 0.0:
		_cue_radiator(pressure)
		# Ordinary heat is sparse and mostly a single harmless ping. Resident
		# signatures have their own scheduler and are allowed to form patterns.
		_next_radiator = _rng.randf_range(
				lerpf(34.0, 25.0, pressure), lerpf(82.0, 56.0, pressure))
		_stagger_guard = 3.0
	elif _next_event <= 0.0 and _stagger_guard <= 0.0:
		_cue_architecture(outside, basement, pressure)
		_next_event = _rng.randf_range(
				lerpf(29.0, 22.0, pressure), lerpf(66.0, 48.0, pressure))
		_stagger_guard = 4.0


func _fade(key: String, target_db: float, delta: float) -> void:
	var bed: AudioStreamPlayer = _beds[key]
	bed.volume_db = lerpf(bed.volume_db, target_db, minf(1.0, delta * 0.8))


func _cue_radiator(pressure: float) -> void:
	var candidates: Array = []
	for radiator in get_tree().get_nodes_in_group("radiators"):
		if radiator == _last_radiator:
			continue
		var distance: float = radiator.global_position.distance_to(
				player.global_position)
		# Occasionally answer from the floor above/below; normally use a
		# source close enough to locate through a wall.
		if distance < 24.0 and (distance < 14.0 or _rng.randf() < 0.24):
			candidates.append(radiator)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a, b):
		return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	var reach := mini(candidates.size(), 6)
	var chosen: Node3D = candidates[_rng.randi_range(0, reach - 1)]
	var roll := _rng.randf()
	var kind := "tick"
	if roll < 0.03 + pressure * 0.08:
		kind = "whistle"
	elif roll < 0.15 + pressure * 0.10:
		kind = "knock"
	chosen.call("play_ambient_cycle", kind,
			clampf(_rng.randf_range(0.18, 0.45) + pressure * 0.10, 0.0, 1.0))
	_last_radiator = chosen
	# A hard knock sometimes receives one remote, quieter reply.
	if kind == "knock" and candidates.size() > 1 and _rng.randf() < 0.32:
		var reply: Node3D = candidates[_rng.randi_range(1,
				mini(candidates.size() - 1, 5))]
		get_tree().create_timer(_rng.randf_range(0.7, 2.4), false).timeout.connect(
				func():
					if is_instance_valid(reply):
						reply.call("play_ambient_cycle", "tick", 0.30))


func _cue_architecture(outside: bool, basement: bool, pressure: float) -> void:
	var keys: Array
	if outside:
		keys = ["distant_rain_people", "hail_window", "rain_on_metal"]
	elif basement:
		keys = ["basement_stairs", "door_squeak", "water_droplets", "creak"]
	else:
		keys = ["creak", "door_squeak", "water_droplets", "sink_water",
				"shower_water"]
		if pressure > 0.48:
			keys.append_array(["knock", "breath"])
		if pressure > 0.78:
			keys.append("power_down")
	var key: String = keys[_rng.randi_range(0, keys.size() - 1)]
	_play_at(key, _architectural_source(), _rng.randf_range(-29.0, -22.0)
			- pressure * 4.0)


## A resident need not have an active work order to infect the air around
## them. Proximity is enough. Resolution—not temporary repair—is the only
## thing that silences their personal tell.
func _cue_nearby_signature() -> void:
	var nearby: Array = []
	for resident in get_tree().get_nodes_in_group("resident_placeholders"):
		if not resident is Node3D:
			continue
		var resident_node := resident as Node3D
		var resident_id: String = str(resident_node.get("resident_id"))
		var case_id: String = RealityCases.case_for_resident(resident_id)
		if case_id.is_empty() or _case_resolved(case_id):
			continue
		var distance: float = resident_node.global_position.distance_to(
				player.global_position)
		if distance <= 10.5:
			nearby.append([distance, resident_node, case_id])
	if nearby.is_empty():
		return
	nearby.sort_custom(func(a, b): return a[0] < b[0])
	var chosen: Array = nearby[0]
	var source: Node3D = chosen[1]
	var case_id: String = chosen[2]
	var signature: Dictionary = PoltergeistLibrary.signature(case_id)
	if signature.is_empty():
		return
	# Omar's infection owns the radiator system. Even before his case starts,
	# the nearest pipe answers him; after resolution it becomes ordinary heat.
	if bool(signature.get("radiator", false)):
		var radiator := _nearest_radiator(source.global_position, 8.0)
		if radiator:
			radiator.call("play_ambient_cycle", "tick", 0.42)
			source = radiator
	_play_signature(signature, source.global_position)


func _play_signature(signature: Dictionary, at: Vector3) -> void:
	var count := clampi(int(signature.get("pattern", 1)), 1, 4)
	var spacing := float(signature.get("delay", 0.0))
	if spacing <= 0.0:
		spacing = _rng.randf_range(0.22, 0.62)
	for index in count:
		var delay := spacing * index
		var pitch := float(signature.get("pitch", 1.0))
		if index % 2 == 1 and signature.has("alternate_pitch"):
			pitch = float(signature.alternate_pitch)
		get_tree().create_timer(delay, false).timeout.connect(func():
			_play_at(str(signature.sound), at, -27.0, pitch))


func _case_resolved(case_id: String) -> bool:
	var case_state := RealityState.case_state(case_id)
	return bool(case_state.get("resolved", false)) \
			or str(case_state.get("stage", "unseen")) == "resolved"


func _nearest_radiator(at: Vector3, radius: float) -> Node3D:
	var best: Node3D
	var best_distance := radius
	for radiator in get_tree().get_nodes_in_group("radiators"):
		var distance: float = radiator.global_position.distance_to(at)
		if distance < best_distance:
			best = radiator
			best_distance = distance
	return best


func _architectural_source() -> Vector3:
	var candidates: Array[Vector3] = []
	for node_id in AcousticGraphData.nodes:
		var at := AcousticGraphData.node_pos(node_id)
		var distance := at.distance_to(player.global_position)
		if distance > 4.0 and distance < 20.0:
			candidates.append(at)
	if candidates.is_empty():
		return player.global_position + Vector3(0.0, 0.5, -7.0)
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _on_sanity_intruded(_case_id: String, tier: int) -> void:
	# Intrusions already own their hero sound. This is a restrained physical
	# afterimage from the object they touched, and some intrusions stay silent.
	if _rng.randf() > 0.34 + tier * 0.09:
		return
	var at := _architectural_source()
	if sanity and sanity.intrusions and not sanity.intrusions.last_targets.is_empty():
		var target: Node3D = sanity.intrusions.last_targets[
				_rng.randi_range(0, sanity.intrusions.last_targets.size() - 1)]
		if is_instance_valid(target):
			at = target.global_position
	var key: String = ["tick", "creak", "knock", "breath"][
			clampi(tier - 1, 0, 3)]
	get_tree().create_timer(_rng.randf_range(0.4, 1.8), false).timeout.connect(
			func(): _play_at(key, at, -18.0 + tier * 1.5))


func _play_at(key: String, at: Vector3, volume_db: float,
		pitch_override := 0.0) -> void:
	var stream := PropAudio.get_stream(key)
	if stream == null:
		return
	var event := _event_players[_event_index % _event_players.size()]
	_event_index += 1
	event.stream = stream
	event.pitch_scale = pitch_override if pitch_override > 0.0 \
			else _rng.randf_range(0.92, 1.06)
	event.volume_db = volume_db
	event.global_position = at
	event.play()
