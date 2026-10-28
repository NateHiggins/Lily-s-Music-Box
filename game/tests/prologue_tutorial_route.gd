extends "res://tests/orison_v2_4b_door_route_test.gd"
## Actual installed-world tutorial slice; DREAM/mirror/finale not executed.
const Director := preload("res://scripts/game/prologue_director.gd")
const BathCurtain := preload("res://scripts/props/clawfoot_curtain_motion.gd")
const Household := preload("res://scripts/building/orison_v2_household_state.gd")
var director: Node
var frame_trace:Node

class FrameTrace extends Node:
	var director:Node
	var rows:Array=[]
	var previous:=0
	var complete:=false
	var settings:Dictionary={}
	func _process(delta:float) -> void:
		var now:=Time.get_ticks_usec()
		if previous>0 and rows.size()<16384:
			var phase:String=str(director.state.phase) if is_instance_valid(director) else "retired"
			rows.append([phase,Engine.max_fps,delta*1000.0,float(now-previous)/1000.0,
				Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		previous=now
	func _exit_tree() -> void:
		var out:=OS.get_environment("SHOT_DIR")
		if out.is_empty():return
		var file:=FileAccess.open(out.path_join("tutorial_frame_times.json"),FileAccess.WRITE)
		if file==null:return
		file.store_string(JSON.stringify({"evidence_class":"INERT","complete":complete,
			"settings":settings,"columns":["phase","fps_cap","process_delta_ms","wall_ms","process_monitor_ms","physics_monitor_ms","draw_calls"],"frames":rows,
			"limits":"Occupied route starts after world construction; process/physics monitors overlap and lag. GPU/render-thread, compilation, loading and streaming costs are not independently attributed. Capture stalls and cap changes are retained; compare matched phases/caps, not an aggregate FPS."},"\t",true,true))

func _init() -> void:
	route_label="V2 PROLOGUE TUTORIAL SLICE"

func _prepare_player_start() -> void:
	var anchor: Dictionary=world.core_loop.resolve_return_anchor()
	player.global_position=anchor.position;player.velocity=Vector3.ZERO

func _route() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	if OS.get_environment("ORISON_BATH_REPAIR_REVIEW")=="1":
		await _review_installed_bath()
		return
	director=Director.new();world.add_child(director)
	if not _require(director.configure(world),"actual 4B fixture and wall supports bound: "+str(director.errors)): return
	frame_trace=FrameTrace.new();frame_trace.director=director
	frame_trace.settings={"viewport":str(get_viewport().size),"msaa_3d":get_viewport().msaa_3d,
		"engine":Engine.get_version_info(),"fixture_script":director.shower.get_script().resource_path,
		"weather":world.get_node("WeatherFX")._live_conditions.duplicate(true)}
	add_child(frame_trace)
	var carrier: Node=world.service_set_carrier
	var draft_before: String=carrier.session.draft
	var lamp_before: bool=player.lamp_is_enabled()
	var radio_before: bool=carrier.device.radio_powered
	carrier.session.draft="Unsubmitted draft survives the opening."
	if not _require(director.begin_waking_preview(),"explicit waking-only slice begins without fake dream acceptance"): return
	carrier.release_story_absence(world) # An unrelated caller cannot reveal it.
	carrier.set_capture_hidden(true)
	carrier.set_capture_hidden(false) # Review visibility cannot defeat story absence.
	var read_press := InputEventAction.new()
	read_press.action="teletype_read";read_press.pressed=true
	var reading_before: bool=carrier.reading
	Input.parse_input_event(read_press)
	await get_tree().process_frame
	read_press=InputEventAction.new();read_press.action="teletype_read";read_press.pressed=false
	Input.parse_input_event(read_press)
	if not _require(carrier.is_story_absent() and not carrier.rig.is_visible_in_tree()
			and carrier.reading==reading_before and not carrier.session.available()
			and not carrier.hand_is_enabled() and carrier.session.draft=="Unsubmitted draft survives the opening.","story absence retains draft, hides the single rig and rejects recall, typing and hand input"): return
	for area: Area3D in carrier.find_children("*","Area3D",true,false):
		if not _require(area.collision_layer==0,"absent companion has no query obstruction: "+str(area.name)): return
	if not _require(not player.flashlight.visible and player.flashlight.light_energy==0.0
			and player.lamp_is_enabled()==lamp_before and carrier.device.radio_powered==radio_before,
			"absent lamp emits nothing without changing switch or radio authority"): return
	player.face_world_point(director._bed_anchor.origin)
	await get_tree().create_timer(2.0).timeout
	await _shot("bedroom_writing.png")
	for at: Vector3 in [Vector3(-11.95,9.6,7.25),Vector3(-9.8,9.6,7.25),Vector3(-9.8,9.6,5.5),Vector3(-10.5,9.6,4.75)]:
		if not await _walk(at): return
	if not await _open_door("F04_B_BATH_DOOR"): return
	for at: Vector3 in [Vector3(-7.9,9.6,4.75),Vector3(-8.45,9.6,4.35)]:
		if not await _walk(at): return
	await get_tree().create_timer(.3).timeout
	if not _require(director.state.phase=="curtain_interaction","actual room entry selects curtain instruction"): return
	var shower: TapProp=director.shower
	player.face_world_point(director._bath_anchor.origin)
	await get_tree().create_timer(1.6).timeout
	await _shot("bathroom_writing.png")
	var plate: Node3D=world.adapter.resolve("F04_B_BATH_SWITCH")
	var fixture: Node=world.adapter.resolve("F04_B_BATH_LT_FLUSH_DOME")
	if not _require(plate!=null and fixture!=null,"bathroom switch and its existing fixture resolve"): return
	var lowest := INF
	for draw: MeshInstance3D in plate._model.find_children("*","MeshInstance3D",true,false):
		for corner in 8: lowest=minf(lowest,draw.to_global(draw.mesh.get_aabb().get_endpoint(corner)).y)
	var border_top: float=world.adapter.root.to_global(Vector3(0,9.6+1.2192+.03,0)).y
	if not _require(lowest>border_top,"whole switch plate clears tile and finishing border"): return
	if not await _drag_part(plate,plate._toggle.global_position,deg_to_rad(-22),"prologue_bath_light_off"): return
	if not _require(not fixture.powered,"raised switch still opens its authoritative bathroom circuit"): return
	if not await _drag_part(plate,plate._toggle.global_position,deg_to_rad(22),"prologue_bath_light_on"): return
	if not _require(fixture.powered,"raised switch restores the same fixture circuit"): return
	player.face_world_point(plate.global_position)
	await get_tree().create_timer(.8).timeout
	await _shot("bathroom_switch_above_tile.png")
	var window := world.adapter.root.get_node_or_null("F04_B_BATH_WINDOW_E/WindowTreatment") as Node3D
	if not _require(window!=null,"actual bathroom window curtain owner exists"): return
	# Household restore is not a witnessed player gesture and must not trigger
	# the joke. The physical opening below must leave the shower gate unfinished.
	var saved: Dictionary=window.settings_snapshot()
	window.set_settings(window.raised,window.tilt_degrees,.8,0.0)
	if not _require(director.message_id=="curtain_open","programmatic window change cannot invent wrong-curtain interaction"): return
	window.restore_settings(saved)
	if not await _walk(Vector3(-6.9,9.6,4.75)): return
	var extent: float=(window.width+.24)*.38
	if not await _drag_part(window,window.get_node("CurtainControl").global_position,extent,"prologue_wrong_curtain"): return
	if not _require(director.message_id=="wrong_curtain" and director.state.phase=="curtain_interaction"
			and "curtain_pulled" not in director.state.events,"actual window-curtain opening prompts correction without completing shower step"): return
	player.face_world_point(director._bath_anchor.origin)
	await get_tree().create_timer(1.6).timeout
	await _shot("wrong_curtain.png")
	if not await _walk(Vector3(-8.45,9.6,4.35)): return
	if not await _drag_part(shower,shower.to_global(Vector3(0,1.18,-.32)),1.78,"prologue_curtain"): return
	if not _require("curtain_pulled" in director.state.events and director.message_id=="cold_start","curtain release advances actual guidance"): return
	if not await _drag_part(shower,shower._handles[1].global_position,PI*.5,"prologue_cold"): return
	if not _require(director.state.phase=="shower_temperature" and shower.get_flow_state().temperature==0.0,"cold valve release begins temperature tutorial"): return
	if not await _drag_part(shower,shower._handles[0].global_position,PI*.5,"prologue_hot"): return
	await get_tree().create_timer(2.0).timeout
	if not _require(director.state.phase=="shower_complete" and "hot_water_adjusted" in director.state.events,"actual mixed valves reach forgiving comfort gate"): return
	await get_tree().create_timer(7.2).timeout
	if not _require(director.state.phase=="mirror_tapping","peace interval reaches shutoff guidance"): return
	if not await _drag_part(shower,shower._handles[0].global_position,0.0,"prologue_hot_off"): return
	if not _require(director.state.phase=="mirror_tapping" and director.message_id=="water_off","cold flow cannot falsely complete shutoff"): return
	if not await _drag_part(shower,shower._handles[1].global_position,0.0,"prologue_cold_off"): return
	if not _require(director.state.phase=="mirror_condensation" and not director.is_processing(),"real shower shutoff completes this bounded slice"): return
	var before: Dictionary=shower.mechanism_snapshot()
	director.shutdown()
	_require(before==shower.mechanism_snapshot(),"presentation retirement does not alter physical mechanisms")
	await get_tree().process_frame
	_require(not carrier.is_story_absent() and carrier.rig.is_visible_in_tree()
			and carrier.session.draft=="Unsubmitted draft survives the opening."
			and player.lamp_is_enabled()==lamp_before and carrier.device.radio_powered==radio_before,
			"shutdown restores original companion while retaining draft and power")
	carrier.session.draft=draft_before
	var temporary := Node.new();world.add_child(temporary)
	_require(carrier.acquire_story_absence(temporary),"temporary staging owner obtains lease")
	temporary.queue_free()
	await get_tree().process_frame
	_require(not carrier.is_story_absent() and carrier.rig.is_visible_in_tree(),"owner removal releases absence without stale hidden rig")
	await _review_refit(carrier)
	var out := OS.get_environment("SHOT_DIR")
	var file := FileAccess.open(out.path_join("tutorial_slice.json"),FileAccess.WRITE)
	if not _require(file!=null,"diagnostic output is writable"): return
	file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual bed-to-bath walking and curtain/cold/hot/shutoff input; no DREAM, body reveal, visitor, crossing, typing arm, finale or production-entry acceptance.","state":director.state,"errors":director.errors,"failures":failures},"\t"))
	frame_trace.complete=failures.is_empty()

func _bath_click() -> void:
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	player._unhandled_input(click)
	await get_tree().physics_frame

func _bath_valve(tap:TapProp,index:int,goal:float) -> bool:
	var part:Node3D=tap._handles[index]
	# Aim at the cap rather than its mounting pivot behind the wall finish.
	var cap:Vector3=part.to_global(Vector3(0,0,-.06))
	player.face_world_point(cap)
	await get_tree().physics_frame
	player.face_world_point(cap)
	if not _require(player._grab.find_target().get("part")==part,"ray selects the specific valve cap: "+str(index)):return false
	# The inherited room-route driver uses constant-size gestures to reach
	# endpoints. Use the existing adaptive hand for a deliberately partial turn.
	var hand:=preload("res://tests/fixed_gesture_patrol_hand.gd").new()
	add_child(hand);hand.player=player
	var moved:bool=await hand.operate(cap,goal,tap)
	hand.queue_free()
	return _require(moved and absf(tap._valve_openings[index]*PI*.5-goal)<.000001,"actual partial valve motion and release: "+str(index))

func _walk_bath_pose(tap:TapProp,local_target:Vector3) -> bool:
	# The ordinary room route stops 100mm short and checks immediately. The
	# bowl's fitted standing pose needs a centered capsule and time to settle
	# after stepping over its rim. Keep this precision local to this review.
	var target:Vector3=tap.model.to_global(local_target)
	var deadline:=Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<deadline:
		var delta:=target-player.global_position;delta.y=0
		if delta.length()<.006:break
		player.rotation.y=atan2(-delta.x,-delta.z);player.camera.rotation=Vector3.ZERO
		Input.action_press("move_forward",minf(1,delta.length()/.12))
		await get_tree().physics_frame
	Input.action_release("move_forward")
	for frame in 60:await get_tree().physics_frame
	var actual:Vector3=tap.model.to_local(player.global_position)
	var ok:=actual.distance_to(local_target)<.035
	trace.append({"bath_target":str(local_target),"bath_actual":str(actual),"ok":ok})
	return _require(ok,"walked precise tub stance and settled through real collision: "+str(actual))

func _review_installed_bath() -> void:
	var tap:TapProp=world.adapter.resolve("F04_4B_SHOWER_01")
	if not _require(tap!=null and tap.has_method("mount_fixture_collision") and tap.native_ready,"actual 4B loader mounts the native bath actor"):return
	# One explicit initial review placement. Subsequent access is walked.
	player.global_position=tap.model.to_global(Vector3(0,0,-1.05));player.velocity=Vector3.ZERO
	await get_tree().physics_frame
	player.face_world_point(tap.model.to_global(Vector3(0,1.25,0)))
	await _shot("installed_tub_closed")
	var point:Vector3=tap.model.to_global(BathCurtain.cloth_centerline(.75,.5,0))
	if not await _drag_part(tap,point,1.78,"installed_tub_curtain"):return
	if not await _walk_bath_pose(tap,Vector3(0,.239,0)):return
	for tick in 30:await get_tree().physics_frame
	if not _require(absf(tap.model.to_local(player.global_position).y-.239)<.045 and is_equal_approx(player._capsule.radius,PlayerController.BODY_RADIUS),"actual room admits the unshrunk standing capsule into the tub"):return
	for index in 2:
		if not await _bath_valve(tap,index,PI*.5*(.85 if index==0 else .5)):return
	var sources:Array=world.bathroom_moisture._sources.filter(func(source:Dictionary):return source.tap==tap)
	if not _require(sources.size()==1 and sources[0].spray.emitting,"one existing moisture owner emits the actual shower cone"):return
	player.face_world_point(tap._stream.global_position-Vector3.UP*.35)
	await get_tree().create_timer(.6).timeout
	await _shot("installed_tub_shower_cone")
	player.face_world_point(tap.model.to_global(Vector3(0,2.28,.44)))
	await _shot("installed_tub_wall_supports")
	if not await _drag_part(tap,tap.diverter.global_position,0.0,"installed_tub_filler"):return
	if not _require(not sources[0].spray.emitting and tap.filler.visible and tap.spray_flow_amount()==0,"filler diversion stops GPU shower emission through authoritative flow"):return
	player.face_world_point(tap._bath_plug.global_position)
	await get_tree().physics_frame
	var target:Dictionary=player._grab.find_target()
	if not _require(target.get("part")==tap._bath_plug,"occupied bowl leaves the specific stopper accessible"):return
	await _bath_click()
	if not _require(player._grab.active() and player._grab.target.part==tap._bath_plug,"primary grabs the installed stopper"):return
	var pixels:Vector2=player.camera.unproject_position(tap.model.to_global(tap.plug_seat))-player.camera.unproject_position(tap._bath_plug.global_position)
	for index in 12:
		var motion:=InputEventMouseMotion.new();motion.relative=pixels/12
		player._unhandled_input(motion);await get_tree().physics_frame
	await _bath_click()
	if not _require(not player._grab.active() and tap._stopper,"installed stopper snaps into the drain on release"):return
	await get_tree().create_timer(2.0).timeout
	if not _require(tap._water_level>.05,"actual occupied tub collects mixed supply behind its sealed drain"):return
	player.face_world_point(tap.model.to_global(Vector3(-.32,.90,.28)))
	await _shot("installed_tub_filler_and_chain")
	for index in 2:
		if not await _bath_valve(tap,index,0.0):return
	if not await _walk_bath_pose(tap,Vector3(0,0,-1.05)):return
	for tick in 30:await get_tree().physics_frame
	if not _require(absf(tap.model.to_local(player.global_position).y)<.045,"actual room permits return to its original floor"):return
	if OS.get_environment("ORISON_BATH_OPTICAL_ONLY")=="1":
		# An exterior view distinguishes the whole cone from the view while
		# standing within it. Restore flow through real controls, then shut off.
		for index in 2:
			if not await _bath_valve(tap,index,PI*.5*(.85 if index==0 else .5)):return
		if not await _drag_part(tap,tap.diverter.global_position,.012,"exterior_shower_diversion"):return
		player.face_world_point(tap._stream.global_position-Vector3.UP*.7)
		await get_tree().create_timer(.6).timeout
		await _shot("installed_tub_shower_exterior")
		for index in 2:
			if not await _bath_valve(tap,index,0.0):return
		print("BATH OPTICAL REVIEW: INERT input/capture review; disk reconstruction is not run in this mode.")
		return
	var old_path:String=RealityState.save_path
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("validated_bath_campaign.json")
	await _save_rebuild_bath(tap)
	RealityState.flush_background_saves();RealityState.save_path=old_path
	var file:=FileAccess.open(OS.get_environment("SHOT_DIR").path_join("bath_world.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","checks":interaction_checks,"failures":failures,
		"scope":"Actual 4B actor, walked vessel access, native controls/spray and validated campaign disk save with world reconstruction. No complete prologue, whole-V2 surface qualification, global navigation, performance attribution or human acceptance."},"\t",true,true))

func _save_rebuild_bath(tap:TapProp) -> void:
	var wanted:Dictionary=tap.mechanism_snapshot()
	var complete_household:Dictionary=world.household_state.snapshot()
	if not _require(world.household_state.validate(complete_household,world.household_state._kinds),"existing household validator accepts the complete mixed fixture roster"):return
	if not _require(RealityState.save_game() and FileAccess.file_exists(RealityState.save_path),"existing campaign storage writes an isolated real save"):return
	var key:String=Household.KEY
	if not _require(RealityState.data[key].records["F04_4B_SHOWER_01"].value==wanted,"campaign snapshot contains the actual released tub controls"):return
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RealityState.save_path))
	var protected_domains:Dictionary={}
	for domain:String in ["cases","inventories","work_orders","resident_trust","newspapers_collected","discovered_documents","campaign_clock"]:
		if saved.has(domain):protected_domains[domain]=saved[domain]
	var previous:WeakRef=weakref(tap)
	world.shutdown_for_tests();remove_child(world);world.free()
	await get_tree().process_frame
	if not _require(previous.get_ref()==null,"retired world releases the original bath and its callbacks"):return
	RealityState.reset_campaign_for_tests();RealityState.load_game()
	var loaded:=_require(RealityState.load_status().status=="loaded" and not RealityState.save_write_blocked,"existing validated campaign loader accepts the complete saved document")
	for domain:String in protected_domains:
		loaded=_require(RealityState.data.get(domain)==protected_domains[domain],"load preserves authoritative domain: "+domain) and loaded
	world=Runtime.instantiate();add_child(world)
	var deadline:=Time.get_ticks_msec()+240000
	while world.startup_ms<=0 and not world.startup_failed and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	if not loaded:return
	if not _require(not world.startup_failed and world.startup_ms>0,"saved household reconstructs on a fresh occupied V2 world"):return
	player=world.player
	var restored:TapProp=world.adapter.resolve("F04_4B_SHOWER_01")
	if not _require(restored!=null and restored!=previous.get_ref(),"new 4B bath owner is resolved after rebuild"):return
	await get_tree().physics_frame;await get_tree().physics_frame
	var actual:Dictionary=restored.mechanism_snapshot()
	var exact:=Vector3(actual.plug[0],actual.plug[1],actual.plug[2])==Vector3(wanted.plug[0],wanted.plug[1],wanted.plug[2])
	var error:=0.0
	for field:String in ["hot","cold","curtain","water","diverter"]:error=maxf(error,absf(float(actual[field])-float(wanted[field])))
	_require(exact and error<1e-12,"fresh actor restores the released plug and every saved control/water value")
	_require(restored._held_valve==-1 and not restored._curtain_hand.held and not restored._plug_hand.held,"reload does not resurrect transient input ownership")
	_require(world.bathroom_moisture._rooms["F04_B_BATH"].humidity==0.0,"transient room steam does not reappear as stale saved observations")

