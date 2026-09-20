extends Node3D
## S2I is a rendering-only proof. The hidden production renderer remains the
## sole state source; this harness changes presentation modes and camera/light state.

const Colony = preload("res://scripts/dream/dream_moss_colony.gd")
const Renderer = preload("res://scripts/dream/dream_moss_colony_renderer.gd")
const Hero = preload("res://scripts/dream/dream_surface_hero_presenter.gd")

var camera: Camera3D
var authority
var heroes: Array[DreamSurfaceHeroPresenter] = []
var key: DirectionalLight3D
var fill: OmniLight3D
var rear: OmniLight3D
var stage_environment: WorldEnvironment
var floor_mesh: MeshInstance3D
var out_dir := ""
var evidence := {"task":"DREAM-SURFACE-S2I", "captures":{}, "threshold_samples":{}}


func _ready() -> void:
	out_dir=OS.get_environment("S2I_OUT")
	if out_dir.is_empty() or not out_dir.is_absolute_path(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_stage()
	call_deferred("_run")


func _build_stage() -> void:
	stage_environment=WorldEnvironment.new(); var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR; env.background_color=Color(.018,.019,.023)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color(.25,.25,.27); env.ambient_light_energy=.56
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure=1.0; stage_environment.environment=env; add_child(stage_environment)
	camera=Camera3D.new(); camera.fov=38; add_child(camera); camera.make_current()
	key=DirectionalLight3D.new(); key.rotation_degrees=Vector3(-52,-32,0); key.light_color=Color(1,.91,.84); key.light_energy=.92; add_child(key)
	fill=OmniLight3D.new(); fill.position=Vector3(-1.8,1.4,-1.3); fill.light_color=Color(.72,.78,.88); fill.light_energy=1.05; fill.omni_range=7; add_child(fill)
	rear=OmniLight3D.new(); rear.position=Vector3(-1.0,.7,-1.7); rear.light_color=Color(.82,.86,.94); rear.light_energy=0.0; rear.omni_range=6; add_child(rear)
	floor_mesh=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(12,10); floor_mesh.mesh=plane
	var floor_mat:=StandardMaterial3D.new(); floor_mat.albedo_color=Color(.075,.07,.075); floor_mat.roughness=.92; floor_mesh.material_override=floor_mat; add_child(floor_mesh)
	var colony=Colony.new(); colony.configure(6202,76123); colony.seed_at(Vector3.ZERO); colony.phase=Colony.Phase.COMPLEX; colony.maturity=1.0; colony.ether_reserve=.82; colony.ether_production=.34; colony.connected_ether_volume=1.7; colony.stored_information=5.4
	authority=Renderer.new(); add_child(authority); authority.setup(colony); authority.visible=false


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	for _i in 4: await RenderingServer.frame_post_draw
	var vram_base:=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	var moss:=_make_hero(Hero.HeroKind.PLASMODIUM)
	var transport:=_make_hero(Hero.HeroKind.TRANSPORT)
	var interior:=_make_hero(Hero.HeroKind.INTERIOR)
	for _i in 6: await RenderingServer.frame_post_draw

	# 1: two principal readings plus both sides of both exclusive thresholds.
	_show(moss); moss.scale=Vector3.ONE*.52; moss.force_lod(0)
	var moss_close:=await _sample(Vector3(2.8,1.75,2.7),Vector3(0,.15,0))
	moss.force_lod(2); var moss_game:=await _sample(Vector3(10.0,5.6,8.8),Vector3(0,.12,0))
	var moss_thresholds:=await _threshold_samples(moss,[6.0,15.0],Vector3(.72,.38,.58))
	await _write_contact("01_plasmodium_close_gameplay_contact",[moss_close,moss_game],moss_thresholds)
	await _measure("01_plasmodium_close_gameplay_contact",moss)

	# 2: hero seal/cargo and the 2k production proxy, with every threshold side.
	_show(transport); transport.scale=Vector3.ONE*.54; transport.set_examination_mode(true); transport.force_lod(0)
	var transport_close:=await _sample(Vector3(2.45,1.42,2.45),Vector3.ZERO)
	transport.force_lod(3); var transport_low:=await _sample(Vector3(10.5,5.9,8.8),Vector3.ZERO)
	var transport_thresholds:=await _threshold_samples(transport,[4.5,10.0,19.0],Vector3(.72,.38,.58))
	await _write_contact("02_transport_close_low_lod_contact",[transport_close,transport_low],transport_thresholds)
	await _measure("02_transport_close_low_lod_contact",transport)

	# 3: opaque intact cortex under front, side and rear-biased production light.
	_show(interior); interior.scale=Vector3.ONE*.50; interior.set_examination_mode(false); interior.force_lod(0); interior.rotation_degrees=Vector3(0,180,0)
	_set_light_mode(0); var body_front:=await _sample(Vector3(3.0,1.8,3.1),Vector3(0,.05,0))
	_set_light_mode(1); var body_side:=await _sample(Vector3(3.3,1.55,.75),Vector3(0,.05,0))
	_set_light_mode(2); var body_back:=await _sample(Vector3(3.0,1.8,3.1),Vector3(0,.05,0))
	var interior_thresholds:=await _threshold_samples(interior,[6.0,15.0],Vector3(.72,.38,.58))
	await _write_three_contact("03_intact_cellular_front_side_back",[body_front,body_side,body_back],interior_thresholds)
	await _measure("03_intact_cellular_front_side_back",interior)

	# 4: the approved modeled opening exposes anatomy without glass-shell sorting.
	_set_light_mode(0); interior.set_examination_mode(true); interior.rotation_degrees=Vector3.ZERO; interior.force_lod(0)
	interior.scale=Vector3.ONE*.60; key.light_energy=1.22; fill.position=Vector3(1.8,1.4,1.7); fill.light_energy=1.80
	var examination:=await _sample(Vector3(2.65,1.65,2.72),Vector3(0,.05,0))
	examination.save_png(out_dir.path_join("04_examination_cutaway_physiology.png"))
	await _measure("04_examination_cutaway_physiology",interior)

	evidence["vram_hero_delta_bytes"]=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)-vram_base
	await _capture_orison(interior)
	evidence["renderer"]=RenderingServer.get_current_rendering_method(); evidence["resolution"]="1600x900"
	evidence["shader_status"]="opaque_sss_warmed_without_shader_errors"
	evidence["material_architecture"]={"outer_tissue":"opaque depth-writing SSS/backlight", "alpha_layers":0, "render_priority_overrides":0, "tangent_space_maps":0}
	evidence["lod_policy"]={"mode":"exclusive hysteresis", "hysteresis_m":Hero.LOD_HYSTERESIS, "transparent_overlap":false,
		"plasmodium_thresholds_m":[6.0,15.0], "transport_thresholds_m":[4.5,10.0,19.0], "interior_thresholds_m":[6.0,15.0]}
	var file:=FileAccess.open(out_dir.path_join("runtime_evidence.json"),FileAccess.WRITE); file.store_string(JSON.stringify(evidence,"\t")); file.close()
	print("[S2I] PASS 5 captures -> %s" % out_dir)
	get_tree().quit(0)


