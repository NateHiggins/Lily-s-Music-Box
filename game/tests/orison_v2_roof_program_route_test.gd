extends "res://tests/orison_v2_roof_plant_test.gd"
## Add interior trace points for the two narrow roof strips crossed by the circuit.
func _walk(target: Vector3, arrival_tolerance: float=.1) -> bool:
	if target.is_equal_approx(Vector3(14,19.2,10.8)):
		if not await super._walk(Vector3(14,19.2,-1),arrival_tolerance): return false
	if target.is_equal_approx(Vector3(7.5,19.2,10.8)):
		if not await super._walk(Vector3(11,19.2,10.8),arrival_tolerance): return false
	return await super._walk(target,arrival_tolerance)