func _review_refit(carrier: Node) -> void:
	player.face_world_point(director._bath_anchor.origin)
	var old_cap := Engine.max_fps
	var records: Array[Dictionary]=[]
	var min_up := 1.0
	var valid := true
	var drift_min := Vector2(INF,INF)
	var drift_max := Vector2(-INF,-INF)
	for cap in [30,60,144]:
		Engine.max_fps=cap
		var walls: Array[float]=[]
		var previous := Time.get_ticks_usec()
		for index in 100:
			if index in [10,35,65]:
				var turn := InputEventMouseMotion.new()
				turn.relative=Vector2(35 if index!=35 else -70,0)
				player._unhandled_input(turn)
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			walls.append(float(now-previous)/1000.0);previous=now
			valid=valid and carrier.motion.global_transform.is_finite() and carrier.rig.global_transform.is_finite()
			var up: Vector3=carrier.rig.global_basis.y.normalized()
			min_up=minf(min_up,up.dot(player.camera.global_basis.y.normalized()))
			var drift: Vector2=carrier.screen_frame._drift
			drift_min=drift_min.min(drift);drift_max=drift_max.max(drift)
			var rect: Rect2=carrier.screen_frame.safe_rect
			valid=valid and rect.position.x>=2.0/3.0 and rect.end.x<=1.0
		walls.sort()
		records.append({"cap":cap,"wall_ms_p50":walls[50],"wall_ms_p95":walls[95],"wall_ms_p99":walls[99],"wall_ms_max":walls[-1]})
	Engine.max_fps=old_cap
	_require(valid and min_up>.95,"phone refit remains finite, upright and in the contextual right third at 30/60/144 caps")
	_require((drift_max-drift_min).length()>.005,"accompanying bot follows a visible bounded flight path instead of a pinned pose")
	_require(carrier.rig.global_basis.get_scale().distance_to(Vector3.ONE*.42)<.0001,"single manufactured assembly retains uniform phone-sized scale")
	player.face_world_point(director._bath_anchor.origin)
	await get_tree().create_timer(.8).timeout
	await _shot("bathroom_phone_accompany.png")
	for pressed in [true,false]:
		var key := InputEventKey.new();key.keycode=KEY_E;key.physical_keycode=KEY_E;key.pressed=pressed
		Input.parse_input_event(key);Input.flush_buffered_events()
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	_require(carrier.reading and carrier.motion.steady_for_input(),"actual recall presents refitted physical interface")
	await _shot("bathroom_phone_reading.png")
	var out := FileAccess.open(OS.get_environment("SHOT_DIR").path_join("phone_flight.json"),FileAccess.WRITE)
	if _require(out!=null,"flight diagnostic output writable"):
		out.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Occupied 4B capped-rate station-keeping and camera-turn diagnostic; no matched performance gain or artistic acceptance.","records":records,"minimum_upright_dot":min_up,"drift_span":str(drift_max-drift_min)},"\t"))

func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var saved := get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(name_))
	_require(saved==OK,"capture written "+name_)
