extends "res://scripts/building/orison_v2_native_domestic_furniture.gd"
## Keep the source mirror node, hinge, inventory and reflection material owner.
const PATH := "res://data/orison_v2/medicine_cabinets.json"

func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is not Dictionary or data.get("mounts") is not Dictionary: return false
	if data.mounts.keys() != ["F04_4B_MIRROR_01"]: return false
	var mount: Dictionary = data.mounts.F04_4B_MIRROR_01
	if mount.get("pitch_degrees") != -6 or mount.get("rise") != .03 or mount.get("pivot") is not Array: return false
	if mount.pivot.size() != 3 or Vector3(mount.pivot[0],mount.pivot[1],mount.pivot[2]) != Vector3(0,1.20,.058): return false
	if not _prepare_family(data): return false
	var shared_parts := {}
	for row: Dictionary in data.assemblies:
		for i in row.parts.size():
			if row.parts[i].get("finish") is not Dictionary: return false
			var component := str(row.parts[i].component)
			if component not in ["Body", "CabinetDoor", "Mirror"]: return false
			var name_: String = str(row.parts[i].name)
			if shared_parts.has(name_):
				_variants[str(row.id)][i] = shared_parts[name_]
			else:
				_variants[str(row.id)][i]["component"] = component
				shared_parts[name_] = _variants[str(row.id)][i]
	return true

func mounting_pose(identity: String) -> Transform3D:
	# Original support origin stays authoritative. Only 4B uses the native
	# six-degree tapered wall rails; the other eleven cabinets remain vertical.
	if identity != "F04_4B_MIRROR_01": return Transform3D.IDENTITY
	var pivot := Vector3(0, 1.20, .058)
	var rotation := Basis(Vector3.RIGHT, deg_to_rad(-6.0))
	return Transform3D(rotation, pivot-rotation*pivot+Vector3(0,.03,0))

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
