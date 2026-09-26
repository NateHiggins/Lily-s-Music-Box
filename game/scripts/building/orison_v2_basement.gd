extends RefCounted
## Service apparatus uses existing production owners. Storage is architecture,
## not a second inventory or a new set of resident quests.
const UNITS := ["1A","1D","2A","2B","2C","3A","3B","3D","4A","4B","4C","4D","5A","5B","5C","6A","6B","6C"]
const BAY_STARTS := [0.0,1.6,4.25,5.55,6.85,8.15,9.45,10.75,12.05]
var _members: Array[Transform3D] = []

func mount(adapter: OrisonV2AnchorAdapter) -> bool:
	var panel := FusePanelProp.new()
	panel.prop_type = "fuse_panel"
	_box(panel,Vector3(0,.5,-.06),Vector3(.66,.90,.12),MatLib.get_mat("cast_iron"),true)
	if not adapter.mount_consumer("B1_FUSE_PANEL",panel):
		panel.free()
		return false
	var bays := adapter.resolve("B1_STORAGE_BAYS") as Node3D
	if bays == null: return false
	_members.clear()
	for row in 2:
		var back: float = 0.0 if row == 0 else 3.55
		for column in 9:
			var x: float = BAY_STARTS[column]
			var width := 1.6 if column < 2 else 1.3
			# Preserve the live wet-stack shaft and its inspection clearance.
			_fence(bays,Vector3(x,1,back+1.05),2.1,true)
			_fence(bays,Vector3(x+width,1,back+1.05),2.1,true)
			var front: float = 2.1 if row == 0 else 3.55
			# 1.05 m clear openings between the fixed panels. The gate is
			# folded against its side partition, outside that opening.
			_fence(bays,Vector3(x+.075,1,front),.15,false)
			_fence(bays,Vector3(x+width-.05,1,front),.1,false)
			_fence(bays,Vector3(x+.15,1,front+(-.52 if row==0 else .52)),1.04,true)
			var label := Label3D.new()
			label.name = "Cage_"+UNITS[row*9+column]
			label.text = UNITS[row*9+column]
			label.font_size = 42
			label.pixel_size = .003
			label.position = Vector3(x+width*.5+.025,2.12,front+(.06 if row==0 else -.06))
			label.rotation.y = 0 if row==0 else PI
			bays.add_child(label)
	var draw := MultiMeshInstance3D.new()
	draw.name = "StorageTimberPartitions"
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = MatLib.get_mat("timber")
	draw.multimesh = MultiMesh.new()
	draw.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	draw.multimesh.mesh = mesh
	draw.multimesh.instance_count = _members.size()
	for i in _members.size(): draw.multimesh.set_instance_transform(i,_members[i])
	bays.add_child(draw)
	_members.clear()
	return true

func _fence(parent: Node3D, center: Vector3, length: float, along_z: bool) -> void:
	var direction := Vector3.BACK if along_z else Vector3.RIGHT
	var size := Vector3(.06,2.0,length) if along_z else Vector3(length,2.0,.06)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
	parent.add_child(body)
	var divisions := maxi(1,int(ceil(length/.16)))
	for index in divisions+1:
		var at := center+direction*(float(index)/float(divisions)-.5)*length
		_members.append(Transform3D(Basis.from_scale(Vector3(.045,2,.045)),at))
	for height in [.12,1.85]:
		var rail_size := Vector3(.065,.065,length) if along_z else Vector3(length,.065,.065)
		_members.append(Transform3D(Basis.from_scale(rail_size),Vector3(center.x,height,center.z)))

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material, solid: bool) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	visual.mesh = mesh
	visual.position = at
	parent.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = at
		body.add_child(shape)
		parent.add_child(body)
