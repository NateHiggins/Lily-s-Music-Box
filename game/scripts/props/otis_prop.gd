class_name OtisProp
extends FunctionalProp
## The porter's board, on the lobby wall by the lift.
##
## A brass annunciator with a lamp per landing — the thing a porter
## would have watched all night when the building still had one. There
## has not been a porter in years, which is why the board is yours.

var _panel: Node
var _clack: AudioStreamPlayer3D
var _lamps: Array = []
var _t := 0.0


func _build_visual() -> void:
	# Mahogany case, brass face, eight little windows in a column.
	make_box(Vector3(0.26, 0.62, 0.06), Vector3(0, 0, 0),
			Color(0.26, 0.15, 0.09))
	var face := make_box(Vector3(0.21, 0.55, 0.012),
			Vector3(0, 0, 0.036), Color(0.55, 0.44, 0.20))
	var fm := face.material_override as StandardMaterial3D
	fm.metallic = 0.65
	fm.roughness = 0.38
	for i in 8:
		var lamp := make_box(Vector3(0.055, 0.035, 0.008),
				Vector3(-0.055, 0.235 - i * 0.063, 0.044),
				Color(0.30, 0.26, 0.16))
		_lamps.append(lamp.material_override as StandardMaterial3D)
		make_box(Vector3(0.075, 0.030, 0.006),
				Vector3(0.040, 0.235 - i * 0.063, 0.042),
				Color(0.78, 0.74, 0.66))
	_clack = make_emitter("tick", -12.0)


func interact_prompt() -> String:
	return "[E]  Work the lift"


func interact(player: Node) -> void:
	if _panel and is_instance_valid(_panel):
		return
	if _clack:
		_clack.play()
	var scr: GDScript = load("res://scripts/ui/otis_panel.gd")
	_panel = scr.new()
	_panel.open(player, self)
	get_tree().current_scene.add_child(_panel)


func panel_closed() -> void:
	_panel = null


func _process(delta: float) -> void:
	# One lamp wanders up and down the column: the car, still running
	# whether or not anybody is watching the board.
	_t += delta
	if _lamps.is_empty():
		return
	var n := _lamps.size()
	var k := int(fmod(_t * 0.55, float(n * 2 - 2)))
	if k >= n:
		k = (n * 2 - 2) - k
	for i in n:
		var m: StandardMaterial3D = _lamps[i]
		var on: bool = i == k
		m.albedo_color = Color(0.95, 0.72, 0.34) if on \
				else Color(0.30, 0.26, 0.16)
		m.emission_enabled = on
		if on:
			m.emission = Color(0.95, 0.72, 0.34)
			m.emission_energy_multiplier = 1.6
