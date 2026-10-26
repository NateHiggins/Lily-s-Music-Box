extends Node
## Authoring probe for resident route files: in the production V2 root, every
## node and every 10 cm along every edge must have floor support and room for
## the resident's capsule. Blocked nodes get the nearest clear spot suggested
## in route coordinates (tools/apply_route_probe.py moves them there).
## ROUTE_FILE picks the files, comma-separated (default Lena's); each finding
## is printed with its file.

const CAPSULE_RADIUS := .28
const CAPSULE_HEIGHT := 1.40
const SHARED_DOORS := ["F01_DOOR_06", "F01_WATCH_MAIL_DOOR", "B1_LAUNDRY_DOOR"]
var failures: Array[String] = []
var _open_doors := false
var _file := ""


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 600)
	var files := OS.get_environment("ROUTE_FILE")
	if files == "":
		files = "res://data/orison_v2/lena_routine.json"
	var world: OrisonV2RuntimeRoot = load("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(.5).timeout
	if world.startup_failed:
		failures.append("startup")
	else:
		for file: String in files.split(","):
			_file = file.get_file()
			var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
			_open_doors = false
			_probe(world, source)
			# Then with every door on the route standing open: a leaf swung into
			# the walking line blocks as surely as furniture.
			await _set_doors(world, source, true)
			_open_doors = true
			_probe(world, source)
			await _set_doors(world, source, false)
	for line in failures:
		print("ROUTE PROBE FAIL: ", line)
	print("ROUTE PROBE: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _set_doors(world: OrisonV2RuntimeRoot, source: Dictionary, open: bool) -> void:
	for identity: String in source.doors + SHARED_DOORS:
		var door := world.find_child(identity + "_Leaf", true, false) as DoorProp
		if door != null:
			door.npc_set_open(open, str(source.resident))
	await get_tree().create_timer(2.5).timeout


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
					# A threshold gap under the wall is bridged by the capsule
					# when floor carries on 15 cm either side along the edge.
					var along := (b - a).normalized() * .15
					if why == "no floor" and _blocked(world, space, at - along) != "no floor" \
							and _blocked(world, space, at + along) != "no floor":
						continue
					if why != "":
						var hint := _clear_near(world, space, root, at)
						failures.append("[%s] edge %s -> %s at %d%%: %s; %s" % [_file, previous[0], record[0], i * 100 / steps, why,
								hint.replace("clear at", "detour at") if hint != "" else "no clear spot within 0.8 m"])
						break
			previous = record
	for id: String in nodes:
		var record: Array = nodes[id]
		var at: Vector3 = root.to_global(Vector3(record[1], record[2], record[3]))
		var why := _blocked(world, space, at)
		if why == "":
			continue
		var hint := _clear_near(world, space, root, at)
		failures.append("[%s] node %s: %s; %s" % [_file, id, why, hint if hint != "" else "no clear spot within 0.8 m"])


## The nearest spot within 0.8 m where the capsule stands clear, in route
## coordinates, or "" when there is none.
func _clear_near(world: OrisonV2RuntimeRoot, space: PhysicsDirectSpaceState3D, root: Node3D, at: Vector3) -> String:
	for radius: float in [.15, .3, .45, .6, .8]:
		for k in 16:
			var offset := Vector3(cos(TAU * k / 16.0), 0, sin(TAU * k / 16.0)) * radius
			if _blocked(world, space, at + offset) == "":
				var local := root.to_local(at + offset)
				return "clear at [%.2f, %.2f, %.2f]" % [local.x, local.y, local.z]
	return ""


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
