extends Node
## Authoring probe for a resident route file: in the production V2 root, every
## node and every 10 cm along every edge must have floor support and room for
## the resident's capsule. Blocked nodes get the nearest clear spot suggested
## in route coordinates. ROUTE_FILE picks the file (default Lena's).

const CAPSULE_RADIUS := .28
const CAPSULE_HEIGHT := 1.40
var failures: Array[String] = []
var _open_doors := false


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 600)
	var file := OS.get_environment("ROUTE_FILE")
	if file == "":
		file = "res://data/orison_v2/lena_routine.json"
	var world: OrisonV2RuntimeRoot = load("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(.5).timeout
	if world.startup_failed:
		failures.append("startup")
	else:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
		_probe(world, source)
		# Then with every door on the route standing open: a leaf swung into
		# the walking line blocks as surely as furniture.
		for identity: String in source.doors + ["F01_DOOR_06", "F01_WATCH_MAIL_DOOR", "B1_LAUNDRY_DOOR"]:
			var door := world.find_child(identity + "_Leaf", true, false) as DoorProp
			if door != null:
				door.npc_set_open(true, str(source.resident))
		await get_tree().create_timer(2.5).timeout
		_open_doors = true
		_probe(world, source)
	for line in failures:
		print("ROUTE PROBE FAIL: ", line)
	print("ROUTE PROBE: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _probe(world: OrisonV2RuntimeRoot, source: Dictionary) -> void:
	var space := world.get_world_3d().direct_space_state
	var root: Node3D = world.adapter.root
	var nodes := {}
	for route: Array in source.paths:
		var previous: Array = []
		for record: Array in route:
			nodes[str(record[0])] = record
			if not previous.is_empty():
				var a: Vector3 = root.to_global(Vector3(previous[1], previous[2], previous[3]))
				var b: Vector3 = root.to_global(Vector3(record[1], record[2], record[3]))
				var steps := maxi(1, ceili(a.distance_to(b) / .1))
				for i in range(1, steps):
					var at := a.lerp(b, float(i) / steps)
					# Stairs are walked on their treads; judge only flat edges here.
					if absf(b.y - a.y) > .05:
						break
					var why := _blocked(world, space, at)
					if why != "":
						failures.append("edge %s -> %s at %d%%: %s" % [previous[0], record[0], i * 100 / steps, why])
						break
			previous = record
	for id: String in nodes:
		var record: Array = nodes[id]
		var at: Vector3 = root.to_global(Vector3(record[1], record[2], record[3]))
		var why := _blocked(world, space, at)
		if why == "":
			continue
		var hint := ""
		for radius: float in [.15, .3, .45, .6, .8]:
			for k in 16:
				var offset := Vector3(cos(TAU * k / 16.0), 0, sin(TAU * k / 16.0)) * radius
				if _blocked(world, space, at + offset) == "":
					var local := root.to_local(at + offset)
					hint = "clear at [%.2f, %.2f, %.2f]" % [local.x, local.y, local.z]
					break
			if hint != "":
				break
		failures.append("node %s: %s; %s" % [id, why, hint if hint != "" else "no clear spot within 0.8 m"])


func _blocked(world: OrisonV2RuntimeRoot, space: PhysicsDirectSpaceState3D, at: Vector3) -> String:
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * .34, at - Vector3.UP * .5, 1)
	var floor_hit := space.intersect_ray(ray)
	if floor_hit.is_empty() or floor_hit.normal.y < .45:
		return "no floor"
	var shape := CapsuleShape3D.new()
	shape.radius = CAPSULE_RADIUS
	shape.height = CAPSULE_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.transform.origin = Vector3(at.x, floor_hit.position.y, at.z) + Vector3.UP * (.25 + CAPSULE_HEIGHT * .5)
	query.exclude = [world.player.get_rid()]
	# A closed leaf is the route owner's to open; with the doors open, the
	# open leaves count.
	for hit: Dictionary in space.intersect_shape(query, 8):
		var node: Node = hit.collider
		var door: DoorProp = null
		while node != null:
			if node is DoorProp:
				door = node
				break
			node = node.get_parent()
		if door == null or (_open_doors and door.open):
			return "blocked by %s (%s)%s" % [hit.collider.name, hit.collider.get_parent().name,
					" open" if door != null else ""]
	return ""
