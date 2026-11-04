extends RefCounted
## Loaded optical ABI and planar shading; controlled lights are test fixtures.
func validate_material_contract(suite: Node) -> void:
	var document: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/runtime_material_sets.json"))
	var source_root := ProjectSettings.globalize_path("res://..").simplify_path()
	var resin_recipe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_root.path_join("art/textures/procedural/bakelite/material.json")))
	for key: String in document.materials:
		var spec: Dictionary=document.materials[key]
		var stock := MatLib.get_mat(key)
		suite.check(is_equal_approx(stock.metallic,float(spec.metallic)),"catalogue metallic reaches renderer: "+key)
		suite.check(is_equal_approx(stock.roughness,float(spec.roughness_multiplier)),"catalogue roughness reaches renderer: "+key)
		suite.check(stock.transparency==(BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS if spec.alpha else BaseMaterial3D.TRANSPARENCY_DISABLED),"normal calibration preserves optical alpha: "+key)
		var expected_normal := .35
		if key=="bakelite":expected_normal=float(resin_recipe.normal_strength)
		elif key.begins_with("resident_"):
			# Retained source normals keep the glTF-authored calibration. Residents
			# without a source normal use the restrained generated atlas relief.
			# Read the independent original asset, not the generated runtime policy.
			var slug:=key.trim_prefix("resident_")
			var stem:="res://assets/characters/"+slug+"/"+slug
			var source:=stem+".gltf" if FileAccess.file_exists(stem+".gltf") else stem+".glb"
			var character: Dictionary=_source_document(suite,source)
			if character.is_empty():continue # A recorded failure,never a passing fallback.
			var originals: Variant=character.get("materials",[])
			suite.check(originals is Array,"resident source has a valid material declaration: "+slug)
			if not originals is Array:continue
			# A valid GLB can omit materials and use glTF's default material.
			# Adela's native export does so;its registered atlas gets the same
			# restrained generated relief as other sources without a normal map.
			var original: Dictionary={}
			if not originals.is_empty():
				suite.check(originals[0] is Dictionary,"resident source material is an object: "+slug)
				if not originals[0] is Dictionary:continue
				original=originals[0]
			if original.has("normalTexture"):expected_normal=float(original.normalTexture.get("scale",1.0))
		elif key.begins_with("site_softwood") or key.begins_with("arcade_"):
			var recipe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_root.path_join("art/textures/procedural/"+key+"/material.json")))
			expected_normal=float(recipe.normal_strength)
		elif str(spec.catalog_mapping).begins_with("procedural/"):
			var recipe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_root.path_join("art/textures/"+str(spec.catalog_mapping)+"/material.json")))
			if recipe.has("normal_authoring"):
				var authored: Dictionary=recipe.normal_authoring
				suite.check(authored.height_units=="metres" and authored.normal_convention=="OpenGL","metric relief units and normal convention: "+key)
				expected_normal=float(authored.normal_strength)
				suite.check(is_finite(expected_normal) and expected_normal>0. and is_equal_approx(expected_normal,float(recipe.normal_strength)),"profile and material normal strengths agree: "+key)
		suite.check(is_equal_approx(stock.normal_scale,expected_normal),"authored normal calibration reaches renderer: "+key)
	var resin := MatLib.get_mat("bakelite")
	suite.check(not document.materials.bakelite.visual_lock and document.materials.bakelite.catalog_mapping=="procedural/bakelite","brown phenolic resin retires the legacy visual lock")
	suite.check(is_equal_approx(resin.uv1_scale.x,25.) and is_equal_approx(resin.normal_scale,1.),"resin retains its authored 40 mm scale and calibrated relief")
	for texture: Texture2D in [resin.albedo_texture,resin.roughness_texture,resin.normal_texture]:
		var image := texture.get_image()
		suite.check(texture.get_width()==512 and texture.get_height()==512 and image!=null and image.has_mipmaps() and image.get_mipmap_count()==9,"resin loads the reduced complete 512-pixel mip chain")

