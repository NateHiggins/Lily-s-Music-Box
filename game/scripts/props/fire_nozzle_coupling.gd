extends Node3D
const FITTING_LAYER:=1<<18
const CURSOR_LAYER:=1<<19
## Actual screw travel followed by free, swept carrying of the original nozzle.
## Parent actor retains maintenance, hand ownership and household persistence.
class CursorBody extends AnimatableBody3D:
	var provider: Callable
	func manipulation_target(hit: Dictionary) -> Dictionary:return provider.call(hit)
class LooseBody extends RigidBody3D:
	var provider: Callable
	func manipulation_target(hit: Dictionary) -> Dictionary:return provider.call(hit)
class RadialEnvelope extends RefCounted:
	var minimum:=INF
	var peak:=-INF
	var maximum:=-INF
	var segments: Array[Vector4]=[]
	func radius_at(limit: float) -> float:
		if limit<minimum:return -INF
		if limit>=peak:return maximum
		for segment: Vector4 in segments:
			if limit<=segment.x:return segment.z+(limit-segment.y)*segment.w
		return maximum
class QueryPart extends RefCounted:
	var shape: ConvexPolygonShape3D
	var transform:=Transform3D.IDENTITY
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
var _speed:=0.
var _support: WeakRef
var _support_pose:=Transform3D.IDENTITY
var _support_geometry:=Transform3D.IDENTITY
var _support_frame: int=-1
var _support_confirmed:=false
var _last_contact: Node3D
var _lever_shapes: Dictionary={}
var _lever_rows: Array[Dictionary]=[]
var _restore_support:=false
var last_sweep_ms:=0.
var last_turn_ms:=0.
var _axial_min:=INF
var _core_axial_min:=INF
var _spigot_shapes: Array[CollisionShape3D]=[]
var _profile_motion:=OS.get_environment("ORISON_NOZZLE_CONTACT_PROFILE")=="1"
var _receiver_reason:=""
var _radial_profiles: Dictionary={}
var _profile_frames: Dictionary={}
var _shape_bounds: Dictionary={}
var _query_parts: Array[QueryPart]=[]
var _body_bounds:=AABB()
var _bounds_stamp:=Transform3D.IDENTITY
var _bounds_ready:=false
var _world_box:=BoxShape3D.new()
var receiver_queries:=0
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
	var fixed:=StaticBody3D.new();fixed.name="NativeNozzleSeatCollision";fixed.collision_layer=1|FITTING_LAYER;seat.add_child(fixed)
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
	body.transform=thread_pose(angle);_apply_visuals()
	for draw: MeshInstance3D in actor._play_pipe.find_children("*","MeshInstance3D",true,false):
		if draw==seat or draw.mesh==null:continue
		var frame: Transform3D=body.global_transform.affine_inverse()*draw.global_transform
		for corner in range(8):
			var axial: float=(frame*draw.mesh.get_aabb().get_endpoint(corner)).y
			_axial_min=minf(_axial_min,axial)
			if draw!=spigot:_core_axial_min=minf(_core_axial_min,axial)
		if draw.is_ancestor_of(actor._lever):continue
		if actor._lever.is_ancestor_of(draw):
			for convex: ConvexPolygonShape3D in _draw_shapes(draw):
				collision=CollisionShape3D.new();collision.shape=convex;collision.transform=frame
				_lever_shapes[body.get_child_count()]=true;body.add_child(collision);_lever_rows.append({"shape":collision,"draw":draw})
		else:
			for convex: ConvexPolygonShape3D in _draw_shapes(draw):
				collision=CollisionShape3D.new();collision.shape=convex;collision.transform=frame;body.add_child(collision)
				if draw==spigot:_spigot_shapes.append(collision)
	# Prepare immutable bounds while installing, avoiding a first-grab hitch.
	for leaf: CollisionShape3D in body.get_children():_collision_profile(leaf)
	for leaf: CollisionShape3D in _spigot_shapes:
		var part:=QueryPart.new();part.shape=leaf.shape;part.transform=leaf.transform;_query_parts.append(part);_collision_profile(part)
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
	actor._play_pipe.global_transform=body.global_transform
	seat.global_transform=actor.global_transform*receiver
	nut.transform=receiver*Transform3D(Basis(Vector3.UP,angle+spin),Vector3.ZERO)
	for row: Dictionary in _lever_rows:row.shape.global_transform=row.draw.global_transform
