extends Node3D
## Separate round native stock after extraction. The folded representation has
## no solver. Candidate owner; installed only by the dedicated diagnostic bench.
const EXTRACTION_M:=.20
var actor: Node3D
var joint: Node3D
var model: Node3D
var rig:=preload("res://scripts/props/native_hose_rig.gd").new()
var contact:=preload("res://scripts/props/native_hose_world_contact.gd").new()
var tether:=preload("res://scripts/props/native_hose_tether.gd").new()
var deployed:=false
var extraction:=0.
var error:=""
var setup_ms:=0.
var _receiver:=Transform3D.IDENTITY
var _extracted_receiver:=Transform3D.IDENTITY
var _placement:=PackedVector3Array()
var _stored: Array[Node3D]=[]
var _stock_layers: Dictionary={}
var _receiver_from_tip:=Transform3D.IDENTITY
var _bend_radii:=PackedFloat64Array()
var _physical_bend_spans:=PackedFloat64Array()
var last_nozzle_query: Dictionary={}
var _nozzle_bounds: Dictionary={}
var _nozzle_box:=BoxShape3D.new()
var _nozzle_radius:=0.
var guide_enabled:=false
var ground_y_local:=0.
var guide_axis_local:=Vector3.LEFT
var guide_side_local:=Vector3.BACK
var _guide_floor:=0.

func configure(owner_actor: Node3D,asset_path: String,projection: Dictionary,placement: Dictionary) -> bool:
	var started: int=Time.get_ticks_usec()
	if actor!=null or owner_actor._nozzle_joint==null:return false
	actor=owner_actor;joint=actor._nozzle_joint;_receiver=joint.receiver
	_extracted_receiver=_receiver;_extracted_receiver.origin+=Vector3.BACK*EXTRACTION_M
	for shape: CollisionShape3D in joint.body.get_children():
		if not shape.shape is ConvexPolygonShape3D:return false
		var local:=AABB(shape.shape.points[0],Vector3.ZERO)
		for point: Vector3 in shape.shape.points:local=local.expand(point)
		_nozzle_bounds[shape]={"resource":shape.shape,"bounds":local}
		for point: Vector3 in shape.shape.points:_nozzle_radius=maxf(_nozzle_radius,(shape.transform*point).length())
	var packed:=load(asset_path) as PackedScene
	if packed==null:return false
	model=packed.instantiate();add_child(model);model.visible=false
	if not rig.configure(model,projection) or not rig.enable_material_transport():return false
	# Retain the source's rigid upstream frame at the actual union port.
	model.transform=Transform3D(Basis(Vector3.BACK,PI*.5),Vector3.ZERO)
	model.position=Vector3(.170,.445,.098)-model.basis*rig.rest[-1]
	if placement.get("points") is not Array or placement.points.size()!=rig.rest.size():return false
	for row: Array in placement.points:
		if row.size()!=3:return false
		_placement.append(model.transform.affine_inverse()*Vector3(.340-float(row[0]),row[1],row[2]))
	var kernel:=preload("res://scripts/props/hose_mass_constraints.gd").new()
	# Bound the discrete mitres by the round outer section. Inflate the
	# required span by the numerical tolerance BEFORE deriving solver radii,
	# so accepting that tolerance cannot violate the physical span below.
	_bend_radii.resize(rig.rest.size());_bend_radii.fill(.02152)
	for i in range(1,rig.rest.size()-1):
		var first: float=rig.strand.lengths[i-1];var second: float=rig.strand.lengths[i]
		var angle: float=minf(PI*.5,2.*atan(minf(first,second)/(2.*.02152)))
		var span: float=sqrt(first*first+second*second+2.*first*second*cos(angle))
		_physical_bend_spans.append(span)
		var target: float=span+.00002
		if target>=first+second:return false
		var solver_angle: float=acos(clampf((target*target-first*first-second*second)/(2.*first*second),-1.,1.))
		_bend_radii[i]=(first+second)*.5/solver_angle
	if not kernel.configure(rig.strand.lengths,_placement,_bend_radii):return false
	if not kernel.coupled.set_bend_error(.00002):return false
	kernel.bend_error_m=.00002
	var tip: Vector3=model.transform.affine_inverse()*(_receiver.origin+Vector3.BACK*EXTRACTION_M)
	# The barrel extends along receiver +Y; cloth leaves the back of its
	# socket along -Y. Reversing this creates a needless loop inside the tip.
	var into_hose: Vector3=-(model.basis.inverse()*_receiver.basis.y)
	var pins: Dictionary={0:tip,1:tip+into_hose*.005,2:tip+into_hose*.010,
		rig.rest.size()-2:_placement[-2],rig.rest.size()-3:_placement[-3]}
	for attempt in 16:
		var solved: PackedVector3Array=kernel.follow(_placement,rig.strand.anchor,{},pins,attempt>0)
		if not solved.is_empty():_placement=solved;break
		if kernel.coupled.last_iterate.size()!=_placement.size():error=kernel.error;return false
		if attempt==15:error=kernel.error;return false
		_placement=kernel.coupled.last_iterate.duplicate()
	if not rig.strand._valid_positions(_placement):error="unracked placement changes material length";return false
	var own: Dictionary=kernel.coupled.round_self_constraints(_placement,_placement,.021,pins)
	if not own.valid or not own.clear:error="unracked placement has round self contact: "+str(own);return false
	_receiver_from_tip=rig.model_frames(_placement)[0].affine_inverse()*model.transform.affine_inverse()*(_receiver*Transform3D(Basis.IDENTITY,_receiver.basis.inverse()*Vector3.BACK*EXTRACTION_M))
	for node: Node3D in [actor._folds,actor.get_node("NativeContinuousFolds"),actor.get_node("NativeHoseRuns")]:_stored.append(node)
	# Material setup and the numerical initial pose happen before input.
	var finish: StandardMaterial3D=MatLib.get_mat("linen").duplicate()
	var catalogue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/runtime_material_sets.json"))
	finish.uv1_triplanar=false;finish.uv1_scale=Vector3.ONE/float(catalogue.materials.linen.meters_per_tile)
	finish.albedo_color=Color(.75,.71,.59);finish.normal_scale=.08;finish.roughness=.9;finish.metallic=0.
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):draw.material_override=finish
	setup_ms=(Time.get_ticks_usec()-started)/1000.
	set_process(false);set_physics_process(false)
	return true

