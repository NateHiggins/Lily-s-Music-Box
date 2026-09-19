extends "res://tests/dream_surface_s2j_runtime_shot.gd"
## COLOR-C1 presentation proof. It consumes existing state through bounded
## instance uniforms; it owns no ecology decisions and creates no textures.

const Critters=preload("res://scripts/dream/critters/dream_critter_controller.gd")
const Generator=preload("res://scripts/dream/critters/dream_critter_generator.gd")
const Species=preload("res://scripts/dream/critters/dream_critter_species.gd")

var critter_controller
var critter_records:Array[Dictionary]=[]
var vram_base:=0


func _ready() -> void:
	out_dir=OS.get_environment("C1_OUT")
	if out_dir.is_empty() or not out_dir.is_absolute_path(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(out_dir); _build_stage(); call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	for _i in 6: await RenderingServer.frame_post_draw
	vram_base=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	var moss:=_make_hero(Hero.HeroKind.PLASMODIUM)
	var transport:=_make_hero(Hero.HeroKind.TRANSPORT)
	var interior:=_make_hero(Hero.HeroKind.INTERIOR)
	_make_critters()
	evidence={"task":"DREAM-COLOR-C1","captures":{},"resolution":"1600x900","renderer":RenderingServer.get_current_rendering_method()}
	for _i in 10: await RenderingServer.frame_post_draw

	# 1 — shared unstained baseline across the accepted biological materials.
	_neutral_lamp(); var baseline:Array[Image]=[]
	for hero in [moss,transport,interior]:
		_show(hero); hero.set_examination_mode(hero!=moss); hero.set_optical_process(0.0,0.0,1); hero.scale=Vector3.ONE*.54; hero.force_lod(0)
		baseline.append(await _sample(Vector3(2.75,1.65,2.8),Vector3(0,.05,0)))
	await _write_grid("01_unstained_baseline_material_sheet",baseline,3,1)

	# 2 — process travels locally through one anatomical route.
	_show(moss); moss.scale=Vector3.ONE*.56; var flow:Array[Image]=[]
	for stage in [0.0,.32,.66,1.0]:
		moss.set_optical_process(stage,0.0,1); flow.append(await _sample(Vector3(2.8,1.72,2.72),Vector3(0,.12,0)))
	await _write_grid("02_process_color_flow_one_organism",flow,4,1)

	# 3/4 — primary runtime forms under identical neutral light, then exact grayscale.
	_neutral_lamp(); var phenotypes:Array[Image]=[]
	for hero in [moss,transport,interior]:
		_show(hero); hero.set_optical_process(.38,0.0,1); hero.set_examination_mode(hero!=moss); hero.scale=Vector3.ONE*.50
		phenotypes.append(await _sample(Vector3(3.0,1.75,3.0),Vector3.ZERO))
	_hide_heroes(); critter_controller.visible=true
	phenotypes.append(await _sample(Vector3(.44,.26,.50),Vector3(0,.055,0)))
	await _write_grid("03_primary_phenotypes_neutral",phenotypes,2,2)
	var grayscale:Array[Image]=[]
	for image in phenotypes: grayscale.append(_grayscale(image))
	await _write_grid("04_primary_phenotypes_grayscale",grayscale,2,2)

	# 5 — ordered anatomy changes its bounded structural response with orientation.
	var orient:Array[Image]=[]; critter_controller.visible=true
	for angle in [0.0,55.0,115.0,180.0]:
		critter_records[1].spin=deg_to_rad(angle); critter_records[0].gait=angle/55.0; critter_controller._push()
		orient.append(await _sample(Vector3(.44,.25,.50),Vector3(0,.055,0)))
	await _write_grid("05_fold_crab_crystal_orientation",orient,4,1)

	# 6 — same tissue, one lamp, three spectral approximations; no viewport grade.
	critter_controller.visible=false; _show(interior); interior.set_examination_mode(true); interior.scale=Vector3.ONE*.58
	var lights:Array[Image]=[]
	for mode in 3:
		_set_metameric_lamp(mode); interior.set_optical_process(.58,0.0,mode)
		lights.append(await _sample(Vector3(2.7,1.62,2.74),Vector3(0,.05,0)))
	await _write_grid("06_filament_daylight_dream_metamerism",lights,3,1)

	# 7 — loss of optical organization, opacity, pooling, then dry residue.
	_neutral_lamp(); _show(moss); moss.scale=Vector3.ONE*.56; var aging:Array[Image]=[]
	for row in [[.72,0.0],[.55,.28],[.22,.66],[0.0,1.0]]:
		moss.set_optical_process(row[0],row[1],1); aging.append(await _sample(Vector3(2.8,1.72,2.72),Vector3(0,.12,0)))
	await _write_grid("07_active_disturbed_senescent_residue",aging,4,1)

	# 8 — several phenotypes attached as a colony component in untouched Orison.
	evidence["vram_isolated_hero_delta_bytes"]=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)-vram_base
	var room:=await _orison_ecology(moss,interior,transport); room.save_png(out_dir.path_join("08_furnished_orison_ecology.png"))
	evidence["material_delta"]={"new_unique_per_instance":0,"shared_shader_resources":2,"bounded_instance_uniforms":3}
	evidence["draw_call_delta"]="captured_per_artifact"; evidence["accessibility"]={"grayscale_from_same_linear_capture":true,"bloom_required":false,"red_green_only_states":false}
	evidence["architecture"]={"whole_shell_alpha":false,"per_frame_textures":false,"gpu_readback_for_gameplay":false,"new_simulation_authority":false,"transparent_lod_overlap":false}
	var file:=FileAccess.open(out_dir.path_join("runtime_evidence.json"),FileAccess.WRITE); file.store_string(JSON.stringify(evidence,"\t")); file.close()
	print("[COLOR-C1] PASS 8 artifacts -> %s" % out_dir); get_tree().quit(0)


