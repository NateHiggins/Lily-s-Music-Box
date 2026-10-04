extends Node3D
## Compare rendered material swatches at corresponding physical positions.
## The left swatch is StandardMaterial; the right is its layered conversion.
var failures:=0
func _ready() -> void:
	var env:=WorldEnvironment.new();var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(.12,.12,.12)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.8
	env.environment=settings;add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-20,-20,0);sun.light_energy=1.;add_child(sun)
	var camera:=Camera3D.new();camera.position=Vector3(0,.5,3.2);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.7;add_child(camera);camera.current=true
	var bitmap:=Image.create(128,128,false,Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:bitmap.set_pixel(x,y,Color(.06,.06,.06) if (int(x/16)+int(y/16))%2==0 else Color(.72,.72,.72))
	var texture:=ImageTexture.create_from_image(bitmap)
	var left:=MeshInstance3D.new();left.mesh=QuadMesh.new();left.position=Vector3(-.65,.5,0);add_child(left)
	var right:=MeshInstance3D.new();right.mesh=QuadMesh.new();right.position=Vector3(.65,.5,0);add_child(right)
	for phase in 2:
		var material:=StandardMaterial3D.new();material.albedo_texture=texture;material.roughness=1.
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
		material.uv1_scale=Vector3.ONE if phase==0 else Vector3(3.4,2.6,1.)
		material.uv1_offset=Vector3.ZERO if phase==0 else Vector3(.13,.27,0.)
		left.material_override=material
		var layered:=SurfacePass.surface_for(material,{"has_detail":false,"has_normal_tex":false,"cavity_ao":0.})
		right.material_override=layered
		_check((layered.get_shader_parameter("mesh_uv_scale") as Vector2).is_equal_approx(Vector2(material.uv1_scale.x,material.uv1_scale.y)),"scale survives conversion")
		_check((layered.get_shader_parameter("mesh_uv_offset") as Vector2).is_equal_approx(Vector2(material.uv1_offset.x,material.uv1_offset.y)),"offset survives conversion")
		for frame in 12:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var rendered:=get_viewport().get_texture().get_image();var samples:=0;var mismatches:=0
		for iy in 21:
			for ix in 21:
				var relative:=Vector3(lerpf(-.46,.46,float(ix)/20),lerpf(-.46,.46,float(iy)/20),0.)
				var a:=camera.unproject_position(left.global_position+relative);var b:=camera.unproject_position(right.global_position+relative)
				var original:=rendered.get_pixelv(Vector2i(a));var converted:=rendered.get_pixelv(Vector2i(b))
				# Ignore antialiased checker edges; compare rendered tile phase
				# and frequency, not the two shaders' different lighting models.
				if original.r>.12 and original.r<.40:continue
				samples+=1
				if (original.r>.30)!=(converted.r>.30):mismatches+=1
		_check(samples>200 and float(mismatches)/maxi(samples,1)<.04,"rendered UV frequency and phase agree: "+str(mismatches)+"/"+str(samples))
		var directory:=OS.get_environment("SHOT_DIR")
		if not directory.is_empty():
			DirAccess.make_dir_recursive_absolute(directory)
			_check(rendered.save_png(directory.path_join("uv_transform_"+str(phase)+".png"))==OK,"rendered comparison capture saved")
	print("SURFACE UV TRANSFORM: failures=",failures)
	get_tree().quit(0 if failures==0 else 1)

func _check(ok: bool, label: String) -> void:
	print("SURFACE UV CHECK: ",label," = ",ok)
	if not ok:failures+=1
