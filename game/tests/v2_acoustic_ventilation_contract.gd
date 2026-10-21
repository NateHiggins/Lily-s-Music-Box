extends "res://tests/v2_spatial_access_cohort.gd"
## Executed partial-network proof; no full-graph, save or listening grant.
const Topology := preload("res://scripts/building/orison_v2_acoustic_topology.gd")
var additional_contracts := {}

func _additional_checks(_world: OrisonV2RuntimeRoot) -> void:
	pass

func _additional_scope() -> String:
	return ""

func _run() -> void:
	initial_inputs=_inputs();bindings=_dependencies()
	if failures>0:
		push_error("Network contract input binding failed before world composition")
		get_tree().quit(1);return
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	Selector.reset_for_tests("v2")
	var original := AcousticGraphData.nodes.duplicate(true)
	var owner_id := AcousticGraphData.get_instance_id()
	var dictionary: Dictionary=AcousticGraphData.nodes
	var world := (load(Selector.scene_path()) as PackedScene).instantiate() as OrisonV2RuntimeRoot
	add_child(world);await get_tree().physics_frame;await get_tree().physics_frame
	_check(not world.startup_failed,"production-selected V2 world starts")
	if world.startup_failed:
		world.shutdown_for_tests();world.free()
		print("V2 ACOUSTIC VENTILATION: FAIL; production startup refused")
		get_tree().quit(1);return
	var module = world.acoustic_topology
	_check(module!=null and module.errors.is_empty(),"physical source bindings accepted")
	_check(AcousticGraphData.get_instance_id()==owner_id and is_same(dictionary,AcousticGraphData.nodes),"original propagation owner and dictionary survive installation")
	_check(AcousticGraphData._topology_base==original and not AcousticGraphData._topology_scopes.is_empty(),"topology lease retains the original graph beneath later physical fits")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Topology.DATA))
	var heat: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/acoustic_heating.json"))
	var flue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/acoustic_flue.json"))
	var current := {}
	for identity: String in AcousticGraphData.nodes:
		if AcousticGraphData.nodes[identity].get("network")=="ventilation":current[identity]=true
	_check(current.size()==49 and data.nodes.size()==49 and data.routes.size()==45,"all installed ventilation nodes and ducts are represented")
	_check(AcousticGraphData.nodes.size()==original.size()-2+27+11,"two absent duct junctions retire; 27 heating and eleven flue carriers enter")
	for retired: Dictionary in data.retirements:
		_check(not AcousticGraphData.nodes.has(str(retired.id)),"uninstalled junction cannot transmit: "+str(retired.id))
	for row: Dictionary in data.nodes:
		var identity := str(row.id)
		var expected: Vector3=world.adapter.root.to_global(GameBoot.b2g(row.pos))
		_check(AcousticGraphData.node_pos(identity).distance_to(expected)<.0001,"actual registered frame: "+identity)
		for key: String in ["frequency_band","delay_ms","damping","infection_receptivity"]:
			_check(AcousticGraphData.nodes[identity][key]==original[identity][key],"authored "+key+": "+identity)
	_check(module.physical_owners_valid(world.adapter),"installed fan/register and native duct owners agree")
	await _additional_checks(world)
	var four: Array=Topology.PARITY
	var carriers := {}
	for node: Node in world.find_children("*","FunctionalProp",true,false):
		var identity := str(node.get("graph_node_id"))
		if identity.is_empty() or str(node.name)!=identity:continue
		if not carriers.has(identity):carriers[identity]=[]
		carriers[identity].append(node)
	for identity: String in original:
		if original[identity].get("network") in ["ventilation","heating","flue"] or identity in four:continue
		var actual: Dictionary=AcousticGraphData.nodes[identity].duplicate(true)
		if actual.pos!=original[identity].pos:
			var owners: Array=carriers.get(identity,[])
			_check(owners.size()==1 and AcousticGraphData.node_pos(identity).distance_to((owners[0] as Node3D).global_position)<.001,"existing position update has one actual physical carrier: "+identity)
			actual.pos=original[identity].pos
		_check(actual==original[identity],"other network authored fields preserved: "+identity)
	for identity: String in four:
		var carrier := world.adapter.resolve(identity) as Node3D
		_check(carrier!=null and AcousticGraphData.node_pos(identity).distance_to(carrier.global_position)<.0001,"retained parity carrier: "+identity)
	var heard: Array[String]=[]
	var listener := func(identity: String,index: int,accent: float,pitch: float,_strength: float):
		if index==0 and accent==.00314159 and pitch==1.:heard.append(identity)
	AcousticGraphData.network_event.connect(listener)
	var expected_events := {}
	for row: Dictionary in data.nodes:
		if row.riser=="V-A":expected_events[str(row.id)]=true
	var plan: Array=AcousticGraphData.audibility("ROOF_VENT_FAN_A")
	_check(plan.size()==expected_events.size(),"fan reaches only its physically installed duct stack")
	AcousticGraphData.propagate("ROOF_VENT_FAN_A",0,.00314159,1.)
	await get_tree().create_timer(.6).timeout
	AcousticGraphData.network_event.disconnect(listener)
	_check(heard.size()==expected_events.size(),"real autoload emits the complete source-derived propagation")
	for identity: String in heard:
		_check(expected_events.has(identity),"no transmission to a different physical stack: "+identity)
	_check("F04_B_BATH_VENT_REGISTER" in heard and "F02_B_BATH_VENT_REGISTER" not in heard,"actual V2 assignment wins over the old unit-letter shortcut")
	_check(heat.nodes.size()==53 and heat.routes.size()==52,"all native steam connections represented")
	var narrative: Array=AcousticGraphData._reality_plan("B1_BOILER_01",{"carrier":"network","networks":["heating"]})
	for target: Dictionary in narrative:
		_check(not AcousticGraphData.nodes[target.id].get("transit_only",false),"passive junction cannot consume an actual case target: "+str(target.id))
	for row: Dictionary in heat.nodes:
		var identity := str(row.id)
		var expected_point: Vector3=world.adapter.root.to_global(GameBoot.b2g(row.pos))
		_check(AcousticGraphData.node_pos(identity).distance_to(expected_point)<.0001,"actual heating frame: "+identity)
		_check(AcousticGraphData.nodes[identity].connections==row.connections,"source-derived heating connections: "+identity)
		if original.has(identity):
			for key: String in ["frequency_band","delay_ms","damping","infection_receptivity"]:
				_check(AcousticGraphData.nodes[identity][key]==original[identity][key],"retained heating "+key+": "+identity)
		else:
			_check(row.delay_ms==0 and row.damping==0 and row.infection_receptivity==0,"passive junction cannot add loss, delay or infection: "+identity)
	for bridge: Dictionary in heat.external_bridges:
		_check(bridge.end in AcousticGraphData.nodes[bridge.start].connections,"retained external heating bridge: "+str(bridge.start)+" -> "+str(bridge.end))
	var heat_heard: Array[String]=[]
	var heat_listener := func(identity: String,index: int,accent: float,pitch: float,_strength: float):
		if index==0 and accent==.00271828 and pitch==1. and AcousticGraphData.nodes[identity].network=="heating":heat_heard.append(identity)
	AcousticGraphData.network_event.connect(heat_listener)
	AcousticGraphData.propagate("B1_BOILER_01",0,.00271828,1.)
	await get_tree().create_timer(1.).timeout
	AcousticGraphData.network_event.disconnect(heat_listener)
	_check(heat_heard.size()==53,"original autoload delivers boiler events to every physical heating junction and emitter")
	for row: Dictionary in heat.nodes:
		_check(str(row.id) in heat_heard,"observed actual heating delivery: "+str(row.id))
	_check(flue.nodes.size()==24 and flue.routes.size()==23,"all thirteen retained and eleven passive flue carriers represented")
	for row: Dictionary in flue.nodes:
		var identity: String=str(row.id)
		_check(AcousticGraphData.node_pos(identity).distance_to(world.adapter.root.to_global(GameBoot.b2g(row.pos)))<.0001,"actual flue frame: "+identity)
		_check(AcousticGraphData.nodes[identity].connections==row.connections,"source-derived physical flue connections: "+identity)
		if original.has(identity):
			for key: String in ["frequency_band","delay_ms","damping","infection_receptivity"]:
				_check(AcousticGraphData.nodes[identity][key]==original[identity][key],"retained flue "+key+": "+identity)
		else:
			_check(row.transit_only and row.delay_ms==0 and row.damping==0 and row.infection_receptivity==0,"flue transit cannot invent a case target, loss or delay: "+identity)
	for target: Dictionary in AcousticGraphData._reality_plan("B1_FLUE_BASE",{"carrier":"network","networks":["flue"]}):
		_check(not AcousticGraphData.nodes[target.id].get("transit_only",false),"passive flue carrier excluded from case targets: "+str(target.id))
	var flue_heard: Array[String]=[]
	var flue_listener:=func(identity: String,index: int,accent: float,pitch: float,_strength: float):
		if index==0 and accent==.00161803 and pitch==1. and AcousticGraphData.nodes[identity].network=="flue":flue_heard.append(identity)
	AcousticGraphData.network_event.connect(flue_listener)
	AcousticGraphData.propagate("B1_FLUE_BASE",0,.00161803,1.)
	await get_tree().create_timer(2.).timeout
	AcousticGraphData.network_event.disconnect(flue_listener)
	_check(flue_heard.size()==24,"original autoload delivers every installed flue carrier")
	for row: Dictionary in flue.nodes:_check(str(row.id) in flue_heard,"observed actual flue delivery: "+str(row.id))

	if module!=null:
		_check(module.release() and AcousticGraphData.nodes==original,"explicit release restores the complete original graph")
		var rebuilt := Topology.new()
		_check(rebuilt.mount(world.adapter,world.layout) and rebuilt.physical_owners_valid(world.adapter),"fresh scope reconstructs from unchanged physical sources")
		module=rebuilt;world.acoustic_topology=rebuilt
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var fan := world.adapter.resolve("ROOF_VENT_FAN_A") as Node3D
		world.player.camera.global_position=fan.to_global(Vector3(2.6,1.4,2.6))
		world.player.camera.look_at(fan.global_position+Vector3.UP*.35)
		world.player.camera.make_current()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("installed_fan.png"))
	var held: WeakRef = weakref(world)
	world.shutdown_for_tests();world.free();await get_tree().process_frame
	_check(held.get_ref()==null,"production root retires")
	_check(AcousticGraphData.nodes==original and AcousticGraphData._topology_scopes.is_empty() and AcousticGraphData._topology_base.is_empty(),"teardown restores every legacy node and releases topology ownership")
	_check(AcousticGraphData.get_instance_id()==owner_id and is_same(dictionary,AcousticGraphData.nodes),"propagation authority identity remains unchanged after teardown")
	var final_inputs:=_inputs()
	_check(initial_inputs==final_inputs and bindings==_dependencies(),"production/geometry and complete test inputs stay fixed")
	var head: Array=[]
	OS.execute("git",["-C",ProjectSettings.globalize_path("res://.."),"rev-parse","HEAD"],head)
	_check(head.size()==1 and str(head[0]).strip_edges().length()==40,"record actual repository provenance")
	_check(not directory.is_empty(),"explicit proof output directory")
	var file: FileAccess
	if not directory.is_empty():file=FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE)
	_check(file!=null,"open executed network contract")
	var test_path: String = "game/"+get_script().resource_path.trim_prefix("res://")
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Installed V2 ventilation, heating and flue topology and event routing only; other acoustic networks, disk save, navigation and human listening remain unproved. "+_additional_scope(),
		"execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false},
		"source":{"test_path":test_path,"test_sha256":bindings.get(test_path,""),
			"test_dependencies":bindings,"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "",
			"runtime_inputs_sha256":final_inputs.runtime,"surface_inputs_sha256":final_inputs.surface},
		"checks":checks,"failures":failures,
		"contracts":{"flue_topology":{"executed":true,"status":"PASS" if failures==0 else "FAIL","nodes":flue.nodes.size(),"routes":flue.routes.size(),"observed_nodes":flue_heard},"heating_topology":{"executed":true,"status":"PASS" if failures==0 else "FAIL","nodes":heat.nodes.size(),"routes":heat.routes.size(),"observed_nodes":heat_heard},
			"ventilation_topology":{"executed":true,"status":"PASS" if failures==0 else "FAIL","nodes":current.size(),"routes":data.routes.size()},
			"propagation":{"executed":true,"status":"PASS" if failures==0 else "FAIL","observed_nodes":heard},
			"teardown":{"executed":true,"status":"PASS" if failures==0 else "FAIL","retained_nodes":0 if held.get_ref()==null else 1}}}
	for key: String in additional_contracts:
		additional_contracts[key].status="PASS" if failures==0 else "FAIL"
		receipt.contracts[key]=additional_contracts[key]
	if file!=null:file.store_string(JSON.stringify(receipt,"\t"));file.flush()
	print("V2 ACOUSTIC VENTILATION: ","PASS" if failures==0 else "FAIL"," checks=",checks.size()," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)
