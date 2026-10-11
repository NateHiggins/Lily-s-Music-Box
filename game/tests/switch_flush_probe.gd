extends RefCounted
## Finished-wall flushness of V2 switch plates. Casts a 13 x 3 grid of rays over the plate's 120 x 180 mm rear face
## along its into-wall axis, from just in front of the face, against every visible mesh and multimesh instance near
## it: wall boxes, far-face skins, public wainscot backing and stiles, door casings, window joinery, risers and any
## object standing there. Physics cannot answer this; those finishes carry no collision.
## Rays start 0.12 m in front of the rear face, so a plate set into a wall reads as sunk, not flush; samples
## cover the rim (x +-0.060) every 10 mm across and the top, middle and bottom.
## measure() returns, per sample, the surface's offset from the plate's rear plane (+ = the plate stands off the
## wall, - = a surface lies in front of the rear plane, the plate is sunk or obstructed; INF = nothing behind).
const REAR := -0.008
const START := 0.12
const REACH := 0.3
var _targets: Array = []
var _faces: Dictionary = {}

func _init(world: Node) -> void:
	for node: GeometryInstance3D in world.find_children("*", "GeometryInstance3D", true, false):
		if not node.is_visible_in_tree() or _in_switch_model(node): continue
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			_add(node.global_transform, (node as MeshInstance3D).mesh)
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
			var multimesh := (node as MultiMeshInstance3D).multimesh
			if multimesh.mesh == null: continue
			var count := multimesh.instance_count if multimesh.visible_instance_count < 0 else multimesh.visible_instance_count
			for i in count:
				_add(node.global_transform * multimesh.get_instance_transform(i), multimesh.mesh)

func _in_switch_model(node: Node) -> bool:
	var at: Node = node
	while at != null:
		if at.name == "SwitchModel": return true
		at = at.get_parent()
	return false

func _add(xform: Transform3D, mesh: Mesh) -> void:
	var box := xform * mesh.get_aabb()
	# The building's outer masonry leaf and the sky dome enclose everything and never stand behind a plate.
	if box.get_longest_axis_size() > 25.0: return
	_targets.append([xform, mesh, box])

func _faces_of(mesh: Mesh) -> PackedVector3Array:
	var key := mesh.get_rid()
	if not _faces.has(key): _faces[key] = mesh.get_faces()
	return _faces[key]

func measure(plate: Node3D) -> Array:
	var into := plate.global_transform.basis.z.normalized()
	var region := AABB(plate.global_position - Vector3.ONE * 0.4, Vector3.ONE * 0.8)
	var near: Array = []
	for target: Array in _targets:
		if (target[2] as AABB).intersects(region): near.append(target)
	var gaps: Array = []
	for gx: float in [-0.060, -0.050, -0.040, -0.030, -0.020, -0.010, 0.0, 0.010, 0.020, 0.030, 0.040, 0.050, 0.060]:
		for gy: float in [-0.090, 0.0, 0.090]:
			var rear := plate.to_global(Vector3(gx, gy, REAR))
			var a := rear - into * START
			var b := rear + into * REACH
			var best := INF
			for target: Array in near:
				var xform: Transform3D = target[0]
				var inv := xform.affine_inverse()
				var la := inv * a
				var lb := inv * b
				var faces := _faces_of(target[1])
				for i in range(0, faces.size(), 3):
					var hit: Variant = Geometry3D.segment_intersects_triangle(la, lb, faces[i], faces[i + 1], faces[i + 2])
					if hit != null: best = minf(best, (xform * (hit as Vector3) - a).dot(into))
			gaps.append(best - START)
	return gaps
