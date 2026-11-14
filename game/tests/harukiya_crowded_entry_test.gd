extends "res://tests/harukiya_roster_intake_test.gd"
## DRAFT: original eighteen-owner construction; two real entry-descent
## opposing journeys. No natural attendance or mass-eighteen-flow claim.
## Observer adapted from res://tests/harukiya_crowded_holding_test.gd;
## kept explicit because its participant constants/safety checks are not virtual.
const OBSERVER_SOURCE := "res://tests/harukiya_crowded_holding_test.gd"
const PassageObservation := preload("res://tests/harukiya_passage_observation.gd")
const PARTICIPANTS := ["nadia_quell","malcolm_reed"]
var squeeze_witness := preload("res://tests/harukiya_squeeze_witness.gd").new()
var entry_opposition_seen := false
const PROGRAMME_SECONDS := 240.0
const PHASE_CEILING_SECONDS := 90.0
const ResidentBase := preload("res://scripts/characters/orison_v2_resident_route.gd")
const OpeningState := preload("res://scripts/game/prologue_state.gd")
const TARGET := {"utc_unix_seconds":1876183200,"local_bias_minutes":-300,"local_zone":"Fixed EST fixture"}
const MAX_NEARBY_METRES := 6.0
const SETTLE_SECONDS := 30.0
var clock := CampaignClock.new()
var births: Dictionary={}
var actor_owners: Dictionary={}
var retained: Array[Dictionary]=[]
var staff: Array[Dictionary]=[]
var original_hash: String
var logger
var finishing:=false
var safety_started:=false
var settle_started:=0
var last_trace:=0
var programme_started:=0
var requested_goals: Dictionary={}
var entry_door: DoorProp
var entry_door_id := 0
var direction_admissions: Dictionary={}
var progress_at:=0
var progress_positions: Dictionary={}
var progress_signature:=""
var progress_warning:=false

func _expected() -> Array:
	var result: Array=ResidentBase.ROUTES.keys(); result.append("mina_vale"); return result

func _born(node: Node) -> void:
	if not is_instance_valid(world) or node.get_parent()!=world or not node is ResidentBase: return
	var id:=str(node.resident)
	if not _check(id in _expected() and not births.has(id) and node.actor==null and int(node.current_id)==-1,
		"exact original route before actor construction "+id): return
	births[id]={"owner":weakref(node),"owner_id":node.get_instance_id(),"actor_before":null,"current_before":int(node.current_id),"script":node.get_script().resource_path}
	# Existing test hook only, before the original setup creates this body.
	node.force_destination="harukiya_bar"

func _disconnect_birth_hook() -> void:
	if get_tree().node_added.is_connected(_born): get_tree().node_added.disconnect(_born)

func _run() -> void:
	directory=OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory)!=OK: get_tree().quit(2); return
	prior_data=RealityState.data; original_hash=JSON.stringify(prior_data).sha256_text()
	prior_mode=GameBoot.launch_mode; prior_mouse=Input.mouse_mode; prior_frozen=CampaignTime._frozen_for_tests
	logger=preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(logger)
	initial_inputs=_inputs()
	contracts.entry_descent_opposition={"executed":false,"status":"NOT_RUN"}
	contracts.physical_returns_and_queue_drain={"executed":false,"status":"NOT_RUN"}
	details.goal_requests=[]; details.phase_budgets=[]; details.no_progress=[]; details.released_departures={}
	for key: String in ["SCHEDULE","SCHEDULE_DAY","SCHEDULE_DOY","SCHEDULE_FIRST_SAT","SCHEDULE_MINUTE","AGENDA","CAMPAIGN_TIME_FREEZE"]:
		_check(OS.get_environment(key).is_empty(),"no inherited selection/time override "+key)
	if not failures.is_empty(): await _finish(); return
	preview_owned=RealityState.begin_preview_campaign(self)
	if not _check(preview_owned,"exclusive nonpersistent preview campaign"): await _finish(); return
	CampaignTime.set_frozen_for_tests(true); GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var opening:=OpeningState.request_skip(OpeningState.initial())
	for index in OpeningState.PHASES.size()-1:
		var phase: String=OpeningState.PHASES[index]
		if phase=="companion_crossing": opening=OpeningState.applied(opening,"companion_materialized")
		if phase=="temporal_command": opening=OpeningState.with_target(opening,TARGET)
		if phase=="temporal_synchronization": break
		opening=OpeningState.advance(opening,OpeningState.PHASES[index+1])
	RealityState.data.prologue=opening
	if not _check(clock.bind_state() and clock.apply_prologue_destination() and clock.loop_calendar_active(),"existing opening owner supplies private campaign clock"): await _finish(); return
	var info:=clock.day_info()
	if not _check(int(info.year)==1929 and int(info.month)==6 and int(info.day_of_month)==14 and str(info.day)=="fri" and absf(clock.minute_of_day()-1260)<.00001,"declared frozen pre-death June14 Friday21:00"): await _finish(); return
	details.context={"opening_target":TARGET,"civil":info,"minute":clock.minute_of_day(),"construction":"existing force_destination supplied before original actor birth; not natural attendance"}
	world=Runtime.instantiate(); get_tree().node_added.connect(_born); add_child(world); _disconnect_birth_hook()
	if not _check(not world.startup_failed,"actual production RuntimeRoot starts"): await _finish(); return
	if not _collect_construction(): await _finish(); return
	if not _check(DisplayServer.get_name()!="headless","native rendered backend retains actual loaded models"): await _finish(); return
	stage="crowd_construction_and_seating"; watching=true; safety_started=true; settle_started=Time.get_ticks_msec()
	while failures.is_empty() and Time.get_ticks_msec()-settle_started<int(SETTLE_SECONDS*1000):
		if motion_frames>=3 and _all_occupied(): break
		await get_tree().physics_frame
	watching=false
	_check(failures.is_empty() and motion_frames>=3 and _all_occupied(),"all eighteen exact owned places physically settle within30s")
	details.prepared_crowd=_crowd_snapshot()
	_contract("crowded_construction_and_seating",failures.is_empty())
	if failures.is_empty():
		watching=true
		await _opposition_programme()
	watching=false; details.final_crowd=_crowd_snapshot()
	_contract("continuous_safety",safety_started and motion_frames>=3 and failures.is_empty())
	await _finish()

