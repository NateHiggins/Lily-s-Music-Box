extends RefCounted
## Uninstalled held-end owner. One authoritative native swept-shell response
## gates each accepted pose. No maintenance, input, case or save authority.
const MAX_MOVE_M:=.08
const SUBSTEP_M:=.008
const MAX_RESPONSES:=4
const WORK_BUDGET_USEC:=6000
var rig: RefCounted
var contact: RefCounted
var kernel:=preload("res://scripts/props/hose_mass_constraints.gd").new()
var error:=""
var last_ms:=0.
var responses:=0
var limited:=false
var blocked:=false
var pending:=false
var _requested_goal:=Vector3.ZERO
var _warm_before:=PackedVector3Array()
var _warm_seed:=PackedVector3Array()
var _warm_world:=Transform3D.IDENTITY
var keep_necks:=true
var lock_tip_direction:=true
var round_self_radius_m:=0.
var seed_factory: Callable
var collect_profile:=false
var profile_usec: Dictionary={}

var substep_m:=SUBSTEP_M
var seeded_candidates:=0
var seeded_accepts:=0
var last_seed_bend_error:=0.
var last_seed_material_valid:=false
var last_seed_points:=PackedVector3Array()
var _neck_offsets:=PackedVector3Array()
var _prepared_before:=PackedVector3Array()
var _prepared_points:=PackedVector3Array()
var _prepared_world:=Transform3D.IDENTITY
var _prepared_frame: int=-1
func _profile_add(stage: String,started: int) -> void:
	if collect_profile:profile_usec[stage]=int(profile_usec.get(stage,0))+Time.get_ticks_usec()-started
func cancel_endpoint() -> void:
	_prepared_before=PackedVector3Array();_prepared_points=PackedVector3Array();_prepared_frame=-1
func has_prepared_endpoint() -> bool:return not _prepared_points.is_empty()
func prepared_endpoint_points() -> PackedVector3Array:return _prepared_points.duplicate()

func _drop_warm() -> void:
	_warm_before=PackedVector3Array();_warm_seed=PackedVector3Array();pending=false
func cancel_motion() -> void:
	_drop_warm();cancel_endpoint()
func resume_prepare() -> bool:
	return pending and prepare_endpoint(_requested_goal)
func configure(owner_rig: RefCounted,owner_contact: RefCounted,minimum_radii:=PackedFloat64Array()) -> bool:
	if rig!=null or owner_rig==null or not owner_rig.configured or owner_contact==null or not owner_contact.ready or owner_contact.rig!=owner_rig:return false
	if not is_finite(substep_m) or substep_m<=0. or substep_m>MAX_MOVE_M:return false
	var radii: PackedFloat64Array=preload("res://scripts/props/native_hose_bend_limits.gd").for_contact(owner_contact) if minimum_radii.is_empty() else minimum_radii
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
	var initial: PackedVector3Array=before
	var has_seed:=false
	if seed_factory.is_valid():
		var stage_started: int=Time.get_ticks_usec() if collect_profile else 0
		var seeded: Variant=seed_factory.call(before,goal)
		_profile_add("seed",stage_started)
		if seeded is PackedVector3Array and seeded.size()==before.size():initial=seeded;has_seed=true
	var pins: Dictionary={0:goal}
	if keep_necks:
		if lock_tip_direction:
			pins[1]=goal+_neck_offsets[0];pins[2]=goal+_neck_offsets[1]
		else:
			var direction: Vector3=(initial[3]-goal).normalized()
			if direction.length_squared()<.99:error="collapsed rigid hose mouth";return PackedVector3Array()
			pins[1]=initial[1] if has_seed else goal+direction*_neck_offsets[0].length()
			pins[2]=initial[2] if has_seed else goal+direction*_neck_offsets[1].length()
		pins[before.size()-2]=before[before.size()-2]
		pins[before.size()-3]=before[before.size()-3]
	var planes: Dictionary={}
	var own_planes: Array=[]
	for iteration in MAX_RESPONSES:
		var continuation: bool=_warm_before==before and _warm_world==rig.model.global_transform and _warm_seed.size()==before.size()
		var seed: PackedVector3Array=_warm_seed if continuation else initial
		var solve_planes: Dictionary=planes if own_planes.is_empty() else planes.duplicate(true)
		for plane: Dictionary in own_planes:_merge(solve_planes,plane)
		var proposed:=PackedVector3Array()
		if has_seed and not continuation:
			seeded_candidates+=1
			last_seed_points=seed
			last_seed_material_valid=rig.strand._valid_positions(seed)
			last_seed_bend_error=kernel._bend_error(seed)
			var valid: bool=last_seed_material_valid and last_seed_bend_error<=kernel.bend_error_m
			for ring: int in pins:valid=valid and seed[ring]==pins[ring]
			for ring: int in solve_planes:
				for plane: Dictionary in solve_planes[ring]:valid=valid and plane.normal.dot(seed[ring])>=plane.offset-.000001
			if valid:proposed=seed;seeded_accepts+=1
		if proposed.is_empty():
			var stage_started: int=Time.get_ticks_usec() if collect_profile else 0
			proposed=kernel.follow(seed,rig.strand.anchor,solve_planes,pins,continuation)
			_profile_add("solver",stage_started)
		if proposed.is_empty():
			error=kernel.error
			if error.contains("ceiling") and kernel.coupled.last_iterate.size()==before.size():
				_warm_before=before.duplicate();_warm_seed=kernel.coupled.last_iterate.duplicate();_warm_world=rig.model.global_transform;pending=true
			else:_drop_warm()
			return PackedVector3Array()
		_drop_warm()
		if not rig.strand._valid_positions(proposed):error="held material residual";return PackedVector3Array()
		var stage_started: int=Time.get_ticks_usec() if collect_profile else 0
		var result: Dictionary=contact.motion_constraints(before,proposed,4096);responses+=1
		_profile_add("world_constraints",stage_started)
		if not result.valid or result.truncated:error="invalid held native response: "+str(result.error);return PackedVector3Array()
		if result.planes.is_empty():
			if not bool(result.get("sweep_clear",false)):
				stage_started=Time.get_ticks_usec() if collect_profile else 0
				var vetoed: bool=contact.veto(before,proposed)
				_profile_add("world_veto",stage_started)
				if vetoed:error="held native sweep blocked";return PackedVector3Array()
			if round_self_radius_m>0.:
				stage_started=Time.get_ticks_usec() if collect_profile else 0
				var own: Dictionary=kernel.coupled.round_self_constraints(before,proposed,round_self_radius_m,pins)
				_profile_add("self_constraints",stage_started)
				if not own.valid:error=str(own.get("error","invalid round self contact"));return PackedVector3Array()
				if not own.clear:
					# Self-contact normals depend on BOTH moving segments. Keep
					# world supports, but replace these local linearizations.
					own_planes=own.planes
					continue
			return proposed
		for plane: Dictionary in result.planes:
			if pins.has(plane.ring) and plane.normal.dot(pins[plane.ring])<plane.offset-.000001:
				error="held fitting or fixed outlet obstructed";return PackedVector3Array()
			_merge(planes,plane)
	error="bounded held contact response ceiling"
	return PackedVector3Array()
