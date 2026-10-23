extends FireLineCabinetProp
## V2 physical-control migration. Retains the base maintenance authority and
## native source pivots. Unmigrated loose-stock work has no legacy click verb.
signal manipulation_changed

class HandBody extends AnimatableBody3D:
	var provider: Callable
	func manipulation_target(_hit: Dictionary) -> Dictionary:
		return provider.call() if provider.is_valid() else {}

var _hands_ready := false
var _hand := ""
var _door_angle := 0.0
var _lever_angle := -.95
var _tag_hinge: Node3D
var _tag_wire: MeshInstance3D
var _tag_angle := 0.0
var _tag_velocity := 0.0
var _tag_arm_length := .081
var _wheel_angle := 0.0
var _observed_open := false
var _observed_shut := false
var _bodies: Dictionary = {}
var _stock: Dictionary = {}
var _joint_stock: RefCounted
var _joint_nut: MeshInstance3D
var _union_angle := 0.0
var _observed_coupled := true
var _loose_union: RefCounted
var _gasket_body: RigidBody3D
var _nozzle_joint: Node3D
var rubber_dressed := false
var _undressed_rubber: Material
var _live_hose: Node3D
var _door_motion: RefCounted
var last_hand_obstruction: Dictionary={}

func try_dress_gasket(items: MaintenanceInventory, contact: Vector3) -> bool:
	if rubber_dressed or items==null or not items.has_item("fire_hose_rubber_protectant") \
			or not contact.is_finite() or not door_open or coupling_made_up or absf(_wheel_angle)>.0001:return false
	if _spare_gasket==null or _spare_gasket.mesh==null:return false
	var at:=_spare_gasket.to_local(contact)
	var bounds: AABB=_spare_gasket.mesh.get_aabb()
	var radius:=Vector2(at.x,at.z).length()
	var outer:=maxf(absf(bounds.position.x),absf(bounds.end.x))
	var inner:=float(_joint_stock.data.dimensions.bore_radius_m)
	if radius<inner-.003 or radius>outer+.003 or at.y<bounds.position.y-.003 or at.y>bounds.end.y+.003:return false
	rubber_dressed=true;_rubber_finish();manipulation_changed.emit();return true

func _rubber_finish() -> void:
	if _spare_gasket==null:return
	if _undressed_rubber==null:_undressed_rubber=_spare_gasket.material_override
	if not rubber_dressed:_spare_gasket.material_override=_undressed_rubber;return
	var finish:=_undressed_rubber.duplicate() as StandardMaterial3D
	if finish!=null:finish.roughness*=.85;_spare_gasket.material_override=finish

func install_nozzle_joint() -> bool:
	_nozzle_joint=preload("res://scripts/props/fire_nozzle_coupling.gd").new();_nozzle_joint.name="NativeNozzleCoupling";add_child(_nozzle_joint)
	return _nozzle_joint.configure(self)

func nozzle_hose_pose() -> int:return 0 if _nozzle_joint!=null else int(nozzle_coupled)

