extends Node
## Self-contained first-slice authority, denial, disk-rebuild and retirement proof.
## Derived from the existing M08F and patrol harnesses; every executed check
## lives in this root source and is covered by the receipt source hash.

class PatrolHand extends Node3D:
	var player: PlayerController
	var follows_cursor := true
	func click() -> void:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
		player._unhandled_input(event)

	func move_to(goal: float) -> bool:
		for i in 640:
			if not player._grab.active(): return false
			var target: Dictionary=player._grab.target
			var value: float=target.read.call()
			if absf(goal-value)<.000001: return true
			var point: Vector3=target.part.to_global(player._grab.contact)
			var local_axis: Vector3=target.axis.call() if target.axis is Callable else target.axis
			var axis: Vector3=target.frame.global_basis*local_axis
			var tangent: Vector3=axis
			if target.kind=="hinge":
				tangent=axis.cross(point-target.part.global_position)
				if tangent.length()<.025: tangent=axis.cross(player.camera.global_basis.x)*.06
				if tangent.length()<.01:tangent=axis.cross(player.camera.global_basis.y)*.06
			var screen: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
			var depth_gesture := screen.length()<24.0 and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5
			if depth_gesture: screen=Vector2(0,tangent.dot(player.camera.global_basis.z)*180.0)
			var event := InputEventMouseMotion.new()
			event.relative=screen*clampf(goal-value,-.12 if target.kind=="hinge" else -.02,.12 if target.kind=="hinge" else .02)/float(target.get("motion_scale",1.0))
			var before_screen: Vector2=player.camera.unproject_position(point)
			player._unhandled_input(event)
			await get_tree().physics_frame
			if not depth_gesture and target.kind=="hinge" and absf(float(target.read.call())-value)>.001:
				var after_screen: Vector2=player.camera.unproject_position(target.part.to_global(player._grab.contact))
				if (after_screen-before_screen).dot(event.relative)<0: follows_cursor=false
		return false

	func operate(point: Vector3, target: float, owner: Node = null) -> bool:
		player.camera.look_at(point)
		await get_tree().physics_frame
		await get_tree().physics_frame
		click()
		if not player._grab.active():
			print("[PATROL POINTER] acquisition refused at ",point," camera=",player.camera.global_position)
			return false
		var picked: Dictionary=player._grab.target
		if owner!=null and picked.owner!=owner:
			print("[PATROL POINTER] wrong owner: ",picked.owner.get_path())
			click()
			return false
		var part_name: String=str(picked.part.get_path())
		var moved: bool=await move_to(target)
		if not moved:
			print("[PATROL POINTER] motion incomplete part=",part_name," wanted=",target," actual=",picked.read.call()," active=",player._grab.active()," captured=",Input.mouse_mode," call_locked=",player.call_locked," mouse_released=",player.mouse_released)
		click()
		return moved and not player._grab.active()


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
var borrowed_shapes: Array[WeakRef] = []
var first_shape_cache: Dictionary = {}
var playbacks: Array[WeakRef] = []
var expected_ritual: Dictionary = {}
var ritual_executed := false
var service_executed := false
var service_travel: Array[Dictionary] = []
var reconstruction_executed := false
var service_bench_only := false
var started := Time.get_ticks_msec()
var initial_inputs: Dictionary = {}


