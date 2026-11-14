extends "res://tests/bodega_waiting_geometry_test.gd"
## Sequential measured-path motor/corner proof; no queue/admission authority.
const Motion := preload("res://tests/harukiya_attendance_test.gd")
const EDGES := [["service","interior"],["interior","exterior"],["exterior","alignment"],
	["wait_front","access_front"],["wait_rear","access_rear"],["access_rear","access_front"],
	["access_front","service_turn"],["service_turn","service"],
 ["alignment","overflow_approach"],["overflow_approach","overflow"]]
var campaign_clock := CampaignClock.new()
var adapter: OrisonV2AnchorAdapter
var motor_started := false
var motor_watching := false
var measured: Dictionary = {}
var previous: Dictionary = {}
var parked: Dictionary = {}
var moving_id := ""
var scenario := ""
var due := 0.0
var frames := 0
var minimum_peer := INF
var minimum_player := INF

func _ready() -> void:
	process_physics_priority = 100; adapter = OrisonV2AnchorAdapter.new(self)
	super._ready()

func _snapshot() -> Dictionary:
	var result := super._snapshot()
	for path: String in [get_script().resource_path, scene_file_path, "res://tests/bodega_waiting_geometry_test.gd",
		"res://tests/BodegaWaitingGeometryTest.tscn", "res://tests/harukiya_attendance_test.gd"]:
		result[path] = {"sha256": FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()}
	return result

func _finish() -> void:
	if failures.is_empty() and not motor_started:
		motor_started = true; surveyed = true; _survey()
		for row: Dictionary in details.candidate_standing: measured[str(row.id)] = row.feet
		details.motor_scope = "separate fresh scenarios; real Route1.05m/s/40mm corners with measured test graph and parked real peers; no live service FIFO/opposing door/agenda/full setup proof"
		details.motor_graph={"points":measured.duplicate(),"edges":EDGES}; details.motor_initials=[]
		details.motor_trace = []; details.motor_witnesses = []; details.motor_legs = []
		if failures.is_empty():
			await _scenario({"rhea_sato":"service", "jonah_price":"wait_front", "teresa_vale":"wait_rear"}, "A")
			if failures.is_empty(): await _leg("rhea_sato", "alignment")
			if failures.is_empty(): await _leg("rhea_sato", "overflow_approach")
			if failures.is_empty(): await _leg("rhea_sato", "overflow")
			if failures.is_empty(): await _leg("jonah_price", "service")
			if failures.is_empty(): await _scenario({"rhea_sato":"alignment", "jonah_price":"wait_front", "teresa_vale":"wait_rear"}, "B")
			if failures.is_empty(): await _leg("teresa_vale", "service")
		motor_watching = false
		details.motor_summary = {"physics_frames":frames, "minimum_peer_axis_distance_m":str(minimum_peer),
			"minimum_player_axis_distance_m":str(minimum_player), "completed_legs":details.motor_legs.size(), "all_five_completed":details.motor_legs.size()==5 and failures.is_empty()}
		_check(details.motor_legs.size()==5 and frames>0, "all five ordinary motor legs complete with physics witnesses")
	for route: Node3D in routes: route.set_physics_process(false)
	await super._finish()