func install_joint_stock(nozzle_socket: Mesh) -> bool:
	_joint_stock=preload("res://scripts/props/fire_joint_stock_library.gd").new()
	if not _joint_stock.load_stock():return false
	for draw: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		var id: String=str(draw.get_meta("native_fire_part",""))
		if id=="F026":
			draw.mesh=_joint_stock.meshes.MaleOutlet;draw.material_override=_joint_stock.finishes.brass
			var body:=StaticBody3D.new();body.name="NativeOutletCollision";draw.add_child(body)
			var collider:=CollisionShape3D.new();collider.shape=draw.mesh.create_trimesh_shape();body.add_child(collider)
		elif id=="F027":
			_joint_nut=draw;draw.mesh=_joint_stock.meshes.FemaleUnion;draw.material_override=_joint_stock.finishes.brass;draw.transform=Transform3D.IDENTITY
		elif id=="F029":
			draw.mesh=_joint_stock.meshes.HoseNeck;draw.material_override=_joint_stock.finishes.linen;draw.transform=Transform3D.IDENTITY
		elif id in ["F028","F030","F031"]:draw.mesh=null
		elif id=="F060":draw.mesh=nozzle_socket;draw.set_meta("native_fire_successor","fire_nozzle_hose/NozzleSocket")
		elif id=="F062":
			draw.position=Vector3(.245,.033,.150)
			var body:=StaticBody3D.new();body.name="NativeGasketTinCollision";draw.add_child(body)
			# Retain the actual open pressed tray. A convex hull fills its basin
			# and leaves the washer floating above the visible bottom.
			var collider:=CollisionShape3D.new();var tin_shape:=ConcavePolygonShape3D.new()
			tin_shape.set_faces(preload("res://scripts/props/fire_hose_rack.gd").imported_faces(draw.mesh))
			collider.shape=tin_shape;body.add_child(collider)
		elif id=="F063":draw.position+=Vector3(.493,-.117,.054)
	if _joint_nut==null:return false
	for key: String in ["SwivelTail","HoseRetainer"]:
		_coupling.add_child(_joint_stock.make_part(key))
	_spare_gasket.mesh=_joint_stock.meshes.UnionGasket;_spare_gasket.material_override=_joint_stock.finishes.rubber
	_spare_gasket.position=Vector3(.245,.048,.150)
	_union_angle=_minimum("joint") if coupling_made_up else _maximum("joint")
	_observed_coupled=coupling_made_up;_apply_joint_pose()
	return true

func _apply_joint_pose() -> void:
	if _joint_stock==null:return
	var pose: Transform3D=_joint_stock.union_pose(_union_angle)
	var at: Vector3=_loose_union.location if _loose_union!=null and _loose_union.active else Vector3(.17,pose.origin.y,.098)
	_coupling.transform=Transform3D(Basis.IDENTITY,at)
	_joint_nut.basis=pose.basis
	# There is one gasket: the existing spare moves into the tail's real seat.
	# The superseded second gasket and dark pocket have no physical surfaces.
	_spare_gasket.visible=true
	if _gasket_body!=null:_gasket_body.sync()
	elif gasket_seated:_spare_gasket.position=_coupling.position+Vector3(0,.020,0)

func _build_reaches() -> void: pass
func _build_primary_interaction() -> void: pass
func manipulation_target(_hit: Dictionary) -> Dictionary: return {}
func interact_prompt() -> String: return ""
func interact(_player: Node) -> void: pass
func control_prompt(_control_id: String) -> String: return ""
func interact_control(_control_id: String, _player: Node) -> bool: return false