func _ready() -> void:
	if service_bench_only:return
	initial_inputs=_input_snapshot()
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

	if not await _exercise_physical_round(world,radiator,board,boiler):
		_track_retirement(world);world.shutdown_for_tests();remove_child(world);world.free()
		await get_tree().process_frame;await get_tree().create_timer(.1).timeout
		_finish_contract();RealityState.persistence_enabled=saved_persistence
		get_tree().quit(1);return

	var old_path := RealityState.save_path
	RealityState.save_path = save_path
	RealityState.persistence_enabled = true
	var disk_measurement_started := Time.get_ticks_usec()
	var saved := RealityState.save_game()
	var disk_measurement_ms := float(Time.get_ticks_usec() - disk_measurement_started) / 1000.0
	var expected := world.work_orders.job_state(ServiceRoundDirector.JOB_ID).duplicate(true)
	# Use the same full-precision JSON contract as RealityState. The engine's
	# parser can move fractional timestamps by one ULP; raw Dictionary equality
	# intermittently rejects an otherwise exact saved record. Keep every field,
	# and separately bound that representation change before checking disk/load.
	var expected_saved: Dictionary = JSON.parse_string(JSON.stringify(expected,"\t",true,true))
	_check(absf(float(expected_saved.issued_at)-float(expected.issued_at)) < 1e-12,
			"serialized issue timestamp retains sub-nanominute precision")
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	_check(saved and disk is Dictionary
			and disk.get("maintenance_jobs",{}).get(ServiceRoundDirector.JOB_ID,{}) == expected_saved,
			"real disk contains the complete serialized round record")
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
	if reconstructed != null and reconstructed.work_orders.job_state(ServiceRoundDirector.JOB_ID) != expected_saved:
		print("[M08F ROUND RECONSTRUCTION MISMATCH] ", JSON.stringify({"saved":saved,"loaded":loaded,
			"expected":expected_saved,"actual":reconstructed.work_orders.job_state(ServiceRoundDirector.JOB_ID)},"",true,true))
	_check(saved and loaded and reconstructed != null
			and reconstructed.work_orders.job_state(ServiceRoundDirector.JOB_ID) == expected_saved,
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
	# FirstShiftDirector defers its arrival placement. Let startup finish before
	# placing the test operator; retain the production arrival authority.
	await get_tree().process_frame
	await get_tree().process_frame
	var director := world.first_shift_director
	var detector := world.adapter.resolve("F01_WATCHMAN_DETECTOR") as WatchmanClockProp
	var register := world.adapter.resolve("F01_NIGHT_REGISTER") as NightRegisterProp
	var guard := world.adapter.resolve("F01_TOUR_KEY_GUARD") as TourKeyGuardProp
	_check(not director.clock_out() and not director.accept_report(ChirpHunt.JOB_ID),
		"arrival refuses premature clock-out and report acceptance")
	_check(not register.take_slip(),"empty spindle cannot invent an opening report")
	var physics_before := world.player.is_physics_processing()
	world.player.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var hand := PatrolHand.new();add_child(hand);hand.player=world.player
	await _look(world,detector.to_global(Vector3(.08,-.85,.8)),detector.to_global(Vector3(0,.2,.14)))
	_check(await hand.operate(detector.to_global(Vector3(.145,.2,.225)),1.65,detector),"open detector cover through actual pointer motion")
	_check(await hand.operate(detector._station_key.global_position+detector.global_basis*Vector3(.014,0,.016),1.18,detector)
		and director.ritual_phase()==FirstShiftDirector.PHASE_CLOCKED_IN
		and world.work_orders.job_stage(ChirpHunt.JOB_ID)=="issued",
		"production detector key stroke clocks in and offers exactly the authored opening job")
	await _look(world,register.to_global(Vector3(.04,-.8,.85)),register.to_global(Vector3(0,.25,.05)))
	_check(await hand.operate(register._slip.global_position+register.global_basis*Vector3(.006,0,.008),.065,register)
		and not register.take_slip() and director.ritual_phase()==FirstShiftDirector.PHASE_REPORT_ACCEPTED
		and world.work_orders.job_stage(ChirpHunt.JOB_ID)=="acknowledged",
		"physical spindle lift acknowledges one report and denies duplicate taking")
	hand.free()
	await _run_patrol(world)
	_check(not guard.key_carried() and not director.tour_key_carried(),
		"physical guard and first-shift observer agree on returned tour key")
	world.player.set_physics_process(physics_before)
	ritual_executed=true

func _track_retirement(world: OrisonV2RuntimeRoot) -> void:
	if expected_ritual.is_empty():expected_ritual=world.first_shift_director.ritual_state()
	nodes.append(weakref(world))
	for node: Node in world.find_children("*","Node",true,false):
		nodes.append(weakref(node))
		if node is AudioStreamPlayer3D and node.playing:
			var playback: AudioStreamPlayback = node.get_stream_playback()
			if playback!=null:playbacks.append(weakref(playback))
	# Identify the exact process-owned warm caches, rather than exempting all
	# retained shapes. Keep only weak references in this test.
	var cached := _shared_shape_ids()
	if first_shape_cache.is_empty():first_shape_cache=cached.duplicate()
	else:_check(cached==first_shape_cache,"reconstruction creates no additional shared radiator shapes")
	for identity: String in EXERCISED:
		var actor := world.find_child(identity,true,false)
		for shape: CollisionShape3D in actor.find_children("*","CollisionShape3D",true,false):
			if shape.shape!=null and shape.shape.resource_path.is_empty():
				if cached.has(shape.shape.get_instance_id()):borrowed_shapes.append(weakref(shape.shape))
				else:resources.append(weakref(shape.shape))

func _shared_shape_ids() -> Dictionary:
	var result := {}
	var shapes: Array=[]
	shapes.append_array(RadiatorNativeParts._collision_shapes.values())
	shapes.append_array(preload("res://scripts/props/radiator_vent_cap.gd")._shared_hulls)
	shapes.append_array(preload("res://scripts/props/radiator_union_packing.gd")._closed)
	shapes.append_array(preload("res://scripts/props/radiator_union_packing.gd")._opened)
	for shape: Shape3D in shapes:result[shape.get_instance_id()]=true
	return result

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

func _input_snapshot() -> Dictionary:
	var root:=ProjectSettings.globalize_path("res://..").simplify_path()
	var digest: Array=[];var physical: Array=[]
	_check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"record current runtime inputs")
	_check(OS.execute("python",[root.path_join("tools/v2_physical_inputs.py"),"--root",root],physical)==0,"record current physical inputs")
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_string(get_script().resource_path).replace("\r\n","\n").to_utf8_buffer())
	return {"runtime":str(digest[0]).strip_edges() if not digest.is_empty() else "","physical":str(physical[0]).strip_edges() if not physical.is_empty() else "","test":hash.finish().hex_encode()}

