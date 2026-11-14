extends "res://tests/harukiya_natural_arrival_test.gd"
## Actual all-resident setup and retained RuntimeRoot shutdown only. The base
## journey is unchanged and is never entered by this explicitly guarded scene.
const Traffic := preload("res://scripts/characters/public_foot_traffic.gd")
const RETAINED_FRAMES := 3
var shutdown_finishing := false

func _run() -> void:
	if OS.get_environment("ORISON_NATURAL_SETUP_ONLY") != "1":
		push_error("HARUKIYA RETAINED SHUTDOWN requires ORISON_NATURAL_SETUP_ONLY=1")
		get_tree().quit(2); return
	await super._run()

func _traffic_snapshot(traffic: Traffic) -> Dictionary:
	return {"retired":traffic._retired,"physics_processing":traffic.is_physics_processing(),
		"map_valid":traffic.solver.map.is_valid(),"agents":traffic.solver.agents.duplicate(true),
		"proposals":traffic._proposals.duplicate(true),"submitted":traffic._submitted.duplicate(true),
		"poses":traffic._poses.duplicate(true),"routes_count":traffic._routes.size(),
		"bodies_count":traffic._bodies.size(),"stats":traffic.stats.duplicate(true),
		"solver_errors":traffic.solver.errors.duplicate()}

func _retirement_clear(snapshot: Dictionary) -> bool:
	return (bool(snapshot.retired) and not bool(snapshot.physics_processing) and not bool(snapshot.map_valid)
		and snapshot.agents.is_empty() and snapshot.proposals.is_empty() and snapshot.submitted.is_empty()
		and snapshot.poses.is_empty() and int(snapshot.routes_count)==0 and int(snapshot.bodies_count)==0
		and snapshot.solver_errors.is_empty())

