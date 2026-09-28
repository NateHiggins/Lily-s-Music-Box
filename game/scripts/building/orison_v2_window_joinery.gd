extends RefCounted
## Complete the existing semantic openings without replacing glazing authority.
static var _shared_mesh: Mesh

static func _mesh() -> Mesh:
	if _shared_mesh!=null: return _shared_mesh
	var source := (preload("res://assets/props/window_joinery.glb") as PackedScene).instantiate()
	_shared_mesh=(source.find_child("WindowJoinery",true,false) as MeshInstance3D).mesh
	source.free()
	return _shared_mesh

static func _placement(root: Node3D,record: Dictionary) -> Transform3D:
	var span: Vector2=root.window_reveal_span(record)
	var along_x := str(record.axis)=="x"
	var at := Vector3(float(record.center[0]),float(root.level_y[record.level])+float(record.sill)+float(record.height)*.5,float(record.center[1]))
	at[2 if along_x else 0]=(span.x+span.y)*.5
	var basis := Basis(Vector3.UP,0.0 if along_x else PI*.5)*Basis.from_scale(Vector3(float(record.width),float(record.height),(span.y-span.x)/.35))
	return Transform3D(basis,at)

## Imported triangles own the finish clearance too: no second hand-sized frame.
static func clearance_boxes(root: Node3D,room: Dictionary) -> Array[AABB]:
	var boxes: Array[AABB]=[]
	var faces := _mesh().get_faces()
	for record: Dictionary in root.layout.windows:
		if str(record.space)!=str(room.id): continue
		var placement := _placement(root,record)
		for start in range(0,faces.size(),3):
			var bounds := AABB(placement*faces[start],Vector3.ZERO)
			bounds=bounds.expand(placement*faces[start+1]).expand(placement*faces[start+2])
			boxes.append(bounds.grow(.0002))
	return boxes

static func mount(root: Node3D) -> void:
	for record: Dictionary in root.layout.windows:
		var opening := root.get_node(str(record.id)) as Node3D
		var jamb := opening.get_node("JambA") as MeshInstance3D
		var frame := MeshInstance3D.new()
		frame.name="FittedWindowJoinery"
		frame.mesh=_mesh()
		frame.material_override=jamb.get_active_material(0)
		frame.transform=opening.transform.affine_inverse()*_placement(root,record)
		opening.add_child(frame)
		jamb.hide()
		opening.get_node("JambB").hide()
