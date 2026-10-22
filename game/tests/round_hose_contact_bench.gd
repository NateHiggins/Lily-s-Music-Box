extends SceneTree
## Numerical collision controls. No rendering or installed gameplay grant.
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	print("ROUND HOSE CONTACT: ",label," = ",ok)
	if not ok:failures.append(label)
func _initialize() -> void:
	var points:=PackedVector3Array([Vector3(-.2,0,0),Vector3(.2,0,0),Vector3(.2,0,.2),Vector3(-.2,0,.2),Vector3(3,3,3)])
	var kernel:=preload("res://scripts/props/hose_mass_constraints.gd").new()
	check(kernel.configure(PackedFloat64Array([.4,.2,.4,5.]),points),"material kernel configures")
	check(kernel.coupled.backend_name=="native","real native collision implementation is present")
	# The remote fifth point carries the kernel's fixed outlet; both ends of
	# the swept second segment remain movable unless explicitly pinned.
	var clear: Dictionary=kernel.coupled.round_self_constraints(points,points,.021)
	check(clear.valid and clear.clear and clear.planes.is_empty(),"separated material is clear")
	var translated:=points.duplicate()
	for i in translated.size():translated[i]+=Vector3(25,19,-31)
	var rigid: Dictionary=kernel.coupled.round_self_constraints(points,translated,.021)
	check(rigid.valid and rigid.clear,"large common translation creates no false relative collision")
	var crossing:=points.duplicate();crossing[2].z=-.2;crossing[3].z=-.2
	var swept: Dictionary=kernel.coupled.round_self_constraints(points,crossing,.021,{0:points[0],1:points[1]})
	check(swept.valid and not swept.clear and not swept.planes.is_empty(),"swept crossing is found even though final segments are separated")
	var only_movable:=true
	for plane: Dictionary in swept.planes:only_movable=only_movable and plane.ring in [2,3] and plane.normal.is_finite() and absf(plane.normal.length()-1.)<.00001 and is_finite(plane.offset)
	check(only_movable,"contact response never asks pinned material to move")
	var fixed: Dictionary=kernel.coupled.round_self_constraints(points,crossing,.021,{0:points[0],1:points[1],2:points[2],3:points[3]})
	check(not fixed.valid and not fixed.clear,"fully fixed crossing is refused")
	var overlap:=points.duplicate();overlap[2].z=.02;overlap[3].z=.02
	var bad: Dictionary=kernel.coupled.round_self_constraints(overlap,overlap,.021)
	check(not bad.valid and str(bad.get("error","")).contains("initial"),"initial material penetration cannot become accepted state")
	var tangent:=points.duplicate();tangent[2].z=.0422;tangent[3].z=.0422
	var near: Dictionary=kernel.coupled.round_self_constraints(tangent,tangent,.021)
	check(near.valid and near.clear,"positive physical clearance remains available")
	var invalid: Dictionary=kernel.coupled.round_self_constraints(points,points,NAN)
	check(not invalid.valid and not invalid.clear,"nonfinite physical radius is refused")
	print("ROUND HOSE CONTACT BENCH: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
