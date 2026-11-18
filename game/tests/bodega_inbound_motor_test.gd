extends "res://tests/bodega_waiting_motor_test.gd"
## Actual inbound side-lane walk with service/front occupied. No queue proof.
var inbound_started := false

func _snapshot() -> Dictionary:
	var result := super._snapshot()
	var parent := "res://tests/bodega_waiting_motor_test.gd"
	result[parent] = {"sha256": FileAccess.get_file_as_string(parent).replace("\r\n", "\n").sha256_text()}
	return result

func _finish() -> void:
	if failures.is_empty() and not inbound_started:
		inbound_started = true; motor_started = true; surveyed = true; _survey()
		for row: Dictionary in details.candidate_standing: measured[str(row.id)] = row.feet
		details.motor_scope = "inbound ordinary motor via staged existing vertices; service and front real bodies remain parked; no admission/agenda/full setup proof"
		details.motor_initials = []; details.motor_trace = []; details.motor_witnesses = []; details.motor_legs = []
		if failures.is_empty():
			await _scenario({"rhea_sato":"service", "jonah_price":"wait_front", "teresa_vale":"overflow"}, "inbound")
			for route: Node3D in routes:
				for edge: Array in [["overflow","exterior"],["interior","entry_turn"],["entry_turn","access_front"]]:
					route.graph.connect_points(int(route.identities[edge[0]]), int(route.identities[edge[1]]))
			for goal: String in ["exterior", "interior", "entry_turn", "access_front", "access_rear", "wait_rear"]:
				if failures.is_empty(): await _leg("teresa_vale", goal)
		motor_watching = false
		details.motor_summary = {"physics_frames":frames, "minimum_peer_axis_distance_m":str(minimum_peer),
			"minimum_player_axis_distance_m":str(minimum_player), "completed_legs":details.motor_legs.size()}
		_check(details.motor_legs.size()==6 and frames>0, "all six inbound ordinary motor legs complete with physics witnesses")
	await super._finish()