func sync() -> void:
	if body==null:return
	if actor.nozzle_coupled!=_observed:
		clocking=fposmod(spin,TAU);spin=clocking
		angle=0. if actor.nozzle_coupled else stock.maximum_angle();loose=not actor.nozzle_coupled;body.transform=thread_pose(angle);_support=null;_speed=0.
	if not loose:body.transform=thread_pose(angle)
	_observed=not loose and absf(angle)<.0001;actor.nozzle_coupled=_observed
	_apply_visuals()
func _grip(kind: String,part: Node3D) -> Dictionary:
	return {"owner":actor,"part":part,"frame":actor,"kind":kind,
		"begin":func():
			if not actor._claim("nozzle_body"):return false
			_support=null;_speed=0.;return true,
		"owns":func():return actor._hand=="nozzle_body","end":_release_body,
		"read":func():return body.position,"write":func(value: Vector3):
			if actor._hand=="nozzle_body":_carry(value)}
func body_grip() -> Dictionary:
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
			if not loose and angle>=stock.maximum_angle()-.000001:loose=true;_speed=0.
			sync();actor._release()}
func _turn_loose(value: float) -> void:
	var delta: float=value-spin
	# Free rotation still operates the actual captured nut. A tightening
	# gesture can pick up the helix only after the spigot enters its mouth.
	var local: Vector3=receiver.affine_inverse()*body.position
	var travel: float=local.y-float(stock.data.dimensions.nozzle_base_y_m)
	var pitch: float=stock.data.dimensions.pitch_m
	var entered: bool=travel>=0. and travel<float(stock.data.dimensions.withdrawal_m)-.0001
	var aligned: bool=Vector2(local.x,local.z).length()<=float(stock.data.dimensions.radial_clearance_m)
	if delta<0. and entered and aligned:
		var pickup: float=TAU*travel/pitch
		# Female angle = maximum+spin; male phase = body clocking. The
		# phase crossing, rather than a release click, starts the native helix.
		var until_match: float=fposmod(stock.maximum_angle()+spin-clocking-pickup,TAU)
		if TAU-until_match<.000001:until_match=0.
		if until_match<=-delta:
			var wanted: Transform3D=actor.global_transform*thread_pose(pickup)
			var query:=PhysicsTestMotionParameters3D.new();query.from=body.global_transform;query.motion=wanted.origin-body.global_position;query.margin=.00002
			var exclusions: Array[RID]=[body.get_rid(),actor._bodies.lever.get_rid(),(seat.get_child(0) as CollisionObject3D).get_rid(),(nut.get_child(0) as CollisionObject3D).get_rid(),physical_nut.get_rid()]
			query.exclude_bodies=exclusions
			# The native lead permits this measured radial clearance. Other
			# world stock must still permit the small centring movement.
			if _world_motion_clear(body.global_transform,query.motion,exclusions) or not PhysicsServer3D.body_test_motion(body.get_rid(),query):
				angle=pickup;spin=clocking;loose=false;_speed=0.;_support=null
				body.global_transform=wanted;sync();turn(pickup+delta+until_match)
				return
	spin=fposmod(value,TAU);_apply_visuals()
func turn(value: float) -> void:
	if loose or not is_finite(value):return
	var wanted: float=clampf(value,0.,stock.maximum_angle())
	var pose: Transform3D=actor.global_transform*thread_pose(wanted)
	var query:=PhysicsTestMotionParameters3D.new();query.from=body.global_transform;query.motion=pose.origin-body.global_position;query.margin=.00002
	query.exclude_bodies=[(seat.get_child(0) as CollisionObject3D).get_rid(),(nut.get_child(0) as CollisionObject3D).get_rid(),physical_nut.get_rid(),actor._bodies.lever.get_rid()]
	var started: int=Time.get_ticks_usec()
	var blocked: bool=not _world_motion_clear(query.from,query.motion,query.exclude_bodies) and PhysicsServer3D.body_test_motion(body.get_rid(),query)
	last_turn_ms=(Time.get_ticks_usec()-started)/1000.
	if blocked:return
	angle=wanted;_observed=absf(angle)<.0001;actor.nozzle_coupled=_observed;sync()
