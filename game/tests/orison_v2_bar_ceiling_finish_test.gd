extends "res://tests/orison_v2_roof_membrane_test.gd"
## Original physical owner and exact unchanged faces under a local catalogue finish.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	var bar: OrisonV2BarRegion=world.bar_region
	check(bar!=null and not world.startup_failed and not bar.startup_failed,"retained independent bar composes with the local ceiling finish")
	if bar==null or world.startup_failed or bar.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var cell: Node3D=bar.get_node("RetainedBarGeometry");var meta: Dictionary=cell.get_meta("bar_ceiling_finish")
	var owner: MeshInstance3D=meta.owner;var original: ArrayMesh=meta.original_mesh;var surface:=int(meta.finish_surface)
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bar_ceiling_finish.json"))
	var fit:=preload("res://scripts/building/orison_v2_bar_ceiling_finish.gd")
	check(FileAccess.get_sha256("res://assets/props/bar_ceiling_finish.glb")==fixture.asset_sha256,"installed ceiling charts bind the native export")
	check(fit._face_counts(original.get_faces())==fit._face_counts(owner.mesh.get_faces()),"every original triangle and orientation survives the surface split")
	check(owner.get_parent()==cell and owner.transform.is_equal_approx(Transform3D.IDENTITY),"retained ceiling draw keeps its original frame and physical owner")
	for row: Dictionary in fixture.original_records:
		var records: Array=bar.source_layout.floors.filter(func(floor):return floor.id=="F01")[0].furniture.filter(func(value):return value.id==row.id)
		check(records.size()==1 and records[0]==row and int(meta.removed_triangles[row.id])==12,"original ceiling stock and twelve source faces remain: "+str(row.id))
	var collision: CollisionShape3D=owner.find_children("*","CollisionShape3D",true,false)[0]
	check((collision.shape as ConcavePolygonShape3D).get_faces()==owner.mesh.get_faces(),"unchanged visible faces keep exact original-owner collision")
	var material:=owner.mesh.surface_get_material(surface) as StandardMaterial3D;var library:=MatLib.get_mat("smoked_plaster")
	check(material!=null and material!=library and library.uv1_triplanar and not material.uv1_triplanar,"local ceiling metre chart leaves the shared cache intact")
	check(material.albedo_texture==library.albedo_texture and material.roughness_texture==library.roughness_texture and material.normal_texture==library.normal_texture,"three catalogue smoke-film maps reach the ceiling")
	check(material.normal_scale==library.normal_scale and material.metallic==0. and material.uv1_scale.is_equal_approx(Vector3.ONE/1.8),"surface keeps the catalogue physical scale and optical calibration")
	var active:=owner.get_active_material(surface) as ShaderMaterial
	check(active!=null and active.get_shader_parameter("albedo_tex")==library.albedo_texture,"production retail surface retains its state owner and new map")
	var fragment:=ArrayMesh.new();fragment.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,owner.mesh.surface_get_arrays(surface));_check_cap_mapping(fragment,true)
	check(fragment.get_faces().size()==48*3,"exactly forty-eight authored ceiling faces take the local finish")
	for i in original.get_surface_count():
		var before: Dictionary=original.get("_surfaces")[i];var after: Dictionary=owner.mesh.get("_surfaces")[i]
		for key: Variant in before:
			if key in ["index_data","index_count","lods"]:continue
			check(before[key]==after.get(key),"unaffected retained vertex/normal/UV buffer stays exact: "+str(key))
	await _ceiling_views(world,bar,owner,original)
	print("BAR CEILING FINISH: checks=",checks," original_stocks=4 source_triangles=48 failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _ceiling_views(world: OrisonV2RuntimeRoot, bar: Node3D, owner: MeshInstance3D, original: ArrayMesh) -> void:
	var views: Array=[
		["pool_ceiling",Vector3(-7.4,-2.775,33.25),Vector3(-7.4,-.15,31.25)],
		["west_ceiling",Vector3(-9.3,-2.775,35.4),Vector3(-7.,-.15,36.5)],
		["bar_ceiling",Vector3(-5.5,-2.775,32.),Vector3(-2.,-.15,29.7)],
		["well_edge",Vector3(-3.8,-2.775,33.5),Vector3(-5.65,-.15,33.4)]]
	for view: Array in views:
		var feet:=bar.to_global(view[1]);var shape:=CapsuleShape3D.new();shape.radius=PlayerController.BODY_RADIUS;shape.height=PlayerController.STANDING_HEIGHT
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*shape.height*.5);query.collision_mask=1;query.exclude=[world.player.get_rid()]
		var clear:=world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty();check(clear,"ordinary standing ceiling view is clear: "+str(view[0]));if not clear:continue
		var floor_query:=PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.02,feet-Vector3.UP*.15,1,[world.player.get_rid()]);var floor_hit:=world.get_world_3d().direct_space_state.intersect_ray(floor_query)
		check(not floor_hit.is_empty() and bar.get_node("RetainedBarGeometry").is_ancestor_of(floor_hit.collider),"standing view has retained floor support: "+str(view[0]));if floor_hit.is_empty():continue
		world.player.global_position=feet;world.player.face_world_point(bar.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0])+"_fitted")
		var fitted:=owner.mesh;var overrides: Array[Material]=[]
		for i in owner.mesh.get_surface_count():overrides.append(owner.get_surface_override_material(i))
		owner.mesh=original;await _settled_optics();await shot(str(view[0])+"_original")
		owner.mesh=fitted
		for i in overrides.size():owner.set_surface_override_material(i,overrides[i])
