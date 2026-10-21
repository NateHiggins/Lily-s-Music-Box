extends RefCounted
## Source-owned arcade fabric. Existing actors and cell lifecycle are retained.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
const ArchitecturalMaterials := preload("res://scripts/building/orison_v2_architectural_materials.gd")
const CANOPY := "res://data/orison_v2/arcade_canopy.json"

static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return mount_canopy(cell,layout) and mount_throat(cell,layout) and mount_lantern(cell,layout) and mount_clock(cell,layout) and mount_retained_finishes(cell,layout)

static func mount_throat(cell: Node3D,layout: Dictionary) -> bool:
	return str(cell.name)!="passage" or Seating.mount_arcade_throat(cell,layout) or _refuse("throat source boundary/native fitting")

static func mount_lantern(cell: Node3D,layout: Dictionary) -> bool:
	return str(cell.name)!="passage" or Seating.mount_arcade_lantern(cell,layout) or _refuse("lantern source boundary/native fitting")

static func mount_clock(cell: Node3D,layout: Dictionary) -> bool:
	return str(cell.name)!="passage" or preload("res://scripts/building/orison_v2_arcade_clock.gd").mount_cell(cell,layout) or _refuse("clock source boundary/native fitting")

static func mount_canopy(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name) != "passage": return true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CANOPY))
	if data is not Dictionary: return false
	var ornaments: Array[MeshInstance3D] = []
	for row: Dictionary in data.legacy_ornaments:
		var matches: Array[MeshInstance3D] = []
		for candidate: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
			if str(candidate.name) == str(row.name): matches.append(candidate)
		if matches.size() != 1: return _refuse("decorative draw count: " + str(row.name) + " = " + str(matches.size()))
		var draw := matches[0]
		if draw.mesh == null or draw.mesh.get_surface_count() != 1 or not draw.find_children("*", "CollisionShape3D", true, false).is_empty(): return _refuse("decorative mesh/collision ownership: " + str(row.name))
		var arrays := draw.mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var triangles := indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		if triangles != int(row.triangles): return _refuse("decorative triangle count: " + str(row.name) + " = " + str(triangles))
		var bounds: AABB = draw.transform * draw.mesh.get_aabb()
		if bounds.position.distance_to(_v(row.low)) > .001 or bounds.end.distance_to(_v(row.high)) > .001: return _refuse("decorative bounds: " + str(row.name) + " = " + str(bounds))
		ornaments.append(draw)
	if ornaments.size() != 3: return false
	if not Seating.mount_arcade_canopy(cell, layout): return _refuse("canopy source boundary/native fitting")
	var model := cell.get_node("ArcadeCanopy") as Node3D
	var optics: Dictionary = data.optics
	if optics.role != "Glazing" or optics.room_class != "public" or optics.registered_owner != "res://scripts/building/orison_v2_architectural_materials.gd" or optics.shader != "res://shaders/lamp_glass_surface.gdshader" or not is_equal_approx(float(optics.surface_roughness), .06): return false
	var glass := ArchitecturalMaterials.new().material_for("Glazing", "public") as ShaderMaterial
	if glass == null or glass.shader.resource_path != str(optics.shader): return false
	glass.set_shader_parameter("surface_roughness", float(optics.surface_roughness))
	var glass_draws := 0
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if str(draw.get_meta("arcade_canopy_part", "")) != "canopy__glassish": continue
		draw.set_meta("glazing_source_surface", draw.mesh.surface_get_material(0))
		draw.material_override = glass
		glass_draws += 1
	if glass_draws != 1: return false
	model.set_meta("optical_material", glass)
	model.set_meta("retired_ornament_draws", ornaments.size())
	for draw: MeshInstance3D in ornaments: draw.free()
	return true

static func mount_retained_finishes(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="passage":return true
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(CANOPY))
	if data is not Dictionary:return false
	var model:=cell.get_node("ArcadeCanopy") as Node3D
	if model==null:return false
	# The retained source charts are already baked in their original metre
	# scale. Convert those charts rather than applying a second generic scale.
	var converted := {"terrazzo": 0, "terrazzo_dark": 0, "common_brick": 0}
	var finishes := {}
	for row: Dictionary in data.retained_finish_draws:
		var identity := str(row.name) + (":solid" if bool(row.colliding) else ":detail")
		if finishes.has(identity) or not converted.has(str(row.source_key)): return _refuse("duplicate/unknown retained source finish: " + identity)
		finishes[identity] = row
	var matched := {}
	for draw: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
		if draw.has_meta("material_key"): continue
		var identity := str(draw.name).trim_suffix("-col") + (":detail" if draw.find_children("*", "CollisionShape3D", true, false).is_empty() else ":solid")
		if not finishes.has(identity): continue
		if matched.has(identity): return _refuse("duplicate retained finish draw: " + identity)
		matched[identity] = true
		var row: Dictionary = finishes[identity]
		var source_key := str(row.source_key)
		if draw.mesh == null or draw.mesh.get_surface_count() != 1: return false
		var selected := str(row.catalog_key)
		if not MatLib.SETS.has(selected): return false
		var original_metres := float(row.source_metres)
		var stock := MatLib.get_mat(selected).duplicate() as StandardMaterial3D
		if stock.albedo_texture == null or stock.roughness_texture == null or stock.normal_texture == null or not stock.normal_enabled: return false
		stock.uv1_triplanar = false
		var scale := original_metres / float(MatLib.SETS[selected][3])
		stock.uv1_scale = Vector3(scale, scale, 1)
		draw.set_surface_override_material(0, stock)
		draw.set_meta("arcade_finish_key", selected)
		draw.set_meta("arcade_source_metres", original_metres)
		converted[source_key] += 1
	if matched.size() != finishes.size() or matched.size() != 6: return _refuse("retained finish counts: " + str(converted))
	model.set_meta("retained_finish_draws", converted)
	return true

static func _v(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

static func _refuse(reason: String) -> bool:
	push_error("Arcade fabric refused: " + reason)
	return false