func _carry(value: Vector3) -> void:
	if not loose or not value.is_finite():return
	var started: int=Time.get_ticks_usec()
	var pose: Transform3D=body.global_transform
	_apply_visuals()
	var remaining: Vector3=actor.global_basis*(value-body.position)
	# Entering the narrow pilot changes the free carry to its real axial
	# guide during mouse travel. Release never performs this centring.
	if actor._hand=="nozzle_body":
		var start: Vector3=receiver.affine_inverse()*body.position
		var proposed: Vector3=receiver.affine_inverse()*value
		var entry: float=stock.pilot_entry
		var lead: float=stock.data.dimensions.radial_clearance_m
		if (_on_pilot() or (start.y>=stock.pilot_min-lead and Vector2(start.x,start.z).length()<=entry and Vector2(proposed.x,proposed.z).length()<=entry)) and proposed.y<stock.pilot_max:
			var centre: Vector3=(actor.global_transform*receiver)*Vector3(0,maxf(start.y,stock.pilot_min),0)
			var exclusions: Array[RID]=[body.get_rid(),actor._bodies.lever.get_rid(),(seat.get_child(0) as CollisionObject3D).get_rid(),(nut.get_child(0) as CollisionObject3D).get_rid(),physical_nut.get_rid()]
			var query:=PhysicsTestMotionParameters3D.new();query.from=pose;query.motion=centre-pose.origin;query.margin=.00002;query.exclude_bodies=exclusions
			if _world_motion_clear(pose,query.motion,exclusions) or not PhysicsServer3D.body_test_motion(body.get_rid(),query):
				pose.origin=centre
				remaining=(actor.global_transform*receiver)*Vector3(0,maxf(proposed.y,stock.pilot_min),0)-pose.origin
	receiver_queries=0
	_last_contact=null
	for step in range(4):
		if remaining.length_squared()<1e-12:break
		var query:=PhysicsTestMotionParameters3D.new();query.from=pose;query.motion=remaining;query.margin=.00002
		var exclusions: Array[RID]=[actor._bodies.lever.get_rid(),(nut.get_child(0) as CollisionObject3D).get_rid()]
		var fitting: Dictionary={}
		var pilot: bool=_pilot_sweep_clear(pose,remaining)
		if not pilot and not _outside_receiver(pose,remaining):fitting=_sweep_spigot(pose,remaining)
		if pilot or _outside_receiver(pose,remaining) or not fitting.is_empty():
			exclusions.append((seat.get_child(0) as CollisionObject3D).get_rid())
			exclusions.append(physical_nut.get_rid())
		if not fitting.is_empty():query.motion=fitting.travel
		query.exclude_bodies=exclusions
		var result:=PhysicsTestMotionResult3D.new()
		if _profile_motion:print("NOZZLE CARRY STEP: ",step," fast=",not fitting.is_empty()," reason=",_receiver_reason," fraction=",fitting.get("fraction",1.))
		var remainder: Vector3
		var normal: Vector3
		var blocked: bool=false
		if not _world_motion_clear(pose,query.motion,exclusions):blocked=_sweep_world(query,result)
		if _profile_motion:print("NOZZLE WORLD SWEEP: ",step," blocked=",blocked," travel=",result.get_travel()," requested=",query.motion," collider=",result.get_collider().get_path() if blocked and result.get_collider()!=null else "none")
		if not blocked:
			pose.origin+=query.motion
			if fitting.is_empty() or fitting.fraction>=1.:break
			_last_contact=fitting.collider;normal=fitting.normal;remainder=remaining-query.motion
		else:
			_last_contact=result.get_collider() as Node3D;pose.origin+=result.get_travel();remainder=remaining-result.get_travel();normal=result.get_collision_normal()
		remaining=remainder.slide(normal)
		# A tangential normal that changes no remainder must not repeat the
		# same stalled contact query four times (thread-root edge contacts).
		if remainder.length()-remaining.length()<.000001:break
	body.global_transform=pose;_apply_visuals()
	last_sweep_ms=(Time.get_ticks_usec()-started)/1000.
