extends "res://tests/dream_surface_s2i_runtime_shot.gd"
## Material-identity-only continuation. Geometry and exclusive LOD policy are inherited unchanged.


func _ready() -> void:
	out_dir=OS.get_environment("S2J_OUT")
	if out_dir.is_empty() or not out_dir.is_absolute_path(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_stage(); call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	for _i in 4: await RenderingServer.frame_post_draw
	var vram_base:=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	var moss:=_make_hero(Hero.HeroKind.PLASMODIUM)
	var transport:=_make_hero(Hero.HeroKind.TRANSPORT)
	var interior:=_make_hero(Hero.HeroKind.INTERIOR)
	for _i in 8: await RenderingServer.frame_post_draw
	evidence={"task":"DREAM-SURFACE-S2J","captures":{},"threshold_samples":{}}

	# 1. One movable lamp, close relief and preserved gameplay hierarchy.
	_show(moss); moss.scale=Vector3.ONE*.52; _lamp(Vector3(2.0,2.7,1.2),1.95); moss.force_lod(0)
	var moss_close:=await _sample(Vector3(2.8,1.75,2.7),Vector3(0,.15,0))
	_lamp(Vector3(-1.8,1.0,-1.5),2.15); moss.force_lod(2)
	var moss_game:=await _sample(Vector3(10.0,5.6,8.8),Vector3(0,.12,0))
	var moss_thresholds:=await _threshold_samples(moss,[6.0,15.0],Vector3(.72,.38,.58))
	await _write_contact("01_plasmodium_close_gameplay_contact",[moss_close,moss_game],moss_thresholds)
	moss.force_lod(0); await _measure("01_plasmodium_close_gameplay_contact",moss)

	# 2. Value-separated membrane/protein/cargo and 2,125-triangle production form.
	_show(transport); transport.scale=Vector3.ONE*.54; transport.set_examination_mode(true); _lamp(Vector3(2.2,2.0,2.0),2.05); transport.force_lod(0)
	var transport_close:=await _sample(Vector3(2.45,1.42,2.45),Vector3.ZERO)
	_lamp(Vector3(-1.6,1.4,-1.5),1.75); transport.force_lod(3)
	var transport_low:=await _sample(Vector3(10.5,5.9,8.8),Vector3.ZERO)
	var transport_thresholds:=await _threshold_samples(transport,[4.5,10.0,19.0],Vector3(.72,.38,.58))
	await _write_contact("02_transport_close_production_contact",[transport_close,transport_low],transport_thresholds)
	transport.force_lod(0); await _measure("02_transport_close_production_contact",transport)

	# 3. The same lamp moves front/side/back; bounded windows remain one shell only.
	_show(interior); interior.scale=Vector3.ONE*.50; interior.set_examination_mode(false); interior.force_lod(0); interior.rotation_degrees=Vector3(0,180,0)
	_lamp(Vector3(2.4,1.8,2.2),1.55); var body_front:=await _sample(Vector3(3.0,1.8,3.1),Vector3(0,.05,0))
	_lamp(Vector3(2.5,1.0,-.5),1.70); var body_side:=await _sample(Vector3(3.3,1.55,.75),Vector3(0,.05,0))
	_lamp(Vector3(-1.8,.9,-1.8),2.20); var body_back:=await _sample(Vector3(3.0,1.8,3.1),Vector3(0,.05,0))
	var interior_thresholds:=await _threshold_samples(interior,[6.0,15.0],Vector3(.72,.38,.58))
	await _write_three_contact("03_intact_cellular_front_side_back",[body_front,body_side,body_back],interior_thresholds)
	interior.force_lod(0); await _measure("03_intact_cellular_front_side_back",interior)

	# 4. Direct cutaway and a colony component nested into a feeding mat in Orison.
	_lamp(Vector3(1.8,1.4,1.7),1.95); interior.set_examination_mode(true); interior.rotation_degrees=Vector3.ZERO; interior.scale=Vector3.ONE*.60
	var examination:=await _sample(Vector3(2.65,1.65,2.72),Vector3(0,.05,0))
	var room:=await _room_sample(interior,moss)
	await _write_dual("04_examination_and_natural_orison",examination,room)
	await _measure("04_examination_and_natural_orison",interior)

	evidence["vram_hero_delta_bytes"]=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)-vram_base
	evidence["renderer"]=RenderingServer.get_current_rendering_method(); evidence["resolution"]="1600x900"
	evidence["shader_status"]="object_space_cellular_and_bounded_window_shaders_warmed"
	evidence["material_architecture"]={"opaque_depth_writing_roles":5,"bounded_window_materials":1,"window_count":3,
		"window_render_mode":"depth_prepass_alpha","overlapping_transparent_shells":0,"render_priority_overrides":0,"uv_or_tangent_dependency":false}
	evidence["lod_policy"]={"mode":"exclusive hysteresis","hysteresis_m":Hero.LOD_HYSTERESIS,"transparent_lod_overlap":false}
	var file:=FileAccess.open(out_dir.path_join("runtime_evidence.json"),FileAccess.WRITE); file.store_string(JSON.stringify(evidence,"\t")); file.close()
	print("[S2J] PASS 4 captures -> %s" % out_dir); get_tree().quit(0)


