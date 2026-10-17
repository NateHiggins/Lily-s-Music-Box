extends Node3D
var station: Node3D
var player: PlayerController
var checks := 0
var failures := 0
var follows_cursor := true
var results: Array[Dictionary] = []

func observe_audio(owner: Node3D) -> Array[Dictionary]:
	var voices: Array[Node]=owner.find_children("*","AudioStreamPlayer3D",true,false)
	for i in AudioPolicy._voice_state.size():
		if AudioPolicy._voice_state[i].get("source_id",&"")==StringName(owner.name): voices.append(AudioPolicy._voices[i])
	var references: Array[Dictionary]=[]
	for voice: AudioStreamPlayer3D in voices:
		if voice.stream==null: continue
		references.append({"player":weakref(voice),"decoder":weakref(voice.get_stream_playback()) if voice.has_stream_playback() else null})
	return references

func audio_retired(references: Array[Dictionary]) -> bool:
	for reference in references:
		var voice = reference.player.get_ref()
		if voice!=null and voice.stream!=null: return false
		if reference.decoder!=null and reference.decoder.get_ref()!=null: return false
	return true

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1
	results.append({"ok":ok,"label":label})
	print("STATION HAND: ",label," = ",ok)

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	player._unhandled_input(event)

func acquire(key: String) -> bool:
	var part: Node3D=station._door if key=="door" else station._crank
	var point: Vector3=part.to_global(Vector3(.196,-.06,.025) if key=="door" else Vector3(0,.056,.025))
	if player.inspecting():
		var cursor := player.camera.unproject_position(point)
		Input.warp_mouse(cursor)
		# The OS warp is asynchronous. Let its motion arrive before grabbing;
		# otherwise it can become a second, opposite gesture on the held crank.
		for frame in 12:
			await get_tree().process_frame
			if get_viewport().get_mouse_position().distance_to(cursor)<2.0: break
		if get_viewport().get_mouse_position().distance_to(cursor)>=2.0:
			print("STATION CURSOR DID NOT SETTLE wanted=",cursor," actual=",get_viewport().get_mouse_position())
			return false
	else: player.camera.look_at(point)
	await get_tree().physics_frame
	await get_tree().physics_frame
	click()
	return player._grab.active() and station.held_part==key