func _finish_contract() -> void:
	var retained_nodes := _remaining(nodes)
	var retained_resources := _remaining(resources)
	var retained_playbacks := _remaining(playbacks)
	_check(retained_nodes==0 and retained_resources==0 and retained_playbacks==0,
		"both production worlds release tracked nodes, authority shapes and observed audio playbacks")
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array=[]
	_check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"record repository provenance")
	var current_inputs:=_input_snapshot()
	_check(current_inputs==initial_inputs,"test, production code and physical inputs remain unchanged throughout execution")
	var source: String = get_script().resource_path
	var passed := failures==0 and ritual_executed and service_executed and reconstruction_executed
	var status := "PASS" if passed else "FAIL"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Seven first-slice authorities: opening detector/report, seven player-ray patrol stations, ordered Lena round, actual disk save and CampaignShell rebuild. Call/dialogue and the closed prior-job gate are fixtures; board, boiler and radiator outcomes come from physical input. Service travel and workshop insert delivery use the collision-bearing controller. Patrol stance placement and whole-world visual acceptance remain separate.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/"+source.trim_prefix("res://"),"test_sha256":current_inputs.test,"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":current_inputs.runtime,"physical_inputs_sha256":current_inputs.physical},
		"contracts":{"production_composition":{"executed":ritual_executed,"status":status,"identities":EXERCISED},
			"save_reconstruction":{"executed":reconstruction_executed,"status":status},
			"physical_service_round":{"executed":service_executed,"status":status,"scope":"Actual part input, controller movement and finite workshop insert delivery; call/dialogue choices remain stimuli."},
			"premature_action_denial":{"executed":ritual_executed,"status":status},
			"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":retained_nodes,"retained_resources":retained_resources,"retained_playbacks":retained_playbacks,
				"resource_scope":"Unpathed collision shapes below the seven exercised authorities; exact process-owned radiator cache IDs separately measured.","shared_cache_count":first_shape_cache.size(),"tracked_borrowed_shapes":borrowed_shapes.size(),"retained_borrowed_shapes":_remaining(borrowed_shapes),"tracked_nodes":nodes.size(),"tracked_resources":resources.size(),"tracked_playbacks":playbacks.size()}},
		"checks":observations,"failures":failures,"route_beats":beats,"service_travel":service_travel}
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
	# Actual clicks acquire the part; projected mouse travel operates it and
	# the next click releases. The original network still publishes marks.
	var hand := PatrolHand.new();add_child(hand);hand.player=world.player
	world.player.cancel_manipulation()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if guard==null: _check(false,"tour key guard present")
	else:
		await _look(world,guard.to_global(Vector3(0,-1.15,.7)),guard.to_global(Vector3(0,.15,.06)))
		_check(await hand.operate(guard._latch.to_global(Vector3(-.030,0,.012)),1.4),"guard latch opens through mouse travel")
		_check(await hand.operate(guard._key.to_global(Vector3(0,-.028,.01)),.065),"key physically lifts from its hook")
		_check(network.tour_key_carried(),"original custody authorizes the round after physical lift")
	for station in ordered:
		await _look(world,station.to_global(Vector3(0,-1.42,.75)),station.to_global(Vector3(0,.16,.05)))
		_check(await hand.operate(station._door.to_global(Vector3(.196,-.06,.025)),1.65),"grab and swing station door: "+station.station_id)
		_check(await hand.operate(station._crank.to_global(Vector3(0,.056,.025)),TAU),"grab and wind full crank stroke: "+station.station_id)
		_check(station.door_open and station.marked(),"full physical stroke publishes station mark: "+station.station_id)
		_check(await hand.operate(station._door.to_global(Vector3(.196,-.06,.025)),0),"physically close station door: "+station.station_id)
	var delivered := network.delivered()
	_check(delivered.size()==STATIONS.size(),"every mark reached the register")
	var order: Array = delivered.map(func(r: Dictionary) -> int: return int(r.get("station_number",0)))
	_check(order==[1,2,3,4,5,6,7],"the register's sequence is the round: plant, floors 2 to 6, lobby")
	for number in WatchRegisterProp.SHUTTER_NUMBERS:
		_check(register.shows(number),"register drop %d down" % number)
	var at := register.to_global(Vector3(0,-.25,.95))
	await _look(world,Vector3(at.x,root.to_global(Vector3.ZERO).y,at.z),register.to_global(Vector3(0,.23,0)))
	await _look(world,guard.to_global(Vector3(0,-1.15,.7)),guard.to_global(Vector3(0,.15,.06)))
	_check(await hand.operate(guard._check.to_global(Vector3(0,0,.01)),0),"carried key physically returns to hook")
	_check(not network.tour_key_carried(),"original network receives returned custody")
	for station in ordered: _check(station.reset_station() and not station.marked(),"supervisor resets box: "+station.station_id)
	await _look(world,Vector3(at.x,root.to_global(Vector3.ZERO).y,at.z),register.to_global(Vector3(0,.23,0)))
	var counter_before: int=register.signals_taken
	_check(await hand.operate(register._lever.to_global(Vector3(0,.062,.018)),.9),"register reset lever works through mouse travel")
	_check(not register.shows(1) and register.signals_taken==counter_before,"physical reset restores shutters without erasing signal count")
	hand.free()
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


