extends RefCounted
## Static resting bar pets and a real counter recess; gameplay owners stay separate.
const Furniture := preload("res://scripts/building/orison_v2_bar_furniture.gd")
const EntryRetirement := preload("res://scripts/building/harukiya_entry_retirement.gd")
const CELL := "res://assets/building/floor_01_cells/shop_bar.gltf"
const ROOT := "HarukiyaPets"
const DATA := "res://data/orison_v2/harukiya_pets.json"
var errors: Array[String] = []
var audit: Dictionary = {}
var _root: Node3D
var _draw: MeshInstance3D
var _shape: CollisionShape3D
var _before: Dictionary = {}

func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if data is not Dictionary: return _fail("pet manifest")
	if not is_instance_valid(cell) or cell.has_node(ROOT) or _root != null: return _fail("already mounted or missing cell")
	if data.get("schema_version") != 1 or data.get("animals") is not Array or data.animals.size() != 2: return _fail("manifest schema")
	# Editor sources retain byte checks. Exported remapped scenes retain the
	# exact loaded stock/triangle/material checks below without shipping raw sources.
	if FileAccess.file_exists(CELL) and FileAccess.get_file_as_string(CELL).replace("\r\n", "\n").sha256_text() != data.cell_lf_sha256: return _fail("original source cell hash")
	if FileAccess.file_exists(CELL.get_basename()+".bin") and FileAccess.get_sha256(CELL.get_basename()+".bin") != data.bin_sha256: return _fail("original source bin hash")
	var catalogue: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/material_catalog.json"))
	if catalogue is not Dictionary: return _fail("material catalogue")
	var names := {}
	for animal: Dictionary in data.animals:
		for part: Dictionary in animal.parts:
			for surface: Dictionary in part.surfaces: names[str(surface.material)]=true
	var material_keys := {}
	for identity: String in names: material_keys[identity]=identity
	if names.size() != 8: return _fail("eight exact registered animal materials")
	for identity: String in names:
		if not material_keys.has(identity) or not catalogue.has(str(material_keys[identity])): return _fail("unregistered animal recipe "+identity)
	var stocks: Array = []
	for floor: Dictionary in layout.floors:
		if str(floor.id) == "F01":
			for row: Dictionary in floor.furniture:
				if str(row.id) == "retail_bar_counter": stocks.append(row)
	if stocks.size() != 1 or stocks[0] != data.source_record or str(data.source_record.mat) != "wood_dark": return _fail("exact counter stock record")
	var stock: Dictionary = data.source_record
	if stock.rect != [-5.1,-30.28,1.2,-29.6] or not is_equal_approx(float(stock.h),1.02) or not is_equal_approx(float(stock.z0),-2.8): return _fail("counter source envelope")
	var record: Dictionary = data.retirement
	if int(record.count) != 12 or record.triangles.size() != 12 or int(record.source_triangles) != 180: return _fail("exact twelve retirement")
	var draw := cell.get_node_or_null(str(record.name)) as MeshInstance3D
	if draw == null or draw.get_parent() != cell or draw.mesh is not ArrayMesh or draw.transform != Transform3D.IDENTITY: return _fail("source draw ABI")
	var shapes := draw.find_children("*", "CollisionShape3D", true, false)
	if shapes.size() != 1: return _fail("source collision multiplicity")
	# Existing production renderer matcher; no box-based or new triangle deletion.
	var replacement := Furniture._without_source_triangles(draw, record)
	if replacement == null or not EntryRetirement._packed_remainder_preserved(draw.mesh as ArrayMesh, replacement, 12): return _fail("current packed remainder")
	var extent := draw.mesh.get_aabb().size
	var tolerance := .00003 + maxf(extent.x, maxf(extent.y, extent.z))/65535.0
	# Existing independent collision face matcher, preserving original shape flags.
	var collision := EntryRetirement._prepare_collision(draw, shapes[0] as CollisionShape3D, record, tolerance)
	if collision.is_empty() or collision.empty: return _fail("current collision remainder")
	var model := Node3D.new(); model.name = ROOT
	if not _counter(model, data.counter): model.free(); return false
	var seen := {}
	for animal: Dictionary in data.animals:
		if str(animal.id) not in ["judge", "lafitte"] or seen.has(str(animal.id)):
			model.free(); return _fail("animal identity")
		seen[str(animal.id)] = true
		var pet := _load(animal)
		if pet == null: model.free(); return false
		if not _animal_bindings(pet, animal.parts, material_keys, catalogue): pet.free(); model.free(); return _fail("asset-owned animal PBR bindings")
		pet.name = str(animal.id)
		var at: Array = animal.source_at
		if at.size() != 3: pet.free(); model.free(); return _fail("pet source position")
		var position := Vector3(at[0],at[1],at[2])
		if not position.is_finite(): pet.free(); model.free(); return _fail("pet nonfinite position")
		pet.position = GameBoot.b2g(at) # once, beneath retained cell frame
		pet.set_meta("harukiya_pet_identity", str(animal.id)); model.add_child(pet)
	# Commit after every source, collision and new asset was independently prepared.
	_draw=draw; _shape=shapes[0] as CollisionShape3D
	_before={"mesh":draw.mesh,"shape":_shape.shape,"disabled":_shape.disabled}
	draw.mesh=replacement; _shape.shape=collision.shape
	_root=model; cell.add_child(model)
	audit={"removed_render_triangles":12,"removed_collision_triangles":12,"counter_triangles":80,
		"pets":["judge","lafitte"],"prior_remainder_preserved":true,"animal_collision":false}
	model.set_meta("harukiya_pets_audit",audit)
	return true

