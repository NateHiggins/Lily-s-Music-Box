extends Node
## Numerical diagnosis of a captured payout sweep, not gameplay proof.
func _points(rows: Array) -> PackedVector3Array:
	var result:=PackedVector3Array()
	for row: Array in rows:result.append(Vector3(row[0],row[1],row[2]))
	return result
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	var path:=OS.get_environment("ORISON_HOSE_PAYOUT_CAPTURE")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var before:=_points(data.pose.points);var after:=_points(data.response.candidate)
	var projection: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_unracked_fire_hose_rig.json"))
	var rest:=_points(projection.points);var lengths:=PackedFloat64Array()
	for i in range(1,rest.size()):lengths.append(rest[i].distance_to(rest[i-1]))
	var kernel:=preload("res://scripts/props/hose_mass_constraints.gd").new()
	if not kernel.configure(lengths,rest):get_tree().quit(1);return
	var pins: Dictionary={0:after[0],1:after[1],2:after[2],before.size()-2:before[-2],before.size()-3:before[-3]}
	var own: Dictionary=kernel.coupled.round_self_constraints(before,after,.021,pins)
	var debts: Array=[]
	for plane: Dictionary in own.planes:debts.append(plane.offset-plane.normal.dot(after[plane.ring]))
	var endpoint: Dictionary=kernel.coupled.round_self_constraints(after,after,.021,pins)
	print("SELF SWEEP REPLAY: ",JSON.stringify({"valid":own.valid,"clear":own.clear,"error":own.get("error",""),"end_clear":endpoint.clear,"end_valid":endpoint.valid,"debts":debts}))
	get_tree().quit(0 if own.valid else 1)
