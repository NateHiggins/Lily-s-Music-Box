extends RefCounted
## Inextensible kinematic strand. No maintenance facts, gravity or world-contact
## authority. A caller must supply its swept-contact veto before world use.
const ERROR_M:=.00002
var points:=PackedVector3Array()
var lengths:=PackedFloat64Array()
var total_length:=0.0
var anchor:=Vector3.ZERO
var last_iterations:=0
func configure(rest: PackedVector3Array) -> bool:
	if rest.size()<3:return false
	var segment_lengths:=PackedFloat64Array();var total:=0.0
	for i in rest.size():
		if not rest[i].is_finite():return false
		if i==0:continue
		var distance: float=rest[i].distance_to(rest[i-1])
		if not is_finite(distance) or distance<.000001:return false
		segment_lengths.append(distance);total+=distance
	points=rest.duplicate();lengths=segment_lengths;total_length=total;anchor=rest[-1]
	return true
func _valid_positions(value: PackedVector3Array) -> bool:
	if points.size()<3 or value.size()!=points.size() or value[-1].distance_to(anchor)>ERROR_M:return false
	var total:=0.0
	for i in value.size():
		if not value[i].is_finite():return false
		if i>0:
			var distance: float=value[i].distance_to(value[i-1])
			if absf(distance-lengths[i-1])>ERROR_M:return false
			total+=distance
	return absf(total-total_length)<=ERROR_M
func move_endpoint(goal: Vector3,contact_veto: Callable=Callable()) -> bool:
	if points.is_empty() or not goal.is_finite():return false
	var proposed:=points.duplicate();var offset: Vector3=goal-anchor
	var distance: float=offset.length();last_iterations=0
	if distance>=total_length-ERROR_M:
		if distance<.000001:return false
		var direction: Vector3=offset/distance;var remaining: float=total_length
		for i in proposed.size():
			proposed[i]=anchor+direction*remaining
			if i<lengths.size():remaining-=lengths[i]
	else:
		for iteration in 512:
			proposed[0]=goal
			for i in range(1,proposed.size()):
				var delta: Vector3=proposed[i]-proposed[i-1]
				if delta.length_squared()<1e-14:return false
				proposed[i]=proposed[i-1]+delta.normalized()*lengths[i-1]
			proposed[-1]=anchor
			for i in range(proposed.size()-2,-1,-1):
				var delta: Vector3=proposed[i]-proposed[i+1]
				if delta.length_squared()<1e-14:return false
				proposed[i]=proposed[i+1]+delta.normalized()*lengths[i]
			last_iterations=iteration+1
			if proposed[0].distance_to(goal)<=ERROR_M:break
		if proposed[0].distance_to(goal)>ERROR_M:return false
	if not _valid_positions(proposed):return false
	# Atomic rejection: collision or failed convergence never leaves half a
	# stretched strand, nor does it drag an already-pinned outlet sideways.
	if contact_veto.is_valid() and bool(contact_veto.call(points,proposed)):return false
	points=proposed
	return true
func snapshot() -> Dictionary:
	var rows: Array=[]
	for p: Vector3 in points:rows.append([p.x,p.y,p.z])
	return {"version":1,"points":rows}
func decoded(value: Variant) -> PackedVector3Array:
	if value is not Dictionary or value.size()!=2 or typeof(value.get("version")) not in [TYPE_INT,TYPE_FLOAT] or value.version!=1 or value.get("points") is not Array:return PackedVector3Array()
	if value.points.size()!=points.size():return PackedVector3Array()
	var restored:=PackedVector3Array()
	for row: Variant in value.points:
		if row is not Array or row.size()!=3:return PackedVector3Array()
		for coordinate: Variant in row:
			if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)):return PackedVector3Array()
		restored.append(Vector3(row[0],row[1],row[2]))
	return restored if _valid_positions(restored) else PackedVector3Array()
func restore(value: Variant,contact_veto: Callable=Callable()) -> bool:
	var restored:=decoded(value)
	if restored.is_empty():return false
	if contact_veto.is_valid() and bool(contact_veto.call(points,restored)):return false
	points=restored
	return true
