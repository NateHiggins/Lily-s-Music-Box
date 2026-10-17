extends Node3D
## Finite physical inserts: one per installed radiator and five shop spares.
## This owner saves identities/locations; radiators retain heat/case authority.
signal manipulation_changed
const PIVOT := Vector3(.043,.075,0)
const THREAD_END := TAU*1.5
const THREAD_TRAVEL := .009
var rows := {}
var radiators := {}
var stock_grades := {}
var held := ""
var _held_radiator: Node3D
var _restoring := false
var _syncing := false

func install_rack(asset: String) -> void:
	var model := (load(asset) as PackedScene).instantiate() as Node3D
	model.name="NativeWorkshopRack"
	add_child(model)
	var fixed := StaticBody3D.new()
	fixed.name="ActualRackCollision"
	add_child(fixed)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for index in draw.mesh.get_surface_count():
			var imported: Material=draw.get_active_material(index)
			# The shared native-stock exporter deliberately omits material
			# payloads. Its named partitions retain the catalogue identity.
			var key := str(draw.name).trim_prefix("Rack_")
			if imported!=null and imported.resource_name.begins_with("CATALOG_"): key=imported.resource_name.trim_prefix("CATALOG_")
			assert(MatLib.SETS.has(key))
			var mat := MatLib.get_mat(key,Color(.5,.43,.34) if key=="timber" else Color(.65,.65,.65)).duplicate() as StandardMaterial3D
			mat.uv1_triplanar=false;mat.uv2_triplanar=false
			mat.set_meta("v2_surface_stock",key)
			draw.set_surface_override_material(index,mat)
		var shape := CollisionShape3D.new()
		shape.shape=draw.mesh.create_trimesh_shape()
		fixed.add_child(shape)
		shape.global_transform=draw.global_transform
	var label := Label3D.new()
	label.text="AIR VALVE PARTS"
	label.font_size=32;label.pixel_size=.0006;label.outline_size=0
	label.modulate=Color(.12,.10,.07)
	label.position=Vector3(0,.065,-.0675)
	add_child(label)

func configure(installed: Array, source: Dictionary) -> void:
	for radiator: Node3D in installed:
		var identity: String=radiator.graph_node_id
		assert(not identity.is_empty() and not radiators.has(identity))
		radiators[identity]=radiator
		radiator.native_orifices=self
		radiator.native_rig.orifices_external=true
		_add_part(identity+"_ORIFICE",radiator.vent_grade,identity,-1)
		for grade in 5: radiator.native_rig.vent.get_node("VentOrificeInsert_%d"%grade).free()
	for record: Dictionary in source.spares:
		stock_grades[str(record.id)]=int(record.grade)
		_add_part(str(record.id),int(record.grade),"",int(record.pocket))
	_sync_all()

func _add_part(identity: String,grade: int,slot: String,rack: int) -> void:
	assert(not rows.has(identity))
	var body := preload("res://scripts/props/radiator_vent_insert.gd").new()
	body.name=identity
	body.bank=self
	body.identity=identity
	body.mass=.003
	body.freeze=true
	body.continuous_cd=true
	body.collision_layer=0
	body.collision_mask=1
	add_child(body)
	var draw := RadiatorNativeParts.part("vent","VentOrificeInsert_%d"%grade,body,
		Transform3D(Basis.IDENTITY,-PIVOT))
	var collision := CollisionShape3D.new()
	var stem := CylinderShape3D.new()
	stem.radius=.003;stem.height=.009
	collision.shape=stem
	collision.position.y=-.0035
	body.add_child(collision)
	var head := CollisionShape3D.new()
	var points := PackedVector3Array()
	for index in 6:
		for height in [0.0,.004]: points.append(Vector3(.005*cos(TAU*index/6+PI/6),height,.005*sin(TAU*index/6+PI/6)))
	var hex := ConvexPolygonShape3D.new()
	hex.points=points;hex.margin=.00005
	head.shape=hex
	body.add_child(head)
	preload("res://scripts/props/manipulation_area.gd").install(draw,grip.bind(identity))
	var stamp := Label3D.new()
	stamp.text=str(grade)
	stamp.font_size=32
	stamp.pixel_size=.00013
	stamp.outline_size=0
	stamp.modulate=Color(.14,.11,.06)
	stamp.rotation.x=-PI/2
	stamp.position=Vector3(0,.0042,0)
	body.add_child(stamp)
	rows[identity]={"body":body,"draw":draw,"head":head,"stamp":stamp,"grade":grade,"slot":slot,"rack":rack,"turn":0.0,"sleeping":true}