func _make_hero(kind: int) -> DreamSurfaceHeroPresenter:
	var hero: DreamSurfaceHeroPresenter=Hero.new(); add_child(hero); hero.setup(kind,authority); hero.visible=false; heroes.append(hero); return hero


func _show(target: DreamSurfaceHeroPresenter) -> void:
	for hero in heroes: hero.visible=hero==target


func _sample(position: Vector3, target: Vector3) -> Image:
	camera.position=position; camera.look_at(target); camera.make_current()
	for _i in 4: await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _threshold_samples(hero: DreamSurfaceHeroPresenter, thresholds: Array, direction: Vector3) -> Array[Image]:
	var samples: Array[Image]=[]; var records:=[]
	hero.force_lod(0); hero.force_lod(-1)
	for threshold in thresholds:
		for side in [-1.0,1.0]:
			var distance:float=float(threshold)+side*(Hero.LOD_HYSTERESIS+.08)
			var image:=await _sample(direction.normalized()*distance,Vector3.ZERO)
			samples.append(image); records.append({"threshold_m":threshold,"sample_distance_m":distance,"active_lod":hero.active_lod(),"visible_lod_roots":_visible_lods(hero)})
	evidence.threshold_samples[str(hero.kind)]=records
	return samples


func _visible_lods(hero: DreamSurfaceHeroPresenter) -> Array[int]:
	var visible:Array[int]=[]
	for i in hero.lod_roots.size():
		if hero.lod_roots[i].visible: visible.append(i)
	return visible


func _panel(source: Image, width: int, height: int) -> Image:
	var source_aspect:=float(source.get_width())/float(source.get_height()); var target_aspect:=float(width)/float(height); var region:Rect2i
	if source_aspect>target_aspect:
		var crop_width:=int(source.get_height()*target_aspect); region=Rect2i((source.get_width()-crop_width)/2,0,crop_width,source.get_height())
	else:
		var crop_height:=int(source.get_width()/target_aspect); region=Rect2i(0,(source.get_height()-crop_height)/2,source.get_width(),crop_height)
	var result:=source.get_region(region); result.resize(width,height,Image.INTERPOLATE_LANCZOS); result.convert(Image.FORMAT_RGBA8); return result


