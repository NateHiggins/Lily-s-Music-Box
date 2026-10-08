extends "res://scripts/building/orison_v2_native_domestic_furniture.gd"
const PATH := "res://data/orison_v2/household_stoves.json"
const VisualMotion := preload("res://scripts/building/orison_v2_stove_visual_motion.gd")
var _fit: Dictionary

func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not _prepare_family(data): return false
	_fit = data.native_service
	if _fit.grate_parking.size() != 4 or _fit.cap_end_blender_delta.size() != 4: return false
	for row: Dictionary in _fit.grate_parking:
		if row.blender_center.size() != 3 or not is_finite(float(row.angle_degrees)): return false
	for offset: Array in _fit.cap_end_blender_delta:
		if offset.size() != 3: return false
	for lift: float in [float(_fit.grate_lift_m),float(_fit.grate_forward_m),float(_fit.cap_lift_m)]:
		if not is_finite(lift) or lift < 0.: return false
	for row: Dictionary in data.assemblies:
		for i in row.parts.size():
			if row.parts[i].get("finish") is not Dictionary: return false
			_variants[str(row.id)][i]["component"] = str(row.parts[i].component)
	return true

func install_on(prop: StoveProp) -> bool:
	var identity := str(prop.name)
	if not _instances.has(identity): return false
	var variant: String = _instances[identity]
	var owners := {"Body":prop.get_node("StaticCarcass"),"OvenDoor":prop._door,"BroilerDrawer":prop._broiler,"OvenValve":prop.get_node("OvenValve")}
	for i in 4:
		owners["BurnerValve"+str(i+1)] = prop._knobs[i]
		owners["Grate"+str(i+1)] = prop._grates[i]
		owners["BurnerCap"+str(i+1)] = prop._caps[i]
	for owner: Node3D in owners.values():
		for child: Node in owner.get_children():
			if child is MeshInstance3D and child not in prop._jet_plugs:
				owner.remove_child(child)
				child.free()
	var enamel: StandardMaterial3D
	for part: Dictionary in _variants[variant]:
		if not owners.has(part.component): return false
		var owner: Node3D = owners[part.component]
		var draw := MeshInstance3D.new()
		draw.name = part.name
		draw.mesh = part.mesh
		draw.transform = owner.transform.affine_inverse()*part.pose
		if part.key == "enamel":
			if enamel == null:
				enamel = part.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
				enamel.albedo_color = prop._enamel_tint()
			draw.material_override = enamel
		draw.set_meta("native_stove_part",part.name)
		draw.set_meta("material_key",part.key)
		owner.add_child(draw)
	for i in 4:
		for grate: bool in [true,false]:
			var owner: Node3D = prop._grates[i] if grate else prop._caps[i]
			owner.set_script(VisualMotion)
			owner.call("configure",grate,i,_fit)
	prop.set_meta("v2_native_stove_variant",variant)
	return true
