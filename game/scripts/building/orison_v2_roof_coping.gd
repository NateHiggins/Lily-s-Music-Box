extends RefCounted
## One mitered weather course replaces intersecting cap-box presentation.
static func mount(root: Node3D) -> void:
	var fixtures: Array=root.fabricated_fixtures.get("roof_coping",[])
	if fixtures.is_empty(): return
	var first := fixtures[0] as MeshInstance3D
	var bounds: AABB=first.transform*first.mesh.get_aabb()
	for fixture: MeshInstance3D in fixtures: bounds=bounds.merge(fixture.transform*fixture.mesh.get_aabb())
	var model := (preload("res://assets/props/roof_coping.glb") as PackedScene).instantiate() as Node3D
	model.name="FittedRoofCoping"
	model.position=Vector3(bounds.get_center().x,float(first.get_meta("fabrication_floor_y")),bounds.get_center().z)
	root.add_child(model)
	var stone := model.get_node("CopingCourse") as MeshInstance3D
	stone.material_override=first.get_active_material(0)
	for fixture: MeshInstance3D in fixtures: fixture.hide()
