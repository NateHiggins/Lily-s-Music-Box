extends RefCounted
## The existing shop frame and hinged leaf retain every interaction owner.
## This adds fitted fixed joinery and an infill inside the original leaf body.
static func mount(exterior: OrisonV2ExteriorCell, architectural_materials: RefCounted) -> Node3D:
	var shop: Node3D=exterior.instance_node("SHOP_BODEGA")
	var leaf: DoorProp=exterior.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF")
	assert(shop!=null and leaf!=null and leaf.width==.95 and leaf.height==2.1)
	var authored: Dictionary={}
	for identity: String in ["left_window_bar","right_window_bar","left_store_glass","right_store_glass","front_transom"]:
		var draw:=authored_mesh(shop,identity)
		if draw==null:return null
		authored[identity]=draw
	var model: Node3D=(preload("res://assets/props/bodega_frontage.glb") as PackedScene).instantiate()
	model.name="FittedFrontage"
	shop.add_child(model)
	var infill: Node3D=model.get_node("LeafInfill")
	model.remove_child(infill)
	leaf._body.add_child(infill)
	infill.position=Vector3(0,0,leaf._hinge_offset)
	model.set_meta("leaf_infill",infill)
	var wood:=MatLib.get_mat("oak_quartered",Color(.42,.30,.20),.8).duplicate() as StandardMaterial3D
	wood.uv1_triplanar=false
	var glass: Material=architectural_materials.material_for("Glazing","public")
	for branch: Node3D in [model,infill]:
		for draw: MeshInstance3D in branch.find_children("*","MeshInstance3D",true,false):
			var key: String=draw.mesh.surface_get_material(0).resource_name
			draw.set_meta("material_key",key)
			draw.material_override=glass if key=="glass" else wood
			if branch==infill:continue
			var body:=StaticBody3D.new();body.name="FittedCollision"
			var shape:=CollisionShape3D.new();shape.name="Surface";shape.shape=draw.mesh.create_trimesh_shape()
			body.add_child(shape);draw.add_child(body)
	var original_bars: Dictionary={}
	for identity: String in ["left_window_bar","right_window_bar"]:
		var bar: GeometryInstance3D=authored[identity]
		original_bars[identity]=bar.visible
		bar.hide()
	var original_glass: Dictionary={}
	for identity: String in ["left_store_glass","right_store_glass","front_transom"]:
		var pane: MeshInstance3D=authored[identity]
		original_glass[identity]=pane.material_override
		pane.material_override=glass
	model.set_meta("original_bars",original_bars)
	model.set_meta("original_glass",original_glass)
	model.set_meta("authored_meshes",authored)
	return model

static func authored_mesh(shop: Node3D, identity: String) -> MeshInstance3D:
	for draw: MeshInstance3D in shop.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("authored_record_id",""))==identity:return draw
	return null
