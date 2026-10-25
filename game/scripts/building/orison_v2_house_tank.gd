extends RefCounted
## Blender fabrication follows the fixture records; physics and service stay live.
static func mount(root: Node3D) -> void:
	var body: MeshInstance3D
	var floor_y := 0.0
	var fixtures: Array=root.fabricated_fixtures.get("house_tank",[])
	for fixture: MeshInstance3D in fixtures:
		if fixture.get_meta("fabrication_part","")=="body":
			body=fixture
			floor_y=float(fixture.get_meta("fabrication_floor_y"))
	var model := (preload("res://assets/props/house_tank.glb") as PackedScene).instantiate() as Node3D
	model.name="FittedHouseTank"
	model.position=Vector3(body.position.x,floor_y,body.position.z)
	root.add_child(model)
	var iron := preload("res://scripts/building/orison_v2_roof_plant_materials.gd").iron()
	var hardware := preload("res://scripts/building/orison_v2_roof_plant_materials.gd").hardware()
	var shell := MatLib.get_mat("enamel").duplicate() as StandardMaterial3D
	shell.resource_name="HouseTankPaintedSteel"
	shell.uv1_triplanar=false
	shell.normal_scale=.06
	# Retire rectangular vessel/band proxies. Keep the four original posts and
	# collector colliders; the vessel and new steelwork use actual native faces.
	var collision := body.get_node("Collision") as StaticBody3D
	for child: Node in collision.get_children(): child.free()
	for fixture: MeshInstance3D in fixtures:
		if str(fixture.get_meta("fabrication_part","")) in ["lid","binding"]:
			var old := fixture.get_node_or_null("Collision") as CollisionObject3D
			if old != null: old.collision_layer=0; old.collision_mask=0
	for part: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		match str(part.name):
			"Timber": part.material_override=body.get_active_material(0)
			"Iron", "Structure": part.material_override=iron
			"Shell": part.material_override=shell
			_: part.material_override=hardware
		if str(part.name) in ["Shell","Structure"]:
			var shape := CollisionShape3D.new()
			shape.name=str(part.name)+"NativeCollision"
			shape.shape=part.mesh.create_trimesh_shape()
			collision.add_child(shape)
			shape.global_transform=part.global_transform
	for fixture: MeshInstance3D in fixtures: fixture.hide()
	# The tank's crown carries St. Elmo's fire in a high-charge storm.
	var StElmo := preload("res://scripts/building/orison_v2_st_elmo.gd")
	var vessel := model.find_child("Shell", true, false) as MeshInstance3D
	if vessel != null:
		model.add_child(StElmo.new(PackedVector3Array([StElmo.crown_of(vessel, model)]), .9))
