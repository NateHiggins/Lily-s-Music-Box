extends RefCounted
## Visual joinery only. The semantic opening and DoorProp retain all authority.
const SOURCE := preload("res://assets/props/millwork_profile.glb")

static func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> bool:
	var stock:=preload("res://scripts/building/orison_v2_casing_mitre_stock.gd").new()
	if not stock.prepare(layout):
		push_error("Native mitered door stock refused: "+str(stock.errors));return false
	adapter.root.set_meta("v2_casing_mitre_stock",stock)
	var source := SOURCE.instantiate()
	var fastener := (source.find_child("ServiceFrameFastener",true,false) as MeshInstance3D).mesh
	source.free()
	var lining := BoxMesh.new()
	lining.size = Vector3.ONE
	var partition_depth := float(layout.dimensions.partition_wall)
	for record: Dictionary in layout.doors:
		var anchor := adapter.resolve(str(record.id)) as Node3D
		if anchor==null: continue
		var leaf := anchor.get_node_or_null(str(record.id)+"_Leaf") as DoorProp
		# An unhung doorway is still cased; its kind stays on the anchor.
		var kind := leaf.door_kind if leaf!=null else str(anchor.get_meta("unhung_door_kind",""))
		if kind not in ["apartment_entry","apartment_interior","service"]: continue
		var span: Vector2=preload("res://scripts/generated/v2_exterior_masonry.gd").DOOR_SPANS.get(str(record.id),Vector2(-partition_depth*.5,partition_depth*.5))
		var wall_depth := span.y-span.x
		var center := (span.x+span.y)*.5
		if leaf!=null and wall_depth>partition_depth+.001:
			var outward := span.y if absf(span.y)>absf(span.x) else span.x
			var swing: Vector3=leaf.basis*Vector3(0,0,1 if leaf.swing_out else -1)
			if signf(swing.z)==signf(outward):leaf.position.z=outward+signf(outward)*.01
		var service := kind=="service"
		var native: Dictionary=stock.frame_for(float(record.width),float(record.height),service)
		if native.is_empty():return false
		var faces: Array[Transform3D] = []
		var reveals: Array[Transform3D] = []
		var material: Material
		for part in ["FrameLeft","FrameRight","FrameHead"]:
			var frame := anchor.get_node(part) as MeshInstance3D
			material = frame.get_active_material(0)
			if service: material = MatLib.get_mat("cast_iron",Color(.24,.25,.23))
			var size: Vector3 = frame.mesh.size
			# Keep source dimensions for the schema/review owners. The playable
			# lining spans the actual partition, with the casing back on its face.
			var frame_center := frame.position+Vector3(0,0,center)
			reveals.append(Transform3D(Basis.from_scale(Vector3(size.x,size.y,wall_depth)),frame_center))
			frame.hide()
		# Native left/head/right mitres meet at the same physical vertices.
		# One complete front mesh per face retains the original single draw
		# batch, without stretching a normalized square-ended extrusion.
		var left:=anchor.get_node("FrameLeft") as MeshInstance3D
		var floor_y: float=left.position.y-left.mesh.size.y*.5
		for side: float in [-1.0,1.0]:
			faces.append(Transform3D(Basis(Vector3.UP,0.0 if side>0 else PI),Vector3(0,floor_y,center+side*(wall_depth*.5+.009))))
		var casing:=_emit(anchor,"DoorCasings",native.mesh,material,faces)
		casing.set_meta("native_parts",native.parts)
		casing.set_meta("native_variant",stock.key_for(float(record.width),float(record.height),service))
		_emit(anchor,"DoorLinings",lining,material,reveals)
		if service:
			var screws: Array[Transform3D] = []
			for side in [-1.0,1.0]:
				var rotation := Basis(Vector3.UP,0 if side>0 else PI)
				var z: float = center+side*(wall_depth*.5+.0197)
				for x in [-leaf.width*.5-.045,leaf.width*.5+.045]:
					for y in [.15,leaf.height*.5,leaf.height-.15]:
						screws.append(Transform3D(rotation,Vector3(x,y,z)))
				for x in [-leaf.width*.32,leaf.width*.32]:
					screws.append(Transform3D(rotation,Vector3(x,leaf.height+.045,z)))
			_emit(anchor,"FrameFasteners",fastener,MatLib.get_mat("iron_neutral"),screws)
	return true

static func _emit(parent: Node3D, label: String, mesh: Mesh, material: Material,
		transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.material_override = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index in transforms.size(): batch.set_instance_transform(index,transforms[index])
	node.multimesh = batch
	parent.add_child(node)
	return node
