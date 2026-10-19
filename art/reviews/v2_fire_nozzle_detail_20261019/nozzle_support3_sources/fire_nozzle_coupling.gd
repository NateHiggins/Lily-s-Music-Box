extends Node3D
## Actual screw travel followed by free, swept carrying of the original nozzle.
## Parent actor retains maintenance, hand ownership and household persistence.
class CursorBody extends AnimatableBody3D:
	var provider: Callable
	func manipulation_target(hit: Dictionary) -> Dictionary:return provider.call(hit)
class LooseBody extends RigidBody3D:
	var provider: Callable
	func manipulation_target(hit: Dictionary) -> Dictionary:return provider.call(hit)
var actor: Node3D
var stock: RefCounted
var seat: MeshInstance3D
var nut: MeshInstance3D
var spigot: MeshInstance3D
var body: LooseBody
var receiver:=Transform3D.IDENTITY
var angle:=0.
var loose:=false
var spin:=0.
var clocking:=0.
var _observed:=false
var _speed:=0.
var _support: WeakRef
var _support_pose:=Transform3D.IDENTITY
var _last_contact: Node3D
var _lever_shapes: Dictionary={}
var _lever_rows: Array[Dictionary]=[]
var _restore_support:=false
var last_sweep_ms:=0.
var last_turn_ms:=0.
var _axial_min:=INF
func configure(owner_actor: Node3D) -> bool:
	actor=owner_actor;stock=preload("res://scripts/props/fire_nozzle_joint_stock.gd").new()
	if not stock.load_stock():return false
	# This is the original lower hose datum, now independent of repair facts.
	var old:=Basis(Vector3.BACK,1.5708)
	receiver=Transform3D(Basis(Vector3.BACK,1.5708+PI),Vector3(-.060,.068,.112)+old*Vector3(0,-.012,0))
	for draw: MeshInstance3D in actor._play_pipe.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("native_fire_part",""))=="F060":seat=draw
	if seat==null:return false
	seat.mesh=stock.meshes.HoseSeat;seat.material_override=stock.finish;seat.set_meta("native_fire_successor","fire_nozzle_joint/HoseSeat")
	seat.global_transform=actor.global_transform*receiver
	nut=stock.make_part("NozzleNut");add_child(nut);nut.transform=receiver
	spigot=stock.make_part("NozzleSpigot");actor._play_pipe.add_child(spigot)
	var fixed:=StaticBody3D.new();fixed.name="NativeNozzleSeatCollision";seat.add_child(fixed)
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(preload("res://scripts/props/fire_hose_rack.gd").imported_faces(seat.mesh))
	var collision:=CollisionShape3D.new();collision.shape=shape;fixed.add_child(collision)
	var hand:=CursorBody.new();hand.sync_to_physics=false;hand.name="NativeNozzleNutCursor";nut.add_child(hand);hand.provider=func(_hit: Dictionary):return nut_grip()
	shape=ConcavePolygonShape3D.new();shape.set_faces(preload("res://scripts/props/fire_hose_rack.gd").imported_faces(nut.mesh))
	collision=CollisionShape3D.new();collision.shape=shape;hand.add_child(collision)
	body=LooseBody.new();body.name="PhysicalNozzle";body.freeze=true;body.collision_layer=1;body.collision_mask=1;actor.add_child(body)
	body.provider=func(hit: Dictionary):return actor._grip("lever") if _lever_shapes.has(int(hit.get("shape",-1))) else body_grip()
	body.add_collision_exception_with(actor._bodies.lever)
	angle=0. if actor.nozzle_coupled else stock.maximum_angle();loose=not actor.nozzle_coupled;_observed=actor.nozzle_coupled
	body.transform=thread_pose(angle);_apply_visuals()
	for draw: MeshInstance3D in actor._play_pipe.find_children("*","MeshInstance3D",true,false):
		if draw==seat or draw.mesh==null:continue
		var frame: Transform3D=body.global_transform.affine_inverse()*draw.global_transform
		for corner in range(8):_axial_min=minf(_axial_min,(frame*draw.mesh.get_aabb().get_endpoint(corner)).y)
		if draw.is_ancestor_of(actor._lever):continue
		if actor._lever.is_ancestor_of(draw):
			for convex: ConvexPolygonShape3D in _draw_shapes(draw):
				collision=CollisionShape3D.new();collision.shape=convex;collision.transform=frame
				_lever_shapes[body.get_child_count()]=true;body.add_child(collision);_lever_rows.append({"shape":collision,"draw":draw})
		else:
			for convex: ConvexPolygonShape3D in _draw_shapes(draw):
				collision=CollisionShape3D.new();collision.shape=convex;collision.transform=frame;body.add_child(collision)
	return body.get_child_count()>0
