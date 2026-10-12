extends RefCounted
## Blocking shell follows a hand-driven leaf; swept proposals stop at solids.
static func install(part: Node3D) -> void:
	var body := AnimatableBody3D.new()
	body.name="HandMovedCollision";body.sync_to_physics=false
	part.add_child(body)
	for draw: MeshInstance3D in part.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null: continue
		var shape := CollisionShape3D.new()
		shape.shape=draw.mesh.create_convex_shape()
		body.add_child(shape)
		shape.global_transform=draw.global_transform

static func clear(owner: Node3D,part: Node3D,pose: Transform3D) -> bool:
	var excluded: Array[RID] = []
	for body: CollisionObject3D in owner.find_children("*","CollisionObject3D",true,false): excluded.append(body.get_rid())
	var inverse := part.global_transform.affine_inverse()
	for shape: CollisionShape3D in part.find_children("*","CollisionShape3D",true,false):
		if shape.disabled or not shape.get_parent() is PhysicsBody3D: continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape=shape.shape;query.margin=.001;query.exclude=excluded
		query.transform=part.get_parent().global_transform*pose*inverse*shape.global_transform
		if not owner.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	return true

static func limited(owner: Node3D,part: Node3D,axis: Vector3,before: float,proposed: float,sliding: bool) -> float:
	var count := maxi(1,ceili(absf(proposed-before)/(.01 if sliding else .025)))
	var accepted := before
	for step in range(1,count+1):
		var candidate := lerpf(before,proposed,float(step)/count)
		var pose := part.transform
		if sliding: pose.origin+=axis*(candidate-before)
		else: pose.basis=Basis(axis,candidate-before)*pose.basis
		if not clear(owner,part,pose): break
		accepted=candidate
	return accepted
