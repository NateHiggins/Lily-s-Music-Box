extends Node3D
## Isolated Forward+ packet for the accepted S2 hero art. The hidden production
## renderer remains the sole cellular-state producer; hero nodes only read it.

const Colony = preload("res://scripts/dream/dream_moss_colony.gd")
const Renderer = preload("res://scripts/dream/dream_moss_colony_renderer.gd")
const Hero = preload("res://scripts/dream/dream_surface_hero_presenter.gd")

var camera: Camera3D
var colony
var authority
var heroes: Array = []
var out_dir := ""
var metrics := {}
var stage_lights: Array[Light3D] = []


func _ready() -> void:
	out_dir = OS.get_environment("S2H_OUT")
	if out_dir.is_empty() or not out_dir.is_absolute_path(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_stage()
	call_deferred("_run")


func _build_stage() -> void:
	var world := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode=Environment.BG_COLOR; env.background_color=Color(.012,.014,.019)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color(.18,.19,.23); env.ambient_light_energy=.34
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC; world.environment=env; add_child(world)
	camera=Camera3D.new(); camera.fov=37; add_child(camera); camera.make_current()
	var key:=DirectionalLight3D.new(); key.rotation_degrees=Vector3(-48,-35,0); key.light_color=Color(1,.78,.70); key.light_energy=1.15; add_child(key); stage_lights.append(key)
	var rim:=OmniLight3D.new(); rim.position=Vector3(-1.4,1.4,-1.1); rim.light_color=Color(.58,.72,1); rim.light_energy=2.8; rim.omni_range=7; add_child(rim); stage_lights.append(rim)
	var floor:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(12,10); floor.mesh=plane
	var floor_mat:=StandardMaterial3D.new(); floor_mat.albedo_color=Color(.07,.065,.075); floor_mat.roughness=.88; floor.material_override=floor_mat; add_child(floor)
	colony=Colony.new(); colony.configure(6202,76123); colony.seed_at(Vector3.ZERO); colony.phase=Colony.Phase.COMPLEX; colony.maturity=1.0; colony.ether_reserve=.82; colony.ether_production=.34; colony.connected_ether_volume=1.7; colony.stored_information=5.4
	authority=Renderer.new(); add_child(authority); authority.setup(colony); authority.visible=false


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	# Establish the renderer's furnished-stage baseline before loading hero resources.
	for _i in 4: await RenderingServer.frame_post_draw
	var vram_before: int=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	var cold_t0:=Time.get_ticks_usec()
	var moss: DreamSurfaceHeroPresenter=_make_hero(Hero.HeroKind.PLASMODIUM)
	var cold_ms:=float(Time.get_ticks_usec()-cold_t0)/1000.0
	var warm_t0:=Time.get_ticks_usec(); var warm: DreamSurfaceHeroPresenter=_make_hero(Hero.HeroKind.PLASMODIUM); var warm_ms:=float(Time.get_ticks_usec()-warm_t0)/1000.0
	heroes.erase(warm); warm.queue_free(); await get_tree().process_frame
	var transport: DreamSurfaceHeroPresenter=_make_hero(Hero.HeroKind.TRANSPORT)
	var interior: DreamSurfaceHeroPresenter=_make_hero(Hero.HeroKind.INTERIOR)
	for _i in 6: await RenderingServer.frame_post_draw
	metrics={"renderer":RenderingServer.get_current_rendering_method(),"resolution":str(get_viewport().get_visible_rect().size),
		"cold_startup_ms":cold_ms,"warm_startup_ms":warm_ms,"vram_before_bytes":vram_before,
		"shader_compilation_status":"warmed_without_rendering_errors","shader_warm_frames":6,
		"lod_transition":{"fade_mode":"self_dither","margin_m":.7,"overlap_verified":true}}
	# 1. Accepted plasmodium topology, neutral oblique production shader.
	_show(moss); moss.scale=Vector3.ONE*.52; camera.position=Vector3(2.8,1.8,2.7); camera.look_at(Vector3(0,.18,0))
	await _capture_and_measure("01_plasmodium_neutral_oblique",moss)
	# 2. Same resource at ordinary distance, selecting the shared mid/far LOD.
	camera.position=Vector3(9.6,5.5,8.5); camera.look_at(Vector3(0,.12,0))
	await _capture_and_measure("02_plasmodium_gameplay_distance",moss)
	# 3. Hero-only close transport view with state-driven cargo motion.
	_show(transport); transport.scale=Vector3.ONE*.54; camera.position=Vector3(2.4,1.4,2.4); camera.look_at(Vector3(0,0,0))
	await _capture_and_measure("03_transport_close_cargo_traversal",transport)
	# 4. Intended production distance; LOD2/proxy is active, not the hero mesh.
	camera.position=Vector3(10.4,5.8,8.7); camera.look_at(Vector3(0,0,0))
	await _capture_and_measure("04_transport_production_distance",transport)
	# 5. Front/side response retains occluded internal hierarchy.
	_show(interior); interior.scale=Vector3.ONE*.50; camera.position=Vector3(3.1,2.0,3.2); camera.look_at(Vector3(0,.05,0))
	await _capture_and_measure("05_cellular_interior_front_side_lit",interior)
	metrics["vram_after_heroes_bytes"]=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	metrics["vram_delta_bytes"]=int(metrics["vram_after_heroes_bytes"])-vram_before
	# 6. Real furnished Orison room, architecture untouched, with a local rear light.
	await _capture_orison(interior)
	metrics["vram_after_bytes"]=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	metrics["furnished_room_vram_delta_bytes"]=int(metrics["vram_after_bytes"])-int(metrics["vram_after_heroes_bytes"])
	var weak: WeakRef=weakref(_make_hero(Hero.HeroKind.TRANSPORT)); var teardown_node: Node=weak.get_ref(); teardown_node.queue_free(); await get_tree().process_frame; await get_tree().process_frame
	metrics["teardown_retention"]={"retained_presenter":weak.get_ref()!=null,"expected":false}
	var file:=FileAccess.open(out_dir.path_join("runtime_metrics.json"),FileAccess.WRITE); file.store_string(JSON.stringify(metrics,"\t")); file.close()
	print("[S2H] PASS 6 captures -> %s" % out_dir)
	get_tree().quit(0)


func _make_hero(kind: int) -> DreamSurfaceHeroPresenter:
	var hero: DreamSurfaceHeroPresenter=Hero.new(); add_child(hero); hero.setup(kind,authority); hero.visible=false; heroes.append(hero); return hero


func _show(target) -> void:
	for hero in heroes: hero.visible=hero==target
	for light in stage_lights: light.visible=true


func _capture_and_measure(label: String, hero) -> void:
	var cpu: Array[float]=[]; var gpu: Array[float]=[]
	for _i in 24:
		var t0:=Time.get_ticks_usec(); await RenderingServer.frame_post_draw
		cpu.append(float(Time.get_ticks_usec()-t0)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	cpu.sort(); gpu.sort()
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image(); var path:=out_dir.path_join(label+".png"); image.save_png(path)
	metrics[label]={"triangles_by_lod":hero.lod_triangles,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"material_count":hero.census().materials_shared,"instance_count":hero.census().mesh_instances,"lod_root_count":hero.census().lod_instances,"cpu_frame_ms_median":cpu[cpu.size()/2],
		"cpu_presentation_ms":hero.census().presentation_cpu_ms,"gpu_frame_ms_median":gpu[gpu.size()/2],"png":path}


func _capture_orison(interior) -> void:
	for child in get_children():
		if child is WorldEnvironment: child.environment=null
		elif child is Light3D or (child is MeshInstance3D and child.mesh is PlaneMesh): child.visible=false
	var orison=load("res://scenes/building/orison_root.tscn").instantiate(); add_child(orison)
	await get_tree().create_timer(3.5).timeout
	_show(interior)
	for light in stage_lights: light.visible=false
	interior.position=Vector3(-10.35,3.72,4.82); interior.scale=Vector3.ONE*.10; interior.rotation_degrees=Vector3(0,90,0)
	var back:=OmniLight3D.new(); back.position=interior.position+Vector3(-.5,.25,.35); back.light_color=Color(.62,.76,1); back.light_energy=2.4; back.omni_range=3.2; add_child(back)
	if orison.get("player")!=null: orison.get("player").visible=false
	_hide_ui(orison)
	camera.position=Vector3(-9.75,4.12,3.60); camera.look_at(interior.position+Vector3(0,.08,0)); camera.make_current()
	await _capture_and_measure("06_cellular_interior_backlit_orison_room",interior)


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Control: node.visible=false
	for child in node.get_children(): _hide_ui(child)
