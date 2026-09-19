extends "res://tests/orison_v2_earned_conversation_route_test.gd"
## Continue the earned first visit using physical input at the existing clock.
func _init() -> void:
	route_label = "V2 RECURRENCE ROUTE"

func _run() -> void:
	var scale := Engine.time_scale
	var ticks := Engine.physics_ticks_per_second
	Engine.time_scale = 2.0
	Engine.physics_ticks_per_second = 120
	await super._run()
	Engine.time_scale = scale
	Engine.physics_ticks_per_second = ticks

func _route() -> void:
	await super._route()
	if not failures.is_empty(): return
	for point in [Vector3(-13.4,3.2,2.5),Vector3(-10.5,3.2,2.5),Vector3(-9.2,3.2,1.4)]:
		if not await _walk(point): return
	if not await _return_core(): return
	var clock: CaseInteractable = world.mina_gameplay.shift_clock
	print("RECURRENCE_CLOCK ",clock.global_position)
	var stance: Vector3 = world.adapter.root.to_local(clock.global_position)
	stance.y = 0
	stance.z -= 1.1
	for point in [Vector3(2.3,0,-6.5),Vector3(0,0,-6.5),Vector3(stance.x,0,-6.5)]:
		if not await _walk(point): return
	if not await _walk(stance): return
	if not await _use(clock,clock.global_position+Vector3.UP*.2,"earned_second_visit_clock"): return
	await get_tree().create_timer(2.8).timeout
	var state := RealityState.case_state(MinaCaseGameplay.CASE_ID)
	if not _require(state.stage=="reopened" and state.recurrence_count==1 and not player.call_locked,
			"clock advances the earned unresolved case and releases movement"): return
	_require(world.mina_gameplay.letter.enabled,"second visit leaves Mina's physical letter")
	if not await _walk(Vector3(2.3,0,-3.5)): return
	if not await _enter_2a(): return
	if not await _walk(Vector3(-10.5,3.2,2.5)): return
	for i in 3:
		var item: CaseInteractable = world.mina_gameplay.evidence_nodes[i]
		var at: Vector3 = world.adapter.root.to_local(item.global_position)
		at.y = 3.2
		at.z += .75
		if not await _walk(at): return
		var spec: Dictionary = MinaCaseGameplay.EVIDENCE[i]
		var expected := "caption_1_%s=%s" % [spec.id,spec.fact]
		for attempt in 3:
			if expected in state.apartment_changes: break
			if not await _use(item,item.global_position+Vector3.UP*.01,"factual_"+str(i)+"_"+str(attempt)): return
		_require(expected in state.apartment_changes,"physical caption records "+spec.fact)
	if not await _walk(Vector3(-10.5,3.2,2.5)): return
	var console: CaseInteractable = world.mina_gameplay.console
	var at: Vector3 = world.adapter.root.to_local(console.global_position)
	at.y = 3.2
	at.z -= .75
	if not await _walk(at): return
	if not await _use(console,console.global_position+Vector3.UP*.06,"second_calibration"): return
	state = RealityState.case_state(MinaCaseGameplay.CASE_ID)
	if not _require(state.stage=="stabilized" and state.repair_count==2,
			"physical second calibration earns real talk"): return
	await _integrate()

func _integrate() -> void:
	for point in [Vector3(-10.5,3.2,2.5),Vector3(-13.4,3.2,2.5),Vector3(-13.4,3.2,1.95)]:
		if not await _walk(point): return
	if not await _meet_mina(): return
	var mina: AnimatedResident = world.mina_routine.actor
	var dialogue := world.mina_gameplay.dialogue
	if not await _use(mina,mina.global_position+Vector3.UP*1.15,"second_visit_real_talk"): return
	if not _require(dialogue.current_node_id=="rt_open" and player.call_locked,"physical Mina offers earned real talk"): return
	dialogue.choose(0)
	dialogue.choose(0)
	dialogue.choose_silence()
	dialogue.choose(0)
	dialogue.choose(0)
	dialogue.choose(0)
	if not _require(dialogue.current_node_id=="rt_heart","conversation reaches the authored silence"): return
	dialogue.choose_silence()
	var state := RealityState.case_state(MinaCaseGameplay.CASE_ID)
	if not _require(state.stage=="integration_ready" and world.core_loop.boundary()=="conversation_complete",
			"earned silence closes the job while integration remains pending"): return
	dialogue.choose(0)
	await get_tree().process_frame
	if not await _use(mina,mina.global_position+Vector3.UP*1.15,"integration_exchange"): return
	if not _require(dialogue.current_node_id=="int_open","physical Mina offers integration"): return
	dialogue.choose_silence()
	dialogue.choose(0)
	await get_tree().process_frame
	var requests: Array[Dictionary] = []
	world.core_loop.dream_requested.connect(func(case_id: String, profile_id: String, window: Dictionary):
		requests.append({"case_id":case_id,"profile_id":profile_id,"window":window}))
	if not await _follow_graph_to(int(world.mina_routine.identities.main_clear)): return
	for point in [Vector3(-11.1,3.2,1.7)]:
		if not await _walk(point): return
	var console: CaseInteractable = world.mina_gameplay.console
	if not await _use(console,console.global_position+Vector3.UP*.2,"final_silent_calibration"): return
	await get_tree().process_frame
	await get_tree().process_frame
	state = RealityState.case_state(MinaCaseGameplay.CASE_ID)
	_require(state.resolved and world.core_loop.boundary()=="dream_pending" and requests.size()==1,
			"resolved physical shift requests its dream exactly once")
	_require(not player.noclip and player.collision_mask==1,
			"full route preserves ordinary player collision")
	if failures.is_empty():
		var previous_path: String = RealityState.save_path
		RealityState.save_path = OS.get_environment("SHOT_DIR").path_join("earned_dream_pending.json")
		_require(RealityState.save_game(),"earned dream boundary writes through the real save owner")
		RealityState.save_path = previous_path


func _nearest_route_node() -> int:
	var graph: AStar3D = world.mina_routine.graph
	return graph.get_closest_point(player.global_position)

func _follow_graph_to(target_id: int) -> bool:
	var graph: AStar3D = world.mina_routine.graph
	var route := graph.get_id_path(_nearest_route_node(),target_id)
	for index in route:
		if not await _walk_world(graph.get_point_position(index)): return false
	return true

func _meet_mina() -> bool:
	var routine: Node3D = world.mina_routine
	var actor: AnimatedResident = routine.actor
	for attempt in 35:
		if player.global_position.distance_to(actor.global_position)<1.5: return true
		var graph: AStar3D = routine.graph
		var route := graph.get_id_path(_nearest_route_node(),int(routine.current_id))
		if route.size()>1:
			if not await _walk_world(graph.get_point_position(route[1])): return false
		else:
			if not routine.path.is_empty():
				if not await _walk_world(graph.get_point_position(routine.path[0])): return false
			else:
				if not await _walk_world(graph.get_point_position(routine.current_id)): return false
	return _require(false,"player reaches the scheduled resident without teleporting her")
