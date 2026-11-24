extends "res://tests/bodega_queue_motor_test.gd"
## Nearby fresh-source entry reproduction: real Cam/guest/player and production
## exterior paving/lamps. Explicit birth stations/goals, not natural attendance.
const Frontier := preload("res://tests/street_frontier_points.gd")
const Traffic := preload("res://scripts/characters/public_foot_traffic.gd")
var public_traffic: Node3D
var street_lamps: Node3D
var frontier: Dictionary = {}
var frontier_started := false
var player_minimum := INF
var active_player_passes: Dictionary = {}
var completed_player_passes: Dictionary = {}
class OutsideBarRoute extends BarRoute:
	# Only the real outside people predicate; this fixture has no bar/seat registry.
	func clear_step(next: Vector3) -> bool:
		return _people_clear(next)

func _snapshot() -> Dictionary:
	var result := super._snapshot()
	for source: String in ["res://tests/street_frontier_points.gd","res://tests/bodega_queue_motor_test.gd",
		"res://scripts/characters/public_foot_traffic.gd","res://scripts/characters/public_avoidance_proposals.gd",
		"res://tests/bodega_initial_placement_test.gd","res://scripts/building/orison_v2_world_connection.gd",
		"res://scripts/building/orison_v2_front_pavement.gd","res://scripts/building/orison_v2_native_faces.gd",
		"res://scripts/building/orison_v2_street_lamps.gd","res://data/orison_v2/exterior/street_lamps.json",
		"res://data/orison_v2/world_connection.json","res://data/orison_v2_blockout.json",
		"res://data/orison_v2/cam_ortiz_routine.json","res://data/orison_v2/transient_guests_routine.json"]:
		result[source]={"sha256":FileAccess.get_file_as_string(source).replace("\r\n","\n").sha256_text()}
	for id: String in ["cam_ortiz","transient_guests"]:
		for suffix: String in [".gltf",".bin",".gltf.import"]:
			var source: String="res://assets/characters/%s/%s%s"%[id,id,suffix]
			result[source]={"sha256":FileAccess.get_sha256(source) if suffix==".bin" else FileAccess.get_file_as_string(source).replace("\r\n","\n").sha256_text()}
	for source: String in ["res://assets/props/front_pavement.glb","res://assets/props/front_pavement.glb.import"]:
		result[source]={"sha256":FileAccess.get_sha256(source) if source.ends_with(".glb") else FileAccess.get_file_as_string(source).replace("\r\n","\n").sha256_text()}
	return result

func _exterior_dependencies() -> Dictionary:
	var resolver: Variant=preload("res://scripts/building/orison_v2_exterior_spatial_resolver.gd").load_default()
	frontier=Frontier.resolve(resolver)
	if not bool(frontier.get("ok",false)): return {}
	return {"player":player,"geometry_instance_ids":["STREET_ORISON_01","SHOP_BODEGA"],"spatial_resolver":resolver,"geometry_source":frontier.production_geometry}

func _mount_extra_exterior() -> bool:
	exterior_cell=exterior
	var registered:=Node3D.new(); registered.name="ProductionPavingFrame"; add_child(registered); owned.append(registered); registered.transform=frontier.registered_frame
	registered.add_child(preload("res://scripts/building/orison_v2_front_pavement.gd").new())
	street_lamps = preload("res://scripts/building/orison_v2_street_lamps.gd").mount(self)
	return street_lamps != null

func _finish() -> void:
	if failures.is_empty() and not frontier_started:
		frontier_started=true; queue_started=true; motor_started=true; surveyed=true; _survey()
		for row: Dictionary in details.candidate_standing: measured[str(row.id)]=row.feet
		for route: Node3D in routes.duplicate():
			route.set_physics_process(false); owned.erase(route); remove_child(route); route.free()
		routes.clear(); previous.clear()
		# Declared initial standing fixture, before this motor observation starts.
		player.global_position=frontier.player_observed; player.set_physics_process(false)
		bodega_admission=preload("res://scripts/building/bodega_admission.gd").new(); add_child(bodega_admission); owned.append(bodega_admission)
		_check(bodega_admission.configure(exterior),"actual admission owner configures on production geometry")
		public_traffic = Traffic.new()
		if not _check(public_traffic.configure(self, exterior), "public avoidance configures on the actual street frame"):
			public_traffic.free()
			await super._finish()
			return
		add_child(public_traffic)
		owned.append(public_traffic)
		public_traffic.register_lamp_posts(street_lamps)
		details.queue_trace=[]; details.queue_failures=[]; details.frontier_births=[]
		var report:=frontier.duplicate(); report.erase("production_geometry"); details.frontier_sources=report
		details.frontier_scope="nearby fresh actual source street stations; forced Cam bodega goal and guest outside bar waypoint; production paving, lamps and avoidance proposals; stationary full player; no complete world/setup/bar admission/natural attendance proof"
		if failures.is_empty(): _birth("cam_ortiz",frontier.cam_ortiz_street,true)
		if failures.is_empty(): _birth("transient_guests",frontier.transient_guests_street,false)
		await get_tree().physics_frame
		if failures.is_empty():
			queue_watch=true
			for route: Node3D in routes: route.set_physics_process(true)
			var cam_alignment_observed:=false
			var deadline:=Time.get_ticks_msec()+45000
			while failures.is_empty() and Time.get_ticks_msec()<deadline:
				if routes[0].current_id==int(routes[0].identities.bodega_route_2): cam_alignment_observed=true
				if cam_alignment_observed and routes[1].current_id==int(routes[1].identities.bar_street_1): break
				await get_tree().physics_frame
			_check(cam_alignment_observed,"Cam ordinarily clears fixed player and reaches actual shop alignment")
			_check(routes[1].current_id==int(routes[1].identities.bar_street_1),"following guest ordinarily clears entrance to actual outside bar waypoint")
			_check(completed_player_passes.has("cam_ortiz") and active_player_passes.is_empty(),
					"Cam completes the cued pass and both residents separate from the unchanged player")
			details.frontier_player_passes = completed_player_passes.duplicate(true)
			details.frontier_final=_queue_state()
		queue_watch=false
		details.frontier_summary={"physics_frames":queue_frames,"minimum_peer_axis_distance_m":str(queue_minimum),"minimum_player_axis_distance_m":str(player_minimum)}
		_check(queue_frames>0,"frontier ordinary motor witnesses executed")
		details.frontier_avoidance = public_traffic.stats.duplicate()
		_check(int(public_traffic.stats.proposals) > 0, "frontier motor consumes public avoidance proposals")
		_check(public_traffic.solver.errors.is_empty(), "frontier avoidance reports no solver errors")
		public_traffic.shutdown()
	await super._finish()