func _collect_construction() -> bool:
	_check(births.size()==18 and world.resident_routes.size()==17 and is_instance_valid(world.mina_routine),"exact eighteen existing owners received pre-birth input")
	routes=world.resident_routes.duplicate(); routes["mina_vale"]=world.mina_routine
	var inspection: Dictionary=Registration.inspect(world); details.registration=inspection
	for row: Dictionary in inspection.checks: _check(bool(row.ok),str(row.label))
	details.construction={}
	for id: String in _expected():
		var route: Node3D=routes.get(id)
		if not _check(is_instance_valid(route) and births.has(id) and births[id].owner.get_ref()==route and is_instance_valid(route.actor),"same production route and actual body "+id): continue
		actor_owners[route.actor.get_instance_id()]=route
		var place: Dictionary=world.bar_region.resident_places.preferred(id)
		var target: int=int(route._bar_route._approach_id)
		var path: PackedInt64Array=route.graph.get_id_path(route.current_id,target)
		var metres: float=route.actor.global_position.distance_to(route.graph.get_point_position(route.current_id))
		for i in range(1,path.size()): metres+=route.graph.get_point_position(path[i-1]).distance_to(route.graph.get_point_position(path[i]))
		var count:=0
		for body: Node in get_tree().get_nodes_in_group("animated_residents"):
			if world.is_ancestor_of(body) and str(body.get("resident_id"))==id: count+=1
		_check(count==1 and route.actor._model!=null and route.actor.is_visible_in_tree() and not route.outside,"one visible original loaded model "+id)
		_check(route.is_physics_processing() and route.can_process() and route.destination=="harukiya_bar" and route.force_destination=="harukiya_bar","actual active production owner consumes declared construction target "+id)
		_check(route.desired_id==target and path.size()>0 and metres<=MAX_NEARBY_METRES,"original construction is nearby own approach within6m "+id)
		_check(absf(route._capsule.radius-.28)<.000001 and absf(route._capsule.height-1.40)<.000001 and absf(route.route_speed-1.05)<.000001,"unchanged original standing capsule and speed "+id)
		last[id]={"at":route.actor.global_position,"transition":str(route._bar_route._transition)}
		details.construction[id]={"owner_id":route.get_instance_id(),"actor_id":route.actor.get_instance_id(),"prebirth_actor_null":true,"prebirth_current_id":births[id].current_before,"route_script":route.get_script().resource_path,"source_path":route.source_path,"model":route.actor.model_path,"current":route.current_id,"current_name":route.identities.find_key(route.current_id),"desired":route.desired_id,"desired_name":route.identities.find_key(route.desired_id),"feet":route.actor.global_position,"fallback_metres":metres,"own_seat":place.get("seat_id","")}
	for body: Node3D in get_tree().get_nodes_in_group("animated_residents"):
		if world.is_ancestor_of(body): retained.append({"body":weakref(body),"id":body.get_instance_id(),"path":str(body.get_path()),"visible":body.is_visible_in_tree()})
	var cast:=world.bar_region.actors.get_node_or_null("HarukiyaCast")
	if _check(is_instance_valid(cast) and bool(cast.ready_ok),"actual original Harukiya staff owner retained"):
		for id: String in ["stacy","lily"]:
			var body: Node3D=cast.actors.get(id)
			if not _check(is_instance_valid(body) and bool(body.ready_ok) and body.is_visible_in_tree(),"actual staff on-shift model present "+id): continue
			staff.append({"body":weakref(body),"id":body.get_instance_id(),"resident":id,"path":str(body.get_path()),"at":body.global_position,"script":body.get_script().resource_path,"capsule_profile":false})
	details.staff_scope="Original Stacy/Lily CastModelPresentation nodes retained. They have no collision/profile and are not in animated_residents; no invented staff capsules or full20/21-cast physical/mesh-fit claim."
	details.staff_initial=[]
	for item: Dictionary in staff:
		var record:=item.duplicate(); record.erase("body"); details.staff_initial.append(record)
	return failures.is_empty()

