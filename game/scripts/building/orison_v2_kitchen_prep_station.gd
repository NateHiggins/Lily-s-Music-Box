extends Node3D
## Native food-preparation stock; household state owns persistent loose poses.
## A tool taken into the inventory is "stowed" (Lily 2026-11-24, order w4b7f08c909bb):
## the world copy is hidden with its collision off, its rest kept, and the carried case
## owns the item. Using it at this station puts it back at its authored rest.
signal manipulation_changed
var tools: Dictionary={}
var stowed: Dictionary={}
var rests: Dictionary={}
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

func _ready() -> void:
	# Stock at rest sleeps. Grabs and restores wake it at once; this slow pose
	# check (no rays) catches any mover that bypasses those entry points.
	var watch:=Timer.new();watch.name="RestWatch";watch.wait_time=.5;watch.autostart=true
	watch.process_callback=Timer.TIMER_PROCESS_PHYSICS;watch.timeout.connect(_watch_rests)
	add_child(watch,false,Node.INTERNAL_MODE_BACK)

func _rested(body: RigidBody3D) -> bool:
	if not _rests.has(body.name):return false
	var rest: Dictionary=_rests[body.name];var support: Node3D=rest.owner.get_ref()
	return is_instance_valid(support) and support.global_transform.is_equal_approx(rest.support_pose) and body.global_transform.is_equal_approx(rest.pose)

func _wake() -> void:
	set_physics_process(true)

func _watch_rests() -> void:
	if is_physics_processing():return
	for key: String in tools:
		if not stowed.has(key) and not _rested(tools[key]):_wake();return

func _physics_process(delta: float) -> void:
	var settled:=true
	for key: String in tools:
		var body: RigidBody3D=tools[key]
		if stowed.has(key):continue
		if _rested(body):continue
		_rests.erase(body.name);settled=false
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
	if settled:set_physics_process(false)

## Querying is free of side effects: the reticle calls this every frame. Only the
## click (begin) takes or returns, through the household state's case commit, and
## it never starts a carry: begin always answers false.
func manipulation_target(hit: Dictionary) -> Dictionary:
	var collider: Object=hit.get("collider")
	var state: Node=_household()
	if state==null:return {}
	var in_hand:=CarriedCase.kitchen_tool_parts(CarriedCase.hand())
	if not in_hand.is_empty() and in_hand[0]==str(name) and stowed.has(in_hand[1]) \
			and (collider==get_node_or_null("Worktable") or tools.values().has(collider)):
		var assembly: String=in_hand[1]
		return {"owner":self,"part":collider,"frame":self,"kind":"free","pickup":false,"put_back":assembly,
			"read":func():return Vector3.ZERO,"write":func(_value: Vector3):pass,
			"begin":func():state.return_kitchen_tool(self,assembly);return false,
			"owns":func():return false,"end":func():pass}
	var body:=collider as RigidBody3D
	if body==null or not tools.values().has(body) or stowed.has(str(body.name)):return {}
	var key:=str(body.name)
	return {"owner":self,"part":body,"frame":self,"kind":"free","pickup":false,"take":key,
		"read":func():return body.position,"write":func(_value: Vector3):pass,
		"begin":func():state.take_kitchen_tool(self,key);return false,
		"owns":func():return false,"end":func():pass}


func _household() -> Node:
	return get_tree().get_first_node_in_group("v2_household_state") if is_inside_tree() else null


## Something resting on this tool (a pin on its board) must be taken first.
func bearing_load(key: String) -> bool:
	var body: RigidBody3D=tools.get(key)
	if body==null:return false
	for other_key: String in tools:
		var other: RigidBody3D=tools[other_key]
		if other==body or stowed.has(other_key) or other.global_position.y<body.global_position.y+.015:continue
		var query:=PhysicsRayQueryParameters3D.create(other.global_position+Vector3.UP*.01,other.global_position-Vector3.UP*.08,1,[other.get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(query).get("collider")==body:return true
	return false


## The authored rest is free of the station's other loose stock.
func rest_clear(key: String) -> bool:
	var body: RigidBody3D=tools.get(key)
	if body==null or not rests.has(key):return false
	# Lifted 2 mm: a pin's authored rest lies on its board, and resting contact is not a block.
	var pose: Transform3D=(global_transform*rests[key]).translated(Vector3.UP*.002)
	var others: Array[RID]=[]
	for other_key: String in tools:
		if other_key!=key and not stowed.has(other_key):others.append(tools[other_key].get_rid())
	for child: Node in body.get_children():
		var shape:=child as CollisionShape3D
		if shape==null:continue
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=pose*shape.transform;query.margin=.0005
		for found: Dictionary in get_world_3d().direct_space_state.intersect_shape(query,8):
			if found.get("rid") in others:return false
	return true


## Applied only by the household state's verified publication or a restore.
func set_stowed(key: String, flag: bool) -> void:
	var body: RigidBody3D=tools.get(key)
	if body==null:return
	if flag:
		if not body.has_meta("kitchen_layers"):body.set_meta("kitchen_layers",[body.collision_layer,body.collision_mask])
		stowed[key]=true;body.visible=false;body.collision_layer=0;body.collision_mask=0
		_rests.erase(key);_fall_speed.erase(key)
	else:
		stowed.erase(key);body.visible=true
		if body.has_meta("kitchen_layers"):
			var layers: Array=body.get_meta("kitchen_layers");body.collision_layer=layers[0];body.collision_mask=layers[1]
		body.transform=rests[key];body.freeze=true;_fall_speed[key]=0.;_wake()


## A world copy drawn for the hand or the case: the tool's own meshes and materials.
func tool_visual(key: String) -> Node3D:
	var body: RigidBody3D=tools.get(key)
	if body==null:return null
	var copy:=Node3D.new();copy.name=key
	for child: Node in body.get_children():
		if child is MeshInstance3D:
			var draw:=child.duplicate() as MeshInstance3D;copy.add_child(draw)
	return copy


func mechanism_snapshot() -> Dictionary:
	var result: Dictionary={}
	for key: String in tools:
		if stowed.has(key):
			result[key]={"stowed":true};continue
		var body: RigidBody3D=tools[key];var q:=body.basis.get_rotation_quaternion()
		result[key]={"position":[body.position.x,body.position.y,body.position.z],"rotation":[q.x,q.y,q.z,q.w]}
	return result

## Each tool is either a resting pose or {"stowed": true}. A stowed tool is valid only
## with its case item; the household state checks that pair (valid_stowed_tools).
func valid_mechanism(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=tools.size():return false
	for key: String in tools:
		var pose: Variant=value.get(key)
		if pose is Dictionary and pose.size()==1 and pose.get("stowed")==true:continue
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
	_rests.clear();_fall_speed.clear()
	for key: String in tools:
		var body: RigidBody3D=tools[key];var pose: Dictionary=value[key]
		if pose.get("stowed")==true:
			set_stowed(key,true);continue
		if stowed.has(key):set_stowed(key,false)
		body.freeze=true;body.linear_velocity=Vector3.ZERO;body.angular_velocity=Vector3.ZERO
		body.position=Vector3(pose.position[0],pose.position[1],pose.position[2])
		body.basis=Basis(Quaternion(pose.rotation[0],pose.rotation[1],pose.rotation[2],pose.rotation[3]))
		body.sleeping=false
	_wake()