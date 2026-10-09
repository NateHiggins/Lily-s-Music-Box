extends RefCounted
## Fixed public furnishings; circulation and door ownership stay with the rooms.
const LIBRARY := preload("res://assets/props/public_furnishings.glb")
static func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> void:
	var library := LIBRARY.instantiate()
	for room_id in ["F01_LOBBY","F01_PACKAGE"]:
		var room := adapter.resolve(room_id) as Node3D
		if room==null: continue
		var rect: Array=[]
		var y := 0.0
		for record: Dictionary in layout.spaces:
			if record.id==room_id:
				rect=record.rect;y=float(adapter.root.level_y[record.level]);break
		if rect.is_empty():continue
		var furniture := Node3D.new()
		furniture.name="PublicFurnishings";room.add_child(furniture)
		if room_id=="F01_LOBBY":
			_install(furniture,library,"LobbyBench","WestBench",Vector3(float(rect[0])+.44,y,float(rect[1])+2.10),-PI*.5)
			_install(furniture,library,"LobbyBench","EastBench",Vector3(float(rect[2])-.44,y,float(rect[1])+2.55),PI*.5)
		else:
			_install(furniture,library,"ParcelRack","EastRack",Vector3(float(rect[2])-.33,y,(float(rect[1])+float(rect[3]))*.5),PI*.5,"ParcelLoadEast")
			_install(furniture,library,"ParcelRack","NorthRack",Vector3((float(rect[0])+float(rect[2]))*.5,y,float(rect[3])-.325),0,"ParcelLoadNorth")
	library.free()

static func _install(parent: Node3D, library: Node3D, model: String, label: String, at: Vector3, yaw: float, dressing := "") -> void:
	var body := StaticBody3D.new()
	body.name=label;body.position=at;body.rotation.y=yaw
	parent.add_child(body)
	_add_visual(body,library,model)
	# Parcel-room stock is dressing on the fixed rack: it shares the rack body and adds no custody owner.
	if not dressing.is_empty(): _add_visual(body,library,dressing)

static func _add_visual(body: StaticBody3D, library: Node3D, model: String) -> void:
	var source := library.get_node(model) as Node3D
	var visual := source.duplicate() as Node3D
	body.add_child(visual)
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		var role := str(mesh.name).trim_prefix(model+"_")
		match role:
			"Oak", "Pine": mesh.material_override=MatLib.get_mat("oak_quartered",Color(.58,.46,.32))
			"Iron": mesh.material_override=MatLib.get_mat("cast_iron")
			"Paper": mesh.material_override=MatLib.get_mat("paper",Color(.78,.73,.59))
			"RedCloth": mesh.material_override=MatLib.get_mat("linen",Color(.32,.12,.085))
			"GreenCloth": mesh.material_override=MatLib.get_mat("linen",Color(.17,.24,.14))
			"BlueCloth": mesh.material_override=MatLib.get_mat("linen",Color(.13,.18,.25))
			"Kraft": mesh.material_override=MatLib.get_mat("paper",Color(.50,.36,.22))
			"Twine": mesh.material_override=MatLib.get_mat("linen",Color(.66,.58,.42))
			"Brass": mesh.material_override=MatLib.get_mat("brass_dull")
			"Book": mesh.material_override=MatLib.get_mat("book_navy")
		var shape := CollisionShape3D.new()
		shape.shape=mesh.mesh.create_trimesh_shape()
		shape.transform=visual.transform*mesh.transform
		body.add_child(shape)
