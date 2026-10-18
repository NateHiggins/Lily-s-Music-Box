extends Node3D
## Fast actual-control diagnosis; no composed-world or runtime-contract proof.
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.12,.14,.16)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.5;add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);add_child(sun)
	var board:=OtisProp.new();board.name="LobbyPorterBoard";board.prop_type="otis";board.position=Vector3(-3.,1.4,0);add_child(board)
	var boiler:=BoilerProp.new();boiler.name="B1_BOILER_01";boiler.prop_type="boiler";boiler.position.x=3.;add_child(boiler)
	preload("res://scripts/building/v2_legacy_material_stock.gd").apply(self)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/service_instruments.json"))
	data.actors=data.actors.filter(func(row):return row.id in ["LobbyPorterBoard","B1_BOILER_01"])
	data.source_materials=data.source_materials.filter(func(row):return row.actor in ["LobbyPorterBoard","B1_BOILER_01"])
	data.work_lights=[];data.dumbwaiter_ropes=[]
	var subset: String="user://first_slice_physical_bench_subset.json"
	FileAccess.open(subset,FileAccess.WRITE).store_string(JSON.stringify(data))
	var factory:=preload("res://scripts/building/orison_v2_native_service_instruments.gd").new()
	if not factory.mount(self,subset):push_error(str(factory.errors));get_tree().quit(1);return
	var player:=PlayerController.new();add_child(player);player.set_physics_process(false)
	var contract:=preload("res://tests/orison_v2_first_slice_contract_test.gd").new();contract.service_bench_only=true;add_child(contract)
	await contract._prove_board(player,board)
	await contract._prove_boiler(player,boiler)
	await _radiator_transfer(contract,player)
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("service_hand_bench.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":contract.observations,"failures":contract.failures,"scope":"Actual board/boiler pointer operations using the bound first-slice driver. No composed-world, job, travel, disk or runtime-contract acceptance."},"\t"))
	print("FIRST SLICE SERVICE HAND BENCH: ","PASS" if contract.failures==0 else "FAIL","; ",contract.passes," passes; ",contract.failures," failures")
	var failed: int=contract.failures;contract.free();player.free();factory=null;board.free();boiler.free();get_tree().quit(1 if failed else 0)

func _radiator_transfer(contract: Node,player: PlayerController) -> void:
	var inventory:=MaintenanceInventory.new();add_child(inventory);inventory.setup()
	var floor_body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(4,.1,4);shape.shape=box;shape.position.y=-.05;floor_body.add_child(shape);add_child(floor_body)
	var prop:=RadiatorProp.new();prop.use_native_v2=true;prop.unit="2B";prop.graph_node_id="F02_B_RADIATOR_01"
	prop.rotation.y=PI*.5;prop.installation_drop=.75;prop.position.y=.75;prop.bind_inventory(inventory)
	preload("res://scripts/building/orison_v2_heating.gd").new()._add_collision(prop);add_child(prop)
	var stock:=preload("res://scripts/props/radiator_vent_stock.gd").new();stock.position=Vector3(1.,.85,.2);add_child(stock)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/heating_service_stock.json"));stock.install_rack(source.asset);stock.configure([prop],source)
	if not await contract._service_supply(player,prop,0.):return
	var original: Dictionary=stock.active(prop)
	if not await contract._service_move_new(player,prop,original.body,Vector3(0,.004,0),Vector3(.03,.10,-.08),stock.THREAD_END):return
	if not await contract._pick_service_part(player,original.body,prop,Vector3(.03,.10,-.08)):return
	contract._check(await contract._carry_service_part(player,original.body,prop.native_rig.to_global(Vector3(-.30,.12,-.55))),"bench original insert physically clears seat")
	player.cancel_manipulation()
	var spare: Dictionary=stock.rows.VENT_SPARE_2
	if not await contract._pick_service_part(player,spare.body,stock,Vector3(.03,.10,.08)):return
	contract._check(await contract._carry_service_part(player,spare.body,spare.body.global_position+Vector3.UP*.04),"bench spare physically lifts clear of rack")
	var receiving: Transform3D=stock._thread_pose(prop,stock.THREAD_END)
	var delivered: bool=await contract._deliver_service_part(player,spare.body,receiving.origin)
	contract._check(delivered,"bench spare physically reaches receiver")
	if not delivered:return
	player.cancel_manipulation()
	contract._check(spare.slot==prop.graph_node_id,"bench delivered spare catches existing thread")
	if not await contract._service_move_new(player,prop,spare.body,Vector3(0,.004,0),Vector3(.03,.10,-.08),0.):return
	contract._check(prop.vent_grade==2 and stock.active(prop).body==spare.body,"bench reverse thread seats actual spare")
