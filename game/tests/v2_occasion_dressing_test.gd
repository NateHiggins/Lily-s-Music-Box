extends Node
## The house dressed for the year's occasions (evidence wall and seasons plan,
## section 5, layer 3). The runtime root does not call the composer yet, so
## this test mounts it onto the booted world itself, exactly as the root will,
## then dresses the house for every name in the calendar and checks that each
## occasion shows its own placements and no others, that each shown piece sits
## against a real wall or on a real support in the room its row names, and
## that every surface is Blender stock on a catalogue finish.
const Dressing := preload("res://scripts/building/orison_v2_occasion_dressing.gd")
const CALENDAR := "res://data/temporal/anchors.json"
const CAPTURED := ["Christmas", "Independence Day", "Hallowe'en", "Armistice Day", ""]
## Standing views in the blockout's plan coordinates: eye, then target.
const VIEWS := [
	["entrance", Vector3(1.3, 1.6, -16.4), Vector3(0.0, 1.9, -12.0)],
	["entrance_near", Vector3(-1.6, 1.6, -14.4), Vector3(0.4, 1.7, -11.7)],
	["lobby_door_wall", Vector3(1.2, 1.6, -5.0), Vector3(-0.6, 1.7, -9.25)],
	["lobby_desk", Vector3(0.6, 1.6, -7.6), Vector3(-3.4, 1.3, -3.6)],
]

var _fails := 0
var _checks := 0
var _world: Node
var _blockout: Node3D
var _eye := Vector3.ZERO
var _target := Vector3.ZERO
var _holding := false


class Stand extends Node:
	## Keeps the player at the viewpoint: the building lights rooms round the
	## player, and the V2 opening moves the player after startup.
	var test: Node
	func _process(_delta: float) -> void:
		if not test._holding or not is_instance_valid(test._world) or test._world.player == null:
			return
		var player: Node3D = test._world.player
		player.global_position += test._eye - player.camera.global_position
		player.camera.look_at(test._target)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(_world)
	while not _world.startup_failed and _world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not _world.startup_failed, "the V2 world starts")
	if _world.startup_failed:
		_finish()
		return
	_blockout = _world._blockout
	await _settle()

	var dressing: Node3D = Dressing.mount(_world, _blockout, _world.layout, _world.adapter)
	_check(dressing != null and dressing.errors.is_empty(), "the composer mounts without errors (%s)" % [dressing.errors])
	_check(dressing.get_parent() == _blockout, "the dressing lies in the blockout's own frame")
	_check(dressing.dressed() == "", "the house starts undressed")
	var placed: Dictionary = dressing.placements()
	_check(placed.size() >= 12, "placements are built (%d)" % placed.size())
	for id: String in placed:
		_check(not (placed[id] as Node3D).visible, "%s is built hidden" % id)
	for i in 3:
		await get_tree().physics_frame

	# Every name in the year's calendar has its dressing, under the calendar's own spelling.
	var anchors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CALENDAR))
	var names: Array[String] = []
	for day: Dictionary in anchors.calendar:
		names.append(str(day.name))
	_check(names.size() == 17, "the calendar holds seventeen occasions (%d)" % names.size())
	for occasion: String in names:
		_check(dressing.occasions().has(occasion), "%s has an entry" % occasion)
	_check(dressing.occasions().size() == names.size(), "the table holds no occasion the calendar lacks")

	var spaces: Dictionary = {}
	for space: Dictionary in _world.layout.spaces:
		spaces[str(space.id)] = space
	var floors: Dictionary = {}
	for level: Dictionary in _world.layout.levels:
		floors[str(level.id)] = float(level.y)
	var most_draws := 0
	var most_triangles := 0
	var seen: Dictionary = {}
	for occasion: String in names:
		dressing.dress(occasion)
		_check(dressing.dressed() == occasion, "%s: the house reports it" % occasion)
		var own: Array = dressing.pieces_for(occasion)
		_check(own.size() >= 1 and own.size() <= 6, "%s shows one to six placements (%d)" % [occasion, own.size()])
		var draws := 0
		var triangles := 0
		for id: String in placed:
			var piece: Node3D = placed[id]
			_check(piece.is_visible_in_tree() == own.has(piece), "%s: %s is %s" % [occasion, id, "shown" if own.has(piece) else "hidden"])
			if not own.has(piece):
				continue
			var cost := _cost(piece)
			draws += cost.x
			triangles += cost.y
			if seen.has(id):
				continue
			seen[id] = true
			_check_seat(piece, id, spaces, floors)
		most_draws = maxi(most_draws, draws)
		most_triangles = maxi(most_triangles, triangles)
		print("[V2 OCCASION DRESSING] %s: %d placements, %d draws, %d triangles" % [occasion, own.size(), draws, triangles])
	_check(seen.size() == placed.size(), "every placement is used by some occasion (%d of %d)" % [seen.size(), placed.size()])

	# Calling it again with the same name does nothing at all.
	dressing.dress("Christmas")
	var probe: Node3D = dressing.pieces_for("Christmas")[0]
	probe.visible = false
	dressing.dress("Christmas")
	_check(not probe.visible, "dressing again for the same occasion touches nothing")
	probe.visible = true
	var before := Time.get_ticks_usec()
	for i in 10000:
		dressing.dress("Christmas")
	var spent := Time.get_ticks_usec() - before
	_check(spent < 20000, "ten thousand unchanged calls cost %.2f ms" % (spent / 1000.0))
	# An occasion and its neighbour share the flag: it stays up across the change.
	dressing.dress("Flag Day")
	var shared: Array = []
	for piece: Node3D in dressing.pieces_for("Flag Day"):
		if dressing.pieces_for("Independence Day").has(piece):
			shared.append(piece)
	dressing.dress("Independence Day")
	for piece: Node3D in shared:
		_check(piece.visible, "%s stays up from Flag Day to Independence Day" % piece.name)
	dressing.dress("no such day")
	_check(dressing.dressed() == "", "a name the table does not hold undresses the house")
	dressing.dress("Christmas")
	dressing.dress("")
	_check(dressing.dressed() == "", "the house reports itself undressed")
	for id: String in placed:
		_check(not (placed[id] as Node3D).visible, "undressed: %s is hidden" % id)

	var totals := _check_surfaces(placed)
	print("[V2 OCCASION DRESSING] built %d placements: %d draws, %d triangles in all; the fullest occasion shows %d draws, %d triangles" % [
			placed.size(), totals.x, totals.y, most_draws, most_triangles])
	await _capture(dressing, names)
	_finish()


