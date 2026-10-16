extends RefCounted
## Fixed native supply fabric; existing boiler/radiator owners retain all state.
static func mount(root: Node3D) -> void:
	var model := (preload("res://assets/props/heating_distribution.glb") as PackedScene).instantiate() as Node3D
	model.name = "HeatingDistribution"
	var finish := MatLib.get_mat("iron_neutral").duplicate() as StandardMaterial3D
	finish.uv1_triplanar = false
	finish.uv1_scale = Vector3.ONE
	finish.normal_scale = .25
	finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		part.material_override = finish
		part.set_meta("v2_material_key", "iron_neutral")
	# Branches and mains are concealed in floor/shaft envelopes. Retain their
	# existing walking hulls; do not add expensive buried triangle collisions.
	root.add_child(model)
