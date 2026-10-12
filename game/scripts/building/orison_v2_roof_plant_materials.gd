extends RefCounted
## Restrained catalogue metal for the existing roof plant. No global remap.
static func iron() -> StandardMaterial3D:
	var mat := MatLib.get_mat("iron_blackened").duplicate() as StandardMaterial3D
	mat.resource_name = "RoofPlantIron"
	mat.uv1_triplanar = false
	mat.normal_scale = .08
	return mat

static func hardware() -> StandardMaterial3D:
	var mat := MatLib.get_mat("iron_neutral").duplicate() as StandardMaterial3D
	mat.resource_name = "RoofPlantHardware"
	mat.uv1_triplanar = false
	mat.normal_scale = .08
	return mat