func _service_focus(player: PlayerController,frame: Node3D,at: Vector3,offset: Vector3) -> void:
	player.cancel_manipulation()
	if player.inspecting():player.end_inspection()
	player.camera.make_current();player.call_locked=false;player.mouse_released=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	player.camera.global_position=at+frame.global_basis*offset;player.camera.look_at(at)
	await get_tree().physics_frame;await get_tree().physics_frame

func _service_move(hand: Node3D,frame: Node3D,part: Node3D,point: Vector3,offset: Vector3,goal: float) -> bool:
	await _service_focus(hand.player,frame,part.to_global(point),offset)
	var target: Dictionary=hand.player._grab.find_target()
	var found: bool=target.get("part")==part
	_check(found,"service cursor resolves actual part: "+str(part.name))
	if not found:
		print("[SERVICE PICK] expected=",part.get_path()," actual=",target," camera=",hand.player.camera.global_position)
		return false
	var result: bool=await hand.operate(part.to_global(point),goal)
	_check(result,"grab, mouse travel and release: "+str(part.name))
	return result

func _prove_board(player: PlayerController,board: OtisProp) -> bool:
	var hand:=PatrolHand.new();add_child(hand);hand.player=player
	var events: Array=[];var observe:=func(result: Dictionary):events.append(result.duplicate(true))
	board.maintenance_completed.connect(observe)
	var good:=await _service_move(hand,board,board._flag_arms[0],Vector3.ZERO,Vector3(.012,.025,.32),board._native_service.FLAG_HIGH)
	if good:good=await _service_move(hand,board,board._contact_bridge,Vector3.ZERO,Vector3(.012,.025,.32),0.0)
	if good:good=await _service_move(hand,board,board._reset_spindle,Vector3(.010,.035,0),Vector3(.012,.025,.32),PI*.5)
	await get_tree().create_timer(1.0).timeout
	_check(good and not board.stuck_flag and board.bank_reset==1. and events.size()==1,"physical flag/contact/reset cycle publishes exactly one comparison")
	board.maintenance_completed.disconnect(observe);hand.free()
	return good and events.size()==1

func _prove_boiler(player: PlayerController,boiler: BoilerProp) -> bool:
	var hand:=PatrolHand.new();add_child(hand);hand.player=player
	var events: Array=[];var observe:=func(result: Dictionary):events.append(result.duplicate(true))
	boiler.maintenance_completed.connect(observe)
	var good:=true
	for cock: Node3D in boiler._column_cocks:
		if not await _service_move(hand,boiler,cock,Vector3(.09,0,0),Vector3(.035,.03,-.30),0.):good=false;break
	if good:
		await _service_focus(player,boiler,boiler._blowdown_lever.to_global(Vector3(.12,0,0)),Vector3(.035,.03,-.30))
		hand.click()
		good=player._grab.active() and player._grab.target.part==boiler._blowdown_lever
		_check(good,"actual boiler drain lever acquisition")
		if good:
			good=await hand.move_to(deg_to_rad(34))
			await get_tree().create_timer(1.8).timeout
			_check(boiler._glass_level<.025 and boiler._drain_proved and boiler.column_isolated,"held drain empties the real isolated column")
			hand.click()
	if good:good=await _service_move(hand,boiler,boiler._witness_marker,Vector3.ZERO,Vector3(.04,.03,-.30),.85)
	if good:
		for cock: Node3D in boiler._column_cocks:
			if not await _service_move(hand,boiler,cock,Vector3(.09,0,0),Vector3(.035,.03,-.30),deg_to_rad(82)):good=false;break
	await get_tree().create_timer(1.6).timeout
	_check(not boiler.column_proved and events.is_empty(),"wrong physical witness cannot certify returned water")
	if good:good=await _service_move(hand,boiler,boiler._witness_marker,Vector3.ZERO,Vector3(.04,.03,-.30),boiler._column_level_y(boiler.water_level))
	await get_tree().create_timer(.2).timeout
	_check(good and boiler.column_proved and events.size()==1,"physical drain, return and correct witness publish one boiler comparison")
	boiler.maintenance_completed.disconnect(observe);hand.free()
	return good and events.size()==1


