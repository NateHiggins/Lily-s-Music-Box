extends Node
## Current working slice: waking surface guidance through shower shutoff.
## Not installed into normal entry until the complete opening is qualified.
signal phase_changed(phase: String)
signal transcription_changed(text: String)
const State := preload("res://scripts/game/prologue_state.gd")
const Writing := preload("res://scripts/game/signal_surface_writing.gd")
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

func _ready() -> void:
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
	for id in ["wake_passed","wake_shower","curtain_open","wrong_curtain","cold_start","hot_start","more_hot","less_hot","comfort","hot_off","water_off"]:
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

func begin_waking_preview() -> bool:
	# Explicit incomplete-slice preview only; it does not claim DREAM was played.
	if world==null or not errors.is_empty() or state.phase not in ["dream","awakening","bedroom_exploration"]: return false
	while state.phase!="bedroom_exploration":
		var next: String=State.PHASES[State.PHASES.find(state.phase)+1]
		if not _store(State.advance(state,next)): return false
	_carrier=world.service_set_carrier
	if _carrier==null or not _carrier.acquire_story_absence(self): return _fail("companion absence lease refused")
	_running=true;set_process(true);_enter_phase()
	return true

func _restore() -> void:
	if _publishing: return
	var replaced := not is_same(_document,RealityState.data)
	var restored := State.restore(RealityState.data.get("prologue",{}))
	if restored.is_empty(): _fail("invalid prologue state");return
	_document=RealityState.data
	if replaced: _last_moved_valve=-1
	if restored==state: return
	var changed: bool=state.get("phase","")!=restored.phase
	state=restored
	if changed and _running: _enter_phase()

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
	_phase_age=0;_comfortable=0;message_id=""
	match state.phase:
		"bedroom_exploration": _say("wake_passed",false)
		"bathroom_entry": _advance("curtain_interaction");return
		"curtain_interaction": _say("cold_start" if "curtain_pulled" in state.events else "curtain_open",true)
		"shower_temperature": _say("hot_start",true)
		"shower_complete": _say("comfort",true)
		"mirror_tapping": _say("hot_off",true)
		"mirror_condensation":
			writing.clear();_running=false;set_process(false)
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
	_poll+=maxf(delta,0.0)
	if _poll<PERIOD: return
	var elapsed := _poll;_poll=0
	if not _running or player.call_locked or player.mouse_released or RealityState.save_write_blocked: return
	if not is_same(_document,RealityState.data): return
	_phase_age+=elapsed
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

func shutdown() -> void:
	_running=false;set_process(false)
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
