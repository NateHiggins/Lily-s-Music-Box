extends Node3D
const FITTING_LAYER:=1<<18
const CURSOR_LAYER:=1<<19
## Original screw travel with direct hand placement and authored release poses.
## Parent actor retains maintenance, hand ownership and household persistence.
class CursorBody extends AnimatableBody3D:
	var provider: Callable
	func manipulation_target(hit: Dictionary) -> Dictionary:return provider.call(hit)
class LooseBody extends RigidBody3D:
	var provider: Callable
	func manipulation_target(hit: Dictionary) -> Dictionary:return provider.call(hit)
class SeatBody extends StaticBody3D:
	var provider: Callable
	func manipulation_target(_hit: Dictionary) -> Dictionary:return provider.call() if provider.is_valid() else {}
var actor: Node3D
var stock: RefCounted
var seat: MeshInstance3D
var nut: MeshInstance3D
var spigot: MeshInstance3D
var body: LooseBody
var physical_nut: CursorBody
var receiver:=Transform3D.IDENTITY
var angle:=0.
var loose:=false
var spin:=0.
var clocking:=0.
var _observed:=false
var _lever_shapes: Dictionary={}
var _lever_rows: Array[Dictionary]=[]
var hose_grip_provider: Callable
var hose_seat_grip_provider: Callable
var _submitted_poses: Dictionary={}
var _actor_pose:=Transform3D.IDENTITY
const GUIDE_SNAP_RADIUS:=.045

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
	var fixed:=SeatBody.new();fixed.name="NativeNozzleSeatCollision";fixed.collision_layer=1|FITTING_LAYER;seat.add_child(fixed)
	fixed.provider=func():return hose_seat_grip_provider.call() if loose and hose_seat_grip_provider.is_valid() else {}
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(preload("res://scripts/props/fire_hose_rack.gd").imported_faces(seat.mesh))
	var collision:=CollisionShape3D.new();collision.shape=shape;fixed.add_child(collision)
	var hand:=CursorBody.new();hand.sync_to_physics=false;hand.name="NativeNozzleNutCursor";hand.collision_layer=CURSOR_LAYER;nut.add_child(hand);hand.provider=func(_hit: Dictionary):return nut_grip()
	shape=ConcavePolygonShape3D.new();shape.set_faces(preload("res://scripts/props/fire_hose_rack.gd").imported_faces(nut.mesh))
	collision=CollisionShape3D.new();collision.shape=shape;hand.add_child(collision)
	physical_nut=CursorBody.new();physical_nut.sync_to_physics=false;physical_nut.name="NativeNozzleNutPhysical";physical_nut.collision_layer=1|FITTING_LAYER;nut.add_child(physical_nut);physical_nut.provider=func(_hit: Dictionary):return nut_grip()
	collision=CollisionShape3D.new();collision.shape=stock.physical_nut;physical_nut.add_child(collision)
	body=LooseBody.new();body.name="PhysicalNozzle";body.freeze=true;body.collision_layer=1;body.collision_mask=1;actor.add_child(body)
	body.provider=func(hit: Dictionary):return actor._grip("lever") if _lever_shapes.has(int(hit.get("shape",-1))) else body_grip()
	body.add_collision_exception_with(actor._bodies.lever)
	angle=0. if actor.nozzle_coupled else stock.maximum_angle();loose=not actor.nozzle_coupled;_observed=actor.nozzle_coupled
	body.transform=rest_pose() if loose else thread_pose(angle);_apply_visuals()
	for draw: MeshInstance3D in actor._play_pipe.find_children("*","MeshInstance3D",true,false):
		if draw==seat or draw.mesh==null:continue
		var frame: Transform3D=body.global_transform.affine_inverse()*draw.global_transform
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
	_submit_global_pose(actor._play_pipe,body.global_transform)
	_submit_global_pose(seat,actor.global_transform*receiver)
	_submit_local_pose(nut,receiver*Transform3D(Basis(Vector3.UP,angle+spin),Vector3.ZERO))
	for row: Dictionary in _lever_rows:_submit_global_pose(row.shape,row.draw.global_transform)

func _submit_global_pose(node: Node3D,pose: Transform3D) -> void:
	# Compare exact matrices. Parent movement must still submit even if the
	# inherited node transform already looks correct: physics can publish later.
	if _pose_was_submitted(node,pose):return
	node.global_transform=pose
	_submitted_poses[node]=[pose,node.transform,node.get_parent_node_3d().global_transform]

func _submit_local_pose(node: Node3D,pose: Transform3D) -> void:
	var world_pose: Transform3D=node.get_parent_node_3d().global_transform*pose
	if _pose_was_submitted(node,world_pose) and node.transform==pose:return
	node.transform=pose
	_submitted_poses[node]=[world_pose,node.transform,node.get_parent_node_3d().global_transform]

