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
	# The four restricted-cell retrofits run above the ordinary walking capsule,
	# below the lower-storey ceiling. Other branches remain in floor/shaft stock.
	# Keep the source-owned wall/slab walking hulls rather than duplicating them
	# with triangle collisions for the fixed heating fabric.
	root.add_child(model)