func _above_static(collider: Object,pose: Transform3D,motion: Vector3) -> bool:
	# A translation whose whole convex stock is above a box's highest plane
	# and never descends cannot hit that box. Backend recovery skins can still
	# report that separating floor contact; do not let it trap a lifted part.
	# No negative gap tolerance, dynamic-body exemption or receiver bypass.
	if not collider is StaticBody3D or motion.y<0.:return false
	var ceiling: float=-INF
	for child: Node in collider.get_children():
		if not child is CollisionShape3D or child.disabled:continue
		if not child.shape is BoxShape3D:return false
		var half: Vector3=child.shape.size*.5
		var bounds:=AABB(-half,half*2.)
		for corner in 8:ceiling=maxf(ceiling,(child.global_transform*bounds.get_endpoint(corner)).y)
	if not is_finite(ceiling):return false
	for shape: CollisionShape3D in body.get_children():
		if shape.disabled:continue
		if not shape.shape is ConvexPolygonShape3D:return false
		var frame: Transform3D=pose*shape.transform
		for vertex: Vector3 in shape.shape.points:
			if (frame*vertex).y-float(shape.shape.margin)<ceiling:return false
	return true
func _sweep_world(query: PhysicsTestMotionParameters3D,result: PhysicsTestMotionResult3D) -> bool:
	# Requery after each geometrically proven separating support, so another
	# obstacle in the same sweep retains its normal collision authority.
	for attempt in 8:
		if not PhysicsServer3D.body_test_motion(body.get_rid(),query,result):return false
		var collider: Object=result.get_collider()
		if not _above_static(collider,query.from,query.motion):return true
		var rid: RID=collider.get_rid()
		if query.exclude_bodies.has(rid):return true
		var exclusions: Array[RID]=query.exclude_bodies;exclusions.append(rid);query.exclude_bodies=exclusions
	return true
func _on_pilot() -> bool:
	var local: Vector3=receiver.affine_inverse()*body.position
	return Vector2(local.x,local.z).length()<.000002 and local.y>=stock.pilot_min-.000002 and local.y<stock.pilot_max-.0001
func _pilot_sweep_clear(pose: Transform3D,motion: Vector3) -> bool:
	if not _outside_receiver(pose,motion,_core_axial_min):return false
	var fixed_inverse: Transform3D=(actor.global_transform*receiver).affine_inverse()
	var a: Vector3=fixed_inverse*pose.origin;var b: Vector3=fixed_inverse*(pose.origin+motion)
	return minf(a.y,b.y)>=stock.pilot_min-.000002 and maxf(Vector2(a.x,a.z).length(),Vector2(b.x,b.z).length())<stock.pilot_clearance*.5
func _collision_profile(shape: Object) -> RadialEnvelope:
	if _profile_frames.get(shape)!=shape.transform:
		var points:=PackedVector2Array();var bounds:=AABB();var first:=true
		for vertex: Vector3 in shape.shape.points:
			if first:bounds=AABB(vertex,Vector3.ZERO);first=false
			else:bounds=bounds.expand(vertex)
			var at: Vector3=shape.transform*vertex
			points.append(Vector2(at.y,Vector2(at.x,at.z).length()))
		var outline: Array[Vector2]=[]
		for point: Vector2 in Geometry2D.convex_hull(points):outline.append(point)
		outline.sort_custom(func(a: Vector2,b: Vector2):return a.x<b.x or (a.x==b.x and a.y>b.y))
		var chain: Array[Vector2]=[]
		for point: Vector2 in outline:
			if not chain.is_empty() and point.x==chain[-1].x:continue
			while chain.size()>1 and (chain[-1]-chain[-2]).cross(point-chain[-1])>=0.:chain.pop_back()
			chain.append(point)
		var envelope:=RadialEnvelope.new();envelope.minimum=chain[0].x
		for point: Vector2 in chain:
			if point.y>envelope.maximum:envelope.maximum=point.y;envelope.peak=point.x
		for i in range(1,chain.size()):
			var a: Vector2=chain[i-1];var b: Vector2=chain[i]
			if a.x>=envelope.peak:break
			envelope.segments.append(Vector4(b.x,a.x,a.y,(b.y-a.y)/(b.x-a.x)))
		_radial_profiles[shape]=envelope;_shape_bounds[shape]=bounds;_profile_frames[shape]=shape.transform
	return _radial_profiles[shape]
