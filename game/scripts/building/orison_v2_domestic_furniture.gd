extends RefCounted
## Individual source-derived assemblies. Adapter owns placement and teardown.
const PATH := "res://data/orison_v2/domestic_furniture.json"
var _owner_finishes := preload("res://scripts/building/orison_v2_owner_finishes.gd").new()
const BEDDING := preload("res://assets/props/bedding.glb")
const WaterCloset := preload("res://scripts/building/orison_v2_water_closet.gd")
const Wardrobe := preload("res://scripts/building/orison_v2_wardrobe.gd")
const PrepCabinet := preload("res://scripts/building/orison_v2_prep_cabinet.gd")
const SpecialistRadio := preload("res://scripts/building/orison_v2_specialist_radio.gd")
const WorkTables := preload("res://scripts/building/orison_v2_work_tables.gd")
const NativeFurniture := preload("res://scripts/building/orison_v2_native_domestic_furniture.gd")
const NativeStorage := preload("res://scripts/building/orison_v2_native_domestic_storage.gd")
const NativePrep := preload("res://scripts/building/orison_v2_native_prep_cabinets.gd")
const NativeWardrobes := preload("res://scripts/building/orison_v2_native_household_wardrobes.gd")
const NativeRadios := preload("res://scripts/building/orison_v2_native_household_radios.gd")
const NativeObjects := preload("res://scripts/building/orison_v2_native_domestic_objects.gd")
const NATIVE_KINDS := ["chair", "sofa", "nightstand", "table_round", "table_rect", "coffee"]
const STORAGE_KINDS := ["shelf", "cupboard", "counter"]
const OBJECT_KINDS := ["pinboard","toolboard","crate","softbox","cablecoil","plant","bookpile","tripod","reeldeck","hallstand","artframe","garmentrail","blanket","hamper","boottray","suitcase","sewingmachine","teardown","easel","canvasstack","cardcabinet","backdroprail","printline","hookstrip","coathook","headsethook","foldedcot"]
const MATERIAL_ALIASES := {"floor_oak": "oak_quartered", "fabric_cool": "linen", "fabric_green": "linen"}
const GARMENT_TINTS := {"fabric_cool": Color(0.36, 0.42, 0.51), "fabric_green": Color(0.38, 0.46, 0.36)}
var errors: Array[String] = []

func mount(adapter: Variant) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return mount_source(adapter, source)

