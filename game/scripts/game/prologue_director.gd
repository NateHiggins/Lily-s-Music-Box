extends Node
## Working slices: waking/shower guidance and the console/sky/historical finale.
## Not installed into normal entry until the complete opening is qualified.
signal phase_changed(phase: String)
signal transcription_changed(text: String)
const State := preload("res://scripts/game/prologue_state.gd")
const Writing := preload("res://scripts/game/signal_surface_writing.gd")
const TemporalConsole:=preload("res://scripts/game/prologue_temporal_console.gd")
const TemporalSky:=preload("res://scripts/game/prologue_temporal_sky.gd")
const WORDS := "res://data/dialogue/prologue.json"
const PERIOD := 0.1
const COMFORT := Vector2(0.30,0.57)
var world: Node3D
var player: PlayerController
var shower: TapProp
var state: Dictionary={}
var errors: Array[String]=[]
var message_id := ""
var writing: Node3D
var _messages: Dictionary={}
var _frame: Node3D
var _bed_anchor: Transform3D
var _bath_anchor: Transform3D
var _poll := 0.0
var _phase_age := 0.0
var _comfortable := 0.0
var _publishing := false
var _running := false
var _last_moved_valve := -1
var _document: Dictionary={}
var _carrier: Node
var _window_controls: Array[Node]=[]
var temporal_console:Node
var temporal_sky:Node
var mirror_crossing:Node
var mirror:MedicineCabinetProp
var _avatar_visible:=true
var _avatar_leased:=false
var _reflection_dwell:=0.0
var _withdrawal_seen:=false
var _knock_index:=0
var _knock:AudioStreamPlayer3D
var _visitor_active:=false
var _visitor_anchor:=Vector3.ZERO
var _visitor_center:=Vector3.ZERO
var _visitor_basis:=Basis.IDENTITY
var _visitor_dwell:=0.0
var _visitor_return_dwell:=0.0
var _contact_index:=0
var _contact_age:=0.0
var _contact_thinking_age:=0.0
var _contact_serial:=-1
var _contact_emotion:=""
var _contact_reading_before:=false
var _contact_owns:=false
var _contact_copies:Array[int]=[]
var waking:Node


func _ready() -> void:
	process_priority=110 # Read the selected/posed mirror after its owner (100).
	set_process(false)

func configure(owner_world: Node3D) -> bool:
	if world!=null or owner_world==null or RealityState.save_write_blocked: return false
	world=owner_world;player=world.player;_frame=world.adapter.root
	shower=world.adapter.resolve("F04_4B_SHOWER_01") as TapProp
	if player==null or shower==null: return _fail("missing installed 4B player/shower")
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(WORDS))
	if data is not Dictionary or data.get("schema_version")!=1 or data.get("messages") is not Array: return _fail("invalid prologue writing catalogue")
	for row: Variant in data.messages:
		if row is not Dictionary or row.get("id") is not String or row.get("text") is not String: return _fail("invalid writing row")
		if row.id.is_empty() or row.text.is_empty() or _messages.has(row.id): return _fail("duplicate/empty writing row")
		_messages[row.id]=row.text
	for id in ["wake_passed","wake_shower","curtain_open","wrong_curtain","cold_start","hot_start","more_hot","less_hot","comfort","hot_off","water_off","cabinet_open","contact_sorry","contact_murder","contact_bigger","contact_who","contact_connect"]:
		if not _messages.has(id): return _fail("missing writing message "+id)
	# One mounting survey per support. The actual wall hit supplies the frame;
	# do not float lettering at a guessed wall plane or scan interaction targets.
	_bed_anchor=_wall_anchor(Vector3(-10.55,11.35,9.8),Vector3.LEFT)
	# Clear south-wall stock west of the cabinet, above the tiled wainscot.
	_bath_anchor=_wall_anchor(Vector3(-8.55,11.35,3.45),Vector3.BACK)
	if not errors.is_empty(): return false
	writing=Writing.new();writing.name="SignalSurfaceWriting";world.add_child(writing)
	writing.transcription_changed.connect(func(text: String): transcription_changed.emit(text))
	shower.manipulation_changed.connect(_released)
	shower.flow_changed.connect(_flow_changed)
	for treatment: Node in get_tree().get_nodes_in_group("v2_window_treatments"):
		if world.is_ancestor_of(treatment) and treatment.get_meta("unit","")=="4B":
			treatment.control_released.connect(_window_released)
			_window_controls.append(treatment)
	for surface:Node in get_tree().get_nodes_in_group("planar_mirror_surface"):
		if not world.is_ancestor_of(surface):continue
		var owner_node:Node=surface.get_parent()
		while owner_node!=null and owner_node is not MedicineCabinetProp:owner_node=owner_node.get_parent()
		if owner_node is MedicineCabinetProp and owner_node.unit=="4B":
			if mirror!=null:return _fail("ambiguous 4B mirror owner")
			mirror=owner_node
	if mirror==null:return _fail("missing installed 4B medicine cabinet")
	if mirror.mirror_surface().has_meta("prologue_mirror_film"):return _fail("mirror presentation already owned")
	mirror.manipulation_released.connect(_cabinet_released)
	RealityState.state_changed.connect(_restore)
	_restore()
	return errors.is_empty()

