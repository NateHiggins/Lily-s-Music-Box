extends MeshInstance3D
## Bend closed native stock at its authored arc coordinates. Endpoint travel
## is refused when the stock cannot reach without stretching or folding over.
var _template: Array=[]
var _length := 0.0
var _radius := 0.0
var _ring_count := 0
var _last_pose: Array=[]

func bind(stock: Mesh, finish: Material, spec: Dictionary) -> bool:
	if stock==null or stock.get_surface_count()!=1: return false
	_length=float(spec.length_m);_radius=float(spec.outer_radius_m)
	var bore: float=float(spec.inner_radius_m)
	if not is_finite(_length) or not is_finite(_radius) or not is_finite(bore) or _length<=0.0 or bore<=0.0 or _radius<=bore: return false
	_template=stock.surface_get_arrays(0)
	var vertices: PackedVector3Array=_template[Mesh.ARRAY_VERTEX]
	if vertices.is_empty(): return false
	if (_template[Mesh.ARRAY_NORMAL] as PackedVector3Array).size()!=vertices.size() or (_template[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size()!=vertices.size()*4: return false
	var levels: Dictionary={}
	for point: Vector3 in vertices: levels[roundi(point.y/_length*1000000.)]=true
	_ring_count=levels.size()-1
	if _ring_count<2: return false
	material_override=finish;mesh=stock;_last_pose=[]
	return true

func can_reach(first: Vector3,last: Vector3,up_sign: float=1.0) -> bool:
	if not first.is_finite() or not last.is_finite() or absf(up_sign)!=1.0 or _template.is_empty(): return false
	var horizontal: Vector3=last-first;horizontal.y=0.0
	var radius: float=horizontal.length()*.25
	var height: float=(last.y-first.y)*up_sign
	return radius>_radius*1.05 and _length>=TAU*radius+absf(height)

func _frame(distance: float,first: Vector3,last: Vector3,up_sign: float) -> Transform3D:
	var start: Vector3=first;start.y*=up_sign
	var direction: Vector3=last-first;direction.y=0.0
	var radius: float=direction.length()*.25;direction=direction.normalized()
	var height: float=(last.y-first.y)*up_sign
	var initial: float=(_length-TAU*radius+height)*.25
	var middle: float=(_length-TAU*radius-height)*.5
	var arc: float=PI*radius
	var at: Vector3
	var tangent: Vector3
	if distance<initial:
		at=start+Vector3.UP*distance;tangent=Vector3.UP
	elif distance<initial+arc:
		var angle: float=(distance-initial)/radius
		at=start+Vector3.UP*initial+direction*radius*(1.0-cos(angle))+Vector3.UP*radius*sin(angle)
		tangent=direction*sin(angle)+Vector3.UP*cos(angle)
	elif distance<initial+arc+middle:
		at=start+direction*radius*2.0+Vector3.UP*(initial-(distance-initial-arc));tangent=Vector3.DOWN
	elif distance<initial+arc+middle+arc:
		var angle: float=(distance-initial-arc-middle)/radius
		at=start+direction*radius*2.0+Vector3.UP*(initial-middle)+direction*radius*(1.0-cos(angle))-Vector3.UP*radius*sin(angle)
		tangent=direction*sin(angle)-Vector3.UP*cos(angle)
	else:
		at=start+direction*radius*4.0+Vector3.UP*(initial-middle+distance-initial-arc-middle-arc);tangent=Vector3.UP
	at.y*=up_sign;tangent.y*=up_sign
	var binormal: Vector3=direction.cross(Vector3.UP).normalized()
	return Transform3D(Basis(tangent.cross(binormal).normalized(),tangent.normalized(),binormal),at)

func pose(first: Vector3,last: Vector3,up_sign: float=1.0) -> bool:
	if not can_reach(first,last,up_sign): return false
	var signature: Array=[first,last,up_sign]
	if signature==_last_pose: return true
	var frames: Array[Transform3D]=[]
	for ring in range(_ring_count+1):frames.append(_frame(_length*ring/_ring_count,first,last,up_sign))
	var arrays: Array=_template.duplicate(true)
	var positions: PackedVector3Array=_template[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=_template[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array=_template[Mesh.ARRAY_TANGENT]
	var moved: PackedVector3Array=[];var rotated: PackedVector3Array=[];var spun: PackedFloat32Array=[]
	moved.resize(positions.size());rotated.resize(positions.size());spun.resize(tangents.size())
	for i in positions.size():
		var point: Vector3=positions[i]
		var frame: Transform3D=frames[clampi(roundi(point.y/_length*_ring_count),0,_ring_count)]
		moved[i]=frame.origin+frame.basis*Vector3(point.x,0,point.z)
		rotated[i]=(frame.basis*normals[i]).normalized()
		var tangent: Vector3=frame.basis*Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
		for axis in 3:spun[i*4+axis]=tangent[axis]
		spun[i*4+3]=tangents[i*4+3]
	arrays[Mesh.ARRAY_VERTEX]=moved;arrays[Mesh.ARRAY_NORMAL]=rotated;arrays[Mesh.ARRAY_TANGENT]=spun
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh=result;_last_pose=signature
	return true
