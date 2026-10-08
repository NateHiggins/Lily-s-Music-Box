extends "res://scripts/building/orison_v2_native_domestic_furniture.gd"
## Shared native stocks attach to the original cycle, tray and glow owners.
const PATH := "res://data/orison_v2/household_toasters.json"
const COMPONENTS := ["Body", "CarriageLever", "BreadCarrier", "OrisonRetrofitCrumbTray", "ResistanceWire"]

func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not _prepare_family(data): return false
	for row: Dictionary in data.assemblies:
		for i in row.parts.size():
			if row.parts[i].get("finish") is not Dictionary: return false
			var component := str(row.parts[i].component)
			if component not in COMPONENTS: return false
			_variants[str(row.id)][i]["component"] = component
	return _variants.has("ToasterCrumb") and _variants.ToasterCrumb.size() == 1

func install_on(prop: Node3D) -> bool:
	var identity := str(prop.name)
	if not _instances.has(identity): return false
	var owners := {}
	for component: String in COMPONENTS:
		var owner := prop.get_node_or_null("StaticCase" if component == "Body" else component) as Node3D
		if owner == null: return false
		owners[component] = owner
	for owner: Node3D in owners.values():
		for child: Node in owner.get_children():
			if child is MeshInstance3D and not child.has_meta("source_toaster_crumb"):
				owner.remove_child(child)
				child.free()
	var variant: String = _instances[identity]
	for part: Dictionary in _variants[variant]:
		var owner: Node3D = owners[part.component]
		var draw := MeshInstance3D.new()
		draw.name = part.name
		draw.mesh = part.mesh
		draw.material_override = prop.get("_coil_mat") if part.component == "ResistanceWire" else part.override
		draw.transform = owner.transform.affine_inverse() * part.pose
		draw.set_meta("native_toaster_part", part.name)
		draw.set_meta("material_key", part.key)
		owner.add_child(draw)
	var crumb_part: Dictionary = _variants.ToasterCrumb[0]
	var bounds: AABB = crumb_part.mesh.get_aabb()
	var count := 0
	for child: Node in owners.OrisonRetrofitCrumbTray.get_children():
		if not child.has_meta("source_toaster_crumb"): continue
		var crumb := child as MeshInstance3D
		var original := crumb.mesh as BoxMesh
		if original == null: return false
		var dimensions := original.size
		crumb.set_meta("source_crumb_dimensions", dimensions)
		crumb.set_meta("source_crumb_transform", crumb.transform)
		crumb.mesh = crumb_part.mesh
		crumb.scale = dimensions / bounds.size
		var center := bounds.get_center()
		var offset := crumb.basis * Vector3(-center.x, -bounds.position.y, -center.z)
		# Original X/Z footprint, yaw, dimensions and material stay household
		# owned. Only its bottom is seated on the real formed pan.
		crumb.position += offset
		crumb.position.y = -.00115 if crumb.position.x >= -.082 and crumb.position.x <= .038 \
				and crumb.position.z >= -.036 and crumb.position.z <= .024 else -.0013
		crumb.set_meta("native_toaster_crumb", true)
		count += 1
	if count != 18: return false
	prop.set_meta("v2_native_toaster_variant", variant)
	return true
