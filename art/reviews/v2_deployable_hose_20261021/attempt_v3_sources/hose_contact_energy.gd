extends RefCounted
## Inelastic contact dissipation after geometric and tangent-velocity projection.
## Never changes positions, accepts potential-energy debt, or supplies energy.
static func dissipate(before: PackedVector3Array,previous: PackedVector3Array,after: PackedVector3Array,proposed: PackedVector3Array,masses: PackedFloat64Array,world_basis: Basis,gravity: Vector3) -> Dictionary:
	var invalid: Dictionary={"valid":false,"velocities":PackedVector3Array(),"removed":0.}
	if before.is_empty() or before.size()!=previous.size() or before.size()!=after.size() or before.size()!=proposed.size() or before.size()!=masses.size() or not gravity.is_finite() or not world_basis.is_finite():return invalid
	var old_kinetic:=0.;var new_kinetic:=0.;var work:=0.
	for i in before.size():
		if not before[i].is_finite() or not after[i].is_finite() or not previous[i].is_finite() or not proposed[i].is_finite() or not is_finite(masses[i]) or masses[i]<=0.:return invalid
		old_kinetic+=masses[i]*(world_basis*previous[i]).length_squared()*.5
		new_kinetic+=masses[i]*(world_basis*proposed[i]).length_squared()*.5
		work+=masses[i]*gravity.dot(world_basis*(after[i]-before[i]))
	var budget: float=old_kinetic+work
	# Raising potential beyond available kinetic energy requires a different
	# positional solve. Velocity damping cannot make such a pose admissible.
	if not is_finite(budget) or budget<0. or not is_finite(new_kinetic):return invalid
	var result:=proposed.duplicate();var scale:=1.
	if new_kinetic>budget and new_kinetic>0.:
		scale=sqrt(budget/new_kinetic)*(1.-.000001)
		for i in result.size():result[i]*=scale
	var accepted_kinetic:=0.
	for i in result.size():accepted_kinetic+=masses[i]*(world_basis*result[i]).length_squared()*.5
	if accepted_kinetic>budget+.000000001:return invalid
	return {"valid":true,"velocities":result,"removed":maxf(0.,new_kinetic-accepted_kinetic)}
