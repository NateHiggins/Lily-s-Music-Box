extends "res://tests/bodega_waiting_motor_test.gd"
## Nearby real owner+motor fixture; forced destination seam, not full setup/agenda.
var bodega_admission: Node3D
var exterior_cell: OrisonV2ExteriorCell
const INITIAL_IDS := ["rhea_sato", "jonah_price", "teresa_vale", "juno_kells"]
var queue_started := false
var queue_watch := false
var queue_frames := 0
var queue_minimum := INF

func _snapshot() -> Dictionary:
	var result := super._snapshot()
	for source: String in ["res://tests/bodega_waiting_motor_test.gd", "res://scripts/building/bodega_admission.gd",
			"res://scripts/characters/shared_passage_admission.gd", "res://scripts/characters/orison_v2_bodega_route.gd"]:
		result[source] = {"sha256":FileAccess.get_file_as_string(source).replace("\r\n", "\n").sha256_text()}
	for id: String in ["juno_kells", "nadia_quell"]:
		for suffix: String in [".gltf", ".bin", ".gltf.import"]:
			var source := "res://assets/characters/%s/%s%s"%[id,id,suffix]
			result[source]={"sha256":FileAccess.get_sha256(source) if suffix==".bin" else FileAccess.get_file_as_string(source).replace("\r\n","\n").sha256_text()}
	return result

func _finish() -> void:
	if failures.is_empty() and not queue_started:
		queue_started=true; motor_started=true; surveyed=true; _survey()
		for row: Dictionary in details.candidate_standing: measured[str(row.id)]=row.feet
		details.queue_scope="actual admission owner/resolver, four initial real actors and one incoming newcomer and original normal motor; reduced graph and explicit destinations; no full Route.setup/natural agenda/crowd/player-input acceptance"
		details.queue_initial=[]; details.queue_trace=[]; details.queue_failures=[]
		if failures.is_empty(): await _registered_fixture()
		if failures.is_empty():
			queue_watch=true
			for route: Node3D in routes: route.set_physics_process(true)
			routes[0].force_destination="alignment"
			var deadline:=Time.get_ticks_msec()+40000
			while failures.is_empty() and Time.get_ticks_msec()<deadline:
				if routes[0].current_id==int(routes[0].identities.alignment) and routes[1].current_id==int(routes[1].identities.bodega) \
						and bodega_admission.debug_snapshot().service_owner.get("resident", "")=="jonah_price": break
				await get_tree().physics_frame
			_check(routes[0].current_id==int(routes[0].identities.alignment), "service owner leaves through original centerline")
			_check(bodega_admission.debug_snapshot().service_owner.get("resident", "")=="jonah_price", "actual front FIFO head reaches and publishes service")
			_check(routes[2].current_id==int(routes[2].identities.bodega_resident_wait_rear), "rear waiter retains real assigned station")
			if failures.is_empty(): await _overflow_newcomer()
			details.queue_final=_queue_state()
		queue_watch=false
		details.queue_summary={"physics_frames":queue_frames,"minimum_peer_axis_distance_m":str(queue_minimum)}
		_check(queue_frames>0, "actual queue motor physics witnesses collected")
	await super._finish()

