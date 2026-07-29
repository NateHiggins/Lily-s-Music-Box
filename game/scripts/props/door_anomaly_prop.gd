class_name DoorAnomalyProp
extends FunctionalProp
## The first impossible door: a door-shaped seam of light in the wall
## between the workstation and the radiator. Invisible until room
## infection is severe; then the seam breathes with the motif. No
## collision, no function yet — Room 0 comes later.

const W := 0.91
const H := 2.13

## Set by building_root: where this seam leads once it is manifest.
var room0: Room0 = null

var _mat: StandardMaterial3D
var _edges: Node3D


func _build_visual() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.05, 0.1, 0.1)
	_mat.emission_enabled = true
	_mat.emission = Color(0.34, 0.9, 0.83)
	_mat.emission_energy_multiplier = 0.0
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_edges = Node3D.new()
	add_child(_edges)
	var t := 0.012
	for spec in [[Vector3(t, H, t), Vector3(-W / 2, H / 2, 0)],
			[Vector3(t, H, t), Vector3(W / 2, H / 2, 0)],
			[Vector3(W, t, t), Vector3(0, H, 0)]]:
		var e := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[0]
		e.mesh = box
		e.position = spec[1]
		e.material_override = _mat
		_edges.add_child(e)
	var knob := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.02
	s.height = 0.04
	knob.mesh = s
	knob.position = Vector3(W / 2 - 0.07, 0.96, 0.0)
	knob.material_override = _mat
	_edges.add_child(knob)
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(W, H, 0.3)
	shape.shape = box
	shape.position = Vector3(0, H / 2, 0)
	area.add_child(shape)
	add_child(area)


func interact_prompt() -> String:
	return "[E]  The seam is warm" if is_manifest() else ""


func interact(player: Node) -> void:
	if is_manifest() and room0:
		room0.enter(player)


func _start_normal_function() -> void:
	state = PState.OPERATING


func _process(_delta: float) -> void:
	# The seam only exists once the building is saturated enough to hold it.
	var base: float = clampf((Conductor.infection - 0.75) / 0.25, 0.0, 1.0)
	_mat.emission_energy_multiplier = maxf(
			lerpf(_mat.emission_energy_multiplier, base * 1.4, 0.05), 0.0)


func is_manifest() -> bool:
	return _mat.emission_energy_multiplier > 0.2


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	if Conductor.infection > 0.75:
		_mat.emission_energy_multiplier = 1.4 + accent * 1.8
