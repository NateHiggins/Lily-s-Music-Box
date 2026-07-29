class_name DeskLamp
extends Node2D
## Flat-color desk lamp whose glow pulses with motif accents. The glow is a
## radial gradient sprite so brightness reads at a glance in a dark room.

var _glow: Sprite2D
var _base_alpha := 0.55
var _pulse_tween: Tween


func _ready() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.55, 0.9))
	grad.set_color(1, Color(1.0, 0.75, 0.4, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_glow = Sprite2D.new()
	_glow.texture = tex
	_glow.position = Vector2(0, -46)
	_glow.scale = Vector2(1.4, 1.4)
	_glow.modulate.a = _base_alpha
	add_child(_glow)
	queue_redraw()


func _draw() -> void:
	# Stand, arm and shade in flat placeholder colors.
	draw_rect(Rect2(-16, 26, 32, 6), Color(0.14, 0.12, 0.1))
	draw_rect(Rect2(-3, -30, 6, 56), Color(0.2, 0.17, 0.14))
	draw_colored_polygon(
		PackedVector2Array([Vector2(-26, -30), Vector2(26, -30), Vector2(14, -56), Vector2(-14, -56)]),
		Color(0.24, 0.2, 0.16)
	)


func pulse(strength: float) -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_glow.modulate.a = clampf(_base_alpha + strength * 0.45, 0.0, 1.0)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_glow, "modulate:a", _base_alpha, 0.3)


func set_base(alpha: float) -> void:
	_base_alpha = clampf(alpha, 0.0, 1.0)
	_glow.modulate.a = _base_alpha


## Brown-out for the "Complete" outcome: dark, stutter, recover.
func power_flicker() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_glow, "modulate:a", 0.02, 0.08)
	_pulse_tween.tween_interval(0.5)
	_pulse_tween.tween_property(_glow, "modulate:a", _base_alpha, 0.05)
	_pulse_tween.tween_property(_glow, "modulate:a", 0.05, 0.06)
	_pulse_tween.tween_property(_glow, "modulate:a", _base_alpha, 0.4)
