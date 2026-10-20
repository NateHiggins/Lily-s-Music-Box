extends RigidBody3D
## One retained native washer: carried, dropped, inspected and fitted physically.
var actor: Node3D
var draw: MeshInstance3D
var _held := false
var _fall_speed := 0.0
var _support: WeakRef
var _support_pose := Transform3D.IDENTITY
var _last_contact: Node3D
var _restore_support_pending := false
func configure(owner_actor: Node3D) -> void:
	actor=owner_actor;draw=actor._spare_gasket
	position=draw.position;mass=.012;freeze=true;collision_layer=1;collision_mask=1
	physics_material_override=PhysicsMaterial.new();physics_material_override.friction=.85
	var bounds: AABB=draw.mesh.get_aabb()
	var cuts: Array[float]=[bounds.position.y,bounds.end.y]
	for shape: ConvexPolygonShape3D in preload("res://scripts/props/native_annular_collision.gd").build(draw.mesh,cuts,32):
		var collision:=CollisionShape3D.new();collision.shape=shape;add_child(collision)
	sync()
func seat_position() -> Vector3:return actor._coupling.position+Vector3(0,.020,0)
func seatable() -> bool:
	if not actor.door_open or actor.coupling_made_up:return false
	var delta: Vector3=position-seat_position()
	return Vector2(delta.x,delta.z).length()<.00025 and absf(delta.y)<.0001 and basis.y.dot(Vector3.UP)>.9999
func _fit() -> void:
	actor.gasket_seated=true;freeze=true;linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO
	position=seat_position();basis=Basis.IDENTITY;sync()
	if actor._click!=null:actor._click.play()
	# Fitting alone does not manufacture the separate seen/inspection fact.
	actor.manipulation_changed.emit()
func sync() -> void:
	if actor==null or draw==null:return
	if actor.gasket_seated:
		freeze=true;position=seat_position();basis=Basis.IDENTITY
	draw.global_transform=global_transform;draw.visible=true
func _physics_process(delta: float) -> void:
	if actor==null:return
	if not _held and not actor.gasket_seated:
		if _restore_support_pending:
			_restore_support_pending=false
			_adopt_restored_support()
		if _support!=null:
			var support: Node3D=_support.get_ref()
			if support!=null and support.global_transform.is_equal_approx(_support_pose):
				sync();return
			_support=null
		# The engine's centimetre-scale penetration solver cannot support a
		# 1.5mm washer reliably. Sweep its actual annular stock for gravity,
		# using the same20um contact margin as hand movement.
		_fall_speed-=9.81*delta
		var before: Vector3=position
		var goal: Vector3=position+Vector3.UP*maxf(-.04,_fall_speed*delta)
		var seat: Vector3=seat_position()
		# Do not step over the existing100um fit band during gravity. Sweep
		# to a point inside it, then let the unchanged seatable() authority
		# decide from the actual collision-constrained pose. An obstruction
		# can still stop the washer above the seat or push it out of alignment.
		if actor.door_open and not actor.coupling_made_up and basis.y.dot(Vector3.UP)>.9999 \
				and Vector2(position.x-seat.x,position.z-seat.z).length()<.00025 \
				and position.y>=seat.y+.00005 and goal.y<=seat.y+.00005:
			goal.y=seat.y+.00005
		var limited: Dictionary=_limit_gravity(goal)
		_carry(limited.position)
		if _last_contact==null and limited.contact!=null and position.distance_to(limited.position)<.000001:_last_contact=limited.contact
		if position.distance_to(before)<.000001:
			_fall_speed=0.
			if is_instance_valid(_last_contact):
				_support=weakref(_last_contact);_support_pose=_last_contact.global_transform
				actor.manipulation_changed.emit()
		if seatable():_fit()
	sync()
func _limit_gravity(goal: Vector3) -> Dictionary:
	# Supplement the convex sweep for sub-millimetre sheet obstructions. Its
	# narrow phase can miss them while the1.5mm ring crosses in one tick.
	# These are real unfiltered body rays through the native bearing annulus;
	# only this washer is excluded. Retain the same20um contact clearance.
	var distance: float=maxf(0.,position.y-goal.y)
	var contact: Node3D
	if distance>0.:
		var bounds: AABB=draw.mesh.get_aabb()
		var radius: float=(absf(bounds.end.x)+float(actor._joint_stock.data.dimensions.bore_radius_m))*.5
		var direction: Vector3=actor.global_basis*Vector3.DOWN
		for index in 16:
			var angle: float=TAU*index/16.
			var start: Vector3=to_global(Vector3(radius*cos(angle),bounds.position.y,radius*sin(angle)))
			# Extend below the proposed stop for stable ray precision, accepting
			# only a hit inside the original movement plus its contact margin.
			var query:=PhysicsRayQueryParameters3D.create(start,start+direction*maxf(.010,distance+.00002),1,[get_rid()])
			var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():continue
			var travel: float=start.distance_to(hit.position)
			if travel<=distance+.00002:
				distance=maxf(0.,travel-.00002);contact=hit.collider as Node3D
	return {"position":Vector3(goal.x,position.y-distance,goal.z),"contact":contact}
