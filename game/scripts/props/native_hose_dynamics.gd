extends RefCounted
## Candidate inextensible release dynamics. Actual annular shell contact planes
## constrain each ring; the final native swept-shell query prevents tunnelling.
## No self-contact, held-end constraint, maintenance facts or installed ownership.
const STEP_S:=1./120.
const MAX_SUBDIVISION_DEPTH:=4
const MAX_STEP_ATTEMPTS:=31
var rig: RefCounted
var contact: RefCounted
var velocities:=PackedVector3Array()
var error:=""
var response_iterations:=0
var contacts_resolved:=0
var projection_error:=""
var response_history: Array[Dictionary]=[]
var last_contacts: Array=[]
var last_proposed:=PackedVector3Array()
var last_energy_delta:=0.
var masses:=PackedFloat64Array()
var kernel:=preload("res://scripts/props/hose_mass_constraints.gd").new()
var step_attempts:=0
var accepted_substeps:=0
var advanced_time_s:=0.
var last_attempt_delta_s:=0.
var _accepted_contacts:=0
var profile_usec: Dictionary={}
var projection_calls:=0
func _profile(category: String,started: int) -> void:
	profile_usec[category]=int(profile_usec.get(category,0))+Time.get_ticks_usec()-started
func configure(owner_rig: RefCounted,owner_contact: RefCounted) -> bool:
	if rig!=null or owner_rig==null or not owner_rig.configured or owner_contact==null or not owner_contact.ready:return false
	if owner_contact.rig!=owner_rig:return false
	if not kernel.configure(owner_rig.strand.lengths,owner_rig.rest):return false
	rig=owner_rig;contact=owner_contact
	velocities.resize(rig.strand.points.size());velocities.fill(Vector3.ZERO)
	masses.resize(velocities.size())
	for i in masses.size():
		masses[i]=(rig.strand.lengths[i-1]*.5 if i>0 else 0.)+(rig.strand.lengths[i]*.5 if i<rig.strand.lengths.size() else 0.)
	return true
func reset_velocity() -> void:velocities.fill(Vector3.ZERO)
func _merge(planes: Dictionary,ring: int,normal: Vector3,offset: float) -> void:
	if not planes.has(ring):planes[ring]=[]
	for old: Dictionary in planes[ring]:
		# Similar normals are not interchangeable: their offsets are measured
		# against the model origin. Merging them without changing that datum
		# can leave a persistent penetration even on an almost-flat contact.
		if (old.normal-normal).length_squared()<1e-14:
			old.offset=maxf(old.offset,offset);return
	planes[ring].append({"normal":normal,"offset":offset})
func _project(target: PackedVector3Array,planes: Dictionary) -> PackedVector3Array:
	var started: int=Time.get_ticks_usec();projection_calls+=1
	var result: PackedVector3Array=kernel.project(target,rig.strand.anchor,planes)
	_profile("position_projection",started)
	profile_usec["joint_projection"]=int(profile_usec.get("joint_projection",0))+kernel.joint_usec
	projection_error=kernel.error
	return result
func _energy_change(before: PackedVector3Array,speed: PackedVector3Array,gravity: Vector3) -> float:
	var result:=0.
	for i in velocities.size():
		var old_world: Vector3=rig.model.global_basis*speed[i]
		var next_world: Vector3=rig.model.global_basis*velocities[i]
		result+=masses[i]*((next_world.length_squared()-old_world.length_squared())*.5-gravity.dot(rig.model.global_basis*(rig.strand.points[i]-before[i])))
	return result
func _rollback(points: PackedVector3Array,speed: PackedVector3Array) -> void:
	var started: int=Time.get_ticks_usec()
	rig.strand.points=points.duplicate();velocities=speed.duplicate()
	if not rig.apply_points(points):error="native dynamics rollback failed"
	_profile("rollback_skin",started)
func _integrate(delta: float,gravity: Vector3,depth: int) -> bool:
	if step_attempts>=MAX_STEP_ATTEMPTS:error="bounded release work ceiling";return false
	step_attempts+=1;last_attempt_delta_s=delta
	var before: PackedVector3Array=rig.strand.points.duplicate();var speed:=velocities.duplicate()
	var previous_count: int=accepted_substeps;var previous_time: float=advanced_time_s;var previous_contacts: int=_accepted_contacts
	if _advance(delta,gravity):
		accepted_substeps+=1;advanced_time_s+=delta;_accepted_contacts+=contacts_resolved
		return true
	var failure: String=error
	_rollback(before,speed)
	if depth<MAX_SUBDIVISION_DEPTH:
		if _integrate(delta*.5,gravity,depth+1) and _integrate(delta*.5,gravity,depth+1):
			var change: float=_energy_change(before,speed,gravity)
			if change<=rig.strand.total_length*gravity.length()*.00002:return true
			failure="subdivided release injects aggregate energy: "+str(change)
		else:failure=error
	_rollback(before,speed)
	accepted_substeps=previous_count;advanced_time_s=previous_time;_accepted_contacts=previous_contacts
	error=failure
	return false