func move_to(goal: float) -> bool:
	for i in 180:
		if not player._grab.active(): return false
		var target: Dictionary=player._grab.target
		var value: float=target.read.call()
		if absf(goal-value)<.001: return true
		var point: Vector3=target.part.to_global(player._grab.contact)
		var axis: Vector3=target.frame.global_basis*target.axis
		var tangent: Vector3=axis
		if target.kind=="hinge":
			tangent=axis.cross(point-target.part.global_position)
			if tangent.length()<.025: tangent=axis.cross(player.camera.global_basis.x)*.06
		var screen: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
		var depth_gesture := screen.length()<24.0 and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5
		if depth_gesture: screen=Vector2(0,tangent.dot(player.camera.global_basis.z)*180.0)
		var event := InputEventMouseMotion.new()
		event.relative=screen*clampf(goal-value,-.15 if target.kind=="hinge" else -.04,.15 if target.kind=="hinge" else .04)
		var before_screen: Vector2=player.camera.unproject_position(point)
		player._unhandled_input(event)
		var dispatched_value: float=target.read.call()
		await get_tree().physics_frame
		if not depth_gesture and target.kind=="hinge" and absf(float(target.read.call())-value)>.001:
			var after_screen: Vector2=player.camera.unproject_position(target.part.to_global(player._grab.contact))
			if (after_screen-before_screen).dot(event.relative)<0:
				follows_cursor=false
				print("HAND DIRECTION MISMATCH part=",target.part.name," before=",value," dispatched=",dispatched_value," after_frame=",target.read.call()," gesture=",event.relative," projected=",after_screen-before_screen)
	return false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled=false
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.15,.17,.20)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.7
	add_child(environment)
	var light := OmniLight3D.new()
	light.position=Vector3(.6,.6,1);light.light_energy=1.1
	add_child(light)
	station=preload("res://scripts/building/orison_v2_watch_station.gd").new()
	station.name="F02_STATION_CORE";station.station_id="F02_STATION_CORE"
	add_child(station)
	var line := WatchStationNetwork.new();add_child(line);line.register(station)
	var guard := TourKeyGuardProp.new();add_child(guard);guard.position.x=3
	line.attach_key_guard(guard)
	player=PlayerController.new();add_child(player)
	player.set_physics_process(false)
	player.position=Vector3(.12,-1.35,.8)
	player.camera.current=true;player.set_lamp_enabled(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	check(station._physical_grip("crank").is_empty(),"closed door blocks internal crank target")
	check(await acquire("door"),"actual pointer grabs native door handle")
	check(is_zero_approx(station.door_angle),"acquisition does not open door")
	check(await move_to(.5),"mouse moves door to partial hinge angle")
	click()
	check(is_equal_approx(station.door_angle,.5),"release retains partial opening")
	check(line.mark_count()==0,"door manipulation publishes no mark")
	check(await acquire("door"),"partial door can be reacquired")
	check(await move_to(1.65),"door swings clear of internal mechanism")
	click()
	check(await acquire("crank"),"exposed native crank is selectable")
	var motion := InputEventMouseMotion.new();motion.relative=Vector2(80,20)
	player._unhandled_input(motion)
	check(is_zero_approx(station.crank_angle) and line.mark_count()==0,"key custody prevents winding and publication")
	click()
	guard.take_key()
	check(await acquire("crank"),"carried tour key permits crank grab")
	check(await move_to(PI),"mouse winds half a revolution")
	check(is_equal_approx(station._wheel.rotation.z,-PI),"coded wheel follows the actual partial crank stroke")
	check(station._transmission.size()==3,"native three-wheel transmission is installed")
	check(is_equal_approx(station._transmission[0].rotation.z,-PI)
		and is_equal_approx(station._transmission[2].rotation.z,-PI),"input and output wheels turn with their shafts")
	check(is_equal_approx(station._transmission[1].rotation.z,2.0*atan2(-.078,-.082)-PI/24.0+PI),"idler reverses with meshed tooth phase")
	click()
	check(line.mark_count()==0 and not station.drop_fallen,"partial crank stroke does not mark")
	check(not station.reset_station() and is_equal_approx(station.crank_angle,PI)
		and is_equal_approx(station._wheel.rotation.z,-PI),"refused supervisor reset preserves partial mechanical position")
	check(await acquire("crank"),"grab before inspection")
	var inspect_event := InputEventKey.new()
	inspect_event.keycode=KEY_SPACE;inspect_event.physical_keycode=KEY_SPACE;inspect_event.pressed=true
	player._unhandled_input(inspect_event)
	check(player.inspecting(),"Space enters fixed inspection camera")
	await RenderingServer.frame_post_draw
	var fixed_camera := player.camera.global_transform
	var abort_state: Dictionary=station.maintenance_snapshot()
	station.restore_maintenance_snapshot(abort_state)
	check(station.held_part.is_empty() and is_equal_approx(station.crank_angle,PI),"maintenance restore retains partial position and clears hand")
	var saved: Dictionary=station.mechanism_snapshot()
	check(station.valid_mechanism(saved),"partial mechanical state validates")
	station.restore_mechanism(JSON.parse_string(JSON.stringify(saved)))
	check(is_equal_approx(station.crank_angle,PI),"serialized partial winding restores")
	check(await acquire("crank"),"restored crank can be reacquired")
	check(await move_to(TAU),"complete deliberate clockwise stroke")
	check(line.mark_count()==1 and station.drop_fallen,"full stroke emits exactly one guarded network record")
	check(station._crank.has_node("CrankLockStop") and station.has_node("LockoutGuide"),"native crank stop and bored lockout guide are installed")
	check(station._counter.position.is_equal_approx(Vector3(.0832,.198,.070)),"completed stroke seats lockout bar against crank stop")
	click()
	check(line.mark_count()==1,"release cannot duplicate mark")
	check(await acquire("crank"),"locked crank remains tangible")
	motion.relative=Vector2(-80,-20);player._unhandled_input(motion)
	check(line.mark_count()==1 and is_equal_approx(station.crank_angle,TAU),"lockout prevents re-winding and duplicate signals")
	click()
	check(follows_cursor,"visible rotating parts follow pointer direction")
	check(player.camera.global_transform.is_equal_approx(fixed_camera),"inspection cursor does not move camera")
	player.end_inspection()
	var invalid: Dictionary=station.mechanism_snapshot();invalid.door_angle=NAN
	check(not station.valid_mechanism(invalid),"nonfinite physical save rejected")
	check(not station.interact_control("station",player),"legacy player click cycle retired")
	player.camera.position=Vector3.ZERO
	player.camera.global_position=Vector3(.4,.28,.7)
	player.camera.look_at(Vector3(0,.16,.05))
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().get_texture().get_image().save_png(out.path_join("station_open.png"))
	var audio_references := observe_audio(station)
	player.queue_free();station.queue_free();guard.queue_free();line.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(.1).timeout
	check(audio_retired(audio_references),"station retirement releases owned players and decoders after audio settles")
	var file := FileAccess.open(out.path_join("bench_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "));file.close()
	print("STATION HAND RESULT ",checks," checks ",failures," failures")
	get_tree().quit(1 if failures else 0)
