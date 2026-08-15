extends Node
## Exact geometry/animation proof for T7e's per-letter neon batching.

var _passed := 0
var _failed := 0


func _ready() -> void:
	var previous := OS.get_environment("PERF_NEON_LETTER_BATCHING_OFF")
	OS.set_environment("PERF_NEON_LETTER_BATCHING_OFF", "1")
	var blade := NeonSignProp.new()
	blade.name = "TEST_NEON_BLADE"
	blade.sign_text = "ORISON"
	blade.vertical = true
	add_child(blade)
	var wall := NeonSignProp.new()
	wall.name = "TEST_NEON_WALL"
	wall.sign_text = "DRUGS"
	wall.vertical = false
	wall.position = Vector3(4.0, 0.0, 0.0)
	add_child(wall)
	await get_tree().process_frame

	var holders: Array = blade._letter_geometry + wall._letter_geometry
	_check("blade and wall retain one holder per letter and face",
			holders.size() == 17)
	var before_boxes: Array[AABB] = []
	var before_draws := 0
	for holder in holders:
		before_boxes.append(_geometry_aabb(holder))
		before_draws += _geometry_under(holder).size()
	_check("the control contains the primitive-built letter population",
			before_draws > 250)

	var removed: int = blade.batch_letter_geometry() \
			+ wall.batch_letter_geometry()
	await get_tree().process_frame
	await get_tree().process_frame
	var after_draws := 0
	var bounds_hold := true
	var holders_intact := true
	for i in holders.size():
		var holder: Node3D = holders[i]
		var draws := _geometry_under(holder)
		after_draws += draws.size()
		holders_intact = holders_intact and draws.size() >= 1 \
				and draws.size() <= 3
		bounds_hold = bounds_hold and before_boxes[i].is_equal_approx(
				_geometry_aabb(holder))
	_check("batching removes more than 200 primitive submissions",
			removed == before_draws - after_draws and removed > 200)
	_check("every animated letter survives as at most three finish draws",
			holders_intact and after_draws <= 51)
	_check("batching preserves every letter's exact local AABB", bounds_hold)
	_check("the production operation is idempotent",
			blade.batch_letter_geometry() == 0
			and wall.batch_letter_geometry() == 0)
	_check("the emissive tube material survives the merge",
			_has_material(blade, blade._tube_mat)
			and _has_material(wall, wall._tube_mat))

	var now := Time.get_ticks_msec() / 1000.0
	blade._dropped = 0
	blade._drop_until = now + 1.0
	blade._process(0.016)
	_check("a batched logical letter can still drop",
			not blade._letters[0].visible)
	blade._drop_until = now - 1.0
	blade._process(0.016)
	_check("a dropped batched letter restores on schedule",
			blade._letters[0].visible and blade._dropped == -1)

	if previous == "":
		OS.set_environment("PERF_NEON_LETTER_BATCHING_OFF", "")
	else:
		OS.set_environment("PERF_NEON_LETTER_BATCHING_OFF", previous)
	print("[NEON BATCH TEST] %d passed, %d failed; draws %d -> %d" % [
			_passed, _failed, before_draws, after_draws])
	get_tree().quit(0 if _failed == 0 else 1)


func _geometry_under(owner: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	_collect(owner, out)
	return out


func _collect(node: Node, out: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


func _geometry_aabb(holder: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for geometry in _geometry_under(holder):
		var relative := holder.global_transform.affine_inverse() \
				* geometry.global_transform
		var box: AABB = relative * geometry.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


func _has_material(owner: Node, material: Material) -> bool:
	for geometry in _geometry_under(owner):
		if geometry is MeshInstance3D \
				and (geometry as MeshInstance3D).material_override == material:
			return true
	return false


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  PASS  " + label)
	else:
		_failed += 1
		push_error("  FAIL  " + label)