func _pose_was_submitted(node: Node3D,world_pose: Transform3D) -> bool:
	if not _submitted_poses.has(node):return false
	var previous: Array=_submitted_poses[node]
	# Capture the accepted local pose: a global-to-local round trip need not
	# reproduce the requested world matrix bit-for-bit at translated frames.
	return previous[0]==world_pose and previous[1]==node.transform and previous[2]==node.get_parent_node_3d().global_transform

func sync() -> void:
	if body==null:return
	if actor.nozzle_coupled!=_observed:
		clocking=fposmod(spin,TAU);spin=clocking
		angle=0. if actor.nozzle_coupled else stock.maximum_angle();loose=not actor.nozzle_coupled
		body.transform=rest_pose() if loose else thread_pose(angle)
	if not loose:_submit_local_pose(body,thread_pose(angle))
	_observed=not loose and absf(angle)<.0001;actor.nozzle_coupled=_observed
	_apply_visuals()

func _grip(kind: String,part: Node3D) -> Dictionary:
	return {"owner":actor,"part":part,"frame":actor,"kind":kind,
		"read_basis":func():return body.basis,"write_basis":_manipulate_basis,
		"begin":func():
			if not actor._claim("nozzle_body"):return false
			return true,
		"owns":func():return actor._hand=="nozzle_body","end":_release_body,
		"read":func():return body.position,"write":func(value: Vector3):
			if actor._hand=="nozzle_body":_carry(value)}


func _manipulate_basis(value: Basis) -> void:
	if actor._hand!="nozzle_body" or not loose or not value.is_finite():return
	body.basis=value.orthonormalized()
	var relative: Basis=receiver.basis.inverse()*body.basis
	clocking=fposmod(atan2(-relative.x.z,relative.x.x),TAU)
	_apply_visuals()

func body_grip() -> Dictionary:
	if not loose and hose_grip_provider.is_valid():return hose_grip_provider.call()
	# A still-threaded body is constrained by its receiving thread. The nut is
	# the operable turning part; clearing it exposes genuine loose-body carrying.
	if not loose:return {}
	return _grip("free",actor._play_pipe)

func nut_grip() -> Dictionary:
	return {"owner":actor,"part":nut,"frame":self,"kind":"hinge","axis":receiver.basis.y,"minimum":-INF if loose else 0.,"maximum":INF if loose else stock.maximum_angle(),
		"read":func():return spin if loose else angle,"write":func(value: float):
			if actor._hand=="nozzle_nut":
				if loose:
					if is_finite(value):_turn_loose(value)
				else:turn(value),
		"begin":func():return actor._claim("nozzle_nut"),"owns":func():return actor._hand=="nozzle_nut",
		"end":func():
			if not loose and angle>=stock.maximum_angle()-.000001:loose=true;_snap_release()
			sync();actor._release()}

func _turn_loose(value: float) -> void:
	var delta: float=value-spin
	# Free rotation still operates the actual captured nut. A tightening
	# gesture can pick up the helix only after the spigot enters its mouth.
	var local: Vector3=receiver.affine_inverse()*body.position
	var travel: float=local.y-float(stock.data.dimensions.nozzle_base_y_m)
	var pitch: float=stock.data.dimensions.pitch_m
	var entered: bool=travel>=0. and travel<float(stock.data.dimensions.withdrawal_m)-.0001
	var aligned: bool=Vector2(local.x,local.z).length()<=float(stock.data.dimensions.radial_clearance_m) and body.basis.y.dot(receiver.basis.y)>.9999
	if delta<0. and entered and aligned:
		var pickup: float=TAU*travel/pitch
		# Female angle = maximum+spin; male phase = body clocking. The
		# phase crossing, rather than a release click, starts the native helix.
		var until_match: float=fposmod(stock.maximum_angle()+spin-clocking-pickup,TAU)
		if TAU-until_match<.000001:until_match=0.
		if until_match<=-delta:
			angle=pickup;spin=clocking;loose=false
			sync();turn(pickup+delta+until_match)
			return
	spin=fposmod(value,TAU);_apply_visuals()

func turn(value: float) -> void:
	if loose or not is_finite(value):return
	# The authored thread is the constraint; no world sweep or impact solve.
	angle=clampf(value,0.,stock.maximum_angle())
	_observed=absf(angle)<.0001;actor.nozzle_coupled=_observed;sync()

func rest_pose() -> Transform3D:
	var pose: Transform3D=thread_pose(stock.maximum_angle(),0.)
	# Authored cabinet-floor bearing, with a tenth-millimetre visual clearance.
	pose.origin+=Vector3.DOWN*.0199
	return pose
func guide_pose() -> Transform3D:
	return receiver*Transform3D(Basis.IDENTITY,Vector3(0,stock.pilot_min,0))
