class_name DartsProp
extends FunctionalProp
## The pot of darts on the ledge beside the oche.
##
## The BOARD is 2.37 m away by regulation, which is well past anybody's
## reach, so the thing the player presses E on is the darts themselves —
## you pick them up where they live, which is also where you stand to
## throw. The board is geometry in gen_layout; this is the handle on it.

signal started

var _pot: MeshInstance3D
var _panel: Node
var _clink: AudioStreamPlayer3D


func _build_visual() -> void:
	# A chipped pint glass with three darts in it, which is where darts
	# live in every bar that has them.
	_pot = make_box(Vector3(0.075, 0.10, 0.075), Vector3(0, 0.05, 0),
			Color(0.72, 0.76, 0.74))
	var gm := _pot.material_override as StandardMaterial3D
	gm.roughness = 0.18
	gm.metallic = 0.0
	for i in 3:
		var d := make_box(Vector3(0.008, 0.16, 0.008),
				Vector3(-0.018 + i * 0.018, 0.12, 0.004 * i),
				Color(0.55, 0.55, 0.60) if i != 1
				else Color(0.72, 0.62, 0.28))
		d.rotation.z = deg_to_rad(-7.0 + i * 6.0)
	# Flights, in three different colours because they are three
	# different darts somebody left behind.
	# (No tuple unpacking in a GDScript for loop — index the array.)
	var flights := [Color("c8352b"), Color("2f8f86"), Color("e3b02f")]
	for i in flights.size():
		make_box(Vector3(0.026, 0.030, 0.002),
				Vector3(-0.018 + i * 0.018, 0.196, 0.004 * i),
				flights[i])
	_clink = make_emitter("tick", -14.0)


func interact_prompt() -> String:
	return "[E]  Play darts  —  301"


func interact(player: Node) -> void:
	if _panel and is_instance_valid(_panel):
		return
	if _clink:
		_clink.play()
	var scr: GDScript = load("res://scripts/ui/darts_panel.gd")
	_panel = scr.new()
	_panel.open(player, self)
	get_tree().current_scene.add_child(_panel)
	started.emit()


func panel_closed() -> void:
	_panel = null
