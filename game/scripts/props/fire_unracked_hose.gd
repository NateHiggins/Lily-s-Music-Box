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
var last_fitting_blocker:=""
var cast_observer: Callable
var _fitting_candidates: Array[Dictionary]=[]
var _nozzle_bounds: Dictionary={}
var _nozzle_box:=BoxShape3D.new()
var _nozzle_radius:=0.
var _receiving_stock: Array[Dictionary]=[]
var guide_enabled:=false
var ground_y_local:=0.
var guide_axis_local:=Vector3.LEFT
var guide_side_local:=Vector3.BACK
var _guide_floor:=0.
var profile_motion:=false
var last_motion_profile: Dictionary={}
var motion_profile_records: Array[Dictionary]=[]
var _last_fitting_usec:=0
var _last_prepare_usec:=0
var _last_broad_queries:=0
var _last_shell_queries:=0
var local_follow_enabled:=false
var local_contacts_enabled:=false
var fps_aim_enabled:=false
var fps_once_per_frame:=false
var last_hand_debug: Dictionary={}
var _hold_frame: int=-1
var _last_hold_usec: int=0
var _carrier: WeakRef
var _auxiliary_contacts: Array[Dictionary]=[]
var _cover: PhysicsBody3D
var _cover_stock_added:=false
var _cover_holder_added:=false
var _contact_exclusions: Array[RID]=[]
var _local_follow:=preload("res://scripts/props/round_local_endpoint.gd").new()
var visual_follow_enabled:=false
var visual_route:=preload("res://scripts/props/hose_visual_route.gd").new()
var water:=preload("res://scripts/props/hose_water_charge.gd").new()
var _spray: GPUParticles3D

func enable_visual_follow() -> void:
	# Owner-authorized approximation supersedes physical full-payout solves.
	# Maintenance fittings retain their existing separate mechanical owners.
	tether.cancel_motion();set_process(false);visual_follow_enabled=true
	fps_aim_enabled=true;fps_once_per_frame=true;error=""
	actor._live_hose=self
	if not actor.manipulation_changed.is_connected(water_controls_changed):actor.manipulation_changed.connect(water_controls_changed)
	if deployed:rig.apply_points(rig.strand.points,water.pressure)
	water_controls_changed()

func water_controls_changed() -> void:
	if not visual_follow_enabled or not deployed:return
	var connected: bool=actor.gasket_seated and actor.coupling_made_up and actor.nozzle_coupled
	var needs_fill: bool=connected and actor.hose_supply_opening()>0.
	var needs_drain: bool=water.fill>0. and (not connected or actor._lever_angle<-.0001)
	if needs_fill or needs_drain or water.spray>0.:set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not visual_follow_enabled or not deployed:set_physics_process(false);return
	var connected: bool=actor.gasket_seated and actor.coupling_made_up and actor.nozzle_coupled
	var supply: float=actor.hose_supply_opening()
	var lever: float=0. if actor.nozzle_shut else clampf(-actor._lever_angle/.95,0.,1.)
	var changed: bool=water.advance(delta,supply,lever,connected)
	if changed:rig.apply_points(rig.strand.points,water.pressure)
	if water.spray>0.001 and _spray==null:_make_spray()
	if _spray!=null:
		_spray.emitting=water.spray>.001
		_spray.amount_ratio=clampf(water.spray,0.,1.)
	# Stable pressure and GPU emission require no ongoing cloth/fluid tick.
	set_physics_process(changed)

func _make_spray() -> void:
	_spray=GPUParticles3D.new();_spray.name="NozzleWater";_spray.emitting=false
	_spray.local_coords=false
	_spray.amount=384;_spray.lifetime=.65;_spray.fixed_fps=30
	_spray.visibility_aabb=AABB(Vector3(-12,-12,-12),Vector3(24,24,24))
	var process:=ParticleProcessMaterial.new();process.direction=Vector3.UP;process.spread=2.5
	process.initial_velocity_min=11.;process.initial_velocity_max=13.;process.gravity=Vector3(0,-9.8,0)
	process.particle_flag_align_y=true
	process.scale_min=.5;process.scale_max=1.;_spray.process_material=process
	var drop:=SphereMesh.new();drop.radius=.002;drop.height=.025;drop.radial_segments=8;drop.rings=4
	var finish: StandardMaterial3D=MatLib.get_mat("water_clear").duplicate()
	finish.uv1_triplanar=false;finish.uv1_scale=Vector3(.05,.10,1.)
	finish.normal_enabled=true;finish.normal_scale=.1
	finish.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	finish.albedo_color=Color(.7,.85,1.,.5);finish.roughness=.12
	drop.material=finish;_spray.draw_pass_1=drop
	# Keep the physical body's shape-only child contract intact. The original
	# play-pipe presentation already follows its authoritative rigid pose.
	actor._play_pipe.add_child(_spray);_spray.position=Vector3(0,.171,0)