func _carry(value: Vector3) -> void:
	if not loose or not value.is_finite() or value.length_squared()>100000000.:return
	body.position=value
	_apply_visuals()
func _snap_release() -> void:
	if not loose:return
	var parked: Transform3D=rest_pose()
	var guided: Transform3D=guide_pose()
	var distance: float=body.position.distance_to(guided.origin)
	# Generous placement, not a micrometre alignment exercise. Seating here
	# only presents the spigot to the nut; it never seals or repairs the joint.
	body.transform=guided if distance<=GUIDE_SNAP_RADIUS and distance<body.position.distance_to(parked.origin) else parked
	clocking=0.;sync()
func _release_body() -> void:
	_snap_release();actor._release()
func _physics_process(_delta: float) -> void:
	# Refresh native picking after an ancestor moves; no idle part simulation.
	if actor!=null and actor.global_transform!=_actor_pose:
		sync();_actor_pose=actor.global_transform

func _on_pilot() -> bool:
	var local: Vector3=receiver.affine_inverse()*body.position
	return Vector2(local.x,local.z).length()<.000002 and local.y>=stock.pilot_min-.000002 and local.y<stock.pilot_max-.0001

func snapshot() -> Dictionary:
	var axes: Array=[]
	for axis: Vector3 in [body.basis.x,body.basis.y,body.basis.z]:axes.append([axis.x,axis.y,axis.z])
	return {"angle":angle,"spin":spin,"clocking":clocking,"loose":loose,"position":[body.position.x,body.position.y,body.position.z],"basis":axes}


func _saved_basis(value: Dictionary,saved_receiver: Variant=null) -> Basis:
	var reference: Transform3D=receiver if saved_receiver==null else saved_receiver
	if not value.has("basis"):return reference.basis*Basis(Vector3.UP,float(value.clocking))
	if value.basis is not Array or value.basis.size()!=3:return Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
	var axes: Array[Vector3]=[]
	for row: Variant in value.basis:
		if row is not Array or row.size()!=3:return Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
		for number: Variant in row:
			if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)):return Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
		axes.append(Vector3(row[0],row[1],row[2]))
	return Basis(axes[0],axes[1],axes[2])

func valid(value: Variant,made_up: bool,saved_receiver: Variant=null) -> bool:
	if saved_receiver!=null and typeof(saved_receiver)!=TYPE_TRANSFORM3D:return false
	var reference: Transform3D=receiver if saved_receiver==null else saved_receiver
	if not reference.is_finite() or absf(reference.basis.determinant()-1.)>.00001 or not reference.basis.transposed().is_equal_approx(reference.basis.inverse()):return false
	if value is not Dictionary or value.size() not in [5,6] or typeof(value.get("loose"))!=TYPE_BOOL:return false
	for key: String in value:
		if key not in ["angle","spin","clocking","loose","position","basis"]:return false
	for key: String in ["spin","clocking"]:
		if typeof(value.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[key])):return false
	if value.clocking<0. or value.clocking>=TAU or value.spin<0. or value.spin>=TAU:return false
	var orientation: Basis=_saved_basis(value,saved_receiver)
	if not orientation.is_finite() or absf(orientation.determinant()-1.)>.00001 or not orientation.transposed().is_equal_approx(orientation.inverse()):return false
	if not value.loose and not orientation.is_equal_approx(reference.basis*Basis(Vector3.UP,float(value.clocking))):return false
	if typeof(value.get("angle")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value.angle)) or value.angle<0. or value.angle>stock.maximum_angle():return false
	if value.get("position") is not Array or value.position.size()!=3:return false
	for coordinate: Variant in value.position:
		if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)):return false
	var at:=Vector3(value.position[0],value.position[1],value.position[2])
	if at.length()>10000.:return false
	if value.loose and absf(float(value.angle)-stock.maximum_angle())>.000001:return false
	var saved_pose:=reference*Transform3D(Basis(Vector3.UP,float(value.clocking)),Vector3(0,stock.body_y(float(value.angle)),0))
	if not value.loose and (at.distance_to(saved_pose.origin)>.000001 or absf(float(value.spin)-float(value.clocking))>.000001):return false
	return made_up==(not value.loose and absf(float(value.angle))<.0001)

func restore(value: Dictionary) -> void:
	angle=value.angle;spin=value.spin;clocking=value.clocking;loose=value.loose;_observed=actor.nozzle_coupled
	body.transform=Transform3D(_saved_basis(value),Vector3(value.position[0],value.position[1],value.position[2]));sync()

func restore_legacy(made_up: bool) -> void:
	angle=0. if made_up else stock.maximum_angle();spin=0.;clocking=0.;loose=not made_up;_observed=made_up
	body.transform=rest_pose() if loose else thread_pose(angle);sync()

