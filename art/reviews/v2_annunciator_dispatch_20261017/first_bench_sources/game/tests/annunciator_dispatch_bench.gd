extends "res://tests/annunciator_hand_bench.gd"
## Actual player hand and production lift owner; room/NPC route is separate.
class DeniedInterlock:
	extends Node
	func permits_car_start() -> bool:return false

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.13,.15,.17)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color(.75,.82,.90);environment.environment.ambient_light_energy=.4;add_child(environment)
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-25,0);light.light_energy=1.4;light.shadow_enabled=true;add_child(light)
	board=OtisProp.new();board.name="LobbyPorterBoard";board.prop_type="otis";board.position.y=1.4;add_child(board)
	check(board.find_children("*","MeshInstance3D",true,false).size()==28,"original board still has its 28 source owners")
	preload("res://scripts/building/v2_legacy_material_stock.gd").apply(self)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/service_instruments.json"))
	data.actors=data.actors.filter(func(row):return row.id=="LobbyPorterBoard")
	data.source_materials=data.source_materials.filter(func(row):return row.actor=="LobbyPorterBoard")
	data.work_lights=[];data.dumbwaiter_ropes=[]
	var subset := "user://annunciator_dispatch_subset.json"
	FileAccess.open(subset,FileAccess.WRITE).store_string(JSON.stringify(data))
	var factory := preload("res://scripts/building/orison_v2_native_service_instruments.gd").new()
	check(factory.mount(self,subset),"native source preflight and service/dispatch stocks mount")
	if board._native_dispatch==null:_done();return
	var controls: Node3D=board._native_dispatch
	var lift := OrisonElevator.new();add_child(lift)
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json"))
	var served: Dictionary={"B1":true}
	for row: Dictionary in layout.lift_landings:
		if row.shaft=="PASSENGER_LIFT_SHAFT":served[row.level]=true
	var stops: Dictionary={}
	for row: Dictionary in layout.levels:
		if served.has(row.id):stops[row.id]=float(row.y)
	lift.setup({"shaft":[4,4,6,6],"cabin":[1.55,2.2],"stops":stops,"door_w":.91})
	check(board.mechanism_snapshot().version==2,"dispatch geometry exists before late lift binding/save restoration")
	check(board.bind_native_lift(lift) and controls.buttons.size()==7 and not controls.levels.has("ROOF"),"keys bind only the seven real passenger stops")
	var uv := preload("res://scripts/building/orison_v2_uv_material_policy.gd").new();add_child(uv);uv.setup(self)
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var seen: Dictionary={}
	for draw: MeshInstance3D in controls.find_children("*","MeshInstance3D",true,false):
		if not seen.has(draw.mesh.get_instance_id()):metrics._check_cap_mapping(draw.mesh,true);seen[draw.mesh.get_instance_id()]=true
	for failure: String in metrics.failures:check(false,failure)
	metrics.free()
	player=PlayerController.new();add_child(player);player.set_physics_process(false)
	player.global_position=Vector3(0,0,.8);player.call_locked=false;player.mouse_released=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	driver=preload("res://tests/radiator_cutover_review.gd").new()
	gestures=preload("res://tests/annunciator_input_driver.gd").new(self,board,player,driver,check)
	var destination: int=controls.levels.find("F02")
	var key: Node3D=controls.buttons[destination]
	await _move(key,float(controls.data.travel)*.5)
	await get_tree().create_timer(.3).timeout
	check(lift.state==OrisonElevator.S.IDLE and lift.current=="F01" and controls.strokes[destination]==0.,"partial stroke returns without calling car")
	await _move(key,float(controls.data.travel));await get_tree().create_timer(.3).timeout
	check(lift.state==OrisonElevator.S.IDLE and board.stuck_flag,"broken board circuit refuses a trip without repairing itself")
	await _move(board._flag_arms[0],board._native_service.FLAG_HIGH);await get_tree().create_timer(.5).timeout
	await _move(board._contact_bridge,0.);await _move(board._reset_spindle,PI*.5);await get_tree().create_timer(.85).timeout
	check(not board.stuck_flag and board.bank_reset==1.,"actual service controls restore circuit before dispatch")
	await _aim(key);driver._click(player);driver._drag_to(player,float(controls.data.travel))
	check(player._grab.active() and lift.moving and lift._pending=="F02","full physical key travel requests the real car")
	var pressed: Dictionary=JSON.parse_string(JSON.stringify(board.mechanism_snapshot()))
	check(board.valid_mechanism(pressed),"pressed/spent key survives JSON round trip")
	var bad: Dictionary=pressed.duplicate(true);bad.dispatch.spent[destination]=false
	check(not board.valid_mechanism(bad),"a fully pressed key cannot restore as an unspent request")
	await _arrive(lift,"F02")
	controls.drive_indicators()
	var lit := 0
	for material: StandardMaterial3D in board._lamps:
		if material.emission_enabled:lit+=1
	check(lit==1 and board._lamps[board._lamps.size()-1-destination].emission_enabled,"board lamp follows actual car position")
	# Explicit door-position fixture detects an illicit repeated held request.
	lift._set_door_t("F02",0.)
	await get_tree().create_timer(.2).timeout
	check(lift._doors.F02.t==0. and lift.state==OrisonElevator.S.IDLE,"held key does not replay after arrival")
	driver._click(player);await get_tree().create_timer(.3).timeout
	check(controls.strokes[destination]==0. and not controls.spent[destination],"physical spring return rearms key")
	check(lift.npc_request("F01"),"existing lift owner accepts independent return fixture")
	await _arrive(lift,"F01")
	board.restore_mechanism(pressed);await get_tree().create_timer(.4).timeout
	check(lift.current=="F01" and not lift.moving and controls.strokes[destination]==0.,"restore returns a saved pressed key without replaying its trip")
	var block := DeniedInterlock.new();add_child(block)
	check(lift.register_landing_interlock("F01",block),"lift owns its interlock contract")
	await _move(key,float(controls.data.travel));await get_tree().create_timer(.3).timeout
	check(lift.current=="F01" and not lift.moving,"physical dispatch cannot bypass landing interlock")
	lift._interlocks.erase("F01");block.free()
	var old: Dictionary=board._native_service.snapshot()
	check(board.valid_mechanism(old),"legacy service snapshot remains accepted")
	board.restore_mechanism(old)
	check(controls.snapshot()==controls.rest_snapshot(),"legacy restoration clears only transient dispatch travel")
	player.camera.global_position=board.to_global(Vector3(.22,-.02,.70));player.camera.look_at(board.to_global(Vector3(0,-.04,.05)))
	await _shot("dispatch_board")
	player.camera.global_position=board.to_global(Vector3(.10,-.30,.28));player.camera.look_at(board.to_global(Vector3(0,-.344,.06)))
	await _shot("dispatch_keys")
	check(board._panel==null and board._service_panel==null,"no overlay or private lift simulation is opened")
	driver.free();lift.free();board.free();_done()

func _arrive(lift: OrisonElevator,level: String) -> void:
	var deadline := Time.get_ticks_msec()+15000
	while (lift.moving or lift.current!=level) and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	check(not lift.moving and lift.current==level and lift.state==OrisonElevator.S.IDLE,"actual doors and car arrive at "+level)

func _done() -> void:
	FileAccess.open(out.path_join("dispatch_bench.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"scope":"Real cursor/grab/motion/release, native keys, actual lift travel and interface interlock, in-memory board restore. Not resident route or disk/world reconstruction."},"\t"))
	print("ANNUNCIATOR DISPATCH BENCH: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",failures)
	terminal=true;get_tree().quit(0 if failures.is_empty() else 1)
