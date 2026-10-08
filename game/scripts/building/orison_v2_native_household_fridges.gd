extends "res://scripts/building/orison_v2_native_domestic_furniture.gd"
## One world cache; original door, ice hatch, service pan and lamp remain owners.
const PATH := "res://data/orison_v2/household_fridges.json"
var _foods: Array = []
var _fit: Dictionary = {}

func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not _prepare_family(data): return false
	_foods = data.foods
	_fit = data.visual_fit
	for row: Dictionary in data.assemblies:
		for i in row.parts.size():
			if row.parts[i].get("finish") is not Dictionary: return false
			var component := str(row.parts[i].component)
			if component not in ["Body", "Door", "IceDoor", "DripTray"]: return false
			_variants[str(row.id)][i]["component"] = component
	return true

func install_on(prop: FridgeProp) -> bool:
	var identity := str(prop.name)
	if not _instances.has(identity): return false
	var owners := {"Body":prop.get_node("StaticCarcass"), "Door":prop._door}
	if not prop.monitor_top:
		owners["IceDoor"] = prop._ice_door
		owners["DripTray"] = prop._tray
	for owner: Node3D in owners.values():
		for child: Node in owner.get_children():
			if child is MeshInstance3D:
				owner.remove_child(child)
				child.free()
	var variant: String = _instances[identity]
	var tints := {"oak":prop._oak_tint(), "enamel":prop._enamel_tint()}
	var local_materials := {}
	for part: Dictionary in _variants[variant]:
		var owner: Node3D = owners[part.component]
		var draw := MeshInstance3D.new()
		draw.name = part.name
		draw.mesh = part.mesh
		draw.transform = owner.transform.affine_inverse() * part.pose
		if tints.has(part.key):
			if not local_materials.has(part.key):
				var material := part.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
				material.albedo_color = tints[part.key]
				local_materials[part.key] = material
			draw.material_override = local_materials[part.key]
		draw.set_meta("native_fridge_part", part.name)
		draw.set_meta("material_key", part.key)
		owner.add_child(draw)
	for child: Node in prop.get_children():
		if not child.has_meta("source_larder_item"): continue
		var item := child as MeshInstance3D
		var source: Array = item.get_meta("source_larder_item")
		var matches := _foods.filter(func(row): return row.source_id == source[0] and is_equal_approx(float(row.width),float(source[2])) and is_equal_approx(float(row.height),float(source[3])))
		if matches.size() != 1: return false
		var prototype: Dictionary = matches[0]
		item.set_meta("source_larder_transform", item.transform)
		item.set_meta("source_larder_mesh", item.mesh)
		item.set_meta("source_larder_material", item.material_override)
		var shelves: Array = _fit.monitor_shelves if prop.monitor_top else _fit.icebox_shelves
		item.position.y = float(shelves[int(source[4])]) + float(_fit.shelf_bearing_offset)
		item.mesh = null
		item.material_override = null
		for part: Dictionary in _variants[str(prototype.id)]:
			var draw := MeshInstance3D.new()
			var material := part.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			if part.key in ["food", "paper", "bottle"]: material.albedo_color = source[1]
			draw.name = part.name
			draw.mesh = part.mesh
			draw.transform = part.pose
			draw.material_override = material
			draw.set_meta("native_larder_part", part.name)
			item.add_child(draw)
		if FridgeProp.LABEL_CELL.has(str(source[0])):
			var label := Label3D.new()
			label.name = "SourceBrand"
			label.text = str(source[0]).replace(" ", "\n")
			label.font_size = 32
			label.pixel_size = float(source[2]) / (32. * 11.)
			label.modulate = Color(.13,.15,.12)
			label.outline_size = 0
			label.no_depth_test = false
			label.position = Vector3(0,float(source[3])*.38,-float(source[2])*.501)
			if not str(source[0]).begins_with("MERIDIAN") and not str(source[0]).begins_with("PEERLESS") and not str(source[0]).begins_with("QUELL"):
				label.position.z = -float(source[2])*.401
			label.rotation.y = PI
			item.add_child(label)
		item.set_meta("native_larder_variant", prototype.id)
	prop.set_meta("v2_native_fridge_variant", variant)
	return true
