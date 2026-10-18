extends Node3D
## INERT native import/fit diagnosis. Composed game qualification is separate.
const Fabric := preload("res://scripts/building/orison_v2_arcade_fabric.gd")
var checks := 0
var failures: Array[String] = []
var externally_managed := false
var review_suite: Node

func _ready() -> void:
	if not externally_managed: _run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if review_suite != null: review_suite.check(value, message)
	if not value: failures.append(message); push_error(message)

func _ray(a: Vector3, b: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))

func _run() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	var packed := ResourceLoader.load("res://assets/building/orison_v2/passage/passage.gltf", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	_check(packed != null, "source cell imported")
	if packed == null: _finish(); return
	var cell := packed.instantiate() as Node3D
	cell.name = "passage"
	add_child(cell)
	var mounted := Fabric.mount_cell(cell, layout)
	_check(mounted, "source-fitted arcade fabric mounts")
	if not mounted: cell.free(); _finish(); return
	await validate_cell(cell, layout)
	cell.free()
	await get_tree().process_frame
	_finish()

func validate_cell(cell: Node3D, layout: Dictionary) -> void:
	var canopy: Node3D = cell.get_node("ArcadeCanopy")
	var throat: Node3D = cell.get_node("ArcadeThroat")
	var lantern: Node3D = cell.get_node("ArcadeLantern")
	var roof_removed: Dictionary = lantern.get_meta("removed_triangles")
	_check(roof_removed.size() == 3, "only three original lantern cap slabs retire")
	for identity: String in roof_removed:
		_check(identity.begins_with("site_passage_lantern_cap_") and int(roof_removed[identity]) == 12, "exact lantern source boundary: " + identity)
	var removed: Dictionary = canopy.get_meta("removed_triangles")
	_check(removed.size() == 34, "all 34 selected roof/gable/diaphragm source boxes retire")
	for id: String in removed: _check(int(removed[id]) == 12, "exact source boundary: " + id)
	_check(int(canopy.get_meta("retired_ornament_draws")) == 3, "three displaced legacy ceiling draws retire")
	_check((throat.get_meta("removed_triangles") as Dictionary).size() == 2, "two original throat walls retire through the existing owner")
	for draw: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
		_check(not str(draw.name).begins_with("V2_PASSAGE_finish_ceiling_"), "no old floating ceiling ornament")
		if not draw.has_meta("arcade_finish_key"): continue
		var stock := draw.get_surface_override_material(0) as StandardMaterial3D
		_check(stock != null and stock.normal_enabled and not stock.uv1_triplanar, "registered source draw has actual mapped normals")
		if not str(draw.get_meta("arcade_finish_key")).begins_with("arcade_terrazzo"): continue
		var arrays := draw.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in vertices.size(): indices.append(index)
		for start in range(0, indices.size(), 3):
			var a := indices[start]; var b := indices[start + 1]; var c := indices[start + 2]
			var area := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).length()
			var delta1 := uv[b] - uv[a]; var delta2 := uv[c] - uv[a]
			var determinant := absf(delta1.cross(delta2))
			if area < .000001: continue
			_check(determinant > 0., "retained floor UV triangle is not collapsed")
			if determinant <= 0.: continue
			var tile := sqrt(area / determinant) / stock.uv1_scale.x
			_check(absf(tile - .4) < .003, "actual imported floor chart remains 0.4 metres per repeat: " + str(draw.name) + " tile=" + str(tile) + " scale=" + str(stock.uv1_scale) + " basis=" + str(draw.basis))
	for key: String in ["arcade_terrazzo", "arcade_terrazzo_dark", "arcade_brick_face", "arcade_brick_bond", "arcade_lime_mortar"]:
		var material := MatLib.get_mat(key)
		_check(material.normal_enabled and is_equal_approx(material.normal_scale, 1.), "calibrated physical normal strength: " + key)
		for texture: Texture2D in [material.albedo_texture, material.roughness_texture, material.normal_texture]:
			_check(texture != null, "actual PBR map: " + key)
			if texture == null: continue
			var image := texture.get_image()
			_check(image != null and image.has_mipmaps(), "loaded mip chain: " + key)
			if image == null: continue
			var levels := 0; var width := maxi(image.get_width(), image.get_height())
			while width > 1: width = width >> 1; levels += 1
			_check(image.get_mipmap_count() == levels, "complete loaded mip chain: " + key)
	await get_tree().physics_frame; await get_tree().physics_frame
	var brick := _ray(cell.to_global(Vector3(11.2, 2.7375, 33.1)), cell.to_global(Vector3(10.9, 2.7375, 33.1)))
	var mortar := _ray(cell.to_global(Vector3(11.2, 2.7375, 33.2)), cell.to_global(Vector3(10.9, 2.7375, 33.2)))
	_check(not brick.is_empty() and absf(cell.to_local(brick.get("position", Vector3.ZERO)).x - 11.) < .0001, "brick collision retains original public wall face")
	_check(not mortar.is_empty() and absf(cell.to_local(mortar.get("position", Vector3.ZERO)).x - 10.9946) < .0001, "mortar collision is recessed 5.4 mm")
	if not brick.is_empty(): _check(str(brick.collider.get_parent().get_meta("arcade_throat_part", "")).begins_with("throat_face_"), "brick hit belongs to its native source-fitted wall")
	if not mortar.is_empty(): _check(str(mortar.collider.get_parent().get_meta("arcade_throat_part", "")) == "throat_mortar__common_brick", "joint hit belongs to the fitted lime backing")
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/arcade_canopy.json"))
	_check((record.cells[0].replace as Array).size() == 34, "runtime consumes the projected roof retirement set")
	# An interior pane away from a rib, ridge and decorative edge. Both its
	# outward and inward faces must be physically present after Godot import.
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	for floor: Dictionary in layout.floors:
		if floor.id != "F01": continue
		for row: Dictionary in floor.furniture:
			if row.id != "site_passage_rib_00_08": continue
			a = Vector3(row.p0[0], row.p0[2], 42.)
			b = Vector3(row.p1[0], row.p1[2], 42.)
	_check(a.distance_to(b) > .3, "glass probe uses retained source rib coordinates")
	var tangent := (b - a).normalized()
	var normal := Vector3(-tangent.y, tangent.x, 0)
	var center := (a + b) * .5 + normal * .049
	var outside := _ray(cell.to_global(center + normal * .2), cell.to_global(center - normal * .2))
	var inside := _ray(cell.to_global(center - normal * .2), cell.to_global(center + normal * .2))
	var world_normal := (cell.global_basis * normal).normalized()
	_check(not outside.is_empty() and outside.get("normal", Vector3.ZERO).dot(world_normal) > .999, "outer native glass surface is collidable")
	_check(not inside.is_empty() and inside.get("normal", Vector3.ZERO).dot(-world_normal) > .999, "native glass underside has its own outward normal")
	# Trace beneath the retained opal top light, stopping before its original
	# glass surface. These four paths were blocked by all three solid slabs.
	for x: float in [13.4, 14.6]:
		for z: float in [51.0, 52.2]:
			var well := _ray(cell.to_global(Vector3(x,10.8,z)), cell.to_global(Vector3(x,11.439,z)))
			_check(well.is_empty(), "loaded lantern has a real light well: " + str(Vector2(x,z)))
	for tier in 3:
		var x: float = [11.2,12.0,12.7][tier]
		var skin := _ray(cell.to_global(Vector3(x,10.8,52)), cell.to_global(Vector3(x,11.5,52)))
		var height: float = 11.12 + .16*tier - .022
		_check(not skin.is_empty() and absf(cell.to_local(skin.get("position",Vector3.ZERO)).y-height)<.00004, "native roof skin retains physical tier height: " + str(tier))
		if not skin.is_empty():
			_check((skin.get("normal",Vector3.ZERO) as Vector3).dot(cell.global_basis*Vector3.DOWN)>.999, "roof underside has its own outward normal: " + str(tier))
			_check(str(skin.collider.get_parent().get_meta("arcade_lantern_part",""))=="lantern_roof__cast_iron", "roof skin hit belongs to the native lantern: " + str(tier))
	var collar := _ray(cell.to_global(Vector3(14.035,10.89,51.6)), cell.to_global(Vector3(14.035,10.92,51.6)))
	_check(not collar.is_empty() and absf(cell.to_local(collar.get("position",Vector3.ZERO)).y-10.9)<.00004, "closed native clock hanger meets the original stem endpoint")

func _finish() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var file := FileAccess.open(directory.path_join("arcade_fit_diagnostic.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"evidence_class":"INERT", "checks":checks, "failures":failures, "scope":"Imported cell fit/mips/collision diagnosis, not composed-world acceptance."}, "\t")); file.close()
	print("ARCADE FABRIC BENCH ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
