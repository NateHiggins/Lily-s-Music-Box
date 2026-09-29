extends RefCounted
## Fixed reading-room furniture. Existing public doors remain the route owners.
const LIBRARY := preload("res://assets/props/reading_furniture.glb")
static func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> void:
	var room := adapter.resolve("F01_COMMON_B") as Node3D
	if room==null: return
	var record: Dictionary={}
	for space: Dictionary in layout.spaces:
		if space.id==str(room.name): record=space; break
	if record.is_empty(): return
	var rect: Array=record.rect
	var center := Vector3((float(rect[0])+float(rect[2]))*.5,float(adapter.root.level_y[record.level]),(float(rect[1])+float(rect[3]))*.5)
	var furniture := Node3D.new()
	furniture.name="ReadingFurniture"
	room.add_child(furniture)
	var library := LIBRARY.instantiate()
	_install(furniture,library,"ReadingTable","Table",center,0)
	for side in [-1.0,1.0]:
		for seat in 3:
			_install(furniture,library,"ReadingChair","Chair_%s_%d" % ["north" if side>0 else "south",seat],center+Vector3((seat-1)*.76,0,side*.86),0 if side>0 else PI)
	for side in [-1.0,1.0]:
		_install(furniture,library,"Bookcase","Bookcase_"+("west" if side<0 else "east"),Vector3(center.x+side*1.05,center.y,float(rect[3])-.32),0)
	library.free()

static func _install(parent: Node3D, library: Node3D, model: String, label: String, at: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name=label;body.position=at;body.rotation.y=yaw
	parent.add_child(body)
	var source := library.get_node(model) as Node3D
	var visual := source.duplicate() as Node3D
	body.add_child(visual)
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		var role := str(mesh.name).trim_prefix(model+"_")
		match role:
			"Oak": mesh.material_override=MatLib.get_mat("oak_quartered",Color(.58,.46,.32))
			"Iron": mesh.material_override=MatLib.get_mat("cast_iron")
			"Paper": mesh.material_override=MatLib.get_mat("paper",Color(.78,.73,.59))
			"RedCloth": mesh.material_override=MatLib.get_mat("linen",Color(.32,.12,.085))
			"GreenCloth": mesh.material_override=MatLib.get_mat("linen",Color(.17,.24,.14))
			"BlueCloth": mesh.material_override=MatLib.get_mat("linen",Color(.13,.18,.25))
		var shape := CollisionShape3D.new()
		shape.shape=mesh.mesh.create_trimesh_shape()
		shape.transform=visual.transform*mesh.transform
		body.add_child(shape)
