class_name DoorOutline
extends Node2D
## The spatial anomaly for the "Complete" outcome: a door-shaped seam of
## light that was never in the wall. Hidden until reveal().

const W := 130.0
const H := 290.0
const GLOW := Color(0.34, 0.9, 0.83)

var _alpha := 0.0
var _flicker_t := 0.0
var _revealed := false


func _process(delta: float) -> void:
	if not _revealed:
		return
	_flicker_t += delta
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.001:
		return
	var a := _alpha * (0.85 + 0.15 * sin(_flicker_t * 7.3))
	var c := Color(GLOW.r, GLOW.g, GLOW.b, a)
	var rect := Rect2(-W / 2.0, -H, W, H)
	draw_rect(rect, c, false, 3.0)
	draw_rect(rect.grow(-14.0), Color(c.r, c.g, c.b, a * 0.4), false, 1.5)
	draw_circle(Vector2(W / 2.0 - 24.0, -H * 0.45), 4.0, c)  # handle
	# faint spill of light under the seam
	draw_rect(Rect2(-W / 2.0 - 8, -4, W + 16, 4), Color(c.r, c.g, c.b, a * 0.3))


func reveal() -> void:
	_revealed = true
	var tw := create_tween()
	tw.tween_method(func(v): _alpha = v, 0.0, 0.9, 3.5).set_trans(Tween.TRANS_SINE)


func reset() -> void:
	_revealed = false
	_alpha = 0.0
	queue_redraw()
