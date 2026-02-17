extends Node2D

var data: Dictionary

func setup(remnant: Dictionary) -> void:
	data = remnant
	global_position = Vector2(remnant["position"]["x"], remnant["position"]["y"])
	queue_redraw()

func _draw() -> void:
	var color := Color(0.8, 0.5, 0.8, 0.8)
	match data.get("aura_color", "Pink"):
		"Blue": color = Color(0.5, 0.7, 1.0, 0.8)
		"Lavender": color = Color(0.7, 0.6, 0.95, 0.8)
	draw_circle(Vector2.ZERO, 10, color)
	draw_arc(Vector2.ZERO, 14, 0, TAU, 16, Color(0.2, 0.2, 0.25, 0.8), 2)
