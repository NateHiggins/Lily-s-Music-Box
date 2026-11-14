extends Node3D
## Synthetic protocol only: declared eligibility and graph/position metadata;
## no physics, native mesh, motor execution or actual BarRoute detour claim.
const Guide := preload("res://scripts/characters/orison_v2_bodega_route.gd")
const Admission := preload("res://scripts/building/bodega_admission.gd")
const StateFixture := preload("res://tests/bodega_admission_test.gd")
const INPUTS := ["res://tests/bodega_route_policy_test.gd","res://tests/BodegaRoutePolicyTest.tscn",
	"res://scripts/characters/orison_v2_bodega_route.gd","res://scripts/characters/orison_v2_bar_route.gd",
	"res://scripts/building/bodega_admission.gd","res://scripts/characters/shared_passage_admission.gd",
	"res://tests/bodega_admission_test.gd","res://tests/guide_bell_error_capture.gd"]
class RouteStub extends Node3D:
	var resident := "entrant"
	var actor: Node3D
	var graph := AStar3D.new()
	var current_id := 0
	var desired_id := 9
	var planned_id := -1
	var path := PackedInt64Array()
	var blocked_reason := ""
	var destination := "unit"
class EligibilityGate extends Guide:
	var declared_blocking_peer: Node3D
	func _people_path_clear(_names: Array) -> bool:
		return not is_instance_valid(declared_blocking_peer)
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var details: Dictionary = {}
func _check(ok: bool, label: String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok: failures.append(label)
func _hashes() -> Dictionary:
	var result := {}
	for path: String in INPUTS:
		result[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text() if FileAccess.file_exists(path) else ""
	return result
func _body() -> Node3D:
	var body:=Node3D.new(); add_child(body); return body
func _ready() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory)!=OK: get_tree().quit(2); return
	var logger:=preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(logger)
	var inputs:=_hashes()
	for path: String in INPUTS: _check(not str(inputs[path]).is_empty(),"bound source exists "+path)
	_transit_eligibility(); _approach_detour(); _queued_turn_retarget()
	for child: Node in get_children(): remove_child(child); child.free()
	await get_tree().process_frame
	_check(inputs==_hashes(),"source bindings stable")
	_check(logger.errors.is_empty(),"no unexpected engine errors"); var errors: Array=logger.errors.duplicate(); OS.remove_logger(logger)
	var result: Dictionary={"schema_version":2,"evidence_kind":"diagnostic","production_runtime":false,"status":"PASS" if failures.is_empty() else "FAIL",
		"scope":"synthetic guide/real admission state protocol only; no actual blocker clearance, physics, motor, native route, FIFO geometry or arrival qualification",
		"source_hashes":inputs,"checks":checks,"failures":failures,"details":details,"engine_errors":errors}
	var file:=FileAccess.open(directory.path_join("route_policy.json"),FileAccess.WRITE)
	if file==null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result,"\t")); file.flush(); var written:=file.get_error()==OK; file.close()
	print("BODEGA ROUTE POLICY: ",result.status," checks=",checks.size()," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() and written else 1)
func _transit_eligibility() -> void:
	var exterior:=StateFixture.FixtureExterior.new(); add_child(exterior)
	var owner:=Admission.new(); add_child(owner); _check(owner.configure(exterior),"reuse declared synthetic resolver with real admission owner")
	var serving:=_body(); serving.global_position=owner.position_marker(Guide.SERVICE).global_position
	var entrant:=_body(); entrant.global_position=owner.position_marker(Guide.OFA).global_position
	var blocker:=_body(); blocker.global_position=owner.position_marker(Guide.OF).global_position
	_check(owner.bind("serving",serving) and owner.bind("entrant",entrant),"exact live actor bindings")
	_check(owner.request_service("serving",serving)!=null and owner.try_service("serving",serving,true) and owner.arrive_service("serving",serving),"real state owner already serving")
	var route:=RouteStub.new(); add_child(route); route.actor=entrant
	route.graph.add_point(0,entrant.global_position); route.graph.add_point(1,blocker.global_position); route.graph.add_point(9,serving.global_position); route.graph.connect_points(0,1)
	var guide:=EligibilityGate.new(); guide.route=route; guide.owner=owner; guide._station=Guide.OFA; guide._nodes={Guide.OFA:0,Guide.OF:1}; guide.declared_blocking_peer=blocker
	_check(not guide._transit([Guide.OFA,Guide.OF],"entry"),"declared blocked newcomer refuses transit")
	var blocked_state:=owner.debug_snapshot()
	_check(blocked_state.transit.queue.is_empty() and blocked_state.transit.active.is_empty(),"physical refusal occurs before FIFO insertion")
	var exit_slot: Array[int]=[0]
	_check(owner.request_transit("serving",serving,exit_slot)!=null and owner.try_transit("serving",serving,true),"existing service owner can acquire departure instead of blocked newcomer")
	details.blocked_transit={"declared_blocker":str(blocker.get_path()),"after_refusal":blocked_state,"departure":owner.debug_snapshot()}
	# Reset actual state claims; explicit eligibility-seam change, not simulated motion.
	owner.cancel("entrant",entrant,true); owner.release_transit("serving",serving,true); guide.declared_blocking_peer=null
	_check(guide._transit([Guide.OFA,Guide.OF],"entry") and owner.has_transit("entrant",entrant),"unblocked eligibility still admits real bound newcomer")
func _approach_detour() -> void:
	var route:=RouteStub.new(); add_child(route); route.actor=_body()
	for pair: Array in [[0,Vector3.ZERO],[1,Vector3(1,0,0)],[2,Vector3(1,0,1)],[3,Vector3(2,0,0)],[4,Vector3(3,0,0)],[9,Vector3(9,0,0)]]: route.graph.add_point(pair[0],pair[1])
	for edge: Array in [[0,1],[1,3],[3,4],[1,2],[2,3],[2,0]]: route.graph.connect_points(edge[0],edge[1])
	var guide:=Guide.new(); guide.route=route; guide._nodes={Guide.ALIGN:3,Guide.OFA:4,Guide.PUBLIC_STREET:0,Guide.PUBLIC_TURN:1}; guide._leg=PackedInt64Array([0,1,3,4]); guide._leg_kind="approach"
	route.current_id=2; route.actor.global_position=route.graph.get_point_position(2).lerp(route.graph.get_point_position(3),.5); route.path=PackedInt64Array([3])
	var before:=route.actor.global_position
	_check(guide._install_tail() and route.path==PackedInt64Array([3]) and route.actor.global_position==before,"mid-edge detour preserves exact committed next vertex without relocation")
	route.actor.global_position=route.graph.get_point_position(2); route.path.clear() # Declared synthetic reached vertex, no actual travel claim.
	_check(guide._install_tail(),"legitimate reached detour vertex resumes upstream approach")
	var connected:=true; var previous:=int(route.current_id)
	for point: int in route.path: connected=connected and route.graph.are_points_connected(previous,point); previous=point
	_check(not route.path.is_empty() and route.path[-1]==4 and connected and route.desired_id==9,"resumed tail follows graph edges to original staging goal without changing semantic destination")
	details.detour={"current":route.current_id,"resumed_path":Array(route.path),"semantic_desired":route.desired_id,"guide_errors":guide.errors.duplicate()}
	# An unregistered local itinerary deviation remains refused; no blanket recovery.
	guide._leg=PackedInt64Array([0,1,3,4]); guide._leg_kind="entry"; route.path=PackedInt64Array([3])
	_check(not guide._install_tail() and not guide.errors.is_empty(),"local itinerary deviation still fails closed")
	details.local_refusal_errors=guide.errors.duplicate()

func _queued_turn_retarget() -> void:
	var exterior:=StateFixture.FixtureExterior.new(); add_child(exterior)
	var owner:=Admission.new(); add_child(owner); _check(owner.configure(exterior),"retarget state fixture configures")
	var serving:=_body(); serving.global_position=owner.position_marker(Guide.SERVICE).global_position
	var entrant:=_body()
	_check(owner.bind("serving",serving) and owner.bind("entrant",entrant),"retarget exact bodies bind")
	_check(owner.request_service("serving",serving)!=null and owner.try_service("serving",serving,true) and owner.arrive_service("serving",serving),"unrelated physical service owner established")
	var holding: Node3D=owner.request_service("entrant",entrant)
	_check(holding!=null,"upstream entrant owns queued request")
	var route:=RouteStub.new(); add_child(route); route.actor=entrant; route.destination="unit"
	for pair: Array in [[0,Vector3.ZERO],[1,Vector3(1,0,0)],[3,Vector3(2,0,0)],[4,Vector3(3,0,0)],[9,Vector3(9,0,0)]]: route.graph.add_point(pair[0],pair[1])
	for edge: Array in [[0,1],[1,3],[3,4]]: route.graph.connect_points(edge[0],edge[1])
	var guide:=Guide.new(); guide.route=route; guide.owner=owner; guide._enabled=true; guide._bound=true
	guide._nodes={Guide.PUBLIC_STREET:0,Guide.PUBLIC_TURN:1,Guide.ALIGN:3,Guide.OFA:4}
	guide._holding=str(holding.name); guide._leg_kind="approach"; guide._leg=PackedInt64Array([0,1,3,4])
	entrant.global_position=Vector3(.5,0,0); route.path=PackedInt64Array([1,3,4])
	_check(guide.guide_path() and guide.manages_path() and route.path[0]==1 and owner.request_service("entrant",entrant)==holding,"mid-edge retarget keeps next public turn and original queue claim")
	route.current_id=1; entrant.global_position=Vector3(1,0,0)
	_check(guide.guide_path() and not guide.manages_path() and route.path.is_empty() and owner.debug_snapshot().service.queue.is_empty(),"reached public turn cancels queued request without needless shop round trip")
	_check(owner.has_service("serving",serving),"upstream cancellation preserves another actual service owner")
	# Explicit safe retirement before the existing outside handoff; no hiding seam.
	guide._holding=str(owner.request_service("entrant",entrant).name); route.current_id=0; entrant.global_position=Vector3.ZERO
	guide._leg_kind="approach"; guide._leg=PackedInt64Array([0,1,3,4]); route.path=PackedInt64Array([1,3,4])
	_check(guide.release_upstream_for_outside() and owner.debug_snapshot().service.queue.is_empty() and route.path.is_empty(),"upstream outside preparation retires only queued custody")
	_check(owner.has_service("serving",serving),"outside preparation preserves other physical service custody")
