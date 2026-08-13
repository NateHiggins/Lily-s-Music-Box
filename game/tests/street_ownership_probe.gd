extends Node
## M0.5 check 2 — name every mass that actually renders into the street.
##
## `art/renders/map_before/street_1.png` shows several large flat-black
## masses across the pavement and carriageway. Materials are not the
## cause: plywood, soil, metal, glassish, limestone and concrete all
## resolve.
##
## SCENE-TREE MEMBERSHIP IS NOT RENDER MEMBERSHIP. The first draft of
## this probe walked the whole tree and indicted `SwcGraybox`, which was
## a false positive: `ArcadeMachine` (game/scripts/arcade/arcade_machine.gd)
## `extends SubViewport` and sets `own_world_3d = true` at :82, so every
## receiver's SWC world lives in its OWN World3D. It is in the tree and
## it can never draw into the street. Anything inside a SubViewport is
## therefore pruned, and a candidate must share the street camera's
## World3D and Viewport and be visible in tree before it is recorded.
##
## Coordinate note: layout data is Blender-handed and `b2g` maps
## [x, y, z] -> (x, z, -y), so the street's Blender y -14..-30 is Godot
## z +14..+30. Everything below is Godot-handed.
##
## Standing caveat: intersecting a broad AABB does not prove visible
## triangles occupy the frame. Merged per-floor buffers span the whole
## site (`F01_furniture_asphalt` is 220.0 x 0.3 x 148.0). Rank by
## individual node, never by owner, and treat hide/show renders as the
## only final evidence.

const STREET_BOX_MIN := Vector3(-36.0, -0.6, 8.0)
const STREET_BOX_MAX := Vector3(36.0, 6.0, 32.0)
const MIN_FACE := 1.6
## A node whose AABB approaches the site is a merged buffer, not a mass.
const SITE_SPAN := 90.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node3D = load(
			"res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.5).timeout
	await get_tree().physics_frame

	var target_vp: Viewport = get_viewport()
	var target_world: World3D = target_vp.find_world_3d()
	var box := AABB(STREET_BOX_MIN, STREET_BOX_MAX - STREET_BOX_MIN)
	var found: Array = []
	_walk(root, box, found, target_world, target_vp)
	found.sort_custom(func(a, b): return a["face"] > b["face"])

	print("\n[OWN] %d main-world masses intersect the street volume"
			% found.size())
	print("[OWN] %-30s %-26s %9s %-22s %s"
			% ["node", "parent", "face m2", "size (x,y,z)", "material"])
	for f in found:
		print("[OWN] %-30s %-26s %9.1f %-22s %s"
				% [f["name"].substr(0, 30), f["parent"].substr(0, 26),
				f["face"], f["size"], f["mat"]])
	print("\n[OWN] --- merged buffers excluded (AABB >= %.0f m) ---"
			% SITE_SPAN)
	get_tree().quit(0)


func _walk(n: Node, box: AABB, out: Array, world: World3D,
		vp: Viewport) -> void:
	# Prune the isolated worlds outright. Recursing into a SubViewport is
	# what produced the SwcGraybox false positive.
	if n is SubViewport:
		return
	if n is GeometryInstance3D and _renders_here(n, world, vp):
		if n is MultiMeshInstance3D:
			_record_multimesh(n as MultiMeshInstance3D, box, out)
		elif n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			_record_mesh(n as MeshInstance3D, box, out)
	for c in n.get_children():
		_walk(c, box, out, world, vp)


func _renders_here(n: Node3D, world: World3D, vp: Viewport) -> bool:
	if n.get_world_3d() != world:
		return false
	if n.get_viewport() != vp:
		return false
	return n.is_visible_in_tree()


func _record_mesh(mi: MeshInstance3D, box: AABB, out: Array) -> void:
	var world_aabb: AABB = mi.global_transform * mi.get_aabb()
	if not world_aabb.intersects(box):
		return
	var s: Vector3 = world_aabb.size
	if maxf(s.x, maxf(s.y, s.z)) >= SITE_SPAN:
		return                      # merged floor buffer, not a mass
	var face: float = maxf(s.x * s.y, maxf(s.z * s.y, s.x * s.z))
	if face < MIN_FACE:
		return
	out.append({
		"name": String(mi.name),
		"parent": String(mi.get_parent().name) if mi.get_parent() else "-",
		"face": face,
		"size": "%.1f,%.1f,%.1f" % [s.x, s.y, s.z],
		"mat": _mat_of(mi),
	})


func _record_multimesh(n: MultiMeshInstance3D, box: AABB,
		out: Array) -> void:
	# Traffic draws as MultiMesh, which does NOT inherit MeshInstance3D.
	# Report instances separately so a moving vehicle is distinguishable
	# from a static obstruction.
	var mm: MultiMesh = n.multimesh
	if mm == null or mm.mesh == null:
		return
	var local: AABB = mm.mesh.get_aabb()
	for i in mm.instance_count:
		var world_aabb: AABB = (n.global_transform
				* mm.get_instance_transform(i)) * local
		if not world_aabb.intersects(box):
			continue
		var s: Vector3 = world_aabb.size
		var face: float = maxf(s.x * s.y, maxf(s.z * s.y, s.x * s.z))
		if face < MIN_FACE:
			continue
		out.append({
			"name": "%s#%d" % [String(n.name), i],
			"parent": "MOVING/%s" % (String(n.get_parent().name)
					if n.get_parent() else "-"),
			"face": face,
			"size": "%.1f,%.1f,%.1f" % [s.x, s.y, s.z],
			"mat": _mm_mat(n, mm),
		})


func _mm_mat(n: MultiMeshInstance3D, mm: MultiMesh) -> String:
	var mat: Material = n.material_override
	if mat == null and mm.mesh.get_surface_count() > 0:
		mat = mm.mesh.surface_get_material(0)
	return _describe(mat)


func _mat_of(m: MeshInstance3D) -> String:
	var mat: Material = m.material_override
	if mat == null and m.mesh.get_surface_count() > 0:
		mat = m.get_active_material(0)
	return _describe(mat)


func _describe(mat: Material) -> String:
	if mat == null:
		return "NONE (unlit default)"
	var label := String(mat.resource_name)
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		label += " [%s albedo=%.2f,%.2f,%.2f shaded=%s]" % [
				"tex" if sm.albedo_texture != null else "FLAT",
				sm.albedo_color.r, sm.albedo_color.g, sm.albedo_color.b,
				"no" if sm.shading_mode
						== BaseMaterial3D.SHADING_MODE_UNSHADED else "yes"]
	return label if label.strip_edges() != "" else String(mat.get_class())
