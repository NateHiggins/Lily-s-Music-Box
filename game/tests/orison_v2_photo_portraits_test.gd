extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
var batch_mode := false
var capture_enabled := true

func _ready() -> void:
	if not batch_mode: call_deferred("_run")

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	if world.startup_failed or world.passage_region.startup_failed:check(false,"world startup failed");world.shutdown_for_tests();world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var passage: OrisonV2PassageRegion=world.passage_region
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	world.shop_simulation.set_process(false)
	var vestibule: Dictionary=world.layout.spaces.filter(func(row):return row.id=="F01_VESTIBULE")[0]
	var rect: Array=vestibule.rect
	world.player.global_position=world.adapter.root.to_global(Vector3((rect[0]+rect[2])*.5,0.,(rect[1]+rect[3])*.5))
	await get_tree().physics_frame;await get_tree().physics_frame
	for frame in 600:
		if passage.residency.state=="RESIDENT":break
		await get_tree().process_frame
	if passage.residency.state!="RESIDENT":check(false,"normal prefetch failed");world.shutdown_for_tests();world.free();get_tree().quit(1);return
	await get_tree().physics_frame;await get_tree().physics_frame
	await validate_in_world(world)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var passage: OrisonV2PassageRegion=world.passage_region
	check(not world.startup_failed and not world.passage_region.startup_failed,"composed world fits the original photography shop")
	check(passage.residency.state=="RESIDENT","normal prefetch exposes fitted stock geometry")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_photo_portraits.json"))
	check(FileAccess.get_sha256("res://assets/props/photo_portraits.glb")==fixture.asset_sha256,"installed mesh binds the native process-equipment export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("PhotoPortraits")
		var originals: Dictionary=model.get_meta("original_meshes");var counts: Dictionary=model.get_meta("removed_triangles")
		for box: Dictionary in record.replace:
			check(counts[box.id]==int(box.expected_triangles),"exact original source boundary removed: "+str(box.id));removed+=int(counts[box.id])
		for draw: MeshInstance3D in originals:
			var original: Mesh=originals[draw];var retained:=draw.mesh
			check(retained.get_surface_count()==0 or original.get_surface_count()==retained.get_surface_count(),"remaining source material slots retained")
			for surface in retained.get_surface_count():
				var before:=original.surface_get_arrays(surface);var after:=retained.surface_get_arrays(surface)
				for attribute in Mesh.ARRAY_MAX:
					if attribute==Mesh.ARRAY_INDEX:continue
					check(before[attribute]==after[attribute],"other source vertex attribute remains identical: "+str(attribute))
				check(original.surface_get_material(surface)==retained.surface_get_material(surface),"original source material remains identical")
			var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
			check((shape.disabled and not draw.visible) if retained.get_surface_count()==0 else (shape.shape as ConcavePolygonShape3D).get_faces()==retained.get_faces(),"trimmed physical boundaries match visible boundaries")
		for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			parts+=1;var count:=draw.mesh.get_faces().size()/3;triangles+=count
			var name:=str(draw.get_meta("photo_portraits_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			var runtime_part: Dictionary=record.parts.filter(func(row):return row.name==name)[0]
			if name in fixture.runtime.image_parts:
				var art:=draw.mesh.surface_get_material(0) as StandardMaterial3D
				check(art!=null and art.albedo_texture!=null and art.albedo_texture.get_width()==1024 and art.albedo_texture.get_height()==1536,"actual registered art role carries the exact generated atlas")
				check(art.albedo_texture.get_image().has_mipmaps(),"generated print content has declared mipmaps for stable distance sampling")
				check(art.uv1_scale==Vector3.ONE and art.uv1_offset==Vector3.ZERO and not art.uv1_triplanar and art.roughness_texture==null and art.normal_texture==null and not art.normal_enabled and is_equal_approx(art.roughness,.82) and art.metallic==0.,"local matte ink face uses the declared flat optical finish and unit cell charts")
				check(str(draw.get_meta("material_key"))=="art" and str(draw.get_meta("portrait_content_sha256"))==str(fixture.runtime.image_content.sha256),"local content binds existing artwork role and exact source bytes")
				_check_atlas_chart(draw,fixture)
			else:
				_check_cap_mapping(draw.mesh,true)
				var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
				check(mat!=null and not mat.uv1_triplanar and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null,"registered process-equipment and timber maps reach native metre charts")
				var source: StandardMaterial3D
				for original_draw: MeshInstance3D in originals:
					if str(original_draw.name).trim_suffix("-col").ends_with("_"+str(runtime_part.key)):source=originals[original_draw].surface_get_material(0)
				if runtime_part.has("catalog_key"):
					var library:=MatLib.get_mat(str(runtime_part.catalog_key))
					check(library!=mat and library.uv1_triplanar and library.albedo_texture==mat.albedo_texture and library.roughness_texture==mat.roughness_texture and library.normal_texture==mat.normal_texture and mat.uv1_scale.is_equal_approx(library.uv1_scale),"local registered finishes use their catalogue owner without changing shared materials")
					check(mat.metallic==library.metallic and mat.roughness==library.roughness and mat.normal_scale==library.normal_scale,"catalogued finish retains its metallic, roughness and normal strength")
				else:
					check(source!=null and source!=mat and source.albedo_texture==mat.albedo_texture and source.roughness_texture==mat.roughness_texture and source.normal_texture==mat.normal_texture,"original timber, glass, bakelite and other shipping materials retain their original shipping maps")
					check(source!=null and source.metallic==mat.metallic and source.roughness==mat.roughness and source.normal_scale==mat.normal_scale,"source finish retains its metallic, roughness and normal strength")
					if str(runtime_part.key)=="glassish":
						check(source!=null and source.albedo_texture==null and mat.albedo_texture==null and source.albedo_color.is_equal_approx(mat.albedo_color) and source.cull_mode==mat.cull_mode,"drawn glass keeps exact original tint, alpha and culling")
						check(not runtime_part.has("plain_alpha") and mat.transparency==source.transparency,"drawn sheet glazing retains the exact original transparency owner")
				if runtime_part.has("tint"):
					var tint: Array=runtime_part.tint
					check(mat.albedo_color.is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3])),"local wrapper or wear finish uses its bounded tint")
			var bounds: AABB=draw.transform*draw.mesh.get_aabb();check(maxf(maxf(bounds.size.x,bounds.size.y),bounds.size.z)<5.,"individual furniture partitions retain bounded culling")
			var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"native furniture physical triangles and poses match visible triangles")
		for contact: Dictionary in fixture.contacts:
			var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
			for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
				var draw:=body.get_parent() as MeshInstance3D
				if draw!=null and str(draw.get_meta("photo_portraits_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_portrait_details(world,fixture)
	await _retail_detail_views(world,fixture)
	return {"checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures.duplicate()}

func _check_atlas_chart(draw: MeshInstance3D, fixture: Dictionary) -> void:
	var name:=str(draw.get_meta("photo_portraits_part"));var identity:=name.trim_suffix("__image")
	var picture: Dictionary=fixture.runtime.portraits.filter(func(row):return row.id==identity)[0]
	var arrays:=draw.mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	check(uv.size()==vertices.size() and draw.mesh.get_faces().size()==6,"one actual two-triangle image face per rigid card")
	var col:=int(picture.atlas_cell)%2;var row_index:=int(picture.atlas_cell)/2
	for index in vertices.size():
		var point:=draw.transform*vertices[index]
		var u:=(point.z+float(picture.position[1]))/float(picture.width)+.5
		var v:=1.-(point.y-(float(picture.position[2])-float(picture.height)*.5))/float(picture.height)
		var expected:=Vector2(col*.5+.005+u*.49,row_index*.5+.005+v*.49)
		check(uv[index].distance_to(expected)<.000015,"exact intended portrait cell has upright, unmirrored image coordinates: "+identity)
		check(absf(point.x-(float(picture.position[0])-.0015))<.00001 and (draw.basis*normals[index]).dot(Vector3.LEFT)>.999,"actual aisle-facing image sits on the rigid card front")

func _check_portrait_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_photo_supplies;var model: Node3D=cell.get_node("PhotoPortraits")
	check(fixture.original_records.size()==8 and fixture.assemblies.size()==8 and fixture.runtime.portraits.size()==7,"exact original rail and seven unclaimed print identities remain the scope")
	check(FileAccess.get_sha256(str(fixture.runtime.image_content.resource))==str(fixture.runtime.image_content.sha256),"canonical generated content has exact recorded source bytes")
	check((ResourceLoader.load(str(fixture.runtime.image_content.catalog_binding.shipping_albedo)) as Texture2D)!=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("material_key"))=="art")[0].mesh.surface_get_material(0).albedo_texture,"shared artwork atlas retains its original owner")
	var bands: Dictionary=model.get_meta("picture_reservations").bands
	check(bands.size()==1 and bands.values()[0].size()==7,"actual single wall law reserves seven non-overlapping hooks")
	for i in range(1,7):
		var left: Dictionary=fixture.runtime.portraits[i-1];var right: Dictionary=fixture.runtime.portraits[i]
		check(absf(float(right.position[1])-float(left.position[1]))-float(left.width)*.5-float(right.width)*.5>=WallArtLaw.VISUAL_GAP,"seven rigid cards retain the shared minimum visual gap")

func _portrait_visible(world: OrisonV2RuntimeRoot, cell: Node3D, picture: Dictionary, feet: Vector3) -> bool:
	var eye:=cell.to_global(feet+Vector3(0,world.player.STANDING_EYE,0));var model: Node3D=cell.get_node("PhotoPortraits")
	var draw: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false).filter(func(part):return str(part.get_meta("photo_portraits_part"))==str(picture.id)+"__image")[0]
	var body: CollisionObject3D=draw.find_children("*","CollisionShape3D",true,false)[0].get_parent()
	for offset: Vector2 in [Vector2.ZERO,Vector2(-.075,-.115),Vector2(.075,-.115),Vector2(-.075,.115),Vector2(.075,.115)]:
		var at:=Vector3(float(picture.position[0])-.0015,float(picture.position[2])+offset.y,-float(picture.position[1])+offset.x)
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,cell.to_global(at+Vector3(.001,0,0)),1,[world.player.get_rid()]))
		if hit.is_empty() or hit.collider!=body:return false
	return true

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_photo_supplies;var observations: Array=[]
	for picture: Dictionary in fixture.runtime.portraits:
		var preferred:=Vector3(21.88,.03,-float(picture.position[1]));var selected:=preferred;var clear:=false
		for offset: Vector3 in [Vector3.ZERO,Vector3(.40,0,0),Vector3(-.30,0,0),Vector3(0,0,.30),Vector3(0,0,-.30),Vector3(.40,0,.30),Vector3(.40,0,-.30)]:
			var feet:=preferred+offset
			if _city_clear_station(world,cell.to_global(feet)) and _portrait_visible(world,cell,picture,feet):selected=feet;clear=true;break
		check(clear,"actual standing capsule and five unobstructed rays reach the whole unclaimed card: "+str(picture.id))
		if not clear:continue
		world.player.global_position=cell.to_global(selected);world.player.velocity=Vector3.ZERO
		var at:=Vector3(picture.position[0],picture.position[2],-float(picture.position[1]));world.player.face_world_point(cell.to_global(at));world.player.set_lamp_enabled(true)
		if capture_enabled:
			await _settled_optics();await shot(str(picture.id).trim_prefix("storm_shop_photo_supplies_"))
		observations.append({"id":picture.id,"feet":[selected.x,selected.y,selected.z],"requested_feet":[preferred.x,preferred.y,preferred.z],"target":[at.x,at.y,at.z],"unobstructed_rays":5,"image":str(picture.id).trim_prefix("storm_shop_photo_supplies_")+".png"})
	var context_feet:=Vector3(20.5,.03,62.70);check(_city_clear_station(world,cell.to_global(context_feet)),"floor-supported original process-context station remains clear")
	world.player.global_position=cell.to_global(context_feet);world.player.face_world_point(cell.to_global(Vector3(22.885,1.385,61.95)));world.player.set_lamp_enabled(true)
	if capture_enabled:
		await _settled_optics();await shot("portrait_context")
	observations.append({"id":"portrait_context","feet":[20.5,.03,62.70],"target":[22.885,1.385,61.95],"image":"portrait_context.png"})
	check(observations.size()==8,"all seven unclaimed prints and one standing context observation are retained")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Supported standing unclaimed-print observations with actual visibility rays; continuous shop/darkroom routes and operating photography remain separate."},"\t"))