func install_native_hand_controls() -> bool:
	if _hands_ready: return false
	_door_motion=preload("res://scripts/props/fire_cabinet_door_motion.gd").new(self)
	_door_angle = 1.78 if door_open else 0.0
	_lever_angle = 0.0 if nozzle_shut else -.95
	_observed_open = door_open; _observed_shut = nozzle_shut
	# Refit the inherited floating wire at unchanged authored length. Its upper
	# end touches the spindle front; its lower end meets the paper's top edge.
	# Native meshes, chart scale and mesh parents remain unchanged.
	var paper: MeshInstance3D
	for draw: MeshInstance3D in _tag.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("native_fire_part",""))=="F032": _tag_wire=draw
		elif str(draw.get_meta("native_fire_part",""))=="F033": paper=draw
	if _tag_wire==null or paper==null: return false
	var wire_bounds: AABB = _tag_wire.mesh.get_aabb()
	var length: float = wire_bounds.size.y
	var faces: PackedVector3Array = _tag_wire.mesh.get_faces()
	if faces.is_empty(): return false
	var attachment: Vector3 = _valve_wheel.position+Vector3(0,-.024,.0135)
	var lower: Vector3
	var wire_basis: Basis
	var middle: Vector3
	var contact: Vector3
	# Use the actual rounded cap's support, not an imaginary square-ended
	# cylinder. Rigid fitting preserves the native wire length and UV metric.
	for iteration in 8:
		var depth: float = _tag.position.z-attachment.z
		# The retained stiff wire hangs to the left of the service joint.
		# A vertical wire put the100mm paper directly over the64mm swivel nut.
		var lateral: float=-.09
		if depth*depth+lateral*lateral>=length*length: return false
		lower = Vector3(attachment.x+lateral,attachment.y-sqrt(length*length-depth*depth-lateral*lateral),_tag.position.z)
		wire_basis = Basis(Quaternion(Vector3.UP,(attachment-lower).normalized()))
		middle = (attachment+lower)*.5
		contact = wire_basis*faces[0]+middle
		for vertex: Vector3 in faces:
			var point: Vector3 = wire_basis*vertex+middle
			if point.z<contact.z: contact=point
		var correction: float = _valve_wheel.position.z+.012-contact.z
		if absf(correction)<.0000001: break
		if iteration==7: return false
		attachment.z+=correction
	_tag.position = lower-Vector3(0,paper.mesh.get_aabb().size.y*.5,0)
	_tag_wire.transform = Transform3D(wire_basis,middle-_tag.position)
	_tag_hinge = Node3D.new(); _tag_hinge.name = "TagWireHinge"
	_tag_hinge.position = contact
	add_child(_tag_hinge); _tag.reparent(_tag_hinge,true)
	_tag_arm_length = maxf(.01,Vector2(_tag.position.y,_tag.position.z).length())
	for id: String in ["door", "lever", "tag", "valve", "joint"]:
		var part: Node3D = _part(id)
		# The old broad boxes can lie proud of the native bevel/pane and steal
		# a moving-part ray. Exact native hand collision supersedes them here.
		for old: StaticBody3D in part.find_children("*","StaticBody3D",true,false):
			if old.name=="NativeCaseCollision": old.collision_layer=0; old.collision_mask=0
		var body: HandBody = HandBody.new()
		body.name = "NativeHandCollision"; body.sync_to_physics = false
		body.collision_layer = 1; body.collision_mask = 0
		body.provider = _grip.bind(id); part.add_child(body)
		_bodies[id] = body; _stock[id] = []
		var draws: Array=part.find_children("*", "MeshInstance3D", true, false)
		if part is MeshInstance3D:draws.push_front(part)
		for draw: MeshInstance3D in draws:
			if draw.mesh == null: continue
			var local: Transform3D = part.global_transform.affine_inverse()*draw.global_transform
			var collision: CollisionShape3D = CollisionShape3D.new()
			collision.shape = draw.mesh.create_trimesh_shape(); collision.transform = local
			body.add_child(collision)
			var shape: ConvexPolygonShape3D = draw.mesh.create_convex_shape()
			shape.margin = .00001
			_stock[id].append({"shape":shape, "frame":local})
		if _stock[id].is_empty(): return false
	_gasket_body=preload("res://scripts/props/fire_line_gasket.gd").new();_gasket_body.name="PhysicalGasket";add_child(_gasket_body);_gasket_body.configure(self)
	_loose_union=preload("res://scripts/props/fire_loose_union.gd").new();_loose_union.configure(self)
	_hands_ready = true; _apply_hand_pose()
	return true

func _part(id: String) -> Node3D:
	match id:
		"door": return _door_pivot
		"tag": return _tag_hinge
		"valve": return _valve_wheel
		"joint": return _joint_nut
	return _lever

func _read(id: String) -> float:
	match id:
		"door": return _door_angle
		"tag": return _tag_angle
		"valve": return _wheel_angle
		"joint": return _union_angle
	return _lever_angle

func _axis(id: String) -> Vector3:
	if id in ["door","valve","joint"]: return Vector3.UP
	return Vector3.LEFT if id=="tag" else Vector3.BACK

