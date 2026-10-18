extends RefCounted
static func _without_boxes(draw: MeshInstance3D, boxes: Array[Dictionary], tolerance: float, counts: Dictionary, require_boundary := true) -> ArrayMesh:
	var result:=ArrayMesh.new()
	var source_surfaces: Array=draw.mesh.get("_surfaces")
	var selected_surfaces: Array=[]
	var prepared: Array[Dictionary]=[]
	for box: Dictionary in boxes:
		var low:=_v(box.low);var high:=_v(box.high)
		prepared.append({"id":str(box.id),"low":low,"high":high})
	var normal_basis:=draw.basis.inverse().transposed()
	for surface in draw.mesh.get_surface_count():
		var arrays:=draw.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		if normals.size()!=vertices.size():return null
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in vertices.size():indices.append(index)
		var positions:=PackedVector3Array();positions.resize(vertices.size())
		var transformed_normals:=PackedVector3Array();transformed_normals.resize(normals.size())
		for index in vertices.size():
			positions[index]=draw.transform*vertices[index]
			transformed_normals[index]=normal_basis*normals[index]
		var retained:=PackedInt32Array()
		for start in range(0,indices.size(),3):
			var p: Array[Vector3]=[];var n:=Vector3.ZERO
			for offset in 3:
				var index:=indices[start+offset];p.append(positions[index]);n+=transformed_normals[index]
			if n.length_squared()<.5:return null
			n=n.normalized();var match_id:=""
			var minimum:=p[0].min(p[1]).min(p[2]);var maximum:=p[0].max(p[1]).max(p[2])
			for box: Dictionary in prepared:
				var low: Vector3=box.low;var high: Vector3=box.high
				if minimum.x<low.x-tolerance or minimum.y<low.y-tolerance or minimum.z<low.z-tolerance or maximum.x>high.x+tolerance or maximum.y>high.y+tolerance or maximum.z>high.z+tolerance:continue
				if not require_boundary:
					match_id=str(box.id);break
				var axis:=n.abs().max_axis_index()
				if absf(n[axis])<.999:continue
				var plane:=high[axis] if n[axis]>0. else low[axis]
				var boundary:=true
				for point: Vector3 in p:
					if absf(point[axis]-plane)>tolerance:boundary=false
				if not boundary:continue
				if not match_id.is_empty():return null
				match_id=str(box.id)
			if match_id.is_empty():
				for offset in 3:retained.append(indices[start+offset])
			else:counts[match_id]+=1
		if retained.is_empty():continue
		# Array reconstruction would quantize decoded normal/tangent values
		# again. Copy the serialized buffers and decoding metadata verbatim;
		# replace only their independently encoded triangle index selection.
		var packed: Dictionary=source_surfaces[surface].duplicate(true)
		var width: int=packed.index_data.size()/int(packed.index_count)
		if width!=2 and width!=4:return null
		var bytes:=PackedByteArray();bytes.resize(retained.size()*width)
		for index in retained.size():
			if width==2:bytes.encode_u16(index*width,retained[index])
			else:bytes.encode_u32(index*width,retained[index])
		packed.index_data=bytes;packed.index_count=retained.size()
		# Old generated LOD indices include the replaced boxes. The retained
		# surface therefore keeps its exact full-resolution triangles.
		packed.lods={};selected_surfaces.append(packed)
	if not selected_surfaces.is_empty():result.set("_surfaces",selected_surfaces)
	return result

static func _v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
