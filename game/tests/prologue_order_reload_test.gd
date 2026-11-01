extends "res://tests/prologue_tutorial_route.gd"
## Fixture order a first-time player may choose, and validated save/load at each
## tutorial boundary through the cabinet. Saved facts are built by the reducer;
## every gesture after a load uses the actual player ray and grab.
const State := preload("res://scripts/game/prologue_state.gd")
const STAND := Vector3(-8.45,9.6,4.35)
var old_path:String

func _init() -> void:
	route_label="V2 PROLOGUE ORDER AND RELOAD"

func _route() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	director=Director.new();world.add_child(director)
	if not _require(director.configure(world),"actual 4B fixture and wall supports bound: "+str(director.errors)):return
	if not _require(director.begin_waking_preview(),"tutorial presentation claims its owners"):return
	old_path=RealityState.save_path
	RealityState.save_path=OS.get_environment("SHOT_DIR").path_join("order_reload.json");RealityState.persistence_enabled=true
	player.global_position=world.adapter.root.to_global(STAND);player.velocity=Vector3.ZERO
	await get_tree().physics_frame
	await _bedroom_save_inside_bath()
	await _cold_before_curtain()
	await _hot_before_cold()
	await _temperature_reload()
	await _early_shutoff_and_tapping()
	await _shutoff_reload()
	await _mirror_and_cabinet_reloads()
	RealityState.persistence_enabled=false;RealityState.save_path=old_path
	_require(director.errors.is_empty(),"no director failure across the matrix: "+str(director.errors))

func _state_at(phase:String,extra:Array=[]) -> Dictionary:
	var built:=State.initial()
	for at:String in State.PHASES:
		if at==phase:break
		for event:String in State.GATES.get(at,[]):built=State.observe(built,event)
		built=State.advance(built,State.PHASES[State.PHASES.find(at)+1])
	for event:String in extra:built=State.observe(built,event)
	return built

func _fixture(curtain:bool,hot:float,cold:float) -> void:
	var shower:TapProp=director.shower
	shower.set_curtain_open(curtain)
	shower.set_valve_opening(0,hot);shower.set_valve_opening(1,cold)

## Saves these facts and this mechanism, disturbs the live mechanism, loads.
func _reload_at(phase:String,extra:Array,curtain:bool,hot:float,cold:float,label:String) -> bool:
	_fixture(curtain,hot,cold)
	RealityState.data.prologue=_state_at(phase,extra)
	if not _require(RealityState.save_game(),"validated save at "+label):return false
	_fixture(not curtain,1.0-hot,1.0-cold)
	var mechanism_was:=[curtain,hot,cold]
	RealityState.load_game()
	await get_tree().process_frame;await get_tree().process_frame
	var flow:Dictionary=director.shower.get_flow_state()
	_require(is_equal_approx(float(flow.hot_opening),mechanism_was[1]) and is_equal_approx(float(flow.cold_opening),mechanism_was[2]) and director.shower.is_curtain_open()==mechanism_was[0],
		"load restores curtain and both valves at "+label+": "+str([director.shower.is_curtain_open(),flow.hot_opening,flow.cold_opening]))
	return _require(director.state.phase==phase or phase=="bedroom_exploration","load keeps saved phase at "+label+": "+str(director.state.phase))

func _valve(index:int,goal:float,label:String) -> bool:
	return await _drag_part(director.shower,director.shower._handles[index].global_position,goal,label)

func _curtain(label:String) -> bool:
	return await _drag_part(director.shower,director.shower.to_global(Vector3(0,1.18,-.32)),1.78,label)

func _bedroom_save_inside_bath() -> void:
	if not await _reload_at("bedroom_exploration",[],false,0.0,0.0,"bedroom"):return
	await get_tree().create_timer(.5).timeout
	_require(director.state.phase=="curtain_interaction" and director.message_id=="curtain_open","a save in the bedroom phase taken inside the bath continues to the curtain")

func _cold_before_curtain() -> void:
	# The closed curtain stands between the player and the valves: aiming at the
	# handle takes the curtain, so the fixture itself enforces this order.
	if not await _reload_at("curtain_interaction",[],false,0.0,0.0,"curtain"):return
	_require(director.message_id=="curtain_open","reload shows the curtain instruction")
	player.camera.look_at(director.shower._handles[1].global_position)
	await get_tree().physics_frame
	player.camera.look_at(director.shower._handles[1].global_position)
	var grip:Dictionary=player._grab.find_target()
	_require(grip.get("owner")==director.shower and str(grip.part.name).begins_with("CurtainHand"),"closed curtain is what the player reaches, not the valve")
	# Water can still already be running: a partly drawn curtain, or an older save.
	if not await _reload_at("curtain_interaction",[],false,0.0,1.0,"curtain with cold running"):return
	_require(director.state.phase=="curtain_interaction" and "curtain_pulled" not in director.state.events,"water alone does not satisfy the curtain")
	if not await _curtain("curtain_after_cold"):return
	_require(director.state.phase=="shower_temperature" and "cold_water_started" in director.state.events,"curtain after cold reaches the temperature step without moving cold again")

