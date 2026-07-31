class_name VirusSoundDirector
extends Node3D
## Plays the authored viral seed and translates its offline analysis into
## deterministic building events. Intro mode reverses a departure: outside,
## through the lobby, up the lift, back into 4B, ending at the incoming call.

const AUDIO := preload("res://assets/audio/viral_seed.ogg")
const FEATURES := "res://data/viral_seed_features.json"
const BAND_ORIGINS := {
	"sub": "B1_BOILER_01",
	"low": "F04_B_RADIATOR_01",
	"mid": "F04_CORRLIGHT_S",
	"high": "F04_B_MONITOR_01",
	"air": "F03_D_SPEAKER_01",
}
const BAND_PITCH := {
	"sub": -9.0, "low": -5.0, "mid": 0.0, "high": 5.0, "air": 10.0,
}
const INTRO_END := 30.35
const INTRO_ROUTE := [
	{"t": 0.0, "p": Vector3(0.0, 0.12, 17.2)},
	{"t": 2.2, "p": Vector3(0.0, 0.12, 16.7)},
	{"t": 5.4, "p": Vector3(0.0, 0.12, 12.1)},
	{"t": 8.0, "p": Vector3(0.0, 0.12, 9.0)},
	{"t": 10.6, "p": Vector3(1.9, 0.12, 7.0)},
	{"t": 12.0, "p": Vector3(1.9, 0.12, 5.65)},
	{"t": 17.0, "p": Vector3(1.9, 9.72, 5.65)},
	{"t": 19.0, "p": Vector3(0.0, 9.72, 4.3)},
	{"t": 23.0, "p": Vector3(-4.9, 9.72, -3.85)},
	{"t": 26.0, "p": Vector3(-6.45, 9.72, -3.9)},
	{"t": 28.4, "p": Vector3(-8.0, 9.72, -4.55)},
	{"t": INTRO_END, "p": Vector3(-9.15, 9.72, -5.50)},
]
## Deliberate, smoothly interpolated attention: architecture first, then
## nervous checks behind and beside the player, finally the desk display.
const INTRO_LOOKS := [
	{"t": 0.0, "p": Vector3(0.0, 5.8, 7.0)},
	{"t": 3.0, "p": Vector3(0.0, 2.5, 9.5)},
	{"t": 7.5, "p": Vector3(-2.7, 1.7, 7.2)},
	{"t": 9.5, "p": Vector3(0.0, 5.8, 0.0)},
	{"t": 11.5, "p": Vector3(1.9, 1.3, 5.2)},
	{"t": 15.0, "p": Vector3(1.9, 10.8, 5.2)},
	{"t": 19.5, "p": Vector3(-2.0, 10.5, 2.0)},
	{"t": 22.0, "p": Vector3(0.0, 10.3, 4.3)},
	{"t": 24.5, "p": Vector3(-6.6, 10.4, -4.0)},
	{"t": 27.2, "p": Vector3(-7.2, 10.4, -7.0)},
	{"t": INTRO_END, "p": Vector3(-8.05, 10.36, -5.50)},
]

var building: Node3D
var active := false
var intro_active := false
var current_features: Dictionary = {}

var _player: AudioStreamPlayer3D
var _frames: Array = []
var _events: Array = []
var _frame_cursor := 0
var _event_cursor := 0
var _elapsed := 0.0
var _previous_infection := 0.15
var _previous_noclip := false
var _previous_call_locked := false
var _camera_home := Vector3(0, 1.62, 0)


func setup(root: Node3D) -> void:
	building = root


func _ready() -> void:
	var file := FileAccess.open(FEATURES, FileAccess.READ)
	if file:
		var data: Dictionary = JSON.parse_string(file.get_as_text())
		_frames = data.get("frames", [])
		_events = data.get("events", [])
	else:
		push_warning("viral seed feature map missing")
	_player = AudioStreamPlayer3D.new()
	_player.name = "ViralSeedEmitter"
	_player.stream = AUDIO
	_player.volume_db = -5.0
	_player.unit_size = 5.5
	_player.max_distance = 42.0
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_player)


func start_seed(as_intro := false) -> void:
	if active:
		stop_seed()
	active = true
	intro_active = as_intro
	_elapsed = 0.0
	_frame_cursor = 0
	_event_cursor = 0
	_previous_infection = Conductor.infection
	Conductor.infection = maxf(Conductor.infection, 0.82)
	if intro_active and building and building.player:
		_previous_noclip = building.player.noclip
		_previous_call_locked = building.player.call_locked
		building.player.noclip = true
		building.player.call_locked = true
		building.player.collision_layer = 0
		building.player.collision_mask = 0
		building.player.global_position = INTRO_ROUTE[0].p
		_camera_home = building.player.camera.position
		building.player.camera.rotation = Vector3.ZERO
	global_position = _sample_route(1.0) if intro_active \
			else AcousticGraphData.node_pos("F04_B_MONITOR_01")
	_player.volume_db = -14.0 if intro_active else -5.0
	_player.play()
	Conductor.viral_seed_state.emit(true)


