extends Node3D
## Survey fixture for the near city's street furniture (Lily's ruling city_complete_next_20261117): starts the
## production V2 world and, for every candidate in $NEAR_CANDIDATES, accepts it only when the walk is underfoot at
## its height and nothing else (a collider, a door's swing area, a trigger) lies within CLEAR_M of its footprint.
## Writes accepted.json to SHOT_DIR with each refusal's reason. No campaign, route or save authority.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const CLEAR_M := 0.5
const SIZES := {"hydrant": Vector3(0.4, 0.8, 0.4), "mailbox": Vector3(0.5, 1.5, 0.5), "callbox": Vector3(0.4, 1.7, 0.4),
	"ashcan": Vector3(0.6, 0.8, 0.6), "telegraph_pole": Vector3(0.35, 9.0, 0.35), "signpost": Vector3(0.3, 3.6, 0.3)}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _owner_key(world: Node, collider: Object) -> String:
	if not (collider is Node):
		return "?"
	var node := collider as Node
	var chain: Array[String] = []
	while node != null and node != world:
		chain.push_front(str(node.name))
		node = node.get_parent()
	return "/".join(chain.slice(0, mini(4, chain.size()))) if node != null else "outside"


func _run() -> void:
	var output := OS.get_environment("SHOT_DIR")
	var source := OS.get_environment("NEAR_CANDIDATES")
	if output.is_empty() or source.is_empty():
		push_error("NEAR FURNITURE PROBE: SHOT_DIR and NEAR_CANDIDATES required")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var candidates: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled = false
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	while world.startup_ms <= 0.0 and not world.startup_failed:
		await get_tree().process_frame
	if world.startup_failed or world.player == null:
		push_error("NEAR FURNITURE PROBE: production world did not start")
		get_tree().quit(1)
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := world.get_world_3d().direct_space_state
	var exclude: Array[RID] = [world.player.get_rid()]
	# Re-survey the candidate locations against the other production owners.
	for body: StaticBody3D in world.get_node("CityNearFurniture").find_children("*", "StaticBody3D", true, false):
		exclude.append(body.get_rid())
	var accepted := {}
	var refused: Array = []
	for kind: String in candidates["items"]:
		accepted[kind] = []
		var size: Vector3 = SIZES.get(kind, Vector3(0.5, 1.5, 0.5))
		for source_item: Array in candidates["items"][kind]:
			# A pole refused where it stands may slide along the kerb (its yaw faces the road, so the kerb runs along
			# local x) by up to 4 m, keeping its wires' spans short; other kinds stay where the rules put them.
			var shifts: Array = [0.0, 2.0, -2.0, 4.0, -4.0] if kind == "telegraph_pole" else [0.0]
			var verdict := {}
			for shift: float in shifts:
				var yaw := float(source_item[3])
				var item: Array = [float(source_item[0]) + cos(yaw) * shift, float(source_item[1]), float(source_item[2]) - sin(yaw) * shift, yaw]
				verdict = _judge(space, world, exclude, kind, item, size)
				if verdict.is_empty():
					accepted[kind].append(item)
					break
			if not verdict.is_empty():
				refused.append(verdict)
	_write(output, accepted, refused)


func _judge(space: PhysicsDirectSpaceState3D, world: Node, exclude: Array[RID], kind: String, item: Array, size: Vector3) -> Dictionary:
	var at := Vector3(float(item[0]), float(item[1]), float(item[2]))
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 1.0, 0xFFFFFFFF, exclude)
	var floor_hit := space.intersect_ray(ray)
	if floor_hit.is_empty():
		return {"kind": kind, "at": item, "why": "nothing underfoot"}
	var under := _owner_key(world, floor_hit.collider)
	if absf(float(floor_hit.position.y) - at.y) > 0.15:
		return {"kind": kind, "at": item, "why": "first hit above or below the walk: %s at %.2f" % [under, floor_hit.position.y]}
	var box := BoxShape3D.new()
	box.size = Vector3(size.x + 2.0 * CLEAR_M, size.y - 0.1, size.z + 2.0 * CLEAR_M)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis(), at + Vector3.UP * (size.y * 0.5 + 0.1))
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = exclude + [floor_hit.rid]
	var hits := space.intersect_shape(query, 8)
	# The street's own surfaces (walk, curb and cap) are ground, not obstacles: the margin reaches the kerb.
	hits = hits.filter(func(h: Dictionary) -> bool: return not _owner_key(world, h.collider).begins_with("CityShells/ContinuousStreetBlock"))
	if not hits.is_empty():
		var names: Array = []
		for h: Dictionary in hits:
			names.append(_owner_key(world, h.collider))
		return {"kind": kind, "at": item, "why": "occupied", "by": names}
	return {}


func _write(output: String, accepted: Dictionary, refused: Array) -> void:
	var counts := {}
	for kind: String in accepted:
		counts[kind] = (accepted[kind] as Array).size()
	var file := FileAccess.open(output.path_join("accepted.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class": "INERT", "clear_m": CLEAR_M, "items": accepted, "refused": refused}, "\t"))
	file.close()
	print("NEAR FURNITURE PROBE accepted ", counts, " refused ", refused.size())
	get_tree().quit(0)