func _visual_receiver(wanted: Transform3D) -> void:
	var started: int=Time.get_ticks_usec()
	var anchor: Vector3=model.to_global(rig.strand.anchor)
	wanted.origin=anchor+(wanted.origin-anchor).limit_length(rig.strand.total_length-.15)
	var local_tip: Vector3=model.to_local(wanted.origin)
	var back: Vector3=(model.global_basis.inverse()*-wanted.basis.y).normalized()
	var up: Vector3=(model.global_basis.inverse()*Vector3.UP).normalized()
	var points: PackedVector3Array=visual_route.build(local_tip,back,rig.strand.anchor,rig.rest.size(),rig.strand.total_length,up,_guide_floor)
	if points.is_empty() or not rig.apply_points(points,water.pressure):error="visual hose route unavailable";return
	rig.strand.points=points
	joint.receiver=actor.global_transform.affine_inverse()*wanted
	joint.sync();error=""
	if profile_motion:
		last_motion_profile={"total_usec":Time.get_ticks_usec()-started,"mode":"visual","process_frame":Engine.get_process_frames(),"shell_queries":0,"broad_queries":0}
		motion_profile_records.append(last_motion_profile)
		if motion_profile_records.size()>512:motion_profile_records.pop_front()

func set_local_follow(enabled: bool) -> bool:
	if not contact.ready:return false
	if enabled:
		if _local_follow.rig==null and not _local_follow.configure(rig,_bend_radii):return false
		_local_follow.prime(rig.strand.points if deployed else _placement)
		tether.seed_factory=_carry_seed;tether.substep_m=.08
		tether.constrained_seed_factory=_local_follow.constrained_seed if local_contacts_enabled else Callable()
	else:
		tether.constrained_seed_factory=Callable()
		tether.seed_factory=_guide_seed if guide_enabled else Callable()
		tether.substep_m=.08 if guide_enabled else .008
	local_follow_enabled=enabled;return true

func _carry_seed(before: PackedVector3Array,goal: Vector3) -> PackedVector3Array:
	return _local_follow.seed(before,goal)

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
	# The receiving seat and captured nut travel with the cloth as well as
	# the barrel. Preserve their bores with native angular stock sectors.
	var nut_mesh:=ArrayMesh.new();var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=joint.stock.physical_nut.get_faces()
	var indices:=PackedInt32Array();indices.resize(arrays[Mesh.ARRAY_VERTEX].size())
	for i in indices.size():indices[i]=i
	arrays[Mesh.ARRAY_INDEX]=indices
	nut_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	for row: Dictionary in [{"mesh":joint.seat.mesh,"nut":false,"cuts":[-.016,0.,.005,.014,.017]}, {"mesh":nut_mesh,"nut":true,"cuts":[.005,.0055,.014,.017,.0285,.029]}]:
		var cuts: Array[float]=[]
		for height: float in row.cuts:cuts.append(height)
		var cells: Array[ConvexPolygonShape3D]=preload("res://scripts/props/native_annular_collision.gd").build(row.mesh,cuts,48)
		if cells.is_empty():return false
		for cell: ConvexPolygonShape3D in cells:
			var bounds:=AABB(cell.points[0],Vector3.ZERO)
			for point: Vector3 in cell.points:bounds=bounds.expand(point)
			_receiving_stock.append({"shape":cell,"bounds":bounds,"nut":row.nut})
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
	var excluded: Array[RID]=[actor._bodies.lever.get_rid(),joint.physical_nut.get_rid()]
	if not joint.loose:excluded.append(joint.body.get_rid())
	for node: Node3D in _stored:
		for body: CollisionObject3D in node.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	for part: Node3D in [joint.seat,joint.nut]:
		for body: CollisionObject3D in part.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	if not contact.configure(rig,get_world_3d().direct_space_state,excluded):error=contact.error;return false
	_contact_exclusions=excluded.duplicate()
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
	var up: Vector3=model.basis.inverse()*Vector3.UP
	_guide_floor=up.dot(model.transform.affine_inverse()*Vector3(0,ground_y_local+.023,0))
	if guide_enabled:
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
	if not actor.door_open:return {}
	var part: Node3D=joint.seat if joint.loose else actor._play_pipe
	if deployed:
		return {"owner":actor,"part":part,"frame":model,"kind":"free",
			"physics_body":joint.body if not joint.loose else null,
			"bind_holder":_bind_hose_holder,
			"hold_pose":_hold_pose if fps_aim_enabled else null,
			"read":func():return rig.strand.points[0],"write":_move,
			"begin":_begin_hose,"owns":func():return actor._hand=="hose",
			"motion_pending":func():return tether.pending,"constraint_feedback":_constraint_feedback,"end":_release}
	return {"owner":actor,"part":part,"frame":actor,"kind":"slider","axis":Vector3.BACK,
		"minimum":0.,"maximum":EXTRACTION_M,"read":func():return extraction,"write":_extract,
		"begin":_begin_hose,"owns":func():return actor._hand=="hose","constraint_feedback":_extraction_feedback,"end":_release}

