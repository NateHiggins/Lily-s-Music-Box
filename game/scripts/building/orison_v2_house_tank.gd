extends RefCounted
## Blender fabrication follows the fixture records; physics and service stay live.
static func mount(root: Node3D) -> void:
	var body: MeshInstance3D
	var column: MeshInstance3D
	var floor_y := 0.0
	var fixtures: Array=root.fabricated_fixtures.get("house_tank",[])
	for fixture: MeshInstance3D in fixtures:
		if fixture.get_meta("fabrication_part","")=="body":
			body=fixture
			floor_y=float(fixture.get_meta("fabrication_floor_y"))
		elif fixture.get_meta("fabrication_part","")=="support" and column==null: column=fixture
	var model := (preload("res://assets/props/house_tank.glb") as PackedScene).instantiate() as Node3D
	model.name="FittedHouseTank"
	model.position=Vector3(body.position.x,floor_y,body.position.z)
	root.add_child(model)
	for part: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		part.material_override=body.get_active_material(0) if str(part.name)=="Timber" else column.get_active_material(0) if str(part.name)=="Iron" else MatLib.get_mat("metal")
	for fixture: MeshInstance3D in fixtures: fixture.hide()
