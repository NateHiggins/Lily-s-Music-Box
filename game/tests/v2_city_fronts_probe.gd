extends Node3D
## Survey fixture for the near city's building fronts (Lily's ruling city_next_batch_20261117): starts the production
## V2 world and judges each candidate in $FRONTS_CANDIDATES. A wall piece (awning, signboard, wall advert, fire escape)
## needs a wall within WALL_M behind it and its own volume in front clear of everything but that wall; a roof piece
## (billboard, roof tank) needs a roof under it, takes that roof's height, and needs its volume clear. Writes
## accepted.json to SHOT_DIR with each refusal's reason. No campaign, route or save authority.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const WALL_M := 0.6


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
	var source := OS.get_environment("FRONTS_CANDIDATES")
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
	if world.startup_failed:
		get_tree().quit(1)
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := world.get_world_3d().direct_space_state
	var exclude: Array[RID] = [world.player.get_rid()]
	var accepted := {}
	var refused: Array = []
	for kind: String in candidates["items"]:
		accepted[kind] = []
		for item: Dictionary in candidates["items"][kind]:
			var verdict := _judge(space, world, exclude, kind, item)
			if verdict.is_empty():
				accepted[kind].append(item)
			else:
				refused.append(verdict)
	var counts := {}
	for kind: String in accepted:
		counts[kind] = (accepted[kind] as Array).size()
	var file := FileAccess.open(output.path_join("accepted.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class": "INERT", "copy": candidates.get("copy", {}), "items": accepted, "refused": refused}, "\t"))
	file.close()
	print("FRONTS PROBE accepted ", counts, " refused ", refused.size())
	get_tree().quit(0)


func _clear(space: PhysicsDirectSpaceState3D, world: Node, exclude: Array[RID], centre: Vector3, size: Vector3, yaw: float, skip: RID, host := "") -> Array:
	var box := BoxShape3D.new()
	box.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis(Vector3.UP, yaw), centre)
	query.collide_with_areas = true
	var skipped: Array[RID] = exclude.duplicate()
	skipped.append(skip)
	query.exclude = skipped
	var names: Array = []
	for h: Dictionary in space.intersect_shape(query, 8):
		var key := _owner_key(world, h.collider)
		if not host.is_empty() and key.begins_with("CityShells/city_elevations/" + host + "__"):
			continue
		names.append(key)
	return names


func _judge(space: PhysicsDirectSpaceState3D, world: Node, exclude: Array[RID], kind: String, item: Dictionary) -> Dictionary:
	var at := Vector3(float(item.at[0]), float(item.at[1]), float(item.at[2]))
	var yaw := float(item.yaw)
	var out := Vector3(sin(yaw), 0.0, cos(yaw))
	if kind in ["billboard", "roof_tank"]:
		var along := Vector3(cos(yaw), 0.0, -sin(yaw))
		var last := {}
		for shift: Vector2 in [Vector2.ZERO, Vector2(3, 0), Vector2(-3, 0), Vector2(0, -3), Vector2(6, 0), Vector2(-6, 0), Vector2(3, -3), Vector2(-3, -3), Vector2(0, -6)]:
			var spot := at + along * shift.x + out * shift.y
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 8.0, spot + Vector3.DOWN * 4.0, 0xFFFFFFFF, exclude))
			if down.is_empty() or absf(float(down.position.y) - at.y) > 2.5:
				last = {"kind": kind, "at": item.at, "why": "no roof underfoot near its height"}
				continue
			var top := float(down.position.y)
			var size := Vector3(7.6, 4.4, 2.0) if kind == "billboard" else Vector3(3.2, 4.0, 3.2)
			var hits := _clear(space, world, exclude, Vector3(spot.x, top + size.y * 0.5 + 0.15, spot.z) - out * 0.8, size, yaw, down.rid)
			if hits.is_empty():
				item.at = [snappedf(spot.x, 0.001), snappedf(top, 0.001), snappedf(spot.z, 0.001)]
				return {}
			last = {"kind": kind, "at": item.at, "why": "occupied", "by": hits}
		return last
	# A wall piece: the wall must stand just behind it.
	var probe_y := at.y if kind != "fire_escape" else float(item.levels[0]) + 0.5
	var from := Vector3(at.x, probe_y, at.z) + out * 0.8
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - out * (0.8 + WALL_M), 0xFFFFFFFF, exclude))
	if wall.is_empty():
		return {"kind": kind, "at": item.at, "why": "no wall behind it"}
	var w := float(item.get("width", 1.0))
	var size := Vector3(w, 0.6, 0.6)
	var centre := at + out * 0.45
	match kind:
		"awning":
			size = Vector3(w, 0.75, float(item.project))
			centre = Vector3(at.x, at.y - 0.4, at.z) + out * (float(item.project) * 0.5 + 0.08)
		"signboard":
			size = Vector3(w, float(item.height), 0.12)
			centre = at + out * 0.12
		"wall_advert":
			size = Vector3(w, float(item.height), 0.05)
			centre = at + out * 0.08
		"fire_escape":
			var lo := float(item.levels[0]) - 0.5
			var hi := float(item.levels[-1]) + 1.0
			size = Vector3(w, hi - lo, float(item.depth))
			centre = Vector3(at.x, (lo + hi) * 0.5, at.z) + out * (float(item.depth) * 0.5 + 0.1)
	var hits := _clear(space, world, exclude, centre, size, yaw, wall.rid, str(item.get("building", "")))
	return {} if hits.is_empty() else {"kind": kind, "at": item.at, "why": "occupied", "by": hits}