func _scenario(starts: Dictionary, label: String) -> void:
	motor_watching = false
	for route: Node3D in routes.duplicate():
		route.set_physics_process(false); owned.erase(route); remove_child(route); route.free()
	routes.clear(); previous.clear(); parked.clear(); moving_id = ""; scenario = label
	await get_tree().physics_frame
	for id: String in IDS:
		var route := Route.new(); route.resident = id; route.world = self; route.set_physics_process(false); add_child(route); owned.append(route); route.set_physics_process(false)
		route._capsule.radius=.28; route._capsule.height=1.40
		route._bar_route=BarRoute.new(); route._bar_route.route=route
		route._doors.append(exterior.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF"))
		for key: String in measured: route._point(key, measured[key]); route.places[key]=key
		for edge: Array in EDGES: route.graph.connect_points(int(route.identities[edge[0]]),int(route.identities[edge[1]]))
		route.current_id=int(route.identities[starts[id]]); route.force_destination=str(starts[id]); route._select_destination()
		var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/%s_routine.json" % id))
		route.actor=Presentation.new(); route.actor.setup(str(source.name),id,str(source.unit),"res://assets/characters/%s/%s.gltf" % [id,id])
		route.actor.externally_driven=true; route.add_child(route.actor); route.actor.global_position=measured[starts[id]]
		_check(route.actor._model!=null, "fresh real presentation "+label+" "+id)
		details.motor_initials.append({"scenario":label,"resident":id,"initial_node":starts[id],"feet":route.actor.global_position,"actor_instance_id":route.actor.get_instance_id(),"node_ids":route.identities.duplicate()})
		routes.append(route); previous[id]=route.actor.global_position; parked[id]=route.actor.global_position
	await get_tree().physics_frame
	motor_watching=true
	for route: Node3D in routes: route.set_physics_process(true)

func _leg(id: String, goal: String) -> void:
	var route: Node3D=routes[IDS.find(id)]; moving_id=id
	var began: Vector3=route.actor.global_position; var deadline:=Time.get_ticks_msec()+30000
	route.force_destination=goal # Only goal seam: owner chooses/plans every actual step.
	while failures.is_empty() and Time.get_ticks_msec()<deadline:
		if route.current_id==int(route.identities[goal]) and route.desired_id==route.current_id and route.path.is_empty(): break
		await get_tree().physics_frame
	var at: Vector3=route.actor.global_position
	var ok: bool =route.current_id==int(route.identities[goal]) and route.path.is_empty() and at.distance_to(measured[goal])<.05
	details.motor_legs.append({"scenario":scenario,"resident":id,"from":began,"goal":goal,"actual":at,
		"current":route.current_id,"desired":route.desired_id,"path":Array(route.path),"blocked":route.blocked_reason,"metres":route.travelled_metres,"ok":ok})
	_check(ok, "normal motor reaches "+scenario+" "+id+" "+goal)
	parked[id]=at; moving_id=""

func _axis_distance(a: Vector3, radius_a: float, height_a: float, b: Vector3, radius_b: float, height_b: float) -> float:
	var vertical:=maxf(0,absf(a.y-b.y)-(height_a*.5-radius_a)-(height_b*.5-radius_b))
	return Vector3(a.x-b.x,vertical,a.z-b.z).length()

func _physics_process(delta: float) -> void:
	if not motor_watching or not failures.is_empty(): return
	frames+=1; due-=delta; var sample: Dictionary={"scenario":scenario,"moving":moving_id,"real_ms":Time.get_ticks_msec(),"physics_delta_s":delta,"actors":{}}
	var space:=get_world_3d().direct_space_state
	for route: Node3D in routes:
		var id: String=route.resident; var at: Vector3=route.actor.global_position
		var witness:=Motion.motion_witness(space,previous[id],at,delta,false)
		if not witness.clear or witness.vertical_m>.00001: details.motor_witnesses.append({"scenario":scenario,"resident":id,"witness":witness})
		if not witness.clear: _check(false,"ordinary supported motion "+id)
		var query:=PhysicsShapeQueryParameters3D.new(); query.shape=route._capsule; query.collision_mask=1
		query.exclude=[player.get_rid()]; query.transform.origin=at+Vector3.UP*.95
		var hits:=space.intersect_shape(query,8)
		if not hits.is_empty(): details.motor_witnesses.append({"resident":id,"at":at,"native_hits":_hit_paths(hits)}); _check(false,"full native motor capsule "+id)
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.03,at-Vector3.UP*.03,1))
		if hit.is_empty() or absf(hit.position.y-at.y)>.003: _check(false,"actual standing support "+id)
		if absf(route.route_speed-1.05)>.00001: _check(false,"unchanged ordinary1.05 speed "+id)
		if id!=moving_id and at.distance_to(parked[id])>.001: _check(false,"parked owner stays stationary "+id)
		var center:=at+Vector3.UP*.95
		var player_gap:=_axis_distance(center,.28,1.40,player._shape.global_position,player._capsule.radius,player._capsule.height)
		minimum_player=minf(minimum_player,player_gap)
		if player_gap<.28+player._capsule.radius-.00001: _check(false,"actual player/body capsule separation "+id)
		for other: Node3D in routes:
			if other==route: continue
			var gap:=_axis_distance(center,.28,1.40,other.actor.global_position+Vector3.UP*.95,.28,1.40)
			minimum_peer=minf(minimum_peer,gap)
			if gap<.56-.00001: _check(false,"full parked/moving peer capsule separation "+id)
		sample.actors[id]={"at":at,"current":route.current_id,"desired":route.desired_id,"path":Array(route.path),
			"blocked":route.blocked_reason,"blocked_seconds":route.blocked_seconds,"floor":route.last_floor,"metres":route.travelled_metres,"motion":witness}
		previous[id]=at
	if due<=0 or not failures.is_empty():
		sample.minimum_peer_m=minimum_peer; sample.minimum_player_m=minimum_player; details.motor_trace.append(sample); due=.1
