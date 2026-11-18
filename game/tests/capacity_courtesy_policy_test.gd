extends Node3D
## DRAFT policy diagnostic: real BarRoute/Visit/registry, synthetic graph/body
## stubs. No native room, ordinary motor, physical prevention or full18 proof.
const Registry := preload("res://scripts/building/orison_v2_bar_resident_places.gd")
const Guide := preload("res://scripts/characters/orison_v2_bar_route.gd")
const Visit := preload("res://scripts/characters/orison_v2_bar_visit.gd")
const Courtesy := preload("res://scripts/characters/character_squeeze_past.gd")
class StubWorld extends Node3D:
	var player: Node3D
class StubRoute extends Node3D:
	var world: Node3D
	var actor: Node3D
	var resident: String
	var graph := AStar3D.new()
	var current_id: int
	var desired_id: int
	var planned_id: int
	var path := PackedInt64Array()
	var blocked_reason := "old unrelated reason"
	var _bar_route
var errors: Array[String]=[]
var world: StubWorld
var registry: Node3D
func check(ok: bool, label: String) -> void:
	print(label+": "+str(ok))
	if not ok: errors.append(label)
func body(parent: Node3D, id: String, at: Vector3) -> Node3D:
	var result:=Node3D.new(); result.name=id; parent.add_child(result)
	result.position=at; result.add_to_group("animated_residents")
	return result
func make_route(id: String, base: int, at_stop: bool) -> StubRoute:
	var route:=StubRoute.new(); route.world=world; route.resident=id; world.add_child(route)
	for i in 5: route.graph.add_point(base+i,Vector3(float(i),0,0) if i<4 else Vector3(-1,0,0))
	for edge: Array in [[4,0],[0,1],[1,2],[2,3]]: route.graph.connect_points(base+edge[0],base+edge[1])
	route.current_id=base if at_stop else base+4; route.desired_id=base+3; route.planned_id=base+3
	route.path=PackedInt64Array([base+1,base+2,base+3]) if at_stop else PackedInt64Array([base,base+1,base+2,base+3])
	route.actor=body(route,id,Vector3.ZERO if at_stop else Vector3(-.5,0,0))
	var guide:=Guide.new(); route._bar_route=guide; guide.route=route; guide.graph=route.graph; guide.registry=registry
	guide.visit=Visit.new(); check(guide.visit.bind(registry,id,route.actor),"real visit binds "+id)
	guide._passages=[{"id":"fixture","a":base+2,"b":base+3,"a_slots":[0,1],"b_slots":[2,3],"path":PackedInt64Array([base+2,base+3])}]
	return route
func _ready() -> void: run.call_deferred()
func run() -> void:
	world=StubWorld.new(); add_child(world); world.player=Node3D.new(); world.add_child(world.player)
	registry=Registry.new(); world.add_child(registry)
	for id: String in ["leader","follower","tie","blocker0","blocker1"]: registry.places[id]={"furniture":id}
	var holds: Array[Node3D]=[]
	for i in 4:
		var marker:=Node3D.new(); world.add_child(marker); marker.position=Vector3(10+i,0,0); holds.append(marker)
	check(registry.configure_passage("fixture",holds),"real registry configures declared synthetic slots")
	var blockers: Array[Node3D]=[]; var allowed: Array[int]=[0,1]
	for i in 2:
		var id: String="blocker"+str(i);var actor:=body(world,id,Vector3(20+i,0,0));blockers.append(actor)
		check(registry.enqueue_passage("fixture",id,actor,allowed)==holds[i],"actual capacity consumed "+id)
	var leader:=make_route("leader",0,true)
	var follower:=make_route("follower",10,false) # Different graph IDs, same global stop.
	check(not leader._bar_route.guide_path() and leader._bar_route._gate.is_empty(),"actual guide refuses overflow without reservation")
	check(leader.blocked_reason=="bar passage side holding capacity exhausted","actual overflow cause replaces stale reason")
	var before: String=JSON.stringify(registry._passages)
	check(follower._bar_route.blocks_capacity_courtesy(leader.actor),"same saturated global vertex blocks follower squeeze")
	check(before==JSON.stringify(registry._passages),"prediction changes no registry state")
	# Synthetic dense approach: the old next-only prediction missed this stop.
	follower.graph.add_point(15, Vector3(-.4,0,0)); follower.graph.add_point(16, Vector3(-.2,0,0))
	follower.graph.connect_points(14,15); follower.graph.connect_points(15,16); follower.graph.connect_points(16,10)
	follower.path=PackedInt64Array([15,16,10,11,12,13])
	check(follower._bar_route.blocks_capacity_courtesy(leader.actor),"lookahead crosses several short authored approach legs")
	var tied:=make_route("tie",20,false)
	var first_blocks: bool=follower._bar_route.blocks_capacity_courtesy(tied.actor)
	var second_blocks: bool=tied._bar_route.blocks_capacity_courtesy(follower.actor)
	check(first_blocks!=second_blocks,"equal-distance approach gives exactly one deterministic leader")
	check(first_blocks==follower._bar_route.blocks_capacity_courtesy(tied.actor),"equal-distance decision is stable")
	var courtesy:=Courtesy.new()
	var deadline: int=Engine.get_physics_frames()+120
	while not courtesy.permits(follower.actor,leader.actor) and Engine.get_physics_frames()<deadline: await get_tree().physics_frame
	check(courtesy.active(),"original timed courtesy would permit this stationary peer")
	check(follower._bar_route.blocks_capacity_courtesy(leader.actor),"new capacity condition still preserves spacing after WAIT")
	check(not follower._bar_route.blocks_capacity_courtesy(world.player),"player remains outside route-capacity restriction")
	var original: Vector3=leader.graph.get_point_position(0)
	leader.graph.set_point_position(0,original+Vector3(0,0,1)) # Declared synthetic alternate topology, not live actor movement.
	check(not follower._bar_route.blocks_capacity_courtesy(leader.actor),"different global stop is not blanket waiter ban")
	leader.graph.set_point_position(0,original)
	for i in 2: check(registry.leave_passage("fixture","blocker"+str(i),blockers[i]),"release actual blocker ownership")
	check(follower._bar_route.capacity_stop().is_empty(),"free capacity has no compulsory stop")
	check(follower._bar_route.blocks_capacity_courtesy(leader.actor),"free-slot interval still keeps approaching follower spaced")
	check(not leader._bar_route.blocks_capacity_courtesy(follower.actor),"nearer unreserved leader can advance")
	check(registry.enqueue_passage("fixture","leader",leader.actor,allowed)==holds[0],"head acquires real free queue slot")
	check(registry.try_admit("fixture","leader",leader.actor,true),"real FIFO grants head (synthetic clear geometry)")
	check(leader._bar_route.capacity_stop().is_empty() and not leader._bar_route.blocks_capacity_courtesy(follower.actor),"actual admitted head may pass follower")
	print("CAPACITY COURTESY POLICY: "+str(errors))
	get_tree().quit(0 if errors.is_empty() else 1)
