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
func configure(owner_rig: RefCounted,owner_contact: RefCounted) -> bool:
	if rig!=null or owner_rig==null or not owner_rig.configured or owner_contact==null or not owner_contact.ready:return false
	if owner_contact.rig!=owner_rig:return false
	rig=owner_rig;contact=owner_contact
	velocities.resize(rig.strand.points.size());velocities.fill(Vector3.ZERO)
	return true
func reset_velocity() -> void:velocities.fill(Vector3.ZERO)
func _merge(planes: Dictionary,ring: int,normal: Vector3,offset: float) -> void:
	if not planes.has(ring):planes[ring]=[]
	for old: Dictionary in planes[ring]:
		if old.normal.dot(normal)>.999999:
			old.offset=maxf(old.offset,offset);return
	planes[ring].append({"normal":normal,"offset":offset})
func _propagate(planes: Dictionary) -> bool:
	# A constrained child can only reach its length sphere if the parent is
	# within one segment of that half-space. Propagate this necessary support
	# toward the outlet before anchor-to-end projection, rather than freezing
	# the entire strand when a neighbouring unsupported ring falls too low.
	for ring in range(rig.strand.points.size()-1):
		for plane: Dictionary in planes.get(ring,[]):
			_merge(planes,ring+1,plane.normal,plane.offset-rig.strand.lengths[ring])
	for plane: Dictionary in planes.get(rig.strand.points.size()-1,[]):
		if plane.normal.dot(rig.strand.anchor)<plane.offset-.000001:return false
	return true
func _project(target: PackedVector3Array,planes: Dictionary) -> PackedVector3Array:
	var result:=target.duplicate();result[-1]=rig.strand.anchor
	for i in range(result.size()-2,-1,-1):
		var delta: Vector3=target[i]-result[i+1]
		if delta.length_squared()<1e-14:return PackedVector3Array()
		var direction: Vector3=delta.normalized()
		var length: float=rig.strand.lengths[i]
		var limits: Array=planes.get(i,[])
		# Intersect the exact segment-length sphere with local support planes.
		# Multiple corner planes may require repeated projection or be infeasible.
		for iteration in 8:
			for plane: Dictionary in limits:
				var normal: Vector3=plane.normal
				var minimum: float=(plane.offset-normal.dot(result[i+1]))/length
				if minimum>1.0001:return PackedVector3Array()
				minimum=minf(minimum,1.)
				if normal.dot(direction)>=minimum:continue
				var tangent: Vector3=direction-normal*normal.dot(direction)
				if tangent.length_squared()<1e-14:
					tangent=normal.cross(Vector3.RIGHT if absf(normal.x)<.8 else Vector3.UP)
				direction=normal*minimum+tangent.normalized()*sqrt(maxf(0.,1.-minimum*minimum))
		result[i]=result[i+1]+direction*length
		for plane: Dictionary in limits:
			if plane.normal.dot(result[i])<plane.offset-.000001:return PackedVector3Array()
	return result
func step(delta: float,world_gravity: Vector3=Vector3(0,-9.81,0)) -> bool:
	error="";response_iterations=0;contacts_resolved=0
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
			error="infeasible length/support constraints";return false
		var result: Dictionary=contact.contact_constraints(proposed,4096)
		if not result.valid or result.truncated:error="invalid or truncated native contact response";return false
		if result.planes.is_empty():
			if contact.veto(before,proposed):error="native swept shell blocked release step";return false
			if not rig.apply_points(proposed):error="native skin rejected release pose";return false
			rig.strand.points=proposed
			for i in velocities.size():velocities[i]=(proposed[i]-before[i])/delta
			velocities[-1]=Vector3.ZERO
			return true
		contacts_resolved+=result.planes.size()
		for plane: Dictionary in result.planes:
			var ring: int=plane.ring
			if ring==before.size()-1:error="fixed outlet intersects world";return false
			_merge(planes,ring,plane.normal,plane.offset)
		if not _propagate(planes):error="outlet cannot reach native support constraints";return false
	error="native response did not converge";return false
