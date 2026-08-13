extends Node
## M0.5 check 2 — name every mass standing in the street.
##
## `art/renders/map_before/street_1.png` shows several large flat-black
## masses across the pavement and carriageway. Materials are not the
## cause: plywood, soil, metal, glassish, limestone and concrete all
## resolve. So this walks the built scene instead of guessing from node
## names, and reports ownership for anything big enough to be one of
## them.
##
## Coordinate note: layout data is Blender-handed and `b2g` maps
## [x, y, z] -> (x, z, -y), so the street's Blender y -14..-30 is Godot
## z +14..+30. Everything below is Godot-handed.
##
## STREET_BOX is the volume the render looks through. A mesh qualifies
## if its world AABB intersects that box and its footprint is at least
## MIN_FACE m2 — small enough to catch a hoarding panel, large enough to
## skip cobbles and bolt heads.

const STREET_BOX_MIN := Vector3(-36.0, -0.6, 8.0)
const STREET_BOX_MAX := Vector3(36.0, 6.0, 32.0)
const MIN_FACE := 1.6


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node3D = load(
			"res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.5).timeout
	await get_tree().physics_frame

	var box := AABB(STREET_BOX_MIN, STREET_BOX_MAX - STREET_BOX_MIN)
	var found: Array = []
	_walk(root, box, found)

	# Biggest first: the masses that dominate the frame are the ones
	# worth naming, and a long tail of trim would bury them.
	found.sort_custom(func(a, b): return a["face"] > b["face"])

	print("\n[OWN] %d masses intersect the street volume (face >= %.1f m2)"
			% [found.size(), MIN_FACE])
	print("[OWN] %-30s %-26s %9s %-22s %s"
			% ["node", "parent", "face m2", "size (x,y,z)", "material"])
	for f in found:
		print("[OWN] %-30s %-26s %9.1f %-22s %s"
				% [f["name"].substr(0, 30), f["parent"].substr(0, 26),
				f["face"], f["size"], f["mat"]])

	# Group by parent so a merged buffer reads as one owner rather than
	# as a hundred anonymous boxes.
	var by_parent := {}
	for f in found:
		var k: String = f["parent"]
		by_parent[k] = float(by_parent.get(k, 0.0)) + f["face"]
	var keys := by_parent.keys()
	keys.sort_custom(func(a, b): return by_parent[a] > by_parent[b])
	print("\n[OWN] --- total street-facing area by owner ---")
	for k in keys:
		print("[OWN] %9.1f m2  %s" % [by_parent[k], k])
	get_tree().quit(0)


func _walk(n: Node, box: AABB, out: Array) -> void:
	# Traffic is drawn as MultiMeshInstance3D, which does NOT inherit
	# MeshInstance3D — walking only MeshInstance3D silently skips every
	# vehicle, which is exactly the class of mass this check exists to
	# name. Report each instance separately so a car in the carriageway
	# is distinguishable from a static obstruction.
	if n is MultiMeshInstance3D and n.multimesh != null \
			and n.multimesh.mesh != null:
		var mm: MultiMesh = n.multimesh
		var local := mm.mesh.get_aabb()
		for i in mm.instance_count:
			var world: AABB = (n.global_transform
					* mm.get_instance_transform(i)) * local
			if not world.intersects(box):
				continue
			var vs := world.size
			var vface: float = maxf(vs.x * vs.y,
					maxf(vs.z * vs.y, vs.x * vs.z))
			if vface < MIN_FACE:
				continue
			out.append({
				"name": "%s#%d" % [String(n.name), i],
				"parent": "MOVING/%s" % (String(n.get_parent().name)
						if n.get_parent() else "-"),
				"face": vface,
				"size": "%.1f,%.1f,%.1f" % [vs.x, vs.y, vs.z],
				"mat": _mm_mat(n, mm),
			})
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		var world: AABB = mi.global_transform * mi.get_aabb()
		if world.intersects(box):
			var s: Vector3 = world.size
			# Footprint, not volume: a tall thin hoarding and a wide flat
			# slab both read as a mass in frame, a lamp post does not.
			var face: float = maxf(s.x * s.y, maxf(s.z * s.y, s.x * s.z))
			if face >= MIN_FACE:
				out.append({
					"name": String(n.name),
					"parent": String(n.get_parent().name)
							if n.get_parent() else "-",
					"face": face,
					"size": "%.1f,%.1f,%.1f" % [s.x, s.y, s.z],
					"mat": _mat_of(n),
				})
	for c in n.get_children():
		_walk(c, box, out)


func _mm_mat(n: MultiMeshInstance3D, mm: MultiMesh) -> String:
	var mat: Material = n.material_override
	if mat == null and mm.mesh.get_surface_count() > 0:
		mat = mm.mesh.surface_get_material(0)
	if mat == null:
		return "NONE (unlit default)"
	var label := String(mat.resource_name)
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		label += " [albedo=%.2f,%.2f,%.2f shaded=%s]" % [
				sm.albedo_color.r, sm.albedo_color.g, sm.albedo_color.b,
				"no" if sm.shading_mode
						== BaseMaterial3D.SHADING_MODE_UNSHADED else "yes"]
	return label if label.strip_edges() != "" else String(mat.get_class())


func _mat_of(m: MeshInstance3D) -> String:
	var mat: Material = m.material_override
	if mat == null and m.mesh.get_surface_count() > 0:
		mat = m.get_active_material(0)
	if mat == null:
		return "-"
	var label := String(mat.resource_name)
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		var tex := "tex" if sm.albedo_texture != null else "flat"
		label += " [%s albedo=%.2f,%.2f,%.2f]" % [tex,
				sm.albedo_color.r, sm.albedo_color.g, sm.albedo_color.b]
	return label if label != "" else String(mat.get_class())