func _wall_anchor(at: Vector3, normal: Vector3) -> Transform3D:
	var start: Vector3=_frame.to_global(at+normal*.32)
	var finish: Vector3=_frame.to_global(at-normal*.18)
	var query := PhysicsRayQueryParameters3D.create(start,finish,1,[player.get_rid()])
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	var expected: Vector3=(_frame.global_basis*normal).normalized()
	if hit.is_empty() or (hit.normal as Vector3).dot(expected)<.95:
		_fail("writing support wall not found at "+str(at));return Transform3D.IDENTITY
	return Transform3D(Basis.looking_at(-expected,Vector3.UP),hit.position+expected*.006)

func _claim_waking_presentation() -> bool:
	_carrier=world.service_set_carrier
	if _carrier==null or (not state.effects.companion_materialized and not _carrier.acquire_story_absence(self)): return _fail("companion absence lease refused")
	if not _avatar_leased:
		_avatar_visible=world.player_avatar.visible;_avatar_leased=true
	_running=true;set_process(true)
	return true

func begin_opening(cover_scene:PackedScene) -> bool:
	# Real DREAM/wake candidate. Normal entry remains gated until its occupied
	# optical/input/reload qualification; the preview below is never a substitute.
	if world==null or not errors.is_empty() or state.phase not in ["dream","awakening"] or is_instance_valid(waking) or get_tree().paused or RealityState.save_write_blocked:return false
	waking=preload("res://scripts/game/prologue_waking.gd").new();add_child(waking)
	if not waking.start(self,cover_scene):
		var reason:String=waking.failure
		var retryable:bool=waking.input_refused
		waking.queue_free();waking=null
		if retryable:return false
		return _fail("opening shot refused: "+reason)
	if not _claim_waking_presentation():
		waking.cancel();waking.queue_free();waking=null
		return false
	world.player_avatar.hide()
	waking.finished.connect(func(_completed:bool):
		if is_instance_valid(waking):waking.queue_free()
		waking=null)
	return true

func resume_opening(cover_scene:PackedScene) -> bool:
	# Campaign startup must resume validated facts, never use the preview's
	# deliberate DREAM advancement. A completed opening is an inert no-op.
	if world==null or not errors.is_empty() or not is_same(_document,RealityState.data) or get_tree().paused or RealityState.save_write_blocked:return false
	if state.phase=="prologue_complete":return true
	if player.protected_input_active():return false
	if player.text_input_owner!=null or not player.camera.is_current():
		# Our own active presentation is already resumed; a foreign owner must
		# remain untouched. Do not restart a clip or reset its phase timers.
		if not _running:return false
		if is_instance_valid(waking) and waking.active and player.text_input_owner==waking and waking.camera.is_current():return true
		if is_instance_valid(temporal_sky) and (temporal_sky.active or temporal_sky.holding) and player.text_input_owner==temporal_sky and temporal_sky.is_ancestor_of(get_viewport().get_camera_3d()):return true
		return _contact_owns and player.text_input_owner==self and player.camera.is_current()
	if state.phase in ["dream","awakening"]:return begin_opening(cover_scene)
	if _running:
		# A previous presentation attempt may have been refused by its owner.
		# Keep the saved phase retryable instead of reporting an idle clip ready.
		return begin_temporal_sky() if state.phase in ["temporal_synchronization","title_reveal"] else true
	if not _claim_waking_presentation():return false
	_enter_phase()
	if state.phase=="title_reveal":return begin_temporal_sky()
	return errors.is_empty()

