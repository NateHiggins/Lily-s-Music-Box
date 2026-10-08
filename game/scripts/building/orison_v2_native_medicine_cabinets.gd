extends "res://scripts/building/orison_v2_native_domestic_furniture.gd"
## Keep the source mirror node, hinge, inventory and reflection material owner.
const PATH := "res://data/orison_v2/medicine_cabinets.json"

func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not _prepare_family(data): return false
	for row: Dictionary in data.assemblies:
		for i in row.parts.size():
			if row.parts[i].get("finish") is not Dictionary: return false
			var component := str(row.parts[i].component)
			if component not in ["Body", "CabinetDoor", "Mirror"]: return false
			_variants[str(row.id)][i]["component"] = component
	return true

func install_on(prop: MedicineCabinetProp) -> bool:
	var identity := str(prop.name)
	if not _instances.has(identity): return false
	var carcass := prop.get_node_or_null("CabinetCarcass") as Node3D
	var contents := prop.get_node_or_null("CabinetContents") as Node3D
	if carcass == null or contents == null or prop._door == null or prop._mirror_surface == null: return false
	for owner: Node3D in [carcass, prop._door]:
		for child: Node in owner.get_children():
			if child is MeshInstance3D and child != prop._mirror_surface:
				owner.remove_child(child)
				child.free()
	var variant: String = _instances[identity]
	for part: Dictionary in _variants[variant]:
		var owner: Node3D = carcass if part.component == "Body" else prop._door
		var draw: MeshInstance3D
		if part.component == "Mirror":
			draw = prop._mirror_surface
			draw.material_override = prop._mirror_fallback
		else:
			draw = MeshInstance3D.new()
			draw.name = part.name
			draw.material_override = part.override
			owner.add_child(draw)
		draw.mesh = part.mesh
		draw.transform = owner.transform.affine_inverse() * part.pose
		draw.set_meta("native_cabinet_part", part.name)
		draw.set_meta("material_key", part.key)
	for child: Node in contents.get_children():
		var item := child as MeshInstance3D
		if item == null or not item.has_meta("source_kept_name"): return false
		var item_name := str(item.get_meta("source_kept_name"))
		var item_variant := "MedicineItem_" + item_name.replace(" ", "_")
		if not _variants.has(item_variant): return false
		var original := item.mesh
		var original_material := item.material_override
		item.set_meta("source_kept_transform", item.transform)
		item.set_meta("source_kept_mesh", original)
		item.set_meta("source_kept_material", original_material)
		item.position.y -= original.get_aabb().size.y*.5 + .004
		item.mesh = null
		item.material_override = null
		for part: Dictionary in _variants[item_variant]:
			var draw := MeshInstance3D.new()
			draw.name = part.name
			draw.mesh = part.mesh
			draw.transform = part.pose
			draw.material_override = part.override
			# The original amber material still owns the ordinary kept bottles.
			if part.key == "bottle" and item_name != "QUELL TONIC": draw.material_override = original_material
			draw.set_meta("native_kept_part", part.name)
			draw.set_meta("material_key", part.key)
			item.add_child(draw)
		if item_name == "QUELL TONIC":
			var label := Label3D.new()
			label.name = "SourceTonicLabel"
			label.text = "QUELL\nTONIC"
			label.font_size = 32
			label.pixel_size = .00018
			label.modulate = Color(.15,.20,.18)
			label.outline_size = 0
			label.no_depth_test = false
			label.position = Vector3(0,.041,-.01815)
			label.rotation.y = PI
			item.add_child(label)
		item.set_meta("native_kept_variant", item_variant)
	prop.set_meta("v2_native_medicine_variant", variant)
	return true
