class_name BuildingEntrySign
extends Node3D
## Exterior bronze-and-enamel identity plaque beside the street entrance.


func _ready() -> void:
	name = "FrontDoorExteriorSign"
	var plaque := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.90, 0.62, 0.045)
	plaque.mesh = box
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.15, 0.105, 0.055)
	bronze.metallic = 0.72
	bronze.roughness = 0.48
	plaque.material_override = bronze
	add_child(plaque)
	for corner in [
		Vector2(-0.405, -0.265), Vector2(0.405, -0.265),
		Vector2(-0.405, 0.265), Vector2(0.405, 0.265)]:
		var screw := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.014
		cylinder.bottom_radius = 0.014
		cylinder.height = 0.012
		screw.mesh = cylinder
		screw.position = Vector3(corner.x, corner.y, 0.032)
		screw.rotation_degrees.x = 90
		screw.material_override = bronze
		add_child(screw)
	_add_label("THE ORISON", Vector3(0, 0.15, 0.031), 42)
	_add_label("APARTMENT BUILDING", Vector3(0, 0.015, 0.031), 22)
	_add_label("QUEENS, N.Y.  ·  EST. 1928",
			Vector3(0, -0.13, 0.031), 17)
	_add_label("REALTY MAINTENANCE",
			Vector3(0, -0.235, 0.031), 12, Color(0.68, 0.55, 0.32))


func _add_label(value: String, at: Vector3, size: int,
		color := Color(0.88, 0.78, 0.52)) -> void:
	var label := Label3D.new()
	label.text = value
	label.font_size = size
	label.modulate = color
	label.outline_size = 2
	label.outline_modulate = Color(0.035, 0.025, 0.015, 0.9)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = at
	label.pixel_size = 0.00155
	label.no_depth_test = false
	add_child(label)
