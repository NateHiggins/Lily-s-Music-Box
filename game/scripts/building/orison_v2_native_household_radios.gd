extends "res://scripts/building/orison_v2_native_domestic_furniture.gd"
## Native visuals follow the existing radio's original tuning pivot.
const PATH := "res://data/orison_v2/household_radios.json"

func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not _prepare_family(data): return false
	for row: Dictionary in data.assemblies:
		for i in row.parts.size():
			if row.parts[i].get("finish") is not Dictionary:return false
			var component := str(row.parts[i].component)
			if component not in ["Body","PowerTuningKnob"]: return false
			_variants[str(row.id)][i]["component"] = component
	return true

func mount_on(body: StaticBody3D, identity: String) -> bool:
	if not _instances.has(identity): return false
	var knob := body.get_node_or_null("PowerTuningKnob") as Node3D
	if knob == null: return false
	for parent: Node3D in [body,knob]:
		for child: Node in parent.get_children():
			if child is MeshInstance3D:
				parent.remove_child(child)
				child.free()
	var variant: String = _instances[identity]
	for part: Dictionary in _variants[variant]:
		var component := str(part.component)
		var parent: Node3D = body if component == "Body" else knob
		var draw := MeshInstance3D.new()
		draw.name = part.name
		draw.mesh = part.mesh
		draw.material_override = part.override
		draw.transform = part.pose if parent == body else parent.transform.affine_inverse()*part.pose
		draw.set_meta("native_radio_part",part.name)
		draw.set_meta("material_key",part.key)
		parent.add_child(draw)
	body.set_meta("v2_native_radio_variant",variant)
	return true