func _body(route: Node3D) -> Dictionary:
	# Occupied phase alone must never shrink standing Mina's physical envelope.
	var seated: bool=route.actor.mina_animation==null and (route.actor._loop_seated() or not str(route._bar_route._transition).is_empty())
	var shape: CapsuleShape3D=route._bar_route._torso if seated else route._capsule
	return {"seated":seated,"shape":shape,"center":route.actor.global_position+Vector3.UP*(route._bar_route.PROVISIONAL_SEATED_SUPPORT+.52 if seated else .25+shape.height*.5)}

func _all_occupied() -> bool:
	if routes.size()!=18: return false
	for id: String in routes:
		var route: Node3D=routes[id]; var place: Dictionary=world.bar_region.resident_places.preferred(id)
		if str(route._bar_route.visit.phase())!="occupied" or not str(route._bar_route._transition).is_empty(): return false
		if not _exact_owner(world.seat_gestures.taken.get(str(place.seat_id),{}),route.actor): return false
		if id=="mina_vale":
			if route.actor.mina_animation==null or route.actor._loop_seated() or route.actor.global_position.distance_to(route.graph.get_point_position(route._bar_route._approach_id))>.04: return false
		else:
			if not route.actor._loop_seated() or route.actor.global_position.distance_to(place.marker.global_position-Vector3.UP*route._bar_route.PROVISIONAL_SEATED_SUPPORT)>.001: return false
	return true

func _fail_safety(label: String, evidence: Dictionary) -> void:
	if not details.has("first_safety_failure"): details.first_safety_failure={"label":label,"evidence":evidence,"state":_crowd_snapshot()}
	_check(false,label)

func _physics_process(delta: float) -> void:
	if not watching or not failures.is_empty(): return
	motion_frames+=1
	for item: Dictionary in retained:
		var body:=item.body.get_ref() as Node3D
		if not is_instance_valid(body) or body.is_queued_for_deletion() or body.is_visible_in_tree()!=bool(item.visible):
			_fail_safety("original bystander retained with original visibility",{"original":item.path}); return
	for item: Dictionary in staff:
		var body:=item.body.get_ref() as Node3D
		if not is_instance_valid(body) or not body.is_visible_in_tree(): _fail_safety("original staff remains present",{"resident":item.resident}); return
	for id: String in routes:
		var route: Node3D=routes[id]; var at: Vector3=route.actor.global_position; var transition:=str(route._bar_route._transition)
		if not route.is_physics_processing() or not route.can_process() or route.outside or not _goal_allowed(id,route) or absf(route.route_speed-1.05)>.000001:
			_fail_safety("all actual mechanical bar owners remain active and unchanged",{"resident":id}); return
		if programme_started>0 and id not in PARTICIPANTS and (str(route._bar_route.visit.phase())!="occupied" or not transition.is_empty()):
			_fail_safety("sixteen nonparticipants retain their occupied crowded-bar places",{"resident":id}); return
		var witness:=Attendance.motion_witness(world.get_world_3d().direct_space_state,last[id].at,at,delta,not transition.is_empty() or not str(last[id].transition).is_empty())
		if not bool(witness.clear): _fail_safety("continuous supported native movement",{"resident":id,"witness":witness}); return
		last[id]={"at":at,"transition":transition}
		var body:=_body(route); var hits:=_world_hits(route,bool(body.seated))
		if not hits.is_empty(): _fail_safety("actual native standing or seated capsule",{"resident":id,"seated":body.seated,"hits":hits,"at":at}); return
		var player_overlap := _capsule_overlap(body.center,body.shape.radius,body.shape.height,world.player._shape.global_position,world.player._capsule.radius,world.player._capsule.height)
		var player_witness: Dictionary = squeeze_witness.observe_pair(id+"|player",route,route.actor,world.player,world.player,player_overlap,delta)
		if not player_witness.ok: _fail_safety("player/resident overlap must be timed ordinary passage",player_witness); return
		for other: Node3D in get_tree().get_nodes_in_group("animated_residents"):
			if other==route.actor or not other.is_visible_in_tree(): continue
			var peer: Dictionary={}
			if actor_owners.has(other.get_instance_id()):
				if other.get_instance_id()<route.actor.get_instance_id(): continue
				peer=_body(actor_owners[other.get_instance_id()])
			else:
				var collision:=other.get_node_or_null("Body/CollisionShape3D") as CollisionShape3D
				if collision==null:
					for child in other.find_children("*","CollisionShape3D",true,false):
						if child.get_parent().name=="Body" and child.shape is CapsuleShape3D: collision=child; break
				if collision==null or not collision.shape is CapsuleShape3D: _fail_safety("actual bystander capsule available",{"path":str(other.get_path())}); return
				peer={"center":collision.global_position,"shape":collision.shape}
			var overlapping := _capsule_overlap(body.center,body.shape.radius,body.shape.height,peer.center,peer.shape.radius,peer.shape.height)
			var other_route: Node3D = actor_owners.get(other.get_instance_id())
			var witness_pair: Dictionary = squeeze_witness.observe_pair(str(route.actor.get_instance_id())+"|"+str(other.get_instance_id()),route,route.actor,other_route,other,overlapping,delta)
			if not witness_pair.ok: _fail_safety("resident overlap must be timed ordinary passage",witness_pair); return
		if not str(route._bar_route.visit.phase()).is_empty():
			var seat:=str(world.bar_region.resident_places.preferred(id).seat_id)
			if not _exact_owner(world.seat_gestures.taken.get(seat,{}),route.actor): _fail_safety("exact shared seat owner",{"resident":id,"seat":seat}); return
	var coverage: Dictionary = squeeze_witness.finish_frame()
	if not coverage.ok: _fail_safety("continuous squeeze observation",coverage); return
	if not _observe_passages(): return
	if Time.get_ticks_msec()-last_trace>=250:
		_observe_progress()
		details.trace.append(_crowd_snapshot()); last_trace=Time.get_ticks_msec()

