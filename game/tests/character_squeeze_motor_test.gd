extends "res://tests/character_squeeze_player_test.gd"
## Production resident motor/presentation on declared diagnostic solids/graph.
const Route := preload("res://scripts/characters/orison_v2_resident_route.gd")
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
var player: PlayerController
var adapter: OrisonV2AnchorAdapter
var public_traffic: Node3D
func run() -> void:
	if not RealityState.begin_preview_campaign(self): get_tree().quit(2); return
	adapter = OrisonV2AnchorAdapter.new(self)
	block(Vector3(0,-.1,0),Vector3(10,.2,14))
	block(Vector3(0,1,-4),Vector3(10,2,.2))
	player = PlayerController.new(); add_child(player)
	player.position=Vector3(0,0,-2); player.set_physics_process(false)
	var peer := Node3D.new(); add_child(peer); peer.add_to_group("animated_residents")
	var route := Route.new(); route.world=self; add_child(route)
	route._sample=10000; route._capsule.radius=.28; route._capsule.height=1.4
	route._point("start",Vector3(0,0,1.2)); route._point("peer_exit",Vector3(0,0,-1.2))
	route._point("player_exit",Vector3(0,0,-3)); route._point("wall_exit",Vector3(0,0,-5))
	for i in 3: route.graph.connect_points(i,i+1)
	route.current_id=0; route.desired_id=1; route.route_speed=1.05
	route.actor=Presentation.new()
	route.actor.setup("Rhea Sato","rhea_sato","","res://assets/characters/rhea_sato/rhea_sato.gltf")
	route.actor.externally_driven=true; route.add_child(route.actor)
	route.actor.position=Vector3(0,0,1.2)
	check(route.actor._model!=null,"production resident presentation loaded")
	var max_wait := 0.0
	for goal in [1,2,3]:
		route.desired_id=goal
		for tick in Engine.physics_ticks_per_second*9:
			await get_tree().physics_frame
			max_wait=maxf(max_wait,route.blocked_seconds)
			if route.current_id==goal and route.path.is_empty(): break
		if goal<3: check(route.current_id==goal,"ordinary motor passes character target "+str(goal))
		else: check(route.current_id!=goal and route.actor.position.z > -3.65,"ordinary motor still stops at solid wall")
	check(max_wait>=.7,"motor yielded before passing")
	check(route.squeeze.cue_count>=1,"motor emits courtesy after movement")
	route.set_physics_process(false)
	RealityState.end_preview_campaign(self)
	get_tree().quit(0 if failures.is_empty() else 1)
