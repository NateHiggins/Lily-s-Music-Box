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
	FileAccess.open(directory.path_join("contact_review.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"production GPU motion with diagnostic post-contact colour on a known floor; contact/no-contact optical controls and isolated splash draws; no gameplay, performance or human acceptance","captures":rows,"splash_changed_pixels_quarter_grid":splash_changed,"failures":failures},"  "))
	print("PRECIPITATION CONTACT REVIEW: ","PASS" if failures.is_empty() else "FAIL", " ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
