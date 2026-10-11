extends Node
## Self-contained first-slice authority, denial, disk-rebuild and retirement proof.
## Derived from the existing M08F and patrol harnesses; every executed check
## lives in this root source and is covered by the receipt source hash.

const Selector := preload("res://scripts/building/building_root_selector.gd")
const REQUIRED := ["F01_WATCHMAN_DETECTOR", "F01_NIGHT_REGISTER",
		"F01_SIGNAL_REGISTER", "F01_TOUR_KEY_GUARD",
		"F02_B_RADIATOR_01", "B1_BOILER_01"]

var failures := 0
var passes := 0
var beats: Array[String] = []

const STATIONS := {
	"B1_WATCH_STATION": ["B1_STATION_BOILER", 1, -3.2],
	"F02_WATCH_STATION": ["F02_STATION_CORE", 2, 3.2],
	"F03_WATCH_STATION": ["F03_STATION_CORE", 3, 6.4],
	"F04_WATCH_STATION": ["F04_STATION_CORE", 4, 9.6],
	"F05_WATCH_STATION": ["F05_STATION_CORE", 5, 12.8],
	"F06_WATCH_STATION": ["F06_STATION_CORE", 6, 16.0],
	"F01_WATCH_STATION": ["F01_STATION_LOBBY", 7, 0.0],
}

const EXERCISED := ["F01_WATCHMAN_DETECTOR", "F01_NIGHT_REGISTER",
	"F01_SIGNAL_REGISTER", "F01_TOUR_KEY_GUARD", "F02_B_RADIATOR_01",
	"B1_BOILER_01", "LobbyPorterBoard"]
var observations: Array[Dictionary] = []
var nodes: Array[WeakRef] = []
var resources: Array[WeakRef] = []
var playbacks: Array[WeakRef] = []
var expected_ritual: Dictionary = {}
var ritual_executed := false
var reconstruction_executed := false
var started := Time.get_ticks_msec()