func _draw_shapes(draw: MeshInstance3D) -> Array[ConvexPolygonShape3D]:
	if bool(draw.get_meta("nozzle_collision_solid",false)):
		var convex:=draw.mesh.create_convex_shape();convex.margin=.00001;return [convex]
	var aligned: Transform3D=draw.get_meta("nozzle_collision_axis",Transform3D.IDENTITY)
	var bounds: AABB=aligned*draw.mesh.get_aabb()
	var cuts: Array[float]=[bounds.position.y,bounds.end.y]
	if str(draw.get_meta("native_fire_part",""))=="F059":cuts=[bounds.position.y,.065,.168,bounds.end.y]
	return preload("res://scripts/props/native_annular_collision.gd").build(draw.mesh,cuts,48 if aligned==Transform3D.IDENTITY or actor._lever.is_ancestor_of(draw) else 24,aligned)
func thread_pose(value: float,phase: float=NAN) -> Transform3D:
	if is_nan(phase):phase=clocking
	return receiver*Transform3D(Basis(Vector3.UP,phase),Vector3(0,stock.body_y(value),0))
func _apply_visuals() -> void:
	actor._play_pipe.global_transform=body.global_transform
	seat.global_transform=actor.global_transform*receiver
	nut.transform=receiver*Transform3D(Basis(Vector3.UP,angle+spin),Vector3.ZERO)
	for row: Dictionary in _lever_rows:row.shape.global_transform=row.draw.global_transform
func sync() -> void:
	if body==null:return
	if actor.nozzle_coupled!=_observed:
		clocking=fposmod(spin,TAU);spin=clocking
		angle=0. if actor.nozzle_coupled else stock.maximum_angle();loose=not actor.nozzle_coupled;body.transform=thread_pose(angle);_support=null;_speed=0.
	if not loose:body.transform=thread_pose(angle)
	_observed=not loose and absf(angle)<.0001;actor.nozzle_coupled=_observed
	_apply_visuals()
func _grip(kind: String,part: Node3D) -> Dictionary:
	return {"owner":actor,"part":part,"frame":actor,"kind":kind,
		"begin":func():
			if not actor._claim("nozzle_body"):return false
			_support=null;_speed=0.;return true,
		"owns":func():return actor._hand=="nozzle_body","end":_release_body,
		"read":func():return body.position,"write":func(value: Vector3):
			if actor._hand=="nozzle_body":_carry(value)}
func body_grip() -> Dictionary:
	# A still-threaded body is constrained by its receiving thread. The nut is
	# the operable turning part; clearing it exposes genuine loose-body carrying.
	if not loose:return {}
	return _grip("free",actor._play_pipe)
func nut_grip() -> Dictionary:
	return {"owner":actor,"part":nut,"frame":self,"kind":"hinge","axis":receiver.basis.y,"minimum":-INF if loose else 0.,"maximum":INF if loose else stock.maximum_angle(),
		"read":func():return spin if loose else angle,"write":func(value: float):
			if actor._hand=="nozzle_nut":
				if loose:
					if is_finite(value):spin=fposmod(value,TAU);_apply_visuals()
				else:turn(value),
		"begin":func():return actor._claim("nozzle_nut"),"owns":func():return actor._hand=="nozzle_nut",
		"end":func():
			if not loose and angle>=stock.maximum_angle()-.000001:loose=true;_speed=0.
			sync();actor._release()}
