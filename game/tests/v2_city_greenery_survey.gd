extends Node3D
## Survey fixture for the city greenery batch (art/blender/scripts/build_city_greenery.py).
## Starts the production V2 world and writes, in the WORLD frame:
## - every pavement, kerb and road surface it can find, as upward-facing triangles in
##   XZ with heights, so planting follows the drawn kerbs (most near-city pavements
##   are drawn without collision of their own);
## - a 1 m grid of first collision hits straight down inside the walkable city, with
##   the owning node path, so planting keeps clear of every post, stoop, door and wall.
## No campaign, route or save authority.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const LIMIT := 220.0
const STEP := 1.0
## Surface words, matched against the draw's name and its surfaces' material names.
const WALK := ["walk", "pavement", "sidewalk", "flag"]
const KERB := ["curb", "kerb"]
const ROAD := ["road", "asphalt", "setts", "cobble", "carriage"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _path(world: Node, node: Node, depth: int) -> String:
	var chain: Array[String] = []
	while node != null and node != world:
		chain.push_front(str(node.name))
		node = node.get_parent()
	if node == null:
		return "outside"
	return "/".join(chain.slice(0, mini(depth, chain.size())))


func _class_of(words: String) -> String:
	var lower := words.to_lower()
	for word in KERB:
		if lower.contains(word): return "kerb"
	for word in WALK:
		if lower.contains(word): return "walk"
	for word in ROAD:
		if lower.contains(word): return "road"
	return ""


func _surfaces(world: Node) -> Array:
	var out: Array = []
	for draw: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if draw.mesh == null or not draw.is_visible_in_tree():
			continue
		var xf := draw.global_transform
		if absf(xf.origin.x) > LIMIT + 40.0 and absf(xf.origin.z) > LIMIT + 40.0:
			continue
		for s in draw.mesh.get_surface_count():
			var material: Material = draw.get_surface_override_material(s)
			if material == null: material = draw.material_override
			if material == null: material = draw.mesh.surface_get_material(s)
			var words := str(draw.name) + " " + (str(material.resource_name) if material else "")
			if material != null and material.has_meta("v2_surface_stock"):
				words += " " + str(material.get_meta("v2_surface_stock"))
			var cls := _class_of(words)
			if cls.is_empty():
				continue
			var arrays := draw.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if index.is_empty():
				index.resize(verts.size())
				for i in verts.size(): index[i] = i
			var tris: Array = []
			for t in range(0, index.size() - 2, 3):
				var a := xf * verts[index[t]]
				var b := xf * verts[index[t + 1]]
				var c := xf * verts[index[t + 2]]
				var normal := (b - a).cross(c - a)
				if normal.length_squared() < 1e-8: continue
				if absf(normal.normalized().y) < 0.8: continue
				if minf(minf(absf(a.x), absf(b.x)), absf(c.x)) > LIMIT or minf(minf(absf(a.z), absf(b.z)), absf(c.z)) > LIMIT:
					continue
				tris.append([snappedf(a.x, 0.01), snappedf(a.y, 0.01), snappedf(a.z, 0.01),
					snappedf(b.x, 0.01), snappedf(b.y, 0.01), snappedf(b.z, 0.01),
					snappedf(c.x, 0.01), snappedf(c.y, 0.01), snappedf(c.z, 0.01)])
			if not tris.is_empty():
				out.append({"class": cls, "path": _path(world, draw, 6), "words": words.left(120), "tris": tris})
	return out


## Small collision footprints (posts, hydrants, boxes, signs) the 1 m grid can miss, and
## the street lamps' flames, so crowns keep off the lamp heads.
func _fixtures(world: Node) -> Dictionary:
	var small: Array = []
	for shape: CollisionShape3D in world.find_children("*", "CollisionShape3D", true, false):
		if shape.shape == null or shape.disabled:
			continue
		var xf := shape.global_transform
		var at := xf.origin
		if absf(at.x) > LIMIT or absf(at.z) > LIMIT:
			continue
		var radius := -1.0
		var height := 0.0
		if shape.shape is CylinderShape3D:
			radius = (shape.shape as CylinderShape3D).radius
			height = (shape.shape as CylinderShape3D).height
		elif shape.shape is CapsuleShape3D:
			radius = (shape.shape as CapsuleShape3D).radius
			height = (shape.shape as CapsuleShape3D).height
		elif shape.shape is BoxShape3D:
			var size := (shape.shape as BoxShape3D).size * xf.basis.get_scale()
			if maxf(size.x, size.z) <= 1.6:
				radius = 0.5 * Vector2(size.x, size.z).length()
				height = size.y
		if radius > 0.0 and radius <= 1.0:
			small.append([snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01), snappedf(radius, 0.01), snappedf(height, 0.01), _path(world, shape, 4)])
	var lamps: Array = []
	for light: Light3D in world.find_children("*", "Light3D", true, false):
		var path := _path(world, light, 6)
		if not path.to_lower().contains("lamp"):
			continue
		var at := light.global_position
		if absf(at.x) <= LIMIT and absf(at.z) <= LIMIT:
			lamps.append([snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01), path])
	return {"small_colliders": small, "lamp_lights": lamps}


func _run() -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty():
		push_error("GREENERY SURVEY: SHOT_DIR required")
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
		push_error("GREENERY SURVEY: production world did not start")
		get_tree().quit(1)
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var surfaces := _surfaces(world)
	var fixtures := _fixtures(world)
	var space := world.get_world_3d().direct_space_state
	var exclude: Array[RID] = [world.player.get_rid()]
	var n := int(2.0 * LIMIT / STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var owners := PackedInt32Array()
	owners.resize(n * n)
	var keys: Array[String] = []
	var lookup := {}
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
			var key := _path(world, hit.collider as Node, 4) if hit.collider is Node else "?"
			if not lookup.has(key):
				lookup[key] = keys.size()
				keys.append(key)
			owners[cell] = lookup[key]
	var file := FileAccess.open(output.path_join("heights.f32"), FileAccess.WRITE)
	file.store_buffer(heights.to_byte_array())
	file.close()
	file = FileAccess.open(output.path_join("owners.i32"), FileAccess.WRITE)
	file.store_buffer(owners.to_byte_array())
	file.close()
	var meta := {"evidence_class": "INERT", "frame": "WORLD", "limit": LIMIT, "step": STEP, "n": n,
		"layout": "row j is z = -limit + j*step, column i is x = -limit + i*step",
		"owners": keys, "player": [world.player.global_position.x, world.player.global_position.y, world.player.global_position.z]}
	file = FileAccess.open(output.path_join("survey.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(meta, " "))
	file.close()
	file = FileAccess.open(output.path_join("surfaces.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(surfaces))
	file.close()
	file = FileAccess.open(output.path_join("fixtures.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(fixtures))
	file.close()
	print("GREENERY SURVEY: %d small colliders, %d lamp lights" % [(fixtures.small_colliders as Array).size(), (fixtures.lamp_lights as Array).size()])
	var counts := {}
	for entry: Dictionary in surfaces:
		counts[entry["class"]] = int(counts.get(entry["class"], 0)) + (entry.tris as Array).size()
	print("GREENERY SURVEY: %d cells, %d owners, surface triangles %s" % [n * n, keys.size(), counts])
	world.shutdown_for_tests()
	get_tree().quit(0)