func begin_waking_preview() -> bool:
	# Explicit incomplete-slice preview only; it does not claim DREAM was played.
	if world==null or not errors.is_empty() or state.phase not in ["dream","awakening","bedroom_exploration","bathroom_entry","curtain_interaction","shower_temperature","shower_complete","mirror_tapping","mirror_condensation","protagonist_reveal","cabinet_inspection","reflection_visitor","companion_crossing","first_contact"]: return false
	while state.phase in ["dream","awakening"]:
		var next: String=State.PHASES[State.PHASES.find(state.phase)+1]
		if not _store(State.advance(state,next)): return false
	if not _claim_waking_presentation():return false
	_enter_phase()
	return true

func begin_temporal_command() -> bool:
	if world==null or RealityState.save_write_blocked or state.get("phase","")!="temporal_command":return false
	if not is_same(_document,RealityState.data):return false
	if not is_instance_valid(_carrier):_carrier=world.service_set_carrier
	if not is_instance_valid(_carrier) or _carrier.arm_busy():return false
	# An accepted saved command is not reprinted or resampled after reload.
	if "destination_accepted" in state.events:return _advance("temporal_synchronization")
	if state.target.is_empty():
		if not _store(State.with_target(state,State.sample_destination())):return false
	if is_instance_valid(temporal_console):temporal_console.queue_free()
	temporal_console=TemporalConsole.new();add_child(temporal_console)
	temporal_console.accepted.connect(_temporal_accepted)
	temporal_console.finished.connect(_temporal_finished)
	return temporal_console.start(_carrier,state.target)

func _temporal_accepted(target:Dictionary) -> void:
	if is_same(_document,RealityState.data) and state.phase=="temporal_command" and state.target==target:
		_remember_contact_copy(_carrier.device.teletype._serial)
		_observe("destination_accepted")

func _temporal_finished(completed:bool) -> void:
	if completed and is_same(_document,RealityState.data) and state.phase=="temporal_command" and "destination_accepted" in state.events:
		_advance("temporal_synchronization")

func begin_temporal_sky() -> bool:
	if world==null or not is_same(_document,RealityState.data) or state.get("phase","") not in ["temporal_synchronization","title_reveal"]:return false
	if is_instance_valid(temporal_sky) and (temporal_sky.active or temporal_sky.holding):return false
	if state.phase=="temporal_synchronization" and state.effects.clock_applied:
		if not finish_temporal_synchronization():return false
	if is_instance_valid(temporal_sky):temporal_sky.queue_free()
	temporal_sky=TemporalSky.new();add_child(temporal_sky)
	return temporal_sky.start(world,func() -> bool:
		if temporal_sky.was_skipped and not _store(State.request_skip(state)):return false
		return finish_temporal_synchronization(),finish_historical_cutaway)

func finish_historical_cutaway(skipped:bool) -> bool:
	if not is_same(_document,RealityState.data):return false
	if state.get("phase","")=="prologue_complete":return true
	if state.get("phase","")!="title_reveal" or not state.effects.clock_applied:return false
	if skipped:
		if not _store(State.request_skip(state)):return false
	elif not _observe("title_presented"):return false
	return _advance("prologue_complete")

## Called only by the completed visual transition (or its explicit skip).
## The historical bedroom cutaway must never call the clock owner again.
func finish_temporal_synchronization() -> bool:
	if not is_same(_document,RealityState.data) or state.get("phase","")!="temporal_synchronization":return false
	if not CampaignClock.new().apply_prologue_destination():return false
	_restore()
	if state.skipped:return _advance("title_reveal")
	return _observe("temporal_transition_complete") and _advance("title_reveal")

