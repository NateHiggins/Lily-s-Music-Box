extends Node3D
## Spatial playback for the Harukiya stage. The cast samples the player clock.
const Score := preload("res://scripts/characters/harukiya_show_score.gd")
const Timing := preload("res://scripts/characters/harukiya_ensemble_timing.gd")

signal played_at(seconds: float)
signal ended

var score := Score.new()
var _player: AudioStreamPlayer3D
var _running := false
var _movie := false
var _frame := 0
var _fps := 0
var _latency := 0.0
var _seconds := 0.0


func _ready() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.stream = Score.SONG
	_player.bus = &"Diegetic"
	_player.unit_size = 4.0
	_player.max_distance = 26.0
	_player.volume_db = -8.0
	_player.finished.connect(_stream_finished)
	add_child(_player)
	set_process(false)


func prepare() -> bool:
	return score.duration > 0.0 or score.load_score()


func start() -> bool:
	if _running or not is_instance_valid(_player) or not prepare():
		return false
	_running = true
	_movie = not Engine.get_write_movie_path().is_empty()
	_frame = 0
	_fps = 0
	_seconds = 0.0
	_latency = 0.0 if _movie else AudioServer.get_output_latency()
	_player.play()
	set_process(true)
	return true


func stop() -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	_player.stop()
	ended.emit()


func _stream_finished() -> void:
	if not _movie and _running:
		played_at.emit(score.duration)
		stop()


func _process(delta: float) -> void:
	if not _running:
		return
	if _movie:
		# MovieWriter supplies a fixed simulation step even when encoding a frame
		# takes seconds. Recover its integer fps, including command-line overrides.
		if _fps == 0:
			if delta <= 0.0 or Engine.time_scale <= 0.0:
				return
			_fps = maxi(1, roundi(Engine.time_scale / delta))
		_seconds = Timing.frame_seconds(_frame, _fps, score.duration)
		_frame += 1
		played_at.emit(_seconds)
		if _seconds >= score.duration:
			stop()
	elif _player.playing:
		_seconds = Timing.audible_seconds(_seconds, _player.get_playback_position(),
				AudioServer.get_time_since_last_mix(), _latency, score.duration)
		played_at.emit(_seconds)