func _crowd_snapshot() -> Dictionary:
	var result: Dictionary={"elapsed_s":(Time.get_ticks_msec()-started)/1000.0,"stage":stage,"actors":{},"passages":_passage_snapshot(),"entry_opposition_seen":entry_opposition_seen,"no_progress_s":(Time.get_ticks_msec()-progress_at)/1000.0 if progress_at>0 else 0.0}
	for id: String in routes:
		var route: Node3D=routes[id]
		if not is_instance_valid(route) or not is_instance_valid(route.actor): continue
		result.actors[id]={"owner_id":route.get_instance_id(),"actor_id":route.actor.get_instance_id(),"at":route.actor.global_position,"current":route.current_id,"desired":route.desired_id,"path":Array(route.path),"phase":route._bar_route.visit.phase(),"transition":route._bar_route._transition,"clip_seated":route.actor._loop_seated(),"mina_standing":route.actor.mina_animation!=null,"blocked":route.blocked_reason,"blocked_seconds":route.blocked_seconds,"last_floor":route.last_floor,"metres":route.travelled_metres,"destination":route.destination,"requested":route.force_destination,"gate":route._bar_route._gate.duplicate(true)}
	result["squeeze_episodes"] = squeeze_witness.snapshot()
	result["player"] = {"feet":world.player.global_position,"physics":world.player.is_physics_processing(),"mask":world.player.collision_mask}
	return result

func _goal_allowed(id: String, route: Node3D) -> bool:
	if not requested_goals.has(id): return route.destination=="harukiya_bar" and route.force_destination=="harukiya_bar"
	return id in PARTICIPANTS and route.force_destination==str(requested_goals[id]) and route.destination in ["unit","harukiya_bar"]

func _request_goal(id: String, goal: String) -> bool:
	if not _check(id in PARTICIPANTS and goal in ["unit","harukiya_bar"] and routes[id].places.has(goal),"only explicit existing participant destination requested "+id+"/"+goal): return false
	requested_goals[id]=goal
	routes[id].force_destination=goal
	details.goal_requests.append({"resident":id,"goal":goal,"state":_crowd_snapshot()})
	return true

func _passage(route: Node3D) -> Dictionary:
	for passage: Dictionary in route._bar_route._passages:
		if str(passage.id)=="entry_descent": return passage
	return {}

func _point_reached(id: String, name: String) -> bool:
	var route: Node3D=routes[id]; var point: int=int(route.identities.get(name,-1))
	if point<0 or route.current_id!=point or not str(route._bar_route.visit.phase()).is_empty() or not str(route._bar_route._transition).is_empty(): return false
	var gap: Vector3=route.actor.global_position-route.graph.get_point_position(point)
	return Vector2(gap.x,gap.z).length()<.05 and absf(gap.y)<.3 and not world.bar_region.resident_places.has_admission("entry_descent",id,route.actor)

func _queue_drained() -> bool:
	for value: Dictionary in world.bar_region.resident_places._passages.values():
		if not value.active.is_empty() or not value.queue.is_empty(): return false
	for id: String in PARTICIPANTS:
		if not routes[id]._bar_route._gate.is_empty(): return false
	return true

func _entry_active(id: String, outward: bool) -> bool:
	var route: Node3D=routes[id]; var passage:=_passage(route)
	return world.bar_region.resident_places.has_admission("entry_descent",id,route.actor) and int(route._bar_route._gate.get("exit",-1))==int(passage.a if outward else passage.b)

