extends "res://tests/orison_v2_roof_base_flashings_test.gd"
## Actual production fit and surface observations. No drainage or ledger claim.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"fitted roof starts in production")
	if world.player==null:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root
	var model: Node3D=root.get_node("RoofMembrane")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_membrane.json"))
	var structural_datum:=0.0
	var owners: Dictionary={}
	for part: Dictionary in fixture.parts:owners[str(part.owner)]=true
	var owner_levels: Dictionary={}
	for space_record: Dictionary in root.layout.spaces:
		if owners.has(str(space_record.id)):owner_levels[str(space_record.level)]=true
	check(owner_levels.size()==1,"source finish owners share one structural level")
	if owner_levels.size()==1:structural_datum=float(root.level_y[str(owner_levels.keys()[0])])
	for path: String in fixture.source_bindings:
		var runtime_path: String=path.replace("game/","res://")
		if not path.begins_with("game/"):continue
		check(FileAccess.get_file_as_string(runtime_path).replace("\r\n","\n").sha256_text()==fixture.source_bindings[path],"fitted roof binds the actual LF-normalized source")
	check(FileAccess.get_sha256("res://assets/props/roof_membrane.glb")==fixture.asset_sha256,"fitted roof binds the actual installed mesh")
	var retained: Dictionary={}
	var floor_ids: Dictionary={}
	for identity: String in owners:
		var floor: MeshInstance3D=root.get_node(identity+"/Floor")
		if floor.mesh==null:
			check(false,"retained floor sides remain present")
			world.shutdown_for_tests();world.free();get_tree().quit(1);return
		floor_ids[(floor.get_node("Collision") as CollisionObject3D).get_rid()]=true
		retained[identity]=floor.mesh
		for surface in floor.mesh.get_surface_count():
			var arrays: Array=floor.mesh.surface_get_arrays(surface)
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for triangle in range(0,indices.size(),3):
				check(not (normals[indices[triangle]].y>.9 and normals[indices[triangle+1]].y>.9 and normals[indices[triangle+2]].y>.9),"former bare top contributes no duplicate render face")
	var substrate_exclusions: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if not floor_ids.has(body.get_rid()):substrate_exclusions.append(body.get_rid())
	var native:=PackedVector3Array()
	var parts:=0;var triangles:=0
	# Godot stores imported vertex albedo in RGBA8. The glTF's normalized
	# uint16 value is truncated when packed into that 8-bit representation.
	var imported_bond:=floorf(float(fixture.recipe.bond_tint)*255.)/255.
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var faces: PackedVector3Array=preload("res://scripts/building/orison_v2_native_faces.gd").read(draw.mesh)
		parts+=1;triangles+=faces.size()/3
		_check_cap_mapping(draw.mesh,true)
		var material:=draw.material_override as StandardMaterial3D
		check(material!=null and material.albedo_texture!=null and material.roughness_texture!=null and material.normal_texture!=null,"three real catalogue maps reach the finish")
		check(material!=MatLib.get_mat("roof_bitumen") and not material.uv1_triplanar,"fitted chart owns UVs without changing the shared catalogue material")
		check(material.vertex_color_use_as_albedo and not material.vertex_color_is_srgb,"one physical roof material reads linear bond shading without extra seam draws")
		for surface in draw.mesh.get_surface_count():
			var colours: PackedColorArray=draw.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			check(not colours.is_empty(),"authored bond shading survives the native export")
			var valid_colours:=true
			for colour: Color in colours:
				valid_colours=valid_colours and absf(colour.r-colour.g)<.00001 and absf(colour.g-colour.b)<.00001 and (absf(colour.r-1.)<.00001 or absf(colour.r-imported_bond)<.00001)
			check(valid_colours,"every field and bond vertex retains its authored factor at the imported RGBA8 precision")
		var bounds: AABB=draw.transform*draw.mesh.get_aabb()
		check(maxf(bounds.size.x,bounds.size.z)<=4.00001,"finish partitions retain bounded culling")
		var actual: PackedVector3Array=draw.transform*faces
		var positive_falls:=true
		for triangle in range(0,actual.size(),3):
			var normal: Vector3=(actual[triangle+1]-actual[triangle]).cross(actual[triangle+2]-actual[triangle]).normalized()
			positive_falls=positive_falls and absf(normal.y)>.999 and Vector2(normal.x,normal.z).length()/absf(normal.y)>.0099
			for offset in 3:positive_falls=positive_falls and actual[triangle+offset].y>=structural_datum+.00998
		check(positive_falls,"every imported finish triangle retains positive physical fall above the full structural slab")
		native.append_array(actual)
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles),"actual part and triangle counts bind the source inventory")
	check(MatLib.get_mat("roof_bitumen").uv1_triplanar,"shared catalogue projection remains unchanged")
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	var contacts:=0
	for station: Dictionary in fixture.stations:
		var at:=_v(station.point)
		var query:=PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.03),root.to_global(at-Vector3.UP*.03),1,substrate_exclusions)
		var hit: Dictionary=space.intersect_ray(query)
		check(not hit.is_empty() and hit.collider==root.get_node(str(station.owner)+"/Floor/Collision") and root.to_local(hit.position).distance_to(at)<.00003,"original physical floor exactly backs fitted finish")
		contacts+=1
	for opening: Dictionary in root.layout.slab_openings:
		if opening.surface!="Floor" or not owners.has(str(opening.space)):continue
		var rect: Array=opening.rect
		var at:=Vector3((rect[0]+rect[2])*.5,structural_datum,(rect[1]+rect[3])*.5)
		check(_mesh_distance(native,at+Vector3.UP*.02,Vector3.DOWN)==INF,"actual finish does not cover the retained fan aperture")
		var query:=PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.02),root.to_global(at-Vector3.UP*.21),1,substrate_exclusions)
		check(space.intersect_ray(query).is_empty(),"original physical fan throat stays open")
	var observations: Array[Dictionary]=[]
	for view: Array in [["roof_west",Vector3(-14.5,20.81,0),Vector3(2,20.5,0)],
		["roof_field",Vector3(-12,20.81,-9),Vector3(-7.5,19.2,-7.4)],
		["roof_seam_close",Vector3(-12.6,20.81,-9),Vector3(-12.,19.2,-8.0)],
		["roof_parapet",Vector3(14.3,20.81,10.5),Vector3(15.49,19.25,11.49)],
		["roof_east",Vector3(14.1,20.81,5.5),Vector3(14.5,19.2,8.7)]]:
		world.player.global_position=root.to_global(view[1])-Vector3.UP*world.player.STANDING_EYE
		world.player.face_world_point(root.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0])
		var after:=_visible_counts()
		model.hide()
		var bare: Dictionary=model.get_meta("bare_roof_meshes")
		for identity: String in bare:root.get_node(identity+"/Floor").mesh=bare[identity]
		await _settled_optics();await shot(str(view[0])+"_before")
		var before:=_visible_counts()
		for identity: String in retained:root.get_node(identity+"/Floor").mesh=retained[identity]
		model.show()
		observations.append({"view":view[0],"before":before,"after":after,"note":"Same-camera rendering substitution; normal eye height except labelled close detail. No new lighting or physics and no FPS acceptance."})
	var file:=FileAccess.open(OS.get_environment("SHOT_DIR").path_join("roof-membrane-inspection.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"contacts":contacts,"parts":parts,"triangles":triangles,"failures":failures,"observations":observations},"\t"))
	print("ROOF MEMBRANE: checks=",checks," contacts=",contacts," parts=",parts," triangles=",triangles," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio()
	get_tree().quit(0 if failures.is_empty() else 1)

func _visible_counts() -> Dictionary:
	var viewport:=get_viewport().get_viewport_rid()
	return {"draws":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"primitives":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}
