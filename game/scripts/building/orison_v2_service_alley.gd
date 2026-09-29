extends Node3D
## Installed in the building's registered frame; the existing street owns the
## sidewalk beyond its mouth. Door interaction remains with DomesticDoors.
const ASSET := preload("res://assets/props/service_alley.glb")

func _ready() -> void:
	var model := ASSET.instantiate() as Node3D
	add_child(model)
	var finishes := {"Paving":"concrete", "Brick":"brick", "Coping":"limestone", "Iron":"cast_iron"}
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = MatLib.get_mat(finishes[str(mesh.name)])
		var body := StaticBody3D.new()
		body.name = str(mesh.name)+"Collision"
		var collision := CollisionShape3D.new()
		collision.shape = mesh.mesh.create_trimesh_shape()
		collision.transform = mesh.transform
		body.add_child(collision)
		model.add_child(body)
	for at: Vector3 in [Vector3(17.8,2.34,-9),Vector3(17.8,2.34,2),Vector3(17.8,2.34,12.5),Vector3(8,2.34,11)]:
		var lamp := LightFixtureProp.new()
		lamp.prop_type = "cage_bulb"
		lamp.position = at
		lamp.range_clamp = 5.0
		lamp.energy_scale = .65
		lamp.navigation_light = true
		lamp.standby_scale = .35
		add_child(lamp)
