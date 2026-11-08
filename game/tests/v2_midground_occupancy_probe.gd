extends Node3D
## Survey fixture for the mid-ground batch: starts the production V2 world and
## ray-casts its collision straight down on a 2 m world grid out to 470 m. Writes the
## first-hit height and the owning top-level node for every cell, so new blocks can
## be authored around every existing owner. No campaign, route or save authority.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const LIMIT := 470.0
const STEP := 2.0


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
	if node == null:
		return "outside"
	return "/".join(chain.slice(0, mini(3, chain.size())))


func _run() -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty():
		push_error("MIDGROUND PROBE: SHOT_DIR required")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
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
		push_error("MIDGROUND PROBE: production world did not start")
		get_tree().quit(1)
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := world.get_world_3d().direct_space_state
	var exclude: Array[RID] = [world.player.get_rid()]
	var n := int(2.0 * LIMIT / STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var owners := PackedInt32Array()
	owners.resize(n * n)
	var keys: Array[String] = []
	var index := {}
	for j in n:
		var z := -LIMIT + j * STEP
		for i in n:
			var x := -LIMIT + i * STEP
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x, 250.0, z), Vector3(x, -40.0, z), 0xFFFFFFFF, exclude)
			var hit := space.intersect_ray(ray)
			var cell := j * n + i
			if hit.is_empty():
				heights[cell] = NAN
				owners[cell] = -1
				continue
			heights[cell] = hit.position.y
			var key := _owner_key(world, hit.collider)
			if not index.has(key):
				index[key] = keys.size()
				keys.append(key)
			owners[cell] = index[key]
	var bounds := world.find_child("StreetBoundaries", true, false) as Node3D
	var file := FileAccess.open(output.path_join("occupancy_heights.f32"), FileAccess.WRITE)
	file.store_buffer(heights.to_byte_array())
	file.close()
	file = FileAccess.open(output.path_join("occupancy_owners.i32"), FileAccess.WRITE)
	file.store_buffer(owners.to_byte_array())
	file.close()
	var meta := {"evidence_class": "INERT", "frame": "WORLD", "limit": LIMIT, "step": STEP, "n": n,
		"layout": "row j is z = -limit + j*step, column i is x = -limit + i*step",
		"owners": keys,
		"street_boundaries": str(bounds.global_transform) if bounds else "",
		"player": str(world.player.global_position)}
	file = FileAccess.open(output.path_join("occupancy.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(meta, " "))
	file.close()
	print("MIDGROUND PROBE: %d cells, %d owners" % [n * n, keys.size()])
	get_tree().quit(0)
