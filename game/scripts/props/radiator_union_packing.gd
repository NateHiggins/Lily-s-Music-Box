extends RigidBody3D
## One physical liner. Inventory retains historical acquire/use facts; this
## mechanism retains its installed/loose pose, just as physical fuse plugs do.
const PEEL := .024
const LIFT := .120
const SECTORS := 16
static var _closed: Array[Shape3D] = []
static var _opened: Array[Shape3D] = []
var radiator: Node3D
var draw: MeshInstance3D
var station := 0 # 0: constrained to seat; 1: loose, including while carried
var _area: Area3D
var _targets: Array[CollisionShape3D] = []
var _last_sleeping := true
var _target_spread := -1.0
var last_block := {}
var support_correction := Vector3.ZERO

func configure(owner: Node3D) -> void:
	radiator=owner
	mass=.012
	freeze=true
	continuous_cd=true
	can_sleep=true
	contact_monitor=true
	max_contacts_reported=128
	physics_material_override=PhysicsMaterial.new()
	physics_material_override.friction=1.0
	physics_material_override.rough=true
	physics_material_override.bounce=0.0
	collision_layer=0
	collision_mask=1
	draw=radiator.native_rig.packing
	draw.reparent(self,false)
	draw.transform=draw.get_meta("native_pose")
	radiator.native_rig.packing_external=true
	_area=preload("res://scripts/props/manipulation_area.gd").new()
	_area.name="PackingSurface"
	_area.provider=grip
	_area.collision_layer=1
	_area.collision_mask=0
	_area.monitoring=false
	_area.add_to_group("functional_interaction_areas")
	add_child(_area)
	for shape: Shape3D in _shapes(1.0):
		var collider := CollisionShape3D.new()
		collider.shape=shape
		add_child(collider)
		var target_shape := CollisionShape3D.new()
		target_shape.shape=BoxShape3D.new()
		_area.add_child(target_shape)
		_targets.append(target_shape)
	refresh()

static func _shapes(spread: float) -> Array[Shape3D]:
	if spread==0.0 and not _closed.is_empty(): return _closed
	if spread==1.0 and not _opened.is_empty(): return _opened
	var result: Array[Shape3D] = []
	# The same 96 angular samples and 13-point spherical profiles as the native
	# liner. Convex sectors preserve the central opening; a solid hull would
	# falsely fill it and collide with the ball it must wrap around.
	for sector in SECTORS:
		var hull := ConvexPolygonShape3D.new()
		hull.margin=.00005
		hull.points=_points(spread,sector)
		result.append(hull)
	if spread==0.0: _closed=result
	if spread==1.0: _opened=result
	return result