func prepare_contact() -> bool:
	var excluded: Array[RID]=[joint.body.get_rid(),actor._bodies.lever.get_rid(),joint.physical_nut.get_rid()]
	for node: Node3D in _stored:
		for body: CollisionObject3D in node.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	for part: Node3D in [joint.seat,joint.nut]:
		for body: CollisionObject3D in part.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	if not contact.configure(rig,get_world_3d().direct_space_state,excluded):error=contact.error;return false
	contact.analytic_boxes=true
	var before: PackedVector3Array=rig.strand.points
	rig.strand.points=_placement
	tether.round_self_radius_m=.021
	tether.lock_tip_direction=false
	if guide_enabled:tether.substep_m=.08
	var prepared: bool=tether.configure(rig,contact,_bend_radii)
	rig.strand.points=before
	if not prepared:return false
	if not tether.kernel.coupled.set_bend_error(.00002):return false
	tether.kernel.bend_error_m=.00002
	if guide_enabled:
		var up: Vector3=model.basis.inverse()*Vector3.UP
		_guide_floor=up.dot(model.transform.affine_inverse()*Vector3(0,ground_y_local+.023,0))
		tether.seed_factory=_guide_seed
	var pins: Dictionary={0:_placement[0],1:_placement[1],2:_placement[2],_placement.size()-2:_placement[-2],_placement.size()-3:_placement[-3]}
	if guide_enabled:
		var seed: PackedVector3Array=_guide_seed(_placement,_placement[0])
		if seed.is_empty():error="simple extended guide unavailable";return false
		pins[1]=seed[1];pins[2]=seed[2]
		var guided: PackedVector3Array=tether.kernel.follow(seed,rig.strand.anchor,{},pins)
		if guided.is_empty():error="initial simple guide fit: "+tether.kernel.error;return false
		_placement=guided
	var planes: Dictionary={}
	for attempt in 16:
		var occupied: Dictionary=contact.contact_constraints(_placement,4096)
		if not occupied.valid or occupied.truncated:error="invalid initial native hose contacts";return false
		if occupied.planes.is_empty():
			if not _physical_bends_clear(_placement):error="initial round hose physical bend bound";return false
			var own: Dictionary=tether.kernel.coupled.round_self_constraints(_placement,_placement,.021,pins)
			if not own.valid or not own.clear:error="world-fitted layout has round self contact: "+str(own);return false
			_extracted_receiver=model.transform*rig.model_frames(_placement)[0]*_receiver_from_tip
			return true
		for plane: Dictionary in occupied.planes:tether._merge(planes,plane)
		var fitted: PackedVector3Array=tether.kernel.follow(_placement,rig.strand.anchor,planes,pins)
		if fitted.is_empty():error="initial hose contact fit: "+tether.kernel.error;return false
		_placement=fitted
	error="initial hose contact fit ceiling";return false

