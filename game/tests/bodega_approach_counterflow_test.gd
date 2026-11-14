extends "res://tests/bodega_queue_motor_test.gd"
## Nearby mechanical counterflow regression. Initial four-body owner transaction
## is inherited; Nadia has one declared original upstream construction placement.
var counterflow_active := false
var counterflow_failure_saved := false

func _snapshot() -> Dictionary:
	var result := super._snapshot()
	for source: String in [get_script().resource_path,scene_file_path,"res://tests/bodega_queue_motor_test.gd","res://tests/BodegaQueueMotorTest.tscn","res://data/orison_v2/nadia_quell_routine.json","res://data/orison_v2/juno_kells_routine.json"]:
		result[source]={"sha256":FileAccess.get_file_as_string(source).replace("\r\n","\n").sha256_text()}
	return result

func _overflow_newcomer() -> void:
	var rhea: Node3D=routes[0]; var state: Dictionary=bodega_admission.debug_snapshot()
	if not _check(rhea.current_id==int(rhea.identities.alignment) and state.service_owner.get("resident","")=="jonah_price"
		and routes[2].current_id==int(routes[2].identities.bodega_resident_wait_rear)
		and routes[3].current_id==int(routes[3].identities.bodega_resident_overflow), "counterflow begins after real service exit/front transfer with rear/overflow still parked"): return
	var route: Node3D=_new_route(); route.resident="nadia_quell"; route.source_path="res://data/orison_v2/nadia_quell_routine.json"; route.world=self
	route.set_physics_process(false); add_child(route); owned.append(route); route.set_physics_process(false)
	route._capsule.radius=.28; route._capsule.height=1.40; route._bar_route=BarRoute.new(); route._bar_route.route=route
	route._doors.append(exterior.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF"))
	# Same registered graph/aliases as the parent; no new waypoint or route.path injection.
	route.identities=rhea.identities.duplicate()
	for point: int in rhea.graph.get_point_ids(): route.graph.add_point(point,rhea.graph.get_point_position(point))
	for point: int in rhea.graph.get_point_ids():
		for other: int in rhea.graph.get_point_connections(point):
			if not route.graph.are_points_connected(point,other): route.graph.connect_points(point,other)
	route.places={"bodega":"bodega","unit":"upstream","alignment":"alignment","upstream":"upstream"}
	route.force_destination="bodega"; route._select_destination()
	route._bodega_route=preload("res://scripts/characters/orison_v2_bodega_route.gd").new()
	if not _check(route._bodega_route.attach(route), "incoming guide attaches unchanged registered approach graph"): return
	var upstream: Dictionary=exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA").nodes[1]
	if not _check(str(upstream.id)=="PAVEMENT_TURN" and upstream.placement.position.distance_to(route.graph.get_point_position(int(route.identities.upstream)))<.001, "birth uses exact original public upstream source point"): return
	var authored: Vector3=upstream.placement.position
	var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(authored+Vector3.UP*.34,authored-Vector3.UP*.5,1))
	if not _check(not hit.is_empty() and hit.normal.y>=.45 and absf(hit.position.y-authored.y)<=.25, "incoming initial feet resolve real native support"): return
	var feet:=Vector3(authored.x,hit.position.y,authored.z)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(route.source_path))
	route.actor=Presentation.new(); route.actor.setup(str(source.name),route.resident,str(source.unit),"res://assets/characters/nadia_quell/nadia_quell.gltf")
	route.actor.externally_driven=true; route.add_child(route.actor); route.current_id=int(route.identities.upstream); route.actor.global_position=feet
	if not _check(route.actor._model!=null and route._bodega_route.bind_actor(), "real incoming actor constructed once at upstream and bound"): return
	routes.append(route); previous[route.resident]=feet
	details.counterflow_scope="real sequential queue setup then opposing public approach; one declared Nadia birth, forced mechanical goals only, no full setup/natural attendance or generalized traffic proof"
	details.queue_scope=details.counterflow_scope; details.motor_scope=details.counterflow_scope
	details.counterflow_start={"physics_frame":Engine.get_physics_frames(),"authored_upstream":authored,"native_feet":feet,
		"floor":str(hit.collider.get_path()),"rhea":rhea.actor.global_position,"nadia":route.actor.global_position,"state":_queue_state()}
	# Both instructions occur in this callback, before another physics frame.
	counterflow_active=true; rhea.force_destination="upstream"; route.set_physics_process(true)
	var deadline:=Time.get_ticks_msec()+60000
	while failures.is_empty() and Time.get_ticks_msec()<deadline:
		if rhea.current_id==int(rhea.identities.upstream) and rhea.path.is_empty() and route.current_id==int(route.identities.bodega_resident_overflow_approach) and route.path.is_empty(): break
		await get_tree().physics_frame
	counterflow_active=false
	_check(rhea.current_id==int(rhea.identities.upstream) and rhea.path.is_empty() and rhea.actor.global_position.distance_to(feet)<.05, "outgoing Rhea ordinarily reaches upstream without passing through incoming body")
	_check(route.current_id==int(route.identities.bodega_resident_overflow_approach) and route.path.is_empty() and route.actor.global_position.distance_to(measured.overflow_approach)<.05, "incoming Nadia ordinarily reaches off-axis overflow approach")
	details.counterflow_end=_queue_state()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if queue_watch:
		for route: Node3D in routes:
			if absf(route.route_speed-1.05)>.00001 or absf(route._capsule.radius-.28)>.00001 or absf(route._capsule.height-1.40)>.00001: _check(false,"counterflow retains full standing profile and ordinary1.05 speed")
	if counterflow_active and not failures.is_empty() and not counterflow_failure_saved:
		counterflow_failure_saved=true; details.counterflow_first_failure={"physics_frame":Engine.get_physics_frames(),"state":_queue_state(),"failures":failures.duplicate()}
