class_name PorchDeckProp
extends FunctionalProp
## The rear wooden porch deck: a lossy, drifting structural path. Motif
## events arrive softened and late through the wall coupling with the
## B-stack radiators, and the deck answers in timber — creaks on light
## accents, a board knock on heavy ones.

var _creak: AudioStreamPlayer3D
var _board: AudioStreamPlayer3D


func _build_visual() -> void:
	_creak = make_emitter("creak", -14.0)
	_board = make_emitter("thud", -16.0)
	_board.pitch_scale = 1.6


func _start_normal_function() -> void:
	state = PState.OPERATING
	_wind_loop()


func _wind_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(rng.randf_range(25.0, 60.0), false).timeout
		if is_inside_tree() and state == PState.OPERATING:
			_creak.pitch_scale = rng.randf_range(0.8, 1.15)
			_creak.volume_db = -20.0
			_creak.play()


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	if accent > 0.75:
		_board.volume_db = -16.0 + linear_to_db(accent)
		_board.play()
	else:
		_creak.pitch_scale = rng.randf_range(0.85, 1.1)
		_creak.volume_db = -14.0 + linear_to_db(clampf(accent, 0.2, 1.0))
		_creak.play()
