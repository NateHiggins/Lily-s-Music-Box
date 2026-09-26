extends Node3D
## Presentation of the existing lift. No independent travel or fault authority.
const Model := preload("res://assets/building/v2_lift_drive.glb")
const SHEAVE_RADIUS := .315
var lift: OrisonElevator
var sheave: Node3D
var sheave_base := Basis.IDENTITY
var observed_car_height := 0.0
var driven_angle := 0.0

func configure(source: OrisonElevator) -> bool:
	if source == null or source._cabin == null: return false
	lift = source
	var model := Model.instantiate() as Node3D
	if model == null: return false
	sheave = model.find_child("TractionSheave",true,false) as Node3D
	if sheave == null:
		model.free()
		return false
	add_child(model)
	sheave_base = sheave.basis
	_apply_materials(model)
	var guard := StaticBody3D.new()
	guard.name = "PlantGuard"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.14,1.925,2.19)
	collision.shape = shape
	collision.position.y = .9625
	guard.add_child(collision)
	add_child(guard)
	var label := Label3D.new()
	label.name = "DriveIdentification"
	label.text = "PASSENGER LIFT\nDRIVE — KEEP CLEAR"
	label.font_size = 36
	label.pixel_size = .0015
	label.modulate = Color(.8,.78,.7)
	label.position = Vector3(0,2.13,1.09)
	add_child(label)
	_update_drive()
	return true

func _process(_delta: float) -> void:
	_update_drive()

func _update_drive() -> void:
	if not is_instance_valid(lift) or not is_instance_valid(lift._cabin): return
	observed_car_height = lift._cabin.position.y
	driven_angle = -observed_car_height / SHEAVE_RADIUS
	sheave.basis = sheave_base * Basis(Vector3.RIGHT,driven_angle)

func _apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		for index in visual.mesh.get_surface_count():
			var material := visual.mesh.surface_get_material(index)
			if material != null and MatLib.SETS.has(material.resource_name):
				visual.set_surface_override_material(index,MatLib.get_mat(material.resource_name))
	for child: Node in node.get_children(): _apply_materials(child)
