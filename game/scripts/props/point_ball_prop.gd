class_name PointBallProp
extends FunctionalProp
## The chalk on the rail. What you press E on to play Point Ball.
##
## The table itself is geometry — two metres of it — so an interactable
## anywhere on it would be a two-metre-wide button. The chalk is where
## a hand goes anyway.

var _panel: Node
var _tap: AudioStreamPlayer3D


func _build_visual() -> void:
	# A cube of blue chalk, worn into a dish, and the triangle leaning
	# on the rail beside it.
	make_box(Vector3(0.026, 0.022, 0.026), Vector3(0, 0.011, 0),
			Color(0.20, 0.34, 0.52))
	make_box(Vector3(0.020, 0.004, 0.020), Vector3(0, 0.023, 0),
			Color(0.14, 0.24, 0.40))
	_tap = make_emitter("tick", -16.0)


func interact_prompt() -> String:
	return "[E]  Point Ball  —  they took the 8"


func interact(player: Node) -> void:
	if _panel and is_instance_valid(_panel):
		return
	if _tap:
		_tap.play()
	var scr: GDScript = load("res://scripts/ui/point_ball_panel.gd")
	_panel = scr.new()
	_panel.open(player, self, "Cam")
	get_tree().current_scene.add_child(_panel)


func panel_closed() -> void:
	_panel = null
