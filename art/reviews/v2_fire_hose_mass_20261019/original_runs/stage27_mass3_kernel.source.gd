extends RefCounted
## Mass-weighted global SHAKE/RATTLE projection for neighbouring material rings.
## Fixed outlet has zero inverse mass. No world, skin or maintenance ownership.
const PROJECTION_ERROR_M:=.000001
const TOTAL_ERROR_M:=.000005
var lengths:=PackedFloat64Array()
var masses:=PackedFloat64Array()
var inverse:=PackedFloat64Array()
var error:=""
var iterations:=0
func configure(rest_lengths: PackedFloat64Array) -> bool:
	if not lengths.is_empty() or rest_lengths.size()<2:return false
	for value: float in rest_lengths:
		if not is_finite(value) or value<=0.:return false
	lengths=rest_lengths.duplicate();masses.resize(lengths.size()+1);inverse.resize(masses.size())
	for i in masses.size():
		masses[i]=(lengths[i-1]*.5 if i>0 else 0.)+(lengths[i]*.5 if i<lengths.size() else 0.)
		inverse[i]=1./masses[i] if i<lengths.size() else 0.
	return true
func _axes(point: Vector3,limits: Array) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	for plane: Dictionary in limits:
		if plane.normal.dot(point)>plane.offset+.000001:continue
		var axis: Vector3=plane.normal
		for old: Vector3 in result:axis-=old*old.dot(axis)
		if axis.length_squared()>1e-12:result.append(axis.normalized())
	return result
func _mobility(points: PackedVector3Array,planes: Dictionary) -> Array[Basis]:
	var result: Array[Basis]=[]
	for i in points.size():
		var x:=Vector3.RIGHT;var y:=Vector3.UP;var z:=Vector3.BACK
		for normal: Vector3 in _axes(points[i],planes.get(i,[])):
			x-=normal*normal.x;y-=normal*normal.y;z-=normal*normal.z
		result.append(Basis(x*inverse[i],y*inverse[i],z*inverse[i]))
	return result
func _support(points: PackedVector3Array,planes: Dictionary,anchor: Vector3) -> PackedVector3Array:
	for ring: int in planes:
		if ring<0 or ring>=points.size():return PackedVector3Array()
		if ring==points.size()-1:
			for plane: Dictionary in planes[ring]:
				if plane.normal.dot(anchor)<plane.offset-.000001:return PackedVector3Array()
			continue
		for iteration in 8:
			for plane: Dictionary in planes[ring]:
				var distance: float=plane.offset-plane.normal.dot(points[ring])
				if distance>0.:points[ring]+=plane.normal*distance
		for plane: Dictionary in planes[ring]:
			if plane.normal.dot(points[ring])<plane.offset-.000001:return PackedVector3Array()
	points[-1]=anchor
	return points
func _solve(points: PackedVector3Array,mobility: Array[Basis],rhs: PackedFloat64Array) -> PackedFloat64Array:
	# J M^-1 J^T is tridiagonal: each distance row shares one ring with
	# each neighbouring row. Factor in Float64, including at long straight runs.
	var diagonal:=PackedFloat64Array();var off:=PackedFloat64Array();var answer:=rhs.duplicate()
	diagonal.resize(lengths.size());off.resize(lengths.size()-1)
	for i in lengths.size():
		var direction: Vector3=points[i]-points[i+1]
		diagonal[i]=direction.dot(mobility[i]*direction+mobility[i+1]*direction)
		if i<off.size():off[i]=-direction.dot(mobility[i+1]*(points[i+1]-points[i+2]))
		if diagonal[i]<1e-18:
			if absf(rhs[i])>1e-12:error="immobile distance constraint";return PackedFloat64Array()
			diagonal[i]=1.
	for i in range(1,diagonal.size()):
		if diagonal[i-1]<=1e-18:error="singular mass projection";return PackedFloat64Array()
		var factor: float=off[i-1]/diagonal[i-1]
		diagonal[i]-=factor*off[i-1];answer[i]-=factor*answer[i-1]
	if diagonal[-1]<=1e-18:error="singular terminal constraint";return PackedFloat64Array()
	answer[-1]/=diagonal[-1]
	for i in range(answer.size()-2,-1,-1):answer[i]=(answer[i]-off[i]*answer[i+1])/diagonal[i]
	for value: float in answer:
		if not is_finite(value):error="nonfinite mass projection";return PackedFloat64Array()
	return answer