func _restore() -> void:
	if _publishing: return
	var replaced := not is_same(_document,RealityState.data)
	if replaced and is_instance_valid(waking):waking.cancel()
	if replaced:_release_contact()
	if replaced and is_instance_valid(temporal_console):temporal_console.cancel()
	if replaced and is_instance_valid(temporal_sky):temporal_sky.cancel()
	if replaced and is_instance_valid(mirror_crossing):mirror_crossing.cancel()
	if replaced and is_instance_valid(_carrier):
		_carrier.device.teletype.retire_transient_copies(_contact_copies)
		_contact_copies.clear()
	var restored := State.restore(RealityState.data.get("prologue",{}))
	if restored.is_empty(): _fail("invalid prologue state");return
	_document=RealityState.data
	if replaced: _last_moved_valve=-1
	if restored==state and not replaced: return
	var changed: bool=state.get("phase","")!=restored.phase
	state=restored
	if (changed or replaced) and _running:
		if is_instance_valid(_carrier):
			if state.effects.companion_materialized:_carrier.release_story_absence(self)
			elif not _carrier.acquire_story_absence(self):_fail("restored opening absence refused");return
		_enter_phase()

func _store(next: Dictionary) -> bool:
	if next.is_empty() or RealityState.save_write_blocked: return _fail("prologue transition refused")
	if next==state: return true
	state=next
	_publishing=true;RealityState.data.prologue=state.duplicate(true)
	RealityState.commit_background();_publishing=false
	return true

func _observe(event: String) -> bool:
	if event in state.events: return true
	return _store(State.observe(state,event))

func _advance(next: String) -> bool:
	if not _store(State.advance(state,next)): return false
	_enter_phase();return true

func _enter_phase() -> void:
	_release_contact(state.phase in ["identity_mystery","temporal_command"])
	_contact_index=0;_contact_age=0;_contact_thinking_age=0;_contact_serial=-1
	if _visitor_active and state.phase!="companion_crossing":_end_visitor()
	_phase_age=0;_comfortable=0;message_id="";_reflection_dwell=0;_knock_index=0;_withdrawal_seen=false
	if _avatar_leased:
		world.player_avatar.visible=State.PHASES.find(state.phase)>=State.PHASES.find("protagonist_reveal") and _avatar_visible
	if state.phase in ["mirror_tapping","mirror_condensation"]:_set_mirror_film(Vector2(1,0))
	elif state.phase in ["protagonist_reveal","cabinet_inspection","reflection_visitor"]:_set_mirror_film(Vector2(1,1))
	elif mirror!=null:_set_mirror_film(Vector2(-1,0))
	if is_instance_valid(_knock):_knock.stop()
	match state.phase:
		"bedroom_exploration": _say("wake_passed",false)
		"bathroom_entry": _advance("curtain_interaction");return
		"curtain_interaction": _say("cold_start" if "curtain_pulled" in state.events else "curtain_open",true)
		"shower_temperature": _say("hot_start",true)
		"shower_complete": _say("comfort",true)
		"mirror_tapping": _say("hot_off",true)
		"mirror_condensation":writing.clear()
		"protagonist_reveal":writing.clear()
		"cabinet_inspection":
			if "cabinet_opened" not in state.events:_say("cabinet_open",true)
			else:writing.clear()
		"reflection_visitor":
			writing.clear()
			if not _begin_visitor():return
		"companion_crossing":
			writing.clear()
		"first_contact","identity_mystery":writing.clear()
		"temporal_command":
			if is_instance_valid(_carrier):_carrier.reading=true
		"temporal_synchronization":
			if world!=null and world.has_node("WakingAtmosphere"):begin_temporal_sky()
	phase_changed.emit(state.phase)

func _say(id: String, bathroom: bool) -> void:
	if id==message_id: return
	message_id=id
	writing.global_transform=_bath_anchor if bathroom else _bed_anchor
	var reveal := 0.7 if bool(GameBoot.settings.get("reduce_flashing",false)) else 1.35
	if not writing.show_message(_messages[id],reveal,-1.0,.9 if bathroom else 1.25): _fail("writing presentation refused "+id)

func _released() -> void:
	if not _running or get_tree().paused or player.call_locked or RealityState.save_write_blocked: return
	if not is_same(_document,RealityState.data): _last_moved_valve=-1;return
	var moved := _last_moved_valve;_last_moved_valve=-1
	var flow: Dictionary=shower.get_flow_state()
	match state.phase:
		"curtain_interaction":
			if shower.is_curtain_open():
				if not _observe("curtain_pulled"): return
				_say("cold_start",true)
				if moved==1 and float(flow.cold_opening)>.1 and float(flow.hot_opening)<.001:
					if _observe("cold_water_started"): _advance("shower_temperature")
		"shower_temperature":
			if moved==0: _observe("hot_water_adjusted")
		"mirror_tapping":
			if float(flow.flow)<=.001:
				if _observe("shower_stopped"): _advance("mirror_condensation")
			elif not bool(flow.hot): _say("water_off",true)