func _guide_seed(before: PackedVector3Array,goal: Vector3) -> PackedVector3Array:
	var retained: PackedVector3Array=before
	var tension: float=clampf((goal.distance_to(rig.strand.anchor)-11.)/8.,0.,.35)
	if tension>0.:
		# The loose floor route must lift inside the case under tension. Give
		# the solver a shorter spatial route, retaining EVERY material interval
		# and the fixed native port. Actual swept contact still vetoes this hint.
		retained=before.duplicate()
		var into_model: Basis=model.basis.inverse()
		var neck: int=before.size()-4
		retained[neck]=retained[neck+1]+into_model*Vector3.DOWN*rig.strand.lengths[neck]
		var horizontal:=Vector3(-sqrt(1.-.4*.4),0,.4)
		var directions: Array[Vector3]=[Vector3(-sin(.14),-cos(.14),0),horizontal*sin(deg_to_rad(85.))+Vector3.DOWN*cos(deg_to_rad(85.)),horizontal,horizontal]
		for offset in 4:
			var index: int=neck-1-offset
			var current: Vector3=(before[index]-before[index+1]).normalized()
			var desired: Vector3=(into_model*directions[offset]).normalized()
			retained[index]=retained[index+1]+current.slerp(desired,tension).normalized()*rig.strand.lengths[index]
	var seed: Dictionary=tether.kernel.coupled.round_guide_seed(retained,goal,before.size()-8,model.basis.inverse()*guide_axis_local,model.basis.inverse()*guide_side_local,_guide_floor)
	return seed.points

func _physical_bends_clear(points: PackedVector3Array) -> bool:
	if points.size()!=_physical_bend_spans.size()+2:return false
	for i in _physical_bend_spans.size():
		if points[i].distance_to(points[i+2])<_physical_bend_spans[i]-.000001:return false
	return true

func grip() -> Dictionary:
	if not actor.door_open or joint.loose:return {}
	if deployed:
		return {"owner":actor,"part":actor._play_pipe,"frame":model,"kind":"free",
			"read":func():return rig.strand.points[0],"write":_move,
			"begin":func():return actor._claim("hose"),"owns":func():return actor._hand=="hose",
			"motion_pending":func():return tether.pending,"end":_release}
	return {"owner":actor,"part":actor._play_pipe,"frame":actor,"kind":"slider","axis":Vector3.BACK,
		"minimum":0.,"maximum":EXTRACTION_M,"read":func():return extraction,"write":_extract,
		"begin":func():return actor._claim("hose"),"owns":func():return actor._hand=="hose","end":_release}