func _opposition_programme() -> void:
	stage="player_refuge"
	var route: Node3D=routes.nadia_quell
	world.player.set_mouse_released(false)
	# Original player walks from original arrival, no reconstructed start.
	var approach: PackedInt64Array=route.graph.get_id_path(int(route.identities.street),int(route.identities.bar_pool_interaction))
	if not _check(not approach.is_empty(),"connected original-player refuge route"): return
	for point: int in approach:
		if not await _walk_player(route.graph.get_point_position(point)): return
	entry_door=world.bar_region.doors.get("F01_BAR_RED_DOOR") as DoorProp
	if not _check(is_instance_valid(entry_door),"original production entry door exists"): return
	entry_door_id=entry_door.get_instance_id()
	for id: String in PARTICIPANTS:
		if not _check(routes[id]._doors.has(entry_door),"ordinary route owns original entry door "+id): return
	programme_started=Time.get_ticks_msec()
	contracts.entry_descent_opposition={"executed":true,"status":"FAIL"}
	contracts.physical_returns_and_queue_drain={"executed":true,"status":"FAIL"}
	if not _request_goal("nadia_quell","unit"): return
	if not await _wait_phase("nadia_outward_admitted",func(): return _entry_active("nadia_quell",true),[{"resident":"nadia_quell","target":"bar_entry_outside","transitions":1,"extra_crossings":0}]): return
	if not _request_goal("malcolm_reed","unit"): return
	# Nadia clears the real passage, then continues around the exterior crates.
	# Malcolm's ordinary approach/seat departure occurs while she is crossing.
	if not await _wait_phase("nadia_reaches_exterior_sidewalk",func(): return _point_reached("nadia_quell","bar_entry_sidewalk"),[{"resident":"nadia_quell","target":"bar_entry_sidewalk","transitions":0,"extra_crossings":0}]): return
	if not _request_goal("nadia_quell","harukiya_bar"): return
	if not await _wait_phase("actual_opposed_entry_request",func(): return entry_opposition_seen,[{"resident":"nadia_quell","target":"bar_entry_hold_outer_01","transitions":0,"extra_crossings":1},{"resident":"malcolm_reed","target":"bar_entry_outside","transitions":1,"extra_crossings":1}]): return
	_contract("entry_descent_opposition",true)
	if not await _wait_phase("malcolm_physically_clears_exterior",func(): return _point_reached("malcolm_reed","bar_entry_sidewalk"),[{"resident":"malcolm_reed","target":"bar_entry_sidewalk","transitions":0,"extra_crossings":1}]): return
	if not _request_goal("malcolm_reed","harukiya_bar"): return
	var plans: Array[Dictionary]=[]
	for id: String in PARTICIPANTS:
		plans.append({"resident":id,"target":str(routes[id].identities.find_key(routes[id]._bar_route._approach_id)),"transitions":1,"extra_crossings":1})
	if not await _wait_phase("all_original_eighteen_returned",func(): return _all_occupied() and _queue_drained(),plans): return
	for id: String in PARTICIPANTS:
		for direction: String in ["out","in"]:
			_check(direction_admissions.has(id+":"+direction),"actual directed entry admission "+id+"/"+direction)
	_check(squeeze_witness.snapshot().active.is_empty(),"all squeeze episodes separate")
	_contract("physical_returns_and_queue_drain",failures.is_empty() and _all_occupied() and _queue_drained())

func _walk_player(goal: Vector3) -> bool:
	var player: PlayerController=world.player
	var initial:=player.global_position
	var seconds:=minf(30.,initial.distance_to(goal)/player.WALK+10.)
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline and failures.is_empty():
		var offset:=goal-player.global_position;offset.y=0
		if offset.length()<.075 and absf(player.global_position.y-goal.y)<.24:break
		var heading:=atan2(-offset.x,-offset.z)
		var turn:=wrapf(heading-player.rotation.y,-PI,PI)
		player.rotation.y+=clampf(turn,-.06,.06);player.camera.rotation=Vector3.ZERO
		if absf(turn)>.18:Input.action_release("move_forward")
		else:Input.action_press("move_forward",clampf(offset.length()/.3,.20,1.))
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var gap:=goal-player.global_position
	var ok:=Vector2(gap.x,gap.z).length()<.10 and absf(gap.y)<.24 and PlayerMotor._service_collision_valid(player) and player.is_physics_processing()
	if not details.has("player_legs"):details.player_legs=[]
	details.player_legs.append({"from":initial,"goal":goal,"actual":player.global_position,"budget_s":seconds,"ok":ok})
	return _check(ok,"original player completes bounded native directional-input leg")

