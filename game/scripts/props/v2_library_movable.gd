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
var _push_frame := -1
var _pushed: Dictionary = {}

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
	_before=transform
	_held=true;_hand_tag=tag
	freeze=true
	linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO
	return true

func _release() -> void:
	var changed:=not transform.is_equal_approx(_before)
	_held=false;_hand_tag=""
	freeze=false;sleeping=false
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
	return {"owner":shelf,"part":self,"frame":shelf,"kind":"hinge","axis":axis,
		"minimum":-TAU,"maximum":TAU,"minimum_lever":.025,
		"read":func(): return _turn_value,
		"write":func(value: float):
			if _held and _hand_tag=="turn": _turn(value),
		"begin":func():
			if not _claim("turn"): return false
			_turn_origin=basis;_turn_axis=axis;_turn_value=0.;return true,
		"owns":func(): return _held and _hand_tag=="turn",
		"end":_release}

func _carry(value: Vector3) -> void:
	if not value.is_finite(): return
	var bounded: Vector3=shelf.limit_library_position(value)
	var pose:=global_transform
	var remaining: Vector3=shelf.global_basis*(bounded-position)
	_last_motion={}
	for slide in 4:
		if remaining.length_squared()<1e-12: break
		var query:=PhysicsTestMotionParameters3D.new()
		query.from=pose;query.motion=remaining;query.margin=.00002
		var result:=PhysicsTestMotionResult3D.new()
		if not _sweep_world(query,result): pose.origin+=remaining;break
		_last_motion={"collider":result.get_collider(),"normal":result.get_collision_normal(),"travel":result.get_travel(),"remainder":result.get_remainder(),"depth":result.get_collision_depth()}
		var other:=result.get_collider() as RigidBody3D
		var incident: Vector3=-result.get_collision_normal()
		if other!=null and not other.freeze and (remaining.dot(incident)>.0000001 or result.get_collision_depth()>.00002):
			var frame:=Engine.get_physics_frames()
			if frame!=_push_frame: _push_frame=frame;_pushed.clear()
			if not _pushed.has(other.get_instance_id()):
				other.sleeping=false
				other.apply_impulse(incident*minf(.12,other.mass*.25),result.get_collision_point()-other.global_position)
				_pushed[other.get_instance_id()]=true
		pose.origin+=result.get_travel()
		remaining=result.get_remainder().slide(result.get_collision_normal())
	global_transform=pose

func _separating_support(collider: Object, pose: Transform3D, motion: Vector3) -> bool:
	# A native stock entirely above a support's highest vertex throughout its
	# sweep cannot strike it. This removes only a proved backend recovery-skin
	# contact; each other case board retains its own solid and collision query.
	if not collider is StaticBody3D: return false
	var ceiling: float=-INF
	for child: Node in collider.get_children():
		if not child is CollisionShape3D or child.disabled: continue
		if child.shape is ConvexPolygonShape3D:
			for point: Vector3 in child.shape.points: ceiling=maxf(ceiling,(child.global_transform*point).y+float(child.shape.margin))
		elif child.shape is BoxShape3D:
			var box:=AABB(-child.shape.size*.5,child.shape.size)
			for corner in 8: ceiling=maxf(ceiling,(child.global_transform*box.get_endpoint(corner)).y+float(child.shape.margin))
		else: return false
	if not is_finite(ceiling): return false
	for shape: CollisionShape3D in _solids:
		if shape.disabled: continue
		if not shape.shape is ConvexPolygonShape3D: return false
		for point: Vector3 in shape.shape.points:
			if (pose*shape.transform*point).y+minf(0.,motion.y)-float(shape.shape.margin)<ceiling: return false
	return true

func _sweep_world(query: PhysicsTestMotionParameters3D, result: PhysicsTestMotionResult3D) -> bool:
	for attempt in 8:
		if not PhysicsServer3D.body_test_motion(get_rid(),query,result): return false
		var collider: Object=result.get_collider()
		if not _separating_support(collider,query.from,query.motion): return true
		var exclusions: Array[RID]=query.exclude_bodies
		if exclusions.has(collider.get_rid()): return true
		exclusions.append(collider.get_rid());query.exclude_bodies=exclusions
	return true

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
	_held=false;_hand_tag=""
	freeze=true
	position=Vector3(value.position[0],value.position[1],value.position[2])
	basis=Basis(Quaternion(value.rotation[0],value.rotation[1],value.rotation[2],value.rotation[3]))
	linear_velocity=Vector3(value.velocity[0],value.velocity[1],value.velocity[2])
	angular_velocity=Vector3(value.spin[0],value.spin[1],value.spin[2])
	freeze=false;sleeping=bool(value.sleeping)
