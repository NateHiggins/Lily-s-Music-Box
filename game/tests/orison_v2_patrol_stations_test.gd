extends "res://tests/orison_v2_floor_surface_test.gd"
## Dossier slice 80, at the owner's direction: a patrol station on every floor.
## Each box is the existing WatchStationProp at its own anchor, flush on an
## actual wall with a clear face, and every box is on the one network. One round
## with the tour key marks all seven and drops all seven register shutters.
const STATIONS := {
	"B1_WATCH_STATION": ["B1_STATION_BOILER", 1, -3.2],
	"F02_WATCH_STATION": ["F02_STATION_CORE", 2, 3.2],
	"F03_WATCH_STATION": ["F03_STATION_CORE", 3, 6.4],
	"F04_WATCH_STATION": ["F04_STATION_CORE", 4, 9.6],
	"F05_WATCH_STATION": ["F05_STATION_CORE", 5, 12.8],
	"F06_WATCH_STATION": ["F06_STATION_CORE", 6, 16.0],
	"F01_WATCH_STATION": ["F01_STATION_LOBBY", 7, 0.0],
}

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if world.player==null or world.startup_failed:
		check(false,"production world initializes with its patrol stations")
		world.free()
		get_tree().quit(1)
		return
	world.player.set_physics_process(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false): layer.hide()
	var root: Node3D = world.adapter.root
	var network: WatchStationNetwork = world.watch_station_network
	var register := world.find_child("F01_SIGNAL_REGISTER",true,false) as WatchRegisterProp
	var guard := world.find_child("F01_TOUR_KEY_GUARD",true,false) as TourKeyGuardProp
	check(network!=null and network.station_count()==STATIONS.size(),"one network carries a box from every floor")
	check(register!=null and WatchRegisterProp.SHUTTER_NUMBERS==[1,2,3,4,5,6,7],"the register has a drop for every box")
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ordered: Array[WatchStationProp] = []
	for anchor: String in STATIONS:
		var row: Array = STATIONS[anchor]
		var station := world.adapter.resolve(anchor) as WatchStationProp
		check(station!=null,"patrol station mounted: "+anchor)
		if station==null: continue
		check(station.station_id==str(row[0]) and station.station_number()==int(row[1]) and station.legend()=="STATION %d" % int(row[1]),"station number and legend: "+anchor)
		check(absf(root.to_local(station.global_position).y-(float(row[2])+1.42))<.001,"case hangs at 1.42 m on its own floor: "+anchor)
		# The box has no body, so a ray through its face meets the wall it hangs on.
		var mount := station.to_global(Vector3(0,.16,0))
		var out := station.global_basis.z.normalized()
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(mount+out*.3,mount-out*.05,1,[world.player.get_rid()]))
		check(not hit.is_empty() and hit.position.distance_to(mount)<.002 and hit.normal.dot(out)>.99,"box flush on an actual wall: "+anchor)
		var front: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(mount+out*.02,mount+out*.7,1,[world.player.get_rid()]))
		check(front.is_empty(),"nothing stands in front of the box: "+anchor)
		ordered.append(station)
		await _look(world,station.to_global(Vector3(0,-1.42,.95)),station.to_global(Vector3(0,.2,0)))
		await shot("patrol_"+anchor)
	ordered.sort_custom(func(a: WatchStationProp,b: WatchStationProp) -> bool: return a.station_number()<b.station_number())
	# One round: the key off its hook, every box opened, cranked and shut, in order.
	check(guard!=null and guard.take_key() and network.tour_key_carried(),"the tour key leaves its hook for the round")
	for station in ordered:
		check(station.open_door() and station.turn_crank() and station.marked() and station.close_door(),"box worked with the tour key: "+station.station_id)
	var delivered := network.delivered()
	check(delivered.size()==STATIONS.size(),"every mark reached the register")
	var order: Array = delivered.map(func(r: Dictionary) -> int: return int(r.get("station_number",0)))
	check(order==[1,2,3,4,5,6,7],"the register's sequence is the round: plant, floors 2 to 6, lobby")
	for number in WatchRegisterProp.SHUTTER_NUMBERS:
		check(register.shows(number),"register drop %d down" % number)
	var at := register.to_global(Vector3(0,-.25,.95))
	await _look(world,Vector3(at.x,root.to_global(Vector3.ZERO).y,at.z),register.to_global(Vector3(0,.23,0)))
	await shot("patrol_register_after_round")
	check(guard.return_key() and not network.tour_key_carried(),"the key goes back on its hook")
	for station in ordered: check(station.reset_station() and not station.marked(),"box reset: "+station.station_id)
	check(register.reset_shutters() and not register.shows(1),"register restored for the morning")
	print("PATROL STATIONS: stations=%d marks=%d delivered=%d failures=%d" % [ordered.size(),network.mark_count(),delivered.size(),failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)

func _look(world: Node, feet: Vector3, target: Vector3) -> void:
	world.player.global_position = feet
	world.player.velocity = Vector3.ZERO
	world.player.set_lamp_enabled(true)
	for i in 12: await get_tree().physics_frame
	var eye: Vector3 = world.player.camera.global_position
	var flat := Vector2(target.x-eye.x,target.z-eye.z)
	world.player.rotation.y = atan2(-flat.x,-flat.y)
	world.player.camera.rotation = Vector3(atan2(target.y-eye.y,flat.length()),0,0)
	for i in 8: await get_tree().process_frame