func _hot_before_cold() -> void:
	if not await _reload_at("curtain_interaction",["curtain_pulled"],true,0.0,0.0,"curtain pulled"):return
	_require(director.message_id=="cold_start","reload after the curtain asks for cold")
	if not await _valve(0,PI*.5,"hot_first"):return
	_require(director.state.phase=="curtain_interaction","hot alone does not satisfy the cold step")
	if not await _valve(1,PI*.5,"cold_after_hot"):return
	_require(director.state.phase=="shower_temperature" and director.message_id!="hot_start","cold after hot skips the false too-cold line")
	await get_tree().create_timer(2.2).timeout
	_require(director.state.phase=="shower_complete","hot opened early counts once the mix is comfortable: "+str(director.state.phase))

func _temperature_reload() -> void:
	if not await _reload_at("shower_temperature",[],true,0.0,1.0,"temperature"):return
	_require(director.message_id=="hot_start","reload with cold running asks for hot")
	await get_tree().create_timer(1.0).timeout
	_require("hot_water_adjusted" not in director.state.events and director.state.phase=="shower_temperature","reload invents no temperature fact")
	if not await _valve(0,PI*.5,"hot_after_reload"):return
	await get_tree().create_timer(2.2).timeout
	_require(director.state.phase=="shower_complete","temperature step completes after reload")

func _early_shutoff_and_tapping() -> void:
	if not await _reload_at("shower_complete",[],true,1.0,1.0,"peace"):return
	player.face_world_point(player.camera.global_position+Vector3(.4,3,.4))
	if not await _valve(0,0.0,"early_hot_off"):return
	if not await _valve(1,0.0,"early_cold_off"):return
	player.face_world_point(player.camera.global_position+Vector3(.4,3,.4))
	await get_tree().create_timer(8.0).timeout
	_require(director.state.phase=="mirror_condensation" and "shower_stopped" in director.state.events,"water shut off early does not strand the shutoff step: "+str(director.state.phase))
	_require(not director._withdrawal_seen and director._phase_age<=1.5,"the reveal still waits for the mirror")
	var first:int=director._knock_index
	await get_tree().create_timer(5.5).timeout
	_require(first>=1 and director._knock_index>first,"tapping keeps calling until the mirror is seen: "+str([first,director._knock_index]))

func _shutoff_reload() -> void:
	if not await _reload_at("mirror_tapping",[],true,1.0,1.0,"shutoff both"):return
	_require(director.message_id=="hot_off","reload with both running asks for hot off")
	if not await _valve(0,0.0,"hot_off_after_reload"):return
	_require(director.message_id=="water_off" and director.state.phase=="mirror_tapping","cold still running asks for the water")
	if not await _reload_at("mirror_tapping",[],true,0.0,1.0,"shutoff cold only"):return
	_require(director.message_id=="water_off","reload with only cold running does not ask for hot off")
	if not await _valve(1,0.0,"cold_off_after_reload"):return
	_require(director.state.phase=="mirror_condensation","shutoff completes after reload")

func _mirror_and_cabinet_reloads() -> void:
	var cabinet:MedicineCabinetProp=director.mirror
	var pane:=cabinet.mirror_surface()
	if await _reload_at("mirror_condensation",[],true,0.0,0.0,"condensation"):
		_require(director._phase_age<.5 and pane.get_meta("prologue_mirror_film")==Vector2(1,0) and not director._withdrawal_seen,"condensation restarts opaque and unobserved")
	if await _reload_at("protagonist_reveal",[],true,0.0,0.0,"reveal"):
		_require(pane.get_meta("prologue_mirror_film")==Vector2(1,1) and director._reflection_dwell==0.0 and "reflection_observed" not in director.state.events,"reveal restores a clear mirror and invents no witness")
	if await _reload_at("cabinet_inspection",[],true,0.0,0.0,"cabinet closed"):
		_require(director.message_id=="cabinet_open" and not cabinet.is_door_open(),"unopened cabinet asks to be opened")
	cabinet.restore_travel(1)
	await get_tree().physics_frame
	if await _reload_at("cabinet_inspection",["cabinet_opened"],true,0.0,0.0,"cabinet opened"):
		_require(director.message_id=="" and cabinet.is_door_open(),"opened cabinet stays open and silent: "+str([director.message_id,cabinet.is_door_open()]))
	cabinet.restore_travel(0)
