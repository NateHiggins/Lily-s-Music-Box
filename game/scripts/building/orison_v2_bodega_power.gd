extends Node3D
## Fixed service fabric in the bodega frame; shop/lighting owners keep all state.
const ASSET := preload("res://assets/props/bodega_power.glb")
const Blockout := preload("res://scripts/building/orison_v2_blockout.gd")
var startup_failed := false
var model: Node3D
var bearing_count := 0
var _cell: Node3D

func configure(exterior: OrisonV2ExteriorCell) -> bool:
	_cell=exterior.instance_node("SHOP_BODEGA") if exterior!=null else null
	if _cell==null: return false
	transform=_cell.global_transform
	return true

func _ready() -> void:
	model=ASSET.instantiate() as Node3D
	add_child(model)
	var port:=model.find_child("PartitionPort",true,false) as Node3D
	if port==null or not _cut_partition(port.position):
		_fail("missing sleeve or unique registered partition")
		return
	var cabinet_body:=StaticBody3D.new()
	cabinet_body.name="ServiceEnclosureCollision"
	var cabinet_shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(.28,.40,.132)
	cabinet_shape.shape=box
	var rear:=model.find_child("RearWallPort",true,false) as Node3D
	if rear==null:
		_fail("missing independent intake")
		return
	cabinet_shape.position=rear.position+Vector3(0,0,.145)
	cabinet_body.add_child(cabinet_shape)
	add_child(cabinet_body)
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var key:=str(mesh.name).get_slice("__",1)
		if not MatLib.SETS.has(key):
			_fail("uncatalogued material: "+key)
			return
		mesh.material_override=MatLib.get_mat(key)
	for bearing: Node3D in model.find_children("Bearing_*","Node3D",true,false):
		bearing_count+=1
	print("[V2 BODEGA POWER] independent inlet; four existing fittings; ",bearing_count," bearings")

func _cut_partition(port: Vector3) -> bool:
	var wall: MeshInstance3D
	var old_shape: CollisionShape3D
	for child in _cell.get_children():
		if child is MeshInstance3D and child.get_meta("authored_record_id","")=="back_wall_right":
			if wall!=null:return false
			wall=child
	var body:=_cell.get_node_or_null("Collision") as StaticBody3D
	if body==null:return false
	for child in body.get_children():
		if child is CollisionShape3D and child.get_meta("authored_record_id","")=="back_wall_right":
			if old_shape!=null:return false
			old_shape=child
	if wall==null or old_shape==null or not wall.mesh is BoxMesh or not old_shape.shape is BoxShape3D:
		return false
	if wall.rotation!=Vector3.ZERO or old_shape.rotation!=Vector3.ZERO:return false
	var bounds:=AABB(wall.position-wall.mesh.size*.5,wall.mesh.size)
	var aperture:=AABB(port-Vector3(.022,.022,bounds.size.z*.5+.001),Vector3(.044,.044,bounds.size.z+.002))
	if not bounds.has_point(port-Vector3(.022,.022,0)) or not bounds.has_point(port+Vector3(.022,.022,0)):return false
	var pieces:=Blockout._subtract_box(bounds,aperture)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in pieces.size():
		var piece: AABB=pieces[index]
		var mesh:=BoxMesh.new()
		mesh.size=piece.size
		surface.append_from(mesh,0,Transform3D(Basis.IDENTITY,piece.get_center()-wall.position))
		var shape_node:=old_shape if index==0 else CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=piece.size
		shape_node.shape=shape
		shape_node.position=piece.get_center()
		if index>0:
			shape_node.name="BodegaServicePortCollision"
			shape_node.set_meta("authored_record_id","back_wall_right")
			body.add_child(shape_node)
	wall.mesh=surface.commit()
	wall.set_meta("independent_service_port",true)
	return true

func _fail(reason: String) -> void:
	startup_failed=true
	push_error("V2 BODEGA POWER: "+reason)
