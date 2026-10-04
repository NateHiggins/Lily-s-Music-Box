extends "res://tests/orison_v2_roof_membrane_test.gd"
## Exact retained boundaries, native collision, open pockets and bar views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	var bar: OrisonV2BarRegion=world.bar_region
	check(bar!=null and not world.startup_failed and not bar.startup_failed,"original independent bar composes with fitted pool table")
	if bar==null or world.startup_failed or bar.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var cell: Node3D=bar.get_node("RetainedBarGeometry");var model: Node3D=cell.get_node("BarPool")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bar_pool.json"))
	var ground: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_ground_construction.json"))
	var grade_samples:=0
	for row: Dictionary in ground.source_plan.retained_solids:
		if not str(row.owner).begins_with("RetainedBarGeometry/") or not (str(row.id).contains("_tread") or str(row.id).ends_with("_floor")):continue
		var b: Array=row.bounds;var at:=Vector3((b[0]+b[3])*.5,b[4],(b[2]+b[5])*.5)
		var query:=PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(at+Vector3.UP*.015),world.adapter.root.to_global(at-Vector3.UP*.015),1,[world.player.get_rid()])
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and cell.is_ancestor_of(hit.collider) and world.adapter.root.to_local(hit.position).distance_to(at)<.0001,"retained stair or basement slab remains the bearing owner: "+str(row.id))
		grade_samples+=1
	check(grade_samples==18,"all fifteen retained treads and three bar floor slabs remain clear of terrain")
	check(FileAccess.get_sha256("res://assets/props/bar_pool.glb")==fixture.asset_sha256,"installed table binds the saved native export")
	var originals: Dictionary=model.get_meta("original_meshes");var counts: Dictionary=model.get_meta("removed_triangles")
	var parts:=0;var triangles:=0;var removed:=0
	for box: Dictionary in fixture.runtime.cells[0].replace:
		check(counts[box.id]==int(box.expected_triangles),"only exact original boundary removed: "+str(box.id));removed+=int(counts[box.id])
	for draw: MeshInstance3D in originals:
		var original: Mesh=originals[draw];var retained:=draw.mesh
		check(retained.get_surface_count()==0 or original.get_surface_count()==retained.get_surface_count(),"other imported material slots remain")
		for surface in retained.get_surface_count():
			var before:=original.surface_get_arrays(surface);var after:=retained.surface_get_arrays(surface)
			for attribute in Mesh.ARRAY_MAX:
				if attribute!=Mesh.ARRAY_INDEX:check(before[attribute]==after[attribute],"other imported vertex attributes remain byte-identical")
			check(original.surface_get_material(surface)==retained.surface_get_material(surface),"other source material remains identical")
		var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
		check((shape.disabled and not draw.visible) if retained.get_surface_count()==0 else (shape.shape as ConcavePolygonShape3D).get_faces()==retained.get_faces(),"retained visible and physical faces agree")
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		parts+=1;var count:=draw.mesh.get_faces().size()/3;triangles+=count
		var identity:=str(draw.get_meta("bar_pool_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==identity)[0]
		check(count==int(expected.triangles),"fitted partition keeps actual native triangle count")
		_check_cap_mapping(draw.mesh,true)
		var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
		check(mat!=null and not mat.uv1_triplanar and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null,"three physical maps reach checked metre charts")
		var part: Dictionary=fixture.runtime.cells[0].parts.filter(func(row):return row.name==identity)[0]
		if part.has("catalog_key"):
			var library:=MatLib.get_mat(part.catalog_key)
			check(mat!=library and library.uv1_triplanar and mat.albedo_texture==library.albedo_texture and mat.roughness_texture==library.roughness_texture and mat.normal_texture==library.normal_texture,"instance finish retains registered maps without changing shared library")
			check(mat.metallic==library.metallic and mat.roughness==library.roughness and mat.normal_scale==library.normal_scale,"registered optical policy remains intact")
			if part.has("tint"):
				var tint: Array=part.tint
				check(mat.albedo_color==Color(tint[0],tint[1],tint[2],tint[3]) and mat.metallic==0.,"local ball and pocket tints retain their nonmetallic catalogue finish")
		else:
			var source: StandardMaterial3D
			for old: MeshInstance3D in originals:
				if str(old.name).trim_suffix("-col").ends_with("_"+str(expected.key)):source=originals[old].surface_get_material(0)
			check(source!=null and source!=mat and source.albedo_texture==mat.albedo_texture and source.roughness_texture==mat.roughness_texture and source.normal_texture==mat.normal_texture,"wood and violet cloth keep original shipping maps")
		var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
		check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"each physical partition exactly follows visible native faces")
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==84,"all seven original boxes have one fitted replacement")
	for contact: Dictionary in fixture.contacts:
		var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
		for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
			if str(body.get_parent().get_meta("bar_pool_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
		var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"actual bearing: "+str(contact.label))
	for pocket: Dictionary in fixture.pockets:
		for offset: Vector3 in [Vector3(.013,0,.017),Vector3(-.018,0,.011)]:
			var at:=_v(pocket.mouth)+offset
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+Vector3.UP*.008),cell.to_global(at-Vector3.UP*.23),1,[world.player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or absf(cell.to_local(hit.position).y-float(pocket.floor_open_until))>=.00003:
				print("POOL_POCKET_DIAGNOSTIC ",JSON.stringify({"id":pocket.id,"sample":str(at),"hit":str(hit.get("position")),"owner":str(hit.get("collider")),"expected_local_y":pocket.floor_open_until}))
			check(not hit.is_empty() and absf(cell.to_local(hit.position).y-float(pocket.floor_open_until))<.00003,"real pocket throat reaches its inner bag bottom: "+str(pocket.id))
	var gap:=PhysicsRayQueryParameters3D.create(cell.to_global(Vector3(-7.4,-2.5,30.8)),cell.to_global(Vector3(-7.4,-2.5,31.7)),1,[world.player.get_rid()])
	check(world.get_world_3d().direct_space_state.intersect_ray(gap).is_empty(),"former solid body leaves real open leg space")
	var chalk: PointBallProp=bar.actors.get_node("F01_BAR_POOL")
	check(chalk!=null and chalk.position.distance_to(Vector3(-6.52,-2.02,30.70))<.000001,"original chalk owner and source position remain")
	check(bar.actors.get_node("BAR_POOL_TABLE").position.distance_to(Vector3(-7.4,-1.95,31.25))<.000001,"retained pool inspection volume remains fitted")
	var zone:=bar.actors.get_node("BAR_POOL_TABLE") as InspectableZone
	var target:=zone.get_node("FittedPoolInspection") as Area3D
	check(zone.collision_layer==0 and target.collision_layer==1 and target.position.distance_to(_v(fixture.runtime.inspection.center)-zone.position)<.000001,"original observation owner has a fitted ray target without invisible blocking collision")
	await _views(world,bar,model)
	print("BAR POOL: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",fixture.contacts.size()," pockets=",fixture.pockets.size()," grade_samples=",grade_samples," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _views(world: OrisonV2RuntimeRoot, bar: Node3D, model: Node3D) -> void:
	for view: Array in [["north",Vector3(-7.4,-2.775,29.65),Vector3(-7.4,-2.055,31.25)],["east",Vector3(-5.5,-2.775,31.25),Vector3(-7.4,-2.055,31.25)],["west",Vector3(-9.4,-2.775,31.25),Vector3(-7.4,-2.055,31.25)],["south",Vector3(-7.4,-2.775,32.9),Vector3(-7.4,-2.055,31.25)],["chalk",Vector3(-5.7,-2.775,30.0),Vector3(-6.52,-2.005,30.70)]]:
		var feet:=bar.to_global(view[1]);var shape:=CapsuleShape3D.new()
		shape.radius=PlayerController.BODY_RADIUS;shape.height=PlayerController.STANDING_HEIGHT
		var capsule:=PhysicsShapeQueryParameters3D.new();capsule.shape=shape
		capsule.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*shape.height*.5)
		capsule.collision_mask=1;capsule.exclude=[world.player.get_rid()]
		var clear:=world.get_world_3d().direct_space_state.intersect_shape(capsule,1).is_empty()
		check(clear,"standing capture capsule clears the fitted room: "+str(view[0]))
		var floor_ray:=PhysicsRayQueryParameters3D.create(feet,feet-Vector3.UP*.06,1,[world.player.get_rid()])
		var floor_hit:=world.get_world_3d().direct_space_state.intersect_ray(floor_ray)
		check(not floor_hit.is_empty() and bar.get_node("RetainedBarGeometry").is_ancestor_of(floor_hit.collider) and absf(bar.to_local(floor_hit.position).y+2.8)<.00003,"standing capture is backed by the retained bar floor: "+str(view[0]))
		if not clear:continue
		world.player.global_position=bar.to_global(view[1]);world.player.face_world_point(bar.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0])+"_fitted")
		var originals: Dictionary=model.get_meta("original_meshes");var fitted: Dictionary={};model.hide()
		for draw: MeshInstance3D in originals:fitted[draw]=draw.mesh;draw.mesh=originals[draw];draw.show()
		await _settled_optics();await shot(str(view[0])+"_original")
		for draw: MeshInstance3D in fitted:draw.mesh=fitted[draw];draw.visible=draw.mesh.get_surface_count()>0
		model.show()
