extends Node3D
## INERT optical diagnostic: production GPU shaders on a known plane.
## This exposes shader/impact failures cheaply; it is not playable-world qualification.
func _ready() -> void:
	run.call_deferred()

func run() -> void:
	RealityState.persistence_enabled=false
	var camera:=Camera3D.new();add_child(camera);camera.position=Vector3(0,1.7,4)
	camera.look_at(Vector3(0,.2,-5));camera.make_current()
	var world_environment:=WorldEnvironment.new();var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.05,.06,.08)
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE
	environment.ambient_light_energy=.8;world_environment.environment=environment;add_child(world_environment)
	var floor_mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(60,.2,60)
	floor_mesh.mesh=box;floor_mesh.position.y=-.1;add_child(floor_mesh)
	var floor_material:=StandardMaterial3D.new();floor_material.albedo_color=Color(.12,.14,.16);floor_mesh.material_override=floor_material
	var contact:=GPUParticlesCollisionHeightField3D.new();contact.size=Vector3(64,20,64)
	contact.resolution=GPUParticlesCollisionHeightField3D.RESOLUTION_256
	contact.heightfield_mask=1;contact.cull_mask=1<<18;add_child(contact)
	var extension:=QueensWeatherExtension.new()
	var emitters:=QueensWeatherExtension.gpu_precipitation(camera,
		preload("res://shaders/queens_precipitation_motion.gdshader"),preload("res://shaders/queens_precipitation_draw.gdshader"))
	# Diagnostic-only colour records whether a main particle ever touched geometry.
	for emitter: GPUParticles3D in [emitters[0],emitters[3]]:
		var process:=emitter.process_material as ShaderMaterial
		var diagnostic:=Shader.new();diagnostic.code=process.shader.code.replace("if(COLLIDED) {","if(COLLIDED) { COLOR=vec4(1.0,0.0,0.0,1.0);")
		process.shader=diagnostic
		var visual:=emitter.draw_pass_1.material as ShaderMaterial
		var colour:=Shader.new();colour.code=visual.shader.code.replace("ALPHA=mask*opacity*COLOR.a;","ALBEDO*=COLOR.rgb; ALPHA=mask*opacity*COLOR.a;")
		visual.shader=colour
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	var rows: Array=[];var failures: Array[String]=[];var splash_images: Array[Image]=[]
	for kind in [0,3]:
		extension.weights=Vector4.ZERO;extension.weights[kind]=1.0
		for enabled in [true,false]:
			contact.cull_mask=(1<<18) if enabled else 0
			for emitter: GPUParticles3D in emitters:emitter.restart(true)
			for frame in 180:
				extension.update_emitters(emitters,camera.global_position,true,1.0,camera)
				await RenderingServer.frame_post_draw
			var name:="%s_%s.png"%["rain" if kind==0 else "hail","contact" if enabled else "no_contact"]
			var image:=get_viewport().get_texture().get_image()
			if image.save_png(directory.path_join(name))!=OK:failures.append("capture "+name)
			var touched:=0
			for y in image.get_height():
				for x in range(0,image.get_width(),2):
					var pixel:=image.get_pixel(x,y)
					if pixel.r>.04 and pixel.r>pixel.g*1.7 and pixel.r>pixel.b*1.7:touched+=1
			if (enabled and touched<4) or (not enabled and touched!=0):failures.append("GPU contact colour control "+name)
			if kind==0:
				print("SPLASH GPU bounds ",enabled," ",emitters[4].capture_aabb()," path ",emitters[0].sub_emitter)
				# Hide only the streak draw, retaining its running parent simulation.
				# Any remaining drops must have been emitted by real GPU contacts.
				var visual:=emitters[0].draw_pass_1.material as ShaderMaterial
				var original:=visual.shader
				var control:=Shader.new();control.code=original.code.replace("ALPHA=mask*opacity*COLOR.a;","ALPHA=0.0;")
				visual.shader=control
				for frame in 8:await RenderingServer.frame_post_draw
				var splash_image:=get_viewport().get_texture().get_image();splash_images.append(splash_image)
				if splash_image.save_png(directory.path_join("splash_"+("contact" if enabled else "no_contact")+".png"))!=OK:failures.append("splash capture")
				visual.shader=original
			rows.append({"kind":kind,"contact":enabled,"image":name,"post_contact_colour_pixels_every_second_column":touched})
	var splash_changed:=0
	for y in range(0,splash_images[0].get_height(),2):
		for x in range(0,splash_images[0].get_width(),2):
			var a:=splash_images[0].get_pixel(x,y);var b:=splash_images[1].get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.02:splash_changed+=1
	if splash_changed<32:failures.append("ongoing impact splashes disappear after bounded pool fills")
	var frogs:=emitters[5]
	var probe:=preload("res://tests/orison_v2_surface_inventory.gd").new()
	var native_surfaces: Array=[];var triangle_count:=0
	for pass_index in frogs.draw_passes:
		var mesh:=frogs.get_draw_pass_mesh(pass_index)
		var geometry: Dictionary=probe._mesh(mesh)
		for surface: Dictionary in geometry.surfaces:
			triangle_count+=int(surface.triangles)
			if bool(surface.missing_uv) or int(surface.nonfinite_uv)>0 or int(surface.degenerate_uv_triangles)>0:failures.append("native frog UV charts")
		var finish: Dictionary=probe._material(mesh.surface_get_material(0))
		if int(finish.get("uv_mode",-1))!=0 or not bool(finish.get("has_normal_tex",false)) or not bool(finish.get("has_rough_tex",false)):failures.append("native frog mapped PBR binding")
		if finish.maps.size()<3:failures.append("native frog PBR maps missing")
		native_surfaces.append({"geometry":geometry,"material":finish})
	for texture: Dictionary in probe.texture_rows.values():
		if not bool(texture.mips) or int(texture.mip_levels)<7:failures.append("native frog loaded mip chain")
	if triangle_count<=0 or triangle_count>600:failures.append("native frog triangle budget")
	extension.weights=Vector4.ZERO;extension.frog_fall=1.0;contact.cull_mask=1<<18
	for frame in 420:
		extension.update_emitters(emitters,camera.global_position,true,1.0,camera)
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("native_frog_fall.png"))
	# Record the genuine GPU collision impulse, without replacing the motion
	# shader or injecting an impact. Only the diagnostic material colours it.
	var diagnostic_frog:=Shader.new()
	diagnostic_frog.code=preload("res://shaders/orison_weather_frog.gdshader").code \
		.replace("void vertex() {","varying float recorded_impact;\nvoid vertex() {") \
		.replace("float impact=clamp(INSTANCE_CUSTOM.w,0.0,1.0);","float impact=clamp(INSTANCE_CUSTOM.w,0.0,1.0); recorded_impact=impact;") \
		.replace("ALBEDO=s.albedo;","ALBEDO=mix(s.albedo,vec3(1.0,0.0,0.0),step(.3,recorded_impact));")
	for pass_index in frogs.draw_passes:
		(frogs.get_draw_pass_mesh(pass_index).surface_get_material(0) as ShaderMaterial).shader=diagnostic_frog
	var impact_pixels:=0
	for frame in 60:
		extension.update_emitters(emitters,camera.global_position,true,1.0,camera)
		await RenderingServer.frame_post_draw
		if frame%4!=0:continue
		var image:=get_viewport().get_texture().get_image();var count:=0
		for y in range(0,image.get_height(),4):
			for x in range(0,image.get_width(),4):
				var pixel:=image.get_pixel(x,y)
				if pixel.r>.08 and pixel.r>pixel.g*2.0 and pixel.r>pixel.b*2.0:count+=1
		if count>impact_pixels:
			impact_pixels=count;image.save_png(directory.path_join("native_frog_impact.png"))
	if impact_pixels<4:failures.append("native frog shader never receives a real GPU impact")
	FileAccess.open(directory.path_join("frog_loaded_stock.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"Small native family UV/PBR/loaded-mip and GPU impact diagnostic; diagnostic red only after a real collision; no composed-world or human acceptance","surfaces":native_surfaces,"textures":probe.texture_rows,"triangles":triangle_count,"impact_pixels_sixteenth_grid_peak":impact_pixels},"\t"))
	probe.free()
	FileAccess.open(directory.path_join("contact_review.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"production GPU motion with diagnostic post-contact colour on a known floor; contact/no-contact optical controls and isolated splash draws; no gameplay, performance or human acceptance","captures":rows,"splash_changed_pixels_quarter_grid":splash_changed,"failures":failures},"  "))
	print("PRECIPITATION CONTACT REVIEW: ","PASS" if failures.is_empty() else "FAIL", " ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