func _ready() -> void:
	var save_path := "user://tests/m08f_runtime_%s.json" % Crypto.new().generate_random_bytes(8).hex_encode()
	var save_directory := ProjectSettings.globalize_path(save_path).get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(save_directory)
	if directory_error != OK:
		push_error("M08F test save directory could not be created: %s (error %d)" %
				[save_directory, directory_error])
		get_tree().quit(2)
		return
	var saved_persistence := RealityState.persistence_enabled
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityCases._ready()
	RealityState.data.intro_complete = true
	_prepare_ritual()
	Selector.reset_for_tests("v2")
	var started := Time.get_ticks_usec()
	var packed := load(Selector.scene_path()) as PackedScene
	var world := packed.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	var cold_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_check(not world.startup_failed, "production-composed v2 root starts")
	for identity in REQUIRED:
		_check(world.find_children(identity, "", true, false).size() == 1,
				"one production gameplay authority: " + identity)
		_check(world.find_children(identity + "_Semantic", "", true, false).size() == 1,
				"one preserved spatial owner: " + identity)
	_check(world.find_children("FirstShiftDirector", "", true, false).size() == 1
			and world.find_children("ServiceRoundDirector", "", true, false).size() == 1
			and world.find_children("WorkOrders", "", true, false).size() == 1,
			"one lifecycle and save authority per contract")
	_check(world.find_children("*", "OrisonV2M08ESpatialCues", true, false).is_empty(),
			"review-only cues are absent from production runtime")

	var detector := world.find_child("F01_WATCHMAN_DETECTOR", true, false) as WatchmanClockProp
	var register := world.find_child("F01_NIGHT_REGISTER", true, false) as NightRegisterProp
	var signal_register := world.find_child("F01_SIGNAL_REGISTER", true, false) as WatchRegisterProp
	var guard := world.find_child("F01_TOUR_KEY_GUARD", true, false) as TourKeyGuardProp
	var radiator := world.find_child("F02_B_RADIATOR_01", true, false) as RadiatorProp
	var board := world.find_child("LobbyPorterBoard", true, false) as OtisProp
	var boiler := world.find_child("B1_BOILER_01", true, false) as BoilerProp
	_check(PlayerController.format_interaction_prompt(
			detector.control_prompt("detector"), &"controller").begins_with("[A]")
			and PlayerController.format_interaction_prompt(
					radiator.interact_prompt(), &"touch").begins_with("[TAP]"),
			"central formatter produces carrier-neutral prompts")
	_check(not guard.return_key() and not signal_register.receive_signal({
			"station_number": 9}), "ritual denial states refuse invented acts")
	await _exercise_ritual(world)

	_close_previous_job(world.work_orders)
	world.service_round.route_beat.connect(func(beat: String): beats.append(beat))
	_check(world.service_round.has_incoming_call()
			and world.service_round.answer_incoming_call()
			and not world.service_round.answer_incoming_call(),
			"service-set call issues exactly one authored radiator obligation")
	world.service_round.dialogue.choose(0)
	boiler.apply_maintenance_result({"note": "premature boiler"})
	radiator.apply_maintenance_result({"note": "premature radiator"})
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID) == "issued"
			and world.work_orders.job_state(ServiceRoundDirector.JOB_ID).evidence.is_empty(),
			"premature mechanisms cannot counterfeit progress")
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID)
	world.service_round.dialogue.choose(0)
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID) == "acknowledged",
			"resident threshold acknowledges the production work order")
	world.player.world_modified.emit(radiator.global_position,
			ServiceRoundDirector.RADIATOR_ID)
	world.player.world_modified.emit(radiator.global_position,
			ServiceRoundDirector.RADIATOR_ID)
	board.apply_maintenance_result({"note": "contacts squared"})
	boiler.apply_maintenance_result({"note": "water column proved"})
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID) == "repairable",
			"radiator, porter board, and boiler evidence earns repairability")
	var before_duplicate := world.work_orders.job_state(ServiceRoundDirector.JOB_ID).duplicate(true)
	boiler.apply_maintenance_result({"note": "duplicate"})
	_check(world.work_orders.job_state(ServiceRoundDirector.JOB_ID) == before_duplicate,
			"duplicate interaction cannot double-advance")
	radiator.apply_maintenance_result({
			"note": "vent freed and clocked; supply returned fully open"})
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID) == "repaired",
			"real 2B radiator authority records the repair")
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID)
	world.service_round.dialogue.choose(0)
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID) == "closed",
			"resident return closes the authored service round")
	_check(beats == ["call", "resident", "radiator_evidence", "lobby_comparison",
			"basement_comparison", "diagnosis", "repair", "resident_return"],
			"production event trace preserves the complete round")

	var old_path := RealityState.save_path
	RealityState.save_path = save_path
	RealityState.persistence_enabled = true
	var disk_measurement_started := Time.get_ticks_usec()
	var saved := RealityState.save_game()
	var disk_measurement_ms := float(Time.get_ticks_usec() - disk_measurement_started) / 1000.0
	var expected := world.work_orders.job_state(ServiceRoundDirector.JOB_ID).duplicate(true)
	_track_retirement(world)
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	packed = null
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	# No composed world remains; release the process-wide warm cache so the
	# harness can distinguish retired-scene retention from intentional caching.
	PropAudio.clear_cache()
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	var loaded := not RealityState.data.is_empty()
	Selector.reset_for_tests("v2")
	var reconstruct_started := Time.get_ticks_usec()
	var shell := CampaignShell.new()
	add_child(shell)
	await get_tree().process_frame
	var reconstruct_ms := float(Time.get_ticks_usec() - reconstruct_started) / 1000.0
	var reconstructed := shell.active_world as OrisonV2RuntimeRoot
	_check(saved and loaded and reconstructed != null
			and reconstructed.work_orders.job_state(ServiceRoundDirector.JOB_ID) == expected,
			"save, destroy, CampaignShell reconstruct, and load preserve round facts")
	_check(str(reconstructed.core_loop.resolve_return_anchor().get("id", ""))
			== "F04_B_BED", "v2 wake uses explicit bedside-return contract")
	_check_reconstruction(reconstructed)
	print("[M08F PERF] cold_ms=%.3f compose_ms=%.3f save_ms=%.3f reconstruct_ms=%.3f nodes=%d collisions=%d cpu_ms=%.3f physics_ms=%.3f" % [
			cold_ms, reconstructed.startup_ms, disk_measurement_ms, reconstruct_ms,
			_count_nodes(reconstructed), reconstructed.find_children(
					"*", "CollisionObject3D", true, false).size(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	_track_retirement(reconstructed)
	reconstructed.shutdown_for_tests()
	remove_child(shell)
	shell.free()
	await get_tree().process_frame
	await get_tree().process_frame
	# The owners above detach every stream synchronously. Give the audio server
	# one bounded mix interval to retire the already-detached decoder playback
	# before this process-level retention assertion exits.
	await get_tree().create_timer(0.1).timeout
	PropAudio.clear_cache()
	print("[M08F SAVE EVIDENCE] ", ProjectSettings.globalize_path(save_path))
	RealityState.save_path = old_path
	RealityState.persistence_enabled = saved_persistence
	RealityState.reset_campaign_for_tests()
	Selector.reset_for_tests()
	_check(FileAccess.get_sha256("res://data/building_layout.json")
			== "68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d",
			"production layout remains byte-stable")
	_check(Selector.DEFAULT_ID == "v2", "committed selector is v2")
	_finish_contract()
	print("ORISON V2 M08F RUNTIME: %s checks=%d" % [
			"PASS" if failures == 0 else "FAIL (%d)" % failures, passes + failures])
	get_tree().quit(failures)

func _close_previous_job(orders: WorkOrders) -> void:
	var job := ServiceRoundDirector.PREVIOUS_JOB_ID
	orders.issue_job(job, "reported")
	orders.acknowledge_job(job)
	orders.diagnose_job(job)
	orders.mark_job_awaiting_part(job)
	orders.mark_job_repairable(job)
	orders.record_job_repair(job, {"quality": "good", "note": "M08F prerequisite"})
	orders.close_job(job)

func _count_nodes(root: Node) -> int:
	var total := 1
	for child: Node in root.get_children():
		total += _count_nodes(child)
	return total

func _check(ok: bool, label: String) -> void:
	observations.append({"label":label,"ok":ok})
	if ok:
		passes += 1
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)

func _prepare_ritual() -> void:
	RealityState.data.first_shift = {"phase":FirstShiftDirector.PHASE_ARRIVED}

func _exercise_ritual(world: OrisonV2RuntimeRoot) -> void:
	var director := world.first_shift_director
	var detector := world.adapter.resolve("F01_WATCHMAN_DETECTOR") as WatchmanClockProp
	var register := world.adapter.resolve("F01_NIGHT_REGISTER") as NightRegisterProp
	var guard := world.adapter.resolve("F01_TOUR_KEY_GUARD") as TourKeyGuardProp
	_check(not director.clock_out() and not director.accept_report(ChirpHunt.JOB_ID),
		"arrival refuses premature clock-out and report acceptance")
	_check(not register.take_slip(),"empty spindle cannot invent an opening report")
	_check(detector.interact_control("detector",world.player)
		and director.ritual_phase()==FirstShiftDirector.PHASE_CLOCKED_IN
		and world.work_orders.job_stage(ChirpHunt.JOB_ID)=="issued",
		"production detector clocks in and offers exactly the authored opening job")
	_check(register.take_slip() and not register.take_slip()
		and director.ritual_phase()==FirstShiftDirector.PHASE_REPORT_ACCEPTED
		and world.work_orders.job_stage(ChirpHunt.JOB_ID)=="acknowledged",
		"production spindle acknowledges one report and denies duplicate taking")
	await _run_patrol(world)
	_check(not guard.key_carried() and not director.tour_key_carried(),
		"physical guard and first-shift observer agree on returned tour key")
	ritual_executed=true

func _track_retirement(world: OrisonV2RuntimeRoot) -> void:
	if expected_ritual.is_empty():expected_ritual=world.first_shift_director.ritual_state()
	nodes.append(weakref(world))
	for node: Node in world.find_children("*","Node",true,false):
		nodes.append(weakref(node))
		if node is AudioStreamPlayer3D and node.playing:
			var playback: AudioStreamPlayback = node.get_stream_playback()
			if playback!=null:playbacks.append(weakref(playback))
	# Only shapes created by the exercised owners; imported and shared warm
	# caches are intentionally outside runtime-owned retirement measurements.
	for identity: String in EXERCISED:
		var actor := world.find_child(identity,true,false)
		for shape: CollisionShape3D in actor.find_children("*","CollisionShape3D",true,false):
			if shape.shape!=null and shape.shape.resource_path.is_empty():resources.append(weakref(shape.shape))

func _check_reconstruction(world: OrisonV2RuntimeRoot) -> void:
	_check(world.first_shift_director.ritual_state()==expected_ritual,
		"disk load reconstructs durable ritual facts without repeating the opening job")
	var guard := world.adapter.resolve("F01_TOUR_KEY_GUARD") as TourKeyGuardProp
	var board := world.adapter.resolve("F01_SIGNAL_REGISTER") as WatchRegisterProp
	_check(not guard.key_carried() and world.watch_station_network.mark_count()==0 and not board.shows(1),
		"reconstruction preserves transient custody and register semantics without inventing saved marks")
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)=="closed",
		"reconstructed production owners preserve the closed Lena round")
	reconstruction_executed=true

