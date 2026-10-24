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
	var rigid: RefCounted=make_kernel(rest)
	check(rigid.pin_rings(PackedInt32Array([29,30])),"additional fixed outlet neck configures")
	var weights: PackedFloat64Array=rigid.inverse.duplicate()
	check(not rigid.pin_rings(PackedInt32Array([-1])) and rigid.inverse==weights,"invalid fixed index leaves configured weights unchanged")
	var all_fixed:=PackedInt32Array()
	for i in rest.size():all_fixed.append(i)
	check(not rigid.pin_rings(all_fixed) and rigid.inverse==weights,"configuration cannot erase all remaining physical mobility")
	predicted=rest.duplicate()
	for i in 29:predicted[i]+=Vector3(0,-.001,0)
	moved=rigid.follow(predicted,rest[-1],{})
	check(valid(rigid,moved,rest[-1]) and moved[29]==rest[29] and moved[30]==rest[30],"implicit fixed neck points survive the follower without separate caller pins")
	var velocity:=PackedVector3Array();velocity.resize(rest.size());velocity.fill(Vector3(0,-1,0))
	var projected: PackedVector3Array=rigid.project_velocity(moved,velocity,{})
	var tangent:=projected.size()==rest.size()
	if tangent:
		for i in rest.size()-1:
			if absf((moved[i]-moved[i+1]).normalized().dot(projected[i]-projected[i+1]))>.0001:tangent=false
	check(tangent and projected[29]==Vector3.ZERO and projected[30]==Vector3.ZERO and projected[31]==Vector3.ZERO,"velocity projection retains the fixed neck and every tangent constraint")
	check(valid(rigid,rigid.project(predicted,rest[-1],{}),rest[-1]),"pinned joint fallback satisfies the same independent material bounds")
	var descending:=PackedVector3Array();var floor_planes: Dictionary={}
	for i in 32:
		descending.append(Vector3(0,.001*i,0))
		floor_planes[i]=[{"normal":Vector3.UP,"offset":.0001}]
	var fine: RefCounted=make_kernel(descending)
	var falling:=descending.duplicate()
	for i in falling.size()-1:falling[i].y-=.005
	var landed: PackedVector3Array=fine.follow(falling,descending[-1],floor_planes)
	check(valid(fine,landed,descending[-1],floor_planes),"dense descending strand can reach a plane without an impossible late bend or fictitious extra stock")
	var planar:=PackedVector3Array([Vector3(-.08,-.16,0),Vector3(-.08,-.06,0),Vector3.ZERO])
	var flat: RefCounted=make_kernel(planar)
	var contact_plane: Dictionary={0:[{"normal":Vector3.UP,"offset":-.06}]}
	var resting: PackedVector3Array=flat.follow(planar,Vector3.ZERO,contact_plane)
	check(valid(flat,resting,Vector3.ZERO,contact_plane) and absf(resting[0].z)<.000001,"an equally valid planar contact solution is preferred over gratuitous sideways twisting")
	_held_regression("res://tests/fixtures/v2_hose_held_case.json","11.4m convergence")
	_held_regression("res://tests/fixtures/v2_hose_held_roundoff_case.json","12.5m roundoff")
	_held_regression("res://tests/fixtures/v2_hose_taut_case.json","nearly taut payout")
	print("HOSE FOLLOW KERNEL: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _held_regression(path: String,label: String) -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var points:=PackedVector3Array()
	for row: Array in data.before:points.append(Vector3(row[0],row[1],row[2]))
	var goal:=Vector3(data.goal[0],data.goal[1],data.goal[2]);var anchor:=Vector3(data.anchor[0],data.anchor[1],data.anchor[2])
	var kernel:=Mass.new()
	check(kernel.configure(PackedFloat64Array(data.lengths),points),"original long-payout failure material binds")
	var span_error:=0.;var inverse_error:=0.
	for i in kernel.bend_spans.size():span_error=maxf(span_error,absf(kernel.bend_spans[i]-float(data.spans[i])))
	for i in kernel.inverse.size():inverse_error=maxf(inverse_error,absf(kernel.inverse[i]-float(data.inverse[i])))
	check(span_error<=1e-12 and inverse_error<=1e-10,"historical bend and mobility survive original JSON precision: "+label)
	var pins: Dictionary={0:goal,1:goal+points[1]-points[0],2:goal+points[2]-points[0],points.size()-2:points[-2],points.size()-3:points[-3]}
	var start: int=Time.get_ticks_usec();var moved: PackedVector3Array=kernel.follow(points,anchor,{},pins)
	print("HELD REGRESSION: ms=",(Time.get_ticks_usec()-start)/1000.," iterations=",kernel.iterations," error=",kernel.error)
	check(valid(kernel,moved,anchor,{},pins),label+" actual-input failure can advance with exact fixed necks and unchanged material/bending bounds")
