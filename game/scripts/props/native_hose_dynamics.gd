extends RefCounted
## Candidate inextensible release dynamics. Actual annular shell contact planes
## constrain each ring; the final native swept-shell query prevents tunnelling.
## No self-contact, held-end constraint, maintenance facts or installed ownership.
const STEP_S:=1./120.
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
	var result: PackedVector3Array=kernel.project(target,rig.strand.anchor,planes)
	projection_error=kernel.error
	return result
func step(delta: float,world_gravity: Vector3=Vector3(0,-9.81,0)) -> bool:
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
		var result: Dictionary=contact.motion_constraints(before,proposed,4096)
		last_proposed=proposed;last_contacts=result.planes.duplicate(true)
		if not result.valid or result.truncated:
			error="invalid or truncated native contact response: "+str([result.valid,result.truncated,result.error]);return false
		if result.planes.is_empty():
			if contact.veto(before,proposed):error="native swept shell blocked release step";return false
			var next_velocity:=PackedVector3Array();next_velocity.resize(velocities.size())
			for i in velocities.size():
				next_velocity[i]=(proposed[i]-before[i])/delta
			next_velocity=kernel.project_velocity(proposed,next_velocity,planes)
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
			if not rig.apply_points(proposed):error="native skin rejected release pose";return false
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