func run(world: OrisonV2RuntimeRoot,suite: Node) -> void:
	var board := world.adapter.resolve("LobbyPorterBoard") as OtisProp
	suite.check(board!=null and board._native_dispatch!=null,"changed finish is installed on the production board")
	if board==null or board._native_dispatch==null:return
	var rows: Array=[];var seen: Dictionary={}
	for draw: MeshInstance3D in board._native_dispatch.find_children("*","MeshInstance3D",true,false):
		var part := str(draw.get_meta("native_annunciator_dispatch_part",""))
		if part not in ["Apron","ButtonCap"] or seen.has(part):continue
		seen[part]=true
		var result := _planar_bias(draw.mesh)
		result["part"]=part;rows.append(result)
		suite.check(result.front_triangles>0 and result.maximum_bias_degrees<.05,"loaded manufactured front remains planar: "+part)
	suite.check(seen.size()==2,"both corrected front-stock families are inspected")
	var directory := OS.get_environment("SHOT_DIR")
	var player := world.player
	var prior_camera := suite.get_viewport().get_camera_3d()
	var prior_transform := player.camera.global_transform
	var prior_fov := player.camera.fov
	var prior_lamp := player.lamp_is_enabled()
	player.camera.global_position=board.to_global(Vector3(.17,-.24,.43))
	player.camera.look_at(board.to_global(Vector3(0,-.28,.048)));player.camera.fov=48.;player.camera.make_current()
	player.set_lamp_enabled(true)
	await suite.get_tree().create_timer(.8).timeout
	await _shot(suite,directory,"control_finish_carried")
	player.set_lamp_enabled(false)
	var deadline := Time.get_ticks_msec()+5000
	while player.flashlight.visible and Time.get_ticks_msec()<deadline:await suite.get_tree().create_timer(.05).timeout
	suite.check(not player.flashlight.visible,"room-only finish capture has a settled real lamp-off state")
	await _shot(suite,directory,"control_finish_room")
	var fixture := OmniLight3D.new();fixture.name="TestOnlyControlFinishLight"
	fixture.light_color=Color.WHITE;fixture.light_energy=.08;fixture.omni_range=.85;fixture.shadow_enabled=true
	fixture.layers=player.flashlight.layers
	world.add_child(fixture)
	for setup in [["diffuse",Vector3(.02,-.22,.36)],["grazing",Vector3(.30,-.30,.09)]]:
		fixture.global_position=board.to_global(setup[1])
		await suite.get_tree().create_timer(.2).timeout
		await _shot(suite,directory,"control_finish_"+str(setup[0]))
	fixture.free()
	player.camera.global_transform=prior_transform;player.camera.fov=prior_fov
	player.set_lamp_enabled(prior_lamp)
	if is_instance_valid(prior_camera):prior_camera.make_current()
	FileAccess.open(directory.path_join("control_finish_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","planar_stock":rows,"scope":"Loaded optical ABI, changed planar normals and four installed finish views. Diffuse/grazing use a declared temporary test light; not production lighting acceptance or disk reconstruction."},"\t"))

func _planar_bias(mesh: Mesh) -> Dictionary:
	var count := 0;var worst := 1.
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for triangle in range(0,indices.size(),3):
			var a := indices[triangle];var b := indices[triangle+1];var c := indices[triangle+2]
			var geometric := (points[b]-points[a]).cross(points[c]-points[a]).normalized()
			if absf(geometric.z)<.999999 or (normals[a]+normals[b]+normals[c]).z<2.7:continue
			count+=1
			for i in [a,b,c]:worst=minf(worst,normals[i].normalized().z)
	return {"front_triangles":count,"maximum_bias_degrees":rad_to_deg(acos(clampf(worst,-1.,1.)))}

func _source_document(suite: Node,path: String) -> Dictionary:
	# Inspect independent native declarations,not generated runtime policy.
	# Bounded GLB header/chunk checks follow the existing critter source reader.
	var file:=FileAccess.open(path,FileAccess.READ)
	suite.check(file!=null,"resident native source is readable: "+path)
	if file==null:return {}
	var payload: String
	if path.get_extension()=="glb":
		var header_ok:=file.get_length()>=20
		if header_ok:header_ok=file.get_32()==0x46546c67 and file.get_32()==2
		suite.check(header_ok,"resident GLB has a complete version2 header: "+path)
		if not header_ok:file.close();return {}
		var length:=file.get_32();var json_length:=file.get_32();var kind:=file.get_32()
		var chunk_ok:=length==file.get_length() and kind==0x4e4f534a and json_length>0 and json_length<=length-20
		suite.check(chunk_ok,"resident GLB JSON chunk is bounded by the actual file: "+path)
		if not chunk_ok:file.close();return {}
		payload=file.get_buffer(json_length).get_string_from_utf8()
	else:payload=file.get_as_text()
	file.close()
	var parser:=JSON.new()
	var valid:=parser.parse(payload)==OK and parser.data is Dictionary
	suite.check(valid,"resident native JSON is an object: "+path)
	if not valid:return {}
	var document: Dictionary=parser.data
	suite.check(document.get("asset") is Dictionary,"resident native document declares its asset: "+path)
	return document if document.get("asset") is Dictionary else {}

func _shot(suite: Node,directory: String,label: String) -> void:
	await RenderingServer.frame_post_draw
	suite.check(suite.get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"changed control finish capture: "+label)
