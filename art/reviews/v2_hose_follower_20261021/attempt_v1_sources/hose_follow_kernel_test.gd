extends Node
const Mass=preload("res://scripts/props/hose_mass_constraints.gd")
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	print("HOSE FOLLOW CHECK: ",label," = ",ok)
	if not ok:failures.append(label)
func valid(kernel: RefCounted,points: PackedVector3Array,anchor: Vector3,planes: Dictionary={},pins: Dictionary={}) -> bool:
	if points.size()!=kernel.lengths.size()+1 or points[-1]!=anchor:return false
	var total:=0.
	for i in points.size():
		if not points[i].is_finite():return false
		if i<kernel.lengths.size():
			var error: float=points[i].distance_to(points[i+1])-kernel.lengths[i]
			if absf(error)>.00002:return false
			total+=error
		if i<kernel.bend_spans.size() and points[i].distance_to(points[i+2])<kernel.bend_spans[i]-.00002:return false
	if absf(total)>.00002:return false
	for ring: int in planes:
		for plane: Dictionary in planes[ring]:
			if plane.normal.dot(points[ring])<plane.offset-.000001:return false
	for ring: int in pins:
		if points[ring]!=pins[ring]:return false
	return true
func make_kernel(points: PackedVector3Array) -> RefCounted:
	var lengths:=PackedFloat64Array()
	for i in points.size()-1:lengths.append(points[i].distance_to(points[i+1]))
	var kernel:=Mass.new()
	check(kernel.configure(lengths,points) and kernel.coupled.backend_name=="native","source-bound native kernel configures")
	return kernel
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	var rest:=PackedVector3Array()
	for i in 32:rest.append(Vector3(.01*i,0,0))
	var kernel: RefCounted=make_kernel(rest);var original:=rest.duplicate()
	var predicted:=rest.duplicate()
	for i in predicted.size()-1:predicted[i]+=Vector3(0,-.001,0)
	var moved: PackedVector3Array=kernel.follow(predicted,rest[-1],{})
	check(valid(kernel,moved,rest[-1]) and moved[0].y<0.,"free strand follows gravity proposal with all original material bounds")
	check(rest==original,"numerical proposal never mutates caller coordinates")
	var pins: Dictionary={0:rest[0]+Vector3(.015,.015,0)}
	moved=kernel.follow(rest,rest[-1],{},pins)
	check(valid(kernel,moved,rest[-1],{},pins),"both held endpoint and fixed outlet resolve without stretching")
	var corner:=PackedVector3Array([Vector3(.2,0,0),Vector3(.1,0,0),Vector3.ZERO])
	var small: RefCounted=make_kernel(corner)
	var planes: Dictionary={0:[{"normal":Vector3.UP,"offset":.03},{"normal":Vector3.BACK,"offset":.03}]}
	moved=small.follow(corner,Vector3.ZERO,planes)
	check(valid(small,moved,Vector3.ZERO,planes),"two simultaneous contact caps retain lengths and finite bend radius")
	planes={0:[{"normal":Vector3.UP,"offset":.3}]}
	check(small.follow(corner,Vector3.ZERO,planes).is_empty() and corner[0]==Vector3(.2,0,0),"unreachable support rejects atomically")
	check(kernel.follow(rest,rest[-1],{},{0:Vector3(-1,0,0)}).is_empty(),"unreachable pinned end cannot add stock")
	check(kernel.follow(rest,rest[-1],{},{true:Vector3.ZERO}).is_empty(),"boolean pin index is rejected")
	check(kernel.follow(rest,rest[-1],{},{-1:Vector3.ZERO}).is_empty(),"negative pin index is rejected")
	check(kernel.follow(rest,rest[-1],{},{0:Vector3(INF,0,0)}).is_empty(),"nonfinite pin is rejected")
	check(kernel.follow(rest,rest[-1],{},{31:rest[-1]+Vector3(0,.0000005,0)}).is_empty(),"a pin cannot move the fixed outlet even within positional tolerance")
	var invalid:=rest.duplicate();invalid[0]=Vector3(INF,0,0)
	check(kernel.follow(invalid,rest[-1],{}).is_empty(),"nonfinite predicted geometry is rejected")
	check(valid(kernel,kernel.follow(rest,rest[-1],{},{0:rest[0]}),rest[-1],{},{0:rest[0]}),"taut strand with both exact endpoints remains valid")
	print("HOSE FOLLOW KERNEL: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
