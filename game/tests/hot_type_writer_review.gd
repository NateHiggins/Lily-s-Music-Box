extends Node3D
## INERT isolated imported-asset diagnostic, not campaign qualification.
var failures: Array[String]=[]
var observations: Array=[]
var checks := 0
var model: Node3D
var writer: Node3D
var camera: Camera3D
var directory := ""

func check(ok: bool,label: String) -> void:
	checks+=1
	print("HOT TYPE REVIEW: ",label," = ",ok)
	if not ok:failures.append(label)

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"captured "+label)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	check(DisplayServer.get_name()!="headless","real rendering backend")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	model=load("res://assets/props/service_radiophone_v2.glb").instantiate();add_child(model)
	preload("res://scripts/device/service_radiophone_stock.gd").apply(model)
	writer=load("res://scripts/device/hot_type_writer.gd").new();add_child(writer)
	check(writer.bind_model(model),"imported candidate binds existing hot controller")
	writer.set_process(false)
	var environment:=WorldEnvironment.new();var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("242426")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.6
	environment.environment=settings;add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-25,-20,0);light.light_energy=1.4;add_child(light)
	camera=Camera3D.new();camera.position=Vector3(.20,.13,.48);camera.look_at_from_position(camera.position,Vector3(0,.005,.03));camera.near=.005;camera.fov=35.;add_child(camera);camera.make_current()
	await shot("01_imported_front")
	var maps: Array=[]
	var metrics: Node=preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for part in model.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(part.mesh,true)
		for surface in part.mesh.get_surface_count():
			var material: Material=part.get_active_material(surface)
			if material is StandardMaterial3D:
				for texture in [material.albedo_texture,material.normal_texture,material.roughness_texture,material.metallic_texture]:
					if texture==null or texture.resource_path in maps:continue
					maps.append(texture.resource_path)
					check(texture.get_image().has_mipmaps(),"loaded map has mips: "+texture.resource_path)
	check(writer.PLATE.get_image().has_mipmaps(),"loaded reversed relief atlas has mips")
	check(maps.size()>=12,"physical map coverage is nonempty")
	for failure: String in metrics.failures:check(false,failure)
	check(metrics.failures.is_empty(),"all 29 imported surfaces retain metric UV and tangent derivatives")
	metrics.free()
	var frame:=model.find_child("Type_hammer",true,false) as Node3D
	var home:=frame.position
	camera.look_at_from_position(Vector3(.045,-.010,.25),Vector3(-.059,-.03,.065));camera.fov=24.
	for glyph in ["A","Q","6"]:
		writer.stop();writer.strike(glyph);writer.set_process(false)
		writer._process(.010)
		var travel: float=home.z-frame.position.z
		var expected: int=floori(float(writer.CHARS.find(glyph))/16.)-1
		check(writer._bank==expected,"character selects correct bank: "+glyph)
		check(travel>.0015 and travel<=.00156,"impression seats at 1.55mm within character interval: "+glyph)
		for mesh in writer._rows:
			var lower: float=mesh.get_blend_shape_value(mesh.find_blend_shape_by_name("LowerSeat"))
			var upper: float=mesh.get_blend_shape_value(mesh.find_blend_shape_by_name("UpperSeat"))
			check((lower>0. if expected==-1 else lower==0.) and (upper>0. if expected==1 else upper==0.),"only selected bank seats: "+glyph+"/"+mesh.name)
		observations.append({"character":glyph,"bank":expected,"travel_m":travel})
		await shot("02_bank_"+glyph)
		writer._process(.3)
		check(not writer.is_processing() and frame.position.is_equal_approx(home),"cooled controller sleeps at rest: "+glyph)
	writer.strike("B");writer.stop()
	check(not writer._puff.emitting and not writer._sound.playing and not writer.is_processing(),"stop clears smoke sound and processing")
	check(frame.position.is_equal_approx(home),"stop restores impression frame")
	await shot("03_rest")
	FileAccess.open(directory.path_join("review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Isolated imported candidate and actual rendering; no campaign or performance qualification","checks":checks,"failures":failures,"observations":observations,"physical_maps":maps},"\t"))
	print("HOT TYPE REVIEW: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks)
	get_tree().quit(0 if failures.is_empty() else 1)
