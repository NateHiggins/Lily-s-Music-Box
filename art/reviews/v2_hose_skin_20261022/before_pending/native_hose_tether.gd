extends RefCounted
## Uninstalled held-end owner. One authoritative native swept-shell response
## gates each accepted pose. No maintenance, input, case or save authority.
const MAX_MOVE_M:=.08
const SUBSTEP_M:=.008
const MAX_RESPONSES:=4
var rig: RefCounted
var contact: RefCounted
var kernel:=preload("res://scripts/props/hose_mass_constraints.gd").new()
var error:=""
var last_ms:=0.
var responses:=0
var limited:=false
var blocked:=false
var keep_necks:=true
var _neck_offsets:=PackedVector3Array()
var _prepared_before:=PackedVector3Array()
var _prepared_points:=PackedVector3Array()
var _prepared_world:=Transform3D.IDENTITY
var _prepared_frame: int=-1
func cancel_endpoint() -> void:
	_prepared_before=PackedVector3Array();_prepared_points=PackedVector3Array();_prepared_frame=-1
func has_prepared_endpoint() -> bool:return not _prepared_points.is_empty()

func configure(owner_rig: RefCounted,owner_contact: RefCounted) -> bool:
	if rig!=null or owner_rig==null or not owner_rig.configured or owner_contact==null or not owner_contact.ready or owner_contact.rig!=owner_rig:return false
	var radii: PackedFloat64Array=preload("res://scripts/props/native_hose_bend_limits.gd").for_contact(owner_contact)
	if radii.size()!=owner_rig.rest.size():return false
	if not kernel.configure(owner_rig.strand.lengths,owner_rig.rest,radii) or kernel.coupled.backend_name!="native":return false
	rig=owner_rig;contact=owner_contact
	_neck_offsets=PackedVector3Array([rig.strand.points[1]-rig.strand.points[0],rig.strand.points[2]-rig.strand.points[0]])
	return true
func _merge(planes: Dictionary,plane: Dictionary) -> void:
	var ring: int=plane.ring
	if not planes.has(ring):planes[ring]=[]
	for old: Dictionary in planes[ring]:
		if (old.normal-plane.normal).length_squared()<1e-14:
			old.offset=maxf(old.offset,plane.offset);return
	planes[ring].append({"normal":plane.normal,"offset":plane.offset})
func _trial(before: PackedVector3Array,goal: Vector3) -> PackedVector3Array:
	var pins: Dictionary={0:goal}
	if keep_necks:
		pins[1]=goal+_neck_offsets[0]
		pins[2]=goal+_neck_offsets[1]
		pins[before.size()-2]=before[before.size()-2]
		pins[before.size()-3]=before[before.size()-3]
	var planes: Dictionary={}
	for iteration in MAX_RESPONSES:
		var proposed: PackedVector3Array=kernel.follow(before,rig.strand.anchor,planes,pins)
		if proposed.is_empty():error=kernel.error;return PackedVector3Array()
		if not rig.strand._valid_positions(proposed):error="held material residual";return PackedVector3Array()
		var result: Dictionary=contact.motion_constraints(before,proposed,4096);responses+=1
		if not result.valid or result.truncated:error="invalid held native response: "+str(result.error);return PackedVector3Array()
		if result.planes.is_empty():
			if not bool(result.get("sweep_clear",false)) and contact.veto(before,proposed):error="held native sweep blocked";return PackedVector3Array()
			return proposed
		for plane: Dictionary in result.planes:
			if pins.has(plane.ring) and plane.normal.dot(pins[plane.ring])<plane.offset-.000001:
				error="held fitting or fixed outlet obstructed";return PackedVector3Array()
			_merge(planes,plane)
	error="bounded held contact response ceiling"
	return PackedVector3Array()
func prepare_endpoint(goal: Vector3) -> bool:
	cancel_endpoint()
	var started: int=Time.get_ticks_usec();responses=0;limited=false;blocked=false;error=""
	if rig==null or not goal.is_finite():error="invalid held endpoint";blocked=true;last_ms=(Time.get_ticks_usec()-started)/1000.;return false
	var before: PackedVector3Array=rig.strand.points.duplicate()
	var offset: Vector3=goal-rig.strand.anchor
	if offset.length()>rig.strand.total_length:
		goal=rig.strand.anchor+offset.normalized()*rig.strand.total_length;limited=true
	var travel: Vector3=goal-before[0]
	if travel.length()>MAX_MOVE_M:goal=before[0]+travel.normalized()*MAX_MOVE_M
	if goal==before[0]:
		_prepare(before,before);last_ms=(Time.get_ticks_usec()-started)/1000.;return true
	# Two bounded attempts permit partial approach to an obstruction without
	# committing half a solve or buying progress by discarding collision.
	for fraction: float in [1.,.5]:
		var end: Vector3=before[0].lerp(goal,fraction)
		var steps: int=maxi(1,ceili(before[0].distance_to(end)/SUBSTEP_M))
		var working: PackedVector3Array=before
		var partial:=false
		for step in range(1,steps+1):
			var proposed: PackedVector3Array=_trial(working,before[0].lerp(end,float(step)/steps))
			if proposed.is_empty():partial=true;break
			working=proposed
		if working==before:continue
		_prepare(before,working);blocked=partial or fraction<1.;error="";last_ms=(Time.get_ticks_usec()-started)/1000.;return true
	blocked=true;last_ms=(Time.get_ticks_usec()-started)/1000.
	return false

func _prepare(before: PackedVector3Array,proposed: PackedVector3Array) -> void:
	_prepared_before=before.duplicate();_prepared_points=proposed.duplicate()
	_prepared_world=rig.model.global_transform;_prepared_frame=Engine.get_physics_frames()
func commit_endpoint() -> bool:
	var started: int=Time.get_ticks_usec()
	if not has_prepared_endpoint():error="no prepared held endpoint";return false
	# A fitting owner can first check its own native sweep, then commit this
	# cloth proposal synchronously. An awaited or externally changed proposal
	# is rejected; recheck world contact even inside the same physics frame.
	if Engine.get_physics_frames()!=_prepared_frame or rig.strand.points!=_prepared_before or rig.model.global_transform!=_prepared_world:
		cancel_endpoint();blocked=true;error="stale held endpoint proposal";return false
	var response: Dictionary=contact.motion_constraints(_prepared_before,_prepared_points,4096)
	responses+=1
	if not response.valid or response.truncated or not response.planes.is_empty() or (not bool(response.get("sweep_clear",false)) and contact.veto(_prepared_before,_prepared_points)):
		cancel_endpoint();blocked=true;error="prepared held endpoint became obstructed";last_ms+=(Time.get_ticks_usec()-started)/1000.;return false
	var points: PackedVector3Array=_prepared_points
	cancel_endpoint()
	if not rig.apply_points(points):error="held skin rejected pose";blocked=true;return false
	rig.strand.points=points;error="";last_ms+=(Time.get_ticks_usec()-started)/1000.
	return true
func move_endpoint(goal: Vector3) -> bool:
	return prepare_endpoint(goal) and commit_endpoint()
