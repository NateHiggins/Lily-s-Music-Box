extends RefCounted
## Exact native triangle partitions: preserve holes, contact faces and winding.
## This changes broad-phase bounds only, never the rendered mesh or authority.
static func build(mesh: Mesh,cell_m: float=.12) -> Array[ConcavePolygonShape3D]:
	return build_mesh_faces(mesh.get_faces(),cell_m) if mesh!=null else []

static func build_mesh_faces(faces: PackedVector3Array,cell_m: float=.12) -> Array[ConcavePolygonShape3D]:
	var output: Array[ConcavePolygonShape3D]=[]
	if faces.size()%3!=0 or not is_finite(cell_m) or cell_m<=0.:return output
	var bins: Dictionary={}
	for index in range(0,faces.size(),3):
		var center: Vector3=(faces[index]+faces[index+1]+faces[index+2])/3.
		var key:=Vector3i(floori(center.x/cell_m),floori(center.y/cell_m),floori(center.z/cell_m))
		if not bins.has(key):bins[key]=[]
		for offset in 3:bins[key].append(faces[index+offset])
	for points: Array in bins.values():
		var shape:=ConcavePolygonShape3D.new();shape.set_faces(PackedVector3Array(points));output.append(shape)
	return output
