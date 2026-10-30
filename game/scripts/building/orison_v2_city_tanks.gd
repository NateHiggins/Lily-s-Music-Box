extends RefCounted
## Source-owned neighbouring tank silhouettes, physical stocks and local maps.
## Supply and active controls remain with their existing building authorities.
static func mount(city: Node3D) -> Node3D:
	var model: Node3D=(preload("res://assets/props/city_tanks.glb") as PackedScene).instantiate()
	model.name="RooftopTanks";city.add_child(model)
	var materials: Dictionary={}
	# Each water tower's roof apex carries St. Elmo's fire in a high-charge storm.
	var StElmo := preload("res://scripts/building/orison_v2_st_elmo.gd")
	var apex: Dictionary={}
	var placement := preload("res://scripts/building/orison_v2_city_placement.gd").new()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var key:=str(draw.name).split("__")[-1]
		assert(MatLib.SETS.has(key),"Tank material must be catalogued: "+key)
		if not materials.has(key):
			var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
			material.uv1_triplanar=false;materials[key]=material
		placement.apply(draw)
		draw.material_override=materials[key]
		var body:=StaticBody3D.new();body.name="TankCollision"
		var shape:=CollisionShape3D.new();shape.name="Surface";shape.shape=draw.mesh.create_trimesh_shape()
		body.add_child(shape);draw.add_child(body)
		if key=="galvanized_roof":
			var site:=str(draw.name).split("__")[0]
			var tip:=StElmo.crown_of(draw,model)
			if not apex.has(site) or tip.y>(apex[site] as Vector3).y: apex[site]=tip
	model.add_child(StElmo.new(PackedVector3Array(apex.values()),1.4))
	return model