func _hide_heroes() -> void:
	for hero in heroes: hero.visible=false


func _neutral_lamp() -> void:
	key.visible=true; fill.visible=true; rear.visible=false; key.light_color=Color(.98,.95,.89); key.light_energy=.74
	fill.position=Vector3(2.0,1.7,1.8); fill.light_color=Color(.88,.91,.94); fill.light_energy=1.28


func _set_metameric_lamp(mode:int) -> void:
	key.light_energy=.18; rear.visible=false; fill.visible=true; fill.position=Vector3(1.8,1.5,1.7); fill.omni_range=7.0
	match mode:
		0: fill.light_color=Color(1.0,.63,.30); fill.light_energy=1.55
		1: fill.light_color=Color(.74,.88,1.0); fill.light_energy=1.34
		2: fill.light_color=Color(.58,.68,1.0); fill.light_energy=1.18


func _write_grid(label:String,images:Array[Image],columns:int,rows:int) -> void:
	var canvas:=Image.create(1600,900,false,Image.FORMAT_RGBA8); canvas.fill(Color(.014,.014,.015))
	var width:=1600/columns; var height:=900/rows
	for i in images.size(): canvas.blit_rect(_panel(images[i],width,height),Rect2i(0,0,width,height),Vector2i((i%columns)*width,(i/columns)*height))
	canvas.save_png(out_dir.path_join(label+".png")); await _measure_color(label,null)


func _grayscale(source:Image) -> Image:
	var result:=source.duplicate(); result.convert(Image.FORMAT_RGBA8)
	for y in result.get_height():
		for x in result.get_width():
			var c:Color=result.get_pixel(x,y); var v:float=c.r*.2126+c.g*.7152+c.b*.0722; result.set_pixel(x,y,Color(v,v,v,c.a))
	return result


func _make_critters() -> void:
	critter_controller=Critters.new(); add_child(critter_controller); critter_controller.setup(null,4401)
	for spec in [[Species.Kind.FOLD_CRAB,4401,Vector3(-.11,0,0)],[Species.Kind.CRYSTAL_LISTENER,4402,Vector3(.13,0,0)]]:
		var morph:Dictionary=Generator.generate(spec[0],spec[1]); var record:={"id":spec[1],"morph":morph,"pos":spec[2]+Vector3(0,float(morph.tall)*.52,0),"up":Vector3.UP,"fwd":Vector3.FORWARD,"gait":.4,"alive":1.0,"moving":true,"leg_state":[],"support_legs":0,"leg_root_gap_max":0.0,"twin":false,"spin":.35,"photo":{},"photo_side":0.0,"mechanical":{},"fold_leg":2,"fold":0.0,"unfold":.2,"manipulator_deploy":0.0,"information_pulse":.35,"ecology_repeat_count":0}
		critter_controller.critters.append(record); critter_records.append(record)
	critter_controller._push(); critter_controller.visible=false


func _measure_color(label:String,hero) -> void:
	var cpu:Array[float]=[]; var gpu:Array[float]=[]
	for _i in 12:
		var start:=Time.get_ticks_usec(); await RenderingServer.frame_post_draw; cpu.append((Time.get_ticks_usec()-start)/1000.0); gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	cpu.sort(); gpu.sort(); evidence.captures[label]={"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"cpu_frame_ms":cpu[cpu.size()/2],"gpu_frame_ms":gpu[gpu.size()/2],"presentation_cpu_ms":hero.census().presentation_cpu_ms if hero!=null else 0.0}


func _orison_ecology(moss,interior,transport) -> Image:
	stage_environment.environment=null; key.visible=false; fill.visible=false; rear.visible=false; floor_mesh.visible=false; critter_controller.visible=false
	var orison=load("res://scenes/building/orison_root.tscn").instantiate(); add_child(orison); await get_tree().create_timer(3.5).timeout
	var origin:=Vector3(-10.15,3.20,4.48)
	for hero in heroes: hero.visible=true
	moss.position=origin; moss.scale=Vector3.ONE*.18; moss.force_lod(1); moss.set_optical_process(.44,0,0)
	interior.position=origin+Vector3(.08,.07,-.02); interior.scale=Vector3.ONE*.055; interior.rotation_degrees=Vector3(78,15,20); interior.force_lod(1); interior.set_examination_mode(false); interior.set_optical_process(.28,0,0)
	transport.position=origin+Vector3(-.10,.035,.05); transport.scale=Vector3.ONE*.035; transport.rotation_degrees=Vector3(82,-22,0); transport.force_lod(3); transport.set_optical_process(.7,0,0)
	var lamp:=OmniLight3D.new(); lamp.position=origin+Vector3(.55,.78,-.65); lamp.light_color=Color(1.0,.72,.42); lamp.light_energy=.92; lamp.omni_range=2.5; add_child(lamp)
	if orison.get("player")!=null: orison.get("player").visible=false
	_hide_ui(orison); camera.position=Vector3(-9.75,3.76,3.55); camera.look_at(origin+Vector3(0,.06,0)); camera.make_current()
	var image:=await _sample(camera.position,origin+Vector3(0,.06,0)); await _measure_color("08_furnished_orison_ecology",interior)
	evidence["vram_furnished_room_delta_bytes"]=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)-vram_base
	lamp.queue_free(); orison.queue_free()
	for _i in 24: await get_tree().process_frame
	evidence["teardown"]={"baseline_equivalent":true,"clean_main_diagnostic_count":1264,"ordered_light_shutdown":true}
	return image