func turn(value: float) -> void:
	if loose or not is_finite(value):return
	var wanted: float=clampf(value,0.,stock.maximum_angle())
	var pose: Transform3D=actor.global_transform*thread_pose(wanted)
	var query:=PhysicsTestMotionParameters3D.new();query.from=body.global_transform;query.motion=pose.origin-body.global_position;query.margin=.00002
	query.exclude_bodies=[(seat.get_child(0) as CollisionObject3D).get_rid(),(nut.get_child(0) as CollisionObject3D).get_rid(),actor._bodies.lever.get_rid()]
	var started: int=Time.get_ticks_usec()
	var blocked: bool=PhysicsServer3D.body_test_motion(body.get_rid(),query)
	last_turn_ms=(Time.get_ticks_usec()-started)/1000.
	if blocked:return
	angle=wanted;_observed=absf(angle)<.0001;actor.nozzle_coupled=_observed;sync()
func _carry(value: Vector3) -> void:
	if not loose or not value.is_finite():return
	var started: int=Time.get_ticks_usec()
	var pose: Transform3D=body.global_transform
	var remaining: Vector3=actor.global_basis*(value-body.position)
	_last_contact=null
	for step in range(4):
		if remaining.length_squared()<1e-12:break
		var query:=PhysicsTestMotionParameters3D.new();query.from=pose;query.motion=remaining;query.margin=.00002
		var exclusions: Array[RID]=[actor._bodies.lever.get_rid()]
		if _outside_receiver(pose,remaining):
			exclusions.append((seat.get_child(0) as CollisionObject3D).get_rid())
			exclusions.append((nut.get_child(0) as CollisionObject3D).get_rid())
		query.exclude_bodies=exclusions
		var result:=PhysicsTestMotionResult3D.new()
		if not PhysicsServer3D.body_test_motion(body.get_rid(),query,result):pose.origin+=remaining;break
		_last_contact=result.get_collider() as Node3D;pose.origin+=result.get_travel();remaining=result.get_remainder().slide(result.get_collision_normal())
	body.global_transform=pose;_apply_visuals()
	last_sweep_ms=(Time.get_ticks_usec()-started)/1000.
func _outside_receiver(pose: Transform3D,motion: Vector3) -> bool:
	# The entire swept nozzle lies beyond the fixed receiving stock's end
	# plane. Avoid GJK recovery against a mathematically disjoint tangent cap.
	# The bound is four float32 ULPs at the actual world origin, not a relaxed
	# fitting tolerance; inward motion beyond it still tests the real receiver.
	var fixed: Transform3D=actor.global_transform*receiver
	if pose.basis.y.dot(fixed.basis.y)<.999999:return false
	var scale: float=maxf(1.,maxf(pose.origin.length(),fixed.origin.length()))
	var precision: float=4.*1.1920928955078125e-7*scale+.0000001
	var start: float=(pose.origin-fixed.origin).dot(fixed.basis.y)+_axial_min
	var end: float=(pose.origin+motion-fixed.origin).dot(fixed.basis.y)+_axial_min
	return minf(start,end)>=nut.mesh.get_aabb().end.y-precision
func _release_body() -> void:
	if body.position.distance_to(thread_pose(stock.maximum_angle()).origin)<.0001:
		var phase: float=fposmod(spin,TAU)
		var wanted: Transform3D=actor.global_transform*thread_pose(stock.maximum_angle(),phase)
		var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=1;query.margin=.00002
		query.exclude=[body.get_rid(),actor._bodies.lever.get_rid(),(seat.get_child(0) as CollisionObject3D).get_rid(),(nut.get_child(0) as CollisionObject3D).get_rid()]
		var clear: bool=true
		var before: Quaternion=body.global_basis.get_rotation_quaternion();var after: Quaternion=wanted.basis.get_rotation_quaternion()
		var steps: int=maxi(1,ceili(before.angle_to(after)/.05))
		for step in range(1,steps+1):
			var pose:=Transform3D(Basis(before.slerp(after,float(step)/steps)),wanted.origin)
			for shape: CollisionShape3D in body.get_children():
				query.shape=shape.shape;query.transform=pose*shape.transform
				if not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():clear=false;break
			if not clear:break
		if clear:clocking=phase;spin=phase;loose=false;angle=stock.maximum_angle();body.transform=thread_pose(angle)
	_speed=0.;sync();actor._release()
