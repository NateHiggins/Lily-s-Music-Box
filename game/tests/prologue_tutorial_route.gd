extends "res://tests/orison_v2_4b_door_route_test.gd"
## Actual installed-world tutorial slice; DREAM/mirror/finale not executed.
const Director := preload("res://scripts/game/prologue_director.gd")
var director: Node

func _init() -> void:
	route_label="V2 PROLOGUE TUTORIAL SLICE"

func _prepare_player_start() -> void:
	var anchor: Dictionary=world.core_loop.resolve_return_anchor()
	player.global_position=anchor.position;player.velocity=Vector3.ZERO

func _route() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	director=Director.new();world.add_child(director)
	if not _require(director.configure(world),"actual 4B fixture and wall supports bound: "+str(director.errors)): return
	if not _require(director.begin_waking_preview(),"explicit waking-only slice begins without fake dream acceptance"): return
	var carrier: Node=world.service_set_carrier
	var draft_before: String=carrier.session.draft
	var lamp_before: bool=player.lamp_is_enabled()
	var radio_before: bool=carrier.device.radio_powered
	carrier.session.draft="Unsubmitted draft survives the opening."
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
			and not carrier.hand_is_enabled(),"story absence hides the single rig and rejects recall, typing and hand input"): return
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
