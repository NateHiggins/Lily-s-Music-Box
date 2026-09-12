extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Prepared while engine use is paused. One initial F04 placement; all door
## opening and subsequent passage use the ordinary controller and input ray.

func _init() -> void:
	route_label = "4B DOOR ROUTE"

func _route() -> void:
	player.global_position = world.adapter.root.to_global(Vector3(-4.65, 9.62, 0))
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var entry := _leaf("F04_DOOR_03")
	if not _require(entry != null and entry.door_kind == "apartment_entry"
			and entry.unit == "4B" and entry.is_in_group("apartment_doors"),
			"4B entry has its production subtype and apartment identity"): return
	if not await _open_door("F04_DOOR_03"): return
	for point in [Vector3(-6.65, 9.6, 0), Vector3(-8.3, 9.6, 0),
			Vector3(-10.8, 9.6, 0), Vector3(-10.8, 9.6, 2.25),
			Vector3(-10.05, 9.6, 2.25)]:
		if not await _walk(point): return
	if not await _open_door("F04_B_HALL_DOOR"): return
	for point in [Vector3(-10.05, 9.6, 4.0), Vector3(-10.5, 9.6, 4.75)]:
		if not await _walk(point): return
	if not await _open_door("F04_B_BATH_DOOR"): return
	for point in [Vector3(-7.9, 9.6, 4.75), Vector3(-10.5, 9.6, 4.75)]:
		if not await _walk(point): return
	# The open bathroom leaf projects into the private hall. Close it from a
	# stance outside its sweep before testing the return path down that hall.
	if not await _close_door("F04_B_BATH_DOOR"): return
	for point in [Vector3(-9.8, 9.6, 5.5), Vector3(-9.8, 9.6, 7.25),
			Vector3(-8.8, 9.6, 7.25)]:
		if not await _walk(point): return
	if not await _open_door("F04_B_CLOSET_DOOR"): return
	for point in [Vector3(-6.95, 9.6, 7.25), Vector3(-9.8, 9.6, 7.25),
			Vector3(-10.05, 9.6, 5.5), Vector3(-10.05, 9.6, 2.25),
			Vector3(-10.8, 9.6, 2.25), Vector3(-10.8, 9.6, 0),
			Vector3(-8.3, 9.6, 0), Vector3(-6.65, 9.6, 0),
			Vector3(-4.65, 9.6, 0)]:
		if not await _walk(point): return
	if not await _close_door("F04_DOOR_03"): return
	var entry_body := entry.get_node("HingedLeaf") as AnimatableBody3D
	var closed_ray := PhysicsRayQueryParameters3D.create(
			world.adapter.root.to_global(Vector3(-4.65, 10.7, 0)),
			world.adapter.root.to_global(Vector3(-6.65, 10.7, 0)), 1)
	closed_ray.exclude = [player.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(closed_ray)
	_require(hit.get("collider") == entry_body, "closed entry restores its solid barrier")
	_require(not player.noclip and player.collision_mask == 1
			and player.is_physics_processing(), "ordinary collision remains active after returning to public hall")

func _leaf(identity: String) -> DoorProp:
	var opening := world.adapter.resolve(identity) as Node3D
	if opening == null: return null
	return opening.get_node_or_null(identity + "_Leaf") as DoorProp

func _open_door(identity: String) -> bool:
	var door := _leaf(identity)
	if not _require(door != null, "production leaf exists: " + identity): return false
	if not _require(not door.open and door.leaf_state == "closed",
			"leaf starts closed and usable: " + identity): return false
	if not await _use(door, door.to_global(Vector3(door.width * .5, 1.1, 0)), identity): return false
	await get_tree().create_timer(.6).timeout
	var body := door.get_node_or_null("HingedLeaf") as AnimatableBody3D
	return _require(door.open and body != null
			and absf(body.rotation.y - deg_to_rad(-100.0 if door.swing_out else 100.0)) < .01,
			"input opens physical leaf to its stop: " + identity)

func _close_door(identity: String) -> bool:
	var door := _leaf(identity)
	if not _require(door != null and door.open, "open leaf ready to close: " + identity): return false
	var body := door.get_node("HingedLeaf") as AnimatableBody3D
	if not await _use(door, body.to_global(Vector3(door.width * .5, 1.1, 0)), identity + "_close"): return false
	await get_tree().create_timer(.6).timeout
	return _require(not door.open and absf(body.rotation.y) < .01,
			"input closes physical leaf: " + identity)
