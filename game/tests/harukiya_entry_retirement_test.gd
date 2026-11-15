extends Node
## DRAFT: install under game/tests after review. No entire world or proxy cell.
const Entry = preload("res://scripts/building/harukiya_entry_retirement.gd")
const CELL = "res://assets/building/floor_01_cells/shop_bar.gltf"
var failures: Array[String] = []
var checks := 0
var layout: Dictionary
var manifest: Dictionary

func _ready() -> void:
	RealityState.persistence_enabled = false
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	manifest = JSON.parse_string(FileAccess.get_file_as_string(Entry.DATA))
	var cell := _compose()
	if cell != null:
		_success(cell)
		cell.free()
	var damaged := _compose()
	if damaged != null:
		_late_failure(damaged)
		damaged.free()
	# This is a focused adapter test, not installed-world/gameplay proof.
	print(JSON.stringify({"test":"harukiya_entry_retirement", "scope":"actual retained-cell composition", "checks":checks, "failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
	return ok

func _compose() -> Node3D:
	var packed := load(CELL) as PackedScene
	if not _check(packed != null, "shipping cell imported"): return null
	var cell := packed.instantiate() as Node3D
	# Same unmounted preparation order as OrisonV2BarRegion._ready.
	var pipeline := [
		["orison_v2_bar_pool.gd", "mount_cell", true],
		["orison_v2_bar_fixture_mounts.gd", "mount_cell", false],
		["orison_v2_bar_pipe_supports.gd", "mount_cell", false],
		["orison_v2_bar_ceiling_finish.gd", "apply", true],
		["orison_v2_bar_gallery.gd", "mount_cell", true],
		["orison_v2_bar_stage.gd", "mount_cell", true],
		["orison_v2_bar_furniture.gd", "mount_cell", true],
		["orison_v2_bar_receiving.gd", "mount_cell", true],
	]
	for step: Array in pipeline:
		var script: GDScript = load("res://scripts/building/" + str(step[0]))
		var args: Array = [cell, layout] if step[2] else [cell]
		if step[0] == "orison_v2_bar_receiving.gd": args.append(false)
		if not _check(bool(script.callv(step[1], args)), "composition " + str(step[0])):
			cell.free(); return null
	var destination := preload("res://scripts/building/orison_v2_bar_destination.gd").new()
	if not _check(destination.mount(cell, layout), "composition destination"):
		if destination.get_parent() == null: destination.free()
		cell.free(); return null
	return cell

func _snapshot(root: Node) -> Dictionary:
	var out := {}
	var nodes: Array[Node] = [root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		nodes.append_array(node.get_children())
		var state := {"class":node.get_class(), "metadata":{}}
		for key: StringName in node.get_meta_list(): state.metadata[key] = node.get_meta(key)
		if node is Node3D:
			state.transform = node.transform; state.visible = node.visible
		if node is MeshInstance3D:
			state.mesh = node.mesh; state.override = node.material_override
			state.overlay = node.material_overlay
			state.surfaces = node.mesh.get("_surfaces").duplicate(true) if node.mesh is ArrayMesh else []
		if node is CollisionShape3D:
			state.shape = node.shape; state.disabled = node.disabled
			state.faces = node.shape.get_faces() if node.shape is ConcavePolygonShape3D else PackedVector3Array()
			state.margin = node.shape.margin if node.shape != null else 0.0
			state.backface = node.shape.backface_collision if node.shape is ConcavePolygonShape3D else false
		if node is CollisionObject3D:
			state.layer = node.collision_layer; state.mask = node.collision_mask
		out[str(root.get_path_to(node))] = state
	return out.duplicate(true)

# Independent occurrence oracle: exhaustive six-corner correspondence, no
# production Matcher/key/bin/filter calls. Consume every desired occurrence.
func _selected(faces: PackedVector3Array, pose: Transform3D, record: Dictionary, tolerance: float) -> Dictionary:
	var selected := {}
	for wanted: Array in record.triangles:
		var found := -1
		for start in range(0, faces.size(), 3):
			if selected.has(start): continue
			for permutation: Array in [[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]:
				var matches := true
				for i in 3:
					var point: Array = wanted[permutation[i]]
					if (pose * faces[start+i]).distance_to(Vector3(point[0],point[1],point[2])) > tolerance:
						matches = false; break
				if matches: found = start; break
			if found >= 0: break
		if not _check(found >= 0, "independent original occurrence " + str(record.name)): return {}
		selected[found] = true
	return selected

func _success(cell: Node3D) -> void:
	var pristine := (load(CELL) as PackedScene).instantiate() as Node3D
	var expected := {}
	for record: Dictionary in manifest.retirement:
		var draw := cell.get_node(str(record.name)) as MeshInstance3D
		var original := pristine.get_node(str(record.name)) as MeshInstance3D
		var source_faces := original.mesh.get_faces()
		var bounds := AABB(source_faces[0], Vector3.ZERO)
		for point: Vector3 in source_faces: bounds = bounds.expand(point)
		var tolerance := .00003 + maxf(bounds.size.x, maxf(bounds.size.y,bounds.size.z))/65535.0
		var chosen := _selected(draw.mesh.get_faces(), draw.transform, record, tolerance)
		var arrays := draw.mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for start in range(0, indices.size(), 3):
			if not chosen.has(start): kept.append_array(indices.slice(start,start+3))
		var item := {"indices":kept, "removed":chosen.size()}
		var shapes := draw.find_children("*", "CollisionShape3D", true, false)
		if bool(record.colliding):
			var shape := shapes[0] as CollisionShape3D
			var faces: PackedVector3Array = shape.shape.get_faces()
			var selected := _selected(faces, draw.transform, record, tolerance)
			var retained := PackedVector3Array()
			for start in range(0,faces.size(),3):
				if not selected.has(start): retained.append_array(faces.slice(start,start+3))
			item.shape_path = str(cell.get_path_to(shape)); item.faces = retained
		expected[str(record.name)] = item
	pristine.free()
	var before := _snapshot(cell)
	var result := Entry.apply(cell,layout)
	if not _check(result.get("verified",false), "composed entry apply"): return
	_check(result.get("removed_render_triangles") == 460, "audit render 460")
	_check(result.get("removed_collision_triangles") == 300, "audit collision 300")
	var after := _snapshot(cell)
	var removed_render := 0; var removed_collision := 0
	for path: String in expected:
		var old: Dictionary = before[path]; var current: Dictionary = after[path]
		var item: Dictionary = expected[path]
		var draw := cell.get_node(path) as MeshInstance3D
		var actual := PackedInt32Array()
		if draw.mesh.get_surface_count() > 0: actual = draw.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		_check(actual == item.indices, path + " exact independently selected index remainder")
		removed_render += int(old.surfaces[0].index_count)/3 - actual.size()/3
		if not item.indices.is_empty():
			var left: Dictionary = old.surfaces[0].duplicate(true)
			var right: Dictionary = current.surfaces[0].duplicate(true)
			for key: String in ["index_data", "index_count"]: left.erase(key); right.erase(key)
			_check(left == right, path + " all packed channels/material/LOD preserved")
		_check(current.visible == (false if item.indices.is_empty() else old.visible), path + " visibility")
		for key: String in ["mesh", "surfaces", "visible"]: old.erase(key); current.erase(key)
		if item.has("shape_path"):
			var old_shape: Dictionary = before[item.shape_path]
			var new_shape: Dictionary = after[item.shape_path]
			_check(new_shape.faces == item.faces, path + " exact independent collider remainder")
			removed_collision += (old_shape.faces.size()-new_shape.faces.size())/3
			_check(new_shape.disabled == item.faces.is_empty(), path + " collider disabled only when empty")
			for key: String in ["shape", "faces", "disabled"]: old_shape.erase(key); new_shape.erase(key)
	_check(removed_render == 460 and removed_collision == 300, "measured mesh/collider deltas 460/300")
	after["."].metadata.erase(Entry.META)
	_check(before == after, "all other descendants, resources, transforms, materials, collision flags and metadata unchanged")
	var stable := _snapshot(cell)
	_check(Entry.apply(cell,layout).is_empty(), "double apply rejected (expected adapter error)")
	_check(stable == _snapshot(cell), "double apply makes no mutation")

func _late_failure(cell: Node3D) -> void:
	# Break final record COLLISION only. Its render and all preceding records
	# remain valid, forcing failure after replacement preparation has begun.
	var record: Dictionary = manifest.retirement.back()
	if not _check(record.colliding and not record.hull_only, "late fault selects final colliding draw"): return
	var owner := cell.get_node(str(record.name)) as Node3D
	var shape := owner.find_children("*", "CollisionShape3D", true, false)[0] as CollisionShape3D
	var replacement := shape.shape.duplicate() as ConcavePolygonShape3D
	var faces := replacement.get_faces()
	for i in faces.size(): faces[i] += Vector3(100,0,0)
	replacement.set_faces(faces); shape.shape = replacement
	var stable := _snapshot(cell)
	_check(Entry.apply(cell,layout).is_empty(), "late collision mismatch rejected (expected adapter error)")
	_check(stable == _snapshot(cell), "late failure changes no mesh/shape/visibility/metadata anywhere")
