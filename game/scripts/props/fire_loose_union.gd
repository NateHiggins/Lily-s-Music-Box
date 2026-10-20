extends RefCounted
## Carried stationary hose end, with the unthreaded nut still retained on it.
## Existing mechanism owns all maintenance facts; this owns constrained motion.
var actor: Node3D
var active := false
var location := Vector3.ZERO
var _velocity := 0.0
var _rows: Array[Dictionary]=[]
var _broad: BoxShape3D
var _bounds: AABB
var _excluded: Array[RID]=[]
class Cursor extends AnimatableBody3D:
	var provider: Callable
	var observer: Callable
	func manipulation_target(hit: Dictionary) -> Dictionary:
		if observer.is_valid():observer.call(hit)
		return provider.call()
func configure(owner_actor: Node3D) -> void:
	actor=owner_actor
	# Exact visible stock remains the cursor authority, including the tail.
	for name: String in ["SwivelTail","HoseRetainer"]:
		var draw: MeshInstance3D=actor._coupling.get_node(name)
		var body:=Cursor.new()
		body.name="NativeJointCursor";body.sync_to_physics=false;body.collision_layer=1;body.collision_mask=0
		body.provider=func():return actor._grip("joint")
		if name=="SwivelTail":body.observer=actor._gasket_body.observe
		draw.add_child(body)
		# Convex annular sectors keep the real bore open and make the thin
		# sealing face selectable without tiny-triangle ray degeneracy.
		var bounds: AABB=draw.mesh.get_aabb()
		var cuts: Array[float]=[bounds.position.y,bounds.end.y]
		if name=="SwivelTail":cuts.insert(1,.017)
		for stock: ConvexPolygonShape3D in preload("res://scripts/props/native_annular_collision.gd").build(draw.mesh,cuts):
			var shape:=CollisionShape3D.new();shape.shape=stock;body.add_child(shape)
		_excluded.append(body.get_rid())
	_excluded.append(actor._bodies.joint.get_rid())
func _ensure_stock() -> void:
	if _broad!=null:return
	var draws: Array[MeshInstance3D]=[actor._joint_nut,actor._coupling.get_node("SwivelTail"),actor._coupling.get_node("HoseRetainer")]
	for child: MeshInstance3D in actor._coupling.find_children("*","MeshInstance3D",true,false):
		if str(child.get_meta("native_fire_part",""))=="F029":draws.append(child)
	var first: bool=true
	for draw: MeshInstance3D in draws:
		var frame: Transform3D=actor._coupling.global_transform.affine_inverse()*draw.global_transform
		var box: AABB=frame*draw.mesh.get_aabb()
		_bounds=box if first else _bounds.merge(box);first=false
		var bounds: AABB=draw.mesh.get_aabb()
		var cuts: Array[float]=[bounds.position.y,bounds.end.y]
		if draw==actor._joint_nut:cuts=[bounds.position.y,.017,.020,bounds.end.y]
		elif draw.name=="SwivelTail":cuts=[bounds.position.y,.017,bounds.end.y]
		for shape: ConvexPolygonShape3D in preload("res://scripts/props/native_annular_collision.gd").build(draw.mesh,cuts):_rows.append({"shape":shape,"frame":frame})
	_broad=BoxShape3D.new();_broad.size=_bounds.size
func receiving() -> Vector3:
	return Vector3(.17,actor._joint_stock.union_pose(actor._maximum("joint")).origin.y,.098)
func reachable(value: Vector3) -> bool:
	var points: Dictionary=actor.flexible_outlet_hose_points()
	return actor.get_node("NativeHoseRuns")._live_lead.can_reach(points.first,value+Vector3(0,-.068,0))
func obstructed(value: Vector3) -> bool:
	_ensure_stock()
	var pose: Transform3D=actor.global_transform*Transform3D(Basis.IDENTITY,value)
	var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=1;query.exclude=_excluded;query.margin=.00001
	if actor.gasket_seated:
		var excluded: Array[RID]=_excluded.duplicate();excluded.append(actor._gasket_body.get_rid());query.exclude=excluded
	query.shape=_broad;query.transform=pose*Transform3D(Basis.IDENTITY,_bounds.get_center())
	var space: PhysicsDirectSpaceState3D=actor.get_world_3d().direct_space_state
	if space.intersect_shape(query,1).is_empty():return false
	for row: Dictionary in _rows:
		query.shape=row.shape;query.transform=pose*row.frame
		if not space.intersect_shape(query,1).is_empty():return true
	return false
func move_to(value: Vector3) -> void:
	if not active or not value.is_finite():return
	var before: Vector3=location
	var steps: int=maxi(1,ceili(before.distance_to(value)/.002))
	for step in range(1,steps+1):
		var proposed: Vector3=before.lerp(value,float(step)/steps)
		if not reachable(proposed) or obstructed(proposed):break
		location=proposed
	actor._apply_joint_pose()
func release() -> void:
	if not active:
		if actor._union_angle>=actor._maximum("joint")-.000001:
			active=true;location=actor._coupling.position;_velocity=0.
		return
	# Within actual radial thread clearance; catching never tightens or repairs.
	if location.distance_to(receiving())<.0001:
		active=false;_velocity=0.;actor._apply_joint_pose()
func tick(delta: float) -> void:
	if not active or actor._hand=="joint":return
	_velocity-=9.81*delta
	var before: Vector3=location
	move_to(location+Vector3.UP*maxf(-.04,_velocity*delta))
	if location.is_equal_approx(before):_velocity=0.
func grip() -> Dictionary:
	return {"owner":actor,"part":actor._joint_nut,"frame":actor,"kind":"free",
		"read":func():return location,"write":func(value: Vector3):
			if actor._hand=="joint":move_to(value),
		"begin":func():
			var claimed: bool=actor._claim("joint")
			if claimed:_velocity=0.
			return claimed,
		"owns":func():return actor._hand=="joint",
		"end":actor._release}
