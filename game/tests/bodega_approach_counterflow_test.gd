extends "res://tests/bodega_queue_motor_test.gd"
## Nearby mechanical counterflow regression. Initial four-body owner transaction
## is inherited; Nadia has one declared original upstream construction placement.
var counterflow_active := false
var counterflow_failure_saved := false
var courtesy_cues_before := 0
var courtesy_started_frame := -1
var courtesy_pairs_completed := 0
var courtesy_last_frame := -1
var courtesy_pair_clear := true
var counterflow_minimum_gap := INF

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
	courtesy_cues_before = rhea.squeeze.cue_count + route.squeeze.cue_count
	counterflow_active=true; rhea.force_destination="upstream"; route.set_physics_process(true)
	var deadline:=Time.get_ticks_msec()+60000
	while failures.is_empty() and Time.get_ticks_msec()<deadline:
		if rhea.current_id==int(rhea.identities.upstream) and rhea.path.is_empty() and route.current_id==int(route.identities.bodega_resident_overflow_approach) and route.path.is_empty(): break
		await get_tree().physics_frame
	counterflow_active=false
	_check(rhea.current_id==int(rhea.identities.upstream) and rhea.path.is_empty() and rhea.actor.global_position.distance_to(feet)<.05, "outgoing Rhea ordinarily reaches upstream")
	_check(route.current_id==int(route.identities.bodega_resident_overflow_approach) and route.path.is_empty() and route.actor.global_position.distance_to(measured.overflow_approach)<.05, "incoming Nadia ordinarily reaches off-axis overflow approach")
	_check_crossing(rhea, route)
	details.counterflow_completed_courtesy = courtesy_pairs_completed
	details.counterflow_end=_queue_state()

func _check_crossing(rhea: Node3D, incoming: Node3D) -> void:
	_check(courtesy_pairs_completed > 0 and courtesy_started_frame == -1,
			"the opposing residents complete a timed courtesy pass and separate")
	_check(rhea.squeeze.cue_count + incoming.squeeze.cue_count > courtesy_cues_before,
			"the crossing issues a new courtesy cue")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if queue_watch:
		for route: Node3D in routes:
			if absf(route.route_speed-1.05)>.00001 or absf(route._capsule.radius-.28)>.00001 or absf(route._capsule.height-1.40)>.00001: _check(false,"counterflow retains full standing profile and ordinary1.05 speed")
	if counterflow_active and not failures.is_empty() and not counterflow_failure_saved:
		counterflow_failure_saved = true
		var rhea: Node3D = routes[0]
		var nadia: Node3D = routes.back()
		details.counterflow_first_failure = {
			"physics_frame": Engine.get_physics_frames(),
			"state": _queue_state(),
			"failures": failures.duplicate(),
			"rhea_contact": rhea.squeeze._contacts.get(nadia.actor.get_instance_id(), {}).duplicate(),
			"nadia_contact": nadia.squeeze._contacts.get(rhea.actor.get_instance_id(), {}).duplicate(),
			"rhea_cues": rhea.squeeze.cue_count,
			"nadia_cues": nadia.squeeze.cue_count,
			"required_wait_seconds": rhea.squeeze.WAIT,
		}


## Only the two moving participants on the opposing approach can overlap.
## The parent still checks native swept clearance, floor and every other pair.
func _queue_pair_clear(route: Node3D, other: Node3D, gap: float, delta: float) -> bool:
	if not counterflow_active:
		return super._queue_pair_clear(route, other, gap, delta)
	var rhea: Node3D = routes[0]
	var nadia: Node3D = routes.back()
	if not ((route == rhea and other == nadia) or (route == nadia and other == rhea)):
		return super._queue_pair_clear(route, other, gap, delta)
	var frame := Engine.get_physics_frames()
	if courtesy_last_frame == frame:
		return courtesy_pair_clear
	courtesy_last_frame = frame
	counterflow_minimum_gap = minf(counterflow_minimum_gap, gap)
	courtesy_pair_clear = _observe_courtesy(rhea, nadia, gap)
	return courtesy_pair_clear


func _observe_courtesy(rhea: Node3D, nadia: Node3D, gap: float) -> bool:
	if gap >= .56 - .00001:
		if courtesy_started_frame >= 0:
			courtesy_pairs_completed += 1
			courtesy_started_frame = -1
		return true
	var frame := Engine.get_physics_frames()
	if courtesy_started_frame >= 0:
		return frame - courtesy_started_frame < 10 * Engine.physics_ticks_per_second
	var rhea_contact: Dictionary = rhea.squeeze._contacts.get(nadia.actor.get_instance_id(), {})
	var nadia_contact: Dictionary = nadia.squeeze._contacts.get(rhea.actor.get_instance_id(), {})
	var rhea_permitted := _current_permission(rhea_contact, frame, rhea.squeeze.WAIT)
	var nadia_permitted := _current_permission(nadia_contact, frame, nadia.squeeze.WAIT)
	if not (rhea_permitted or nadia_permitted):
		return false
	if rhea.squeeze.cue_count + nadia.squeeze.cue_count <= courtesy_cues_before:
		return false
	courtesy_started_frame = frame
	details.counterflow_courtesy = {"frame": frame, "gap": gap,
			"rhea_contact": rhea_contact.duplicate(), "nadia_contact": nadia_contact.duplicate()}
	return true


static func _current_permission(contact: Dictionary, frame: int, wait_seconds: float) -> bool:
	var age := frame - int(contact.get("frame", -1))
	var seconds := float(contact.get("seconds", 0.0))
	return age >= 0 and age <= 1 and is_finite(seconds) and seconds >= wait_seconds
