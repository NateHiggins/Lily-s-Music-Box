extends Node
## The evidence pieces as real objects (build_evidence_pieces.py, the stock in
## orison_v2_evidence_stock.gd). First the stock alone: it prepares, builds
## every clue id in the anchors table plus the bundle and the pin, and each
## piece is authored geometry on its own chart wearing catalogue finishes,
## with its origin on the centre of its back face, +Z its face and a
## plausible size. Then the V2 world is booted once: all thirteen hang in a
## row on a clear wall of 4B at eye height and lie on tables there, and are
## photographed (windowed, SHOT_DIR).
const Stock := preload("res://scripts/building/orison_v2_evidence_stock.gd")
const ANCHORS := "res://data/temporal/anchors.json"
const GENERAL: Array[String] = ["bundle", "pin"]
## The clear stretch of 4B's south wall above the couch, west of the wall clock, in plan.
const WALL_PLAN := Vector2(-11.95, -3.85)
const WALL_INTO_ROOM := Vector3(0, 0, 1)
const EYE_HEIGHT := 1.5
const GAP := 0.05

var _fails := 0
var _checks := 0
var world: Node
var _view := Vector3.ZERO
var _target := Vector3.ZERO
var _eye := Vector3(0, 1.6, 0)
var _filming := false


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	process_priority = 1000
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var stock := Stock.new()
	_check(stock.prepare(), "the stock prepares: %s" % [stock.errors])
	var ids: Array[String] = []
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ANCHORS))
	for anchor_id: String in table.anchors:
		ids.append(str(table.anchors[anchor_id].clue.id))
	_check(ids.size() == 11, "the anchors table names eleven pieces of evidence (%d)" % ids.size())
	ids.append_array(GENERAL)
	_check(not stock.has("no_such_piece") and stock.build("no_such_piece") == null and stock.size("no_such_piece") == Vector3.ZERO,
		"an unknown id builds nothing")
	var draws := 0
	var triangles := 0
	for id: String in ids:
		_check(stock.has(id), "%s is in the stock" % id)
		var piece := stock.build(id)
		_check(piece != null, "%s builds" % id)
		if piece == null:
			continue
		var again := stock.build(id)
		_check(again != null and again != piece, "%s builds a new node each time" % id)
		if again != null:
			again.free()
		var box := AABB()
		var first := true
		var parts := piece.find_children("*", "MeshInstance3D", true, false)
		_check(not parts.is_empty(), "%s draws" % id)
		for draw: MeshInstance3D in parts:
			draws += 1
			var part_box: AABB = draw.transform * draw.mesh.get_aabb()
			box = part_box if first else box.merge(part_box)
			first = false
			_check(draw.mesh is ArrayMesh, "%s/%s is authored geometry" % [id, draw.name])
			_check(draw.visibility_range_end >= 8.0 and draw.visibility_range_end <= 16.0,
				"%s/%s has a visibility range (%.1f)" % [id, draw.name, draw.visibility_range_end])
			var finish := draw.material_override
			if finish is ShaderMaterial:
				_check((finish as ShaderMaterial).shader.resource_path == "res://shaders/lamp_glass_surface.gdshader",
					"%s/%s is the house glazing" % [id, draw.name])
			else:
				var paint := finish as StandardMaterial3D
				_check(paint != null and paint.albedo_texture != null and paint.roughness_texture != null
					and paint.normal_texture != null and not paint.uv1_triplanar
					and paint.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,
					"%s/%s wears a catalogue finish on its own chart" % [id, draw.name])
			for surface in draw.mesh.get_surface_count():
				var arrays := draw.mesh.surface_get_arrays(surface)
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
				var finite := true
				for value in uv:
					finite = finite and is_finite(value.x) and is_finite(value.y)
				_check(uv.size() == vertices.size() and finite and tangents.size() == vertices.size() * 4,
					"%s/%s has a finite UV and a tangent per vertex" % [id, draw.name])
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
		var extent := stock.size(id)
		_check((box.size - extent).length() < 0.002,
			"%s is the size the data gives (%s against %s)" % [id, box.size, extent])
		var centre := box.get_center()
		_check(absf(centre.x) < 0.001 and absf(centre.y) < 0.001, "%s is centred on its origin across and up (%s)" % [id, centre])
		var longest := maxf(extent.x, maxf(extent.y, extent.z))
		if id == "pin":
			_check(box.position.z < -0.003 and box.position.z > -0.005 and box.end.z > 0.007,
				"the pin's point lies behind its origin and its head in front (%.4f to %.4f)" % [box.position.z, box.end.z])
			_check(longest >= 0.010 and longest <= 0.015, "the pin is about 12 mm long (%.4f)" % longest)
		else:
			_check(absf(box.position.z) < 0.0005, "%s has its back face on the origin plane (%.4f)" % [id, box.position.z])
			_check(extent.z < extent.x and extent.z < extent.y, "%s faces +Z: its depth is its least side (%s)" % [id, extent])
			_check(longest >= 0.03 and longest <= 0.40, "%s is between 3 cm and 40 cm (%.3f)" % [id, longest])
		piece.free()
	print("[V2 EVIDENCE PIECES] thirteen pieces: draws %d, triangles %d" % [draws, triangles])

	world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	if world.startup_failed:
		_finish()
		return
	var steady := 0
	var waited := 0
	var last := Time.get_ticks_usec()
	while steady < 60 and waited < 3000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		steady = steady + 1 if now - last < 250000 else 0
		last = now
		waited += 1
	_check(steady >= 60, "the world is steady")

	# The row on the wall.
	var blockout: Node3D = world._blockout
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var couch := world.adapter.resolve("4B_couch") as Node3D
	_check(couch != null, "4B's couch gives the floor")
	if couch == null:
		_finish()
		return
	var floor_local: float = blockout.to_local(couch.global_position).y
	var out: Vector3 = (blockout.global_transform.basis * WALL_INTO_ROOM).normalized()
	var across := Vector3.UP.cross(out).normalized()
	var middle: Vector3 = blockout.to_global(Vector3(WALL_PLAN.x, floor_local + EYE_HEIGHT, WALL_PLAN.y)) + out * 0.6
	var total := -GAP
	for id: String in ids:
		total += stock.size(id).x + GAP
	var holder := Node3D.new()
	holder.name = "EvidenceReview"
	world.add_child(holder)
	var hung: Dictionary = {}
	var cursor := -total * 0.5
	var depths: Array[float] = []
	for id: String in ids:
		var extent := stock.size(id)
		var from := middle + across * (cursor + extent.x * 0.5)
		cursor += extent.x + GAP
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - out * 1.2))
		_check(not hit.is_empty(), "%s finds the wall" % id)
		if hit.is_empty():
			continue
		depths.append(from.distance_to(hit.position))
		_check((hit.normal as Vector3).dot(out) > 0.99, "%s hangs on a wall that faces the room" % id)
		_check(world.unit_at_world(from) == "4B", "%s hangs in 4B (%s)" % [id, world.unit_at_world(from)])
		var piece := stock.build(id)
		holder.add_child(piece)
		piece.global_transform = Transform3D(Basis(across, Vector3.UP, out), hit.position)
		hung[id] = piece
		_check(piece.global_transform.basis.z.dot(out) > 0.999 and piece.global_transform.basis.y.dot(Vector3.UP) > 0.999,
			"%s hangs with one transform: +Z off the wall, +Y up" % id)
	var nearest := 1e9
	var farthest := 0.0
	for depth in depths:
		nearest = minf(nearest, depth)
		farthest = maxf(farthest, depth)
	_check(depths.size() == ids.size() and farthest - nearest < 0.005,
		"the wall is clear and flat along the row (%.3f m long, depth spread %.4f)" % [total, farthest - nearest])

	# The set on 4B's tables: the small pieces on the meal table, the bundle on the low table.
	var laid: Dictionary = {}
	var table_node := world.adapter.resolve("4B_meal_table") as Node3D
	var low_table := world.adapter.resolve("4B_coffee") as Node3D
	_check(table_node != null and low_table != null, "4B has its meal table and its low table")
	var table_top := Vector3.ZERO
	if table_node != null and low_table != null:
		var away: Vector3 = -(blockout.global_transform.basis * Vector3(1, 0, 0)).normalized()
		var right := away.cross(Vector3.UP).normalized()
		var flat := Basis(right, away, Vector3.UP)
		var index := 0
		for id: String in ids:
			var spot: Vector3
			if id == "bundle":
				spot = low_table.global_position
			else:
				var column := index % 4
				var row := index / 4
				spot = table_node.global_position + right * (float(column) - 1.5) * 0.17 - away * (float(row) - 1.0) * 0.20
				index += 1
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 1.3, spot + Vector3.UP * 0.2))
			_check(not hit.is_empty(), "%s finds a table top" % id)
			if hit.is_empty():
				continue
			if id != "bundle":
				table_top = hit.position if table_top == Vector3.ZERO else table_top
			var piece := stock.build(id)
			holder.add_child(piece)
			piece.global_transform = Transform3D(flat, hit.position)
			laid[id] = piece
			_check(piece.global_transform.basis.z.dot(Vector3.UP) > 0.999, "%s lies face up" % id)
			var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(piece.global_position + Vector3.UP * 0.05,
				piece.global_position + Vector3.DOWN * 0.2))
			_check(not below.is_empty() and absf(float(below.position.y) - piece.global_position.y) < 0.002, "%s rests on its support" % id)
	_check(laid.size() == ids.size() and hung.size() == ids.size(), "all thirteen hang and all thirteen lie")
	for i in 5:
		await get_tree().process_frame
	_check(holder.get_child_count() == ids.size() * 2 and holder.is_inside_tree(), "the pieces stand in the world")

	var shots := OS.get_environment("SHOT_DIR")
	if shots != "":
		for layer in world.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false
		world.player.set_physics_process(false)
		world.player.set_lamp_enabled(false)
		var carrier := world.get("service_set_carrier") as Node3D
		if carrier != null:
			carrier.visible = false
		_eye = world.player.camera.global_position - world.player.global_position
		await _film(shots, "row_at_2m", middle - out * 0.6, middle + out * 1.4)
		await _film(shots, "row_left_at_1m", middle - out * 0.6 - across * total * 0.27, middle + out * 0.5 - across * total * 0.27)
		await _film(shots, "row_right_at_1m", middle - out * 0.6 + across * total * 0.27, middle + out * 0.5 + across * total * 0.27)
		for id: String in ids:
			if hung.has(id):
				var piece: Node3D = hung[id]
				var reach: float = clampf(stock.size(id).length() * 1.6, 0.12, 0.8)
				await _film(shots, "wall_" + id, piece.global_position, piece.global_position + out * reach + Vector3.UP * reach * 0.1)
		if table_top != Vector3.ZERO and table_node != null:
			var centre := Vector3(table_node.global_position.x, table_top.y, table_node.global_position.z)
			var back: Vector3 = (blockout.global_transform.basis * Vector3(1, 0, 0)).normalized()
			await _film(shots, "table_set", centre, centre + back * 0.75 + Vector3.UP * 0.75)
			await _film(shots, "table_set_close", centre, centre + back * 0.30 + Vector3.UP * 0.55)
		if laid.has("bundle"):
			var piece: Node3D = laid["bundle"]
			await _film(shots, "table_bundle", piece.global_position + Vector3.UP * 0.06, piece.global_position + out * 0.7 + Vector3.UP * 0.6 + across * 0.3)
	_finish()


func _process(_delta: float) -> void:
	if _filming and world != null:
		world.player.global_position = _view - _eye
		world.player.camera.look_at(_target)


## Photographs `subject` from `view` with the room's own lights.
func _film(dir: String, label: String, subject: Vector3, view: Vector3) -> void:
	_view = view
	_target = subject
	_filming = true
	for i in 32:
		await get_tree().process_frame
	for i in 10:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(label + ".png"))
	_filming = false


func _finish() -> void:
	var ok := _fails == 0
	print("[V2 EVIDENCE PIECES] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if world != null:
		if world.has_method("shutdown_for_tests"):
			world.shutdown_for_tests()
		remove_child(world)
		world.free()
	get_tree().quit(0 if ok else 1)
