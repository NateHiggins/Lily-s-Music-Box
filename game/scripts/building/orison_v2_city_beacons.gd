extends RefCounted
## Source-owned passive mast-head beacon housings, physical stocks and local maps.
## Supply and active controls remain with their existing building authorities.
static func mount(city: Node3D) -> Node3D:
	var model: Node3D=(preload("res://assets/props/city_beacons.glb") as PackedScene).instantiate()
	model.name="RooftopBeacons";city.add_child(model)
	var materials: Dictionary={}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var key:=str(draw.name).split("__")[-1]
		assert(MatLib.SETS.has(key),"Beacon material must be catalogued: "+key)
		if not materials.has(key):
			var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
			material.uv1_triplanar=false;materials[key]=material
		draw.material_override=materials[key]
		var body:=StaticBody3D.new();body.name="BeaconCollision"
		var shape:=CollisionShape3D.new();shape.name="Surface";shape.shape=draw.mesh.create_trimesh_shape()
		body.add_child(shape);draw.add_child(body)
	return model