## The world keeps loading for some seconds after it reports ready.
func _settle() -> void:
	var calm := 0
	var guard := 0
	while calm < 60 and guard < 3000:
		var before := Time.get_ticks_usec()
		await get_tree().process_frame
		calm = calm + 1 if Time.get_ticks_usec() - before < 250000 else 0
		guard += 1
	for i in 3:
		await get_tree().physics_frame


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0xFFFFFFFF
	if _world.player != null:
		query.exclude = [_world.player.get_rid()]
	return get_viewport().world_3d.direct_space_state.intersect_ray(query)


## Bounds of every mesh under `node`, in `frame`'s local space.
func _extent(frame: Node3D, node: Node) -> AABB:
	var found := false
	var result := AABB()
	var inverse := frame.global_transform.affine_inverse()
	for draw: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (inverse * draw.global_transform) * draw.get_aabb()
		result = box if not found else result.merge(box)
		found = true
	return result


func _cost(piece: Node3D) -> Vector2i:
	var draws := 0
	var triangles := 0
	for draw: MeshInstance3D in piece.find_children("*", "MeshInstance3D", true, false):
		draws += 1
		var arrays := draw.mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		triangles += (indices.size() if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return Vector2i(draws, triangles)


## A shown piece sits against its wall (or the leaf it hangs on) or stands on
## its support, in the room and on the level its row names.
func _check_seat(piece: Node3D, id: String, spaces: Dictionary, floors: Dictionary) -> void:
	var rest := str(piece.get_meta("occasion_rest", ""))
	var box := _extent(piece, piece)
	var frame := piece.global_transform
	var out := Vector3.ZERO
	if rest == "wall" or rest == "leaf":
		# Across its span, at its own fixing height: the wall face is the piece's z = 0.
		var xs: Array[float] = [0.0]
		if box.size.x > 0.5:
			xs = [box.position.x + 0.03, 0.0, box.end.x - 0.03]
		for x: float in xs:
			var hit := _ray(frame * Vector3(x, -0.01, 0.30), frame * Vector3(x, -0.01, -0.30))
			var depth := 9.0 if hit.is_empty() else (frame.affine_inverse() * (hit.position as Vector3)).z
			var body := "nothing" if hit.is_empty() else str((hit.collider as Node).name)
			_check(absf(depth) < 0.012, "%s: construction stands behind it at x %.2f (%s at %.3f m)" % [id, x, body, depth])
		_check(box.position.z > -0.004, "%s: nothing of it is sunk in the wall (%.3f m)" % [id, box.position.z])
		_check(box.position.z < 0.012, "%s: it touches the wall (%.3f m)" % [id, box.position.z])
		if rest == "leaf":
			_check(piece.get_parent() is AnimatableBody3D, "%s rides the leaf it hangs on" % id)
		out = Vector3(0.0, 0.0, 0.25)
	elif rest == "support":
		var hit := _ray(frame * Vector3(0.0, 0.30, 0.0), frame * Vector3(0.0, -0.30, 0.0))
		var height := 9.0 if hit.is_empty() else (frame.affine_inverse() * (hit.position as Vector3)).y
		var body := "nothing" if hit.is_empty() else str((hit.collider as Node).name)
		_check(absf(height) < 0.012, "%s: it stands on a support (%s at %.3f m)" % [id, body, height])
		_check(absf(box.position.y) < 0.006, "%s: its base is at its seat (%.3f m)" % [id, box.position.y])
		# The whole foot is carried, not just the middle.
		var reach := minf(box.size.x, box.size.z) * 0.2
		for corner: Vector2 in [Vector2(reach, 0), Vector2(-reach, 0), Vector2(0, reach), Vector2(0, -reach)]:
			var under := _ray(frame * Vector3(corner.x, 0.30, corner.y), frame * Vector3(corner.x, -0.30, corner.y))
			var level := 9.0 if under.is_empty() else (frame.affine_inverse() * (under.position as Vector3)).y
			_check(absf(level) < 0.012, "%s: its foot is carried at (%.2f, %.2f) (%.3f m)" % [id, corner.x, corner.y, level])
		out = Vector3(0.0, 0.10, 0.0)
	else:
		_check(false, "%s names a rest the test knows (%s)" % [id, rest])
	var space_id := str(piece.get_meta("occasion_space", ""))
	var level_id := str(piece.get_meta("occasion_level", ""))
	_check(spaces.has(space_id) and floors.has(level_id), "%s names a real room and level (%s, %s)" % [id, space_id, level_id])
	if not spaces.has(space_id) or not floors.has(level_id):
		return
	var at: Vector3 = _blockout.global_transform.affine_inverse() * (frame * out)
	var rect: Array = spaces[space_id].rect
	_check(at.x > float(rect[0]) and at.x < float(rect[2]) and at.z > float(rect[1]) and at.z < float(rect[3]),
			"%s is in %s (%.2f, %.2f)" % [id, space_id, at.x, at.z])
	_check(str(spaces[space_id].level) == level_id and at.y > float(floors[level_id]) - 0.05 and at.y < float(floors[level_id]) + 3.2,
			"%s is on %s (%.2f m)" % [id, level_id, at.y])


## Every drawn surface: Blender stock with authored UVs and tangents on a
## duplicated catalogue finish that samples its own chart with mipmaps.
func _check_surfaces(placed: Dictionary) -> Vector2i:
	var draws := 0
	var triangles := 0
	var maps: Dictionary = {}
	for id: String in placed:
		var piece: Node3D = placed[id]
		for node: Node in piece.find_children("*", "", true, false):
			if node is OmniLight3D:
				var flame := node as OmniLight3D
				_check(not flame.shadow_enabled and flame.omni_range <= 1.5 and flame.light_color.r > flame.light_color.b,
						"%s: the candle is a small warm light without shadows" % id)
				continue
			_check(node is MeshInstance3D, "%s/%s is a mesh" % [id, node.name])
			if node is not MeshInstance3D:
				continue
			var draw := node as MeshInstance3D
			var named := "%s/%s" % [id, draw.name]
			draws += 1
			_check(draw.mesh is ArrayMesh and draw.mesh.get_surface_count() == 1, "%s is one surface of Blender stock" % named)
			_check(draw.visibility_range_end >= 8.0 and draw.visibility_range_end <= 40.0, "%s has a visibility range (%.0f m)" % [named, draw.visibility_range_end])
			_check(draw.get_child_count() == 0, "%s carries no collision" % named)
			var arrays := draw.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			_check(uvs.size() == vertices.size() and uvs.size() > 0, "%s has authored UVs" % named)
			_check(tangents.size() == vertices.size() * 4, "%s has tangents" % named)
			var key := str(draw.get_meta("material_key", ""))
			var finish := draw.material_override as StandardMaterial3D
			_check(MatLib.SETS.has(key) and finish != null, "%s wears a registered catalogue finish (%s)" % [named, key])
			if finish == null or not MatLib.SETS.has(key):
				continue
			var catalogue := MatLib.get_mat(key) as StandardMaterial3D
			_check(finish != catalogue and finish.albedo_texture == catalogue.albedo_texture and finish.roughness_texture == catalogue.roughness_texture
					and finish.normal_texture == catalogue.normal_texture, "%s is a duplicate of the catalogue's %s" % [named, key])
			_check(finish.albedo_texture != null and finish.roughness_texture != null and finish.normal_texture != null and finish.normal_enabled,
					"%s has albedo, roughness and normal maps" % named)
			_check(not finish.uv1_triplanar, "%s uses its authored chart, not triplanar" % named)
			_check(finish.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, "%s samples with mipmaps" % named)
			for map: Texture2D in [finish.albedo_texture, finish.roughness_texture, finish.normal_texture]:
				if map != null:
					maps[map.resource_path] = map
	for path: String in maps:
		var image := (maps[path] as Texture2D).get_image()
		_check(path.begins_with("res://assets/building/textures/") and image != null and image.has_mipmaps(),
				"%s is a catalogue map with its mip chain" % path.get_file())
	return Vector2i(draws, triangles)


func _capture(dressing: Node3D, names: Array[String]) -> void:
	var out := OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(out)
	for layer in _world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	_world.player.set_physics_process(false)
	_world.player.set_lamp_enabled(false)
	if _world.service_set_carrier != null:
		_world.service_set_carrier.visible = false
	var stand := Stand.new()
	stand.test = self
	stand.process_priority = 1000
	add_child(stand)
	var plan := _blockout.global_transform
	for occasion: String in CAPTURED:
		dressing.dress(occasion)
		var tag := "undressed" if occasion == "" else occasion.to_lower().replace(" ", "_").replace("'", "")
		for view: Array in VIEWS:
			await _shot(out, "%s_%s" % [tag, view[0]], plan * (view[1] as Vector3), plan * (view[2] as Vector3))
	# Each placement once, close, in its own place under the room's own light.
	var done: Dictionary = {}
	for occasion: String in names:
		dressing.dress(occasion)
		for piece: Node3D in dressing.pieces_for(occasion):
			var id := str(piece.get_meta("occasion_placement"))
			if done.has(id):
				continue
			done[id] = true
			var box := _extent(piece, piece)
			var middle := box.get_center()
			var span := maxf(maxf(box.size.x, box.size.y), 0.25)
			var eye := middle + Vector3(span * 0.25, 0.05, 0.55 + span * 1.05)
			if str(piece.get_meta("occasion_rest")) == "support":
				eye = middle + Vector3(span * 0.5, span * 0.45 + 0.1, 0.45 + span * 1.2)
			await _shot(out, "piece_%s" % id, piece.global_transform * eye, piece.global_transform * middle)
	dressing.dress("")
	_holding = false
	stand.queue_free()


func _shot(out: String, key: String, eye: Vector3, target: Vector3) -> void:
	_eye = eye
	_target = target
	_holding = true
	for i in 45:
		await get_tree().process_frame
	for i in 10:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("occasion_%s.png" % key))
	print("[V2 OCCASION DRESSING] shot ", key)


func _finish() -> void:
	var ok := _fails == 0
	print("[V2 OCCASION DRESSING] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	_holding = false
	if is_instance_valid(_world):
		if _world.has_method("shutdown_for_tests"):
			_world.shutdown_for_tests()
		remove_child(_world)
		_world.free()
	get_tree().quit(0 if ok else 1)
