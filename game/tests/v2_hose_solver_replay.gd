extends Node
## Numerical diagnosis from an actual-world capture, not gameplay qualification.
class ReplayRig extends RefCounted:
	var rest:=PackedVector3Array()
	var strand:=preload("res://scripts/props/hose_length_constraint.gd").new()
func _point(row: Array) -> Vector3:return Vector3(row[0],row[1],row[2])
func _points(rows: Array) -> PackedVector3Array:
	var result:=PackedVector3Array()
	for row: Array in rows:result.append(_point(row))
	return result
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	var path:=OS.get_environment("ORISON_HOSE_SOLVER_CAPTURE")
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is not Dictionary or data.get("schema")!="orison.hose-kernel-capture.v1":
		push_error("HOSE SOLVER REPLAY: invalid capture");get_tree().quit(1);return
	var rest:=_points(data.rest);var before:=_points(data.before);var seed:=_points(data.seed)
	var lengths:=PackedFloat64Array(data.lengths);var radii:=PackedFloat64Array(data.radii)
	var planes: Dictionary={};var pins: Dictionary={}
	for row: Dictionary in data.planes:
		var ring:=int(row.ring)
		if not planes.has(ring):planes[ring]=[]
		planes[ring].append({"normal":_point(row.normal),"offset":float(row.offset)})
	for row: Dictionary in data.pins:pins[int(row.ring)]=_point(row.position)
	var results: Dictionary={"evidence_class":"INERT","capture":path,"captured_error":data.error,"continuation":data.continuation}
	for mode: String in ["captured_contacts","without_contacts"]:
		var kernel:=preload("res://scripts/props/hose_mass_constraints.gd").new()
		if not kernel.configure(lengths,rest,radii) or not kernel.coupled.set_bend_error(.00002):
			push_error("HOSE SOLVER REPLAY: native setup failed");get_tree().quit(1);return
		kernel.bend_error_m=.00002
		var started: int=Time.get_ticks_usec()
		var solved: PackedVector3Array=kernel.follow(seed,_point(data.anchor),planes if mode=="captured_contacts" else {},pins)
		results[mode]={"accepted":not solved.is_empty(),"error":kernel.error,"usec":Time.get_ticks_usec()-started,"iterations":kernel.iterations}
	var rig:=ReplayRig.new();rig.rest=rest;rig.strand.configure(rest)
	rig.strand.lengths=lengths;rig.strand.points=before;rig.strand.anchor=_point(data.anchor)
	rig.strand.total_length=0.
	for length: float in lengths:rig.strand.total_length+=length
	var local:=preload("res://scripts/props/round_local_endpoint.gd").new()
	local.configure(rig,radii);local.prime(before)
	var proposed: PackedVector3Array=local.constrained_seed(before,_point(data.goal),planes,pins)
	results.local_contacts={"accepted":not proposed.is_empty(),"error":local.last_error,"join":local.last_join,"usec":local.last_usec}
	results.reproduced=not results.captured_contacts.accepted and results.captured_contacts.error==data.error and not data.continuation
	print("HOSE SOLVER REPLAY: ",JSON.stringify(results))
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var file:=FileAccess.open(directory.path_join("replay.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(results,"\t"));file.close()
	get_tree().quit(0 if results.reproduced else 1)