func step(delta: float,world_gravity: Vector3=Vector3(0,-9.81,0)) -> bool:
	step_attempts=0;accepted_substeps=0;advanced_time_s=0.;_accepted_contacts=0
	profile_usec={};projection_calls=0
	if rig==null or not is_finite(delta) or delta<=0. or delta>STEP_S+.00000001 or not world_gravity.is_finite():
		error="invalid bounded dynamics step";return false
	var before: PackedVector3Array=rig.strand.points.duplicate();var speed:=velocities.duplicate()
	if not _integrate(delta,world_gravity,0):return false
	last_energy_delta=_energy_change(before,speed,world_gravity)
	if absf(advanced_time_s-delta)>.0000000001 or last_energy_delta>rig.strand.total_length*world_gravity.length()*.00002:
		_rollback(before,speed);accepted_substeps=0;advanced_time_s=0.;error="release aggregate time/energy contract failed";return false
	contacts_resolved=_accepted_contacts;error=""
	return true
func _advance(delta: float,world_gravity: Vector3) -> bool:
	error="";response_iterations=0;contacts_resolved=0;response_history.clear();last_contacts.clear();last_energy_delta=0.
	if rig==null or not is_finite(delta) or delta<=0. or delta>STEP_S+.00000001 or not world_gravity.is_finite():
		error="invalid bounded dynamics step";return false
	var before: PackedVector3Array=rig.strand.points.duplicate()
	var predicted:=before.duplicate()
	var gravity: Vector3=rig.model.global_basis.inverse()*world_gravity
	var damping: float=exp(-3.*delta)
	for i in range(predicted.size()-1):predicted[i]+=velocities[i]*delta*damping+gravity*delta*delta
	var planes: Dictionary={}
	for iteration in 32:
		response_iterations=iteration+1
		var proposed:=_project(predicted,planes)
		if proposed.is_empty() or not rig.strand._valid_positions(proposed):
			error="infeasible length/support constraints: "+projection_error
			if not proposed.is_empty():
				var total:=0.;var widest:=0.
				for i in rig.strand.lengths.size():
					var length: float=proposed[i].distance_to(proposed[i+1]);total+=length;widest=maxf(widest,absf(length-rig.strand.lengths[i]))
				error+=" length errors "+str([widest,total-rig.strand.total_length])
			return false
		var contact_started: int=Time.get_ticks_usec()
		var result: Dictionary=contact.motion_constraints(before,proposed,4096)
		_profile("world_contact",contact_started)
		last_proposed=proposed;last_contacts=result.planes.duplicate(true)
		if not result.valid or result.truncated:
			error="invalid or truncated native contact response: "+str([result.valid,result.truncated,result.error]);return false
		if result.planes.is_empty():
			var sweep_started: int=Time.get_ticks_usec()
			var blocked: bool=contact.veto(before,proposed)
			_profile("final_sweep",sweep_started)
			if blocked:error="native swept shell blocked release step";return false
			var next_velocity:=PackedVector3Array();next_velocity.resize(velocities.size())
			for i in velocities.size():
				next_velocity[i]=(proposed[i]-before[i])/delta
			var velocity_started: int=Time.get_ticks_usec()
			next_velocity=kernel.project_velocity(proposed,next_velocity,planes)
			_profile("velocity_projection",velocity_started)
			if next_velocity.is_empty():error="mass velocity projection: "+kernel.error;return false
			for i in velocities.size():
				var old_world: Vector3=rig.model.global_basis*velocities[i]
				var next_world: Vector3=rig.model.global_basis*next_velocity[i]
				last_energy_delta+=masses[i]*((next_world.length_squared()-old_world.length_squared())*.5-world_gravity.dot(rig.model.global_basis*(proposed[i]-before[i])))
			# Static-world release cannot manufacture energy. Reject the whole
			# proposal while the candidate's mass/bending solve remains unfinished.
			# The allowance is only the existing20micrometre positional precision;
			# it is translation-independent, unlike a percentage of altitude.
			if last_energy_delta>rig.strand.total_length*world_gravity.length()*.00002:
				error="release proposal injects mechanical energy: "+str(last_energy_delta);return false
			var skin_started: int=Time.get_ticks_usec()
			var applied: bool=rig.apply_points(proposed)
			_profile("accepted_skin",skin_started)
			if not applied:error="native skin rejected release pose";return false
			rig.strand.points=proposed
			velocities=next_velocity
			velocities[-1]=Vector3.ZERO
			return true
		contacts_resolved+=result.planes.size()
		var deepest: float=-INF
		for plane: Dictionary in result.planes:deepest=maxf(deepest,plane.offset-plane.normal.dot(proposed[plane.ring]))
		response_history.append({"iteration":iteration,"planes":result.planes.size(),"required_correction":deepest})
		for plane: Dictionary in result.planes:
			var ring: int=plane.ring
			if ring==before.size()-1:error="fixed outlet intersects world";return false
			_merge(planes,ring,plane.normal,plane.offset)
	error="native response did not converge: "+str(response_history.slice(-4));return false
