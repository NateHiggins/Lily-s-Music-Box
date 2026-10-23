extends RefCounted
## Physical poses within10um; wheel JSON round-trip within1e-12 radians.
## Water, maintenance facts and all other non-pose fields remain exact.
static func pose(value: Dictionary) -> Transform3D:
	var axes: Array[Vector3]=[]
	for axis: Array in value.basis:axes.append(Vector3(axis[0],axis[1],axis[2]))
	return Transform3D(Basis(axes[0],axes[1],axes[2]),Vector3(value.position[0],value.position[1],value.position[2]))
static func compare(actual: Dictionary,wanted: Dictionary) -> Dictionary:
	var result: Dictionary={"raw_equal":actual==wanted,"poses":{},"other_fields_equal":false,"equal":false}
	var a: Dictionary=actual.duplicate(true);var b: Dictionary=wanted.duplicate(true)
	var poses_equal:=true
	for component: String in ["receiver","nozzle","gasket","loose"]:
		var av: Dictionary=a.hose.receiver if component=="receiver" else a[component]
		var bv: Dictionary=b.hose.receiver if component=="receiver" else b[component]
		var first: Transform3D;var second: Transform3D
		if component in ["gasket","loose"]:
			var ar: Array=av.get("rotation",[0.,0.,0.,1.]);var br: Array=bv.get("rotation",[0.,0.,0.,1.])
			first=Transform3D(Basis(Quaternion(ar[0],ar[1],ar[2],ar[3])),Vector3(av.position[0],av.position[1],av.position[2]))
			second=Transform3D(Basis(Quaternion(br[0],br[1],br[2],br[3])),Vector3(bv.position[0],bv.position[1],bv.position[2]))
		else:first=pose(av);second=pose(bv)
		var position_error: float=first.origin.distance_to(second.origin)
		var basis_error: float=maxf(first.basis.x.distance_to(second.basis.x),maxf(first.basis.y.distance_to(second.basis.y),first.basis.z.distance_to(second.basis.z)))
		result.poses[component]={"position_error_m":position_error,"basis_axis_error":basis_error}
		poses_equal=poses_equal and position_error<.00001 and basis_error<.00001
	a.hose.erase("receiver");b.hose.erase("receiver")
	for component: String in ["gasket","loose"]:
		a[component].erase("position");b[component].erase("position")
		a[component].erase("rotation");b[component].erase("rotation")
	a.nozzle.erase("position");a.nozzle.erase("basis");b.nozzle.erase("position");b.nozzle.erase("basis")
	result.wheel_error_rad=absf(float(a.hose.wheel)-float(b.hose.wheel))
	var wheel_equal: bool=result.wheel_error_rad<.000000000001
	a.hose.erase("wheel");b.hose.erase("wheel")
	result.other_fields_equal=a==b;result.equal=poses_equal and wheel_equal and result.other_fields_equal
	return result