func _minimum(id: String) -> float:
	if id=="door" and is_instance_valid(_live_hose) and _live_hose.deployed:return preload("res://scripts/props/hose_cabinet_route.gd").AJAR
	if id=="joint":return TAU*float(_joint_stock.data.dimensions.gasket_thickness_m)/float(_joint_stock.data.dimensions.pitch_m) if gasket_seated else 0.
	return -.95 if id=="lever" else 0.0

func _maximum(id: String) -> float:
	match id:
		"door": return 1.78
		"tag": return 1.0
		"valve": return TAU*2. if is_instance_valid(_live_hose) and _live_hose.deployed else .025
		"joint": return TAU*.008/float(_joint_stock.data.dimensions.pitch_m)
	return 0.0

func hose_supply_opening() -> float:
	# Retain the original 25 mrad spindle play as closed-seat travel. Tiny
	# accepted angles inside that play cannot create a permanent trickle.
	if not is_instance_valid(_live_hose) or not _live_hose.deployed:return 0.
	return clampf((_wheel_angle-.025)/(TAU*2.-.025),0.,1.)

func _claim(id: String) -> bool:
	if not _hands_ready or not _hand.is_empty(): return false
	if id=="joint" and not door_open:return false
	_hand = id; _balk_left = 0.0; _balk_focus = ""
	if id=="tag": _tag_velocity=0.0
	return true

func _release() -> void:
	if _hand=="joint":_loose_union.release()
	var was_door: bool=_hand=="door"
	_hand = ""; manipulation_changed.emit()
	if was_door:_door_motion.schedule()

func _grip(id: String) -> Dictionary:
	if id=="joint" and not door_open:return {}
	if id=="joint" and _loose_union!=null and _loose_union.active:return _loose_union.grip()
	var result: Dictionary={"owner":self, "part":_part(id), "frame":_part(id).get_parent_node_3d(),
		"kind":"hinge", "axis":_axis(id),
		"minimum":_minimum(id), "maximum":_maximum(id),
		"read":func():return _read(id), "write":func(value: float):
			if _hand==id: _move_hand_part(id,value),
		"begin":func():return _claim(id), "owns":func():return _hand==id,
		"end":_release}
	if id=="door":result.bind_holder=_door_motion.bind_holder
	return result

func _move_hand_part(id: String, value: float) -> void:
	if not is_finite(value): return
	value = clampf(value,_minimum(id),_maximum(id))
	var before: float = _read(id)
	var steps: int = maxi(1,ceili(absf(value-before)/.01))
	var accepted: float = before
	if id=="door":
		_door_motion.accommodate(value);accepted=value
	else:
		for step in range(1,steps+1):
			var proposed: float = value if step==steps else lerpf(before,value,float(step)/steps)
			if _obstructed(id,proposed): break
			accepted = proposed
	if id=="door":
		_door_angle = accepted; door_open = accepted>=.8; _observed_open = door_open
	elif id=="lever":
		_lever_angle = accepted; nozzle_shut = accepted>=-.0001; _observed_shut = nozzle_shut
	elif id=="tag": _tag_angle = accepted
	elif id=="valve": _wheel_angle = accepted
	elif id=="joint":
		_union_angle=accepted;coupling_made_up=absf(accepted-_minimum("joint"))<.0001;_observed_coupled=coupling_made_up
	_apply_hand_pose()
	if is_instance_valid(_live_hose):_live_hose.water_controls_changed()

