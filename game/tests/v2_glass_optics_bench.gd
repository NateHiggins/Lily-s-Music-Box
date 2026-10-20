extends Node3D
## Optical diagnostic only. Swatches are not world geometry or runtime proof.
const Glass := preload("res://scripts/building/orison_v2_expressive_glass.gd")
const Factory := preload("res://scripts/building/orison_v2_architectural_materials.gd")
const Nook := preload("res://scripts/building/orison_v2_reading_nook.gd")
var panels: Array[MeshInstance3D]=[]
var directory: String
var failures:=0
var measurements: Dictionary={}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(.025,.03,.04)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_energy=.35
	var world:=WorldEnvironment.new();world.environment=env;add_child(world)
	var player:=PlayerController.new();add_child(player);player.set_physics_process(false)
	player.position=Vector3(0,0,2.8);player.camera.global_position=Vector3(0,1.35,2.8)
	player.camera.look_at(Vector3(0,1.35,0));player.camera.make_current();player.set_lamp_enabled(true)
	var air:=preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new();add_child(air)
	verify(air.setup(player,env),"production voxel light initializes")
	var materials: Array[Material]=[Factory.new().material_for("Glazing","public")]
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Nook.PATH))
	materials.append(Nook._source_material(data.local_materials.glassish))
	for key: String in Glass.STYLES: materials.append(Glass.make(key))
	verify(RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_rendering_device()!=null,"actual Forward+ device is available")
	for material: Material in materials:
		var textures: Array=[]
		if material is StandardMaterial3D: textures=[material.normal_texture,material.roughness_texture]
		else: textures=[material.get_shader_parameter("normal_tex"),material.get_shader_parameter("rough_tex")]
		for texture: Texture2D in textures:
			verify(texture!=null,"glass map is loaded")
			if texture==null: continue
			var pixels:=texture.get_image()
			verify(pixels!=null and pixels.has_mipmaps() and pixels.get_mipmap_count()==int(floor(log(float(maxi(texture.get_width(),texture.get_height())))/log(2.))),"glass map has a full loaded mip chain")
	var names: Array[String]=["architectural","nook","drawn","reeded","cut","frosted"]
	for index in materials.size():
		var x: float=(index%3-1)*.78;var y: float=1.35+(.5-float(index/3))*.78
		var draw:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.7,.7)
		draw.mesh=quad;draw.material_override=materials[index];draw.position=Vector3(x,y,0)
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(draw);panels.append(draw)
		if materials[index] is StandardMaterial3D:
			var material: StandardMaterial3D=materials[index]
			material.uv1_scale=Vector3.ONE*4.
			measurements[names[index]]={"refraction":material.refraction_enabled,"normal":material.normal_enabled,"normal_strength":material.normal_scale}
		else:
			measurements[names[index]]={"shader":materials[index].shader.resource_path}
		for stripe in 19:
			var bar:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.037,.7,.03)
			bar.mesh=box;bar.position=Vector3(x-.35+stripe*.038,y,-.22)
			var paint:=StandardMaterial3D.new();paint.albedo_color=Color(.78,.67,.43) if stripe%2==0 else Color(.025,.055,.10)
			bar.material_override=paint;add_child(bar)
		var label:=Label3D.new();label.text=names[index];label.font_size=36;label.pixel_size=.001
		label.position=Vector3(x,y-.40,.05);add_child(label)
	for draw: MeshInstance3D in panels: draw.hide()
	var bare:=await capture("bare")
	for draw: MeshInstance3D in panels: draw.show()
	var mapped:=await capture("mapped")
	for material: Material in materials:
		if material is StandardMaterial3D: material.normal_enabled=false
		else: material.set_shader_parameter("normal_strength",0.)
	var flat:=await capture("flat_normals")
	for index in materials.size():
		var point:=player.camera.unproject_position(panels[index].global_position)
		var total:=0.;var count:=0;var bare_difference:=0.
		for dy in range(-42,43):
			for dx in range(-42,43):
				var px:=int(point.x)+dx;var py:=int(point.y)+dy
				if px<0 or py<0 or px>=mapped.get_width() or py>=mapped.get_height(): continue
				var value:=mapped.get_pixel(px,py);var other:=flat.get_pixel(px,py);var back:=bare.get_pixel(px,py)
				total+=absf(value.r-other.r)+absf(value.g-other.g)+absf(value.b-other.b)
				bare_difference+=absf(value.r-back.r)+absf(value.g-back.g)+absf(value.b-back.b);count+=1
		measurements[names[index]]["mapped_flat_mean_rgb_difference"]=total/maxi(count,1)/3.
		measurements[names[index]]["mapped_bare_mean_rgb_difference"]=bare_difference/maxi(count,1)/3.
	measurements["renderer"]=RenderingServer.get_current_rendering_method()
	if OS.get_environment("GLASS_REQUIRE_EFFECTS")=="1":
		verify(materials[1].refraction_enabled,"actual nook source material enables refraction")
		verify(float(measurements.architectural.mapped_flat_mean_rgb_difference)>.005,"architectural authored normals visibly alter rendered scenery")
		verify(float(measurements.cut.mapped_flat_mean_rgb_difference)>.01,"cut finish retains visible optical relief")
		verify(float(measurements.reeded.mapped_flat_mean_rgb_difference)>.01,"reeded finish retains visible optical relief")
		verify(float(measurements.frosted.mapped_bare_mean_rgb_difference)>.05,"frosted finish visibly obscures scenery")
	FileAccess.open(directory.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
	print("GLASS OPTICS DIAGNOSTIC: ",JSON.stringify(measurements))
	print("GLASS OPTICS: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	get_tree().quit(failures)

func capture(identity: String) -> Image:
	for frame in 24: await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image();image.save_png(directory.path_join(identity+".png"));return image

func verify(condition: bool, message: String) -> void:
	if not condition: failures+=1;push_error(message)
