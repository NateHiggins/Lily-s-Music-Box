extends RefCounted
## Fixed source-fitted steel beneath the retained front-court roof slab.
static func mount(root: Node3D) -> void:
	var model: Node3D=(preload("res://assets/props/front_court_roof.glb") as PackedScene).instantiate()
	model.name="FrontCourtRoofFrame";root.add_child(model)
	var materials: Dictionary={}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var key:=str(draw.name).split("__")[1]
		if not materials.has(key):
			var tint: Color=Color(.10,.11,.10) if key=="cast_iron" else Color(.24,.25,.23)
			var material:=MatLib.get_mat(key,tint).duplicate() as StandardMaterial3D
			material.uv1_triplanar=false;materials[key]=material
		draw.material_override=materials[key];draw.set_meta("roof_frame_material_key",key)
		var body:=StaticBody3D.new();body.name="RoofFrameCollision"
		var shape:=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape()
		draw.add_child(body);body.add_child(shape)
	# Only already-exposed roof undersides change finish. Their metre charts,
	# original slab body and every retained walking/top/side surface stay owned.
	var soffit: Material=root.architectural_materials.material_for("ExteriorSoffit","service")
	for space: Dictionary in root.layout.spaces:
		if not str(space.id).begins_with("ROOF_DECK_"):continue
		var floor:=root.get_node(str(space.id)+"/Floor") as MeshInstance3D
		if floor.mesh.get_surface_count()!=2:continue
		floor.mesh.surface_set_material(1,soffit);floor.set_meta("soffit_material_key","concrete")
	print("[V2 FRONT COURT ROOF] three seated girders; retained roof slabs; mapped exterior concrete")
