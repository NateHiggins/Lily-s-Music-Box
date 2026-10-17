extends RigidBody3D
## The existing cap is a threaded physical part, never a vent-grade selector.
const TURN_END := TAU*2.0
const THREAD_TRAVEL := .014
const PIVOT := Vector3(.043,.054,0)
var radiator: Node3D
var turn := 0.0
var loose := false
var draw: MeshInstance3D
var insert_collision: CollisionShape3D
var _hulls: Array[ConvexPolygonShape3D] = []
static var _shared_hulls: Array[ConvexPolygonShape3D] = []
var _was_sleeping := true
var _float_held := false
var _float_lift := 0.0

func configure(owner: Node3D) -> void:
	radiator=owner
	mass=.025
	freeze=true
	continuous_cd=true
	contact_monitor=true
	max_contacts_reported=64
	collision_layer=0
	collision_mask=1
	physics_material_override=PhysicsMaterial.new()
	physics_material_override.friction=.8
	draw=radiator.native_rig.vent.get_node("VentCap")
	draw.reparent(self,false)
	draw.transform=Transform3D(Basis.IDENTITY,-PIVOT)*draw.get_meta("native_pose")
	# Curved sectors retain the actual needle/orifice bore. A single convex
	# cap hull would seal that opening and give misleading physical contact.
	_hulls=_cap_hulls()
	for shape in _hulls:
		var collision := CollisionShape3D.new()
		collision.shape=shape
		add_child(collision)
	# The retained insert projects four millimetres above the cap. Include
	# its native outer hull while this assembly remains one carried part.
	var insert: MeshInstance3D=radiator.native_rig.vent.get_node("VentOrificeInsert_%d"%radiator.vent_grade)
	insert_collision = CollisionShape3D.new()
	insert_collision.shape=insert.mesh.create_convex_shape()
	insert_collision.transform=Transform3D(Basis.IDENTITY,-PIVOT)*insert.get_meta("native_pose")
	add_child(insert_collision)
	preload("res://scripts/props/manipulation_area.gd").install(draw,grip)
	refresh()

static func _cap_hulls() -> Array[ConvexPolygonShape3D]:
	if not _shared_hulls.is_empty(): return _shared_hulls
	# Axial bands preserve the stepped bellmouth and flange as well as the
	# central bore. One hull per angular sector would bridge those recesses.
	for band in [[.054,.0602,.0135,.004],[.0602,.061,.0135,.0012],
		[.061,.066,.0135,.0032],[.066,.075,.019,.0032]]:
		for sector in 16:
			var points := PackedVector3Array()
			for step in range(sector*4,sector*4+5):
				var angle := TAU*float(step)/64.0
				for height: float in [band[0],band[1]]:
					for radius: float in [band[2],band[3]]:
						points.append(Vector3(radius*cos(angle),height-.054,radius*sin(angle)))
			var shape := ConvexPolygonShape3D.new()
			shape.points=points
			shape.margin=.00005
			_shared_hulls.append(shape)
	return _shared_hulls

func home() -> Transform3D:
	return radiator.native_rig.vent.global_transform*Transform3D(Basis.IDENTITY,PIVOT)

func manipulation_target(_hit: Dictionary) -> Dictionary:
	return grip()

func grip() -> Dictionary:
	if not loose and radiator.supply_position>.02: return {}
	var threaded := not loose
	return {"owner":radiator,"part":self,"frame":radiator.native_rig.vent if threaded else radiator,
		"kind":"hinge" if threaded else "free","axis":Vector3.UP,
		"minimum":0.0,"maximum":TURN_END,
		"read":func(): return turn if threaded else position,
		"begin":func():
			if not radiator._native_held.is_empty() or radiator._supply_held or RealityState.save_write_blocked: return false
			radiator._native_held="vent_cap"
			radiator.physical_action.emit("inspect_vent",{"condition":radiator.open_shift_condition,"observation":"vent_grade_%d"%radiator.vent_grade})
			freeze=true
			linear_velocity=Vector3.ZERO
			angular_velocity=Vector3.ZERO
			return true,
		"owns":func(): return radiator._native_held=="vent_cap",
		"write":func(value):
			if radiator._native_held!="vent_cap": return
			if threaded:
				turn=clampf(float(value),0.0,TURN_END)
				refresh()
			else: _carry(value),
		"end":func():
			if threaded and turn>=TURN_END-.0001:
				loose=true
				_drop()
			elif loose: _release()
			radiator._native_held=""
			radiator._update_balance()
			radiator.manipulation_changed.emit()}

func refresh() -> void:
	if draw==null or loose: return
	freeze=true
	collision_layer=0
	var pose := home()
	pose*=Transform3D(Basis(Vector3.UP,turn),Vector3.UP*THREAD_TRAVEL*turn/TURN_END)
	global_transform=pose
	# The installed insert belongs to this cap. It travels with the cap until
	# its own physical replacement is implemented; removal never changes grade.
	_sync_insert()

