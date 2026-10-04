extends Node3D
## Closed source-derived city masses. Existing street, shop and alley owners
## retain their ground, openings and actors; this region adds none of those.
const ASSET := preload("res://assets/props/city_shells.glb")

func _ready() -> void:
	var section := preload("res://scripts/building/orison_v2_street_frame.gd").load_default()
	if section.is_empty(): return
	position.z = -float(section.source_threshold_z)
	var model := ASSET.instantiate() as Node3D
	add_child(model)
	var materials: Dictionary={}
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		mesh.set_meta("retained_city_shell",true)
		var key := str(mesh.name).split("__")[-1]
		assert(MatLib.SETS.has(key),"City material must be catalogued: " + key)
		if not materials.has(key):
			var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
			material.uv1_triplanar=false;materials[key]=material
		mesh.material_override=materials[key]
		var body := StaticBody3D.new()
		body.set_meta("retained_city_shell",true)
		body.name = str(mesh.name)+"Collision"
		var collision := CollisionShape3D.new()
		collision.shape = mesh.mesh.create_trimesh_shape()
		collision.transform = mesh.transform
		body.add_child(collision)
		model.add_child(body)
	preload("res://scripts/building/orison_v2_city_masts.gd").mount(self)
	preload("res://scripts/building/orison_v2_city_aerials.gd").mount(self)
	preload("res://scripts/building/orison_v2_city_tanks.gd").mount(self)
	preload("res://scripts/building/orison_v2_city_beacons.gd").mount(self)
