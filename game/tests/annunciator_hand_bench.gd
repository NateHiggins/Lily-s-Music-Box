extends Node3D
## Original native board + physical service, actual production player/input.
## This related-owner bench does not prove the whole building service route.
var failures: Array[String]=[]
var checks := 0
var terminal := false
var player: PlayerController
var board: OtisProp
var driver: Node3D
var gestures: RefCounted
var out := ""
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func _ready() -> void:
	get_tree().create_timer(40).timeout.connect(func():
		if not terminal:push_error("Annunciator hand bench incomplete");get_tree().quit(1))
	_run.call_deferred()

func _aim(part: Node3D) -> void:
	await gestures.focus(part)

func _move(part: Node3D,goal: float) -> void:
	await gestures.move(part,goal)

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))==OK,"capture "+label)

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.13,.15,.17)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.75,.82,.90);environment.environment.ambient_light_energy=.4
	add_child(environment)
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-25,0);light.light_energy=1.4;light.shadow_enabled=true;add_child(light)
	board=OtisProp.new();board.name="LobbyPorterBoard";board.prop_type="otis";board.position.y=1.4;add_child(board)
	check(board.find_children("*","MeshInstance3D",true,false).size()==28,"source's original 28 visual owners remain before native mount")
	preload("res://scripts/building/v2_legacy_material_stock.gd").apply(self)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/service_instruments.json"))
	data.actors=data.actors.filter(func(row):return row.id=="LobbyPorterBoard")
	data.source_materials=data.source_materials.filter(func(row):return row.actor=="LobbyPorterBoard")
	data.work_lights=[];data.dumbwaiter_ropes=[]
	var subset := "user://annunciator_native_bench_subset.json"
	FileAccess.open(subset,FileAccess.WRITE).store_string(JSON.stringify(data))
	var factory := preload("res://scripts/building/orison_v2_native_service_instruments.gd").new()
	check(factory.mount(self,subset),"canonical native factory mounts related board and real controls")
	if board._native_service==null:terminal=true;get_tree().quit(1);return
	for retained: Dictionary in factory.installed.LobbyPorterBoard.source:
		var draw: MeshInstance3D=retained.draw.get_ref()
		check(draw!=null and draw.get_parent().get_instance_id()==retained.parent,"original visual owner and parent survive detail replacement")
		if draw!=null and retained.preserve_material:
			check(draw.get_active_material(0)==retained.material,"original live instrument material reference survives detail replacement")
	for i in board._lamps.size():
		var lens: MeshInstance3D=factory.installed.LobbyPorterBoard.source[2+i*3].draw.get_ref()
		check(lens.get_active_material(0)==board._lamps[i] and lens.has_node("LampBezel"),"original lamp material drives its curved lens and seated bezel")
	var first_bezel: MeshInstance3D=factory.installed.LobbyPorterBoard.source[2].draw.get_ref().get_node("LampBezel")
	var last_bezel: MeshInstance3D=factory.installed.LobbyPorterBoard.source[23].draw.get_ref().get_node("LampBezel")
	check(first_bezel.mesh==last_bezel.mesh and first_bezel.material_override==last_bezel.material_override and first_bezel.material_override!=MatLib.get_mat("radiator_service_brass"),"eight bezels share native geometry and private fixed-stock material without mutating the catalogue")
	var uv := preload("res://scripts/building/orison_v2_uv_material_policy.gd").new();add_child(uv);uv.setup(self)
	player=PlayerController.new();add_child(player);player.set_physics_process(false)
	player.global_position=Vector3(0,0,.8);player.call_locked=false;player.mouse_released=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	driver=preload("res://tests/radiator_cutover_review.gd").new()
	gestures=preload("res://tests/annunciator_input_driver.gd").new(self,board,player,driver,check)
	var events: Array=[];board.maintenance_completed.connect(func(result: Dictionary):events.append(result.duplicate(true)))
	var orders := WorkOrders.new();orders.name="WorkOrders";add_child(orders)
	orders.setup(null);orders.bind_job_library(MaintenanceJobLibrary.load_default())
	orders.issue_job(ServiceRoundDirector.JOB_ID,"reported");orders.acknowledge_job(ServiceRoundDirector.JOB_ID)
	# Explicit route-start fixture: this bench tests the board's comparison,
	# not walking upstairs and collecting the earlier radiator observation.
	orders.record_job_evidence(ServiceRoundDirector.JOB_ID,"radiator_airbound")
	var round := ServiceRoundDirector.new();add_child(round);round.work_orders=orders
	board.maintenance_completed.connect(round._on_board_completed)
	var codec := preload("res://scripts/building/orison_v2_household_state.gd").new();add_child(codec)
	codec._subjects={"LobbyPorterBoard":board};codec._kinds={"LobbyPorterBoard":"mechanism"};codec._defaults=codec.snapshot()
	check(not board.interact_control("service",player) and board._service_panel==null,"native board cannot launch old service panel")
	check(not board.interact_control("dispatch",player) and board._panel==null,"unconverted dispatch does not launch old minigame in V2")
	var first: Node3D=board._flag_arms[0]
	await _aim(first);driver._click(player)
	check(player._grab.active() and board._native_service.held==first,"actual sticky flag can be grabbed")
	var initial: float=first.rotation.x
	driver._drag_to(player,-.1)
	check(absf(first.rotation.x-initial)<.00001 and board.stuck_flag,"sticking bearing resists the wrong direction")
	driver._drag_to(player,board._native_service.FLAG_HIGH)
	check(not board.stuck_flag,"real full lift frees the flag bearing")
	driver._click(player);await get_tree().create_timer(.5).timeout
	check(absf(first.rotation.x)<.00001 and events.is_empty(),"freed flag returns physically without awarding contact proof")
	await _move(board._flag_arms[7],board._native_service.FLAG_HIGH)
	await get_tree().create_timer(.5).timeout
	check(absf(board._flag_arms[7].rotation.x)<.00001 and events.is_empty(),"another flag and its real axle return without inventing a test")
	await _move(board._contact_bridge,.11)
	var saved: Dictionary=JSON.parse_string(JSON.stringify(board.mechanism_snapshot()))
	check(board.valid_mechanism(saved),"partial-contact JSON snapshot validates")
	var household: Dictionary=JSON.parse_string(JSON.stringify(codec.snapshot()))
	check(codec.validate(household,codec._kinds),"new board state passes existing household codec")
	await _move(board._contact_bridge,0.0)
	codec._restore(household)
	check(absf(board._contact_bridge.rotation.z-.11)<.00001,"restore reconstructs changed contact geometry")
	for key: String in ["version","contact","reset"]:
		var bad := saved.duplicate(true);bad[key]=true
		check(not board.valid_mechanism(bad),"reject boolean "+key)
	await _move(board._contact_bridge,0.0)
	check(absf(board.contact_alignment-.63)<.00001 and events.is_empty(),"actual silver alignment alone cannot counterfeit a tested bank")
	await _move(board._reset_spindle,.6)
	await get_tree().create_timer(.4).timeout
	check(events.is_empty() and board.bank_reset==0.0,"partial reset returns without completing service")
	await _aim(board._reset_spindle);driver._click(player)
	var space := InputEventKey.new();space.keycode=KEY_SPACE;space.physical_keycode=KEY_SPACE;space.pressed=true
	player._unhandled_input(space)
	check(player.inspecting(),"Space reaches physical annunciator service")
	var camera := player.camera.global_transform
	if player.inspecting():
		Input.warp_mouse(player.camera.unproject_position(board._reset_spindle.to_global(Vector3(.010,.035,0))))
		await get_tree().physics_frame
		driver._click(player)
		check(player._grab.active(),"inspection pointer grabs reset part")
		driver._drag_to(player,.4)
		check(camera.is_equal_approx(player.camera.global_transform),"inspection camera remains static during actual reset motion")
		driver._click(player)
	player.end_inspection()
	await _move(board._reset_spindle,PI*.5)
	await get_tree().create_timer(.85).timeout
	check(board.bank_reset==1.0 and absf(board._native_service.reset_travel)<.00001,"full physical reset returns its real spindle")
	check(events.size()==1 and events[0].get("mechanism_patch",{}).get("stuck_flag",true)==false,"actual contact and reset publish original service outcome once")
	check("lobby_contact_compared" in orders.job_state(ServiceRoundDirector.JOB_ID).get("evidence",[]) and orders.job_stage(ServiceRoundDirector.JOB_ID)=="acknowledged","physical board reports through original comparison owner without bypassing boiler diagnosis")
	await get_tree().create_timer(.2).timeout
	check(events.size()==1,"settled mechanism does not repeat completion")
	await _aim(board._reset_spindle);driver._click(player);driver._drag_to(player,PI*.5)
	var armed: Dictionary=JSON.parse_string(JSON.stringify(board.mechanism_snapshot()))
	print("ANNUNCIATOR ARMED ROUNDTRIP ",armed," pi/2 difference ",float(armed.reset)-PI*.5)
	check(armed.armed and board.valid_mechanism(armed),"full reset arms a durable mechanical test latch")
	board.restore_mechanism(armed);player._grab.validate()
	await get_tree().create_timer(.85).timeout
	check(events.size()==2 and not board.mechanism_snapshot().armed,"restored spring cycle finishes its original test once")
	board.restore_mechanism(JSON.parse_string(JSON.stringify(board.mechanism_snapshot())))
	await get_tree().create_timer(.15).timeout
	check(events.size()==2,"completed-state restoration does not replay the service outcome")
	player.camera.global_position=board.to_global(Vector3(.22,.08,.65));player.camera.look_at(board.to_global(Vector3(0,0,.04)))
	await _shot("annunciator_serviced")
	await _aim(board._contact_bridge);await _shot("annunciator_contacts")
	player.set_lamp_enabled(false)
	await get_tree().create_timer(.7).timeout
	check(not player.lamp_is_enabled() and not player.flashlight.visible,"controlled-light captures use the actual settled lamp-off state")
	var initial_lamp := -1
	for i in board._lamps.size():
		if board._lamps[i].emission_enabled:initial_lamp=i
	var lamp_deadline := Time.get_ticks_msec()+3000
	while initial_lamp>=0 and board._lamps[initial_lamp].emission_enabled and Time.get_ticks_msec()<lamp_deadline:
		await get_tree().create_timer(.05).timeout
	var active_lamps := 0
	var lit_index := -1
	for i in board._lamps.size():
		if board._lamps[i].emission_enabled:active_lamps+=1;lit_index=i
	check(initial_lamp>=0 and not board._lamps[initial_lamp].emission_enabled and active_lamps==1,"existing car-indicator cadence advances with one real emissive lens")
	if lit_index>=0:
		var lens: MeshInstance3D=factory.installed.LobbyPorterBoard.source[2+lit_index*3].draw.get_ref()
		player.camera.global_position=lens.global_position+Vector3(.065,.035,.17);player.camera.look_at(lens.global_position)
		await _shot("annunciator_lamp_detail")
	player.camera.global_position=board.to_global(Vector3(.12,.08,.60));player.camera.look_at(board.to_global(Vector3(0,0,.04)))
	await _shot("annunciator_diffuse")
	player.camera.global_position=board.to_global(Vector3(.14,.17,.19));player.camera.look_at(board._flag_arms[1].global_position)
	await _shot("annunciator_flag_detail")
	light.rotation_degrees=Vector3(-12,-75,0)
	player.camera.global_position=board.to_global(Vector3(.12,-.24,.23));player.camera.look_at(board._reset_spindle.global_position)
	await _shot("annunciator_grazing")
	player.set_lamp_enabled(true)
	await get_tree().create_timer(.7).timeout
	await _shot("annunciator_flashlight_detail")
	var inspector := preload("res://tests/radiator_native_review.gd").new()
	for draw: MeshInstance3D in board.find_children("*","MeshInstance3D",true,false):
		for i in draw.mesh.get_surface_count():
			var before := inspector.failures.size()
			inspector._check_surface(draw.mesh,i,draw.get_active_material(i))
			if inspector.failures.size()!=before:print("ANNUNCIATOR SURFACE FAILURE ",draw.get_path()," / ",draw.mesh.resource_path," / ",i)
	failures.append_array(inspector.failures);inspector.free();driver.free()
	FileAccess.open(out.path_join("annunciator_hand.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"scope":"Original native board and actual service input/partial restore; no whole repair route or disk contract."},"\t"))
	print("ANNUNCIATOR HAND: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",failures)
	terminal=true;get_tree().quit(0 if failures.is_empty() else 1)
