extends Node3D
## Installed in the building's registered frame; the existing street owns the
## sidewalk beyond its mouth. Door interaction remains with DomesticDoors.
const ASSET := preload("res://assets/props/service_alley.glb")
const GROUNDWORKS := preload("res://assets/props/alley_groundworks.glb")

func _ready() -> void:
	var model := ASSET.instantiate() as Node3D
	add_child(model)
	var finishes := {"Paving":"concrete", "Brick":"brick", "Coping":"limestone", "Iron":"cast_iron"}
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		# The fitted grade and open well replace these two original finish owners.
		if str(mesh.name) in ["Paving","Iron"]:
			mesh.free()
			continue
		mesh.material_override = MatLib.get_mat(finishes[str(mesh.name)])
		var body := StaticBody3D.new()
		body.name = str(mesh.name)+"Collision"
		var collision := CollisionShape3D.new()
		collision.shape = mesh.mesh.create_trimesh_shape()
		collision.transform = mesh.transform
		body.add_child(collision)
		model.add_child(body)
	var groundworks:=GROUNDWORKS.instantiate() as Node3D
	groundworks.name="Groundworks"
	add_child(groundworks)
	var concrete:=MatLib.get_mat("concrete").duplicate() as StandardMaterial3D
	var iron:=MatLib.get_mat("cast_iron").duplicate() as StandardMaterial3D
	concrete.uv1_triplanar=false;iron.uv1_triplanar=false
	for draw: MeshInstance3D in groundworks.find_children("*","MeshInstance3D",true,false):
		draw.material_override=iron if str(draw.name).contains("cast_iron") else concrete
		var body:=StaticBody3D.new();body.name="GroundworksCollision";draw.add_child(body)
		var collision:=CollisionShape3D.new();collision.shape=_native_shape(draw.mesh);body.add_child(collision)
	for at: Vector3 in [Vector3(17.8,2.34,-9),Vector3(17.8,2.34,2),Vector3(17.8,2.34,12.5),Vector3(8,2.34,11)]:
		var lamp := LightFixtureProp.new()
		lamp.prop_type = "cage_bulb"
		lamp.position = at
		lamp.range_clamp = 5.0
		lamp.energy_scale = .65
		lamp.navigation_light = true
		lamp.standby_scale = .35
		add_child(lamp)

func _native_shape(mesh: Mesh) -> ConcavePolygonShape3D:
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(preload("res://scripts/building/orison_v2_native_faces.gd").read(mesh));return shape