func _obstructed(id: String, value: float) -> bool:
	last_hand_obstruction={}
	var part: Node3D = _part(id)
	var proposed: Transform3D = part.transform
	proposed.basis = Basis(_axis(id),value+PI if id=="lever" else value)
	var world: Transform3D = part.get_parent_node_3d().global_transform*proposed
	if id=="joint":
		var frame: Transform3D=_coupling.transform
		frame.origin.y=_joint_stock.union_pose(value).origin.y
		world=global_transform*frame*proposed
	var excluded: Array[RID] = [(_bodies[id] as HandBody).get_rid()]
	if id=="lever" and _nozzle_joint!=null and _nozzle_joint.body!=null:excluded.append(_nozzle_joint.body.get_rid())
	if id=="lever" and is_instance_valid(_live_hose):excluded.append_array(_live_hose.inspection_control_exclusions())
	if id=="joint" and _loose_union!=null:excluded.append_array(_loose_union._excluded)
	if id=="joint" and gasket_seated:excluded.append(_gasket_body.get_rid())
	# Fixed stock in this same fitted assembly supplies the hinge/valve stops.
	# Other moving parts, the player and surrounding architecture remain solid.
	for body: StaticBody3D in find_children("*","StaticBody3D",true,false):
		if id!="lever" and body is not AnimatableBody3D: excluded.append(body.get_rid())
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.collision_mask = 1; query.exclude = excluded; query.margin = .00001
	for stock: Dictionary in _stock[id]:
		query.shape = stock.shape; query.transform = world*stock.frame
		var hits: Array[Dictionary]=get_world_3d().direct_space_state.intersect_shape(query,1)
		if not hits.is_empty():
			var collider: Object=hits[0].get("collider")
			last_hand_obstruction={"control":id,"value":value,"collider":str(collider.get_path()) if collider is Node else str(collider)}
			return true
	return false

func _apply_hand_pose() -> void:
	if _door_pivot!=null: _door_pivot.rotation.y = _door_angle
	if _lever!=null: _lever.rotation.z = PI+_lever_angle
	if _tag_hinge!=null: _tag_hinge.rotation.x = -_tag_angle
	if _valve_wheel!=null: _valve_wheel.rotation.y = _wheel_angle
	_apply_joint_pose()
	_apply_nozzle_pose()

func _apply_nozzle_pose() -> void:
	if _nozzle_joint!=null:_nozzle_joint.sync();return
	if _play_pipe==null:return
	var original_angle: float=2.42 if nozzle_coupled else 1.5708
	var original_position:=Vector3(.045,.205,.120) if nozzle_coupled else Vector3(-.060,.068,.112)
	var old_basis:=Basis(Vector3.BACK,original_angle)
	var new_basis:=Basis(Vector3.BACK,original_angle+PI)
	var inlet: Vector3=original_position+old_basis*Vector3(0,-.012,0)
	_play_pipe.transform=Transform3D(new_basis,inlet-new_basis*Vector3(0,-.012,0))

func _physics_process(delta: float) -> void:
	if not _hands_ready: return
	_door_motion.tick(delta)
	_loose_union.tick(delta)
	# Neither transient wire swing nor locked-spindle play is a saved setting.
	if _hand!="tag" and (_tag_angle>0.0 or absf(_tag_velocity)>.00001):
		_tag_velocity += (-9.81/_tag_arm_length*sin(_tag_angle)-5.0*_tag_velocity)*delta
		var before: float = _tag_angle
		_move_hand_part("tag",_tag_angle+_tag_velocity*delta)
		if _tag_angle<=0.0 or is_equal_approx(before,_tag_angle): _tag_velocity=0.0
	if _hand!="valve" and _wheel_angle>0.0 and not (is_instance_valid(_live_hose) and _live_hose.deployed):
		_move_hand_part("valve",move_toward(_wheel_angle,0.0,delta*.2))

func _refresh_cabinet() -> void:
	if _hands_ready:
		if door_open!=_observed_open: _door_angle = 1.78 if door_open else 0.0
		if nozzle_shut!=_observed_shut: _lever_angle = 0.0 if nozzle_shut else -.95
		if coupling_made_up!=_observed_coupled:
			_union_angle=_minimum("joint") if coupling_made_up else _maximum("joint")
			if coupling_made_up:_loose_union.active=false
	super._refresh_cabinet()
	if _hands_ready:
		_apply_hand_pose(); _observed_open = door_open; _observed_shut = nozzle_shut;_observed_coupled=coupling_made_up

