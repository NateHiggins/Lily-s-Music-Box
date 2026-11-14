extends "res://tests/harukiya_roster_intake_test.gd"
## Stage one ONLY: original eighteen route owners, production construction and
## normal seating. No opponent programme, attendance, cast-fit or service claim.
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
	contracts.busy_opposing={"executed":false,"status":"NOT_RUN"}
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
	details.final_crowd=_crowd_snapshot()
	_contract("crowded_construction_and_seating",failures.is_empty())
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
		if not route.is_physics_processing() or not route.can_process() or route.outside or route.destination!="harukiya_bar" or absf(route.route_speed-1.05)>.000001:
			_fail_safety("all actual mechanical bar owners remain active and unchanged",{"resident":id}); return
		var witness:=Attendance.motion_witness(world.get_world_3d().direct_space_state,last[id].at,at,delta,not transition.is_empty() or not str(last[id].transition).is_empty())
		if not bool(witness.clear): _fail_safety("continuous supported native movement",{"resident":id,"witness":witness}); return
		last[id]={"at":at,"transition":transition}
		var body:=_body(route); var hits:=_world_hits(route,bool(body.seated))
		if not hits.is_empty(): _fail_safety("actual native standing or seated capsule",{"resident":id,"seated":body.seated,"hits":hits,"at":at}); return
		if _capsule_overlap(body.center,body.shape.radius,body.shape.height,world.player._shape.global_position,world.player._capsule.radius,world.player._capsule.height):
			_fail_safety("actual player full-body separation",{"resident":id,"at":at,"player":world.player.global_position}); return
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
			if _capsule_overlap(body.center,body.shape.radius,body.shape.height,peer.center,peer.shape.radius,peer.shape.height):
				_fail_safety("actual resident full-body separation",{"resident":id,"other":str(other.get_path()),"at":at,"other_at":other.global_position}); return
		if not str(route._bar_route.visit.phase()).is_empty():
			var seat:=str(world.bar_region.resident_places.preferred(id).seat_id)
			if not _exact_owner(world.seat_gestures.taken.get(seat,{}),route.actor): _fail_safety("exact shared seat owner",{"resident":id,"seat":seat}); return
	if Time.get_ticks_msec()-last_trace>=250:
		details.trace.append(_crowd_snapshot()); last_trace=Time.get_ticks_msec()

func _crowd_snapshot() -> Dictionary:
	var result: Dictionary={"elapsed_s":(Time.get_ticks_msec()-started)/1000.0,"actors":{}}
	for id: String in routes:
		var route: Node3D=routes[id]
		if not is_instance_valid(route) or not is_instance_valid(route.actor): continue
		result.actors[id]={"owner_id":route.get_instance_id(),"actor_id":route.actor.get_instance_id(),"at":route.actor.global_position,"current":route.current_id,"desired":route.desired_id,"path":Array(route.path),"phase":route._bar_route.visit.phase(),"transition":route._bar_route._transition,"clip_seated":route.actor._loop_seated(),"mina_standing":route.actor.mina_animation!=null,"blocked":route.blocked_reason,"blocked_seconds":route.blocked_seconds,"metres":route.travelled_metres}
	return result

func _finish() -> void:
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
	var result: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","production_runtime":true,"selector":"v2","suite":"HarukiyaCrowdedPassageTest","status":"PASS" if failures.is_empty() else "FAIL",
		"scope":"Stage1 mechanical original eighteen-owner crowded reconstruction and normal seating only; full native route-body/player/actual capsule-bystander safety. Staff models retained but have no physical profile. No busy/opposing, natural attendance, full20/21-cast physical or visual fit, service, cost, play or art claim.",
		"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/"+test.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(test),"test_scene_path":"game/"+scene.trim_prefix("res://"),"test_scene_sha256":FileAccess.get_sha256(scene),"runtime_inputs_sha256":initial_inputs.get("runtime",""),"physical_inputs_sha256":initial_inputs.get("physical",""),"test_dependencies":initial_inputs.get("dependencies",{})},
		"contracts":contracts,"source_inputs":initial_inputs,"checks":checks,"failures":failures,"engine_errors":errors,"details":details,"motion_frames":motion_frames,
		"fixture":{"nearby_limit_m":MAX_NEARBY_METRES,"seating_deadline_s":SETTLE_SECONDS,"post_birth_transform_writes":false,"forced_initial_destination":true,"hidden_bystanders":false,"opposition_programme":"NOT_RUN"}}
	var file:=FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE)
	if file==null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result,"\t")); file.flush(); var written:=file.get_error()==OK; file.close()
	get_tree().quit(0 if failures.is_empty() and written else 1)