func _flow_changed() -> void:
	# Restore/supply notifications cannot manufacture tutorial interaction.
	if _running and is_same(_document,RealityState.data) and shower._held_valve in [0,1]: _last_moved_valve=shower._held_valve

func _window_released(control: String, before: float, after: float) -> void:
	if not _running or get_tree().paused or player.call_locked or RealityState.save_write_blocked: return
	if not is_same(_document,RealityState.data): return
	if state.phase=="curtain_interaction" and "curtain_pulled" not in state.events \
			and control=="curtain" and after>.1 and after>before+.02:
		_say("wrong_curtain",true)

func _process(delta: float) -> void:
	if _visitor_active:_pose_visitor()
	if _running and state.phase in ["first_contact","identity_mystery"]:
		_contact_tick(delta);return
	if not _running or player.call_locked or player.mouse_released or RealityState.save_write_blocked: return
	if not is_same(_document,RealityState.data): return
	var step:=maxf(delta,0.0)
	_phase_age+=step
	if state.phase=="mirror_condensation":
		if not _withdrawal_seen:_phase_age=minf(_phase_age,1.5)
		else:_set_mirror_film(Vector2(1,smoothstep(2.0,10.0,_phase_age)))
	# Presentation consumes the same phase age every frame. Story observations
	# retain their existing cadence, with no protected-input time accumulated.
	_poll+=step
	if _poll<PERIOD: return
	var elapsed := _poll;_poll=0
	match state.phase:
		"bedroom_exploration":
			if _phase_age>=4.0: _say("wake_shower",false)
			if world.room_at_world(player.global_position+Vector3.UP*.7)=="F04_B_BATH":
				if _observe("bathroom_entered"): _advance("bathroom_entry")
		"shower_temperature":
			var flow: Dictionary=shower.get_flow_state()
			var temperature := float(flow.temperature)
			var mixed: bool=float(flow.hot_opening)>.1 and float(flow.cold_opening)>.1
			var comfortable: bool=mixed and temperature>=COMFORT.x and temperature<=COMFORT.y
			_comfortable=_comfortable+elapsed if comfortable else 0.0
			if _phase_age>=2.5:
				_say("comfort" if comfortable else "less_hot" if temperature>COMFORT.y else "more_hot",true)
			if _comfortable>=1.5 and "hot_water_adjusted" in state.events and shower._held_valve==-1 and not player._grab.active():
				if _observe("temperature_balanced"): _advance("shower_complete")
		"shower_complete":
			if _phase_age>=7.0: _advance("mirror_tapping")
		"mirror_tapping":_tap_mirror()
		"mirror_condensation":
			# Let the player find the tapping before the branching moment runs.
			if not _withdrawal_seen:
				_withdrawal_seen=_mirror_observed()
				if not _withdrawal_seen:_phase_age=minf(_phase_age,1.5);return
			# Restore the synchronized body behind opaque film before paths open.
			if _avatar_leased and _phase_age>=2.5:world.player_avatar.visible=_avatar_visible
			_set_mirror_film(Vector2(1,smoothstep(2.0,10.0,_phase_age)))
			if _phase_age>=10.0:_advance("protagonist_reveal")
		"protagonist_reveal":
			if _mirror_observed():_reflection_dwell+=elapsed
			if _reflection_dwell>=8.0:
				if _observe("reflection_observed"):_advance("cabinet_inspection")
		"cabinet_inspection":
			if not ("cabinet_opened" in state.events) or _phase_age>=6.0:_tap_mirror()
		"reflection_visitor":_observe_visitor(elapsed)
		"companion_crossing":
			if not is_instance_valid(mirror_crossing) or not mirror_crossing.active:
				if not _mirror_observed():return
				if not _visitor_active and not _begin_visitor():return
				if is_instance_valid(mirror_crossing):mirror_crossing.queue_free()
				mirror_crossing=preload("res://scripts/game/prologue_mirror_crossing.gd").new();add_child(mirror_crossing)
				mirror_crossing.finished.connect(_crossing_finished)
				mirror_crossing.start(self)
		"temporal_command":
			# First let the real flight owner leave its protected observation
			# stance. Starting a key cycle before that cancels its waiting arm.
			if is_instance_valid(_carrier) and _carrier.motion.steady_for_input() and (not is_instance_valid(temporal_console) or not temporal_console.active):begin_temporal_command()