func _receiver_overlap(pose: Transform3D,shapes: Array,profiles: Array[RadialEnvelope],query: PhysicsShapeQueryParameters3D,fixed_inverse: Transform3D) -> Dictionary:
	var relative: Vector3=fixed_inverse*pose.origin
	var skin: float=.00004+4.*1.1920928955078125e-7*maxf(1.,pose.origin.length())
	var radial: float=Vector2(relative.x,relative.z).length()+skin
	var start: float=stock.clearance_start+skin-relative.y
	var limit: float=stock.clearance_end-relative.y+skin
	for i in shapes.size():
		var shape: Object=shapes[i];var profile: RadialEnvelope=profiles[i]
		if profile.minimum>start and profile.radius_at(limit)+radial<stock.clearance_radius:continue
		query.shape=shape.shape;query.transform=pose*shape.transform
		receiver_queries+=1
		var hit: Array[Dictionary]=actor.get_world_3d().direct_space_state.intersect_shape(query,1)
		if not hit.is_empty():return {"shape":shape,"collider":hit[0].collider}
	return {}
func _world_motion_clear(pose: Transform3D,motion: Vector3,exclude: Array[RID]) -> bool:
	if not _bounds_ready or _bounds_stamp!=actor._lever.transform:
		var first:=true
		for shape: CollisionShape3D in body.get_children():
			_collision_profile(shape)
			var bounds: AABB=shape.transform*_shape_bounds[shape]
			_body_bounds=bounds if first else _body_bounds.merge(bounds);first=false
		_bounds_stamp=actor._lever.transform
		_bounds_ready=true
	var bounds: AABB=pose*_body_bounds
	bounds=bounds.merge(AABB(bounds.position+motion,bounds.size)).grow(.0001)
	_world_box.size=bounds.size
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=_world_box;query.transform=Transform3D(Basis.IDENTITY,bounds.get_center());query.margin=0.;query.collision_mask=1
	var exclusions: Array[RID]=exclude.duplicate();exclusions.append(body.get_rid());query.exclude=exclusions
	return actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func _sweep_spigot(pose: Transform3D,motion: Vector3) -> Dictionary:
	# Verify actual receiver overlaps in <=100um increments, refining the
	# first contact. Do not use the late backend casts in this fine cavity.
	var fixed_inverse: Transform3D=(actor.global_transform*receiver).affine_inverse()
	if pose.basis.y.dot((actor.global_transform*receiver).basis.y)<.999999:return {}
	var shapes: Array=_query_parts if _outside_receiver(pose,motion,_core_axial_min) else body.get_children()
	var profiles: Array[RadialEnvelope]=[]
	var moving:=AABB();var first:=true
	for shape: Object in shapes:
		profiles.append(_collision_profile(shape))
		var bounds: AABB=Transform3D(fixed_inverse.basis*pose.basis,Vector3.ZERO)*shape.transform*_shape_bounds[shape]
		moving=bounds if first else moving.merge(bounds);first=false
	var receiver_box: AABB=(fixed_inverse*physical_nut.global_transform)*stock.physical_bounds
	receiver_box=receiver_box.merge((fixed_inverse*seat.global_transform)*seat.mesh.get_aabb()).grow(.00005)
	var low: Vector3=receiver_box.position-moving.end;var high: Vector3=receiver_box.end-moving.position
	var at: Vector3=fixed_inverse*pose.origin;var velocity: Vector3=fixed_inverse.basis*motion
	var entry:=0.;var leave:=1.
	var clear: Dictionary={"fraction":1.,"normal":Vector3.ZERO,"collider":null,"travel":motion}
	for axis in 3:
		if absf(velocity[axis])<1e-12:
			if at[axis]<low[axis] or at[axis]>high[axis]:return clear
		else:
			var a: float=(low[axis]-at[axis])/velocity[axis];var b: float=(high[axis]-at[axis])/velocity[axis]
			entry=maxf(entry,minf(a,b));leave=minf(leave,maxf(a,b))
			if entry>leave:return clear
	var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=FITTING_LAYER;query.margin=.00002
	if not _receiver_overlap(pose,shapes,profiles,query,fixed_inverse).is_empty():_receiver_reason="initial overlap";return {}
	var steps: int=maxi(1,ceili(motion.length()*(leave-entry)/.0001))
	var previous: float=entry
	for step in range(1,steps+1):
		var fraction: float=lerpf(entry,leave,float(step)/steps)
		var sample: Transform3D=pose;sample.origin+=motion*fraction
		var hit: Dictionary=_receiver_overlap(sample,shapes,profiles,query,fixed_inverse)
		if hit.is_empty():previous=fraction;continue
		var lower: float=previous;var upper: float=fraction
		for refine in 1:
			var middle: float=(lower+upper)*.5;sample.origin=pose.origin+motion*middle
			var candidate: Dictionary=_receiver_overlap(sample,shapes,profiles,query,fixed_inverse)
			if candidate.is_empty():lower=middle
			else:upper=middle;hit=candidate
		sample.origin=pose.origin+motion*upper;query.shape=hit.shape.shape;query.transform=sample*hit.shape.transform
		var contact: Dictionary=actor.get_world_3d().direct_space_state.get_rest_info(query)
		if contact.is_empty():_receiver_reason="missing contact info";return {}
		_receiver_reason="bounded overlap hit"
		var safe: float=maxf(0.,lower-.000002/maxf(motion.length(),.000002))
		return {"fraction":safe,"normal":contact.normal,"collider":hit.collider,"travel":motion*safe}
	_receiver_reason="bounded overlap clear"
	return clear
