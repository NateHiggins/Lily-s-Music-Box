extends "res://tests/orison_v2_earned_dream_boundary_test.gd"
## Starts with the genuinely earned request. Only ordinary movement drives
## the Dream: no manual outcome, pursuit step, teleport or clock override.
func manual_onset_clock() -> bool:
	return false

func enter_earned_dream() -> bool:
	var entries: Array[String] = []
	shell.sleep_pressure.sleep_entry_requested.connect(func(case_id: String, _form: String):
		entries.append(case_id))
	var started := Time.get_ticks_msec()
	while shell.world_kind() == "waking" and Time.get_ticks_msec() - started < 15000:
		await get_tree().process_frame
	return check(not shell.sleep_pressure.manual_clock and shell.world_kind() == "dream"
			and entries == [MinaCaseGameplay.CASE_ID],
			"normal protected sleep onset enters the earned Dream exactly once")

func complete_dream() -> bool:
	var dream := shell.active_world as DreamMazeRoot
	if not check(dream != null and dream.autonomous and dream.rooms != null,
			"real autonomous room-based Dream is active"): return false
	var body := dream.player
	var field := dream.hazards
	var outcomes: Array[Dictionary] = []
	shell.dream_director.dream_ended.connect(func(case_id: String, outcome: String) -> void:
		outcomes.append({"case_id":case_id,"outcome":outcome}))
	var previous := body.global_position
	var distance := 0.0
	var visited: Array[String] = []
	var trace: Array[Dictionary] = []
	var waypoints: Array = []
	var departed := ""
	var started := Time.get_ticks_msec()
	var next_capture := 0
	var react_to_tell := OS.get_environment("DREAM_REACT_TO_TELL")=="1"
	var reacted := false
	var saw_lamp_off := false
	var release_toggle_at := 0
	Input.action_press("run")
	while shell.world_kind()=="dream" and Time.get_ticks_msec()-started<40000:
		if not is_instance_valid(dream) or not is_instance_valid(body): break
		if release_toggle_at>0 and Time.get_ticks_msec()>=release_toggle_at:
			Input.action_release("lamp_toggle")
			release_toggle_at = 0
		if react_to_tell and not reacted:
			for tell: Dictionary in field.perception_log:
				if str(tell.get("caption",""))=="TRUNK HISS":
					Input.action_press("lamp_toggle")
					release_toggle_at = Time.get_ticks_msec()+100
					reacted = true
					break
		if reacted and not body.lamp_is_enabled(): saw_lamp_off = true
		distance += body.global_position.distance_to(previous)
		previous = body.global_position
		var here: String = dream.rooms.nav_room_at(body.position.x,body.position.z)
		var new_room := not here.is_empty() and not here in visited
		if new_room: visited.append(here)
		if waypoints.is_empty():
			var room: Dictionary = dream.rooms.room_at_key(here)
			var best_score := -INF
			for door: Dictionary in room.get("doors",[]):
				var destination := str(door.get("leads_to",""))
				if bool(door.get("sealed",true)) or destination.is_empty() or destination==departed: continue
				var candidate: Array = dream.rooms.route(here,destination)
				if candidate.is_empty(): continue
				var exit_point: Vector3 = dream.to_global(candidate.back())
				var score := exit_point.distance_to(dream.pursuer.global_position) \
						- exit_point.distance_to(body.global_position)*.5
				if score > best_score:
					best_score = score
					waypoints = candidate
			if not waypoints.is_empty(): departed = here
		if not waypoints.is_empty():
			var target: Vector3 = dream.to_global(waypoints[0])
			var delta := target-body.global_position
			delta.y = 0
			if delta.length()<.12:
				waypoints.pop_front()
			else:
				body.rotation.y = atan2(-delta.x,-delta.z)
				body.camera.rotation = Vector3.ZERO
				Input.action_press("move_forward",minf(1.0,delta.length()/.35))
		else:
			Input.action_release("move_forward")
		if new_room or Time.get_ticks_msec()-started>=next_capture:
			trace.append({"seconds":float(Time.get_ticks_msec()-started)/1000.0,
					"position":str(body.global_position),"room":here,"distance":distance,
					"noclip":body.noclip,"collision_mask":body.collision_mask})
			await RenderingServer.frame_post_draw
			if shell.world_kind()=="dream":
				get_viewport().get_texture().get_image().save_png(output.path_join("played_%02d.png" % trace.size()))
			next_capture += 2000
		await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_release("run")
	Input.action_release("lamp_toggle")
	check(distance>1.0,"ordinary Dream controller actually traverses space")
	check(visited.size()>=2,"ordinary Dream movement crosses an authored doorway")
	var collision_live := true
	for sample in trace: collision_live = collision_live and not sample.noclip and sample.collision_mask==1
	check(collision_live and not trace.is_empty(),"Dream movement retains normal collision")
	check(outcomes.size()==1,"autonomous Dream commits exactly one outcome")
	check(field.unfair_impacts().is_empty(),"contact preserves the authored warning interval")
	if react_to_tell:
		check(reacted and saw_lamp_off,"normal lamp input responds to the perceived trunk warning")
	FileAccess.open(output.path_join("played_route.json"),FileAccess.WRITE).store_string(
			JSON.stringify({"distance_m":distance,"rooms":visited,"trace":trace,
			"outcomes":outcomes,"impacts":field.impact_log,"perceptions":field.perception_log,
			"react_to_tell":react_to_tell,"reacted":reacted,"observed_lamp_off":saw_lamp_off,
			"natural_return":shell.world_kind()=="waking"},"\t"))
	return shell.world_kind()=="waking"