func inspection_view() -> Dictionary:
	if is_instance_valid(_live_hose) and _live_hose.deployed:
		return {"from":to_global(Vector3(-.10,.60,1.10)),"at":to_global(Vector3(.04,.35,.15)),"fov":60.0}
	return {"from":to_global(Vector3(-.10,.80,.85)),"at":to_global(Vector3(.04,.43,.10)),"fov":50.0}

func inspection_view_for(part: Node3D) -> Dictionary:
	if is_instance_valid(_live_hose) and _live_hose.deployed and (part==_play_pipe or _play_pipe.is_ancestor_of(part)):
		var camera:=get_viewport().get_camera_3d()
		return {"from":camera.global_position,"at":camera.global_position-camera.global_basis.z,"fov":50.}
	return inspection_view()

func flexible_outlet_hose_points() -> Dictionary:
	var fold: MeshInstance3D=_fold_leaves.back()
	var first: Vector3=get_node("NativeContinuousFolds").outlet_position() if has_node("NativeContinuousFolds") else to_local(fold.to_global(Vector3(.01,.131,0)))
	return {"first":first,
		"last":to_local(_coupling.to_global(Vector3(0,-.068 if _joint_stock!=null else -.075,0))),
		"upright":_coupling.basis.y.dot(Vector3.UP)>.99999}

func mechanism_snapshot() -> Dictionary:
	var at: Vector3=_loose_union.location if _loose_union.active else _loose_union.receiving()
	var value: Dictionary={"door":_door_angle,"lever":_lever_angle,"joint":_union_angle,"loose":{"active":_loose_union.active,"position":[at.x,at.y,at.z]},"gasket":_gasket_body.snapshot(),"facts":maintenance_snapshot()}
	if _nozzle_joint!=null:value.nozzle=_nozzle_joint.snapshot()
	value.rubber_dressed=rubber_dressed
	if is_instance_valid(_live_hose) and _live_hose.visual_follow_enabled:value.hose=_live_hose.deployment_snapshot()
	return value