func _crossing_finished(completed:bool) -> void:
	if completed and is_same(_document,RealityState.data) and state.phase=="companion_crossing":
		if _store(State.applied(state,"companion_materialized")):_advance("first_contact")

func _release_contact(keep_reading:=false) -> void:
	if not _contact_owns:return
	_contact_owns=false
	if is_instance_valid(player):player.release_text_input(self)
	if is_instance_valid(_carrier):
		_carrier.release_story_pose(self)
		_carrier.reading=true if keep_reading else _contact_reading_before
	_contact_emotion=""

func _contact_face(expression:String) -> void:
	_contact_emotion=expression
	_carrier.set_story_face(self,expression)

func _remember_contact_copy(serial:int) -> void:
	if serial<=0 or serial in _contact_copies:return
	_contact_copies.append(serial)
	if _contact_copies.size()>_carrier.device.teletype.HISTORY_LIMIT:_contact_copies.pop_front()

func _contact_tick(delta:float) -> void:
	if not is_same(_document,RealityState.data) or RealityState.save_write_blocked or not is_instance_valid(_carrier):_release_contact();return
	if state.phase=="first_contact" and "murder_presented" in state.events:_advance("identity_mystery");return
	var session:Node=_carrier.session
	if get_tree().paused or player.protected_input_active() or player.mouse_released or not player.camera.is_current() or not _carrier.device.radio_powered or _carrier.device.incoming_call or session.typing or session.opening or session._foreign_editor_active():
		_release_contact();return
	if player.text_input_owner!=self:
		if not player.acquire_text_input(self):return
		_contact_reading_before=_carrier.reading;_contact_owns=true
		_carrier.reading=true
	var ids:Array=["contact_sorry","contact_murder"] if state.phase=="first_contact" else ["contact_bigger","contact_who","contact_connect"]
	var expressions:Array=["sympathetic","grinning"] if state.phase=="first_contact" else ["conspiratorial","thoughtful","grinning"]
	# Completed identity revelation resumes at the final line after reload.
	if state.phase=="identity_mystery" and "identity_question_presented" in state.events and _contact_index<2:_contact_index=2
	var paper:Node=_carrier.device.teletype
	if _contact_serial>=0 and paper._serial!=_contact_serial:
		_contact_serial=-1;_contact_age=0;_contact_thinking_age=0 # A real field copy took priority.
	if _contact_serial<0:
		if paper.printing or _carrier.arm_busy():return
		if not _carrier.print_telegram_card({"title":"","body":_messages[ids[_contact_index]]},true):return
		_contact_serial=paper._serial;_contact_age=0;_contact_thinking_age=0
		_remember_contact_copy(_contact_serial)
		_contact_face(expressions[_contact_index])
	elif _contact_emotion.is_empty():_contact_face(expressions[_contact_index])
	_carrier.rig.request_keyboard(false)
	if not paper.copy_delivered():return
	_contact_age+=maxf(0,delta)
	var emotion:String=expressions[_contact_index]
	if state.phase=="identity_mystery" and _contact_index==0 and _contact_age>=2.0:
		emotion="thoughtful"
		if _contact_emotion!=emotion:_contact_face(emotion)
		if _carrier.rig.display.settled():_contact_thinking_age+=maxf(0,delta)
	var tilt:=Vector3(0,0,.07) if emotion=="sympathetic" else Vector3(-.025,0,-.025) if emotion=="thoughtful" else Vector3.ZERO
	var bounce:=sin(clampf(_contact_age,0,1)*PI)*-.006 if emotion=="grinning" else 0.0
	_carrier.set_story_pose(self,tilt,Vector2(0,bounce),.96 if state.phase=="identity_mystery" else 1.0)
	# Reading holds begin after real print completion, not a guessed print timer.
	var hold:=4.0 if _contact_index==0 else 6.0
	if state.phase=="identity_mystery":hold=4.0 if _contact_index==0 else 5.0
	if _contact_age<hold:return
	if state.phase=="identity_mystery" and _contact_index==0 and _contact_thinking_age<2.0:return
	if state.phase=="first_contact" and _contact_index==1:
		if _observe("murder_presented"):_advance("identity_mystery")
	elif state.phase=="identity_mystery" and _contact_index==1:
		if _observe("identity_question_presented"):_contact_index+=1;_contact_serial=-1;_contact_age=0
	elif state.phase=="identity_mystery" and _contact_index==2:_advance("temporal_command")
	else:_contact_index+=1;_contact_serial=-1;_contact_age=0

