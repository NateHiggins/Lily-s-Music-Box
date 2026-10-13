extends RefCounted
## Source-authored rooms own their floors, walls, windows and passage openings.
## Native stock adds the continuous facade articulation and fitted seating.
static func mount(root: Node3D) -> void:
	var model := preload("res://assets/props/front_restoration_details.glb").instantiate() as Node3D
	model.name = "FrontRestoration"
	root.add_child(model)
	var tints := {"brick":Color(.85,.78,.72),"concrete":Color(.88,.84,.74),"wood_dark":Color(.80,.74,.63)}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var key := str(draw.name).split("__")[1]
		var material := MatLib.get_mat(key,tints[key]).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		draw.material_override = material
		draw.create_trimesh_collision()
