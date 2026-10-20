extends RefCounted
## Mass-weighted distance and tangent-velocity projection for material rings.
## Fixed outlet has zero inverse mass. No world, skin or maintenance ownership.
const PROJECTION_ERROR_M:=.000001
const TOTAL_ERROR_M:=.000005
const ACCEPT_ERROR_M:=preload("res://scripts/props/hose_length_constraint.gd").ERROR_M
const MIN_BEND_RADIUS_M:=.003
var lengths:=PackedFloat64Array()
var masses:=PackedFloat64Array()
var inverse:=PackedFloat64Array()
var bend_spans:=PackedFloat64Array()
var bend_hints:=PackedVector3Array()
var error:=""
var iterations:=0
var last_input:=PackedVector3Array()
var last_planes: Dictionary={}
var last_result:=PackedVector3Array()
var joint_accepted:=false
var coupled:=preload("res://scripts/props/hose_contact_projection.gd").new()
func configure(rest_lengths: PackedFloat64Array,rest_points: PackedVector3Array) -> bool:
	if not lengths.is_empty() or rest_lengths.size()<2:return false
	if rest_points.size()!=rest_lengths.size()+1:return false
	for point: Vector3 in rest_points:
		if not point.is_finite():return false
	for value: float in rest_lengths:
		if not is_finite(value) or value<=0.:return false
	lengths=rest_lengths.duplicate();masses.resize(lengths.size()+1);inverse.resize(masses.size())
	for i in masses.size():
		masses[i]=(lengths[i-1]*.5 if i>0 else 0.)+(lengths[i]*.5 if i<lengths.size() else 0.)
		inverse[i]=1./masses[i] if i<lengths.size() else 0.
	for i in range(1,rest_points.size()-1):
		var angle: float=minf((lengths[i-1]+lengths[i])*.5/MIN_BEND_RADIUS_M,PI*.5)
		bend_spans.append(sqrt(lengths[i-1]*lengths[i-1]+lengths[i]*lengths[i]+2.*lengths[i-1]*lengths[i]*cos(angle)))
		var span: Vector3=rest_points[i+1]-rest_points[i-1]
		if span.length_squared()<1e-14:return false
		bend_hints.append(span.normalized())
	coupled.configure(lengths,bend_spans,inverse)
	return true
func _bend(points: PackedVector3Array,collapsed_only: bool=true) -> PackedVector3Array:
	# Mass-balanced two-interval inequality prevents a zero-radius hairpin.
	# It does not impose the authored folds as a preferred/resting pose.
	for i in range(1,points.size()-1):
		var span: Vector3=points[i+1]-points[i-1]
		var distance: float=span.length()
		if distance>=bend_spans[i-1] or (collapsed_only and distance>.0000001):continue
		var direction: Vector3=span/distance if distance>.0000001 else bend_hints[i-1]
		var correction: Vector3=direction*(bend_spans[i-1]-distance)/(inverse[i-1]+inverse[i+1])
		points[i-1]-=correction*inverse[i-1];points[i+1]+=correction*inverse[i+1]
	return points
func _bend_error(points: PackedVector3Array) -> float:
	var result:=0.
	for i in range(1,points.size()-1):result=maxf(result,bend_spans[i-1]-points[i+1].distance_to(points[i-1]))
	return result
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
func _rows(points: PackedVector3Array) -> Dictionary:
	var first:=PackedInt32Array();var last:=PackedInt32Array();var vectors:=PackedVector3Array();var rhs:=PackedFloat64Array()
	var bends:=0
	for i in lengths.size():
		var d: Vector3=points[i]-points[i+1]
		first.append(i);last.append(i+1);vectors.append(d);rhs.append(.5*(d.length_squared()-lengths[i]*lengths[i]))
		if i+2>=points.size():continue
		d=points[i]-points[i+2]
		if d.length()>=bend_spans[i]:continue
		first.append(i);last.append(i+2);vectors.append(d);rhs.append(.5*(d.length_squared()-bend_spans[i]*bend_spans[i]));bends+=1
	return {"first":first,"last":last,"vectors":vectors,"rhs":rhs,"bends":bends}