func _remaining(refs: Array[WeakRef]) -> int:
	var count := 0
	for ref in refs:
		if ref.get_ref()!=null:count+=1
	return count

func _finish_contract() -> void:
	var retained_nodes := _remaining(nodes)
	var retained_resources := _remaining(resources)
	var retained_playbacks := _remaining(playbacks)
	_check(retained_nodes==0 and retained_resources==0 and retained_playbacks==0,
		"both production worlds release tracked nodes, authority shapes and observed audio playbacks")
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array=[]
	var digest: Array=[]
	_check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"record repository provenance")
	_check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"record current runtime inputs")
	var source: String = get_script().resource_path
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_string(source).replace("\r\n","\n").to_utf8_buffer())
	var passed := failures==0 and ritual_executed and reconstruction_executed
	var status := "PASS" if passed else "FAIL"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Seven first-slice authorities: opening detector/report, seven player-ray patrol stations, ordered Lena round, actual disk save and CampaignShell rebuild. Direct service-owner calls are contract stimuli; continuous walking and whole-world visual acceptance are not claimed.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/"+source.trim_prefix("res://"),"test_sha256":hash.finish().hex_encode(),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},
		"contracts":{"production_composition":{"executed":ritual_executed,"status":status,"identities":EXERCISED},
			"save_reconstruction":{"executed":reconstruction_executed,"status":status},
			"premature_action_denial":{"executed":ritual_executed,"status":status},
			"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":retained_nodes,"retained_resources":retained_resources,"retained_playbacks":retained_playbacks,
				"resource_scope":"Unpathed collision shapes below the seven exercised authorities; shared imported caches excluded.","tracked_nodes":nodes.size(),"tracked_resources":resources.size(),"tracked_playbacks":playbacks.size()}},
		"checks":observations,"failures":failures,"route_beats":beats}
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty():directory=ProjectSettings.globalize_path("res://../tmp/v2-first-slice-20261011/runtime")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("runtime_authority_receipt.json"),FileAccess.WRITE)
	_check(file!=null,"open runtime contract output")
	if file==null:return
	file.store_string(JSON.stringify(receipt,"\t"));file.flush()
	_check(file.get_error()==OK,"flush runtime contract output")

