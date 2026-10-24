extends Node
const Energy=preload("res://scripts/props/hose_contact_energy.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("HOSE CONTACT ENERGY CHECK: ",label," = ",ok)
	if not ok:failures.append(label)
func _ready() -> void:
	var before:=PackedVector3Array([Vector3(-1,1,0),Vector3(0,1,0),Vector3(1,1,0)])
	var after:=before.duplicate();after[0].y-=.01;after[1].y-=.01
	var zero:=PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
	var proposed:=PackedVector3Array([Vector3(0,3,0),Vector3(0,3,0),Vector3.ZERO])
	var masses:=PackedFloat64Array([1.,1.,1.]);var gravity:=Vector3(0,-9.81,0)
	for basis: Basis in [Basis.IDENTITY,Basis(Vector3.UP,PI),Basis(Vector3.BACK,.65)]:
		var result: Dictionary=Energy.dissipate(before,zero,after,proposed,masses,basis,gravity)
		check(result.valid and result.removed>0.,"inelastic impact removes excess projected kinetic energy at rotated frame")
		if result.valid:
			var kinetic:=0.;var work:=0.
			for i in 3:
				kinetic+=masses[i]*(basis*result.velocities[i]).length_squared()*.5
				work+=masses[i]*gravity.dot(basis*(after[i]-before[i]))
			check(kinetic<=work+.00000001,"independent kinetic plus potential budget remains nonincreasing")
			check(result.velocities[0]==result.velocities[1] and result.velocities[2]==Vector3.ZERO,"homogeneous velocity relations and a pinned zero survive dissipation")
	var slow:=PackedVector3Array([Vector3(0,.1,0),Vector3(0,.1,0),Vector3.ZERO])
	var result: Dictionary=Energy.dissipate(before,zero,after,slow,masses,Basis.IDENTITY,gravity)
	check(result.valid and result.velocities==slow and result.removed==0.,"already admissible velocities remain bit-exact")
	result=Energy.dissipate(before,zero,before,proposed,masses,Basis.IDENTITY,gravity)
	check(result.valid and result.velocities==zero,"zero available energy permits only a stationary impact")
	var raised:=before.duplicate();raised[0].y+=.01
	check(not Energy.dissipate(before,zero,raised,proposed,masses,Basis.IDENTITY,gravity).valid,"velocity damping cannot accept an impossible potential-energy increase")
	var bad:=after.duplicate();bad[0].x=INF
	check(not Energy.dissipate(before,zero,bad,proposed,masses,Basis.IDENTITY,gravity).valid,"nonfinite positions fail closed")
	check(not Energy.dissipate(before,zero,after,proposed,PackedFloat64Array([1.,-1.,1.]),Basis.IDENTITY,gravity).valid,"invalid material masses fail closed")
	check(before[0]==Vector3(-1,1,0) and proposed[0]==Vector3(0,3,0),"dissipation never mutates input positions or velocities")
	print("HOSE CONTACT ENERGY TEST: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
