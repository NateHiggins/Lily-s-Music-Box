extends RefCounted
## Visual joinery only. The semantic opening and DoorProp retain all authority.
const SOURCE := preload("res://assets/props/millwork_profile.glb")

static func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> void:
	var source := SOURCE.instantiate()
	var profile := (source.find_child("DoorCasing",true,false) as MeshInstance3D).mesh
	var service_profile := (source.find_child("ServiceCasing",true,false) as MeshInstance3D).mesh
	var fastener := (source.find_child("ServiceFrameFastener",true,false) as MeshInstance3D).mesh
	source.free()
	var lining := BoxMesh.new()
	lining.size = Vector3.ONE
	var wall_depth := float(layout.dimensions.partition_wall)
	for record: Dictionary in layout.doors:
		var anchor := adapter.resolve(str(record.id)) as Node3D
		if anchor==null: continue
		var leaf := anchor.get_node_or_null(str(record.id)+"_Leaf") as DoorProp
		if leaf==null or leaf.door_kind not in ["apartment_entry","apartment_interior","service"]: continue
		var service := leaf.door_kind=="service"
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
			reveals.append(Transform3D(Basis.from_scale(Vector3(size.x,size.y,wall_depth)),frame.position))
			for side in [-1.0,1.0]:
				var at := frame.position+Vector3(0,0,side*(wall_depth*.5+.009))
				var rotation := Basis(Vector3.UP,0 if side>0 else PI)
				var dimensions := Vector3(size.x,size.y,.018)
				if part!="FrameHead":
					# The raised outer bead points away from the aperture on both
					# jambs and both faces; no negative scale or mirrored normals.
					rotation = rotation*Basis(Vector3.BACK,PI*.5*side*(1 if part=="FrameLeft" else -1))
					dimensions = Vector3(size.y,size.x,.018)
				faces.append(Transform3D(rotation*Basis.from_scale(dimensions),at))
			frame.hide()
		_emit(anchor,"DoorCasings",service_profile if service else profile,material,faces)
		_emit(anchor,"DoorLinings",lining,material,reveals)
		if service:
			var screws: Array[Transform3D] = []
			for side in [-1.0,1.0]:
				var rotation := Basis(Vector3.UP,0 if side>0 else PI)
				var z: float = side*(wall_depth*.5+.0197)
				for x in [-leaf.width*.5-.045,leaf.width*.5+.045]:
					for y in [.15,leaf.height*.5,leaf.height-.15]:
						screws.append(Transform3D(rotation,Vector3(x,y,z)))
				for x in [-leaf.width*.32,leaf.width*.32]:
					screws.append(Transform3D(rotation,Vector3(x,leaf.height+.045,z)))
			_emit(anchor,"FrameFasteners",fastener,MatLib.get_mat("steel"),screws)

static func _emit(parent: Node3D, label: String, mesh: Mesh, material: Material,
		transforms: Array[Transform3D]) -> void:
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