func _sync_insert() -> void:
	if radiator.native_orifices!=null:
		radiator.native_orifices.sync_radiator(radiator)
		return
	var vent: Node3D=radiator.native_rig.vent
	for index in 5:
		var insert: MeshInstance3D=vent.get_node("VentOrificeInsert_%d"%index)
		insert.global_transform=global_transform*Transform3D(Basis.IDENTITY,-PIVOT)*insert.get_meta("native_pose")

func tick() -> void:
	if loose: _sync_insert()
	if not _float_held:
		var state: Dictionary=radiator.get_heat_state()
		var target := .0055*clampf(float(state.get("heat",0.0))/.1,0.0,1.0) if not chamber_exposed() else 0.0
		_float_lift=move_toward(_float_lift,target,radiator.get_process_delta_time()*.002)
		_float_draw().position.y=_float_lift
	var settled := freeze or sleeping
	if settled and not _was_sleeping: radiator.manipulation_changed.emit()
	_was_sleeping=settled

func chamber_exposed() -> bool:
	return loose and global_position.distance_to(home().origin)>.04

func _float_draw() -> MeshInstance3D:
	return radiator.native_rig.vent.get_node("FloatAndNeedle")

func float_grip() -> Dictionary:
	if not chamber_exposed() or radiator.supply_position>.02: return {}
	return {"owner":radiator,"part":_float_draw(),"frame":radiator.native_rig.vent,
		"kind":"slide","axis":Vector3.UP,"minimum":0.0,"maximum":.0055,
		"read":func(): return _float_lift,
		"begin":func():
			if not radiator._native_held.is_empty() or radiator._supply_held or RealityState.save_write_blocked: return false
			radiator._native_held="vent_float"
			_float_held=true
			return true,
		"owns":func(): return radiator._native_held=="vent_float",
		"write":func(value: float):
			if not _float_held: return
			_float_lift=clampf(value,0.0,.0055)
			_float_draw().position.y=_float_lift,
		"end":func():
			_float_held=false
			radiator._native_held=""}

func leak() -> float:
	return 1.0 if loose else clampf(turn/TURN_END,0.0,1.0)

func _carry(value: Vector3) -> void:
	if not value.is_finite(): return
	var pose := global_transform
	var remaining: Vector3=radiator.global_basis*(value-position)
	for slide in 4:
		if remaining.length_squared()<1e-10: break
		var query := PhysicsTestMotionParameters3D.new()
		query.from=pose
		query.motion=remaining
		query.margin=.0002
		var result := PhysicsTestMotionResult3D.new()
		if not PhysicsServer3D.body_test_motion(get_rid(),query,result):
			pose.origin+=remaining
			break
		pose.origin+=result.get_travel()
		remaining=result.get_remainder().slide(result.get_collision_normal())
	global_transform=pose
	_sync_insert()

func _release() -> void:
	# Catch the mouth only after the hand brings the cap to its real axis.
	# It still requires two turns back down to seal; proximity is not repair.
	var receiving := home().translated_local(Vector3.UP*THREAD_TRAVEL)
	if radiator.supply_position<=.02 and global_position.distance_to(receiving.origin)<.006:
		loose=false
		turn=TURN_END
		refresh()
	else:
		_drop()

func _drop() -> void:
	collision_layer=1
	freeze=false
	sleeping=false

func snapshot() -> Dictionary:
	if not loose: return {"loose":false,"turn":turn}
	var q := basis.get_rotation_quaternion()
	return {"loose":true,"position":[position.x,position.y,position.z],"rotation":[q.x,q.y,q.z,q.w]}

static func valid(value: Variant) -> bool:
	if value is not Dictionary or typeof(value.get("loose"))!=TYPE_BOOL: return false
	if not value.loose:
		return value.size()==2 and typeof(value.get("turn")) in [TYPE_FLOAT,TYPE_INT] and is_finite(float(value.turn)) and value.turn>=0 and value.turn<=TURN_END
	if value.size()!=3: return false
	for key: String in ["position","rotation"]:
		if value.get(key) is not Array or value[key].size()!=(3 if key=="position" else 4): return false
		for number: Variant in value[key]:
			if typeof(number) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(number)): return false
	var pos := Vector3(value.position[0],value.position[1],value.position[2])
	var q := Quaternion(value.rotation[0],value.rotation[1],value.rotation[2],value.rotation[3])
	return pos.length()<10000 and absf(q.length_squared()-1.0)<.0001

func restore(value: Dictionary) -> void:
	_float_held=false
	loose=value.loose
	freeze=true
	linear_velocity=Vector3.ZERO
	angular_velocity=Vector3.ZERO
	if loose:
		position=Vector3(value.position[0],value.position[1],value.position[2])
		basis=Basis(Quaternion(value.rotation[0],value.rotation[1],value.rotation[2],value.rotation[3]).normalized())
		collision_layer=1
		freeze=false
		sleeping=false
		_sync_insert()
	else:
		turn=value.turn
		refresh()
