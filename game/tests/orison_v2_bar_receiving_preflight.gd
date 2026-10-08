extends SceneTree
## Fast composed bar source/physics preflight before a production-world run.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var cell := (load("res://assets/building/floor_01_cells/shop_bar.gltf") as PackedScene).instantiate() as Node3D
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	for script: String in ["bar_pool","bar_fixture_mounts","bar_pipe_supports","bar_ceiling_finish","bar_gallery","bar_stage","bar_furniture","bar_receiving"]:
		var helper: GDScript=load("res://scripts/building/orison_v2_"+script+".gd")
		var ok: bool
		if script=="bar_ceiling_finish": ok=helper.apply(cell,layout)
		elif script in ["bar_fixture_mounts","bar_pipe_supports"]: ok=helper.mount_cell(cell)
		else: ok=helper.mount_cell(cell,layout)
		print("BAR PREFLIGHT ",script," ",ok)
		if not ok: cell.free(); quit(1); return
	root.add_child(cell)
	var surface := preload("res://scripts/building/surface_pass.gd").new()
	surface.apply({"shop_bar":cell})
	preload("res://scripts/building/orison_v2_bar_receiving.gd").calibrate(cell)
	await physics_frame
	await physics_frame
	var excluded: Array[RID]=[]
	for body: StaticBody3D in cell.get_node("BarReceiving").find_children("*","StaticBody3D",true,false): excluded.append(body.get_rid())
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bar_receiving.json"))
	var passed := true
	for draw: MeshInstance3D in cell.get_node("BarReceiving").find_children("*","MeshInstance3D",true,false):
		passed=passed and draw.get_surface_override_material(0) is ShaderMaterial
	for contact: Dictionary in fixture.contacts:
		var p: Array=contact.point; var at := Vector3(p[0],p[1],p[2])
		var hit := cell.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.03,at-Vector3.UP*.03,1,excluded))
		passed=passed and not hit.is_empty() and hit.position.distance_to(at)<.0002
	for z in [35.35,36.30]:
		var feet := Vector3(2.30,-2.59,z)
		var shape := CapsuleShape3D.new(); shape.radius=.33; shape.height=1.524
		var query := PhysicsShapeQueryParameters3D.new(); query.shape=shape; query.collision_mask=1
		query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*1.524*.5)
		var hits := cell.get_world_3d().direct_space_state.intersect_shape(query)
		print("STATION ",feet," COLLISIONS ",hits)
		passed=passed and hits.is_empty()
	print("BAR RECEIVING PREFLIGHT ","PASS" if passed else "FAIL")
	cell.free(); quit(0 if passed else 1)