func _begin_hose() -> bool:
	if not tether.set_hand_follow_budget(.6 if fps_aim_enabled else tether.MAX_MOVE_M,12000 if fps_aim_enabled else tether.WORK_BUDGET_USEC):return false
	if not actor._claim("hose"):return false
	error="";tether.blocked=false;tether.limited=false;return true

func _bind_hose_holder(holder: Node3D) -> void:
	_hold_frame=-1;_last_hold_usec=0
	_clear_cover_passage();_clear_auxiliary_contacts();_carrier=weakref(holder);_refresh_cover_passage()
	if holder is not PhysicsBody3D:return
	var roots: Array[Node]=[joint.seat]
	if not joint.loose:roots.append_array([joint.nut,joint.physical_nut,actor._bodies.lever])
	var parts: Array[PhysicsBody3D]=[]
	for root: Node in roots:
		if root is PhysicsBody3D and not parts.has(root):parts.append(root)
		for part: PhysicsBody3D in root.find_children("*","PhysicsBody3D",true,false):
			if not parts.has(part):parts.append(part)
	for part: PhysicsBody3D in parts:
		if part==joint.body or part==holder:continue
		var holder_added: bool=not holder.get_collision_exceptions().has(part)
		var part_added: bool=not part.get_collision_exceptions().has(holder)
		if holder_added:holder.add_collision_exception_with(part)
		if part_added:part.add_collision_exception_with(holder)
		_auxiliary_contacts.append({"body":part,"holder_added":holder_added,"part_added":part_added})

func _clear_auxiliary_contacts() -> void:
	var holder: PhysicsBody3D=_carrier.get_ref() as PhysicsBody3D if _carrier!=null else null
	for row: Dictionary in _auxiliary_contacts:
		var part: PhysicsBody3D=row.body
		if holder==null or not is_instance_valid(part):continue
		if row.holder_added:holder.remove_collision_exception_with(part)
		if row.part_added:part.remove_collision_exception_with(holder)
	_auxiliary_contacts.clear()

func _refresh_cover_passage() -> void:
	if not actor.door_open or joint.loose or actor._hand!="hose":
		_clear_cover_passage();return
	if is_instance_valid(_cover):return
	var holder: PhysicsBody3D=_carrier.get_ref() as PhysicsBody3D if _carrier!=null else null
	if holder==null:return
	_cover=actor._bodies.door
	_cover_stock_added=not joint.body.get_collision_exceptions().has(_cover)
	_cover_holder_added=not holder.get_collision_exceptions().has(_cover)
	if _cover_stock_added:joint.body.add_collision_exception_with(_cover)
	if _cover_holder_added:holder.add_collision_exception_with(_cover)

func _clear_cover_passage() -> void:
	if is_instance_valid(_cover):
		if _cover_stock_added and is_instance_valid(joint):joint.body.remove_collision_exception_with(_cover)
		var holder: PhysicsBody3D=_carrier.get_ref() as PhysicsBody3D if _carrier!=null else null
		if _cover_holder_added and holder!=null:holder.remove_collision_exception_with(_cover)
	_cover=null;_cover_stock_added=false;_cover_holder_added=false