static func _points(spread: float,sector: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	for step in range(sector*6,sector*6+7):
		var t := float(step)/96.0
		var angle := PI+.001+t*(TAU-.002)
		var open_angle := deg_to_rad(255.0+t*210.0)
		var ratio := (TAU-.002)/deg_to_rad(210.0)
		for axial in 13:
			var x := .0002+(.025-.0002)*float(axial)/12.0
			for radius in [.0328,.032]:
				var r := sqrt(float(radius)*float(radius)-x*x)
				var rest := Vector3(x,r*sin(angle),-r*cos(angle))
				var opened := Vector3(x,r*ratio*sin(open_angle),-r*ratio*cos(open_angle))
				points.append(rest.lerp(opened,spread))
	return points

func _update_targets(spread: float) -> void:
	if spread==_target_spread: return
	for sector in SECTORS:
		var points := _points(spread,sector)
		var tangent := (points[points.size()-1]-points[25]).normalized()
		var axes := Basis(Vector3.RIGHT,tangent,Vector3.RIGHT.cross(tangent)).orthonormalized()
		var bounds := AABB(axes.inverse()*points[0],Vector3.ZERO)
		for point in points: bounds=bounds.expand(axes.inverse()*point)
		# Small-part cursor bounds follow each curved sector, retaining the
		# open centre. They do not replace the liner's physical convex skin.
		_targets[sector].shape.size=bounds.size+Vector3.ONE*.002
		_targets[sector].transform=Transform3D(axes,axes*bounds.get_center())
	_target_spread=spread

func home() -> Transform3D:
	var rig: Node3D=radiator.native_rig
	return rig.transform*Transform3D(rig.body.basis,rig.header_joint)

func manipulation_target(_hit: Dictionary) -> Dictionary:
	return grip()

func grip() -> Dictionary:
	if station==0 and (radiator.supply_position>.02 or radiator.native_service_progress<.999): return {}
	var constrained := station==0
	return {"owner":radiator,"part":self,"frame":radiator,"kind":"slide" if constrained else "free",
		"axis":Vector3.FORWARD,"minimum":0.0,"maximum":PEEL+LIFT,
		"read":func(): return radiator.native_packing_spread*PEEL+radiator.native_packing_out*LIFT if constrained else position,
		"begin":func():
			if not radiator._native_held.is_empty() or radiator._supply_held or RealityState.save_write_blocked: return false
			radiator._native_held="packing"
			freeze=true
			linear_velocity=Vector3.ZERO
			angular_velocity=Vector3.ZERO
			if not constrained and radiator.inventory!=null and radiator.inventory.item_state(radiator.PACKING_ITEM).is_empty(): _acquired()
			return true,
		"owns":func(): return radiator._native_held=="packing",
		"write":func(value):
			if radiator._native_held!="packing": return
			if constrained: _peel(float(value))
			else: _carry(value),
		"end":func():
			if station==1: _release()
			radiator._native_held=""
			radiator._apply_visual_state()
			radiator.manipulation_changed.emit()}

func _peel(value: float) -> void:
	var was_loose := station==1
	var travel := clampf(value,0.0,PEEL+LIFT)
	radiator.native_packing_spread=clampf(travel/PEEL,0.0,1.0)
	radiator.native_packing_out=clampf((travel-PEEL)/LIFT,0.0,1.0)
	# Once the unbent liner actually leaves its seat, saving or releasing it
	# must produce a loose body, even halfway through the hand's lift travel.
	station=1 if radiator.native_packing_out>0.0 else 0
	transform=home()
	position+=Vector3.FORWARD*LIFT*radiator.native_packing_out
	refresh()
	if station==1 and not was_loose: _acquired()
	radiator._update_balance()

func _acquired() -> void:
	if radiator.inventory!=null:
		# grant() itself refuses both a duplicate and a previously consumed id.
		radiator.inventory.grant(radiator.PACKING_ITEM,"radiator_2b_union")
	radiator.physical_action.emit("inspect_union",{"condition":radiator.open_shift_condition,"observation":"packing_removed_from_union"})

func _carry(value: Vector3) -> void:
	if not value.is_finite(): return
	var pose := global_transform
	var remaining: Vector3=radiator.global_basis*(value-position)
	last_block={}
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
		last_block={"collider":str(result.get_collider().get_path()),"normal":str(result.get_collision_normal())}
	global_transform=pose

func _release() -> void:
	# Flexible cloth conforms to the ball only when hand-delivered to its
	# receiving seat. Closing the empty joint is still physically possible.
	if radiator.supply_position<=.02 and radiator.native_service_progress>=.999 and position.distance_to(home().origin)<.008:
		station=0
		radiator.native_packing_spread=1.0
		radiator.native_packing_out=0.0
		refresh()
		radiator._update_balance()
		return
	collision_layer=1
	freeze=false
	sleeping=false
	radiator._update_balance()

func refresh() -> void:
	if draw==null: return
	if station==0:
		freeze=true
		collision_layer=0
		transform=home()
		position+=Vector3.FORWARD*LIFT*radiator.native_packing_out
	var spread: float=radiator.native_packing_spread
	RadiatorNativeParts.spread_packing(draw,spread)
	_update_targets(spread)

func tick() -> void:
	var settled := freeze or sleeping
	if settled and not _last_sleeping: radiator.manipulation_changed.emit()
	_last_sleeping=settled

func snapshot() -> Dictionary:
	if station==0: return {"station":0}
	var rotation := basis.get_rotation_quaternion()
	return {"station":1,"position":[position.x,position.y,position.z],"rotation":[rotation.x,rotation.y,rotation.z,rotation.w]}

static func valid(value: Variant,spread: float,out: float,service: float) -> bool:
	if value is not Dictionary or typeof(value.get("station")) not in [TYPE_INT,TYPE_FLOAT]: return false
	if value.station==0: return value.size()==1 and (spread<=0.0 or service>=.999) and (out<=0.0 or spread>=.999)
	if value.station!=1 or value.size()!=3 or spread<.999 or out<=0.0: return false
	for key: String in ["position","rotation"]:
		if value.get(key) is not Array or value[key].size()!=(3 if key=="position" else 4): return false
		for number: Variant in value[key]:
			if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)): return false
	var pos := Vector3(value.position[0],value.position[1],value.position[2])
	var rot := Quaternion(value.rotation[0],value.rotation[1],value.rotation[2],value.rotation[3])
	return pos.length()<10000 and absf(rot.length_squared()-1.0)<.0001

func restore(value: Dictionary) -> void:
	station=int(value.station)
	freeze=true
	linear_velocity=Vector3.ZERO
	angular_velocity=Vector3.ZERO
	if station==1:
		position=Vector3(value.position[0],value.position[1],value.position[2])
		basis=Basis(Quaternion(value.rotation[0],value.rotation[1],value.rotation[2],value.rotation[3]).normalized())
		collision_layer=1
		freeze=false
		sleeping=false
	refresh()
