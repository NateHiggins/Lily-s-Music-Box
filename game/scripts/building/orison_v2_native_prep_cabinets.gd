extends "res://scripts/building/orison_v2_native_domestic_furniture.gd"
## Replace only visual children; the original cabinet owns motion and collision.
const PATH := "res://data/orison_v2/prep_cabinets.json"

func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not _prepare_family(data): return false
	for row: Dictionary in data.assemblies:
		for i in row.parts.size():
			if row.parts[i].get("finish") is not Dictionary: return false
			var component := str(row.parts[i].component)
			if component not in ["Body","SlidingPanel"]: return false
			_variants[str(row.id)][i]["component"] = component
	return true

func mount_on(body: StaticBody3D, identity: String) -> bool:
	if not _instances.has(identity): return false
	var slide := body.get_node_or_null("SlidingPanel") as AnimatableBody3D
	if slide == null: return false
	for parent: Node3D in [body,slide]:
		for child: Node in parent.get_children():
			if child is MeshInstance3D:
				parent.remove_child(child)
				child.free()
	var variant: String = _instances[identity]
	for part: Dictionary in _variants[variant]:
		var component := str(part.component)
		if component not in ["Body","SlidingPanel"]: return false
		var parent: Node3D = body if component == "Body" else slide
		var draw := MeshInstance3D.new()
		draw.name = part.name
		draw.mesh = part.mesh
		draw.transform = part.pose
		draw.set_meta("native_prep_part",part.name)
		draw.set_meta("material_key",part.key)
		parent.add_child(draw)
	body.set_meta("v2_native_prep_variant",variant)
	return true