func _walk_service(world: OrisonV2RuntimeRoot,target: Vector3) -> bool:
	var player:=world.player;var frame: Node3D=world.adapter.root
	var carrying: Node3D=player._grab.target.part if player._grab.active() and player._grab.target.kind=="free" else null
	player.camera.position=Vector3(0,PlayerController.STANDING_EYE,0);player.camera.rotation=Vector3.ZERO
	player.set_physics_process(true);player.autopilot=Vector3.ZERO
	var goal:=frame.to_global(target);var deadline:=Time.get_ticks_msec()+15000
	var initial:=frame.to_local(player.global_position)
	while Time.get_ticks_msec()<deadline:
		var offset: Vector3=goal-player.global_position;offset.y=0
		if offset.length()<.075 and absf(player.global_position.y-goal.y)<.24:break
		var heading:=atan2(-offset.x,-offset.z)
		var turn:=wrapf(heading-player.rotation.y,-PI,PI)
		# Turn continuously so carried stock follows an actual sweep rather
		# than the teleport-denial guard rejecting a one-frame corner snap.
		player.rotation.y+=clampf(turn,-.06,.06);player.camera.rotation=Vector3.ZERO
		if absf(turn)>.18:Input.action_release("move_forward")
		else:Input.action_press("move_forward",clampf(offset.length()/.3,.20,1.))
		await get_tree().physics_frame
	Input.action_release("move_forward");player.velocity=Vector3.ZERO;player.set_physics_process(false)
	var at:=frame.to_local(player.global_position)
	var valid: bool=Vector2(at.x-target.x,at.z-target.z).length()<.10 and absf(at.y-target.y)<.24 and not player.noclip and player.collision_mask==1
	if carrying!=null:valid=valid and player._grab.active() and player._grab.target.part==carrying and carrying.global_position.distance_to(player.camera.global_position)<1.8
	var contacts: Array=[]
	for i in player.get_slide_collision_count():
		var collider: Object=player.get_slide_collision(i).get_collider()
		if collider is Node:contacts.append(str(collider.get_path()))
	var cargo := {}
	if carrying!=null:
		cargo={"at":frame.to_local(carrying.global_position),"grip_active":player._grab.active(),"camera_distance":carrying.global_position.distance_to(player.camera.global_position)}
		var sight:=PhysicsRayQueryParameters3D.create(player.camera.global_position,carrying.global_position)
		sight.collide_with_areas=true;sight.exclude=[player.get_rid()]
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(sight)
		if not hit.is_empty():cargo["sight_hit"]=str(hit.collider.get_path());cargo["sight_position"]=frame.to_local(hit.position)
	service_travel.append({"from":initial,"target":target,"actual":at,"carried":str(carrying.name) if carrying!=null else "","cargo":cargo,"contacts":contacts,"ok":valid})
	_check(valid,"service walking "+str(target)+" actual="+str(at))
	if not valid:print("[SERVICE WALK BLOCKED] ",JSON.stringify(service_travel.back()))
	return valid

func _service_stairs(base: float,up: bool) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	for i in 10:points.append(Vector3(1.925,base+.16*(i+1),-3.1+.285*(i+.5)))
	points.append_array([Vector3(1.925,base+1.6,1.25),Vector3(3.975,base+1.6,1.25)])
	for i in 10:points.append(Vector3(3.975,base+1.6+.16*(i+1),1.03-.285*(i+.5)))
	# Approach north of the stair opening, leaving real capsule clearance at
	# the closed fire cabinet on the east wall.
	points.append_array([Vector3(3.65,base+3.2,-2.9),Vector3(3.65,base+3.2,-3.45),Vector3(1.925,base+3.2,-3.45)])
	if not up:points.reverse();points.append(Vector3(1.925,base,-3.45))
	return points

