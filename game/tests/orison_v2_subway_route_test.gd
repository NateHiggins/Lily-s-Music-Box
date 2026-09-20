extends "res://tests/orison_v2_passage_route_test.gd"

func _init() -> void:
	route_label = "V2 SUBWAY SIDEWALK"

func _route() -> void:
	for point in [Vector3(2.3,0,-6.5),Vector3(0,0,-8.5),Vector3(0,0,-10.2),Vector3(0,0,-12.2)]:
		if not await _walk(point): return
	for point in [Vector3(0,0,3),Vector3(14,0,3),Vector3(14,0,4.2),Vector3(14,-.1,8),
			Vector3(14,-.1,13.6),Vector3(-1,-.1,13.6),Vector3(-1,0,15.3),Vector3(-.65,0,16)]:
		if not await _walk_world(point): return
	await _capture("sidewalk_entrance",Vector3(2.5,1.5,16))
	var query := PhysicsRayQueryParameters3D.create(Vector3(2,1,16),Vector3(2,-2,16),1)
	query.exclude = [player.get_rid()]
	var stair := player.get_world_3d().direct_space_state.intersect_ray(query)
	_require(not stair.is_empty() and stair.position.y < -.2, "sidewalk opening exposes relocated real treads")
	query = PhysicsRayQueryParameters3D.create(Vector3(-.65,1.36,16),Vector3(.2,1.36,16),1)
	query.exclude = [player.get_rid()]
	var gate := player.get_world_3d().direct_space_state.intersect_ray(query)
	_require(not gate.is_empty() and gate.position.x > -.3, "authored closed entrance gate retains collision")
	for point in [Vector3(-.7,0,17.3),Vector3(5.65,0,17.3),Vector3(5.65,0,14.8),
			Vector3(-.7,0,14.8)]:
		if not await _walk_world(point): return
	await _capture("subway_outside_arcade",Vector3(2.5,1.5,16))
	if not await _walk_world(Vector3(14,0,14.8)): return
	if not await _walk_world(Vector3(14,0,20)): return
	await _capture("arcade_clear",Vector3(2.5,1.5,16))
