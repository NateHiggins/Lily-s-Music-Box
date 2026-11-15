extends "res://tests/harukiya_mass_return_test.gd"
## Nearby real-motor control: original18 retained; only Lena walks out to the
## street turn and returns. No post-birth placements or invented obstacles.
var handoff_frames := 0
var departure_frames := 0
var return_frames := 0
var public_release_seen := false
var max_edge_deviation := 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not watching or not failures.is_empty() or programme_started == 0: return
	var route: Node3D = routes.lena_ortiz
	if route.path.is_empty() or not route._bar_route._gate.is_empty(): return
	if not world.public_traffic._inside(route.actor.global_position): return
	if not route._bar_route.owns_local_edge(): return
	handoff_frames += 1
	if stage == "approach_outbound": departure_frames += 1
	if stage == "approach_return": return_frames += 1
	if world.public_traffic._can_steer(route):
		_fail_safety("public avoidance yields before the narrow entrance turn", {}); return
	var a: Vector3 = route.graph.get_point_position(route.current_id)
	var b: Vector3 = route.graph.get_point_position(route.path[0])
	var feet: Vector3 = route.actor.global_position
	a.y=feet.y; b.y=feet.y
	var gap := feet.distance_to(Geometry3D.get_closest_point_to_segment(feet,a,b))
	max_edge_deviation=maxf(max_edge_deviation,gap)
	if gap > .05: _fail_safety("ordinary motor retains authored narrow-edge alignment", {"feet":feet,"a":a,"b":b,"gap":gap})

func _opposition_programme() -> void:
	contracts.erase("all_eighteen_exterior_departures")
	contracts.erase("physical_returns_and_queue_drain")
	programme_started=Time.get_ticks_msec()
	if not _request_goal("lena_ortiz","unit"): return
	if not await _wait_mass_phase("approach_outbound",func(): return _point_reached("lena_ortiz","bar_street_5"),75.0): return
	var route: Node3D=routes.lena_ortiz
	# Let the ordinary motor select its next outward edge at the reached vertex.
	await get_tree().physics_frame
	public_release_seen=not route.path.is_empty() and not route._bar_route.owns_local_edge() and world.public_traffic._can_steer(route)
	if not _check(public_release_seen,"public avoidance resumes beyond the narrow approach"): return
	if not _request_goal("lena_ortiz","harukiya_bar"): return
	if not await _wait_mass_phase("approach_return",func(): return _all_occupied() and _queue_drained(),75.0): return
	_check(departure_frames>0 and return_frames>0,"actual ungated narrow approach observed in both directions")
	_contract("native_approach_round_trip",failures.is_empty())

func _decorate_result(result: Dictionary) -> void:
	result.suite="HarukiyaApproachHandoffTest"
	result.scope="Original18 owners/models retained; Lena alone walks through actual entrance to existing bar_street_5, then returns via ordinary force_destination. All native body, floor, squeeze, seat and FIFO safety observers retained. Public avoidance handoff and resumption checked. Not mass18 returns, natural attendance, staff fit or artistic acceptance."
	result.details.approach_handoff={"frames":handoff_frames,"outbound_frames":departure_frames,
		"return_frames":return_frames,"public_release":public_release_seen,"max_edge_deviation":max_edge_deviation}
