extends RefCounted
## Uninstalled held-end owner. One authoritative native swept-shell response
## gates each accepted pose. No maintenance, input, case or save authority.
const MAX_MOVE_M:=.08
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
func configure(owner_rig: RefCounted,owner_contact: RefCounted) -> bool:
	if rig!=null or owner_rig==null or not owner_rig.configured or owner_contact==null or not owner_contact.ready or owner_contact.rig!=owner_rig:return false
	if not kernel.configure(owner_rig.strand.lengths,owner_rig.rest) or kernel.coupled.backend_name!="native":return false
	rig=owner_rig;contact=owner_contact
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
		pins[1]=goal+before[1]-before[0]
		pins[before.size()-2]=before[before.size()-2]
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
func move_endpoint(goal: Vector3) -> bool:
	var started: int=Time.get_ticks_usec();responses=0;limited=false;blocked=false;error=""
	if rig==null or not goal.is_finite():error="invalid held endpoint";blocked=true;last_ms=(Time.get_ticks_usec()-started)/1000.;return false
	var before: PackedVector3Array=rig.strand.points.duplicate()
	var offset: Vector3=goal-rig.strand.anchor
	if offset.length()>rig.strand.total_length:
		goal=rig.strand.anchor+offset.normalized()*rig.strand.total_length;limited=true
	var travel: Vector3=goal-before[0]
	if travel.length()>MAX_MOVE_M:goal=before[0]+travel.normalized()*MAX_MOVE_M
	if goal==before[0]:last_ms=(Time.get_ticks_usec()-started)/1000.;return true
	# Two bounded attempts permit partial approach to an obstruction without
	# committing half a solve or buying progress by discarding collision.
	for fraction: float in [1.,.5]:
		var proposed: PackedVector3Array=_trial(before,before[0].lerp(goal,fraction))
		if proposed.is_empty():continue
		if not rig.apply_points(proposed):error="held skin rejected pose";break
		rig.strand.points=proposed;error="";last_ms=(Time.get_ticks_usec()-started)/1000.;return true
	blocked=true;last_ms=(Time.get_ticks_usec()-started)/1000.
	return false
