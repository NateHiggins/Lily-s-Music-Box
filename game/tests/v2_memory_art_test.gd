extends Node
## The residents' memory art in V2 (v1r_found_art_20261109, memory art only):
## V1's twenty pieces, each in its resident's main room, the hung ones flat
## against a real wall and the standing ones on a real support, every frame
## Blender geometry in a catalogue finish, and every frame empty: none of V1's
## generated pictures is carried. With SHOT_DIR set (windowed), also
## photographs every piece in its room.
const MemoryArt := preload("res://scripts/building/orison_v2_memory_art.gd")
const Piece := preload("res://scripts/building/orison_v2_memory_art_piece.gd")

var _fails := 0
var _checks := 0
var _world: Node
var _stand := Vector3.ZERO
var _look := Vector3.ZERO
var _framing := false


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	process_priority = 1000
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
	var blockout: Node3D = _world.get("_blockout")
	var node: Node = blockout.get_node_or_null(MemoryArt.HOLDER)
	if node == null:
		node = MemoryArt.mount(_world, blockout, _world.layout, _world.adapter)
	_check(node.errors.is_empty(), "the mount reports no errors: %s" % [node.errors])
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MemoryArt.CATALOG))
	_check(node.pieces.size() == 20 and int(catalog.expected_count) == 20, "V1's twenty pieces are hung (%d)" % node.pieces.size())
	_check(get_tree().get_nodes_in_group("character_memories").size() == node.pieces.size(), "they are in V1's group")
	var again: Node = MemoryArt.mount(_world, blockout, _world.layout, _world.adapter)
	_check(not again.errors.is_empty() and again.pieces.is_empty(), "a second mount is refused")
	again.free()
	await _settle()
	_world.player.set_physics_process(false)
	_stand = _world.player.global_position
	_look = _stand + Vector3.FORWARD
	_framing = true
	await _place_checks(node, catalog)
	_surface_checks(node)
	if not OS.get_environment("SHOT_DIR").is_empty():
		await _photograph(node, catalog)
	_finish()


func _process(_delta: float) -> void:
	if _framing and _world != null and _world.player != null:
		_world.player.global_position = _stand
		_world.player.camera.look_at(_look)


func _settle() -> void:
	var calm := 0
	var last := Time.get_ticks_usec()
	for i in 1800:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		calm = calm + 1 if now - last < 250000 else 0
		last = now
		if calm >= 60:
			return
	_check(false, "the world settles")


func _floor_of(piece: Node3D) -> float:
	return floorf((piece.global_position.y + 0.3) / 3.2) * 3.2


func _place_checks(node: Node, catalog: Dictionary) -> void:
	var hung := 0
	var standing := 0
	for spec: Dictionary in catalog.pieces:
		var id := str(spec.id)
		var piece: Node3D = node.pieces.get(id)
		_check(piece != null, "%s is hung" % id)
		if piece == null:
			continue
		var unit := str(spec.unit)
		var out := piece.global_transform.basis.z
		var inside := piece.global_position + out * 0.15 + Vector3.UP * 0.05
		var room: String = _world.room_at_world(inside)
		_check(_world.unit_at_world(inside) == unit and room.ends_with("_MAIN"),
			"%s is in %s's main room (found '%s')" % [id, unit, room])
		_check(piece.get_script() == Piece and piece is CharacterMemoryArt and piece.name == "MemoryArt_" + id
			and piece.art_id == id and piece.medium == str(spec.get("medium", "photo")),
			"%s keeps V1's identity and medium (%s)" % [id, piece.medium])
		# Bring the room up round the player before measuring it.
		_stand = Vector3(inside.x, _floor_of(piece), inside.z) + out * 1.2
		_look = piece.global_position
		for i in 20:
			await get_tree().process_frame
		var space := piece.get_world_3d().direct_space_state
		if str(spec.get("placement", "wall")) == "tabletop":
			standing += 1
			_check(piece.tabletop and piece.draws.size() == 2, "%s stands on furniture, as V1" % id)
			var worst := 0.0
			var missed := 0
			for foot: Vector3 in [Vector3(0, 0, 0), Vector3(0.17, 0, 0.08), Vector3(-0.17, 0, 0.08), Vector3(0.17, 0, -0.09), Vector3(-0.17, 0, -0.09)]:
				var from := piece.global_transform * (foot + Vector3.UP * 0.05)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.1))
				if hit.is_empty():
					missed += 1
				else:
					worst = maxf(worst, absf((hit.position as Vector3).distance_to(from) - 0.05))
			var height := piece.global_position.y - _floor_of(piece)
			# The table's drawn top is its furniture bound; its collider sits 5 mm off it.
			_check(missed == 0 and worst <= 0.006 and height > 0.55 and height < 1.1,
				"%s rests on a real support %.2f m up (%d of 5 rays missed, worst gap %.1f mm)" % [id, height, missed, worst * 1000.0])
		else:
			hung += 1
			_check(not piece.tabletop and piece.draws.size() == 3, "%s hangs on a wall, as V1" % id)
			var worst := 0.0
			var missed := 0
			var square := true
			for at: Vector3 in [Vector3.ZERO, Vector3(0.38, 0.38, 0), Vector3(-0.38, 0.38, 0), Vector3(0.38, -0.38, 0),
					Vector3(-0.38, -0.38, 0), Vector3(0, 0.43, 0)]:
				var from := piece.global_transform * (at + Vector3.BACK * 0.05)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - out * 0.1))
				if hit.is_empty():
					missed += 1
					continue
				worst = maxf(worst, absf((hit.position as Vector3).distance_to(from) - 0.05))
				square = square and (hit.normal as Vector3).dot(out) > 0.9995
			_check(missed == 0 and worst <= 0.004 and square and absf(out.y) < 0.001,
				"%s hangs flat against a real wall (%d of 6 rays missed, worst gap %.1f mm)" % [id, missed, worst * 1000.0])
			var height := piece.global_position.y - _floor_of(piece)
			_check(height >= 1.5 and height <= 1.75, "%s hangs at eye height (%.2f m)" % [id, height])
			# Nothing solid stands in front of it.
			var front := space.intersect_ray(PhysicsRayQueryParameters3D.create(
					piece.global_position + out * 0.06, piece.global_position + out * 0.5))
			_check(front.is_empty(), "%s has clear air in front of it" % id)
	_check(hung == 18 and standing == 2, "eighteen hang and two stand, as V1 (%d, %d)" % [hung, standing])
	# No two pieces share a place.
	var crowded := 0
	var all: Array = node.pieces.values()
	for i in all.size():
		for j in range(i + 1, all.size()):
			if (all[i] as Node3D).global_position.distance_to((all[j] as Node3D).global_position) < 0.9:
				crowded += 1
	_check(crowded == 0, "no two pieces crowd each other (%d pairs)" % crowded)