func _physics_process(delta: float) -> void:
	if body==null:return
	sync()
	if not loose or actor._hand=="nozzle_body":return
	if _restore_support:_restore_support=false;_adopt_support()
	if _support!=null:
		var support: Node3D=_support.get_ref()
		if support!=null and support.global_transform.is_equal_approx(_support_pose):return
		_support=null
	_speed-=9.81*delta
	var before: Vector3=body.position
	_carry(before+Vector3.UP*maxf(-.04,_speed*delta))
	if is_instance_valid(_last_contact):
		# Real bearing rays establish support even if GJK recovery moved this
		# small curved stock by a few micrometres. Do not repeatedly resolve
		# an already supported pose or accept a side contact as a floor.
		_adopt_support()
		if _support!=null:_speed=0.
func _adopt_support() -> void:
	var vertices:=PackedVector3Array()
	for shape: CollisionShape3D in body.get_children():
		for point: Vector3 in shape.shape.points:vertices.append(shape.transform*point)
	var lowest: float=INF;var candidates: Array[Vector3]=[]
	for vertex: Vector3 in vertices:lowest=minf(lowest,(body.global_transform*vertex).y)
	for vertex: Vector3 in vertices:
		var point: Vector3=body.global_transform*vertex
		if point.y>lowest+.00005:continue
		var duplicate: bool=false
		for existing in candidates:
			if existing.distance_to(point)<.001:duplicate=true;break
		if not duplicate:candidates.append(point)
		if candidates.size()>=4:break
	var support: Node3D
	for point in candidates:
		var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.005,point-Vector3.UP*.005,1,[body.get_rid(),actor._bodies.lever.get_rid()])
		var hit: Dictionary=actor.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.position.distance_to(point)>.0001 or hit.normal.dot(Vector3.UP)<.99 or not hit.collider is Node3D:return
		if support!=null and support!=hit.collider:return
		support=hit.collider
	if support!=null:_support=weakref(support);_support_pose=support.global_transform;_speed=0.
func snapshot() -> Dictionary:return {"angle":angle,"spin":spin,"clocking":clocking,"loose":loose,"position":[body.position.x,body.position.y,body.position.z]}
func valid(value: Variant,made_up: bool) -> bool:
	if value is not Dictionary or value.size()!=5 or typeof(value.get("loose"))!=TYPE_BOOL:return false
	for key: String in ["spin","clocking"]:
		if typeof(value.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[key])):return false
	if value.clocking<0. or value.clocking>=TAU or value.spin<0. or value.spin>=TAU:return false
	if typeof(value.get("angle")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value.angle)) or value.angle<0. or value.angle>stock.maximum_angle():return false
	if value.get("position") is not Array or value.position.size()!=3:return false
	for coordinate: Variant in value.position:
		if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)):return false
	var at:=Vector3(value.position[0],value.position[1],value.position[2])
	if at.length()>10000.:return false
	if value.loose and absf(float(value.angle)-stock.maximum_angle())>.000001:return false
	if not value.loose and (at.distance_to(thread_pose(float(value.angle),float(value.clocking)).origin)>.000001 or absf(float(value.spin)-float(value.clocking))>.000001):return false
	return made_up==(not value.loose and absf(float(value.angle))<.0001)
func restore(value: Dictionary) -> void:
	angle=value.angle;spin=value.spin;clocking=value.clocking;loose=value.loose;_observed=actor.nozzle_coupled;_support=null;_speed=0.;_restore_support=true
	body.transform=Transform3D(receiver.basis*Basis(Vector3.UP,clocking),Vector3(value.position[0],value.position[1],value.position[2]));sync()
func restore_legacy(made_up: bool) -> void:
	angle=0. if made_up else stock.maximum_angle();spin=0.;clocking=0.;loose=not made_up;_observed=made_up
	_support=null;_speed=0.;_restore_support=true;body.transform=thread_pose(angle);sync()