func mount_source(adapter: Variant, source: Variant) -> bool:
	if not validate(source, adapter):
		return false
	var native: NativeFurniture
	if adapter.root.has_meta("v2_native_domestic_factory"):
		native = adapter.root.get_meta("v2_native_domestic_factory") as NativeFurniture
	if native == null:
		native = NativeFurniture.new()
		if not native.prepare():
			errors.append("native domestic variants refused")
			return false
		adapter.root.set_meta("v2_native_domestic_factory",native)
	var storage: NativeStorage
	if adapter.root.has_meta("v2_native_storage_factory"):
		storage = adapter.root.get_meta("v2_native_storage_factory") as NativeStorage
	if storage == null:
		storage = NativeStorage.new()
		if not storage.prepare():
			errors.append("native storage variants refused")
			return false
		adapter.root.set_meta("v2_native_storage_factory",storage)
	var prep: NativePrep
	if adapter.root.has_meta("v2_native_prep_factory"):
		prep = adapter.root.get_meta("v2_native_prep_factory") as NativePrep
	if prep == null:
		prep = NativePrep.new()
		if not prep.prepare():
			errors.append("native preparation cabinet refused")
			return false
		adapter.root.set_meta("v2_native_prep_factory",prep)
	var wardrobes: NativeWardrobes
	if adapter.root.has_meta("v2_native_wardrobe_factory"):
		wardrobes = adapter.root.get_meta("v2_native_wardrobe_factory") as NativeWardrobes
	if wardrobes == null:
		wardrobes = NativeWardrobes.new()
		if not wardrobes.prepare():
			errors.append("native household wardrobes refused")
			return false
		adapter.root.set_meta("v2_native_wardrobe_factory",wardrobes)
	var objects: NativeObjects
	if adapter.root.has_meta("v2_native_object_factory"):
		objects = adapter.root.get_meta("v2_native_object_factory") as NativeObjects
	if objects == null:
		objects = NativeObjects.new()
		if not objects.prepare():
			errors.append("native household objects refused")
			return false
		adapter.root.set_meta("v2_native_object_factory",objects)
	var radios: NativeRadios
	if adapter.root.has_meta("v2_native_radio_factory"):
		radios = adapter.root.get_meta("v2_native_radio_factory") as NativeRadios
	if radios == null:
		radios = NativeRadios.new()
		if not radios.prepare():
			errors.append("native household radios refused")
			return false
		adapter.root.set_meta("v2_native_radio_factory",radios)
	for record: Dictionary in source.furniture:
		var native_table: bool = str(record.id) in WorkTables.IDS
		var native_furniture: bool = record.kind in NATIVE_KINDS and not native_table
		var native_storage: bool = record.kind in STORAGE_KINDS
		var native_object: bool = record.kind in OBJECT_KINDS
		var body: StaticBody3D
		if record.kind == "toilet":
			body = WaterCloset.new()
			body.call("setup", {"id": record.id, "asm": "toilet"})
			body.set("model_path", str(record.model))
		elif record.kind == "wardrobe":
			body = Wardrobe.new()
			body.call("setup", record.mechanism)
			body.set_meta("v2_wardrobe_factory",wardrobes)
		elif record.kind == "radio":
			body = SpecialistRadio.new()
			body.call("setup", record.mechanism)
			body.set_meta("v2_radio_factory",radios)
		else:
			body = PrepCabinet.new() if record.kind == "prep_cabinet" else StaticBody3D.new()
			if record.kind == "prep_cabinet": body.call("setup", str(record.mechanism.unit))
			if not native_table and not native_furniture and not native_storage and not native_object and record.kind != "bed" and not record.get("collision_from_surfaces", false):
				for box: Array in record.get("collision_boxes", [record.bounds]):
					var collision := CollisionShape3D.new()
					var shape := BoxShape3D.new()
					var low := _vector(box[0])
					var high := _vector(box[1])
					shape.size = high - low
					collision.shape = shape
					collision.position = (high + low) * 0.5
					body.add_child(collision)
		body.set_meta("v2_furniture_id", str(record.id))
		if native_table:
			if not WorkTables.mount_on(body, str(record.id), record):
				body.free()
				errors.append("native work table mount refused: " + str(record.id))
				return false
		elif native_furniture:
			if not native.mount_on(body,str(record.id)):
				body.free(); native.finish()
				errors.append("native domestic furniture mount refused: " + str(record.id))
				return false
		elif native_storage:
			if not storage.mount_on(body,str(record.id)):
				body.free(); storage.finish()
				errors.append("native storage mount refused: " + str(record.id))
				return false
		elif native_object:
			if not objects.mount_on(body,str(record.id)):
				body.free(); objects.finish()
				errors.append("native household object mount refused: " + str(record.id))
				return false
		elif record.kind == "prep_cabinet":
			if not prep.mount_on(body,str(record.id)):
				body.free(); prep.finish()
				errors.append("native preparation cabinet mount refused: " + str(record.id))
				return false
		elif record.kind == "bed": _add_bed(body,record)
		elif record.kind not in ["toilet","wardrobe","radio"]: _add_surfaces(body, record.surfaces)
		if not native_table and not native_furniture and not native_storage and not native_object and record.get("collision_from_surfaces", false):
			# Separate tabletop/paper/leg triangles preserve the actual bearings;
			# one enclosing box would fill the space above a desk up to its stock.
			for child: Node in body.get_children():
				if not child is MeshInstance3D: continue
				var visual := child as MeshInstance3D
				var collision := CollisionShape3D.new()
				collision.shape = visual.mesh.create_trimesh_shape()
				collision.transform = visual.transform
				body.add_child(collision)
		if not adapter.mount_consumer(str(record.id), body):
			body.free()
			errors.append("furniture mount refused: " + str(record.id))
			return false
		if record.kind in ["wardrobe","radio"] and not body.get("native_ready"):
			errors.append("native household mechanism mount refused: " + str(record.id))
			return false
	return true