func _surface_checks(node: Node) -> void:
	var draws := 0
	var triangles := 0
	var pictures := 0
	for id: String in node.pieces:
		var piece: Node3D = node.pieces[id]
		var bad: Array[String] = []
		for found in piece.find_children("*", "", true, false):
			if not (found is MeshInstance3D):
				bad.append("%s is not frame stock" % found.name)
				continue
			var draw := found as MeshInstance3D
			draws += 1
			if not (draw.mesh is ArrayMesh) or draw.mesh.get_surface_count() != 1:
				bad.append("%s is not one authored surface" % draw.name)
				continue
			var arrays := draw.mesh.surface_get_arrays(0)
			var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
			triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			if uvs == null or (uvs as PackedVector2Array).is_empty() or arrays[Mesh.ARRAY_TANGENT] == null:
				bad.append("%s has no authored UVs or tangents" % draw.name)
			var finish := draw.material_override as StandardMaterial3D
			if finish == null or finish.albedo_texture == null or finish.roughness_texture == null \
					or finish.normal_texture == null or finish.uv1_triplanar:
				bad.append("%s is not a catalogue finish on its own UVs" % draw.name)
			elif finish.albedo_texture.resource_path.contains("character_memories") \
					or finish.albedo_texture.resource_path.contains("found_art"):
				pictures += 1
			if draw.visibility_range_end <= 0.0 or draw.visibility_range_end > 16.0:
				bad.append("%s has no visibility range" % draw.name)
			if draw.name.contains("Mount") and (finish == null or finish.albedo_texture != MatLib.get_mat("paper").albedo_texture):
				bad.append("%s is not a blank paper mount" % draw.name)
			if draw.name.contains("Moulding") and finish != null:
				var wanted: String = "oak_quartered" if piece.medium == "painting" else "wood_dark"
				if finish.albedo_texture != MatLib.get_mat(wanted).albedo_texture:
					bad.append("%s is not the %s frame its medium asks for" % [draw.name, wanted])
		_check(bad.is_empty(), "%s: Blender frame stock in catalogue finishes %s" % [piece.name, bad])
	_check(pictures == 0, "no frame carries one of V1's generated pictures")
	print("  [V2 MEMORY ART] %d mesh draws, %d triangles in the whole house; each within 14 m only" % [draws, triangles])


func _photograph(node: Node, catalog: Dictionary) -> void:
	var dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	for layer in _world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	if _world.service_set_carrier != null:
		_world.service_set_carrier.visible = false
	_world.player.set_lamp_enabled(false)
	var switches := _world.get_node("V2RoomSwitches") as SwitchSystem
	var lit := [false]
	var index := 0
	for spec: Dictionary in catalog.pieces:
		var id := str(spec.id)
		var piece: Node3D = node.pieces.get(id)
		if piece == null:
			continue
		index += 1
		var out := piece.global_transform.basis.z
		var room: String = _world.room_at_world(piece.global_position + out * 0.15 + Vector3.UP * 0.05)
		# The room's own light, on.
		var heard := func(toggled: String, on: bool) -> void:
			if toggled == room:
				lit[0] = on
		switches.room_toggled.connect(heard)
		lit[0] = false
		switches.toggle_room(room)
		if not lit[0]:
			switches.toggle_room(room)
		switches.room_toggled.disconnect(heard)
		var floor_y := _floor_of(piece)
		_look = piece.global_position + Vector3.UP * (0.19 if piece.tabletop else 0.0)
		var views := [["room", 2.1 if not piece.tabletop else 1.5]]
		if id in ["evelyn_retirement", "iris_self_portrait", "juno_session", "mae_young_cataloger"]:
			views.append(["close", 0.85 if not piece.tabletop else 0.6])
		for view: Array in views:
			_stand = piece.global_position + out * float(view[1])
			_stand.y = floor_y + 0.02 if not piece.tabletop or str(view[0]) == "room" else floor_y - 0.45
			for i in 40:
				await get_tree().process_frame
			for i in 10:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%02d_%s_%s_%s.png" % [dir, index, spec.unit, id, view[0]])


func _finish() -> void:
	var ok := _fails == 0
	print("[V2 MEMORY ART] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	_framing = false
	if _world != null:
		if _world.has_method("shutdown_for_tests"):
			_world.shutdown_for_tests()
		remove_child(_world)
		_world.free()
		_world = null
	get_tree().quit(0 if ok else 1)