func _begin_visitor() -> bool:
	if not is_instance_valid(_carrier) or not _carrier.begin_story_reflection(self):return _fail("reflection presentation lease refused")
	_visitor_active=true;_visitor_dwell=0;_visitor_return_dwell=0
	var normal:=mirror.mirror_normal()
	_visitor_basis=Basis.looking_at(normal,Vector3.UP)
	# Choose an interior point of the actual mirror window, then place the
	# bot on its reflected ray at a fixed behind-player distance. This accounts
	# for an off-centre player without following their subsequent gaze.
	var center:=mirror.mirror_center()
	var reflected:Vector3=world.mirror_renderer._reflect_point(player.camera.global_position,center,normal)
	var pane:MeshInstance3D=mirror.mirror_surface()
	var opening:=center+pane.global_basis.x.normalized()*.11+pane.global_basis.y.normalized()*.06
	var ray:=opening-reflected
	var depth:float=(player.camera.global_position-center).dot(normal)+.40
	_visitor_anchor=reflected+ray*((depth-(reflected-center).dot(normal))/ray.dot(normal))
	_pose_visitor()
	return true

func _pose_visitor() -> void:
	# The same manufactured bot is placed behind the player in reflected rays.
	# Its normal compositor and query areas remain disabled by the absence lease.
	var effort:=maxf(0,_phase_age-2.0)
	_visitor_center=_visitor_anchor+_visitor_basis.x*sin(effort*.85)*.025+Vector3.UP*sin(effort*1.13)*.014
	var basis:=_visitor_basis*Basis(Vector3.FORWARD,sin(effort*.85)*.055)
	var offset:Vector3=basis*(_carrier.screen_frame.stock_bounds.get_center()*_carrier.PRESENTATION_SCALE)
	_carrier.pose_story_reflection(self,Transform3D(basis,_visitor_center-offset),world.mirror_renderer.active_mirror()==mirror and player.camera.is_current())

func _visitor_observed() -> bool:
	if not _visitor_active or not _mirror_observed() or not _carrier.rig.is_visible_in_tree():return false
	var camera:Camera3D=world.mirror_renderer.active_camera()
	if camera==null or not camera.is_position_in_frustum(_visitor_center):return false
	var direction:=(_visitor_center-camera.global_position).normalized()
	var point:Variant=Plane(mirror.mirror_normal(),mirror.mirror_center()).intersects_ray(camera.global_position,direction)
	if point is not Vector3:return false
	# Start outside the pane's real solid leaf; retained room obstructions still
	# block the observation. The player's generous capsule is not their drawing.
	var ray:=PhysicsRayQueryParameters3D.create(point+direction*.03,_visitor_center,1,[player.get_rid()])
	return world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _observe_visitor(elapsed:float) -> void:
	if _phase_age>=2:_tap_mirror(2.0)
	if _visitor_observed():
		_visitor_dwell+=elapsed
		if _visitor_dwell>=.8 and not _observe("visitor_seen"):return
		if "looked_behind" in state.events:
			_visitor_return_dwell+=elapsed
			if _visitor_return_dwell>=.8 and not _observe("visitor_seen_again"):return
	else:
		_visitor_return_dwell=0
		var toward:=(_visitor_center-player.camera.global_position).normalized()
		if "visitor_seen" in state.events and (-player.camera.global_basis.z).dot(toward)>.55:
			if not _observe("looked_behind"):return
	# Time alone cannot fabricate seeing the visitor or investigating its absence.
	# Leave room for repeated experiments after returning to the mirror.
	if _phase_age>=18 and _visitor_dwell>=6 and _visitor_return_dwell>=5 and "visitor_seen_again" in state.events:
		_advance("companion_crossing")

func _end_visitor() -> void:
	if is_instance_valid(_carrier):_carrier.end_story_reflection(self)
	_visitor_active=false

