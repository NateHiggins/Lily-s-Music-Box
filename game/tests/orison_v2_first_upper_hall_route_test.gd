extends "res://tests/orison_v2_apartment_door_route_test.gd"
## Existing two-home circuit followed by both public-hall return connections.
func _init() -> void:
	route_label="FIRST-UPPER HALL ROUTE"
func _prepare_player_start() -> void:
	_require(world.adapter.root.get_node_or_null("FirstUpperHallSeats")!=null,"production hall seats are installed")
	super._prepare_player_start()
func _route() -> void:
	await super._route()
	if not failures.is_empty():return
	for point in [Vector3(6.2,3.2,-3.25),Vector3(-1.75,3.2,-3.4),Vector3(-1.75,3.2,0),Vector3(-3.2,3.2,0),Vector3(-4.65,3.2,0)]:
		if not await _walk(point):return
	_require(not player.noclip and player.collision_mask==1 and player.is_physics_processing(),"ordinary collision retained after both hall return connections")