func validate(source: Variant, adapter: Variant) -> bool:
	errors.clear()
	if source is not Dictionary or source.get("schema_version") != 1 or source.get("furniture") is not Array:
		errors.append("malformed furniture source")
		return false
	var seen: Dictionary = {}
	for record: Variant in source.furniture:
		if record is not Dictionary or record.get("id") is not String or record.get("kind") not in ["bed", "workbench", "toilet", "nightstand", "wardrobe", "shelf", "sofa", "counter", "desk", "chair", "table_round", "table_rect", "cupboard", "coffee", "crate", "pinboard", "toolboard", "prep_cabinet", "radio", "reeldeck", "plant", "tripod", "softbox", "cablecoil", "bookpile", "hallstand", "artframe", "garmentrail", "blanket", "hamper", "boottray", "suitcase", "sewingmachine", "teardown", "easel", "canvasstack", "cardcabinet", "backdroprail", "printline", "hookstrip", "coathook", "headsethook", "foldedcot"]:
			errors.append("invalid furniture identity or kind")
			continue
		if seen.has(record.id) or adapter == null or not adapter.resolve(record.id) is Node3D:
			errors.append("duplicate or missing furniture anchor: " + str(record.id))
		seen[record.id] = true
		if record.kind == "radio":
			var mechanism: Variant = record.get("mechanism")
			if mechanism is not Dictionary or mechanism.size() != 2 \
					or mechanism.get("asm") != "radio" or mechanism.get("id") != record.id:
				errors.append("invalid specialist radio mechanism")
		if record.kind == "prep_cabinet":
			var mechanism: Variant = record.get("mechanism")
			if mechanism is not Dictionary or mechanism.size() != 1 \
					or mechanism.get("unit") not in ["1A", "1D", "2A", "2B", "2C", "3A", "3B", "3D", "4A", "4B", "4C", "4D", "5A", "5B", "5C", "6A", "6B", "6C"] \
					or not str(record.id).begins_with(str(mechanism.get("unit", "")) + "_") \
					or not record.has("collision_boxes"):
				errors.append("invalid preparation cabinet mechanism")
		if record.kind == "wardrobe":
			var mechanism: Variant = record.get("mechanism")
			if mechanism is not Dictionary or mechanism.size() != 4 \
					or mechanism.get("id") != record.id or mechanism.get("asm") != "wardrobe" \
					or mechanism.get("W") != 1.3 or mechanism.get("case_wood") not in ["oak_quartered", "wood_dark"]:
				errors.append("invalid household wardrobe mechanism")
		var bounds: Variant = record.get("bounds")
		if bounds is not Array or bounds.size() != 2 or not _numbers(bounds[0], 3) or not _numbers(bounds[1], 3):
			errors.append("invalid furniture bounds")
			continue
		for axis in range(3):
			if bounds[1][axis] <= bounds[0][axis]:
				errors.append("inverted furniture bounds")
		if record.kind == "bed":
			var size := _vector(bounds[1])-_vector(bounds[0])
			var supported := false
			for expected in [Vector3(1.35,.99,2.6),Vector3(1.4,.99,2.05),Vector3(1.5,.99,2.05)]:
				if size.is_equal_approx(expected) and _vector(bounds[0]).is_equal_approx(Vector3(-expected.x*.5,0,-expected.z*.5)):supported=true
			if not supported:errors.append("bed bounds require a rebuilt Blender variant")
		if record.kind == "prep_cabinet" and (not _vector(bounds[0]).is_equal_approx(Vector3(-.415,0,-.29)) \
				or not _vector(bounds[1]).is_equal_approx(Vector3(.415,.9,.245))):
			errors.append("preparation cabinet bounds do not cover its fixed mechanism")
		if record.kind == "radio" and (not _vector(bounds[0]).is_equal_approx(Vector3(-.24,-.03,-.19)) \
				or not _vector(bounds[1]).is_equal_approx(Vector3(.24,.31,.15))):
			errors.append("specialist radio bounds do not match its native collision")
		if record.has("collision_boxes"):
			var boxes: Variant = record.collision_boxes
			if record.kind not in ["desk", "counter", "prep_cabinet"] or boxes is not Array \
					or boxes.is_empty() or boxes.size() > 64:
				errors.append("invalid furniture collision pieces")
				continue
			for box: Variant in boxes:
				if box is not Array or box.size() != 2 \
						or not _numbers(box[0], 3) or not _numbers(box[1], 3):
					errors.append("invalid furniture collision box")
					continue
				for axis in range(3):
					if box[1][axis] <= box[0][axis] \
							or box[0][axis] < bounds[0][axis] \
							or box[1][axis] > bounds[1][axis]:
						errors.append("furniture collision box exceeds its bounds")
		if record.has("collision_from_surfaces") and (record.collision_from_surfaces != true \
				or typeof(record.collision_from_surfaces) != TYPE_BOOL \
				or record.kind not in ["desk", "table_rect"] or record.has("collision_boxes")):
			errors.append("invalid explicit furniture surface collision")
		if record.kind == "toilet":
			if record.get("model") != WaterCloset.MODEL or record.has("surfaces"):
				errors.append("water closet must use its Blender assembly")
		else:
			_validate_surfaces(record.get("surfaces"))
	if seen.is_empty():
		errors.append("empty furniture source")
	return errors.is_empty()