func _outside_receiver(pose: Transform3D,motion: Vector3,minimum: float=NAN) -> bool:
	# The entire swept nozzle lies beyond the fixed receiving stock's end
	# plane. Avoid GJK recovery against a mathematically disjoint tangent cap.
	# The bound is four float32 ULPs at the actual world origin, not a relaxed
	# fitting tolerance; inward motion beyond it still tests the real receiver.
	var fixed: Transform3D=actor.global_transform*receiver
	if pose.basis.y.dot(fixed.basis.y)<.999999:return false
	var scale: float=maxf(1.,maxf(pose.origin.length(),fixed.origin.length()))
	var precision: float=4.*1.1920928955078125e-7*scale+.0000001
	if is_nan(minimum):minimum=_axial_min
	var start: float=(pose.origin-fixed.origin).dot(fixed.basis.y)+minimum
	var end: float=(pose.origin+motion-fixed.origin).dot(fixed.basis.y)+minimum
	return minf(start,end)>=nut.mesh.get_aabb().end.y-precision
func _release_body() -> void:
	_speed=0.;sync();actor._release()
func _physics_process(delta: float) -> void:
	if body==null:return
	sync()
	if not loose or actor._hand=="nozzle_body":return
	# The inserted pilot is an axial mechanical guide, not a free-falling
	# rigid body. It remains withdrawable and is not yet a sealed thread.
	if _on_pilot():_speed=0.;return
	if _support!=null and _support_geometry!=actor._lever.transform:
		_support=null;_restore_support=true
	if _restore_support:_restore_support=false;_adopt_support()
	if _support!=null:
		var support: Node3D=_support.get_ref()
		if support!=null and support.global_transform.is_equal_approx(_support_pose):
			if _support_confirmed or Engine.get_physics_frames()<=_support_frame:return
			# A moved StaticBody can publish its new node transform before
			# the direct-space ray sees its new broadphase position. Confirm
			# a newly cached bearing on the following physics tick.
			_support=null;_adopt_support()
			if _support!=null:_support_confirmed=true;return
		_support=null
		_support_confirmed=false
	_speed-=9.81*delta
	var before: Vector3=body.position
	_carry(before+Vector3.UP*maxf(-.04,_speed*delta))
	if is_instance_valid(_last_contact):
		# Real bearing rays establish support even if GJK recovery moved this
		# small curved stock by a few micrometres. Do not repeatedly resolve
		# an already supported pose or accept a side contact as a floor.
		_adopt_support()
		if _support!=null:_speed=0.
