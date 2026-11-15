extends "res://tests/harukiya_mass_return_test.gd"
## Read-only observation of the original full18 programme. A diagnostic stop is
## deliberately a failed contract, never a substitute for complete returns.
var diagnostic_tick := 0
var diagnostic_rows: Array[Dictionary] = []

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not watching or not failures.is_empty() or stage != "mass_return": return
	var now := Time.get_ticks_msec()
	if now - diagnostic_tick < 1000: return
	diagnostic_tick = now
	for id: String in ["lena_ortiz", "peter_wren", "mina_vale", "juno_kells"]:
		var route: Node3D = routes[id]
		if route.path.is_empty() or not route._bar_route._gate.is_empty(): continue
		var traffic: Node3D = world.public_traffic
		var at: Vector3 = route.actor.global_position
		var target: Vector3 = route.graph.get_point_position(route.path[0])
		var reply: Dictionary = traffic._proposals.get(route.actor.get_instance_id(), {})
		var row: Dictionary = {"elapsed_s": (now-started)/1000.0, "resident": id,
			"feet": at, "target": target, "current": route.current_id,
			"next": route.path[0], "blocked": route.blocked_reason,
			"blocked_seconds": route.blocked_seconds, "reply": reply.duplicate(true),
			"capacity": route._bar_route.capacity_stop(false), "delta": delta}
		var straight: Vector3 = at + Vector3(target.x-at.x, 0, target.z-at.z).limit_length(delta*route.route_speed)
		row.straight = _native_probe(route, straight)
		if not reply.is_empty():
			var proposed: Vector3 = at + Vector3(reply.velocity).limit_length(route.route_speed)*delta
			row.avoidance = _native_probe(route, proposed)
		row.peers = []
		for peer_id: String in routes:
			if peer_id == id: continue
			var peer: Node3D = routes[peer_id]
			if peer.actor.global_position.distance_to(at) > 1.2: continue
			row.peers.append({"resident": peer_id, "feet": peer.actor.global_position,
				"capacity": peer._bar_route.capacity_stop(false),
				"blocks_capacity_courtesy": route._bar_route.blocks_capacity_courtesy(peer.actor)})
		diagnostic_rows.append(row)
		if diagnostic_rows.size() > 600: diagnostic_rows.pop_front()
	var file := FileAccess.open(directory.path_join("public_return_observation.json"), FileAccess.WRITE)
	if file == null:
		_check(false, "diagnostic observation file must open")
		return
	file.store_string(JSON.stringify({"scope":"Read-only proposal reconstruction; no permits calls or motor changes; not executed-step proof", "rows":diagnostic_rows}, "\t"))
	file.flush()
	var written := file.get_error() == OK
	file.close()
	if not written:
		_check(false, "diagnostic observation file must be written completely")
		return
	if progress_at > 0 and now-progress_at >= 30000:
		_check(false, "diagnostic stop: original return programme has no progress for30s; full acceptance NOT_RUN")

func _decorate_result(result: Dictionary) -> void:
	result.evidence_kind = "diagnostic_observation"
	result.suite = "HarukiyaPublicReturnDiagnostic"
	result.scope = "Read-only reconstructed public avoidance and straight native proposals during the original18 departure/return programme. No actor placement, motor, courtesy or admission changes. Deliberate diagnostic stop after30s without programme progress; never full-return acceptance."
	result.details.public_diagnostic = {"samples":diagnostic_rows.size(),
		"sidecar":"public_return_observation.json", "executed_step_proof":false,
		"limitations":"Queries reconstruct raw proposals rather than post-courtesy actual steps. Cast-only contact may require further collider identification."}

func _hit_record(hit: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["position", "normal", "shape", "face_index"]:
		if hit.has(key): result[key] = hit[key]
	var collider: Object = hit.get("collider")
	if collider is Node: result.collider = str(collider.get_path())
	return result

func _native_probe(route: Node3D, next: Vector3) -> Dictionary:
	# Same support/capsule queries as public_foot_traffic.clear_step, without
	# invoking that stateful method or mutating courtesy/contact timers.
	var at: Vector3 = route.actor.global_position
	var space := route.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(next+Vector3.UP*.34,next-Vector3.UP*.5,1))
	var result := {"next":next, "support":_hit_record(hit)}
	if hit.is_empty(): result.verdict="missing_support"; return result
	if absf(hit.position.y-at.y)>.25: result.verdict="support_rise"; return result
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=route._capsule; query.collision_mask=1; query.exclude=[route.world.player.get_rid()]
	query.transform.origin=at+Vector3.UP*(.25+route._capsule.height*.5)
	query.motion=Vector3(next.x,hit.position.y,next.z)-at
	var cast := space.cast_motion(query)
	result.cast=Array(cast)
	result.center=query.transform.origin; result.motion=query.motion
	result.radius=route._capsule.radius; result.height=route._capsule.height
	query.transform.origin+=query.motion; query.motion=Vector3.ZERO
	result.endpoint_hits=[]
	for overlap: Dictionary in space.intersect_shape(query,8):
		result.endpoint_hits.append(_hit_record(overlap))
	result.verdict="cast" if cast.size()!=2 or cast[0]<1.0 else ("overlap" if not result.endpoint_hits.is_empty() else "clear")
	return result