func prepare_endpoint(goal: Vector3) -> bool:
	cancel_endpoint()
	var started: int=Time.get_ticks_usec();responses=0;limited=false;blocked=false;error="";pending=false
	if collect_profile:profile_usec={}
	if rig==null or not goal.is_finite():error="invalid held endpoint";blocked=true;last_ms=(Time.get_ticks_usec()-started)/1000.;return false
	var before: PackedVector3Array=rig.strand.points.duplicate()
	var offset: Vector3=goal-rig.strand.anchor
	if offset.length()>rig.strand.total_length:
		goal=rig.strand.anchor+offset.normalized()*rig.strand.total_length;limited=true
	var travel: Vector3=goal-before[0]
	if travel.length()>MAX_MOVE_M:goal=before[0]+travel.normalized()*MAX_MOVE_M
	_requested_goal=goal
	if goal==before[0]:
		_drop_warm();_prepare(before,before);last_ms=(Time.get_ticks_usec()-started)/1000.;return true
	# Two bounded attempts permit partial approach to an obstruction without
	# committing half a solve or buying progress by discarding collision.
	for fraction: float in [1.,.5]:
		var end: Vector3=before[0].lerp(goal,fraction)
		var steps: int=maxi(1,ceili(before[0].distance_to(end)/substep_m))
		var working: PackedVector3Array=before
		var partial:=false
		for step in range(1,steps+1):
			var proposed: PackedVector3Array=_trial(working,before[0].lerp(end,float(step)/steps))
			if proposed.is_empty():partial=not pending;break
			working=proposed
			if step<steps and Time.get_ticks_usec()-started>=WORK_BUDGET_USEC:
				pending=true;break
		if working==before:
			if pending:last_ms=(Time.get_ticks_usec()-started)/1000.;return false
			continue
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
		cancel_motion();blocked=true;error="stale held endpoint proposal";return false
	var stage_started: int=Time.get_ticks_usec() if collect_profile else 0
	var response: Dictionary=contact.motion_constraints(_prepared_before,_prepared_points,4096)
	_profile_add("commit_world",stage_started)
	responses+=1
	if not response.valid or response.truncated or not response.planes.is_empty() or (not bool(response.get("sweep_clear",false)) and contact.veto(_prepared_before,_prepared_points)):
		cancel_motion();blocked=true;error="prepared held endpoint became obstructed";last_ms+=(Time.get_ticks_usec()-started)/1000.;return false
	if round_self_radius_m>0.:
		stage_started=Time.get_ticks_usec() if collect_profile else 0
		var own: Dictionary=kernel.coupled.round_self_constraints(_prepared_before,_prepared_points,round_self_radius_m)
		_profile_add("commit_self",stage_started)
		if not own.valid or not own.clear:
			cancel_motion();blocked=true;error="prepared round hose self contact";last_ms+=(Time.get_ticks_usec()-started)/1000.;return false
	var points: PackedVector3Array=_prepared_points
	cancel_endpoint()
	stage_started=Time.get_ticks_usec() if collect_profile else 0
	var applied: bool=rig.apply_points(points)
	_profile_add("skin_apply",stage_started)
	if not applied:error="held skin rejected pose";blocked=true;return false
	rig.strand.points=points
	if not _warm_before.is_empty() and _warm_before!=points:
		_warm_before=PackedVector3Array();_warm_seed=PackedVector3Array()
	error="";last_ms+=(Time.get_ticks_usec()-started)/1000.
	return true
func move_endpoint(goal: Vector3) -> bool:
	return prepare_endpoint(goal) and commit_endpoint()
