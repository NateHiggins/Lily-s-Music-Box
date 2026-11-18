extends Node3D
## Spatial playback for the Harukiya stage. The cast samples the player clock.
const Score := preload("res://scripts/characters/harukiya_show_score.gd")

signal played_at(seconds: float)
signal ended

var score := Score.new()
var _player: AudioStreamPlayer3D
var _running := false


func _ready() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.stream = Score.SONG
	_player.bus = &"Diegetic"
	_player.unit_size = 4.0
	_player.max_distance = 26.0
	_player.volume_db = -8.0
	_player.finished.connect(stop)
	add_child(_player)
	set_process(false)


func prepare() -> bool:
	return score.duration > 0.0 or score.load_score()


func start() -> bool:
	if _running or not is_instance_valid(_player) or not prepare():
		return false
	_running = true
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


func _process(_delta: float) -> void:
	if _player.playing:
		played_at.emit(clampf(_player.get_playback_position(), 0.0, score.duration))
