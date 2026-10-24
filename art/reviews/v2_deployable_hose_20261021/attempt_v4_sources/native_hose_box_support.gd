extends RefCounted
## Exact half-space shortcut for a complete large face of a single static box.
## Unknown, multi-shape, edge/corner and near-boundary cases use native shell GJK.
## Neither a centreline proxy nor a closed bore: every support uses native skin.
const GUARD_M:=.00001
func segment(owner: RefCounted,hits: Array[Dictionary],bounds: AABB,old_bounds: AABB,next_bounds: AABB,world: Transform3D,next: Array[Transform3D],index: int) -> Dictionary:
	var fallback: Dictionary={"handled":false}
	# A full result set is required. Do not hide a second obstruction behind
	# the first broad-phase floor hit or a truncated result buffer.
	if hits.is_empty() or hits.size()>=65:return fallback
	var planes: Array[Dictionary]=[];var collider: Object=null
	for hit: Dictionary in hits:
		var body: Object=hit.collider
		if body is not StaticBody3D or body is AnimatableBody3D:return fallback
		var rid: RID=hit.rid
		if PhysicsServer3D.body_get_shape_count(rid)!=1 or int(hit.shape)!=0:return fallback
		var shape: RID=PhysicsServer3D.body_get_shape(rid,0)
		if PhysicsServer3D.shape_get_type(shape)!=PhysicsServer3D.SHAPE_BOX:return fallback
		var half: Vector3=PhysicsServer3D.shape_get_data(shape)
		var pose: Transform3D=PhysicsServer3D.body_get_state(rid,PhysicsServer3D.BODY_STATE_TRANSFORM)*PhysicsServer3D.body_get_shape_transform(rid,0)
		if not half.is_finite() or half.x<=0. or half.y<=0. or half.z<=0. or not pose.is_finite() or absf(pose.basis.determinant())<.000001:return fallback
		var inverse:=pose.affine_inverse()
		var local_bounds: AABB=inverse*bounds
		var local_old: AABB=inverse*old_bounds
		var local_next: AABB=inverse*next_bounds
		var axis: int=-1;var sign_value:=0.
		for candidate in 3:
			var fits:=true
			for other in 3:
				if other!=candidate and (local_bounds.position[other]<=-half[other]+GUARD_M or local_bounds.end[other]>=half[other]-GUARD_M):fits=false;break
			if not fits:continue
			if local_old.position[candidate]>half[candidate]+GUARD_M:axis=candidate;sign_value=1.;break
			if local_old.end[candidate]<-half[candidate]-GUARD_M:axis=candidate;sign_value=-1.;break
		if axis<0:return fallback
		var conservative_gap: float=local_next.position[axis]-half[axis] if sign_value>0. else -local_next.end[axis]-half[axis]
		if conservative_gap>GUARD_M:continue
		var local_axis:=Vector3.ZERO;local_axis[axis]=sign_value
		var normal: Vector3=(inverse.basis.transposed()*local_axis).normalized()
		var point: Vector3=pose*(local_axis*half[axis])
		# Confirm the actual physical face, at the server's current transform.
		# A node can move before a physics broad-phase update; node transforms
		# or a cached plane are not authoritative here.
		var ray:=PhysicsRayQueryParameters3D.create(point+normal*.005,point-normal*.005,1,owner.exclusions)
		var witness: Dictionary=owner.space.intersect_ray(ray)
		if witness.is_empty() or witness.rid!=rid or witness.normal.dot(normal)<.999999 or absf(normal.dot(witness.position-point))>.000002:return fallback
		var info: Dictionary={"rid":rid,"normal":witness.normal,"point":witness.position}
		var scale: float=(world.basis.transposed()*witness.normal).length()
		if scale<.000001:return fallback
		var pair: Array[Dictionary]=[];var actual_gap:=INF
		for ring: int in [index,index+1]:
			var plane: Dictionary=owner._contact_plane(ring,next[ring],world,info,false)
			if plane.is_empty():return fallback
			pair.append(plane)
			actual_gap=minf(actual_gap,(plane.normal.dot(next[ring].origin)-plane.offset)*scale+owner.RESPONSE_CLEARANCE_M)
		if actual_gap>GUARD_M:continue
		if actual_gap>=-GUARD_M:return fallback
		# Both original rings are outside this face, and the complete swept
		# footprint fits its rectangle. A native outer vertex crossing it must
		# contact this box, including a complete traversal of a thin floor.
		planes.append_array(pair);collider=body
	return {"handled":true,"planes":planes,"collider":collider}