func _exit_tree() -> void:
	_clear_cover_passage();_clear_auxiliary_contacts()
	if is_instance_valid(actor) and actor._live_hose==self:actor._live_hose=null
	if is_instance_valid(_spray):_spray.queue_free()

func _hold_pose(view: Transform3D) -> void:
	_refresh_cover_passage()
	if fps_once_per_frame:
		var frame: int=Engine.get_process_frames()
		if frame==_hold_frame:return
		_hold_frame=frame
	if visual_follow_enabled:
		var aimed:=Basis(view.basis.x,-view.basis.z,view.basis.y)
		var wanted:=Transform3D(aimed*Basis(Vector3.UP,-joint.clocking),view*Vector3(.17,-.16,-.48))
		_visual_receiver(wanted)
		return
	if not fps_aim_enabled:
		# Preserve the previous position-only candidate for isolated controls.
		var point: Vector3=joint.body.global_position
		_move(rig.strand.points[0]+model.global_basis.inverse()*(view*Vector3(.17,-.16,-.48)-point).limit_length(.06))
		return
	var before: PackedVector3Array=rig.strand.points
	var direction: Vector3=(before[1]-before[0]).normalized()
	var desired: Vector3=(model.global_basis.inverse()*view.basis.z).normalized()
	var goal: Vector3=model.to_local(view*Vector3(.17,-.16,-.48))
	# Withdraw into the hand before turning beside the rack and open leaf.
	# A blocked translation still remains blocked by the original fitting sweep.
	if before[0].distance_to(goal)>.12:desired=direction
	var angle: float=acos(clampf(direction.dot(desired),-1.,1.))
	var now: int=Time.get_ticks_usec()
	var elapsed: float=minf(float(now-_last_hold_usec)/1000000.,.1) if fps_once_per_frame and _last_hold_usec>0 else get_physics_process_delta_time()
	_last_hold_usec=now
	var turn: float=minf(angle,6.*elapsed)
	if angle>.00001:
		# Antiparallel directions need an explicit stable perpendicular axis.
		var axis: Vector3=direction.cross(desired)
		if axis.length_squared()<1e-12:axis=direction.cross(Vector3.UP if absf(direction.y)<.9 else Vector3.RIGHT)
		direction=direction.rotated(axis.normalized(),turn).normalized()
	if tether.tip_direction.distance_to(direction)>.000001:tether.cancel_motion()
	if profile_motion:last_hand_debug={"frame":Engine.get_process_frames(),"distance_to_hand":before[0].distance_to(goal),"angle":angle,"elapsed":elapsed,"turn":turn,"requested":[direction.x,direction.y,direction.z],"desired":[desired.x,desired.y,desired.z]}
	tether.tip_direction=direction;_local_follow.tip_direction=direction
	_move(before[0]+(goal-before[0]).limit_length(minf(.6,12.*elapsed)))

func _constraint_feedback() -> String:
	if visual_follow_enabled:
		if not error.is_empty():return "blocked"
		return "limit" if visual_route.limited else "grabbed"
	if tether.pending:return "grabbed"
	if not error.is_empty() or tether.blocked:return "blocked"
	return "limit" if tether.limited else "grabbed"

func _extraction_feedback() -> String:
	if not error.is_empty():return "blocked"
	return "limit" if extraction>=EXTRACTION_M-.000001 else "grabbed"

func _nozzle_clear(receiver: Transform3D) -> bool:
	last_fitting_blocker=""
	if not _receiving_stock_clear(receiver):return false
	if joint.loose:return true
	var pose: Transform3D=actor.global_transform*joint.thread_pose(joint.angle)
	var proposed: Transform3D=actor.global_transform*receiver*Transform3D(Basis(Vector3.UP,joint.clocking),Vector3(0,joint.stock.body_y(joint.angle),0))
	var excluded: Array[RID]=[joint.body.get_rid(),actor._bodies.lever.get_rid(),joint.physical_nut.get_rid()]
	_append_carried_exclusions(excluded)
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
	if cast_observer.is_valid():_fitting_candidates=space.intersect_shape(query,256)
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
				if not _fitting_probe_clear(space,query,"barrel rotation"):return false
				query.motion=motion/steps
				if not _fitting_sweep_clear(space,query,"barrel arc"):return false
			continue
		query.shape=shape.shape;query.transform=proposed*shape.transform;query.motion=Vector3.ZERO
		if not _fitting_probe_clear(space,query,"barrel endpoint"):return false
		query.transform=pose*shape.transform;query.motion=proposed.origin-pose.origin
		if not _fitting_sweep_clear(space,query,"barrel translation"):return false
	return true