func restore() -> void:
	if is_instance_valid(_draw) and not _before.is_empty(): _draw.mesh=_before.mesh
	if is_instance_valid(_shape) and not _before.is_empty():
		_shape.shape=_before.shape; _shape.disabled=_before.disabled
	if is_instance_valid(_root): _root.free()
	_root=null; _draw=null; _shape=null; _before.clear()

func _load(spec: Dictionary) -> Node3D:
	if FileAccess.file_exists(str(spec.asset)) and FileAccess.get_sha256(str(spec.asset)) != str(spec.sha256): _fail("native asset bytes"); return null
	var packed := load(str(spec.asset)) as PackedScene
	if packed == null: _fail("native PackedScene"); return null
	var model := packed.instantiate() as Node3D
	if model == null: _fail("native root"); return null
	if model.transform != Transform3D.IDENTITY: model.free(); _fail("native root transform"); return null
	return model

func _counter(parent: Node3D, spec: Dictionary) -> bool:
	var model := _load(spec)
	if model == null: return false
	var expected := {}; var seen := {}; var total := 0
	for part: Dictionary in spec.parts: expected[str(part.name)] = part
	if expected.size() != 2: model.free(); return _fail("two native counter partitions")
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not expected.has(str(draw.name)) or seen.has(str(draw.name)) or draw.transform != Transform3D.IDENTITY or draw.mesh == null or draw.mesh.get_surface_count() != 1: model.free(); return _fail("counter inventory")
		var row: Dictionary = expected[str(draw.name)]
		var count: int = draw.mesh.get_faces().size()/3
		if count != int(row.surfaces[0].triangles): model.free(); return _fail("counter triangle count")
		total+=count; seen[str(draw.name)] = true
		var recipe: Dictionary = row.recipe; var key := str(recipe.catalog_key)
		if key not in ["wood_dark","timber"] or not MatLib.SETS.has(key) or not is_equal_approx(float(recipe.tile),float(MatLib.SETS[key][3])): model.free(); return _fail("counter catalogue recipe")
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar=false; material.uv1_scale=Vector3.ONE/float(recipe.tile)
		material.roughness=float(recipe.roughness); material.normal_scale=float(recipe.normal)
		var tint: Array = recipe.tint; material.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
		if material.albedo_texture == null or material.roughness_texture == null or material.normal_texture == null: model.free(); return _fail("counter map triplet")
		draw.mesh=draw.mesh.duplicate() as ArrayMesh; draw.mesh.surface_set_material(0,material)
		draw.set_meta("material_key",key); draw.set_meta("harukiya_pet_counter_part",str(draw.name))
		draw.name="F01_retail_bar_pet_"+str(draw.name)
		# Actual imported concave faces preserve the open recess. No convex hull.
		draw.create_trimesh_collision()
	if seen.size() != 2 or total != 80: model.free(); return _fail("counter complete eighty triangles")
	model.name="CounterRecess"; parent.add_child(model)
	return true

func _animal_bindings(model: Node3D, parts: Array, material_keys: Dictionary, catalogue: Dictionary) -> bool:
	var expected := {}; var seen := {}
	for part: Dictionary in parts: expected[str(part.name)] = part
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not expected.has(str(draw.name)) or seen.has(str(draw.name)) or draw.transform != Transform3D.IDENTITY or draw.skin != null or draw.mesh == null or draw.mesh.get_blend_shape_count() != 0: return false
		var surfaces: Array = expected[str(draw.name)].surfaces
		if draw.mesh.get_surface_count() != surfaces.size() or draw.material_override != null: return false
		for index in surfaces.size():
			var row: Dictionary = surfaces[index]
			var material := draw.mesh.surface_get_material(index) as StandardMaterial3D
			if material == null or material.resource_name != str(row.material) or draw.get_surface_override_material(index) != null: return false
			if material.albedo_texture == null or material.roughness_texture == null or material.normal_texture == null or not material.normal_enabled: return false
			if material.albedo_color != Color.WHITE or material.metallic != float(row.metallic_factor) or material.roughness != float(row.roughness_factor) or material.normal_scale != float(row.normal_scale): return false
			var scale: Array = row.uv_scale; var offset: Array = row.uv_offset
			var key := str(material_keys[str(row.material)])
			if material.uv1_triplanar or material.uv2_triplanar or material.uv1_scale != Vector3(scale[0],scale[1],1) or material.uv1_offset != Vector3(offset[0],offset[1],0): return false
			var recipe: Dictionary = catalogue[key]
			if recipe.get("base_color",[]) != [1,1,1,1] or float(recipe.get("roughness",-1)) != material.roughness or float(recipe.get("metallic",-1)) != material.metallic: return false
			if float(scale[0]) <= 0.0 or not is_equal_approx(float(scale[0]),float(scale[1])): return false
			if material.roughness_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_GREEN or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.cull_mode != BaseMaterial3D.CULL_DISABLED or material.next_pass != null: return false
			var mesh := draw.mesh as ArrayMesh
			if mesh == null or mesh.surface_get_array_index_len(index)/3 != int(row.triangles): return false
		draw.set_meta("pet_asset_materials",material_keys.duplicate())
		seen[str(draw.name)]=true
	return seen.size() == expected.size()

func _fail(reason: String) -> bool:
	errors.append(reason); push_error("Harukiya pets: "+reason)
	return false
