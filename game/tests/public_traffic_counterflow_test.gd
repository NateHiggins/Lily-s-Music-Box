extends "res://tests/bodega_approach_counterflow_test.gd"
## Actual production proposal owner and native paving/lamps; reduced graph goals.
const Frontier := preload("res://tests/street_frontier_points.gd")
const Traffic := preload("res://scripts/characters/public_foot_traffic.gd")
const Proposals := preload("res://scripts/characters/public_avoidance_proposals.gd")
var public_traffic: Node3D
var production: Dictionary = {}
class BoundaryBody extends Node3D:
	var mina_animation: Node
class BoundaryRoute extends Node3D:
	var actor: Node3D
	var path := PackedInt64Array([1])
	var route_speed := 1.05
	var _bodega_route: Node
	var _bar_route: Node
	func _talking() -> bool: return false

func _snapshot() -> Dictionary:
	var result:=super._snapshot()
	for source: String in ["res://scripts/characters/public_foot_traffic.gd","res://scripts/characters/public_avoidance_proposals.gd",
		"res://tests/bodega_approach_counterflow_test.gd","res://data/orison_v2/cam_ortiz_routine.json","res://data/orison_v2/transient_guests_routine.json",
		"res://tests/street_frontier_points.gd","res://scripts/building/orison_v2_world_connection.gd",
		"res://scripts/building/orison_v2_front_pavement.gd","res://scripts/building/orison_v2_native_faces.gd",
		"res://scripts/building/orison_v2_street_lamps.gd","res://data/orison_v2/exterior/street_lamps.json",
		"res://data/orison_v2/world_connection.json","res://data/orison_v2_blockout.json"]:
		result[source]={"sha256":FileAccess.get_file_as_string(source).replace("\r\n","\n").sha256_text()}
	for source: String in ["res://assets/props/front_pavement.glb","res://assets/props/front_pavement.glb.import"]:
		result[source]={"sha256":FileAccess.get_sha256(source) if source.ends_with(".glb") else FileAccess.get_file_as_string(source).replace("\r\n","\n").sha256_text()}
	return result

func _exterior_dependencies() -> Dictionary:
	var resolver: Variant=preload("res://scripts/building/orison_v2_exterior_spatial_resolver.gd").load_default()
	production=Frontier.resolve(resolver)
	if not bool(production.get("ok",false)): return {}
	return {"player":player,"geometry_instance_ids":["STREET_ORISON_01","SHOP_BODEGA"],"spatial_resolver":resolver,"geometry_source":production.production_geometry}

func _mount_extra_exterior() -> bool:
	exterior_cell=exterior
	var frame:=Node3D.new(); frame.name="ProductionPavingFrame"; add_child(frame); owned.append(frame); frame.transform=production.registered_frame
	frame.add_child(preload("res://scripts/building/orison_v2_front_pavement.gd").new())
	return preload("res://scripts/building/orison_v2_street_lamps.gd").mount(self)!=null

func _registered_fixture() -> void:
	await _proposal_contract()
	public_traffic=Traffic.new()
	if not _check(public_traffic.configure(self,exterior),"production public owner configures actual street frame"): return
	add_child(public_traffic); owned.append(public_traffic)
	_boundary_contract()
	await super._registered_fixture()
	# All ordinary actors are held by fixture setup, not relocated in this check.
	var before: Dictionary={}
	for route: Node3D in routes: before[route.resident]=route.actor.global_position
	get_tree().paused=true
	await get_tree().physics_frame; await get_tree().physics_frame
	_check(public_traffic._paused and public_traffic._proposals.is_empty() and public_traffic._submitted.is_empty(),"pause retires pending velocity proposals")
	for route: Node3D in routes: _check(route.actor.global_position==before[route.resident],"pause leaves actual actor unchanged "+str(route.resident))
	get_tree().paused=false
	await get_tree().physics_frame; await get_tree().physics_frame
	_check(not public_traffic._paused,"public owner resumes after actual tree pause")

func _boundary_contract() -> void:
	# Proposal policy only: no body motion or replacement of native trip proof.
	var route:=BoundaryRoute.new(); add_child(route); route.set_physics_process(true)
	route.actor=BoundaryBody.new(); route.add_child(route.actor)
	var bounds: Rect2=public_traffic._bounds
	var at:=Vector3(bounds.position.x+.005,public_traffic._floor_y,bounds.get_center().y)
	route.actor.global_position=at
	var delta:=1.0/60.0
	for toward: float in [-1.0,1.0]:
		var target:=at+Vector3(toward,0,0)
		public_traffic._proposals[route.actor.get_instance_id()]={"target":target,"velocity":Vector3(-.75,0,.7)}
		var expected:=at+Vector3(toward,0,0)*route.route_speed*delta
		_check(public_traffic.propose(route,target,delta).distance_to(expected)<.000001,"boundary exit uses guarded authored straight edge for target sign "+str(toward))
	route.process_mode=Node.PROCESS_MODE_DISABLED
	_check(not public_traffic._can_steer(route),"visible disabled owner remains a passive body")
	public_traffic._proposals.erase(route.actor.get_instance_id()); route.free()
	details.boundary_scope="injected velocity proposal policy only; no physical crossing claim"

func _proposal_contract() -> void:
	var probe:=Proposals.new(); probe.open()
	var rows: Array[Dictionary]=[{"id":1,"feet":Vector3.ZERO,"preferred":Vector3(1.42,0,0),"steer":true,"player":false,"max_speed":1.42}]
	_check(probe.submit(rows),"native solver accepts original hurry speed as explicit cap")
	await get_tree().physics_frame; await get_tree().physics_frame; await get_tree().physics_frame
	var reply: Dictionary=probe.take(1)
	_check(not reply.is_empty() and reply.velocity.length()>1.40 and reply.velocity.length()<=1.42001,"native velocity preserves1.42 cap rather than silently limiting to1.05")
	_check(probe.take(1).is_empty(),"safe velocity proposal consumes only once")
	probe.close(); _check(not probe.map.is_valid() and probe.agents.is_empty(),"speed protocol map closes all owned RIDs")
	details.hurry_scope="solver speed-cap protocol only, not physical Mina hurry qualification"

func _overflow_newcomer() -> void:
	await super._overflow_newcomer()
	_check(public_traffic.solver.errors.is_empty(),"production public snapshot owner reports no errors")
	details.public_traffic_scope="actual production owner/ordinary motor with unchanged goals, full bodies and production paving/lamps; reduced home alias and forced destination fixture, not natural attendance"
	details.public_traffic_stats=public_traffic.stats.duplicate()
	details.public_traffic_agents=public_traffic.solver.agents.size()
	_check(int(public_traffic.stats.proposals)>0,"actual ordinary motor consumed production avoidance proposals")
	public_traffic.shutdown()
	_check(not public_traffic.solver.map.is_valid() and public_traffic.solver.agents.is_empty(),"production owner frees map/agents before preview retirement")