func _nozzle_clear(receiver: Transform3D) -> bool:
	var pose: Transform3D=actor.global_transform*joint.thread_pose(joint.angle)
	var proposed: Transform3D=actor.global_transform*receiver*Transform3D(Basis(Vector3.UP,joint.clocking),Vector3(0,joint.stock.body_y(joint.angle),0))
	var excluded: Array[RID]=[joint.body.get_rid(),actor._bodies.lever.get_rid(),joint.physical_nut.get_rid()]
	for part: Node3D in [joint.seat,joint.nut]:
		for body: CollisionObject3D in part.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	# Receiver transport can change the child collider frames independently
	# of the lever angle. Transform immutable local bounds; do not regenerate
	# the receiver's expensive radial contact profiles for a broad-phase test.
	var bounds:=AABB();var first:=true;var radius:=0.
	for shape: CollisionShape3D in joint.body.get_children():
		if shape.disabled:continue
		if not _nozzle_bounds.has(shape) or _nozzle_bounds[shape].resource!=shape.shape:return false
		var local: AABB=shape.transform*_nozzle_bounds[shape].bounds
		radius=maxf(radius,local.position.abs().max(local.end.abs()).length())
		var current: AABB=pose*local
		current=current.merge(proposed*local)
		bounds=current if first else bounds.merge(current);first=false
	if first:return false
	var motion: Vector3=proposed.origin-pose.origin
	var angle: float=pose.basis.get_rotation_quaternion().angle_to(proposed.basis.get_rotation_quaternion())
	# Endpoint boxes contain every vertex chord. Inflate by the maximum
	# circular-arc sagitta to contain the complete rotation between endpoints.
	bounds=bounds.grow(radius*(1.-cos(angle*.5))+.0001)
	var space:=get_world_3d().direct_space_state
	var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=1;query.exclude=excluded;query.margin=0.
	_nozzle_box.size=bounds.size;query.shape=_nozzle_box;query.transform=Transform3D(Basis.IDENTITY,bounds.get_center())
	var broad_clear: bool=space.intersect_shape(query,1).is_empty()
	last_nozzle_query={"motion":motion,"broad_clear":broad_clear}
	if broad_clear:return true
	# The coupled body is frozen. Sweep its actual convex stock directly,
	# including the lever, rather than relying on dynamic-body motion recovery.
	query.margin=.00002
	for shape: CollisionShape3D in joint.body.get_children():
		if shape.disabled:continue
		if not shape.shape is ConvexPolygonShape3D:return false
		if angle>.000001:
			# Reuse cached stock at each short arc's midpoint orientation.
			# Inflation bounds every vertex's displacement from that midpoint;
			# the translation cast covers the simultaneous origin movement.
			var steps: int=ceili(angle/.04)
			if steps>64:return false
			query.margin=2.*radius*sin(angle/(4.*steps))+.00002
			query.shape=shape.shape
			var first_rotation: Quaternion=pose.basis.get_rotation_quaternion()
			var last_rotation: Quaternion=proposed.basis.get_rotation_quaternion()
			for step in steps:
				var fraction: float=float(step)/steps
				var basis:=Basis(first_rotation.slerp(last_rotation,(float(step)+.5)/steps))
				query.transform=Transform3D(basis,pose.origin+motion*fraction)*shape.transform;query.motion=Vector3.ZERO
				if not space.intersect_shape(query,1).is_empty():return false
				query.motion=motion/steps
				var swept: PackedFloat32Array=space.cast_motion(query)
				if swept.size()!=2 or swept[0]<1.:return false
			continue
		query.shape=shape.shape;query.transform=proposed*shape.transform;query.motion=Vector3.ZERO
		if not space.intersect_shape(query,1).is_empty():return false
		query.transform=pose*shape.transform;query.motion=proposed.origin-pose.origin
		var result: PackedFloat32Array=space.cast_motion(query)
		if result.size()!=2 or result[0]<1.:return false
	return true

func _extract(value: float) -> void:
	if actor._hand!="hose" or deployed or not is_finite(value):return
	value=clampf(value,0.,EXTRACTION_M)
	var proposed:=_receiver;proposed.origin+=Vector3.BACK*value
	proposed.basis=Basis(_receiver.basis.get_rotation_quaternion().slerp(_extracted_receiver.basis.get_rotation_quaternion(),value/EXTRACTION_M))
	if not _nozzle_clear(proposed):error="nozzle extraction obstructed";return
	if value>=EXTRACTION_M-.000001:
		# Representation swap is discrete and authorized. Occupancy is checked
		# afresh; no sweep from a completely different folded topology is faked.
		if not contact.ready or contact.intersects_pose(_placement):error="unracked placement obstructed";return
		if not rig.apply_points(_placement):error="unracked native skin unavailable";return
		rig.strand.points=_placement.duplicate();deployed=true;actor.hose_racked=false
		for node: Node3D in _stored:
			node.visible=false;node.set_process(false)
			for body: CollisionObject3D in node.find_children("*","CollisionObject3D",true,false):
				_stock_layers[body]=body.collision_layer;body.collision_layer=0
		model.visible=true
	joint.receiver=proposed;joint.sync();extraction=value;error=""

func _move(value: Vector3) -> void:
	if actor._hand!="hose" or not deployed or not value.is_finite():return
	if not tether.prepare_endpoint(value):error=tether.error;set_process(tether.pending);return
	_commit_motion()
	set_process(tether.pending)

func _process(_delta: float) -> void:
	if actor._hand!="hose" or not deployed:tether.cancel_motion();set_process(false);return
	if tether.pending and tether.resume_prepare():_commit_motion()
	set_process(tether.pending)

func _commit_motion() -> void:
	if not tether.has_prepared_endpoint():return
	var points: PackedVector3Array=tether.prepared_endpoint_points()
	if not _physical_bends_clear(points):tether.cancel_motion();error="round hose physical bend bound";return
	var receiver: Transform3D=model.transform*rig.model_frames(points)[0]*_receiver_from_tip
	if not _nozzle_clear(receiver):tether.cancel_motion();error="nozzle obstructed";return
	if not tether.commit_endpoint():error=tether.error;return
	joint.receiver=receiver;joint.sync();error=""

func _release() -> void:
	tether.cancel_motion();set_process(false);actor._release()