func _run_patrol(world: Node) -> void:
	var root: Node3D = world.adapter.root
	var network: WatchStationNetwork = world.watch_station_network
	var register := world.find_child("F01_SIGNAL_REGISTER",true,false) as WatchRegisterProp
	var guard := world.find_child("F01_TOUR_KEY_GUARD",true,false) as TourKeyGuardProp
	_check(network!=null and network.station_count()==STATIONS.size(),"one network carries a box from every floor")
	_check(register!=null and WatchRegisterProp.SHUTTER_NUMBERS==[1,2,3,4,5,6,7],"the register has a drop for every box")
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ordered: Array[WatchStationProp] = []
	for anchor: String in STATIONS:
		var row: Array = STATIONS[anchor]
		var station := world.adapter.resolve(anchor) as WatchStationProp
		_check(station!=null,"patrol station mounted: "+anchor)
		if station==null: continue
		_check(station.station_id==str(row[0]) and station.station_number()==int(row[1]) and station.legend()=="STATION %d" % int(row[1]),"station number and legend: "+anchor)
		_check(absf(root.to_local(station.global_position).y-(float(row[2])+1.42))<.001,"case hangs at 1.42 m on its own floor: "+anchor)
		# The box has no body, so a ray through its face meets the wall it hangs on.
		var mount := station.to_global(Vector3(0,.16,0))
		var out := station.global_basis.z.normalized()
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(mount+out*.3,mount-out*.05,1,[world.player.get_rid()]))
		_check(not hit.is_empty() and hit.position.distance_to(mount)<.002 and hit.normal.dot(out)>.99,"box flush on an actual wall: "+anchor)
		var front: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(mount+out*.02,mount+out*.7,1,[world.player.get_rid()]))
		_check(front.is_empty(),"nothing stands in front of the box: "+anchor)
		ordered.append(station)
		await _look(world,station.to_global(Vector3(0,-1.42,.95)),station.to_global(Vector3(0,.2,0)))

	ordered.sort_custom(func(a: WatchStationProp,b: WatchStationProp) -> bool: return a.station_number()<b.station_number())
	# One round, worked the way a player works it: the key off its hook with E at
	# the guard, then at every box in order one E to open it and one E to turn
	# the crank, after which the latch spring takes the door home.
	if guard==null: _check(false,"tour key guard present")
	else:
		await _look(world,guard.to_global(Vector3(0,-1.15,.7)),guard.to_global(Vector3(0,.15,.06)))
		_check(guard.interact_prompt().begins_with("[E]  Take the tour key"),"the guard offers its key")
		world.player.use_primary_interaction()
		await get_tree().physics_frame
		_check(network.tour_key_carried(),"the tour key leaves its hook for the round by the player's press")
	for station in ordered:
		await _look(world,station.to_global(Vector3(0,-1.42,.75)),station.to_global(Vector3(0,.16,.05)))
		_check(station.interact_prompt().begins_with("[E]  Open the signal box"),"box offers its door: "+station.station_id)
		world.player.use_primary_interaction()
		await get_tree().physics_frame
		var opened := station.door_open
		world.player.use_primary_interaction()
		await get_tree().physics_frame
		_check(opened and station.marked() and not station.door_open,"box worked by the player's presses: "+station.station_id)
	var delivered := network.delivered()
	_check(delivered.size()==STATIONS.size(),"every mark reached the register")
	var order: Array = delivered.map(func(r: Dictionary) -> int: return int(r.get("station_number",0)))
	_check(order==[1,2,3,4,5,6,7],"the register's sequence is the round: plant, floors 2 to 6, lobby")
	for number in WatchRegisterProp.SHUTTER_NUMBERS:
		_check(register.shows(number),"register drop %d down" % number)
	var at := register.to_global(Vector3(0,-.25,.95))
	await _look(world,Vector3(at.x,root.to_global(Vector3.ZERO).y,at.z),register.to_global(Vector3(0,.23,0)))

	await _look(world,guard.to_global(Vector3(0,-1.15,.7)),guard.to_global(Vector3(0,.15,.06)))
	world.player.use_primary_interaction()
	await get_tree().physics_frame
	_check(not network.tour_key_carried(),"the key goes back on its hook by the player's press")
	for station in ordered: _check(station.reset_station() and not station.marked(),"box reset: "+station.station_id)
	_check(register.reset_shutters() and not register.shows(1),"register restored for the morning")
	print("PATROL STATIONS: stations=%d marks=%d delivered=%d failures=%d" % [ordered.size(),network.mark_count(),delivered.size(),failures])

func _look(world: Node, feet: Vector3, target: Vector3) -> void:
	world.player.global_position = feet
	world.player.velocity = Vector3.ZERO
	world.player.set_lamp_enabled(true)
	for i in 12: await get_tree().physics_frame
	var eye: Vector3 = world.player.camera.global_position
	var flat := Vector2(target.x-eye.x,target.z-eye.z)
	world.player.rotation.y = atan2(-flat.x,-flat.y)
	world.player.camera.rotation = Vector3(atan2(target.y-eye.y,flat.length()),0,0)
	for i in 8: await get_tree().process_frame