func _bed_variant(record: Dictionary) -> String:
	var low := _vector(record.bounds[0])
	var high := _vector(record.bounds[1])
	return "Bed_%d_%d" % [roundi((high.x-low.x)*100),roundi((high.z-low.z)*100)]

func _add_bed(body: StaticBody3D, record: Dictionary) -> void:
	var library := BEDDING.instantiate()
	var model := library.get_node(_bed_variant(record)).duplicate() as Node3D
	body.add_child(model);library.free()
	var wood := "oak_quartered"
	var blanket := "fabric_warm"
	for surface: Dictionary in record.surfaces:
		if surface.material in ["oak_quartered","wood_dark"]:wood=surface.material
		if str(surface.material).begins_with("fabric_"):blanket=surface.material
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var role := str(mesh.name).trim_prefix(str(model.name)+"_")
		mesh.material_override=_material(wood if role=="Frame" else (blanket if role=="Blanket" else "linen"))
		mesh.material_override=_owner_finishes.material_for(mesh.material_override,"domestic" if role=="Frame" else "bedding_"+role)
		var collision := CollisionShape3D.new()
		collision.shape=mesh.mesh.create_trimesh_shape()
		collision.transform=model.transform*mesh.transform
		body.add_child(collision)
	body.set_meta("v2_owner_finish_group","bedding")
	body.set_meta("v2_owner_finish_slots",4)

func _add_surfaces(body: Node3D, surfaces: Array) -> void:
	for surface: Dictionary in surfaces:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		for i in range(0, surface.vertices.size(), 3):
			vertices.append(Vector3(surface.vertices[i], surface.vertices[i + 1], surface.vertices[i + 2]))
			normals.append(Vector3(surface.normals[i], surface.normals[i + 1], surface.normals[i + 2]))
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = _material(str(surface.material))
		body.add_child(visual)
		if surface.material == "glassish":
			preload("res://scripts/lamp/lamp_optical_receivers.gd").add_glass_haze(visual)

func _validate_surfaces(surfaces: Variant) -> void:
	if surfaces is not Array or surfaces.is_empty():
		errors.append("missing furniture surfaces")
		return
	for surface: Variant in surfaces:
		if surface is not Dictionary or surface.get("material") is not String:
			errors.append("invalid furniture surface")
			continue
		if surface.material != "glassish" and not MatLib.SETS.has(MATERIAL_ALIASES.get(surface.material, surface.material)):
			errors.append("unknown furniture material")
		var vertices: Variant = surface.get("vertices")
		if vertices is not Array or vertices.is_empty() or vertices.size() % 9 != 0:
			errors.append("invalid furniture triangles")
			continue
		if not _numbers(vertices, vertices.size()) or not _numbers(surface.get("normals"), vertices.size()):
			errors.append("invalid furniture coordinates or normals")

func _numbers(values: Variant, count: int) -> bool:
	if values is not Array or values.size() != count:
		return false
	for value: Variant in values:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	return true

func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func _material(key: String) -> Material:
	if key == "glassish":
		var glass := ShaderMaterial.new()
		glass.shader = preload("res://shaders/lamp_glass_surface.gdshader")
		return glass
	var material := MatLib.get_mat(str(MATERIAL_ALIASES.get(key, key)), GARMENT_TINTS.get(key, Color.WHITE))
	if GARMENT_TINTS.has(key):
		material = material.duplicate() as StandardMaterial3D
		material.roughness = 0.92
	return material