func active(radiator: Node3D) -> Dictionary:
	for row: Dictionary in rows.values():
		if row.slot==radiator.graph_node_id: return row
	return {}

func rack_pose(index: int) -> Transform3D:
	return Transform3D(Basis.IDENTITY,Vector3((index-2)*.06,0,0))

func _thread_pose(radiator: Node3D,turn: float) -> Transform3D:
	var cap: Node3D=radiator.native_vent_cap
	return cap.global_transform*Transform3D(Basis.IDENTITY,PIVOT-cap.PIVOT)*Transform3D(Basis(Vector3.UP,turn),Vector3.UP*THREAD_TRAVEL*turn/THREAD_END)

func sync_radiator(radiator: Node3D) -> void:
	var row := active(radiator)
	var cap: Node3D=radiator.native_vent_cap
	cap.insert_collision.disabled=row.is_empty()
	if row.is_empty(): return
	var body_pose := _thread_pose(radiator,row.turn)
	if not row.body.global_transform.is_equal_approx(body_pose): row.body.global_transform=body_pose
	cap.insert_collision.shape=row.head.shape
	var head_pose: Transform3D=Transform3D(Basis.IDENTITY,PIVOT-cap.PIVOT)*Transform3D(Basis(Vector3.UP,row.turn),Vector3.UP*THREAD_TRAVEL*row.turn/THREAD_END)*row.head.transform
	if not cap.insert_collision.transform.is_equal_approx(head_pose): cap.insert_collision.transform=head_pose

func _sync_all() -> void:
	if _syncing: return
	_syncing=true
	var changed_grades: Array[Node3D]=[]
	for row: Dictionary in rows.values():
		if not row.slot.is_empty():
			row.body.freeze=true
			row.body.collision_layer=0
		elif row.rack>=0:
			row.body.freeze=true
			row.body.collision_layer=0
			row.body.transform=rack_pose(row.rack)
	for radiator: Node3D in radiators.values():
		sync_radiator(radiator)
		var row := active(radiator)
		if not row.is_empty() and radiator.vent_grade!=int(row.grade):
			radiator.vent_grade=int(row.grade)
			changed_grades.append(radiator)
	_syncing=false
	for radiator: Node3D in changed_grades: radiator.vent_changed.emit(radiator.vent_grade)

func leak(radiator: Node3D) -> float:
	var row := active(radiator)
	return 1.0 if row.is_empty() else clampf(float(row.turn)/THREAD_END,0.0,1.0)

func _changed() -> void:
	_sync_all()
	for radiator: Node3D in radiators.values(): radiator._update_balance()
	manipulation_changed.emit()

func inspection_owner_for(part: Node3D) -> Node3D:
	var nearest: Node3D=self
	var distance := .3
	for radiator: Node3D in radiators.values():
		var gap := part.global_position.distance_to(_thread_pose(radiator,0).origin)
		if gap<distance: nearest=radiator;distance=gap
	return nearest

func owns_part(part: Node3D) -> bool:
	return rows.values().any(func(row): return row.body==part)

func interaction_owner_for(part: Node3D) -> Node3D:
	# A held part keeps its assembly context until release. Crossing the
	# proximity boundary while carrying it must not change grab ownership.
	if not held.is_empty() and rows[held].body==part:
		return _held_radiator if _held_radiator!=null else self
	return inspection_owner_for(part)

func inspection_view() -> Dictionary:
	return {"from":to_global(Vector3(.02,.14,.18)),"at":global_position,"fov":48.0}

func inspection_view_for(part: Node3D) -> Dictionary:
	var owner := inspection_owner_for(part)
	if owner!=self: return owner.inspection_view_for(owner.native_vent_cap)
	return {"from":part.global_position+global_basis*Vector3(.015,.06,.07),"at":part.global_position,"fov":48.0}

