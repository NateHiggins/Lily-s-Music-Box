extends RefCounted
## Shared Blender dressing; semantic steps, ramps and walls retain collision.
const PUBLIC := preload("res://assets/props/stair_ironwork_public.glb")
const SERVICE := preload("res://assets/props/stair_ironwork_service.glb")

func mount(parent: Node3D, stair: Dictionary, base_y: float) -> bool:
	var public := is_equal_approx(float(stair.width),1.2)
	var width := 1.2 if public else 1.05
	if not is_equal_approx(float(stair.width),width) \
		or not is_equal_approx(float(stair.tread),.285 if public else .275) \
		or not is_equal_approx(float(stair.landing_depth),width) \
		or not is_equal_approx(float(stair.rise),.16) or int(stair.risers_per_flight)!=10 \
		or not is_equal_approx(float(stair.gap),.3) or not is_equal_approx(float(stair.guard_height),.91):
		return false
	var model := (PUBLIC if public else SERVICE).instantiate() as Node3D
	model.name = "Ironwork"
	parent.add_child(model)
	model.position = Vector3(float(stair.origin[0]),base_y,float(stair.origin[1]))
	for part: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in part.mesh.get_surface_count():
			var source := part.mesh.surface_get_material(surface)
			part.set_surface_override_material(surface,MatLib.get_mat(source.resource_name))
	return true