func _phase_budget(plans: Array[Dictionary]) -> float:
	var maximum:=0.0; var measurements: Array[Dictionary]=[]
	for plan: Dictionary in plans:
		var route: Node3D=routes[str(plan.resident)]; var target: int=int(route.identities.get(str(plan.target),-1))
		if not _check(target>=0,"budget target is an existing graph point "+str(plan.target)): return 0.0
		var from: int=int(route.current_id)
		var distance: float=route.actor.global_position.distance_to(route.graph.get_point_position(from))
		# Retarget preserves a partly traversed edge. Budget that actual first leg.
		if distance>.05 and not route.path.is_empty() and str(route._bar_route._transition).is_empty() and not route.actor._loop_seated():
			from=int(route.path[0]); distance=route.actor.global_position.distance_to(route.graph.get_point_position(from))
		var path: PackedInt64Array=route.graph.get_id_path(from,target)
		if not _check(not path.is_empty(),"budget follows connected actual graph "+str(plan.resident)): return 0.0
		for i in range(1,path.size()): distance+=route.graph.get_point_position(path[i-1]).distance_to(route.graph.get_point_position(path[i]))
		var passage:=_passage(route); var crossing:=0.0
		if not _check(not passage.is_empty(),"existing entry-descent passage available for budget"): return 0.0
		for i in range(1,passage.path.size()): crossing+=route.graph.get_point_position(passage.path[i-1]).distance_to(route.graph.get_point_position(passage.path[i]))
		var queue: Dictionary=world.bar_region.resident_places._passages.entry_descent
		var ahead: int=queue.queue.size()+(0 if queue.active.is_empty() else 1)+int(plan.extra_crossings)
		var seconds: float=distance/1.05+float(plan.transitions)*route._bar_route.SEAT_TRANSITION_SECONDS+float(ahead)*(crossing+.75)/1.05+30.0
		maximum=maxf(maximum,seconds)
		measurements.append({"resident":plan.resident,"from":from,"target":target,"distance_m":distance,"speed":1.05,"seat_transitions":plan.transitions,"crossing_m":crossing,"queued_or_active_plus_planned":ahead,"clearance_allowance_m":.75,"obstruction_margin_s":30,"uncapped_s":seconds})
	var budget:=minf(maximum,PHASE_CEILING_SECONDS)
	details.phase_budgets.append({"stage":stage,"plans":measurements,"budget_s":budget,"phase_cap_s":PHASE_CEILING_SECONDS,"programme_remaining_s":PROGRAMME_SECONDS-(Time.get_ticks_msec()-programme_started)/1000.0})
	return budget

func _wait_phase(name: String, predicate: Callable, plans: Array[Dictionary]) -> bool:
	stage=name; progress_at=Time.get_ticks_msec(); progress_positions.clear(); progress_signature=""; progress_warning=false
	var budget:=_phase_budget(plans); var began:=Time.get_ticks_msec()
	while failures.is_empty():
		if (Time.get_ticks_msec()-programme_started)/1000.0>=PROGRAMME_SECONDS or (Time.get_ticks_msec()-began)/1000.0>=budget:
			details.deadline_failure={"phase":name,"budget_s":budget,"state":_crowd_snapshot()}; return _check(false,"finite actual phase/programme deadline "+name)
		if predicate.call():
			details.trace.append(_crowd_snapshot()); return _check(true,"physical phase completed "+name)
		await get_tree().physics_frame
	return false

func _entry_record(entry: Dictionary) -> Dictionary:
	if entry.is_empty(): return {}
	var owner: Object=entry.owner.get_ref() if entry.get("owner") is WeakRef else null
	return {"resident":str(entry.get("resident","")),"owner_id":owner.get_instance_id() if is_instance_valid(owner) else 0,"slot":int(entry.get("slot",-1))}

func _passage_snapshot() -> Dictionary:
	var result: Dictionary={}
	if not is_instance_valid(world) or not is_instance_valid(world.bar_region) or not is_instance_valid(world.bar_region.resident_places): return result
	for id: String in world.bar_region.resident_places._passages:
		var value: Dictionary=world.bar_region.resident_places._passages[id]; var queue: Array=[]
		for entry: Dictionary in value.queue: queue.append(_entry_record(entry))
		result[id]={"active":_entry_record(value.active),"queue":queue}
	return result

## A schedule reversal can release a completed crossing and acquire its reverse
## in one physics tick. Only that exact endpoint transition starts a new slot
## lifetime; queued owners and mid-crossing owners must retain their slots.
func _completed_reentry(name: String, id: String, route: Node3D, value: Dictionary, record: Dictionary) -> bool:
	var old: Dictionary = passage_before.get(name,{})
	var prior: Dictionary = old.get("gate",{})
	var current: Dictionary = route._bar_route._gate
	if str(old.get("active","")) != id or str(value.active.get("resident","")) != id: return false
	if not old.get("queue",[]).is_empty() or not value.queue.is_empty(): return false
	if prior.is_empty() or current.is_empty() or str(prior.id) != name or str(current.id) != name: return false
	if int(prior.goal) == int(current.goal) or int(prior.exit) == int(current.exit): return false
	if int(route.current_id) != int(prior.exit): return false
	var offset: Vector3 = route.actor.global_position-route.graph.get_point_position(int(prior.exit))
	# Match the production graph-arrival datum; native support is tested separately.
	if Vector2(offset.x,offset.z).length() >= .05 or absf(offset.y) >= .3: return false
	var authored: Dictionary = {}
	for passage: Dictionary in route._bar_route._passages:
		if str(passage.id)==name: authored=passage; break
	if authored.is_empty(): return false
	if int(prior.exit) not in [int(authored.a),int(authored.b)] or int(current.exit) not in [int(authored.a),int(authored.b)]: return false
	var old_slots: Array = authored.a_slots if int(prior.exit)==int(authored.b) else authored.b_slots
	var new_slots: Array = authored.a_slots if int(current.exit)==int(authored.b) else authored.b_slots
	if not old_slots.has(int(old.records[id].slot)) or not new_slots.has(int(record.slot)): return false
	if int(old.records[id].owner_id) != int(record.owner_id): return false
	if not details.has("completed_reentries"): details.completed_reentries=[]
	details.completed_reentries.append({"resident":id,"passage":name,"old_gate":prior,"new_gate":current.duplicate(true),"at":route.actor.global_position,"before":old.records[id],"after":record})
	return true