func grip(identity: String) -> Dictionary:
	var row: Dictionary=rows[identity]
	var mounted: bool=not row.slot.is_empty()
	var radiator: Node3D=radiators.get(row.slot)
	if mounted and radiator.supply_position>.02: return {}
	return {"owner":self,"part":row.body,"frame":radiator.native_vent_cap if mounted else self,
		"kind":"hinge" if mounted else "free","axis":Vector3.UP,"minimum":0.0,"maximum":THREAD_END,
		"read":func(): return row.turn if mounted else row.body.position,
		"begin":func():
			if not held.is_empty() or RealityState.save_write_blocked: return false
			var context := inspection_owner_for(row.body)
			if context!=self and (not context._native_held.is_empty() or context._supply_held): return false
			_held_radiator=context if context!=self else null
			if _held_radiator!=null: _held_radiator._native_held="vent_orifice"
			held=identity
			if mounted: radiator.physical_action.emit("inspect_vent",{"condition":radiator.open_shift_condition,"observation":"vent_grade_%d"%row.grade})
			row.body.freeze=true
			row.body.linear_velocity=Vector3.ZERO
			row.body.angular_velocity=Vector3.ZERO
			if not mounted: row.rack=-1
			return true,
		"owns":func(): return held==identity,
		"write":func(value):
			if held!=identity: return
			if mounted:
				row.turn=clampf(float(value),0.0,THREAD_END)
				sync_radiator(radiator)
			else: _carry(row,value),
		"end":func():
			if mounted and row.turn>=THREAD_END-.0001:
				row.slot=""
				_drop(row)
			elif not mounted: _release(row)
			if _held_radiator!=null and _held_radiator._native_held=="vent_orifice": _held_radiator._native_held=""
			_held_radiator=null
			held=""
			_changed()}

func _carry(row: Dictionary,value: Vector3) -> void:
	if not value.is_finite(): return
	var pose: Transform3D=row.body.global_transform
	var remaining: Vector3=global_basis*(value-row.body.position)
	for slide in 4:
		if remaining.length_squared()<1e-10: break
		var query := PhysicsTestMotionParameters3D.new()
		query.from=pose;query.motion=remaining;query.margin=.0002
		var result := PhysicsTestMotionResult3D.new()
		if not PhysicsServer3D.body_test_motion(row.body.get_rid(),query,result): pose.origin+=remaining;break
		pose.origin+=result.get_travel()
		remaining=result.get_remainder().slide(result.get_collision_normal())
	row.body.global_transform=pose

func _release(row: Dictionary) -> void:
	for radiator: Node3D in radiators.values():
		if radiator.supply_position>.02 or not active(radiator).is_empty(): continue
		if row.body.global_position.distance_to(_thread_pose(radiator,THREAD_END).origin)<.006:
			row.slot=radiator.graph_node_id;row.turn=THREAD_END
			return
	for index in 5:
		if rows.values().any(func(other): return other!=row and other.rack==index): continue
		if row.body.position.distance_to(rack_pose(index).origin)<.008: row.rack=index;return
	_drop(row)

func _drop(row: Dictionary) -> void:
	row.rack=-1
	row.body.collision_layer=1
	row.body.freeze=false
	row.body.sleeping=false

func _process(_delta: float) -> void:
	_sync_all()
	for row: Dictionary in rows.values():
		var sleeping: bool=row.body.freeze or row.body.sleeping
		if sleeping and not row.sleeping: manipulation_changed.emit()
		row.sleeping=sleeping

func mechanism_snapshot() -> Dictionary:
	var parts: Array=[]
	for identity: String in rows:
		var row: Dictionary=rows[identity]
		var value := {"id":identity,"grade":int(row.grade)}
		if not row.slot.is_empty(): value.slot=row.slot;value.turn=row.turn
		elif row.rack>=0: value.rack=int(row.rack)
		else:
			var at: Vector3=row.body.position
			var q: Quaternion=row.body.basis.get_rotation_quaternion()
			value.position=[at.x,at.y,at.z];value.rotation=[q.x,q.y,q.z,q.w]
		parts.append(value)
	return {"version":1,"parts":parts}

