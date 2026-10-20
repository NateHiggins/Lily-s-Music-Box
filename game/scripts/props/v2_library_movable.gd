extends RigidBody3D
## One physical stock; its shelf remains the interaction and durable-save owner.
signal settled
var shelf: Node3D
var stock_id := ""
var _held := false
var _hand_tag := ""
var _before := Transform3D.IDENTITY
var _turn_origin := Basis.IDENTITY
var _turn_axis := Vector3.UP
var _turn_value := 0.0
var _solids: Array[CollisionShape3D] = []
var _last_motion: Dictionary = {}
var _contact_ids: Dictionary = {}
var _push_frame := -1
var _pushed: Dictionary = {}

var _rest_until := -1
var _rest_pose := Transform3D.IDENTITY
var _rest_velocity := Vector3.ZERO
var _rest_spin := Vector3.ZERO

func start_at_rest() -> void:
	# Shape/mass synchronization can wake newly placed bodies after sleeping
	# is requested. Adopt the construction/save pose once during that first
	# synchronization, never in response to a later collision or hand motion.
	_rest_pose=transform;_rest_velocity=linear_velocity;_rest_spin=angular_velocity
	_rest_until=Engine.get_physics_frames()+2
	sleeping=true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var deadline:=_rest_until
	_rest_until=-1
	if deadline<Engine.get_physics_frames() or _held: return
	state.transform=get_parent().global_transform*_rest_pose
	state.linear_velocity=_rest_velocity;state.angular_velocity=_rest_spin
	state.sleeping=true

func _ready() -> void:
	collision_layer=1;collision_mask=1
	continuous_cd=true
	can_sleep=true
	freeze_mode=RigidBody3D.FREEZE_MODE_KINEMATIC
	var contact:=PhysicsMaterial.new()
	contact.friction=.85;contact.bounce=0.
	physics_material_override=contact
	sleeping_state_changed.connect(func():
		if sleeping and not _held: settled.emit())

func manipulation_target(_hit: Dictionary) -> Dictionary: return grip()

func _claim(tag: String) -> bool:
	if _held or not shelf.claim_library_hand(self,tag): return false
	_rest_until=-1
	_contact_ids.clear()
	_before=transform
	_held=true;_hand_tag=tag
	freeze=true
	linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO
	return true

func _release() -> void:
	var changed:=not transform.is_equal_approx(_before)
	_held=false;_hand_tag=""
	freeze=shelf.has_method("supports_inspected_stock") and shelf.supports_inspected_stock(self);sleeping=false
	shelf.release_library_hand(self,changed)

func grip() -> Dictionary:
	return {"owner":shelf,"part":self,"frame":shelf,"kind":"free",
		"read":func(): return position,
		"write":func(value: Vector3):
			if _held and _hand_tag=="body": _carry(value),
		"begin":func(): return _claim("body"),
		"owns":func(): return _held and _hand_tag=="body",
		"end":_release}

func turn_grip(axis: Vector3) -> Dictionary:
	return {"owner":shelf,"part":self,"frame":shelf,"kind":"hinge","axis":func(): return _turn_axis,
		"minimum":-TAU,"maximum":TAU,"minimum_lever":.025,
		"read":func(): return _turn_value,
		"write":func(value: float):
			if _held and _hand_tag=="turn": _turn(value),
		"begin":func():
			if not _claim("turn"): return false
			_turn_origin=basis;_turn_axis=basis*axis;_turn_value=0.;return true,
		"owns":func(): return _held and _hand_tag=="turn",
		"end":_release}

func _shape_query(solid: CollisionShape3D, pose: Transform3D) -> PhysicsShapeQueryParameters3D:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=solid.shape;query.transform=pose*solid.transform
	query.exclude=[get_rid()];query.margin=.00002;query.collision_mask=collision_mask
	return query

func _contact(info: Dictionary, motion: Vector3) -> void:
	var other:=instance_from_id(int(info.collider_id)) as CollisionObject3D
	if other==null: return
	_contact_ids[other.get_instance_id()]=true
	var normal: Vector3=info.normal
	_last_motion={"collider":other,"normal":normal,"point":info.point}
	if other is RigidBody3D and not other.freeze and motion.dot(-normal)>.0000001:
		_push_stock(other,-normal,info.point)

