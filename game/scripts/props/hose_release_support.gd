extends RefCounted
## One release-time support placement. No gravity, cloth or resting callback.
## The original receiver/nozzle transforms remain the only saved pose authority.
var stock: Array[Dictionary]=[]
var last_result: Dictionary={}

func prepare(hose: Node3D) -> void:
	if not stock.is_empty():return
	for shape: CollisionShape3D in hose.joint.body.get_children():
		if not shape.shape is ConvexPolygonShape3D:continue
		var points: PackedVector3Array=shape.shape.points
		if points.is_empty():continue
		var bounds:=AABB(points[0],Vector3.ZERO)
		for point: Vector3 in points:bounds=bounds.expand(point)
		stock.append({"shape":shape,"bounds":bounds})

func _bounds(hose: Node3D,receiver: Transform3D) -> AABB:
	var body: Transform3D=receiver*Transform3D(Basis(Vector3.UP,hose.joint.clocking),Vector3(0,hose.joint.stock.body_y(hose.joint.angle),0))
	var result:=AABB();var first:=true
	for row: Dictionary in stock:
		var shape: CollisionShape3D=row.shape
		if not is_instance_valid(shape) or shape.disabled:continue
		var bounds: AABB=body*shape.transform*row.bounds
		result=bounds if first else result.merge(bounds);first=false
	for row: Dictionary in [{"mesh":hose.joint.seat.mesh,"pose":receiver},{"mesh":hose.joint.nut.mesh,"pose":receiver*Transform3D(Basis(Vector3.UP,hose.joint.angle+hose.joint.spin),Vector3.ZERO)}]:
		result=result.merge(row.pose*row.mesh.get_aabb())
	return result

func place(hose: Node3D,holder: Node3D) -> bool:
	var started: int=Time.get_ticks_usec()
	last_result={"placed":false,"reason":"no clear support","rays":0,"overlap_queries":0}
	prepare(hose)
	if stock.is_empty():last_result.reason="no physical nozzle envelope";return false
	var before: Transform3D=hose.actor.global_transform*hose.joint.receiver
	var forward: Vector3=hose.joint.body.global_basis.y;forward.y=0.
	if forward.length_squared()<.01:forward=-holder.global_basis.z;forward.y=0.
	forward=forward.normalized()
	var right: Vector3=forward.cross(Vector3.UP).normalized()
	var pose:=Transform3D(Basis(right,forward,Vector3.UP)*Basis(Vector3.UP,-hose.joint.clocking),before.origin)
	var excluded: Array[RID]=[]
	for body: CollisionObject3D in hose.actor.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	if holder is CollisionObject3D:excluded.append(holder.get_rid())
	var space: PhysicsDirectSpaceState3D=hose.get_world_3d().direct_space_state
	var box:=BoxShape3D.new()
	var overlap:=PhysicsShapeQueryParameters3D.new();overlap.shape=box;overlap.collision_mask=1;overlap.exclude=excluded;overlap.margin=0.
	var anchor: Vector3=hose.model.to_global(hose.rig.strand.anchor)
	for offset: Vector3 in [Vector3.ZERO,right*.25,-right*.25,-forward*.25]:
		pose.origin=before.origin+offset
		var bounds: AABB=_bounds(hose,pose)
		var center: Vector3=bounds.get_center();center.y=before.origin.y+.10
		var query:=PhysicsRayQueryParameters3D.create(center,center-Vector3.UP*2.5,1,excluded)
		var hit: Dictionary=space.intersect_ray(query);last_result.rays+=1
		if hit.is_empty() or hit.normal.dot(Vector3.UP)<.99:continue
		pose.origin.y+=float(hit.position.y)+.002-bounds.position.y
		if pose.origin.distance_to(anchor)>hose.rig.strand.total_length-.15:continue
		bounds=_bounds(hose,pose)
		box.size=bounds.size
		overlap.transform=Transform3D(Basis.IDENTITY,bounds.get_center())
		last_result.overlap_queries+=1
		if not space.intersect_shape(overlap,1).is_empty():continue
		# A real support must also lie beneath the opposite end of this short
		# stock; a ray through a narrow edge alone cannot establish a rest pose.
		var end: Vector3=pose.origin+forward*.18+Vector3.UP*.15
		query=PhysicsRayQueryParameters3D.create(end,end-Vector3.UP*.30,1,excluded)
		var second: Dictionary=space.intersect_ray(query);last_result.rays+=1
		if second.is_empty() or second.normal.dot(Vector3.UP)<.99 or absf(float(second.position.y)-float(hit.position.y))>.002:continue
		hose._visual_receiver(pose)
		if hose.actor.to_global(hose.joint.receiver.origin).distance_to(pose.origin)>.0001:
			hose._visual_receiver(before);continue
		last_result.merge({"placed":true,"reason":"supported","floor_y":hit.position.y,"envelope_bottom_y":bounds.position.y,"receiver_world":var_to_str(pose.origin),"elapsed_usec":Time.get_ticks_usec()-started},true)
		return true
	last_result.elapsed_usec=Time.get_ticks_usec()-started
	return false
