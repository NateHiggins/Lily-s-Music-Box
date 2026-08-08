class_name DeadLettersProp
extends FunctionalProp
## The tray of unsorted post on the ledge under the mail bank.
##
## The bank itself is a wall of twenty-four doors and one of them is
## yours — reaching for the whole wall would fight with that. The TRAY
## is the handle: somebody leaves it there, and sorting it is the sort
## of favour an operator ends up doing at the start of a shift because
## nobody else is going to.

var _panel: Node
var _rustle: AudioStreamPlayer3D


func _build_visual() -> void:
	# A shallow wire tray with a wad of envelopes in it, leaning.
	make_box(Vector3(0.34, 0.012, 0.24), Vector3(0, 0.006, 0),
			Color(0.32, 0.31, 0.30))
	for s in [-1.0, 1.0]:
		make_box(Vector3(0.34, 0.05, 0.010),
				Vector3(0, 0.030, s * 0.115), Color(0.32, 0.31, 0.30))
	make_box(Vector3(0.010, 0.05, 0.24), Vector3(-0.165, 0.030, 0),
			Color(0.32, 0.31, 0.30))
	# The post: a leaning stack in three papers, none of them white.
	var papers := [Color(0.86, 0.83, 0.74), Color(0.80, 0.78, 0.72),
			Color(0.74, 0.70, 0.60)]
	for i in papers.size():
		var e := make_box(Vector3(0.30 - i * 0.012, 0.016,
				0.19 - i * 0.010),
				Vector3(-0.004 * i, 0.020 + i * 0.014, 0.004 * i),
				papers[i])
		e.rotation.y = deg_to_rad(-4.0 + i * 3.5)
	_rustle = make_emitter("tick", -18.0)


func interact_prompt() -> String:
	return "[E]  Sort the post"


func interact(player: Node) -> void:
	if _panel and is_instance_valid(_panel):
		return
	if _rustle:
		_rustle.play()
	var scr: GDScript = load("res://scripts/ui/dead_letters_panel.gd")
	_panel = scr.new()
	_panel.open(player, self)
	get_tree().current_scene.add_child(_panel)


func panel_closed() -> void:
	_panel = null
