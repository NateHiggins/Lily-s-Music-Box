extends MeshInstance3D
## Bend native rings at their authored arc length; never replace the UV stock.
var _template: Array=[]
var _length: float=.8
var _radius: float=.0035

func bind(stock: Mesh,finish: Material,length_m: float,radius_m: float) -> bool:
	if stock==null or stock.get_surface_count()!=1 or length_m<=0 or radius_m<=0:return false
	_template=stock.surface_get_arrays(0);_length=length_m;_radius=radius_m
	material_override=finish
	return _template[Mesh.ARRAY_VERTEX] is PackedVector3Array and not _template[Mesh.ARRAY_VERTEX].is_empty()

func can_reach(first: Vector3,last: Vector3) -> bool:
	if not first.is_finite() or not last.is_finite():return false
	var horizontal: Vector2=Vector2(last.x-first.x,last.z-first.z)
	var radius: float=horizontal.length()*.5
	return radius>=_radius*4. and absf(last.y-first.y)+PI*radius<=_length

func _frame(distance: float,first: Vector3,last: Vector3) -> Transform3D:
	var horizontal: Vector3=last-first;horizontal.y=0
	var direction: Vector3=horizontal.normalized();var radius: float=horizontal.length()*.5
	var common: float=(first.y+last.y+PI*radius-_length)*.5
	var initial: float=first.y-common
	var at: Vector3
	var tangent: Vector3
	if distance<initial:
		at=first-Vector3.UP*distance;tangent=Vector3.DOWN
	elif distance<initial+PI*radius:
		var angle: float=(distance-initial)/radius
		at=(first+last)*.5;at.y=common;at-=direction*radius*cos(angle);at.y-=radius*sin(angle)
		tangent=direction*sin(angle)-Vector3.UP*cos(angle)
	else:
		at=last;at.y=common+distance-initial-PI*radius;tangent=Vector3.UP
	var normal: Vector3=Vector3.UP.cross(direction).normalized()
	return Transform3D(Basis(tangent.cross(normal).normalized(),tangent.normalized(),normal),at)

func pose(first: Vector3,last: Vector3) -> bool:
	if not can_reach(first,last) or _template.is_empty():return false
	var arrays: Array=_template.duplicate(true)
	var originals: PackedVector3Array=_template[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=_template[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array=_template[Mesh.ARRAY_TANGENT]
	var vertices: PackedVector3Array=[];var result_normals: PackedVector3Array=[];var result_tangents: PackedFloat32Array=[]
	vertices.resize(originals.size());result_normals.resize(originals.size())
	if tangents.size()==originals.size()*4:result_tangents.resize(tangents.size())
	for i in originals.size():
		var source: Vector3=originals[i];var frame: Transform3D=_frame(clampf(source.y,0.,_length),first,last)
		vertices[i]=frame.origin+frame.basis*Vector3(source.x,0,source.z)
		result_normals[i]=(frame.basis*normals[i]).normalized()
		if not result_tangents.is_empty():
			var tangent: Vector3=frame.basis*Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
			for axis in 3:result_tangents[i*4+axis]=tangent[axis]
			result_tangents[i*4+3]=tangents[i*4+3]
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=result_normals
	if not result_tangents.is_empty():arrays[Mesh.ARRAY_TANGENT]=result_tangents
	var current: ArrayMesh=ArrayMesh.new();current.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh=current
	return true