func _walk_service_points(world: OrisonV2RuntimeRoot,points: Array) -> bool:
	for target: Vector3 in points:
		if not await _walk_service(world,target):return false
	return true

func _service_door(world: OrisonV2RuntimeRoot,identity: String) -> bool:
	var opening:=world.adapter.resolve(identity) as Node3D
	var door:=opening.get_node_or_null(identity+"_Leaf") as DoorProp if opening!=null else null
	_check(door!=null,"service route has an actual door: "+identity)
	if door==null:return false
	if door.open:return true
	var leaf:=door.get_node("HingedLeaf") as Node3D
	world.player.camera.position=Vector3(0,PlayerController.STANDING_EYE,0)
	var hand:=PatrolHand.new();add_child(hand);hand.player=world.player
	var result: bool=await hand.operate(leaf.to_global(Vector3(door.width*.5,1.1,0)),door.motion_target_angle(true),door)
	_check(result and door.open,"actual hand opens service route leaf: "+identity)
	hand.free();return result and door.open

func _service_supply(player: PlayerController,prop: RadiatorProp,value: float) -> bool:
	var hand:=PatrolHand.new();add_child(hand);hand.player=player
	var point: Vector3=prop._wheel.global_position+prop.global_basis*Vector3(0,0,-.045)
	await _service_focus(player,prop,point,Vector3(0,.15,-.35))
	var result: bool=await hand.operate(point,value*TAU*3.5,prop)
	_check(result and absf(prop.supply_position-value)<.00001,"physical one-pipe supply travel to "+str(value))
	hand.free();return result

func _carry_service_part(player: PlayerController,body: Node3D,goal: Vector3) -> bool:
	var start:=body.to_global(player._grab.contact)
	player.camera.global_position=(start+goal)*.5+Vector3.UP*.35+player.camera.global_basis.z*.8
	player.camera.look_at(start)
	for i in 320:
		if not player._grab.active():
			print("[SERVICE CARRY RELEASED] part=",body.name," at=",body.global_position," goal=",goal," camera=",player.camera.global_position)
			return false
		var contact: Vector3=body.to_global(player._grab.contact)
		if body.global_position.distance_to(goal)<.001:return true
		var destination: Vector3=goal+body.global_basis*player._grab.contact
		var axis: Vector3=(contact-player.camera.global_position).normalized()
		var depth: float=(destination-contact).dot(axis)
		if absf(depth)>.0001:
			var wheel:=InputEventMouseButton.new();wheel.pressed=true
			wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN if depth>0 else MOUSE_BUTTON_WHEEL_UP
			wheel.factor=minf(3.,absf(depth)/.025);player._unhandled_input(wheel)
		contact=body.to_global(player._grab.contact)
		var motion:=InputEventMouseMotion.new()
		motion.relative=player.camera.unproject_position(destination)-player.camera.unproject_position(contact)
		player._unhandled_input(motion);await get_tree().physics_frame
	print("[SERVICE CARRY BLOCKED] part=",body.name," at=",body.global_position," goal=",goal," active=",player._grab.active()," camera=",player.camera.global_position)
	return false

func _pick_service_part(player: PlayerController,body: Node3D,frame: Node3D,offset: Vector3) -> bool:
	await _service_focus(player,frame,body.to_global(Vector3(0,.004,0)),offset)
	# Released stock can fall during the two physics frames above. Track its
	# current surface, matching the production live pointer.
	player.camera.look_at(body.to_global(Vector3(0,.004,0)))
	var hand:=PatrolHand.new();add_child(hand);hand.player=player;hand.click();hand.free()
	var good: bool=player._grab.active() and player._grab.target.part==body
	if not good:print("[FREE SERVICE PICK] at=",body.global_transform," cursor=",player._grab.find_target()," camera=",player.camera.global_position)
	_check(good,"actual free part acquisition: "+str(body.name));return good

func _deliver_service_part(player: PlayerController,body: Node3D,goal: Vector3) -> bool:
	# Clear the casting before approaching the upward-facing threaded seat.
	# Every leg remains a mouse/wheel gesture through the real swept body.
	var raised:=body.global_position;raised.y=maxf(raised.y,goal.y+.20)
	if not await _carry_service_part(player,body,raised):return false
	if not await _carry_service_part(player,body,goal+Vector3.UP*.20):return false
	return await _carry_service_part(player,body,goal)

