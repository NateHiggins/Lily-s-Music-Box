extends "res://tests/v2_spatial_access_cohort.gd"
## Production prop/player in a small fixture. No installed-room or network grant.
const Metrics=preload("res://tests/orison_v2_domestic_native_test.gd")
const Hand=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand

func _run() -> void:
	initial_inputs=_inputs();bindings=_dependencies()
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	var stage:=Node3D.new();add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.035,.04,.05)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy=.22;stage.add_child(environment)
	var wall:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(1.6,2.8,.15)
	wall.mesh=box;wall.position=Vector3(0,1.4,.075);wall.material_override=MatLib.get_mat("plaster");stage.add_child(wall);wall.create_trimesh_collision()
	var prop:=FlueBreastProp.new();prop.prop_type="flue_breast";prop.unit="5C";stage.add_child(prop)
	var player:=PlayerController.new();stage.add_child(player)
	player.set_physics_process(false);player.call_locked=false;player.mouse_released=false
	player.position=Vector3(0,0,-.9);player.camera.global_position=Vector3(.12,1.5,-.7)
	player.camera.make_current();player.camera.look_at(Vector3(0,1.44,-.09));player.set_lamp_enabled(true)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for layer: CanvasLayer in player.find_children("*","CanvasLayer",true,false):layer.hide()
	await get_tree().physics_frame;await get_tree().physics_frame
	_check(prop.visible_mesh_count()==13,"thirteen real native stocks, including two closure pieces")
	_check(prop._cap.get_child_count()==3,"one moving closure owns two stocks and its precise grip")
	_check(prop.interact_prompt().is_empty(),"no player E toggle or inspection card prompt")
	_check(prop.state==FunctionalProp.PState.OPERATING and prop.profile==FunctionalProp._catalog.flue_breast,"original mechanical profile and normal function remain")
	var metrics: Node=Metrics.new();var textures: Dictionary={}
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/runtime_material_sets.json")).materials
	for draw: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):
		var material:=draw.material_override as StandardMaterial3D
		var key: String=material.get_meta("v2_surface_stock","")
		_check(key in ["soot","iron_neutral"] and not material.uv1_triplanar and material.uv1_scale==Vector3.ONE,"catalogue stock with authored tile charts: "+str(draw.name))
		_check(material.normal_enabled and is_equal_approx(material.normal_scale,.15 if key=="soot" else .25),"actual normal recipe: "+str(draw.name))
		var copy:=ArrayMesh.new()
		for surface in draw.mesh.get_surface_count():
			var arrays: Array=draw.mesh.surface_get_arrays(surface);var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			for index in uv.size():uv[index]*=float(catalog[key].meters_per_tile)
			arrays[Mesh.ARRAY_TEX_UV]=uv;copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		metrics._check_cap_mapping(copy,true)
		for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
			_check(texture!=null,"all custom PBR maps loaded: "+str(draw.name))
			if texture==null or textures.has(texture.resource_path):continue
			textures[texture.resource_path]=true
			var image:=texture.get_image()
			_check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(maxi(image.get_width(),image.get_height()))/log(2.))),"actual full loaded mip chain: "+texture.resource_path)
		if key=="soot":
			var colors: PackedColorArray=draw.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR];var low:=1.;var high:=0.
			for color in colors:low=minf(low,color.a);high=maxf(high,color.a)
			_check(low<.001 and high>.99 and material.vertex_color_use_as_albedo and material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"actual imported deposit alpha fades completely at its boundary")
	for label: String in metrics.failures:_check(false,label)
	_check(metrics.failures.is_empty(),"all imported metric UV and normal/tangent derivatives pass")
	metrics.free();_check(textures.size()==6,"both complete custom PBR sets are exercised")
	var hand:=Hand.new();hand.player=player;add_child(hand)
	var contact:=prop._cap.to_global(Vector3(0,-.01,-.023))
	player.camera.look_at(contact)
	await get_tree().physics_frame;await get_tree().physics_frame
	_check(player._grab.find_target().get("owner")==prop,"cursor acquires the loose closure through the real wall fixture")
	var seated:=prop._cap.transform
	hand.click();_check(player._grab.active(),"actual primary click grabs closure")
	await _cursor_motion(hand,.5)
	_check(await hand.move_to(Vector3(.002,-.001,-.003).length()),"actual mouse motion rocks plate to original mechanical stop")
	_check(prop._cap.position.distance_to(seated.origin)>.003,"plate visibly translates and rocks while held")
	var held:=prop._cap.transform
	prop._perform_synced_event(0,.8,0.)
	await get_tree().create_timer(.08).timeout
	_check(prop._cap.transform.is_equal_approx(held) and prop._held,"conductor never steals a held plate")
	_check(prop._knock.pitch_scale>=.5 and prop._knock.pitch_scale<=.8,"original muffled knock tuning retained")
	await _shot(player,"held")
	_check(await hand.move_to(0.),"actual reverse mouse motion follows constraint")
	_check(await hand.move_to(Vector3(.002,-.001,-.003).length()),"second actual outward gesture")
	hand.click();_check(not player._grab.active(),"next primary click releases")
	await get_tree().create_timer(.35).timeout
	_check(prop._cap.transform.is_equal_approx(seated),"closure reseats after hand release")
	await _shot(player,"seated")
	player.camera.look_at(prop._cap.to_global(Vector3(0,-.01,-.023)))
	await get_tree().physics_frame;await get_tree().physics_frame
	hand.click();_check(player._grab.active(),"closure reacquired for inspection")
	var prior:=player.camera.global_transform
	var space:=InputEventAction.new();space.action="jump";space.pressed=true;player._unhandled_input(space)
	_check(player.inspecting() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not player._grab.active(),"actual Space enters static-camera cursor inspection")
	var anchor:=player.camera.global_transform
	await get_tree().create_timer(.3).timeout
	_check(player.camera.global_transform.is_equal_approx(anchor),"inspection camera remains static")
	Input.warp_mouse(player.camera.unproject_position(prop._cap.to_global(Vector3(0,-.01,-.023))))
	await get_tree().process_frame;await get_tree().physics_frame
	hand.click();_check(player._grab.active(),"visible cursor selects the closure within inspection")
	await _cursor_motion(hand,.5)
	_check(await hand.move_to(Vector3(.002,-.001,-.003).length()),"actual inspection mouse motion manipulates closure")
	hand.click();await _shot(player,"inspection")
	player._unhandled_input(space)
	_check(not player.inspecting() and player.camera.global_transform.is_equal_approx(prior),"Space backs out and restores original eye")
	var reference: WeakRef=weakref(prop);hand.free();stage.free();await get_tree().process_frame
	_check(reference.get_ref()==null,"prop and production player retire")
	var final_inputs:=_inputs();_check(initial_inputs==final_inputs and bindings==_dependencies(),"all production/surface/test inputs remain frozen")
	var directory: String=OS.get_environment("SHOT_DIR");_check(not directory.is_empty(),"explicit proof directory")
	var head: Array=[]
	_check(OS.execute("git",["-C",ProjectSettings.globalize_path("res://.."),"rev-parse","HEAD"],head)==0 and head.size()==1,"record actual repository provenance")
	var receipt: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Production flue fitting and player in a small wall fixture: imported UV/PBR/mips, hand controls, static inspection and retirement only. No installed apartment, full flue network, save, navigation or human acceptance.",
		"execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false},
		"source":{"test_path":"game/tests/v2_flue_breast_bench.gd","test_sha256":bindings.get("game/tests/v2_flue_breast_bench.gd",""),"test_dependencies":bindings,"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":final_inputs.runtime,"surface_inputs_sha256":final_inputs.surface},
		"checks":checks,"failures":failures,"contracts":{"native_fitting":{"executed":true,"status":"PASS" if failures==0 else "FAIL"}}}
	if not directory.is_empty():FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("V2 FLUE BREAST BENCH: ","PASS" if failures==0 else "FAIL"," checks=",checks.size()," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)

func _shot(player: PlayerController,identity: String) -> void:
	var directory: String=OS.get_environment("SHOT_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(directory.path_join(identity+".png"))==OK,"actual windowed frame: "+identity)

func _cursor_motion(hand: Node3D,fraction: float) -> void:
	if not hand.player._grab.active():_check(false,"active plate for screen-direction measurement");return
	var target: Dictionary=hand.player._grab.target
	var contact: Vector3=hand.player._grab.contact
	var camera: Camera3D=hand.player.camera
	var point: Vector3=target.part.to_global(contact)
	var direction: Vector3=target.frame.global_basis*target.axis
	var screen: Vector2=(camera.unproject_position(point+direction*.01)-camera.unproject_position(point))/.01
	var before: Vector2=camera.unproject_position(point)
	var event:=InputEventMouseMotion.new();event.relative=screen*float(target.maximum)*fraction
	hand.player._unhandled_input(event);await get_tree().physics_frame
	var after: Vector2=camera.unproject_position(target.part.to_global(contact))
	_check(event.relative.length()>.01 and (after-before).dot(event.relative)>0.,"actual coupled plate travel follows the screen gesture, including in cursor inspection")