func valid_mechanism(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=2: return false
	if typeof(value.get("version")) not in [TYPE_INT,TYPE_FLOAT]: return false
	if value.version!=1 or value.get("parts") is not Array or value.parts.size()!=rows.size(): return false
	var ids := {};var slots := {};var pockets := {}
	for part: Variant in value.parts:
		if part is not Dictionary or part.get("id") not in rows or ids.has(part.id): return false
		ids[part.id]=true
		if typeof(part.get("grade")) not in [TYPE_INT,TYPE_FLOAT] or part.grade!=floor(part.grade) or part.grade<0 or part.grade>4: return false
		if stock_grades.has(part.id) and part.grade!=stock_grades[part.id]: return false
		if part.has("slot"):
			if part.size()!=4 or part.slot not in radiators or slots.has(part.slot): return false
			if typeof(part.get("turn")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(part.turn)) or part.turn<0 or part.turn>THREAD_END: return false
			slots[part.slot]=true
		elif part.has("rack"):
			if part.size()!=3 or typeof(part.rack) not in [TYPE_INT,TYPE_FLOAT] or part.rack!=floor(part.rack) or part.rack<0 or part.rack>4 or pockets.has(part.rack): return false
			pockets[part.rack]=true
		else:
			if part.size()!=4: return false
			for key: String in ["position","rotation"]:
				if part.get(key) is not Array or part[key].size()!=(3 if key=="position" else 4): return false
				for number: Variant in part[key]:
					if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)): return false
			if Vector3(part.position[0],part.position[1],part.position[2]).length()>10000: return false
			if absf(Quaternion(part.rotation[0],part.rotation[1],part.rotation[2],part.rotation[3]).length_squared()-1.0)>.0001: return false
	return true

func restore_mechanism(value: Dictionary) -> void:
	if not valid_mechanism(value): return
	_restoring=true
	if _held_radiator!=null and _held_radiator._native_held=="vent_orifice": _held_radiator._native_held=""
	held="";_held_radiator=null
	for part: Dictionary in value.parts:
		var row: Dictionary=rows[part.id]
		row.grade=int(part.grade)
		row.stamp.text=str(row.grade)
		if row.draw.get_meta("native_stock")!="VentOrificeInsert_%d"%row.grade:
			var replacement := RadiatorNativeParts.part("vent","VentOrificeInsert_%d"%row.grade,row.body,Transform3D(Basis.IDENTITY,-PIVOT))
			row.draw.mesh=replacement.mesh
			for index in replacement.mesh.get_surface_count(): row.draw.set_surface_override_material(index,replacement.get_active_material(index))
			replacement.free()
			row.draw.set_meta("native_stock","VentOrificeInsert_%d"%row.grade)
		row.slot=part.get("slot","");row.rack=int(part.get("rack",-1));row.turn=float(part.get("turn",0))
		row.body.freeze=true
		row.body.linear_velocity=Vector3.ZERO;row.body.angular_velocity=Vector3.ZERO
		if row.slot.is_empty() and row.rack<0:
			row.body.position=Vector3(part.position[0],part.position[1],part.position[2])
			row.body.basis=Basis(Quaternion(part.rotation[0],part.rotation[1],part.rotation[2],part.rotation[3]).normalized())
			_drop(row)
	_changed()
	_restoring=false

func migrate_legacy_snapshot(value: Dictionary,records: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	for part: Dictionary in result.parts:
		if not part.has("slot"): continue
		var saved: Variant=records.get(part.slot,{}).get("value")
		if saved is Dictionary and saved.has("vent_grade"): part.grade=int(saved.vent_grade)
	return result

func validate_related_records(records: Dictionary) -> bool:
	if not records.has(str(name)): return true # pre-stock save migrates once
	var value: Variant=records[str(name)].get("value")
	if not valid_mechanism(value): return false
	for part: Dictionary in value.parts:
		if not part.has("slot") or not records.has(part.slot): continue
		var radiator_value: Variant=records[part.slot].get("value")
		if radiator_value is Dictionary and radiator_value.get("vent_grade")!=part.grade: return false
	return true