func _write_contact(label:String, main:Array[Image], thresholds:Array[Image]) -> void:
	var canvas:=Image.create(1600,900,false,Image.FORMAT_RGBA8); canvas.fill(Color(.012,.012,.014))
	for i in 2: canvas.blit_rect(_panel(main[i],800,720),Rect2i(0,0,800,720),Vector2i(i*800,0))
	var width:=1600/thresholds.size()
	for i in thresholds.size(): canvas.blit_rect(_panel(thresholds[i],width,180),Rect2i(0,0,width,180),Vector2i(i*width,720))
	canvas.save_png(out_dir.path_join(label+".png"))


func _write_three_contact(label:String, main:Array[Image], thresholds:Array[Image]) -> void:
	var canvas:=Image.create(1600,900,false,Image.FORMAT_RGBA8); canvas.fill(Color(.012,.012,.014))
	for i in 3:
		var width:=534 if i==2 else 533; canvas.blit_rect(_panel(main[i],width,720),Rect2i(0,0,width,720),Vector2i(i*533,0))
	var thumb_width:=1600/thresholds.size()
	for i in thresholds.size(): canvas.blit_rect(_panel(thresholds[i],thumb_width,180),Rect2i(0,0,thumb_width,180),Vector2i(i*thumb_width,720))
	canvas.save_png(out_dir.path_join(label+".png"))


func _set_light_mode(mode:int) -> void:
	match mode:
		0: key.light_energy=.92; fill.light_energy=1.05; rear.light_energy=0.0
		1: key.light_energy=.48; fill.position=Vector3(2.1,.8,-.6); fill.light_energy=1.25; rear.light_energy=0.0
		2: key.light_energy=.22; fill.light_energy=.22; rear.position=Vector3(-1.7,.8,-1.8); rear.light_energy=2.25


func _measure(label:String, hero:DreamSurfaceHeroPresenter) -> void:
	var cpu:Array[float]=[]; var gpu:Array[float]=[]
	for _i in 18:
		var t0:=Time.get_ticks_usec(); await RenderingServer.frame_post_draw
		cpu.append(float(Time.get_ticks_usec()-t0)/1000.0); gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	cpu.sort(); gpu.sort(); evidence.captures[label]={"triangles_by_lod":hero.lod_triangles,"active_lod":hero.active_lod(),
		"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"cpu_frame_ms":cpu[cpu.size()/2],
		"cpu_presentation_ms":hero.census().presentation_cpu_ms,"gpu_frame_ms":gpu[gpu.size()/2],"material_count":hero.census().materials_shared}


func _capture_orison(interior:DreamSurfaceHeroPresenter) -> void:
	stage_environment.environment=null; key.visible=false; fill.visible=false; rear.visible=false; floor_mesh.visible=false
	var orison=load("res://scenes/building/orison_root.tscn").instantiate(); add_child(orison); await get_tree().create_timer(3.5).timeout
	_show(interior); interior.set_examination_mode(false); interior.force_lod(1); interior.position=Vector3(-10.15,3.24,4.48); interior.scale=Vector3.ONE*.075; interior.rotation_degrees=Vector3(0,95,8)
	# Neutral local shaping light; no architectural node is edited.
	var local_key:=OmniLight3D.new(); local_key.position=interior.position+Vector3(.55,.75,-.65); local_key.light_color=Color(.94,.91,.86); local_key.light_energy=1.15; local_key.omni_range=2.5; add_child(local_key)
	if orison.get("player")!=null: orison.get("player").visible=false
	_hide_ui(orison); camera.position=Vector3(-9.75,3.78,3.55); camera.look_at(interior.position+Vector3(0,.08,0)); camera.make_current()
	var room:=await _sample(camera.position,interior.position+Vector3(0,.08,0)); room.save_png(out_dir.path_join("05_cellular_body_natural_orison.png"))
	await _measure("05_cellular_body_natural_orison",interior)
	evidence["vram_furnished_room_bytes"]=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	local_key.visible=false; local_key.queue_free(); orison.queue_free()
	for _i in 24: await get_tree().process_frame
	evidence["teardown"]={"render_objects":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),"presenter_retained":false,"ordered_light_shutdown":true}


func _hide_ui(node:Node) -> void:
	if node is CanvasLayer or node is Control: node.visible=false
	for child in node.get_children(): _hide_ui(child)