func _carry(value: Vector3) -> void:
	if not value.is_finite(): return
	var bounded: Vector3=shelf.limit_library_position(value)
	var pose:=global_transform
	var remaining: Vector3=shelf.global_basis*(bounded-position)
	var space:=get_world_3d().direct_space_state
	_last_motion={}
	for slide in 4:
		if remaining.length_squared()<1e-12: break
		# Casts deliberately ignore existing overlap. First constrain movement
		# into resting contacts; separating/tangential input remains available.
		for solid: CollisionShape3D in _solids:
			var rest:=space.get_rest_info(_shape_query(solid,pose))
			if not rest.is_empty() and remaining.dot(rest.normal)<-.0000001:
				_contact(rest,remaining)
				remaining=remaining.slide(rest.normal)
		if remaining.length_squared()<1e-12: break
		var safe:=1.
		var unsafe:=1.
		var contact_query: PhysicsShapeQueryParameters3D
		for solid: CollisionShape3D in _solids:
			var query:=_shape_query(solid,pose);query.motion=remaining
			var fractions:=space.cast_motion(query)
			if fractions[0]<safe:
				safe=fractions[0];unsafe=fractions[1];contact_query=query
		if contact_query==null:
			pose.origin+=remaining;break
		# Recover the first impact normal just inside its unsafe fraction.
		# Keep the original native-piece frame for geometric refinement: the
		# engine's fraction can be coarse relative to a 1mm felt sole.
		var from:=contact_query.transform
		var probe_fraction:=.00005/maxf(remaining.length(),.000001)
		contact_query.transform.origin+=remaining*minf(1.,unsafe+probe_fraction)
		contact_query.motion=Vector3.ZERO
		var hit:=space.get_rest_info(contact_query)
		if hit.is_empty(): break
		var normal: Vector3=hit.normal
		var approach: float=-remaining.dot(normal)
		if approach>.0000001:
			var edge: float=INF
			for vertex: Vector3 in contact_query.shape.points: edge=minf(edge,(from*vertex).dot(normal))
			var clearance: float=edge-hit.point.dot(normal)-.00002
			safe=minf(safe,maxf(0.,clearance/approach))
		pose.origin+=remaining*safe
		_contact(hit,remaining)
		remaining=(remaining*(1.-safe)).slide(normal)
	global_transform=pose

func _push_stock(other: RigidBody3D, direction: Vector3, point: Vector3) -> void:
	var frame:=Engine.get_physics_frames()
	if frame!=_push_frame: _push_frame=frame;_pushed.clear()
	if _pushed.has(other.get_instance_id()): return
	other.sleeping=false
	other.apply_impulse(direction*minf(.12,other.mass*.25),point-other.global_position)
	_pushed[other.get_instance_id()]=true

func _clear_pose(pose: Transform3D, selected: Array[CollisionShape3D]=[]) -> bool:
	var solids: Array[CollisionShape3D]=_solids if selected.is_empty() else selected
	for shape: CollisionShape3D in solids:
		if shape.disabled: continue
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=shape.shape;query.transform=pose*shape.transform
		query.exclude=[get_rid()];query.margin=.00001;query.collision_mask=collision_mask
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	return true

func _turn(proposed: float) -> void:
	if not is_finite(proposed): return
	var target:=clampf(proposed,-TAU,TAU)
	var steps:=maxi(1,ceili(absf(target-_turn_value)/.02))
	var before:=_turn_value
	for index in range(1,steps+1):
		var value:=lerpf(before,target,float(index)/steps)
		var local_pose:=transform
		local_pose.basis=Basis(_turn_axis,value)*_turn_origin
		if not _clear_pose(shelf.global_transform*local_pose): break
		transform=local_pose;_turn_value=value

func stock_snapshot() -> Dictionary:
	var q:=basis.get_rotation_quaternion().normalized()
	return {"position":[position.x,position.y,position.z],"rotation":[q.x,q.y,q.z,q.w],
		"velocity":[linear_velocity.x,linear_velocity.y,linear_velocity.z],
		"spin":[angular_velocity.x,angular_velocity.y,angular_velocity.z],"sleeping":sleeping}

static func valid_stock(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=5 or value.get("sleeping") is not bool: return false
	for key: String in ["position","rotation","velocity","spin"]:
		if value.get(key) is not Array or value[key].size()!=(4 if key=="rotation" else 3): return false
		for item: Variant in value[key]:
			if typeof(item) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(item)): return false
	var q:=Quaternion(value.rotation[0],value.rotation[1],value.rotation[2],value.rotation[3])
	return absf(q.length_squared()-1.)<.0001 and Vector3(value.position[0],value.position[1],value.position[2]).length()<20. \
		and Vector3(value.velocity[0],value.velocity[1],value.velocity[2]).length()<100. \
		and Vector3(value.spin[0],value.spin[1],value.spin[2]).length()<100.

func restore_stock(value: Dictionary) -> void:
	_rest_until=-1
	_held=false;_hand_tag=""
	freeze=true
	position=Vector3(value.position[0],value.position[1],value.position[2])
	basis=Basis(Quaternion(value.rotation[0],value.rotation[1],value.rotation[2],value.rotation[3]))
	linear_velocity=Vector3(value.velocity[0],value.velocity[1],value.velocity[2])
	angular_velocity=Vector3(value.spin[0],value.spin[1],value.spin[2])
	freeze=false;sleeping=bool(value.sleeping)
	if sleeping: start_at_rest()