func _registered_fixture() -> void:
	motor_watching=false
	for route: Node3D in routes.duplicate():
		route.set_physics_process(false); owned.erase(route); remove_child(route); route.free()
	routes.clear(); previous.clear(); exterior_cell=exterior
	bodega_admission=preload("res://scripts/building/bodega_admission.gd").new(); add_child(bodega_admission); owned.append(bodega_admission)
	if not _check(bodega_admission.configure(exterior), "actual source-bound bodega owner configures"): return
	for id: String in INITIAL_IDS:
		var route:=Route.new(); route.resident=id; route.world=self; route.set_physics_process(false); add_child(route); owned.append(route); route.set_physics_process(false)
		route._capsule.radius=.28; route._capsule.height=1.40; route._bar_route=BarRoute.new(); route._bar_route.route=route
		route._doors.append(exterior.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF"))
		for name: String in measured: route._point(name, measured[name]); route.places[name]=name
		for edge: Array in EDGES: route.graph.connect_points(int(route.identities[edge[0]]), int(route.identities[edge[1]]))
		for pair: Array in [["service","service_stance"],["alignment","street_alignment"],["exterior","exterior_stance"],["interior","interior_arrival"]]:
			route.graph.set_point_position(int(route.identities[pair[0]]), bodega_admission.position_marker(pair[1]).global_position)
		var upstream: Vector3=exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA").nodes[1].placement.position
		var upstream_id: int=route._point("upstream",upstream); route.places.upstream="upstream"
		route.graph.connect_points(int(route.identities.alignment),upstream_id)
		route.identities.street=upstream_id # Reduced home alias, not the composed building frame.
		route.identities.bodega=route.identities.service; route.identities.bodega_route_2=route.identities.alignment
		route.identities.bodega_route_3=route.identities.exterior; route.identities.bodega_route_4=route.identities.interior
		route.places.bodega="bodega"; route.places.unit="alignment"; route.force_destination="bodega"; route._select_destination(); route.current_id=route.desired_id
		route._bodega_route=preload("res://scripts/characters/orison_v2_bodega_route.gd").new()
		if not _check(route._bodega_route.attach(route), "real guide attaches "+id): return
		var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/%s_routine.json"%id))
		route.actor=Presentation.new(); route.actor.setup(str(source.name),id,str(source.unit),"res://assets/characters/%s/%s.gltf"%[id,id]); route.actor.externally_driven=true; route.add_child(route.actor)
		if not _check(route.actor._model!=null and route._bodega_route.bind_actor(), "real exact actor binds "+id): return
		var initial: Dictionary=route._bodega_route.initial_placement()
		if not _check(initial.get("handled",false) and initial.get("ok",false), "reserved construction station available "+id): return
		route.current_id=int(initial.point_id); route.actor.global_position=initial.feet
		_check(route._bodega_route.initial_arrived(), "actual initial station published "+id)
		details.queue_initial.append({"resident":id,"placement":initial,"actor_instance_id":route.actor.get_instance_id()}); routes.append(route); previous[id]=route.actor.global_position
	await get_tree().physics_frame
	_check(bodega_admission.debug_snapshot().service_owner.get("resident", "")=="rhea_sato", "initial first actual shopper owns service")
	_check(routes.size()==4 and routes[0].actor.global_position.distance_to(routes[1].actor.global_position)>=.60 \
		and routes[1].actor.global_position.distance_to(routes[2].actor.global_position)>=.60, "reserved initial bodies do not overlap")


func _overflow_newcomer() -> void:
	# Free the original departure endpoint through a real authored upstream walk.
	routes[0].force_destination="upstream"
	var deadline:=Time.get_ticks_msec()+30000
	while failures.is_empty() and Time.get_ticks_msec()<deadline:
		if routes[0].current_id==int(routes[0].identities.upstream) and routes[0].path.is_empty(): break
		await get_tree().physics_frame
	if not _check(routes[0].current_id==int(routes[0].identities.upstream), "first departure walks to actual original upstream vertex"): return
	# A fifth real presentation is constructed once at the existing outside mark.
	# It binds normally but does not reconstruct into its desired station.
	var source_route: Node3D=routes[0]
	var route:=Route.new(); route.resident="nadia_quell"; route.world=self; route.set_physics_process(false); add_child(route); owned.append(route); route.set_physics_process(false)
	route._capsule.radius=.28; route._capsule.height=1.40; route._bar_route=BarRoute.new(); route._bar_route.route=route
	route._doors.append(exterior.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF"))
	# Preserve aliases by copying the exact registered graph, not adding duplicate stations.
	route.graph.clear(); route.identities=source_route.identities.duplicate()
	for point: int in source_route.graph.get_point_ids(): route.graph.add_point(point,source_route.graph.get_point_position(point))
	for point: int in source_route.graph.get_point_ids():
		for other: int in source_route.graph.get_point_connections(point):
			if not route.graph.are_points_connected(point,other): route.graph.connect_points(point,other)
	route.places={"bodega":"bodega","unit":"upstream","alignment":"alignment","upstream":"upstream"}
	route.force_destination="bodega"; route._select_destination()
	route._bodega_route=preload("res://scripts/characters/orison_v2_bodega_route.gd").new()
	if not _check(route._bodega_route.attach(route), "newcomer attaches same actual authored graph"): return
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/nadia_quell_routine.json"))
	route.actor=Presentation.new(); route.actor.setup(str(source.name),"nadia_quell",str(source.unit),"res://assets/characters/nadia_quell/nadia_quell.gltf"); route.actor.externally_driven=true; route.add_child(route.actor)
	route.current_id=int(route.identities.bodega_resident_overflow_approach)
	route.actor.global_position=measured.overflow_approach
	if not _check(route.actor._model!=null and route._bodega_route.bind_actor(), "newcomer body constructed and bound once outside"): return
	routes.append(route); previous[route.resident]=route.actor.global_position; route.set_physics_process(true)
	for frame in 45: await get_tree().physics_frame
	var snapshot: Dictionary=bodega_admission.debug_snapshot()
	_check(snapshot.service.queue.size()==3 and snapshot.transit.queue.is_empty() and snapshot.transit.active.is_empty(), "blocked newcomer cannot occupy circulation FIFO head")
	_check(routes[3].current_id==int(routes[3].identities.bodega_resident_overflow), "older overflow waiter retains real station")
	details.blocked_newcomer_before_departure=_queue_state()
	routes[1].force_destination="alignment"
	deadline=Time.get_ticks_msec()+40000
	while failures.is_empty() and Time.get_ticks_msec()<deadline:
		if routes[1].current_id==int(routes[1].identities.alignment) and bodega_admission.debug_snapshot().service_owner.get("resident", "")=="teresa_vale": break
		await get_tree().physics_frame
	_check(routes[1].current_id==int(routes[1].identities.alignment), "newcomer blocked by overflow does not prevent service departure")
	_check(bodega_admission.debug_snapshot().service_owner.get("resident", "")=="teresa_vale", "older rear waiter reaches service before newcomer")
	_check(route.current_id==int(route.identities.bodega_resident_overflow_approach), "newcomer waits outside without walking into overflow body")

func _queue_state() -> Dictionary:
	var state: Dictionary={"owner":bodega_admission.debug_snapshot(),"actors":{}}
	for route: Node3D in routes:
		state.actors[route.resident]={"at":route.actor.global_position,"current":route.current_id,"desired":route.desired_id,"path":Array(route.path),"blocked":route.blocked_reason}
	return state

func _physics_process(delta: float) -> void:
	if not queue_watch or not failures.is_empty(): return
	queue_frames+=1
	var space:=get_world_3d().direct_space_state
	for route: Node3D in routes:
		var at: Vector3=route.actor.global_position; var id: String=route.resident
		var witness:=Motion.motion_witness(space,previous[id],at,delta,false)
		if not witness.clear: details.queue_failures.append({"resident":id,"motion":witness}); _check(false,"ordinary supported queue motion "+id)
		var query:=PhysicsShapeQueryParameters3D.new(); query.shape=route._capsule; query.collision_mask=1; query.exclude=[player.get_rid()]; query.transform.origin=at+Vector3.UP*.95
		var hits:=space.intersect_shape(query,8)
		if not hits.is_empty(): details.queue_failures.append({"resident":id,"at":at,"native_hits":_hit_paths(hits)}); _check(false,"actual queue native capsule "+id)
		var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.03,at-Vector3.UP*.03,1))
		if floor_hit.is_empty() or absf(floor_hit.position.y-at.y)>.003: _check(false,"actual queue supported feet "+id)
		for other: Node3D in routes:
			if other==route: continue
			var gap:=_axis_distance(at+Vector3.UP*.95,.28,1.40,other.actor.global_position+Vector3.UP*.95,.28,1.40)
			queue_minimum=minf(queue_minimum,gap)
			if gap<.56-.00001: _check(false,"queue retains native peer separation "+id)
		previous[id]=at
	if queue_frames%30==0: details.queue_trace.append(_queue_state())