func _observe_passages() -> bool:
	var registry: Node3D=world.bar_region.resident_places
	for id: String in routes:
		var route: Node3D=routes[id]
		for passage: Dictionary in route._bar_route._passages:
			var points:=PackedVector3Array()
			for point: int in passage.path: points.append(route.graph.get_point_position(point))
			var hit:=PassageObservation.classify(route.actor.global_position,points)
			if not bool(hit.valid): _fail_safety("valid actual passage geometry",{"resident":id,"passage":passage.id}); return false
			if bool(hit.requires_admission) and not registry.has_admission(str(passage.id),id,route.actor):
				var next_id: int=int(route.path[0]) if not route.path.is_empty() else -1
				if not PassageObservation.is_released_departure(route.actor.global_position,int(route.current_id),next_id,passage.path,route.graph):
					_fail_safety("actual protected passage body requires exact live admission",{"resident":id,"passage":passage.id,"observation":hit}); return false
				var key:=id+":"+str(passage.id)+":"+str(route.current_id)
				if not details.released_departures.has(key): details.released_departures[key]={"current":route.current_id,"next":next_id,"at":route.actor.global_position,"observation":hit}
	var passage_owners: Dictionary={}
	for name: String in registry._passages:
		var value: Dictionary=registry._passages[name]; var seen: Dictionary={}; var entries: Array=value.queue.duplicate()
		var previous_records: Dictionary=passage_before.get(name,{}).get("records",{}); var records: Dictionary={}
		if not value.active.is_empty(): entries.append(value.active)
		for entry: Dictionary in entries:
			var id:=str(entry.get("resident","")); var slot:=int(entry.get("slot",-1)); var route: Node3D=routes.get(id)
			if not is_instance_valid(route) or not _exact_owner(entry,route.actor) or slot<0 or slot>=value.holding.size() or seen.has(slot) or passage_owners.has(id):
				_fail_safety("exact original passage owner and exclusive retained slot",{"passage":name,"entry":_entry_record(entry)}); return false
			seen[slot]=true; passage_owners[id]=name
			var record:=_entry_record(entry)
			if previous_records.has(id) and previous_records[id]!=record and not _completed_reentry(name,id,route,value,record):
				_fail_safety("waiting or active owner retains its original slot",{"passage":name,"before":previous_records[id],"after":record}); return false
			records[id]=record
		var active:=str(value.active.get("resident","")); var old: Dictionary=passage_before.get(name,{"active":"","queue":[]}); var queue_ids: Array=[]
		for entry: Dictionary in value.queue: queue_ids.append(str(entry.resident))
		if not active.is_empty() and active!=str(old.active):
			if not old.queue.is_empty() and active!=str(old.queue[0]): _fail_safety("actual passage promotion follows observed FIFO head",{"passage":name,"previous":old,"active":active}); return false
			var route: Node3D=routes[active]; var passage:=_passage(route)
			if name=="entry_descent":
				if str(route._bar_route._gate.get("id",""))!=name or int(route._bar_route._gate.get("exit",-1)) not in [int(passage.a),int(passage.b)]:
					_fail_safety("admitted original owner has actual directed passage gate",{"resident":active,"gate":route._bar_route._gate}); return false
				var direction: String="in" if int(route._bar_route._gate.get("exit",-1))==int(passage.b) else "out"
				direction_admissions[active+":"+direction]=true
			details.admissions.append({"passage":name,"resident":active,"gate":route._bar_route._gate.duplicate(true),"previous":old,"state":_passage_snapshot()})
		passage_before[name]={"active":active,"queue":queue_ids,"records":records,"gate":routes[active]._bar_route._gate.duplicate(true) if not active.is_empty() else {}}
	if programme_started>0:
		if not is_instance_valid(entry_door) or entry_door.get_instance_id()!=entry_door_id or world.bar_region.doors.get("F01_BAR_RED_DOOR")!=entry_door:
			_fail_safety("original entry door owner retained",{}); return false
		for id: String in PARTICIPANTS:
			if not routes[id]._doors.has(entry_door): _fail_safety("route retains ordinary entry-door owner",{"resident":id}); return false
		var entry: Dictionary=registry._passages.entry_descent
		if _entry_active("malcolm_reed",true):
			for waiting: Dictionary in entry.queue:
				if str(waiting.resident)!="nadia_quell": continue
				var inward: Node3D=routes.nadia_quell; var outward: Node3D=routes.malcolm_reed
				var passage:=_passage(inward)
				if not _exact_owner(waiting,inward.actor) or not _exact_owner(entry.active,outward.actor) or not passage.a_slots.has(int(waiting.slot)) or not passage.b_slots.has(int(entry.active.slot)) or int(inward._bar_route._gate.get("exit",-1))!=int(passage.b):
					_fail_safety("opposition has exact original owners and opposite-side slots",{"state":_passage_snapshot()}); return false
				if not entry_opposition_seen:
					details.entry_opposition={"state":_crowd_snapshot(),"outer_slot":int(waiting.slot),"inner_slot":int(entry.active.slot),"door_id":entry_door_id}
				entry_opposition_seen=true

	return true

