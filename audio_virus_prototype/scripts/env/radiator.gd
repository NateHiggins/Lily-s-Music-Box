class_name RadiatorProp
extends Node2D
## Flat-color radiator that physically shakes on knock events — the wall is
## answering, and the player should *see* it before they trust their ears.

var _shake := 0.0
var _rng := RandomNumberGenerator.new()
var _rest := Vector2.ZERO


func _ready() -> void:
	_rest = position
	_rng.randomize()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-80, 56, 160, 8), Color(0.1, 0.09, 0.1))  # base shadow
	for i in 7:
		var x := -76 + i * 22
		draw_rect(Rect2(x, -50, 16, 106), Color(0.32, 0.3, 0.29))
		draw_rect(Rect2(x, -50, 16, 8), Color(0.4, 0.38, 0.36))
	draw_rect(Rect2(-80, -58, 160, 6), Color(0.36, 0.34, 0.32))  # top rail
	draw_rect(Rect2(76, -30, 10, 14), Color(0.3, 0.28, 0.26))    # valve
	draw_rect(Rect2(80, -100, 8, 70), Color(0.3, 0.28, 0.27))    # pipe up the wall


func knock(strength: float) -> void:
	_shake = maxf(_shake, clampf(strength, 0.0, 1.0) * 3.5)


func _process(delta: float) -> void:
	if _shake > 0.01:
		position = _rest + Vector2(_rng.randf_range(-_shake, _shake), _rng.randf_range(-_shake, _shake))
		_shake = maxf(_shake - delta * 14.0, 0.0)
	elif position != _rest:
		position = _rest
