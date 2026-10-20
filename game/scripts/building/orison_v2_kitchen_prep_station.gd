extends Node3D
## Native food-preparation stock; household state owns persistent loose poses.
signal manipulation_changed
var tools: Dictionary={}
var held: RigidBody3D
var payload: Array[RigidBody3D]=[]
var record: Dictionary
var _fall_speed: Dictionary={}
var _rests: Dictionary={}
var hulls: Dictionary={}

func _bottom_points(body: RigidBody3D) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	for hull: Array in hulls[str(body.name)]:
		var low:=INF;var points: Array[Vector3]=[]
		for vertex: Array in hull:
			var point: Vector3=body.to_global(Vector3(vertex[0],vertex[1],vertex[2]))
			if point.y<low-.000001:points.clear();low=point.y
			if absf(point.y-low)<.000001:points.append(point)
		var center:=Vector3.ZERO
		for point: Vector3 in points:center+=point
		center/=maxi(1,points.size());result.append(center)
		for index in range(0,points.size(),maxi(1,int(ceil(points.size()/8.)))):result.append(points[index])
		# Broad faces can bridge a narrow bearing between their vertices.
		# Convex combinations remain on the actual native bottom plane.
		for index in range(0,points.size(),maxi(1,int(ceil(points.size()/8.)))):
			result.append(center.lerp(points[index],.9));result.append(center.lerp(points[index],.5))
	return result

func _physics_process(delta: float) -> void:
	for body: RigidBody3D in tools.values():
		if body==held or body in payload:continue
		if _rests.has(body.name):
			var rest: Dictionary=_rests[body.name];var support: Node3D=rest.owner.get_ref()
			if is_instance_valid(support) and support.global_transform==rest.support_pose and body.global_transform==rest.pose:continue
			_rests.erase(body.name)
		var speed: float=float(_fall_speed.get(body.name,0.))+9.81*delta
		var travel:=minf(.04,speed*delta);var bearing: Dictionary={}
		# Cast from the actual lowest native hull vertices. Thin wooden stock
		# otherwise sinks into triangle supports by Jolt's resting penetration.
		for point: Vector3 in _bottom_points(body):
			var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.003,point-Vector3.UP*(travel+.003),1,[body.get_rid()])
			var hit:=get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.normal.y>.5 and point.y-hit.position.y<=travel:
				travel=point.y-hit.position.y;bearing=hit
		body.global_position.y-=travel
		_fall_speed[body.name]=speed if bearing.is_empty() else 0.
		if not bearing.is_empty():_rests[body.name]={"owner":weakref(bearing.collider),"support_pose":bearing.collider.global_transform,"pose":body.global_transform}

func manipulation_target(hit: Dictionary) -> Dictionary:
	var body:=hit.get("collider") as RigidBody3D
	if body==null or not tools.values().has(body):return {}
	return {"owner":self,"part":body,"frame":self,"kind":"free",
		"read":func():return body.position,"write":func(value: Vector3):
			if held==body:_carry(body,value),
		"begin":func():
			if held!=null or RealityState.save_write_blocked:return false
			held=body;payload.clear()
			# A pin/bowl actually borne by the board travels with that bearing.
			# Test the native support, rather than guessing from matching names.
			for other: RigidBody3D in tools.values():
				if other==body or other.global_position.y<body.global_position.y+.015:continue
				var query:=PhysicsRayQueryParameters3D.create(other.global_position+Vector3.UP*.01,other.global_position-Vector3.UP*.08,1,[other.get_rid()])
				var support:=get_world_3d().direct_space_state.intersect_ray(query)
				if support.get("collider")==body:payload.append(other)
			for part: RigidBody3D in [body]+payload:
				_rests.erase(part.name);_fall_speed[part.name]=0.
				part.freeze=true;part.linear_velocity=Vector3.ZERO;part.angular_velocity=Vector3.ZERO
			return true,
		"owns":func():return held==body,
		"end":func():
			held=null
			for part: RigidBody3D in [body]+payload:_fall_speed[part.name]=0.
			payload.clear();manipulation_changed.emit()}

func _carry(body: RigidBody3D,value: Vector3) -> void:
	if not value.is_finite():return
	var remaining: Vector3=global_basis*(value-body.position)
	var package: Array[RigidBody3D]=[body];package.append_array(payload)
	var excluded: Array[RID]=[]
	for part: RigidBody3D in package:excluded.append(part.get_rid())
	for step in range(4):
		if remaining.length_squared()<1e-12:break
		var accepted:=remaining;var normal:=Vector3.ZERO
		for part: RigidBody3D in package:
			var query:=PhysicsTestMotionParameters3D.new();query.from=part.global_transform;query.motion=remaining;query.margin=.0002;query.exclude_bodies=excluded
			var result:=PhysicsTestMotionResult3D.new()
			if PhysicsServer3D.body_test_motion(part.get_rid(),query,result) and result.get_travel().dot(remaining)<accepted.dot(remaining):
				accepted=result.get_travel();normal=result.get_collision_normal()
		if accepted.y<-.000001:
			var fraction:=1.
			for part: RigidBody3D in package:
				for point: Vector3 in _bottom_points(part):
					var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.0001,point+accepted,1,excluded)
					var hit:=get_world_3d().direct_space_state.intersect_ray(query)
					if not hit.is_empty() and hit.normal.y>.5:fraction=minf(fraction,clampf((hit.position-point).dot(accepted)/accepted.length_squared(),0.,1.))
			if fraction<1.:accepted*=fraction;normal=Vector3.UP
		for part: RigidBody3D in package:part.global_position+=accepted
		if normal==Vector3.ZERO:break
		remaining=(remaining-accepted).slide(normal)

func mechanism_snapshot() -> Dictionary:
	var result: Dictionary={}
	for key: String in tools:
		var body: RigidBody3D=tools[key];var q:=body.basis.get_rotation_quaternion()
		result[key]={"position":[body.position.x,body.position.y,body.position.z],"rotation":[q.x,q.y,q.z,q.w]}
	return result

func valid_mechanism(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=tools.size():return false
	for key: String in tools:
		var pose: Variant=value.get(key)
		if pose is not Dictionary or pose.size()!=2:return false
		for field: String in ["position","rotation"]:
			if pose.get(field) is not Array or pose[field].size()!=(3 if field=="position" else 4):return false
			for number: Variant in pose[field]:
				if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)):return false
		var q:=Quaternion(pose.rotation[0],pose.rotation[1],pose.rotation[2],pose.rotation[3])
		if absf(q.length_squared()-1.)>.0001:return false
		if Vector3(pose.position[0],pose.position[1],pose.position[2]).length()>1000.:return false
	return true

func restore_mechanism(value: Dictionary) -> void:
	held=null;payload.clear();_rests.clear();_fall_speed.clear()
	for key: String in tools:
		var body: RigidBody3D=tools[key];var pose: Dictionary=value[key]
		body.freeze=true;body.linear_velocity=Vector3.ZERO;body.angular_velocity=Vector3.ZERO
		body.position=Vector3(pose.position[0],pose.position[1],pose.position[2])
		body.basis=Basis(Quaternion(pose.rotation[0],pose.rotation[1],pose.rotation[2],pose.rotation[3]))
		body.sleeping=false