func _corrections(points: PackedVector3Array,mobility: Array[Basis],multipliers: PackedFloat64Array) -> PackedVector3Array:
	var result:=PackedVector3Array();result.resize(points.size())
	for i in points.size():
		var force:=Vector3.ZERO
		if i<lengths.size():force+=(points[i]-points[i+1])*multipliers[i]
		if i>0:force-=(points[i-1]-points[i])*multipliers[i-1]
		result[i]=mobility[i]*force
	return result
func project(target: PackedVector3Array,anchor: Vector3,planes: Dictionary) -> PackedVector3Array:
	error="";iterations=0
	if target.size()!=masses.size():error="wrong material ring count";return PackedVector3Array()
	var points:=target.duplicate()
	# Position inequalities may release while neighbouring rings rise. Locking
	# every first contact to equality overconstrains a bent, varying section.
	# Alternate support projection with the global unconstrained mass solve;
	# the final check still requires both support and exact material length.
	var mobility: Array[Basis]=_mobility(points,{})
	var last_maximum:=0.;var last_total:=0.
	for iteration in 128:
		iterations=iteration+1
		points=_support(points,planes,anchor)
		if points.is_empty():error="incompatible support constraints";return PackedVector3Array()
		var rhs:=PackedFloat64Array();rhs.resize(lengths.size())
		var maximum:=0.;var total:=0.
		for i in lengths.size():
			var distance: float=points[i].distance_to(points[i+1])
			if not is_finite(distance) or distance<.0000001:error="collapsed material interval";return PackedVector3Array()
			rhs[i]=.5*(distance*distance-lengths[i]*lengths[i])
			maximum=maxf(maximum,absf(distance-lengths[i]));total+=distance-lengths[i]
		# Float32 imported positions do not reliably resolve a0.2micrometre
		# residual after repeated contact. Both targets remain stricter than
		# the unchanged20micrometre per-interval AND total acceptance checks.
		if maximum<PROJECTION_ERROR_M and absf(total)<TOTAL_ERROR_M:return points
		last_maximum=maximum;last_total=total
		var multipliers:=_solve(points,mobility,rhs)
		if multipliers.is_empty():return PackedVector3Array()
		var corrections:=_corrections(points,mobility,multipliers)
		for i in points.size():points[i]-=corrections[i]
	error="global length/support projection did not converge: "+str([last_maximum,last_total]);return PackedVector3Array()
func project_velocity(points: PackedVector3Array,velocity: PackedVector3Array,planes: Dictionary) -> PackedVector3Array:
	if points.size()!=masses.size() or velocity.size()!=points.size():error="wrong velocity count";return PackedVector3Array()
	var result:=velocity.duplicate();result[-1]=Vector3.ZERO
	for i in result.size():
		for normal: Vector3 in _axes(points[i],planes.get(i,[])):result[i]-=normal*normal.dot(result[i])
	var mobility: Array[Basis]=_mobility(points,planes)
	var rhs:=PackedFloat64Array();rhs.resize(lengths.size())
	for i in lengths.size():rhs[i]=(points[i]-points[i+1]).dot(result[i]-result[i+1])
	var multipliers:=_solve(points,mobility,rhs)
	if multipliers.is_empty():return PackedVector3Array()
	var corrections:=_corrections(points,mobility,multipliers)
	for i in result.size():result[i]-=corrections[i]
	return result
