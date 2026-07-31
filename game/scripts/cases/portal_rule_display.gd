class_name PortalRuleDisplay
extends Node3D
## Durable storage-room record of the practical laws residents recover.

var _rules: Label3D


func _ready() -> void:
	name = "AcceptedRealityRules"
	var board := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.55, 1.05, 0.055)
	board.mesh = mesh
	var material := MatLib.get_mat(
			"wood_dark", Color(0.38, 0.29, 0.22), 0.75)
	board.material_override = material
	add_child(board)
	var header := _label("REALITY MAINTENANCE\nACCEPTED LOCAL EXCEPTIONS",
			Vector3(0, 0.36, 0.036), 24, Color(0.82, 0.68, 0.40))
	header.outline_size = 5
	_rules = _label("", Vector3(0, -0.06, 0.036), 22,
			Color(0.82, 0.86, 0.79))
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules.width = 620
	RealityState.state_changed.connect(_refresh)
	_refresh()


func _label(value: String, at: Vector3, size: int,
		color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = at
	label.font_size = size
	label.pixel_size = 0.002
	label.modulate = color
	label.outline_size = 7
	label.outline_modulate = Color(0.015, 0.012, 0.01, 0.95)
	add_child(label)
	return label


func _refresh() -> void:
	var rules: Array = RealityState.data.get("portal_rules", [])
	if rules.is_empty():
		_rules.text = "NO EXCEPTIONS ACCEPTED\nDO NOT FEED THE APERTURE"
		_rules.modulate = Color(0.56, 0.57, 0.53)
		return
	var lines := PackedStringArray()
	for index in rules.size():
		lines.append("%02d  %s" % [index + 1, str(rules[index]).to_upper()])
	_rules.text = "\n".join(lines)
	_rules.modulate = Color(0.82, 0.86, 0.79)