func _birth(id: String, source_point: Vector3, grocery: bool) -> void:
	var route:=Route.new(); route.resident=id; route.source_path="res://data/orison_v2/%s_routine.json"%id; route.world=self; route.set_physics_process(false); add_child(route); owned.append(route); route.set_physics_process(false)
	route._capsule.radius=.28; route._capsule.height=1.40; route._bar_route=BarRoute.new(); route._bar_route.route=route
	var street: int=route._point("street",source_point)
	if grocery:
		for pair: Array in [["bodega","service_stance"],["bodega_route_2","street_alignment"],["bodega_route_3","exterior_stance"],["bodega_route_4","interior_arrival"]]:
			var row: Dictionary=exterior.spatial_resolver.resolve_placement("SHOP_BODEGA",pair[1]); route._point(pair[0],row.position)
		var upstream: Vector3=exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA").nodes[1].placement.position
		route._point("bodega_route_1",upstream)
		for edge: Array in [["street","bodega_route_1"],["bodega_route_1","bodega_route_2"],["bodega_route_2","bodega_route_3"],["bodega_route_3","bodega_route_4"],["bodega_route_4","bodega"]]: route.graph.connect_points(int(route.identities[edge[0]]),int(route.identities[edge[1]]))
		route.places.bodega="bodega"; route.force_destination="bodega"
		route._doors.append(exterior.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF"))
		route._bodega_route=preload("res://scripts/characters/orison_v2_bodega_route.gd").new()
		if not _check(route._bodega_route.attach(route),"actual public-turn guide attaches Cam"): return
	else:
		route._bar_route=OutsideBarRoute.new(); route._bar_route.route=route
		route._point("bar_street_0",frontier.bar_stage0); route._point("bar_street_1",frontier.bar_stage1)
		route.graph.connect_points(street,int(route.identities.bar_street_0)); route.graph.connect_points(int(route.identities.bar_street_0),int(route.identities.bar_street_1))
		route.places.outside_bar="bar_street_1"; route.force_destination="outside_bar"
	route._select_destination(); route.current_id=street
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(route.source_path))
	route.actor=Presentation.new(); route.actor.setup(str(source.name),id,str(source.unit),"res://assets/characters/%s/%s.gltf"%[id,id]); route.actor.externally_driven=true; route.add_child(route.actor)
	var support:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(source_point+Vector3.UP*.34,source_point-Vector3.UP*.5,1))
	if not _check(not support.is_empty(),"real native birth support "+id): return
	route.actor.global_position=Vector3(source_point.x,support.position.y,source_point.z)
	_check(route.actor._model!=null,"actual presentation loaded "+id)
	if grocery: _check(route._bodega_route.bind_actor(),"Cam exact actor binds admission")
	routes.append(route); previous[id]=route.actor.global_position
	details.frontier_births.append({"resident":id,"source":source_point,"actual":route.actor.global_position,"actor_instance_id":route.actor.get_instance_id()})

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not queue_watch or not failures.is_empty(): return
	for route: Node3D in routes:
		var gap:=_axis_distance(route.actor.global_position+Vector3.UP*.95,.28,1.40,player._shape.global_position,player._capsule.radius,player._capsule.height)
		player_minimum=minf(player_minimum,gap)
		if not _observe_player_pass(route, gap):
			_check(false, "any player overlap follows an authorized, cued pass: " + str(route.resident))
		if absf(route.route_speed-1.05)>.00001: _check(false,"frontier retains normal1.05 speed")

## Only the player contact is eligible for this exception. The parent still
## checks every resident pair and the supported, native capsule sweep.
func _observe_player_pass(route: Node3D, gap: float) -> bool:
	var id := str(route.resident)
	var frame := Engine.get_physics_frames()
	if gap >= route._capsule.radius + player._capsule.radius - .00001:
		if active_player_passes.has(id):
			var witness: Dictionary = active_player_passes[id]
			witness["separated_frame"] = frame
			completed_player_passes[id] = witness
			active_player_passes.erase(id)
		return true
	if active_player_passes.has(id):
		return frame - int(active_player_passes[id].frame) < 10 * Engine.physics_ticks_per_second
	var contact: Dictionary = route.squeeze._contacts.get(player.get_instance_id(), {})
	var age := frame - int(contact.get("frame", -1))
	var seconds := float(contact.get("seconds", 0.0))
	if age < 0 or age > 1 or not is_finite(seconds) or seconds < route.squeeze.WAIT:
		return false
	if route.squeeze.cue_count <= 0 or not is_instance_valid(route.actor.get_node_or_null("PassingCourtesy")):
		return false
	active_player_passes[id] = {"frame": frame, "contact": contact.duplicate(), "first_gap_m": gap,
			"cue_count": route.squeeze.cue_count}
	return true