func _exercise_physical_round(world: OrisonV2RuntimeRoot,radiator: RadiatorProp,board: OtisProp,boiler: BoilerProp) -> bool:
	_close_previous_job(world.work_orders)
	world.service_round.route_beat.connect(func(beat: String):beats.append(beat))
	_check(world.service_round._radiator==radiator and world.service_round._board==board and world.service_round._boiler==boiler,"service director binds the installed native owners")
	_check(world.service_round.has_incoming_call() and world.service_round.answer_incoming_call() and not world.service_round.answer_incoming_call(),"call issues one original radiator obligation")
	world.service_round.dialogue.choose(0)
	boiler.apply_maintenance_result({"note":"premature boiler"});radiator.apply_maintenance_result({"note":"premature radiator"})
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)=="issued" and world.work_orders.job_state(ServiceRoundDirector.JOB_ID).evidence.is_empty(),"premature legacy stimuli cannot counterfeit progress")
	if not await _walk_service_points(world,[Vector3(-1.8,0,-1.5),Vector3(-1.8,0,-3.45),Vector3(1.925,0,-3.45),Vector3(1.925,0,-3.)]):return false
	if not await _walk_service_points(world,_service_stairs(0.,true)):return false
	if not await _walk_service_points(world,[Vector3(3.65,3.2,-3.45),Vector3(3.65,3.2,-3.15),Vector3(5.9,3.2,-3.15),Vector3(8.55,3.2,-3.25)]):return false
	if not await _service_door(world,"F02_B_ENTRY_DOOR"):return false
	if not await _walk_service_points(world,[Vector3(10.95,3.2,-3.25),Vector3(10.95,3.2,-2.5),Vector3(12.5,3.2,-2.5),Vector3(13.6,3.2,-1.8)]):return false
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID);world.service_round.dialogue.choose(0)
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)=="acknowledged","resident threshold acknowledges original work order")
	if not await _walk_service(world,Vector3(14.5,3.2,-3.)):return false
	if not await _service_supply(world.player,radiator,0.):return false
	var hand:=PatrolHand.new();add_child(hand);hand.player=world.player
	var nut: Node3D=radiator.native_rig.header_nut
	var at: Vector3=nut.global_position+radiator.global_basis*Vector3(0,0,-.045)
	await _service_focus(world.player,radiator,at,Vector3(-.45,.20,-.30));hand.click()
	var key:=InputEventKey.new();key.keycode=KEY_SPACE;key.physical_keycode=KEY_SPACE;key.pressed=true;world.player._unhandled_input(key)
	_check(world.player.inspecting() and "radiator_airbound" in world.work_orders.job_state(ServiceRoundDirector.JOB_ID).evidence,"Space inspection earns original radiator evidence")
	world.player.end_inspection();hand.free()
	var stock: Node3D=radiator.native_orifices
	var original: Dictionary=stock.active(radiator)
	var original_id: String=original.body.identity
	print("[PHYSICAL ROUND INITIAL] ",JSON.stringify(radiator.mechanism_snapshot())," insert=",original_id)
	if not await _service_move_new(world.player,radiator,original.body,Vector3(0,.004,0),Vector3(.03,.10,-.08),stock.THREAD_END):return false
	_check(stock.active(radiator).is_empty(),"old insert actually unthreads without changing identity")
	if not await _pick_service_part(world.player,original.body,radiator,Vector3(.03,.10,-.08)):return false
	var park: Vector3=radiator.native_rig.to_global(Vector3(-.30,.12,-.55))
	var parked: bool=await _carry_service_part(world.player,original.body,park)
	_check(parked,"old insert physically moves clear of its seat")
	hand=PatrolHand.new();add_child(hand);hand.player=world.player;hand.click();hand.free()
	if not parked:return false
	if not await _walk_service_points(world,[Vector3(13.6,3.2,-2.8),Vector3(12.5,3.2,-2.5),Vector3(10.95,3.2,-2.5),Vector3(10.95,3.2,-3.25),Vector3(8.55,3.2,-3.25),Vector3(5.9,3.2,-3.15),Vector3(3.65,3.2,-3.15),Vector3(3.65,3.2,-3.45),Vector3(1.925,3.2,-3.45)]):return false
	if not await _walk_service_points(world,_service_stairs(0.,false)):return false
	if not await _walk_service_points(world,[Vector3(-1.8,0,-3.45),Vector3(-1.8,0,-1.5),Vector3(-2.,0,-.65)]):return false
	if not await _prove_board(world.player,board):return false
	_check("lobby_contact_compared" in world.work_orders.job_state(ServiceRoundDirector.JOB_ID).evidence,"physical board outcome reaches original ordered comparison")
	if not await _walk_service_points(world,[Vector3(-1.8,0,-1.5),Vector3(-1.8,0,-3.45),Vector3(1.925,0,-3.45)]):return false
	if not await _walk_service_points(world,_service_stairs(-3.2,false)):return false
	if not await _walk_service_points(world,[Vector3(3.65,-3.2,-3.45),Vector3(4.9,-3.2,-2.5),Vector3(4.9,-3.2,-.4),Vector3(7.2,-3.2,-.4),Vector3(8.7,-3.2,-.4)]):return false
	if not await _service_door(world,"B1_BOILER_FIRE_DOOR"):return false
	if not await _walk_service_points(world,[Vector3(10.1,-3.2,-.4),Vector3(10.9,-3.2,-.5)]):return false
	if not await _prove_boiler(world.player,boiler):return false
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)=="repairable","real board and boiler outcomes earn repairability")
	if not await _walk_service_points(world,[Vector3(10.9,-3.2,-.4),Vector3(8.7,-3.2,-.4),Vector3(7.4,-3.2,-.4)]):return false
	if not await _service_door(world,"B1_SHOP_DOOR"):return false
	if not await _walk_service_points(world,[Vector3(7.4,-3.2,1.),Vector3(7.4,-3.2,3.),Vector3(7.65,-3.2,4.45)]):return false
	var replacement: Dictionary=stock.rows.VENT_SPARE_2
	if not await _pick_service_part(world.player,replacement.body,stock,Vector3(.03,.10,.08)):return false
	if not await _carry_service_part(world.player,replacement.body,world.player.to_global(Vector3(0,1.35,-.35))):return false
	if not await _walk_service_points(world,[Vector3(7.4,-3.2,3.),Vector3(7.4,-3.2,1.),Vector3(7.4,-3.2,-.4),Vector3(4.9,-3.2,-.4),Vector3(4.9,-3.2,-2.5),Vector3(3.65,-3.2,-3.45),Vector3(1.925,-3.2,-3.45),Vector3(1.925,-3.2,-3.)]):return false
	if not await _walk_service_points(world,_service_stairs(-3.2,true)):return false
	if not await _walk_service_points(world,_service_stairs(0.,true)):return false
	if not await _walk_service_points(world,[Vector3(3.65,3.2,-3.45),Vector3(3.65,3.2,-3.15),Vector3(5.9,3.2,-3.15),Vector3(8.55,3.2,-3.25),Vector3(10.95,3.2,-3.25),Vector3(10.95,3.2,-2.5),Vector3(12.5,3.2,-2.5),Vector3(13.6,3.2,-2.8),Vector3(14.5,3.2,-3.)]):return false
	var receiving: Transform3D=stock._thread_pose(radiator,stock.THREAD_END)
	world.player.camera.global_position=receiving.origin+radiator.global_basis*Vector3(.02,.15,-.35);world.player.camera.look_at(receiving.origin)
	if not await _deliver_service_part(world.player,replacement.body,receiving.origin):return false
	hand=PatrolHand.new();add_child(hand);hand.player=world.player;hand.click();hand.free()
	_check(replacement.slot==radiator.graph_node_id and absf(replacement.turn-stock.THREAD_END)<.0001,"delivered spare catches thread without auto seating")
	if not await _service_move_new(world.player,radiator,replacement.body,Vector3(0,.004,0),Vector3(.03,.10,-.08),0.):return false
	_check(radiator.vent_grade==2 and stock.active(radiator).body==replacement.body and stock.rows.size()==28 and stock.rows[original_id].body.identity==original_id,"physical exchange preserves all 28 identities and sets actual vent grade")
	if not await _service_supply(world.player,radiator,.42):return false
	await get_tree().create_timer(1.).timeout
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)=="repairable" and radiator._native_repair_seconds==0.,"partial one-pipe supply cannot prove repair")
	if not await _service_supply(world.player,radiator,1.):return false
	var deadline:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline and world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)!="repaired":await get_tree().physics_frame
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)=="repaired" and radiator.open_shift_condition=="repaired","sustained real steam completes original physical repair")
	if world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)!="repaired":print("[SERVICE THERMAL] ",radiator.get_heat_state()," mechanism=",radiator.mechanism_snapshot());return false
	if not await _walk_service(world,Vector3(13.6,3.2,-1.8)):return false
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID);world.service_round.dialogue.choose(0)
	_check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)=="closed","resident return closes authored round after actual repair")
	_check(beats==["call","resident","radiator_evidence","lobby_comparison","basement_comparison","diagnosis","repair","resident_return"],"physical production trace preserves complete ordered round")
	service_executed=world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)=="closed" and failures==0
	return service_executed

func _service_move_new(player: PlayerController,frame: Node3D,part: Node3D,point: Vector3,offset: Vector3,goal: float) -> bool:
	var hand:=PatrolHand.new();add_child(hand);hand.player=player
	var good: bool=await _service_move(hand,frame,part,point,offset,goal)
	hand.free();return good