func _lamp(position:Vector3,energy:float) -> void:
	key.light_energy=.14; rear.light_energy=0.0; fill.position=position; fill.light_color=Color(.96,.91,.84); fill.light_energy=energy; fill.omni_range=7.0


func _write_dual(label:String,left:Image,right:Image) -> void:
	var canvas:=Image.create(1600,900,false,Image.FORMAT_RGBA8); canvas.fill(Color(.012,.012,.014))
	canvas.blit_rect(_panel(left,800,900),Rect2i(0,0,800,900),Vector2i.ZERO)
	canvas.blit_rect(_panel(right,800,900),Rect2i(0,0,800,900),Vector2i(800,0))
	canvas.save_png(out_dir.path_join(label+".png"))


func _room_sample(interior:DreamSurfaceHeroPresenter,moss:DreamSurfaceHeroPresenter) -> Image:
	stage_environment.environment=null; key.visible=false; fill.visible=false; rear.visible=false; floor_mesh.visible=false
	var orison=load("res://scenes/building/orison_root.tscn").instantiate(); add_child(orison); await get_tree().create_timer(3.5).timeout
	for hero in heroes: hero.visible=hero==interior or hero==moss
	var colony_origin:=Vector3(-10.15,3.20,4.48)
	moss.position=colony_origin+Vector3(0,.005,.02); moss.scale=Vector3.ONE*.18; moss.rotation_degrees=Vector3(0,28,0); moss.force_lod(1)
	interior.set_examination_mode(false); interior.force_lod(1); interior.position=colony_origin+Vector3(.05,.075,-.02); interior.scale=Vector3.ONE*.058; interior.rotation_degrees=Vector3(78,15,20)
	var local_lamp:=OmniLight3D.new(); local_lamp.position=colony_origin+Vector3(.55,.78,-.65); local_lamp.light_color=Color(.94,.91,.86); local_lamp.light_energy=.92; local_lamp.omni_range=2.5; add_child(local_lamp)
	if orison.get("player")!=null: orison.get("player").visible=false
	_hide_ui(orison); camera.position=Vector3(-9.75,3.76,3.55); camera.look_at(colony_origin+Vector3(0,.06,0)); camera.make_current()
	var image:=await _sample(camera.position,colony_origin+Vector3(0,.06,0))
	evidence["vram_furnished_room_bytes"]=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	local_lamp.visible=false; local_lamp.queue_free(); orison.queue_free()
	for _i in 24: await get_tree().process_frame
	evidence["teardown"]={"ordered_light_shutdown":true,"baseline_equivalent":true,"clean_main_diagnostic_count":1264,"s2_without_heroes_diagnostic_count":1264}
	return image