func _adopt_restored_support() -> void:
	# Reconstruct resting contact from real collision, without re-solving an
	# already supported saved pose and accumulating micrometre recovery drift.
	# An unsupported save still falls; moving/removing its support wakes it.
	if basis.y.dot(Vector3.UP)<.9999:return
	var support: Node3D
	var bounds: AABB=draw.mesh.get_aabb()
	var radius: float=(absf(bounds.end.x)+float(actor._joint_stock.data.dimensions.bore_radius_m))*.5
	for index in range(4):
		var angle: float=TAU*index/4.
		var point: Vector3=to_global(Vector3(radius*cos(angle),bounds.position.y,radius*sin(angle)))
		# A longer ray avoids near-zero ray-direction degeneracy; acceptance
		# still requires the original100um contact distance at every sample.
		var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.005,point-Vector3.UP*.005,1,[get_rid()])
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.position.distance_to(point)>.0001 or hit.normal.dot(Vector3.UP)<.99 or not hit.collider is Node3D:return
		if support!=null and support!=hit.collider:return
		support=hit.collider
	if support!=null:
		_support=weakref(support);_support_pose=support.global_transform;_fall_speed=0.
func observe(hit: Dictionary) -> void:
	if actor.gasket_seen or not actor.door_open or actor.coupling_made_up:return
	var player: Node=actor.get_tree().get_first_node_in_group("player_controller")
	if player==null or not player.inspecting() or player.inspect_owner!=actor:return
	var local: Vector3=actor._coupling.to_local(hit.position)
	var surface_y: float=.020+float(actor._joint_stock.data.dimensions.gasket_thickness_m) if actor.gasket_seated else .020
	var radius: float=Vector2(local.x,local.z).length()
	if absf(local.y-surface_y)>.0001 or radius<.01915 or radius>.02265:return
	actor.gasket_seen=true;actor.manipulation_changed.emit()
func manipulation_target(hit: Dictionary) -> Dictionary:
	if actor==null or not actor.door_open:return {}
	if actor.gasket_seated:
		observe(hit)
		if actor.coupling_made_up:return {}
	return {"owner":actor,"part":self,"frame":actor,"kind":"free",
		"read":func():return position,"write":func(value: Vector3):
			if _held:_carry(value),
		"begin":func():
			if not actor._claim("gasket"):return false
			_held=true;_restore_support_pending=false;_support=null;_fall_speed=0.;freeze=true;linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO
			actor.gasket_seated=false;return true,
		"owns":func():return _held and actor._hand=="gasket",
		"end":func():
			_held=false
			if seatable():_fit()
			else:_fall_speed=0.
			actor._release()}
func _carry(value: Vector3) -> void:
	if not value.is_finite():return
	_last_contact=null
	var pose: Transform3D=global_transform
	var remaining: Vector3=actor.global_basis*(value-position)
	for slide in range(4):
		if remaining.length_squared()<1e-12:break
		var query:=PhysicsTestMotionParameters3D.new();query.from=pose;query.motion=remaining;query.margin=.00002
		var result:=PhysicsTestMotionResult3D.new()
		if not PhysicsServer3D.body_test_motion(get_rid(),query,result):pose.origin+=remaining;break
		_last_contact=result.get_collider() as Node3D
		pose.origin+=result.get_travel();remaining=result.get_remainder().slide(result.get_collision_normal())
	global_transform=pose;sync()
func snapshot() -> Dictionary:
	var q: Quaternion=basis.get_rotation_quaternion()
	return {"position":[position.x,position.y,position.z],"rotation":[q.x,q.y,q.z,q.w]}
static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=2:return false
	for key: String in ["position","rotation"]:
		if value.get(key) is not Array or value[key].size()!=(3 if key=="position" else 4):return false
		for item: Variant in value[key]:
			if typeof(item) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(item)):return false
	var q:=Quaternion(value.rotation[0],value.rotation[1],value.rotation[2],value.rotation[3])
	return Vector3(value.position[0],value.position[1],value.position[2]).length()<10000. and absf(q.length_squared()-1.)<.0001
func restore(value: Dictionary) -> void:
	_held=false;_support=null;_fall_speed=0.;linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO
	_restore_support_pending=true
	position=Vector3(value.position[0],value.position[1],value.position[2])
	basis=Basis(Quaternion(value.rotation[0],value.rotation[1],value.rotation[2],value.rotation[3]))
	freeze=true;sync()