func stop_seed() -> void:
	if not active:
		return
	active = false
	_player.stop()
	Conductor.infection = _previous_infection
	if intro_active and building and building.player:
		building.player.noclip = _previous_noclip
		building.player.call_locked = _previous_call_locked
		building.player.collision_layer = 0 if _previous_noclip else 1
		building.player.collision_mask = 0 if _previous_noclip else 1
		building.player.velocity = Vector3.ZERO
		building.player.camera.position = _camera_home
		building.player.camera.rotation = Vector3.ZERO
	intro_active = false
	current_features = {}
	Conductor.viral_seed_state.emit(false)


func toggle_intro() -> void:
	if active:
		stop_seed()
	else:
		start_seed(true)


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed = _player.get_playback_position()
	if intro_active and _elapsed >= INTRO_END:
		_finish_intro()
		return
	if not _player.playing:
		stop_seed()
		return
	while _frame_cursor + 1 < _frames.size() \
			and float(_frames[_frame_cursor + 1].time) <= _elapsed:
		_frame_cursor += 1
	if not _frames.is_empty():
		current_features = _frames[_frame_cursor]
		Conductor.viral_seed_frame.emit(current_features)
	while _event_cursor < _events.size() \
			and float(_events[_event_cursor].time) <= _elapsed:
		_transmit(_events[_event_cursor], _event_cursor)
		_event_cursor += 1
	if intro_active:
		_animate_intro(delta)


func _transmit(event: Dictionary, index: int) -> void:
	var band: String = event.get("band", "mid")
	var origin: String = BAND_ORIGINS.get(band, "F04_CORRLIGHT_S")
	var strength: float = float(event.get("strength", 0.5))
	var pan: float = float(event.get("pan", 0.0))
	## Stereo position adds a small pitch disagreement: remote fixtures do
	## not merely flash; they reproduce the spatial argument in the seed.
	var pitch: float = float(BAND_PITCH.get(band, 0.0)) + pan * 1.5
	AcousticGraphData.propagate(origin, index, strength, pitch)


func _animate_intro(delta: float) -> void:
	if building == null or building.player == null:
		return
	var player: PlayerController = building.player
	var desired := _sample_route(_elapsed)
	var ahead := _sample_route(minf(_elapsed + 0.18, INTRO_END))
	global_position = ahead
	player.global_position = player.global_position.lerp(
			desired, clampf(delta * 7.0, 0.0, 1.0))
	player.velocity = Vector3.ZERO
	var look := _sample_look(_elapsed)
	var direction := (look - player.camera.global_position).normalized()
	var desired_yaw := atan2(-direction.x, -direction.z)
	var desired_pitch := -atan2(direction.y,
			Vector2(direction.x, direction.z).length())
	player.rotation.y = lerp_angle(player.rotation.y, desired_yaw,
			1.0 - exp(-delta * 3.2))
	player.camera.rotation.x = lerp_angle(player.camera.rotation.x,
			clampf(desired_pitch, -0.9, 0.8), 1.0 - exp(-delta * 3.8))
	# Hurried but human: heel cadence and restrained lateral weight shift.
	# The lift interval becomes almost still, retaining only nervous breath.
	var walking := not (_elapsed >= 12.0 and _elapsed <= 17.0)
	var cadence := 8.7 if walking else 1.5
	var bob := sin(_elapsed * cadence) * (0.035 if walking else 0.008)
	var sway := sin(_elapsed * cadence * 0.5) * (0.018 if walking else 0.004)
	player.camera.position = _camera_home + Vector3(sway, bob, 0)
	# The mix rises toward the desk, then is severed rather than faded.
	_player.volume_db = lerpf(-14.0, -1.0,
			pow(clampf(_elapsed / INTRO_END, 0.0, 1.0), 0.72))


func _finish_intro() -> void:
	if building and building.player:
		building.player.global_position = INTRO_ROUTE[-1].p
		var monitor: Node = building.get_node_or_null("F04_B_MONITOR_01")
		if monitor and monitor.has_method("show_incoming_call"):
			monitor.show_incoming_call()
	# Hard cut: no score tail. Prop loops, pipes, lamps and room tone remain.
	_player.stop()
	stop_seed()


func _sample_route(time: float) -> Vector3:
	if time <= float(INTRO_ROUTE[0].t):
		return INTRO_ROUTE[0].p
	for index in range(1, INTRO_ROUTE.size()):
		var right: Dictionary = INTRO_ROUTE[index]
		if time <= float(right.t):
			var left: Dictionary = INTRO_ROUTE[index - 1]
			var weight := inverse_lerp(float(left.t), float(right.t), time)
			weight = smoothstep(0.0, 1.0, weight)
			return (left.p as Vector3).lerp(right.p, weight)
	return INTRO_ROUTE[-1].p


func _sample_look(time: float) -> Vector3:
	if time <= float(INTRO_LOOKS[0].t):
		return INTRO_LOOKS[0].p
	for index in range(1, INTRO_LOOKS.size()):
		var right: Dictionary = INTRO_LOOKS[index]
		if time <= float(right.t):
			var left: Dictionary = INTRO_LOOKS[index - 1]
			var weight := smoothstep(0.0, 1.0,
					inverse_lerp(float(left.t), float(right.t), time))
			return (left.p as Vector3).lerp(right.p, weight)
	return INTRO_LOOKS[-1].p
