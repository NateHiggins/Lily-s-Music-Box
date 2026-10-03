extends "res://tests/orison_v2_roof_route_test.gd"
## One initial placement; retained controller/input for both directions and laundry.
func _init() -> void:
	route_label="GROUND CORE TRANSFER ROUTE"

func _prepare_player_start() -> void:
	player.global_position=world.adapter.root.to_global(Vector3(1.925,-3.18,-3.5));player.velocity=Vector3.ZERO

func _route() -> void:
	for point: Vector3 in [Vector3(1.5,-3.2,-3.3),Vector3(-1.7,-3.2,-3.3),Vector3(-1.7,-3.2,-1.5),Vector3(-1.7,-3.2,.25),Vector3(-1.7,-3.2,1.5),Vector3(-1.7,-3.2,3.15),Vector3(.2,-3.2,3.15),Vector3(.2,-3.2,1.5),Vector3(-1.7,-3.2,1.5),Vector3(-1.7,-3.2,-1.5)]:
		if not await _walk(point):return
	if not await _open_door("B1_LAUNDRY_DOOR"):return
	for point: Vector3 in [Vector3(-3.2,-3.2,-1.5),Vector3(-4.5,-3.2,-1.5),Vector3(-4.5,-3.2,1.5),Vector3(-3.2,-3.2,1.5)]:
		if not await _walk(point):return
	await _roof_capture("laundry_transfer",Vector3(-1.8,-.35,.725))
	for point: Vector3 in [Vector3(-4.5,-3.2,1.5),Vector3(-4.5,-3.2,-1.5),Vector3(-1.7,-3.2,-1.5),Vector3(-1.7,-3.2,.25),Vector3(-1.7,-3.2,1.5),Vector3(-1.7,-3.2,3.15),Vector3(.2,-3.2,3.15)]:
		if not await _walk(point):return
	await _roof_capture("north_column_passage",Vector3(-1.3,-.55,1.4))
	for point: Vector3 in [Vector3(-1.7,-3.2,3.15),Vector3(-1.7,-3.2,1.5),Vector3(-1.7,-3.2,-1.5),Vector3(-1.7,-3.2,-3.3),Vector3(1.5,-3.2,-3.3),Vector3(1.925,-3.2,-3.5)]:
		if not await _walk(point):return
	_require(not player.noclip and player.collision_mask==1,"both west passage directions retain actual collision")