func _observe_progress() -> void:
	if programme_started==0: return
	var signature:=JSON.stringify(_passage_snapshot()); var moved:=false
	for id: String in PARTICIPANTS:
		var at: Vector3=routes[id].actor.global_position
		if not progress_positions.has(id) or at.distance_to(progress_positions[id])>.02: moved=true
	if moved or signature!=progress_signature:
		progress_at=Time.get_ticks_msec(); progress_warning=false; progress_signature=signature
		for id: String in PARTICIPANTS: progress_positions[id]=routes[id].actor.global_position
	elif not progress_warning and Time.get_ticks_msec()-progress_at>=10000:
		progress_warning=true; details.no_progress.append(_crowd_snapshot())

func _finish() -> void:
	Input.action_release("move_forward")
	if finishing: return
	finishing=true; watching=false; _disconnect_birth_hook()
	for name: String in ["crowded_construction_and_seating","continuous_safety"]:
		if not contracts.has(name): contracts[name]={"executed":safety_started if name=="continuous_safety" else is_instance_valid(world),"status":"FAIL"}
	var cleanup_errors:=failures.size()
	if is_instance_valid(world):
		if not details.has("final_crowd"): details.final_crowd=_crowd_snapshot()
		world.shutdown_for_tests(); remove_child(world); world.free(); world=null
	await get_tree().process_frame
	if preview_owned:
		_check(RealityState.end_preview_campaign(self) and is_same(RealityState.data,prior_data),"exact original preview and protection context restored"); preview_owned=false
	GameBoot.launch_mode=prior_mode; Input.mouse_mode=prior_mouse; CampaignTime.set_frozen_for_tests(prior_frozen)
	_check(JSON.stringify(prior_data).sha256_text()==original_hash,"original campaign content unchanged")
	_check(CampaignTime._frozen_for_tests==prior_frozen and GameBoot.launch_mode==prior_mode and Input.mouse_mode==prior_mouse,"original freeze launch and mouse custody restored")
	_check(not get_tree().node_added.is_connected(_born),"construction hook disconnected on exit")
	_check(_inputs()==initial_inputs,"runtime physical and transitive test source inputs stable")
	var errors: Array=[]
	for error: String in logger.errors:
		if not error.contains("HARUKIYA ROSTER:"): errors.append(error)
	OS.remove_logger(logger); _check(errors.is_empty(),"no unexpected engine errors")
	contracts.preview_source_cleanup={"executed":true,"status":"PASS" if failures.size()==cleanup_errors else "FAIL"}
	var test: String=get_script().resource_path; var scene: String=scene_file_path
	var result: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","production_runtime":true,"selector":"v2","suite":"HarukiyaCrowdedEntryTest","status":"PASS" if failures.is_empty() else "FAIL",
		"scope":"Mechanical original eighteen-owner construction/seating; original active player walks to refuge; Nadia and Malcolm traverse native entry descent in both directions, with an actual inward FIFO request while the other owns outward admission, then all18 reoccupy. Sixteen nonparticipants remain occupied and active. Timed character squeezing is observed without granting permissions; original native geometry, entry door and passage authority retained. No natural attendance, mass18-way flow, whole-cast physical fit, service, cost, play or artistic acceptance.",
		"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/"+test.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(test),"test_scene_path":"game/"+scene.trim_prefix("res://"),"test_scene_sha256":FileAccess.get_sha256(scene),"runtime_inputs_sha256":initial_inputs.get("runtime",""),"physical_inputs_sha256":initial_inputs.get("physical",""),"test_dependencies":initial_inputs.get("dependencies",{})},
		"contracts":contracts,"source_inputs":initial_inputs,"checks":checks,"failures":failures,"engine_errors":errors,"details":details,"motion_frames":motion_frames,
		"fixture":{"nearby_limit_m":MAX_NEARBY_METRES,"seating_deadline_s":SETTLE_SECONDS,"post_birth_transform_writes":false,"forced_initial_destination":true,"hidden_bystanders":false,"entry_programme":"event-driven existing force_destination plus actual directional player input","programme_limit_s":PROGRAMME_SECONDS,"phase_ceiling_s":PHASE_CEILING_SECONDS}}
	var file:=FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE)
	if file==null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result,"\t")); file.flush(); var written:=file.get_error()==OK; file.close()
	get_tree().quit(0 if failures.is_empty() and written else 1)
