extends Node3D
## Synthetic protocol diagnostic only: real registry/Visit/BarRoute, empty geometry.
## Explicit state probes below are NOT motor, native clearance or arrival proof.
const Registry := preload("res://scripts/building/orison_v2_bar_resident_places.gd")
const Visit := preload("res://scripts/characters/orison_v2_bar_visit.gd")
const Guide := preload("res://scripts/characters/orison_v2_bar_route.gd")
class MiniWorld extends Node3D:
	var player: Node3D
class MiniRoute extends Node3D:
	var world: Node3D
	var actor: Node3D
	var graph := AStar3D.new()
	var resident := "rhea_sato"
	var current_id := 0
	var desired_id := 3
	var planned_id := 3
	var path := PackedInt64Array([4])
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var inputs: Dictionary
var began := Time.get_ticks_msec()
var logger
const SOURCES := ["res://tests/guide_bell_error_capture.gd","res://scripts/building/orison_v2_bar_resident_places.gd",
	"res://scripts/characters/orison_v2_bar_visit.gd","res://scripts/characters/orison_v2_bar_route.gd"]
func _hashes() -> Dictionary:
	var result := {}
	var paths: Array = SOURCES.duplicate(); paths.append(get_script().resource_path); paths.append(scene_file_path)
	for path: String in paths:
		if not FileAccess.file_exists(path): result[path]="MISSING"
		else: result[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	return result
func _check(ok: bool, label: String) -> bool:
	checks.append({"ok":ok,"label":label})
	if not ok: failures.append(label)
	return ok
func _body(parent: Node3D, at: Vector3) -> Node3D:
	var body:=Node3D.new(); parent.add_child(body); body.position=at
	body.add_to_group("animated_residents"); return body
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	logger=preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(logger)
	inputs=_hashes()
	_check(not inputs.values().has("MISSING"),"all bound source inputs exist")
	var world:=MiniWorld.new(); add_child(world)
	world.player=_body(world,Vector3(20,0,20))
	world.player.remove_from_group("animated_residents")
	var registry:=Registry.new(); world.add_child(registry)
	registry.places={"rhea_sato":{"furniture":"synthetic_waiter"},"lena_ortiz":{"furniture":"synthetic_follower"},"transient_guests":{"furniture":"synthetic_opponent"}}
	var holds: Array[Node3D]=[]
	for point: Vector3 in [Vector3(-1,0,0),Vector3(-2,0,0),Vector3(2,0,2)]:
		var marker:=Node3D.new(); world.add_child(marker); marker.position=point; holds.append(marker)
	_check(registry.configure_passage("fixture",holds),"real registry accepts declared synthetic holding layout")
	var route:=MiniRoute.new(); world.add_child(route); route.world=world
	route.actor=_body(route,Vector3(-.5,0,0)) # sole construction place, halfway toward pocket.
	for point: Vector3 in [Vector3.ZERO,Vector3(0,0,1),Vector3(0,0,2),Vector3(1,0,2),Vector3(-1,0,0)]:
		route.graph.add_point(route.graph.get_point_count(),point)
	for edge: Array in [[0,1],[1,2],[2,3],[0,4]]: route.graph.connect_points(edge[0],edge[1])
	var opponent:=_body(world,Vector3(0,0,1.5)); var follower:=_body(world,Vector3(-2,0,0))
	var guide:=Guide.new(); guide.route=route; guide.graph=route.graph; guide.registry=registry
	guide.visit=Visit.new(); _check(guide.visit.bind(registry,"rhea_sato",route.actor),"actual waiter visit binds exact body")
	guide._gate={"id":"fixture","holding":4,"exit":2,"goal":3,"path":PackedInt64Array([1,2])}
	var opponent_slot: Array[int]=[2]; var waiter_slot: Array[int]=[0]; var follower_slot: Array[int]=[1]
	_check(registry.enqueue_passage("fixture","transient_guests",opponent,opponent_slot)==holds[2] and registry.try_admit("fixture","transient_guests",opponent,true),"real active opponent owns passage")
	_check(registry.enqueue_passage("fixture","rhea_sato",route.actor,waiter_slot)==holds[0],"waiter retains exact pocket reservation")
	_check(registry.enqueue_passage("fixture","lena_ortiz",follower,follower_slot)==holds[1],"real follower queues behind waiter")
	for index in 3:
		guide.guide_path()
		_check(not registry.has_admission("fixture","rhea_sato",route.actor) and registry._passages.fixture.queue[0].owner.get_ref()==route.actor and int(registry._passages.fixture.queue[0].slot)==0 and route.path==PackedInt64Array([4]),"live opponent prevents premature admission; exact FIFO/slot stable "+str(index))
	_check(not registry.try_admit("fixture","lena_ortiz",follower,true),"follower cannot bypass active opponent/head")
	_check(registry.leave_passage("fixture","transient_guests",opponent),"opponent releases exact owner")
	# Keep its real body on the segment: free token alone is not physical clearance.
	guide.guide_path()
	_check(not registry.has_admission("fixture","rhea_sato",route.actor),"remaining actual opponent body still vetoes clear-path retry")
	world.remove_child(opponent); opponent.free() # declared opponent retirement, no hidden live peer.
	guide.guide_path()
	var acquired:=registry.has_admission("fixture","rhea_sato",route.actor)
	_check(acquired,"queued waiter acquires free physically clear passage BEFORE reaching remote pocket")
	if acquired:
		_check(route.current_id==0 and route.actor.position==Vector3(-.5,0,0),"guide never transforms body or fabricates reached vertex")
		_check(route.path==PackedInt64Array([0,1,2,3]),"mid-edge retry retraces reached vertex then actual connected corner chain")
		_check(registry._passages.fixture.active.slot==0 and registry._passages.fixture.queue[0].owner.get_ref()==follower,"admission retains waiter slot and follower FIFO")
		route.desired_id=4; guide.guide_path()
		_check(registry.has_admission("fixture","rhea_sato",route.actor) and route.path[0]==0,"mid-edge retarget retains token and committed retrace")
		# Explicit synthetic reached-state probes, NOT a simulated successful motor.
		route.actor.position=Vector3.ZERO; route.current_id=0; guide.guide_path()
		_check(route.path==PackedInt64Array([1,2]),"retarget at reached vertex preserves protected exit before new goal")
		route.actor.position=Vector3(0,0,2); route.current_id=2; route.path.clear(); guide.guide_path()
		_check(not registry.has_admission("fixture","rhea_sato",route.actor) and guide._gate.is_empty(),"actual guide releases at declared reached protected exit")
		_check(registry.try_admit("fixture","lena_ortiz",follower,true),"original FIFO follower becomes eligible only after release")
	_check(inputs==_hashes(),"source bindings stable")
	remove_child(world); world.free()
	var errors: Array=logger.errors.duplicate(); OS.remove_logger(logger)
	_check(errors.is_empty(),"no unexpected engine errors")
	var directory:=OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory)!=OK: get_tree().quit(2); return
	var receipt: Dictionary={"schema_version":2,"evidence_kind":"diagnostic","production_runtime":false,"status":"PASS" if failures.is_empty() else "FAIL","scope":"synthetic graph/real registry visit guide protocol; explicit state probes, no native collision, motor, body sweep, attendance or rendered fit proof","checks":checks,"failures":failures,"source_hashes":inputs,"engine_errors":errors,"execution":{"completed":true,"elapsed_s":(Time.get_ticks_msec()-began)/1000.0,"exit_code":0 if failures.is_empty() else 1}}
	var file:=FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE)
	if file==null: get_tree().quit(2); return
	file.store_string(JSON.stringify(receipt,"\t")); file.flush(); var written:=file.get_error()==OK; file.close()
	get_tree().quit(0 if failures.is_empty() and written else 1)
