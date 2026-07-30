class_name VirusSoundDirector
extends Node3D
## Plays the authored viral seed and translates its offline analysis into
## deterministic building events. Debug lure mode stages the opening journey:
## the sound stays just ahead while the director draws the player to 4B.

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
## Times and positions form a debug cinematic path from the front door,
## through the lift, down floor four's corridor and into the player's room.
const LURE_ROUTE := [
	{"t": 0.0, "p": Vector3(0.0, 0.12, 9.0)},
	{"t": 4.0, "p": Vector3(1.9, 0.12, 7.2)},
	{"t": 7.0, "p": Vector3(1.9, 0.12, 5.65)},
	{"t": 12.0, "p": Vector3(1.9, 9.72, 5.65)},
	{"t": 15.0, "p": Vector3(0.0, 9.72, 4.3)},
	{"t": 20.0, "p": Vector3(-4.9, 9.72, -3.85)},
	{"t": 24.0, "p": Vector3(-6.45, 9.72, -3.9)},
	{"t": 30.0, "p": Vector3(-10.2, 9.72, -4.8)},
]

var building: Node3D
var active := false
var lure_active := false
var current_features: Dictionary = {}

var _player: AudioStreamPlayer3D
var _frames: Array = []
var _events: Array = []
var _frame_cursor := 0
var _event_cursor := 0
var _elapsed := 0.0
var _previous_infection := 0.15
var _previous_noclip := false


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


func start_seed(with_debug_lure := false) -> void:
	if active:
		stop_seed()
	active = true
	lure_active = with_debug_lure
	_elapsed = 0.0
	_frame_cursor = 0
	_event_cursor = 0
	_previous_infection = Conductor.infection
	Conductor.infection = maxf(Conductor.infection, 0.82)
	if lure_active and building and building.player:
		_previous_noclip = building.player.noclip
		building.player.noclip = true
		building.player.collision_layer = 0
		building.player.collision_mask = 0
		building.player.global_position = LURE_ROUTE[0].p
	global_position = _sample_route(1.25) if lure_active \
			else AcousticGraphData.node_pos("F04_B_MONITOR_01")
	_player.play()
	Conductor.viral_seed_state.emit(true)


func stop_seed() -> void:
	if not active:
		return
	active = false
	_player.stop()
	Conductor.infection = _previous_infection
	if lure_active and building and building.player:
		building.player.noclip = _previous_noclip
		building.player.collision_layer = 0 if _previous_noclip else 1
		building.player.collision_mask = 0 if _previous_noclip else 1
		building.player.velocity = Vector3.ZERO
	lure_active = false
	current_features = {}
	Conductor.viral_seed_state.emit(false)


func toggle_debug_lure() -> void:
	if active:
		stop_seed()
	else:
		start_seed(true)


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed = _player.get_playback_position()
	if not _player.playing:
		if lure_active and building and building.player:
			building.player.global_position = LURE_ROUTE[-1].p
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
	if lure_active:
		_guide_player(delta)


func _transmit(event: Dictionary, index: int) -> void:
	var band: String = event.get("band", "mid")
	var origin: String = BAND_ORIGINS.get(band, "F04_CORRLIGHT_S")
	var strength: float = float(event.get("strength", 0.5))
	var pan: float = float(event.get("pan", 0.0))
	## Stereo position adds a small pitch disagreement: remote fixtures do
	## not merely flash; they reproduce the spatial argument in the seed.
	var pitch: float = float(BAND_PITCH.get(band, 0.0)) + pan * 1.5
	AcousticGraphData.propagate(origin, index, strength, pitch)


func _guide_player(delta: float) -> void:
	if building == null or building.player == null:
		return
	var player: PlayerController = building.player
	var desired := _sample_route(_elapsed)
	var beacon := _sample_route(minf(_elapsed + 1.25, 30.0))
	global_position = beacon
	## A critically soft pull leaves a trace of pursuit instead of reading
	## as a teleport. Noclip is debug-only so the lift transition is testable.
	player.global_position = player.global_position.lerp(
			desired, clampf(delta * 2.8, 0.0, 1.0))
	player.velocity = Vector3.ZERO
	var flat_target := Vector3(beacon.x, player.global_position.y, beacon.z)
	if player.global_position.distance_squared_to(flat_target) > 0.05:
		player.look_at(flat_target, Vector3.UP, true)


func _sample_route(time: float) -> Vector3:
	if time <= float(LURE_ROUTE[0].t):
		return LURE_ROUTE[0].p
	for index in range(1, LURE_ROUTE.size()):
		var right: Dictionary = LURE_ROUTE[index]
		if time <= float(right.t):
			var left: Dictionary = LURE_ROUTE[index - 1]
			var weight := inverse_lerp(float(left.t), float(right.t), time)
			weight = smoothstep(0.0, 1.0, weight)
			return (left.p as Vector3).lerp(right.p, weight)
	return LURE_ROUTE[-1].p
