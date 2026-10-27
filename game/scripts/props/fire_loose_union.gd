extends RefCounted
## Carried stationary hose end, with the unthreaded nut still retained on it.
## Existing mechanism owns facts and thread travel; release chooses authored poses.
var actor: Node3D
var active := false
var location := Vector3.ZERO
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

func receiving() -> Vector3:
	return Vector3(.17,actor._joint_stock.union_pose(actor._maximum("joint")).origin.y,.098)

func reachable(value: Vector3) -> bool:
	var points: Dictionary=actor.flexible_outlet_hose_points()
	return actor.get_node("NativeHoseRuns")._live_lead.can_reach(points.first,value+Vector3(0,-.068,0))

func move_to(value: Vector3) -> void:
	if not active or not value.is_finite() or not reachable(value):return
	location=value;actor._apply_joint_pose()
func resting() -> Vector3:
	return receiving()+Vector3(0,-.025,.060)

func release() -> void:
	if not active:
		if actor._union_angle>=actor._maximum("joint")-.000001:
			active=true;location=actor._coupling.position
		return
	var target: Vector3=receiving()
	var distance: float=location.distance_to(target)
	# A generous mating zone restores the thread grip, never its tightness.
	if distance<=.045 and distance<location.distance_to(resting()):
		active=false;location=target
	else:location=resting()
	actor._apply_joint_pose()

func grip() -> Dictionary:
	return {"owner":actor,"part":actor._joint_nut,"frame":actor,"kind":"free",
		"read":func():return location,"write":func(value: Vector3):
			if actor._hand=="joint":move_to(value),
		"begin":func():
			var claimed: bool=actor._claim("joint")
			return claimed,
		"owns":func():return actor._hand=="joint",
		"end":actor._release}