func _band_solve(mobility: Array[Basis],rows: Dictionary,rhs: PackedFloat64Array) -> PackedFloat64Array:
	# Interleaved adjacent/two-hop rows share material rings within four rows.
	# A banded Float64 LDL factorization couples bending and extension instead
	# of making their independent projections fight each other indefinitely.
	var first: PackedInt32Array=rows.first;var last: PackedInt32Array=rows.last;var vectors: PackedVector3Array=rows.vectors
	var factor:=PackedFloat64Array();var diagonal:=PackedFloat64Array();var answer:=rhs.duplicate()
	factor.resize(first.size()*5);diagonal.resize(first.size())
	for i in first.size():
		for j in range(maxi(0,i-4),i+1):
			var value:=0.
			if first[i]==first[j]:value+=vectors[i].dot(mobility[first[i]]*vectors[j])
			if first[i]==last[j]:value-=vectors[i].dot(mobility[first[i]]*vectors[j])
			if last[i]==first[j]:value-=vectors[i].dot(mobility[last[i]]*vectors[j])
			if last[i]==last[j]:value+=vectors[i].dot(mobility[last[i]]*vectors[j])
			for k in range(maxi(0,i-4),j):value-=factor[i*5+i-k]*diagonal[k]*factor[j*5+j-k]
			if i==j:
				if value<=1e-18:error="singular coupled bend/length row "+str(i);return PackedFloat64Array()
				diagonal[i]=value
			else:factor[i*5+i-j]=value/diagonal[j]
		for j in range(maxi(0,i-4),i):answer[i]-=factor[i*5+i-j]*answer[j]
	for i in answer.size():answer[i]/=diagonal[i]
	for i in range(answer.size()-1,-1,-1):
		for j in range(i+1,mini(answer.size(),i+5)):answer[i]-=factor[j*5+j-i]*answer[j]
		if not is_finite(answer[i]):error="nonfinite coupled projection";return PackedFloat64Array()
	return answer
func _band_corrections(points: PackedVector3Array,mobility: Array[Basis],rows: Dictionary,multipliers: PackedFloat64Array) -> PackedVector3Array:
	var forces:=PackedVector3Array();forces.resize(points.size());forces.fill(Vector3.ZERO)
	var first: PackedInt32Array=rows.first;var last: PackedInt32Array=rows.last;var vectors: PackedVector3Array=rows.vectors
	for i in first.size():
		forces[first[i]]+=vectors[i]*multipliers[i];forces[last[i]]-=vectors[i]*multipliers[i]
	for i in forces.size():forces[i]=mobility[i]*forces[i]
	return forces
func project(target: PackedVector3Array,anchor: Vector3,planes: Dictionary) -> PackedVector3Array:
	error="";iterations=0
	last_input=target.duplicate();last_planes=planes.duplicate(true);last_result=PackedVector3Array();joint_accepted=false
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
		points=_bend(points)
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
		if maximum<PROJECTION_ERROR_M and absf(total)<TOTAL_ERROR_M and _bend_error(points)<PROJECTION_ERROR_M:return points
		last_maximum=maximum;last_total=total
		var rows: Dictionary=_rows(points)
		var multipliers: PackedFloat64Array
		var corrections: PackedVector3Array
		if rows.bends==0:
			multipliers=_solve(points,mobility,rhs)
			if multipliers.is_empty():return PackedVector3Array()
			corrections=_corrections(points,mobility,multipliers)
		else:
			multipliers=_band_solve(mobility,rows,rows.rhs)
			if multipliers.is_empty():return PackedVector3Array()
			corrections=_band_corrections(points,mobility,rows,multipliers)
		for i in points.size():points[i]-=corrections[i]
	# The strict targets above are early-exit optimization targets. At the
	# iteration ceiling, admit only the ORIGINAL length owner's criteria,
	# including the separate accumulated-length bound, after support projection.
	# The caller independently checks those same criteria and the native sweep.
	points=_support(points,planes,anchor)
	if not points.is_empty():
		last_maximum=0.;last_total=0.
		for i in lengths.size():
			var distance: float=points[i].distance_to(points[i+1])
			last_maximum=maxf(last_maximum,absf(distance-lengths[i]));last_total+=distance-lengths[i]
		if last_maximum<=ACCEPT_ERROR_M and absf(last_total)<=ACCEPT_ERROR_M and _bend_error(points)<=ACCEPT_ERROR_M:return points
		var joint: PackedVector3Array=coupled.project(points,anchor,planes)
		if not joint.is_empty():joint_accepted=true;return joint
	last_result=coupled.last_iterate.duplicate() if not coupled.last_iterate.is_empty() else points.duplicate()
	error="global length/support projection did not converge: "+str([last_maximum,last_total,_bend_error(points) if not points.is_empty() else INF])+" joint="+coupled.error;return PackedVector3Array()
func project_velocity(points: PackedVector3Array,velocity: PackedVector3Array,planes: Dictionary) -> PackedVector3Array:
	var result: PackedVector3Array=coupled.project_velocity(points,velocity,planes)
	if result.is_empty():error=coupled.error
	return result