func _set_mirror_film(value:Vector2) -> void:
	if not is_instance_valid(mirror):return
	var pane:=mirror.mirror_surface()
	world.bathroom_moisture.set_mirror_story(pane,value)
	world.mirror_renderer.set_mirror_story(pane,value)

func _mirror_observed() -> bool:
	if not is_instance_valid(mirror) or not player.camera.is_current() or world.mirror_renderer.active_mirror()!=mirror or not world.player_avatar.reflected:return false
	var camera:Camera3D=player.camera
	var toward:=mirror.mirror_center()-camera.global_position
	if toward.length()>2.5 or (-camera.global_basis.z).dot(toward.normalized())<.72:return false
	var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,mirror.mirror_center(),1,[player.get_rid()])
	var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or mirror.is_ancestor_of(hit.collider)

func _tap_mirror(offset:=0.0) -> void:
	var next:=offset+float(_knock_index/3)*5.0+float(_knock_index%3)*.28
	if _phase_age<next:return
	_knock_index+=1
	if not is_instance_valid(_knock):
		_knock=AudioStreamPlayer3D.new();_knock.name="InsideMirrorTap"
		_knock.stream=preload("res://assets/audio/freesound/processed/mechanical/pipe_knock.ogg")
		_knock.volume_db=-25;_knock.max_distance=6;_knock.unit_size=.5;add_child(_knock)
	_knock.global_position=mirror.mirror_center()-mirror.mirror_normal()*.03
	_knock.play()

func _cabinet_released(before:float,after:float) -> void:
	if not _running or get_tree().paused or player.call_locked or RealityState.save_write_blocked or not is_same(_document,RealityState.data):return
	if state.phase!="cabinet_inspection":return
	if after>=.55 and after>before+.02 and "cabinet_opened" not in state.events:
		if _observe("cabinet_opened"):_phase_age=0;_knock_index=0;writing.clear()
	elif after<=.025 and after<before-.02 and "cabinet_opened" in state.events:
		if _observe("cabinet_closed"):_advance("reflection_visitor")


func shutdown() -> void:
	# cancel emits finished synchronously; its callback can clear `waking`.
	var old_waking:Node=waking
	waking=null
	if is_instance_valid(old_waking):old_waking.cancel();old_waking.queue_free()
	_release_contact()
	if is_instance_valid(mirror_crossing):mirror_crossing.cancel();mirror_crossing.queue_free()
	mirror_crossing=null
	_end_visitor()
	_running=false;set_process(false)
	if is_instance_valid(_knock):_knock.stop();_knock.queue_free()
	_knock=null
	if is_instance_valid(mirror):
		_set_mirror_film(Vector2(-1,0))
		if mirror.manipulation_released.is_connected(_cabinet_released):mirror.manipulation_released.disconnect(_cabinet_released)
	if _avatar_leased and is_instance_valid(world) and is_instance_valid(world.player_avatar):world.player_avatar.visible=_avatar_visible
	_avatar_leased=false
	if is_instance_valid(temporal_sky):temporal_sky.cancel();temporal_sky.queue_free()
	temporal_sky=null
	if is_instance_valid(temporal_console):
		if temporal_console.accepted.is_connected(_temporal_accepted):temporal_console.accepted.disconnect(_temporal_accepted)
		if temporal_console.finished.is_connected(_temporal_finished):temporal_console.finished.disconnect(_temporal_finished)
		temporal_console.cancel();temporal_console.queue_free()
	temporal_console=null
	if is_instance_valid(_carrier): _carrier.release_story_absence(self)
	_carrier=null
	if is_instance_valid(shower) and shower.manipulation_changed.is_connected(_released): shower.manipulation_changed.disconnect(_released)
	if is_instance_valid(shower) and shower.flow_changed.is_connected(_flow_changed): shower.flow_changed.disconnect(_flow_changed)
	for treatment: Node in _window_controls:
		if is_instance_valid(treatment) and treatment.control_released.is_connected(_window_released): treatment.control_released.disconnect(_window_released)
	_window_controls.clear()
	if RealityState.state_changed.is_connected(_restore): RealityState.state_changed.disconnect(_restore)
	if is_instance_valid(writing): writing.clear();writing.queue_free()
	writing=null
	_document={}

func _exit_tree() -> void:
	shutdown()

func _fail(message: String) -> bool:
	errors.append(message);_running=false;set_process(false)
	push_error("Prologue: "+message)
	return false
