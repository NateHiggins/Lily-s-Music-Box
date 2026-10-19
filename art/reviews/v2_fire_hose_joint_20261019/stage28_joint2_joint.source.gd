extends RefCounted
## Joint mass-weighted projection of length equalities and unilateral bend/
## contact constraints. No skin, world queries, facts or save-state ownership.
const ERROR_M:=preload("res://scripts/props/hose_length_constraint.gd").ERROR_M
var error:=""
var iterations:=0
var qp_iterations:=0
var last_iterate:=PackedVector3Array()
var lengths:=PackedFloat64Array()
var spans:=PackedFloat64Array()
var inverse:=PackedFloat64Array()
func configure(material_lengths: PackedFloat64Array,bend_spans: PackedFloat64Array,weights: PackedFloat64Array) -> void:
	lengths=material_lengths.duplicate();spans=bend_spans.duplicate();inverse=weights.duplicate()
func _dot(a: Vector3,b: Vector3) -> float:
	# Keep matrix accumulation inFloat64; imported positions remainFloat32.
	return float(a.x)*float(b.x)+float(a.y)*float(b.y)+float(a.z)*float(b.z)
func _rows(points: PackedVector3Array,planes: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for i in points.size():
		if i<lengths.size():
			var d: Vector3=points[i]-points[i+1];var distance: float=d.length()
			if distance<.0000001:error="collapsed joint length gradient";return []
			result.append({"first":i,"last":i+1,"vector":d/distance,"g":distance-lengths[i],"equality":true,"plane":false})
		if i<spans.size():
			var d: Vector3=points[i]-points[i+2];var distance: float=d.length()
			if distance<.0000001:error="collapsed joint bend gradient";return []
			result.append({"first":i,"last":i+2,"vector":d/distance,"g":distance-spans[i],"equality":false,"plane":false})
		for plane: Dictionary in planes.get(i,[]):
			result.append({"first":i,"last":-1,"vector":plane.normal,"g":_dot(plane.normal,points[i])-plane.offset,"equality":false,"plane":true})
	return result
func _entry(a: Dictionary,b: Dictionary) -> float:
	var weight:=0.
	if a.first==b.first:weight+=inverse[a.first]
	if a.first==b.last:weight-=inverse[a.first]
	if a.last>=0:
		if a.last==b.first:weight-=inverse[a.last]
		if a.last==b.last:weight+=inverse[a.last]
	return _dot(a.vector,b.vector)*weight
func _factor(rows: Array[Dictionary],ids: PackedInt32Array) -> PackedFloat64Array:
	var bandwidth:=0
	for i in ids.size():
		for j in range(i-1,-1,-1):
			if rows[ids[i]].first-rows[ids[j]].first>2:break
			bandwidth=maxi(bandwidth,i-j)
	if bandwidth>128:error="excess joint contact bandwidth";return PackedFloat64Array()
	var width: int=bandwidth+1
	var lower:=PackedFloat64Array();var diagonal:=PackedFloat64Array();var answer:=PackedFloat64Array()
	lower.resize(ids.size()*width);diagonal.resize(ids.size());answer.resize(ids.size())
	for i in ids.size():
		answer[i]=rows[ids[i]].g
		for j in range(maxi(0,i-bandwidth),i+1):
			var value: float=_entry(rows[ids[i]],rows[ids[j]])
			for k in range(maxi(0,i-bandwidth),j):value-=lower[i*width+i-k]*diagonal[k]*lower[j*width+j-k]
			if i==j:
				if not is_finite(value) or value<=1e-16:error="dependent joint constraint row "+str(i);return PackedFloat64Array()
				diagonal[i]=value
			else:lower[i*width+i-j]=value/diagonal[j]
		for j in range(maxi(0,i-bandwidth),i):answer[i]-=lower[i*width+i-j]*answer[j]
	for i in answer.size():answer[i]/=diagonal[i]
	for i in range(answer.size()-1,-1,-1):
		for j in range(i+1,mini(answer.size(),i+width)):answer[i]-=lower[j*width+j-i]*answer[j]
		if not is_finite(answer[i]):error="nonfinite joint multiplier";return PackedFloat64Array()
	return answer
func _gradient(row: Dictionary,values: PackedVector3Array) -> float:
	var value: Vector3=values[row.first]
	if row.last>=0:value-=values[row.last]
	return _dot(row.vector,value)
func _linear(rows: Array[Dictionary],count: int) -> PackedVector3Array:
	var active:=PackedByteArray();active.resize(rows.size());active.fill(0)
	for iteration in 64:
		qp_iterations+=1
		var ids:=PackedInt32Array()
		for i in rows.size():
			if rows[i].equality or active[i]==1:ids.append(i)
		var multipliers:=_factor(rows,ids)
		if multipliers.is_empty():return PackedVector3Array()
		var delta:=PackedVector3Array();delta.resize(count);delta.fill(Vector3.ZERO)
		for i in ids.size():
			var row: Dictionary=rows[ids[i]]
			delta[row.first]-=row.vector*(inverse[row.first]*multipliers[i])
			if row.last>=0:delta[row.last]+=row.vector*(inverse[row.last]*multipliers[i])
		var added:=false
		for i in rows.size():
			if not rows[i].equality and active[i]==0 and rows[i].g+_gradient(rows[i],delta)<-.000000001:
				active[i]=1;added=true
		if added:continue
		var remove: int=-1;var largest:=.0000000001
		for i in ids.size():
			if not rows[ids[i]].equality and multipliers[i]>largest:largest=multipliers[i];remove=ids[i]
		if remove>=0:active[remove]=0;continue
		return delta
	error="joint active-set iteration ceiling";return PackedVector3Array()
func _metrics(rows: Array[Dictionary]) -> PackedFloat64Array:
	var maximum:=0.;var total:=0.;var bend:=0.;var plane:=0.
	for row: Dictionary in rows:
		if row.equality:maximum=maxf(maximum,absf(row.g));total+=row.g
		elif row.plane:plane=maxf(plane,-row.g)
		else:bend=maxf(bend,-row.g)
	return PackedFloat64Array([maximum,total,bend,plane])
func _acceptable(metrics: PackedFloat64Array) -> bool:
	return metrics[0]<=ERROR_M and absf(metrics[1])<=ERROR_M and metrics[2]<=ERROR_M and metrics[3]<=.000001
func project(seed: PackedVector3Array,anchor: Vector3,planes: Dictionary) -> PackedVector3Array:
	error="";iterations=0;qp_iterations=0;last_iterate=seed.duplicate()
	if seed.size()!=inverse.size() or lengths.size()!=seed.size()-1 or spans.size()!=seed.size()-2:
		error="joint material sizes differ";return PackedVector3Array()
	var points:=seed.duplicate();points[-1]=anchor
	for iteration in 64:
		iterations=iteration+1
		var rows: Array[Dictionary]=_rows(points,planes)
		if rows.is_empty():return PackedVector3Array()
		var metrics:=_metrics(rows)
		if _acceptable(metrics):return points
		var delta:=_linear(rows,points.size())
		if delta.is_empty():last_iterate=points;return PackedVector3Array()
		for i in points.size():points[i]+=delta[i]
		points[-1]=anchor;last_iterate=points.duplicate()
	var rows: Array[Dictionary]=_rows(points,planes)
	if not rows.is_empty() and _acceptable(_metrics(rows)):return points
	error="joint nonlinear projection ceiling";return PackedVector3Array()
func project_velocity(points: PackedVector3Array,velocity: PackedVector3Array,planes: Dictionary) -> PackedVector3Array:
	error="";qp_iterations=0
	if points.size()!=velocity.size():error="joint velocity sizes differ";return PackedVector3Array()
	var rows: Array[Dictionary]=_rows(points,planes)
	if rows.is_empty():return PackedVector3Array()
	var selected: Array[Dictionary]=[]
	for row: Dictionary in rows:
		if not row.equality and row.g>(.000001 if row.plane else ERROR_M):continue
		var constraint: Dictionary=row.duplicate();constraint.g=_gradient(row,velocity);selected.append(constraint)
	var delta:=_linear(selected,points.size())
	if delta.is_empty():return PackedVector3Array()
	var result:=velocity.duplicate()
	for i in result.size():result[i]+=delta[i]
	result[-1]=Vector3.ZERO
	return result
