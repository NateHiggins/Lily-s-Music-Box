extends "res://tests/v2_spatial_access_cohort.gd"
## Imported stock only. Shipping-world installation and authorities stay pending.
const Stock=preload("res://scripts/building/c_stove_stack_stock.gd")
const Metrics=preload("res://tests/orison_v2_domestic_native_test.gd")

func _run() -> void:
	initial_inputs=_inputs();bindings=_dependencies()
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests();CampaignTime.set_frozen_for_tests(true)
	var stage:=Node3D.new();add_child(stage)
	var stock: Node3D=Stock.build();stage.add_child(stock)
	var draws:=stock.find_children("*","MeshInstance3D",true,false)
	_check(draws.size()==4,"native closed source stocks import as four physical material batches")
	var metrics: Node=Metrics.new();var textures: Dictionary={};var triangles:=0
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/runtime_material_sets.json")).materials
	for draw: MeshInstance3D in draws:
		var key:=str(draw.name);var material:=draw.material_override as StandardMaterial3D
		_check(Stock.STRENGTHS.has(key) and str(material.get_meta("v2_surface_stock",""))==key,"registered custom physical stock: "+key)
		_check(not material.uv1_triplanar and not material.uv2_triplanar and material.uv1_scale==Vector3.ONE,"authored normalized metric UV: "+key)
		_check(material.normal_enabled and is_equal_approx(material.normal_scale,float(Stock.STRENGTHS[key])) and material.vertex_color_use_as_albedo,"actual normal and kiln-variation recipe: "+key)
		var copy:=ArrayMesh.new()
		for surface in draw.mesh.get_surface_count():
			var arrays: Array=draw.mesh.surface_get_arrays(surface);var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			for index in uv.size():uv[index]*=float(catalog[key].meters_per_tile)
			arrays[Mesh.ARRAY_TEX_UV]=uv;copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX];triangles+=indices.size()/3
		metrics._check_cap_mapping(copy,true)
		for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
			_check(texture!=null,"custom PBR map loaded: "+key)
			if texture==null or textures.has(texture.resource_path):continue
			textures[texture.resource_path]=true;var image:=texture.get_image()
			_check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(maxi(image.get_width(),image.get_height()))/log(2.))),"actually loaded full mip chain: "+texture.resource_path)
	for label: String in metrics.failures:_check(false,label)
	_check(metrics.failures.is_empty(),"all four imported batches meet unchanged metric UV/normal/tangent/handedness tolerances")
	metrics.free();_check(textures.size()==12,"four complete custom PBR sets exercised")
	var installed_inspector:=preload("res://tests/v2_c_stove_surface_inspector.gd").new()
	var installed_report: Dictionary=installed_inspector.inspect(stock)
	_check(installed_inspector.failures==0 and int(installed_report.metric_checks)>0,"installed-world surface inspector ABI and actual stock checks pass")
	installed_inspector.free()
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.035,.04,.05)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.35;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-55,0);sun.light_energy=1.2;sun.shadow_enabled=true;stage.add_child(sun)
	var player:=PlayerController.new();stage.add_child(player);player.set_physics_process(false);player.camera.make_current();player.set_lamp_enabled(true)
	for layer: CanvasLayer in player.find_children("*","CanvasLayer",true,false):layer.hide()
	await get_tree().physics_frame;await get_tree().physics_frame
	var physical:=stage.get_world_3d().direct_space_state;var mouths:=0;var vertical:=0
	for y: float in [4.64,7.84,11.04,14.24,17.44]:
		for offset: Vector2 in [Vector2.ZERO,Vector2(.08,0),Vector2(-.08,0),Vector2(0,.08),Vector2(0,-.08)]:
			var query:=PhysicsRayQueryParameters3D.create(Vector3(6.99,y+offset.x,10.05+offset.y),Vector3(7.57,y+offset.x,10.05+offset.y),1,[player.get_rid()])
			_check(physical.intersect_ray(query).is_empty(),"actual native round mouth clearance: "+str(y)+" "+str(offset));mouths+=1
	for x: float in [7.68,7.74,7.80]:
		var query:=PhysicsRayQueryParameters3D.create(Vector3(x,-3.18,10.05),Vector3(x,21.5,10.05),1,[player.get_rid()])
		_check(physical.intersect_ray(query).is_empty(),"actual full native vertical airway: "+str(x));vertical+=1
	var control:=PhysicsRayQueryParameters3D.create(Vector3(6.9,4.64,10.30),Vector3(7.60,4.64,10.30),1,[player.get_rid()])
	_check(not physical.intersect_ray(control).is_empty(),"positive retained masonry beside the round mouth")
	var directory: String=OS.get_environment("SHOT_DIR");_check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"explicit imported-stock output")
	for view: Array in [["port",Vector3(6.2,4.9,9.4),Vector3(7.25,4.64,10.05)],["crown",Vector3(6.8,22.3,9.2),Vector3(7.74,21.23,10.05)],["brick_face",Vector3(8.8,1.6,11.1),Vector3(7.74,1.4,10.4)]]:
		player.global_position=view[1]-Vector3.UP*PlayerController.STANDING_EYE;player.camera.position=Vector3(0,PlayerController.STANDING_EYE,0);player.camera.look_at(view[2])
		for frame in 12:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check(get_viewport().get_texture().get_image().save_png(directory.path_join(str(view[0])+".png"))==OK,"actual imported stock under carried light: "+str(view[0]))
	var reference: WeakRef=weakref(stock);stage.free();await get_tree().process_frame
	_check(reference.get_ref()==null,"native stock retires with its fixture")
	var final_inputs:=_inputs();_check(initial_inputs==final_inputs and bindings==_dependencies(),"production/render/test inputs stay fixed")
	var receipt: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Imported C stove-stack stock fixture only: UV/PBR/mips, exact native openings and retirement. Not installed rooms, shipping roof/grade cuts, whole network/gameplay or human acceptance.","execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false},
		"source":{"test_path":"game/tests/v2_c_stove_stock_bench.gd","test_sha256":bindings.get("game/tests/v2_c_stove_stock_bench.gd",""),"test_dependencies":bindings,"runtime_inputs_sha256":final_inputs.runtime,"surface_inputs_sha256":final_inputs.surface},"checks":checks,"failures":failures,
		"contracts":{"native_stock":{"executed":true,"status":"PASS" if failures==0 else "FAIL","batches":draws.size(),"triangles":triangles,"mouth_rays":mouths,"vertical_rays":vertical}}}
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("C STOVE STOCK BENCH: ","PASS" if failures==0 else "FAIL"," checks=",checks.size()," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)