func _adopt_support() -> void:
	var vertices:=PackedVector3Array()
	for shape: CollisionShape3D in body.get_children():
		for point: Vector3 in shape.shape.points:vertices.append(shape.transform*point)
	var lowest: float=INF;var candidates: Array[Vector3]=[]
	for vertex: Vector3 in vertices:lowest=minf(lowest,(body.global_transform*vertex).y)
	for vertex: Vector3 in vertices:
		var point: Vector3=body.global_transform*vertex
		if point.y>lowest+.00005:continue
		var duplicate: bool=false
		for existing in candidates:
			if existing.distance_to(point)<.001:duplicate=true;break
		if not duplicate:candidates.append(point)
		if candidates.size()>=4:break
	var support: Node3D
	for point in candidates:
		var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.005,point-Vector3.UP*.005,1,[body.get_rid(),actor._bodies.lever.get_rid()])
		var hit: Dictionary=actor.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.position.distance_to(point)>.0001 or hit.normal.dot(Vector3.UP)<.99 or not hit.collider is Node3D:return
		if support!=null and support!=hit.collider:return
		support=hit.collider
	if support!=null:
		_support=weakref(support);_support_pose=support.global_transform;_speed=0.
		_support_geometry=actor._lever.transform
		_support_frame=Engine.get_physics_frames();_support_confirmed=false
func snapshot() -> Dictionary:return {"angle":angle,"spin":spin,"clocking":clocking,"loose":loose,"position":[body.position.x,body.position.y,body.position.z]}
func valid(value: Variant,made_up: bool) -> bool:
	if value is not Dictionary or value.size()!=5 or typeof(value.get("loose"))!=TYPE_BOOL:return false
	for key: String in ["spin","clocking"]:
		if typeof(value.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value[key])):return false
	if value.clocking<0. or value.clocking>=TAU or value.spin<0. or value.spin>=TAU:return false
	if typeof(value.get("angle")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value.angle)) or value.angle<0. or value.angle>stock.maximum_angle():return false
	if value.get("position") is not Array or value.position.size()!=3:return false
	for coordinate: Variant in value.position:
		if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)):return false
	var at:=Vector3(value.position[0],value.position[1],value.position[2])
	if at.length()>10000.:return false
	if value.loose and absf(float(value.angle)-stock.maximum_angle())>.000001:return false
	if not value.loose and (at.distance_to(thread_pose(float(value.angle),float(value.clocking)).origin)>.000001 or absf(float(value.spin)-float(value.clocking))>.000001):return false
	return made_up==(not value.loose and absf(float(value.angle))<.0001)
func restore(value: Dictionary) -> void:
	angle=value.angle;spin=value.spin;clocking=value.clocking;loose=value.loose;_observed=actor.nozzle_coupled;_support=null;_speed=0.;_restore_support=true
	body.transform=Transform3D(receiver.basis*Basis(Vector3.UP,clocking),Vector3(value.position[0],value.position[1],value.position[2]));sync()
func restore_legacy(made_up: bool) -> void:
	angle=0. if made_up else stock.maximum_angle();spin=0.;clocking=0.;loose=not made_up;_observed=made_up
	_support=null;_speed=0.;_restore_support=true;body.transform=thread_pose(angle);sync()