func _fitting_sweep_clear(space: PhysicsDirectSpaceState3D,query: PhysicsShapeQueryParameters3D,stage: String) -> bool:
	var result: PackedFloat32Array=space.cast_motion(query)
	if result.size()==2 and result[0]>=1.:return true
	if cast_observer.is_valid():cast_observer.call(query,_fitting_candidates,stage,result)
	last_fitting_blocker=stage+": fractions="+str(result)
	if profile_motion and result.size()==2:
		var original: Transform3D=query.transform;var motion: Vector3=query.motion
		query.transform=original.translated(motion*result[1]);query.motion=Vector3.ZERO
		var hits: Array[Dictionary]=space.intersect_shape(query,1)
		if not hits.is_empty():
			var collider: Object=hits[0].get("collider")
			last_fitting_blocker+=" "+(str(collider.get_path()) if collider is Node else str(collider))
		query.transform=original;query.motion=motion
	return false

func _append_carried_exclusions(excluded: Array[RID]) -> void:
	# Manual fitting queries must share the body's authoritative exceptions:
	# the carrier and any unlocked leaf accommodated by EasyDoorMotion.
	# No wall, locked leaf or unrelated body is added here.
	if joint.loose or actor._hand!="hose":return
	for body: PhysicsBody3D in joint.body.get_collision_exceptions():
		var rid: RID=body.get_rid()
		if not excluded.has(rid):excluded.append(rid)

func _refresh_carry_contacts() -> void:
	if not contact.ready:return
	var excluded: Array[RID]=_contact_exclusions.duplicate()
	_append_carried_exclusions(excluded)
	if excluded!=contact.exclusions:contact.set_exclusions(excluded)

func _fitting_probe_clear(space: PhysicsDirectSpaceState3D,query: PhysicsShapeQueryParameters3D,stage: String) -> bool:
	var hits: Array[Dictionary]=space.intersect_shape(query,1)
	if hits.is_empty():return true
	var collider: Object=hits[0].get("collider")
	last_fitting_blocker=stage+": "+(str(collider.get_path()) if collider is Node else str(collider))
	return false

func _receiving_stock_clear(receiver: Transform3D) -> bool:
	var before: Transform3D=actor.global_transform*joint.receiver
	var after: Transform3D=actor.global_transform*receiver
	var excluded: Array[RID]=[actor._bodies.lever.get_rid(),joint.physical_nut.get_rid()]
	_append_carried_exclusions(excluded)
	if not joint.loose:excluded.append(joint.body.get_rid())
	for part: Node3D in [joint.seat,joint.nut]:
		for body: CollisionObject3D in part.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	var space:=get_world_3d().direct_space_state
	var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=1;query.exclude=excluded
	var bounds:=AABB();var first:=true;var radius:=0.
	var spin:=Transform3D(Basis(Vector3.UP,joint.angle+joint.spin),Vector3.ZERO)
	for row: Dictionary in _receiving_stock:
		var local: AABB=(spin*row.bounds) if row.nut else row.bounds
		radius=maxf(radius,local.position.abs().max(local.end.abs()).length())
		var swept: AABB=(before*local).merge(after*local)
		bounds=swept if first else bounds.merge(swept);first=false
	if first:return false
	var angle: float=before.basis.get_rotation_quaternion().angle_to(after.basis.get_rotation_quaternion())
	bounds=bounds.grow(radius*(1.-cos(angle*.5))+.0001)
	_nozzle_box.size=bounds.size;query.shape=_nozzle_box;query.margin=0.;query.transform=Transform3D(Basis.IDENTITY,bounds.get_center())
	if space.intersect_shape(query,1).is_empty():return true
	var steps: int=maxi(1,ceili(angle/.04))
	if steps>64:return false
	query.margin=2.*radius*sin(angle/(4.*steps))+.00002
	for row: Dictionary in _receiving_stock:
		query.shape=row.shape
		var local: Transform3D=spin if row.nut else Transform3D.IDENTITY
		for step in steps:
			var fraction: float=float(step)/steps
			var rotation:=Basis(before.basis.get_rotation_quaternion().slerp(after.basis.get_rotation_quaternion(),(float(step)+.5)/steps))
			query.transform=Transform3D(rotation,before.origin.lerp(after.origin,fraction))*local;query.motion=Vector3.ZERO
			if not _fitting_probe_clear(space,query,"receiver rotation"):return false
			query.motion=(after.origin-before.origin)/steps
			if not _fitting_sweep_clear(space,query,"receiver arc"):return false
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
		if not rig.apply_points(_placement,water.pressure if visual_follow_enabled else 1.):error="unracked native skin unavailable";return
		rig.strand.points=_placement.duplicate();deployed=true;actor.hose_racked=false
		for node: Node3D in _stored:
			node.visible=false;node.set_process(false)
			for body: CollisionObject3D in node.find_children("*","CollisionObject3D",true,false):
				_stock_layers[body]=body.collision_layer;body.collision_layer=0
		model.visible=true
	joint.receiver=proposed;joint.sync();extraction=value;error=""

