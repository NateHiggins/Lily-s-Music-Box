extends SceneTree
## Fast source-boundary preflight without constructing a production world.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var scene := load("res://assets/building/floor_01_cells/shop_bar.gltf") as PackedScene
	var cell := scene.instantiate() as Node3D
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	for script: String in ["bar_pool","bar_fixture_mounts","bar_pipe_supports","bar_ceiling_finish","bar_gallery","bar_stage"]:
		var helper: GDScript=load("res://scripts/building/orison_v2_"+script+".gd")
		var ok: bool
		if script=="bar_ceiling_finish": ok=helper.apply(cell,layout)
		elif script in ["bar_fixture_mounts","bar_pipe_supports"]: ok=helper.mount_cell(cell)
		else: ok=helper.mount_cell(cell,layout)
		print("EARLIER BAR MOUNT ",script," ",ok)
		if not ok: cell.free(); quit(1); return
	var passed := preload("res://scripts/building/orison_v2_bar_furniture.gd").mount_cell(cell,layout)
	if passed:
		var ceiling: Dictionary = cell.get_meta("bar_ceiling_finish")
		print("CEILING RETAINED ",ceiling.finish_surface," ",ceiling.owner.mesh.surface_get_material(int(ceiling.finish_surface)).resource_name)
		root.add_child(cell)
		await physics_frame
		await physics_frame
		for i in 7:
			var angle := i*TAU/7.+.007
			for radius in [60.,103.,132.,166.]:
				var at := Vector3(-11.406,-1.07+cos(angle)*radius/1000.,33.-sin(angle)*radius/1000.)
				var hit := cell.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.RIGHT*.5,at-Vector3.RIGHT*.5,1))
				var body: Node = hit.get("collider")
				var expected := "DartsCabinet__sector_"+str(i)+("_single" if radius in [60.,132.] else "")
				passed = passed and body!=null and str(body.get_parent().get_meta("bar_furniture_part",""))==expected
				print("FIELD ",i," ",radius," ","MISS" if body==null else str(body.get_parent().get_meta("bar_furniture_part",body.get_parent().name))," ",hit.get("position"))
		var feet := Vector3(-1.90,-2.55,36.25)
		var capsule := CapsuleShape3D.new(); capsule.radius=PlayerController.BODY_RADIUS; capsule.height=PlayerController.STANDING_HEIGHT
		var query := PhysicsShapeQueryParameters3D.new(); query.shape=capsule; query.collision_mask=1
		query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*PlayerController.STANDING_HEIGHT*.5)
		var collisions := cell.get_world_3d().direct_space_state.intersect_shape(query)
		print("STAGE STATION COLLISIONS ",collisions)
		passed = passed and collisions.is_empty()
	print("BAR FURNITURE SOURCE PREFLIGHT ","PASS" if passed else "FAIL")
	cell.free()
	quit(0 if passed else 1)
