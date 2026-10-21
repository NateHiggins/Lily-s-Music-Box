extends "res://tests/v2_spatial_access_cohort.gd"
## Imported rebuilt construction only, before composing the new full world.
const Metrics=preload("res://tests/orison_v2_domestic_native_test.gd")
func _run() -> void:
	var stage:=Node3D.new();add_child(stage)
	var metrics: Node=Metrics.new();var parts:=0
	for path: String in ["res://assets/props/exterior_masonry.glb","res://assets/props/roof_drainage_falls.glb","res://assets/props/roof_membrane.glb","res://assets/props/roof_base_flashings.glb","res://assets/props/roof_service_weathering.glb","res://assets/props/roof_public_weathering.glb"]:
		var stock: Node3D=(load(path) as PackedScene).instantiate();stage.add_child(stock)
		for draw: MeshInstance3D in stock.find_children("*","MeshInstance3D",true,false):
			metrics._check_cap_mapping(draw.mesh,true);parts+=1
		stock.free()
	var alley:=preload("res://scripts/building/orison_v2_service_alley.gd").new();stage.add_child(alley)
	var textures: Dictionary={}
	for draw: MeshInstance3D in alley.find_children("*","MeshInstance3D",true,false):
		if not draw.is_visible_in_tree() or draw.mesh==null:continue
		# Production lamps are unchanged procedural fixtures, not this native batch.
		if not draw.has_meta("v2_alley_source"):continue
		metrics._check_cap_mapping(draw.mesh,true);parts+=1
		var mat:=draw.material_override as StandardMaterial3D
		_check(mat!=null and not mat.uv1_triplanar,"actual alley stock uses its authored UV: "+str(draw.name))
		if mat==null:continue
		_check(mat.normal_enabled and mat.normal_texture!=null,"actual alley normal relief is enabled")
		for texture: Texture2D in [mat.albedo_texture,mat.roughness_texture,mat.normal_texture]:
			_check(texture!=null,"custom alley PBR map loaded")
			if texture==null or textures.has(texture.resource_path):continue
			textures[texture.resource_path]=true;var image:=texture.get_image()
			_check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(maxi(image.get_width(),image.get_height()))/log(2.))),"actual complete alley mip chain: "+texture.resource_path)
	for label: String in metrics.failures:_check(false,label)
	_check(metrics.failures.is_empty() and parts>100,"all rebuilt native family charts and tangent bases pass unchanged tolerances")
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(9.0,1.5,10.0);camera.look_at(Vector3(7.6,1.5,10.9));camera.make_current()
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.08,.09,.10);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.35;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-20,0);sun.shadow_enabled=true;stage.add_child(sun)
	var directory: String=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory);await get_tree().create_timer(.2).timeout;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("alley_authored_uv.png"))
	metrics.free();stage.free();await get_tree().process_frame
	print("C STOVE FABRICATION BENCH: ","PASS" if failures==0 else "FAIL"," parts=",parts," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)
