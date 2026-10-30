class_name NewspaperAdMark
extends Control
## A firm's registered mark: initials set live inside a ruled device.

const INK := Color(0.11, 0.098, 0.086)
const FACE := preload("res://assets/fonts/librebodoni/LibreBodoni[wght].ttf")

var initials := ""
var shape := "ring"


func _draw() -> void:
	var middle := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 1.5
	match shape:
		"diamond":
			_outline([middle + Vector2(0, -radius), middle + Vector2(radius, 0),
					middle + Vector2(0, radius), middle + Vector2(-radius, 0)])
		"shield":
			_outline([middle + Vector2(-radius, -radius), middle + Vector2(radius, -radius),
					middle + Vector2(radius, radius * 0.25), middle + Vector2(0, radius),
					middle + Vector2(-radius, radius * 0.25)])
		"oval":
			draw_set_transform(middle, 0.0, Vector2(1.0, 0.72))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, INK, 2.0, true)
			draw_set_transform(Vector2.ZERO)
		_:
			draw_arc(middle, radius, 0.0, TAU, 40, INK, 2.0, true)
			draw_arc(middle, radius - 3.5, 0.0, TAU, 40, INK, 1.0, true)
	var font_size := int(radius * (1.0 if initials.length() <= 1 else 0.72 if initials.length() == 2 else 0.5))
	var width := FACE.get_string_size(initials, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := middle.y + FACE.get_ascent(font_size) * 0.36
	draw_string(FACE, Vector2(middle.x - width * 0.5, baseline), initials, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)


func _outline(points: Array) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, INK, 2.0, true)
