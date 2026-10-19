extends RefCounted
## Convex angular sectors clipped from actual imported annular stock.
## Shapes are collision only; no generated visual or filled-bore substitute.
static func build(mesh: Mesh,cuts: Array[float],sectors: int=48,frame: Transform3D=Transform3D.IDENTITY) -> Array[ConvexPolygonShape3D]:
	# Mesh.get_faces rounds positions to100um. Keep actual imported vertices
	# for small bores, and optionally align a transverse spindle with local Y.
	var faces:=PackedVector3Array()
	for surface in mesh.get_surface_count():
		var arrays: Array=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for point: Vector3 in vertices:faces.append(frame*point)
		else:
			for index: int in indices:faces.append(frame*vertices[index])
	var buckets: Dictionary={}
	for i in range(0,faces.size(),3):
		var lowest: float=minf(faces[i].y,minf(faces[i+1].y,faces[i+2].y))
		var highest: float=maxf(faces[i].y,maxf(faces[i+1].y,faces[i+2].y))
		var points: Array[Vector3]=[faces[i],faces[i+1],faces[i+2]]
		for edge in range(3):
			var a: Vector3=faces[i+edge];var b: Vector3=faces[i+(edge+1)%3]
			for y: float in cuts:
				if (a.y<y and b.y>y) or (a.y>y and b.y<y):points.append(a.lerp(b,(y-a.y)/(b.y-a.y)))
		for point: Vector3 in points:
			var angle: float=fposmod(atan2(point.z,point.x),TAU)*sectors/TAU
			var section: int=int(floor(angle))%sectors
			var angular: Array[int]=[section]
			if absf(angle-roundf(angle))<.00001:angular=[roundi(angle)%sectors,(roundi(angle)+sectors-1)%sectors]
			for band in range(cuts.size()-1):
				# A cap or a flange touching only a band's boundary has no
				# volume in that band. Including it would fill a stepped bore
				# or turn the narrow stem below a flange into an invisible cone.
				if highest<=cuts[band]+.00000001 or lowest>=cuts[band+1]-.00000001:continue
				if point.y<cuts[band]-.0000001 or point.y>cuts[band+1]+.0000001:continue
				for sector: int in angular:
					var key: int=band*sectors+sector
					if not buckets.has(key):buckets[key]={}
					buckets[key][point]=true
	var result: Array[ConvexPolygonShape3D]=[]
	var original: Transform3D=frame.affine_inverse()
	for points: Dictionary in buckets.values():
		if points.size()<4:continue
		var shape:=ConvexPolygonShape3D.new();var local:=PackedVector3Array()
		for point: Vector3 in points:local.append(original*point)
		shape.points=local;shape.margin=.00001
		result.append(shape)
	return result