func valid_mechanism(value: Variant) -> bool:
	if value is not Dictionary or value.size()<3 or value.size()>9:return false
	for key: String in value:
		if key not in ["door","lever","facts","joint","loose","gasket","nozzle","rubber_dressed","hose"]:return false
	if value.has("hose") and (not value.has("nozzle") or not is_instance_valid(_live_hose) or not _live_hose.valid_deployment(value.hose)):return false
	if value.has("loose") and not value.has("joint"):return false
	if value.has("gasket") and not value.has("loose"):return false
	if value.has("nozzle") and (not value.has("gasket") or _nozzle_joint==null):return false
	if value.has("rubber_dressed") and value.rubber_dressed is not bool:return false
	if value.has("gasket") and not preload("res://scripts/props/fire_line_gasket.gd").valid(value.gasket):return false
	if value.has("joint"):
		if typeof(value.joint) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value.joint)) or float(value.joint)<0. or float(value.joint)>_maximum("joint"):return false
	for id: String in ["door","lever"]:
		if typeof(value.get(id)) not in [TYPE_INT,TYPE_FLOAT]: return false
		var angle: float = float(value[id])
		if not is_finite(angle) or angle<(0.0 if id=="door" else -.95) or angle>(1.78 if id=="door" else 0.0): return false
	if value.get("facts") is not Dictionary: return false
	var facts: Dictionary = value.facts
	var template: Dictionary = maintenance_snapshot()
	if facts.size()!=template.size(): return false
	for key: String in template:
		if key=="tag_line":
			if facts.get(key) is not String or str(facts[key]).length()>64: return false
		elif typeof(facts.get(key))!=TYPE_BOOL: return false
	var receiver: Variant=null
	if value.has("hose"):
		if value.hose.deployed and facts.hose_racked:return false
		receiver=_live_hose.saved_receiver(value.hose)
	elif is_instance_valid(_live_hose) and _live_hose.visual_follow_enabled:
		# Legacy rack saves must not depend on the current deployed receiver.
		receiver=_live_hose._receiver
	if value.has("nozzle") and (_nozzle_joint==null or not _nozzle_joint.valid(value.nozzle,facts.nozzle_coupled,receiver)):return false
	if value.has("joint"):
		var stop: float=TAU*float(_joint_stock.data.dimensions.gasket_thickness_m)/float(_joint_stock.data.dimensions.pitch_m) if facts.gasket_seated else 0.
		if float(value.joint)<stop or facts.coupling_made_up!=(absf(float(value.joint)-stop)<.0001):return false
	if value.has("loose"):
		var loose: Variant=value.loose
		if loose is not Dictionary or loose.size()!=2 or typeof(loose.get("active"))!=TYPE_BOOL or loose.get("position") is not Array or loose.position.size()!=3:return false
		for coordinate: Variant in loose.position:
			if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)):return false
		var saved_at:=Vector3(loose.position[0],loose.position[1],loose.position[2])
		if not loose.active and saved_at.distance_to(_loose_union.receiving())>.000001:return false
		if loose.active:
			if absf(float(value.joint)-_maximum("joint"))>.000001 or facts.coupling_made_up:return false
			var first: Vector3=flexible_outlet_hose_points().first
			# The retained source's last fold is index9, with its half-pitch
			# shift and16mm fresh-crease drop. Validate the saved fold state.
			first+=Vector3(.01475,-.016,0)*(int(facts.folds_fresh)-int(folds_fresh))
			var at:=Vector3(loose.position[0],loose.position[1],loose.position[2])
			if not get_node("NativeHoseRuns")._live_lead.can_reach(first,at+Vector3(0,-.068,0)):return false
	if value.has("gasket") and facts.gasket_seated:
		var union_at:=Vector3(.17,_joint_stock.union_pose(float(value.get("joint",_minimum("joint")))).origin.y,.098)
		if value.get("loose",{}).get("active",false):union_at=Vector3(value.loose.position[0],value.loose.position[1],value.loose.position[2])
		var ring_at:=Vector3(value.gasket.position[0],value.gasket.position[1],value.gasket.position[2])
		var q: Array=value.gasket.rotation
		if ring_at.distance_to(union_at+Vector3(0,.020,0))>.0001 or (Basis(Quaternion(q[0],q[1],q[2],q[3])).y.dot(Vector3.UP))<.9999:return false
	return facts.door_open==(float(value.door)>=.8) and facts.nozzle_shut==(float(value.lever)>=-.0001)

func restore_mechanism(value: Dictionary) -> void:
	if not _hand.is_empty() or not valid_mechanism(value): return
	restore_maintenance_snapshot(value.facts)
	_door_angle = float(value.door); _lever_angle = float(value.lever)
	_union_angle=float(value.get("joint",_minimum("joint") if coupling_made_up else _maximum("joint")))
	_loose_union.active=bool(value.get("loose",{}).get("active",false))
	if _loose_union.active:
		var at: Array=value.loose.position
		_loose_union.location=Vector3(at[0],at[1],at[2]);_loose_union._velocity=0.
	_observed_coupled=coupling_made_up
	_observed_open = door_open; _observed_shut = nozzle_shut; _apply_hand_pose()
	if value.has("gasket"):_gasket_body.restore(value.gasket)
	else:_gasket_body.restore({"position":[.245,.048,.150],"rotation":[0.,0.,0.,1.]})
	if is_instance_valid(_live_hose) and _live_hose.visual_follow_enabled:
		if value.has("hose"):_live_hose.restore_deployment(value.hose)
		else:_live_hose.restore_stored()
		_apply_hand_pose()
	if value.has("nozzle"):_nozzle_joint.restore(value.nozzle)
	elif _nozzle_joint!=null:_nozzle_joint.restore_legacy(value.facts.nozzle_coupled)
	rubber_dressed=bool(value.get("rubber_dressed",false));_rubber_finish()
	_door_motion.schedule()

func _exit_tree() -> void:
	if _door_motion!=null:_door_motion.release()