func _move(value: Vector3) -> void:
	if actor._hand!="hose" or not deployed or not value.is_finite():return
	if visual_follow_enabled:
		var wanted: Transform3D=actor.global_transform*joint.receiver
		wanted.origin=model.to_global(value);_visual_receiver(wanted);return
	_refresh_cover_passage()
	_refresh_carry_contacts()
	tether.collect_profile=profile_motion
	var started: int=Time.get_ticks_usec() if profile_motion else 0
	_last_fitting_usec=0;_last_broad_queries=contact.broad_queries;_last_shell_queries=contact.shell_queries
	var prepared: bool=tether.prepare_endpoint(value)
	_last_prepare_usec=Time.get_ticks_usec()-started if profile_motion else 0
	if not prepared:
		error=tether.error;set_process(tether.pending);_record_motion_profile(started);return
	_commit_motion()
	set_process(tether.pending)
	_record_motion_profile(started)

func _record_motion_profile(started: int) -> void:
	if not profile_motion:return
	last_motion_profile={"total_usec":Time.get_ticks_usec()-started,"prepare_usec":_last_prepare_usec,"fitting_usec":_last_fitting_usec,"tether":tether.profile_usec.duplicate(),"broad_queries":contact.broad_queries-_last_broad_queries,"shell_queries":contact.shell_queries-_last_shell_queries,"responses":tether.responses,"native_iterations":tether.kernel.coupled.iterations,"native_qp_iterations":tether.kernel.coupled.qp_iterations,"local_enabled":local_follow_enabled,"local_join":_local_follow.last_join if local_follow_enabled else -1,"local_usec":_local_follow.last_usec if local_follow_enabled else 0}
	last_motion_profile.physics_frame=Engine.get_physics_frames();last_motion_profile.process_frame=Engine.get_process_frames()
	motion_profile_records.append(last_motion_profile)
	if motion_profile_records.size()>512:motion_profile_records.pop_front()

func _process(_delta: float) -> void:
	if actor._hand!="hose" or not deployed:tether.cancel_motion();set_process(false);return
	_refresh_cover_passage();_refresh_carry_contacts()
	if tether.pending and tether.resume_prepare():_commit_motion()
	set_process(tether.pending)

func _commit_motion() -> void:
	if not tether.has_prepared_endpoint():return
	var points: PackedVector3Array=tether.prepared_endpoint_points()
	if not _physical_bends_clear(points):tether.cancel_motion();error="round hose physical bend bound";return
	var receiver: Transform3D=model.transform*rig.model_frames(points)[0]*_receiver_from_tip
	var started: int=Time.get_ticks_usec() if profile_motion else 0
	var clear: bool=_nozzle_clear(receiver)
	_last_fitting_usec=Time.get_ticks_usec()-started if profile_motion else 0
	if not clear:tether.cancel_motion();error="nozzle obstructed";return
	if not tether.commit_endpoint():error=tether.error;return
	joint.receiver=receiver;joint.sync();error=""

func _release() -> void:
	_clear_cover_passage();_clear_auxiliary_contacts();_carrier=null
	if contact.ready:contact.set_exclusions(_contact_exclusions)
	tether.cancel_motion();set_process(false);actor._release()
