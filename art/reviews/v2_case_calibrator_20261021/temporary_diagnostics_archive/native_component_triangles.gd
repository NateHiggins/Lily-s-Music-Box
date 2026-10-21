extends RefCounted
## Diagnostic closed connected components, each retaining exact native triangles.
## No hulls, welding, position changes or collision-mask changes.
const PLANE_EPSILON:=.0000001
static func _root(parents: Array[int],index: int) -> int:
	while parents[index]!=index:
		parents[index]=parents[parents[index]];index=parents[index]
	return index

static func build(mesh: Mesh) -> Array[Shape3D]:
	var result: Array[Shape3D]=[]
	var faces: PackedVector3Array=mesh.get_faces()
	if faces.is_empty() or faces.size()%3!=0:return result
	var vertices:=PackedVector3Array();var lookup: Dictionary={};var ids:=PackedInt32Array()
	for point: Vector3 in faces:
		if not point.is_finite():return []
		if not lookup.has(point):lookup[point]=vertices.size();vertices.append(point)
		ids.append(int(lookup[point]))
	var count: int=faces.size()/3
	var parents: Array[int]=[];parents.resize(count)
	for index in count:parents[index]=index
	var edges: Dictionary={}
	for index in count:
		var a: int=ids[index*3];var b: int=ids[index*3+1];var c: int=ids[index*3+2]
		if a==b or b==c or c==a:return []
		for pair: Vector2i in [Vector2i(a,b),Vector2i(b,c),Vector2i(c,a)]:
			var key:=Vector2i(mini(pair.x,pair.y),maxi(pair.x,pair.y))
			if not edges.has(key):edges[key]=[index,pair.x,pair.y]
			else:
				var edge: Array=edges[key]
				if edge.size()!=3 or int(edge[1])!=pair.y or int(edge[2])!=pair.x:return []
				parents[_root(parents,index)]=_root(parents,int(edge[0]));edge.append(index)
	for edge: Array in edges.values():
		if edge.size()!=4:return []
	var components: Dictionary={}
	for index in count:
		var identity:=_root(parents,index)
		if not components.has(identity):components[identity]=[]
		components[identity].append(index)
	for component: Array in components.values():
		var selected: Dictionary={};var points:=PackedVector3Array()
		for index: int in component:
			for corner in 3:
				var vertex: int=ids[index*3+corner]
				if not selected.has(vertex):selected[vertex]=true;points.append(vertices[vertex])
		if points.size()<4:return []
		# Preserve every original triangle; partition changes only acceleration.
		var component_faces:=PackedVector3Array()
		for index: int in component:
			for corner in 3:component_faces.append(faces[index*3+corner])
		var shape:=ConcavePolygonShape3D.new();shape.set_faces(component_faces)
		result.append(shape)
	return result
