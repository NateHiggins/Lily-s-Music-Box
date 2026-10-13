extends RefCounted
## Localized period repairs retain every semantic room, door and service owner.
static func mount(root: Node3D) -> void:
	var model := (preload("res://assets/props/fire_repairs.glb") as PackedScene).instantiate() as Node3D
	model.name = "FireRepairs"
	root.add_child(model)
	var tints := {"timber": Color(.72,.65,.53), "iron_neutral": Color(.55,.55,.52), "brick": Color(.92,.84,.71), "soot": Color(.58,.58,.58)}
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var key := str(draw.name).split("__")[1]
		var material := MatLib.get_mat(key,tints[key]).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.normal_scale = .65
		draw.material_override = material
		draw.create_trimesh_collision()
