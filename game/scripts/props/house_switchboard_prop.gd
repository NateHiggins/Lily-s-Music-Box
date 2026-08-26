class_name HouseSwitchboardProp
extends FunctionalProp
## Compact porter board. Lamps and cords present HouseTelephoneNetwork state;
## the board owns neither the caller nor the report carried over the line.

const WOOD := Color(0.16, 0.07, 0.035)
const EBONITE := Color(0.025, 0.028, 0.030)
const BRASS := Color(0.52, 0.37, 0.14)

var network: Node
var _asking_lamp: MeshInstance3D
var _cord: Node3D
var _key: Node3D


func bind_line(owner: Node) -> void:
	network = owner
	if not owner.is_connected("line_changed", _on_line_changed):
		owner.connect("line_changed", _on_line_changed)


func _build_visual() -> void:
	make_box(Vector3(0.78, 0.68, 0.16), Vector3(0, 0.34, 0), WOOD)
	make_box(Vector3(0.70, 0.55, 0.025), Vector3(0, 0.37, -0.095), EBONITE)
	_label("HOUSE  LINE", Vector3(0, 0.642, -0.116), 0.00042)
	_label("A", Vector3(-0.29, 0.485, -0.121), 0.00032)
	_label("B", Vector3(-0.29, 0.355, -0.121), 0.00032)
	_label("TRUNK", Vector3(0.20, 0.225, -0.121), 0.00025)
	for row in 3:
		for col in 6:
			var x := -0.25 + col * 0.10
			var y := 0.52 - row * 0.13
			make_cyl(0.018, 0.018, 0.018, Vector3(x, y, -0.116), BRASS, 0.30).rotation.x = PI * 0.5
	_asking_lamp = make_cyl(0.034, 0.034, 0.018,
			Vector3(-0.25, 0.58, -0.118), Color(0.18, 0.06, 0.02), 0.30)
	_asking_lamp.rotation.x = PI * 0.5
	_key = Node3D.new(); _key.position = Vector3(0.25, 0.18, -0.12); add_child(_key)
	var lever := make_box(Vector3(0.025, 0.13, 0.025), Vector3.ZERO, BRASS)
	remove_child(lever); _key.add_child(lever); lever.position.y = 0.06
	_cord = Node3D.new(); add_child(_cord)
	for i in 9:
		# Nine short, overlapping cloth-covered lengths make one slack U. The
		# end plugs stay high and the bight hangs low; a straight cord would
		# read like a painted rule rather than a circuit under custody.
		var drop := make_cyl(0.012, 0.012, 0.064,
				Vector3(-0.24 + i * 0.06, 0.055 + abs(i - 4) * 0.034, -0.135),
				Color(0.34, 0.075, 0.035), 0.72)
		remove_child(drop); _cord.add_child(drop); drop.rotation.z = PI * 0.5
	_cord.visible = false


func _label(words: String, at: Vector3, scale: float) -> void:
	var label := Label3D.new()
	label.text = words
	label.font_size = 72
	label.pixel_size = scale
	label.modulate = Color(0.88, 0.78, 0.55)
	label.outline_size = 4
	label.outline_modulate = Color(0.015, 0.012, 0.008, 0.9)
	label.position = at
	label.rotation.y = PI
	add_child(label)


func _start_normal_function() -> void:
	state = PState.IDLE


func interact_prompt() -> String:
	if network == null: return "[E] Read the dead house board"
	var line: Dictionary = network.call("snapshot")
	match str(line.state):
		"ASKING": return "[E] Answer the asking line"
		"ANSWERED": return "[E] Carry the line to the house trunk"
		"CARRYING": return "[E] Release the carried line"
		_: return "[E] Read the quiet house board"


func interact(_actor: Node = null) -> Dictionary:
	if network == null: return {"action":"board_read", "accepted":false}
	var line: Dictionary = network.call("snapshot")
	var accepted := false
	match str(line.state):
		"ASKING": accepted = bool(network.call("answer", "house_board"))
		"ANSWERED": accepted = bool(network.call("carry", "outside_trunk"))
		"CARRYING": accepted = bool(network.call("release", "house_board"))
	return {"action":"board_operate", "accepted":accepted,
			"line":network.call("snapshot")}


func _on_line_changed(line: Dictionary) -> void:
	var phase := str(line.get("state", "IDLE"))
	if _asking_lamp != null:
		_asking_lamp.material_override = _pmat(Color(1.0, 0.28, 0.035)
				if phase == "ASKING" else Color(0.18, 0.06, 0.02))
	if _cord != null: _cord.visible = phase == "CARRYING"
	if _key != null: _key.rotation.z = -0.42 if phase in ["ANSWERED", "CARRYING"] else 0.0