func _finish() -> void:
	if shutdown_finishing: return
	shutdown_finishing=true; watching=false
	_check(setup_only and details.has("grocery_reconstruction"),"existing setup-only reconstruction completed before retained lifecycle check")
	_contract("registered_setup_and_grocery_reconstruction", setup_only and details.has("grocery_reconstruction") and failures.is_empty())
	var retained_start_failures:=failures.size()
	var retained_executed:=false
	var held_solver: RefCounted
	var traffic_ref: WeakRef
	var world_ref: WeakRef
	if is_instance_valid(world):
		world_ref=weakref(world)
		details.final_setup_state=details.get("initial_spawn",{}).duplicate(true)
		var traffic:=world.public_traffic as Traffic
		_check(is_instance_valid(traffic),"actual RuntimeRoot owns public traffic before shutdown")
		var identities: Array[Dictionary]=[]
		var owners: Array=world.resident_routes.values(); owners.append(world.mina_routine)
		_check(owners.size()==18,"all eighteen actual owners available for retained shutdown")
		for owner: Node3D in owners:
			if not _check(is_instance_valid(owner) and is_instance_valid(owner.actor),"actual owner and actor survive setup"): continue
			identities.append({"actor":weakref(owner.actor),"id":owner.actor.get_instance_id(),"resident":str(owner.resident),"at":owner.actor.global_position})
		_check(identities.size()==18,"retained shutdown observes eighteen existing resident bodies")
		var player_ref: WeakRef
		var player_at:=Vector3.ZERO
		if _check(is_instance_valid(world.player),"actual player available for retained shutdown"):
			player_ref=weakref(world.player); player_at=world.player.global_position
		var callback_entries: Array[Dictionary]=[]
		var callback_before: Array[Dictionary]=[]
		if is_instance_valid(traffic):
			traffic_ref=weakref(traffic); held_solver=traffic.solver
			var before:=_traffic_snapshot(traffic)
			details.public_traffic_before_shutdown=before
			_check(not traffic._retired and traffic.is_physics_processing() and traffic.solver.map.is_valid(),"actual traffic processor and private map are live before root shutdown")
			_check(not traffic.solver.agents.is_empty(),"actual public body agents exist before shutdown; test is not vacuous")
			# Deliberately reproduce the insufficient former control without changing
			# production code: only the parent is disabled; its ALWAYS child remains.
			world.process_mode=Node.PROCESS_MODE_DISABLED
			var negative_first_frame:=Engine.get_physics_frames()
			for index in RETAINED_FRAMES:
				await get_tree().physics_frame
				await get_tree().process_frame
				_check(not traffic._retired and traffic.can_process() and traffic.is_physics_processing() and traffic.solver.map.is_valid(),"negative parent-only disable leaves real ALWAYS traffic active "+str(index))
				for identity: Dictionary in identities:
					var body:=identity.actor.get_ref() as Node3D
					_check(is_instance_valid(body) and body.global_position.distance_to(identity.at)<.000001,"negative control holds actual resident motor "+str(identity.resident)+"/"+str(index))
				var player:=player_ref.get_ref() as Node3D if player_ref!=null else null
				_check(is_instance_valid(player) and player.global_position.distance_to(player_at)<.000001,"negative control holds actual player motor "+str(index))
			var negative_after:=_traffic_snapshot(traffic)
			var callback_advanced:=false
			for identity in negative_after.agents:
				if before.agents.has(identity) and int(negative_after.agents[identity].frame)>int(before.agents[identity].frame): callback_advanced=true
			_check(Engine.get_physics_frames()-negative_first_frame>=RETAINED_FRAMES and callback_advanced,"native callback-frame state advances across three frames despite disabled parent")
			details.parent_disable_negative={"first_physics_frame":negative_first_frame,"last_physics_frame":Engine.get_physics_frames(),"before":before,"after":negative_after,
				"scope":"only actual parent process_mode disabled; no copied root, replaced solver, actor movement or direct callback invocation"}
			var callback_seen:=false
			for entry: Dictionary in traffic.solver.agents.values():
				callback_entries.append(entry); callback_before.append(entry.duplicate(true))
				if int(entry.frame)>=0: callback_seen=true
			_check(callback_seen,"actual avoidance callback state was populated before shutdown")
		# The production owner must retire its ALWAYS child. The fixture never
		# calls traffic.shutdown(), toggles child processing, or clears solver state.
		world.shutdown_for_tests(); retained_executed=true
		_check(is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion(),"actual shutdown retains live RuntimeRoot for observation")
		_check(world.process_mode==Node.PROCESS_MODE_DISABLED,"actual root disables its inherited processing")
		var retired: Dictionary={}
		if is_instance_valid(traffic):
			retired=_traffic_snapshot(traffic); details.public_traffic_after_shutdown=retired
			_check(_retirement_clear(retired),"root shutdown immediately retires public map, agents and all pending state")
		var initial_frame:=Engine.get_physics_frames()
		var observed: Array[Dictionary]=[]
		for index in RETAINED_FRAMES:
			await get_tree().physics_frame
			await get_tree().process_frame
			_check(is_instance_valid(world) and world.is_inside_tree(),"world remains alive through retained physics frame "+str(index))
			var frame_record: Dictionary={"physics_frame":Engine.get_physics_frames(),"actors":[]}
			if _check(is_instance_valid(traffic),"traffic node remains available during retained interval "+str(index)):
				var current:=_traffic_snapshot(traffic); frame_record.traffic=current
				_check(_retirement_clear(current) and current==retired,"no public callback/proposal/state writes after shutdown frame "+str(index))
			for entry in callback_entries.size():
				_check(callback_entries[entry]==callback_before[entry],"previous callback-owned entry remains unchanged "+str(index)+"/"+str(entry))
			for identity: Dictionary in identities:
				var body:=identity.actor.get_ref() as Node3D
				if not _check(is_instance_valid(body) and body.is_inside_tree() and not body.is_queued_for_deletion(),"retained actual actor still exists "+str(identity.resident)+"/"+str(index)): continue
				_check(body.global_position.distance_to(identity.at)<.000001,"retired world does not move actual actor "+str(identity.resident)+"/"+str(index))
				frame_record.actors.append({"resident":identity.resident,"id":identity.id,"at":body.global_position})
			var player:=player_ref.get_ref() as Node3D if player_ref!=null else null
			_check(is_instance_valid(player) and player.global_position.distance_to(player_at)<.000001,"retained actual player remains stationary "+str(index))
			observed.append(frame_record)
		details.retained_shutdown={"first_physics_frame":initial_frame,"last_physics_frame":Engine.get_physics_frames(),"frames":observed,
			"callback_write_scope":"unchanged observed solver state and previously callback-owned dictionaries; no claim that callback function invocation itself was instrumented"}
		_check(Engine.get_physics_frames()-initial_frame>=RETAINED_FRAMES,"at least three actual physics frames elapsed while shutdown world remained alive")
		# No second shutdown call: after retained observation free the real owner.
		remove_child(world); world.free(); world=null
	contracts.retained_root_shutdown={"executed":retained_executed,"status":"PASS" if retained_executed and failures.size()==retained_start_failures else "FAIL"}
	var cleanup_start_failures:=failures.size()
	await get_tree().process_frame
	_check(world_ref==null or world_ref.get_ref()==null,"actual world freed after retained interval")
	_check(traffic_ref==null or traffic_ref.get_ref()==null,"actual traffic node freed with owner")
	if held_solver!=null:
		_check(not held_solver.map.is_valid() and held_solver.agents.is_empty(),"retained solver reference has no private map or agents after world free")
	if preview_owned:
		_check(RealityState.end_preview_campaign(self) and is_same(RealityState.data,prior_data),"exact original preview and protection context restored")
		preview_owned=false
	GameBoot.launch_mode=prior_mode; Input.mouse_mode=prior_mouse; CampaignTime.set_frozen_for_tests(prior_frozen)
	_check(JSON.stringify(prior_data).sha256_text()==original_hash,"original campaign unchanged")
	_check(CampaignTime._frozen_for_tests==prior_frozen,"original freeze custody restored")
	_check(GameBoot.launch_mode==prior_mode and Input.mouse_mode==prior_mouse,"original launch and mouse modes restored")
	_check(_inputs()==initial_inputs,"runtime physical and transitive source bindings remain stable")
	var errors: Array=[]
	if log_capture!=null:
		for error: String in log_capture.errors:
			if not error.contains("HARUKIYA ROSTER:"): errors.append(error)
		OS.remove_logger(log_capture)
	_check(errors.is_empty(),"no unexpected engine errors during setup retained shutdown or cleanup")
	contracts.cleanup_custody={"executed":true,"status":"PASS" if failures.size()==cleanup_start_failures else "FAIL"}
	var test_path: String=get_script().resource_path
	var scene_path: String=scene_file_path
	var result: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","production_runtime":true,"selector":"v2",
		"suite":"HarukiyaRetainedShutdownTest","status":"PASS" if failures.is_empty() else "FAIL",
		"scope":"actual all-eighteen-owner RuntimeRoot setup and grocery reconstruction, actual shutdown with live world retained for at least three physics frames, then owner free and original context restoration; no natural attendance, journey, rendered art or save-reload claim",
		"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/"+test_path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(test_path),
			"test_scene_path":"game/"+scene_path.trim_prefix("res://"),"test_scene_sha256":FileAccess.get_sha256(scene_path),
			"runtime_inputs_sha256":initial_inputs.get("runtime",""),"physical_inputs_sha256":initial_inputs.get("physical",""),"test_dependencies":initial_inputs.get("dependencies",{})},
		"contracts":contracts,"diagnostic_mode":"setup_and_retained_shutdown_only","initial_context":first_context,
		"source_inputs":initial_inputs,"details":details,"checks":checks,"failures":failures,"engine_errors":errors,
		"claim_limit":"The ordinary journey is not entered. No natural attendance contract is emitted. Callback write observation covers actual retained state, not callback invocation counts."}
	var file:=FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE)
	if file==null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result,"\t")); file.flush(); var written:=file.get_error()==OK; file.close()
	get_tree().quit(0 if failures.is_empty() and written else 1)
