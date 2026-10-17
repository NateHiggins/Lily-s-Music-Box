extends Node3D
## INERT renderer calibration fixtures, not V2 art or room acceptance.
## Can a probe exclude the transient carried-light layer without changing
## that light's direct camera contribution? Measure, do not assume.
const TRANSIENT := 1<<18
var failures: Array[String]=[]
var checks := 0
var out := ""
var sphere_region := Rect2i()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func _ready() -> void:_run.call_deferred()
func _run() -> void:
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.025,.025,.025)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.12,.12,.12)
	environment.environment.ambient_light_energy=.25
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var plaster := StandardMaterial3D.new();plaster.albedo_color=Color(.7,.7,.7);plaster.roughness=.8
	for spec: Array in [[Vector3(6,.1,6),Vector3(0,-.05,0)],[Vector3(6,.1,6),Vector3(0,3.05,0)],
		[Vector3(.1,3,6),Vector3(-3.05,1.5,0)],[Vector3(.1,3,6),Vector3(3.05,1.5,0)],
		[Vector3(6,3,.1),Vector3(0,1.5,-3.05)],[Vector3(6,3,.1),Vector3(0,1.5,3.05)]]:
		var draw := MeshInstance3D.new();var mesh := BoxMesh.new();mesh.size=spec[0]
		draw.mesh=mesh;draw.material_override=plaster;draw.position=spec[1];add_child(draw)
	var chrome := StandardMaterial3D.new();chrome.albedo_color=Color(.8,.8,.8);chrome.metallic=1.;chrome.roughness=.2
	var sample := MeshInstance3D.new();var sphere := SphereMesh.new();sphere.radius=.48;sphere.height=.96;sphere.radial_segments=64;sphere.rings=32
	sample.mesh=sphere;sample.material_override=chrome;sample.position=Vector3(0,1,0);add_child(sample)
	var fixed := OmniLight3D.new();fixed.position=Vector3(-1,2,1);fixed.omni_range=7;fixed.light_energy=1.;add_child(fixed)
	var carried := OmniLight3D.new();carried.position=Vector3(1.3,1.6,-.6);carried.omni_range=7;carried.light_energy=2.;carried.light_color=Color(1,.02,.02);add_child(carried)
	var camera := Camera3D.new();camera.position=Vector3(0,1.4,2.5);camera.fov=55;add_child(camera);camera.look_at(sample.position);camera.current=true
	var projected := Rect2(camera.unproject_position(sample.to_global(sample.mesh.get_aabb().get_endpoint(0))),Vector2.ZERO)
	for index in range(8):projected=projected.expand(camera.unproject_position(sample.to_global(sample.mesh.get_aabb().get_endpoint(index))))
	sphere_region=Rect2i(Vector2i(projected.position.floor()),Vector2i(projected.size.ceil()))
	var probe := ReflectionProbe.new();probe.size=Vector3(6,3,6);probe.position=Vector3(0,1.5,0);probe.origin_offset=Vector3(0,0,1.2)
	probe.box_projection=true;probe.interior=true;probe.enable_shadows=true
	probe.cull_mask=0xFFFFF & ~TRANSIENT;probe.intensity=0.;add_child(probe)
	carried.layers=TRANSIENT
	var direct_excluded := await _capture("direct_transient_layer")
	carried.layers=1
	var direct_default := await _capture("direct_default_layer")
	var direct_delta := _difference(direct_excluded,direct_default)
	check(direct_delta<.002,"changing light visibility layer preserves direct camera lighting")
	probe.intensity=1.;carried.layers=TRANSIENT;probe.position.x+=.0001
	var excluded := await _capture("probe_excludes_transient")
	carried.layers=1;probe.position.x-=.0001
	var included := await _capture("probe_includes_transient")
	var capture_delta := _difference(excluded,included)
	var reflected_red_increase := _reflected_red_difference(excluded,included)
	check(reflected_red_increase>.02,"probe cull mask excludes red transient photons from the projected reflection target")
	var result := {"evidence_class":"INERT","checks":checks,"failures":failures,"direct_mean_rgb_difference":direct_delta,"capture_mean_rgb_difference":capture_delta,
		"projected_sphere_region":str(sphere_region),"reflected_red_minus_green_increase":reflected_red_increase,
		"scope":"Synthetic renderer light/probe layer calibration only. No V2 art, physical interaction, gameplay or runtime contract."}
	FileAccess.open(out.path_join("reflection_capture_bench.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("REFLECTION CAPTURE BENCH: ","PASS" if failures.is_empty() else "FAIL","; ",result)
	probe.free()
	# Retire this test's World3D while the rendering device is still alive.
	# Merely removing a probe leaves its shared world atlas allocated.
	for child in get_children():child.free()
	get_viewport().world_3d=World3D.new()
	for frame in range(3):await RenderingServer.frame_post_draw
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture(label: String) -> Image:
	for frame in range(24):await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	check(picture.save_png(out.path_join(label+".png"))==OK,label+" captured")
	return picture

func _difference(a: Image,b: Image) -> float:
	var sum := 0.;var count := 0
	for y in range(0,a.get_height(),4):
		for x in range(0,a.get_width(),4):
			var p := a.get_pixel(x,y);var q := b.get_pixel(x,y)
			sum+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b);count+=3
	return sum/maxi(count,1)

func _reflected_red_difference(a: Image,b: Image) -> float:
	var sum := 0.;var count := 0
	var region := sphere_region.intersection(Rect2i(Vector2i.ZERO,a.get_size()))
	for y in range(region.position.y,region.end.y,2):
		for x in range(region.position.x,region.end.x,2):
			var p := a.get_pixel(x,y);var q := b.get_pixel(x,y)
			sum+=(q.r-q.g)-(p.r-p.g);count+=1
	return sum/maxi(count,1)
