extends "res://tests/orison_v2_basement_route_test.gd"
## Ordinary street-to-bunker travel, with independent physics rays through
## the raised aperture and into its retained sill and closed pavement plate.
func _init() -> void:
	route_label = "COAL DELIVERY"

func _route() -> void:
	for point in [Vector3(2.3,0,-6.5),Vector3(0,0,-8.5),Vector3(0,0,-12.8),Vector3(14.2,0,-13.3)]:
		if not await _walk(point): return
	await _roof_capture("closed_delivery_cover",Vector3(14.2,.02,-13.3))
	if not _require(player.is_on_floor(),"closed coal cover remains walkable"): return
	for point in [Vector3(0,0,-12.8),Vector3(0,0,-8.5),Vector3(2.3,0,-6.5),Vector3(2.3,0,-3.5),
			Vector3(3.8,0,-3.4),Vector3(3.8,-1.6,1.3),Vector3(2.3,-1.6,1.3),Vector3(2.3,-3.2,-3.5),
			Vector3(5,-3.2,-3.5),Vector3(5,-3.2,-.4),Vector3(8.3,-3.2,-.4)]:
		if not await _walk(point): return
	if not await _open_door("B1_BOILER_FIRE_DOOR"): return
	# Clear the open fire-door tip before turning into the west boiler aisle.
	for point in [Vector3(11.2,-3.2,-.4),Vector3(11.2,-3.2,-1.8),Vector3(10.6,-3.2,-1.8),Vector3(10.6,-3.2,-3.8),Vector3(14.2,-3.2,-3.8),Vector3(14.2,-3.2,-4.4)]:
		if not await _walk(point): return
	if not await _open_door("B1_COAL_DOOR"): return
	for point in [Vector3(14.2,-3.2,-6.8),Vector3(12.8,-3.2,-9.5)]:
		if not await _walk(point): return
	await _roof_capture("coal_delivery_overview",Vector3(14.2,-1.8,-11.5))
	if not await _walk(Vector3(12.8,-3.2,-11.2)): return
	await _roof_capture("delivery_chute_and_bunker",Vector3(14.2,-1.5,-11.8))
	# The ray lies along the chute centre line, through the actual partition.
	if not _require(_ray(Vector3(14.2,-.8,-12.6),Vector3(14.2,-1.3,-12.1)).is_empty(),
			"raised delivery aperture is physically open along the gravity run"): return
	if not _require(not _ray(Vector3(14.2,-2.6,-12.6),Vector3(14.2,-2.6,-12.1)).is_empty(),
			"solid wall remains below the delivery aperture"): return
	var cover := _ray(Vector3(14.2,.3,-13.3),Vector3(14.2,-.1,-13.3))
	var bunker := world.adapter.resolve("B1_COAL_BUNKER") as Node3D
	var shell := bunker.find_child("CoalDelivery_metal",true,false) as MeshInstance3D
	if not _require(shell != null,"imported chute shell is present"): return
	for corner in 8:
		var at: Vector3 = bunker.to_local(shell.to_global(shell.get_aabb().get_endpoint(corner)))
		if not _require(at.y <= 3.145,"chute shell stays below the pavement seat"): return
	if not _require(not cover.is_empty() and bunker.is_ancestor_of(cover.collider),
			"closed imported iron cover has matching collision"): return
	for point in [Vector3(12.8,-3.2,-9.5),Vector3(14.2,-3.2,-6.8),Vector3(14.2,-3.2,-3.8),Vector3(10.6,-3.2,-3.8),Vector3(10.6,-3.2,-1.8),Vector3(11.2,-3.2,-1.8),Vector3(11.2,-3.2,-.4),Vector3(8.3,-3.2,-.4)]:
		if not await _walk(point): return
	_require(not player.noclip and player.is_on_floor(),"coal circuit returns through production doors")

func _ray(a: Vector3,b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(a),world.adapter.root.to_global(b),1)
	query.exclude = [player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query)
