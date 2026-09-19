extends Node3D
## Material response fixture only. These spheres are not an anatomy acceptance.
var directory: String
var failures := 0
var labels: Array[String] = []
var centers: Array[Vector3] = []
var camera: Camera3D
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5
	camera.position = Vector3(0,0,5)
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camera.environment.ambient_light_color = Color.BLACK
	add_child(camera)
	camera.make_current()
	for kind in 6:
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/dream_hero_skin.gdshader")
		material.set_shader_parameter("system_kind",kind)
		material.set_shader_parameter("proof_time",0.0)
		_add(material,["flesh_sss","gold","crystal","membrane_skin","wet_sucker","cilium_skin"][kind])
	for kind in 3:
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/dream_cilia.gdshader")
		_add(material,"orbital_cilia_"+str(kind),kind)
	for path in ["dream_eyelid","dream_eye","dream_eyelid_translucent"]:
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/"+path+".gdshader")
		if path == "dream_eyelid_translucent": material.set_shader_parameter("lid_kind",2)
		_add(material,path)
	var light := SpotLight3D.new()
	light.position = Vector3(0,0,3)
	light.spot_angle = 65
	light.spot_range = 10
	light.light_energy = 8
	light.shadow_enabled = true
	add_child(light)
	var on: Image = await _capture("front")
	var blocker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10,10,.1)
	blocker.mesh = box
	blocker.position.z = 1
	blocker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(blocker)
	var shadow: Image = await _capture("native_mesh_shadow")
	blocker.queue_free()
	light.light_energy = 0
	var off: Image = await _capture("off_authored_emission_only")
	var results := {}
	for i in labels.size():
		var p := camera.unproject_position(centers[i])
		var gain := 0.0
		var shadow_gain := 0.0
		for y in range(-15,16):
			for x in range(-15,16):
				var a := on.get_pixel(int(p.x)+x,int(p.y)+y)
				var b := off.get_pixel(int(p.x)+x,int(p.y)+y)
				var s := shadow.get_pixel(int(p.x)+x,int(p.y)+y)
				gain += (a.r+a.g+a.b-b.r-b.g-b.b)/3.0
				shadow_gain += (s.r+s.g+s.b-b.r-b.g-b.b)/3.0
		gain /= 961.0
		shadow_gain /= 961.0
		results[labels[i]] = {"lamp_gain":gain,"shadow_gain":shadow_gain}
		if gain < .002:
			failures += 1
			push_error("Missing native light response: "+labels[i])
		if shadow_gain > maxf(.01,gain*.15):
			failures += 1
			push_error("Mesh shadow failed to suppress native light: "+labels[i])
	light.position.z = -3
	light.rotation.y = PI
	light.light_energy = 8
	await _capture("back")
	FileAccess.open(directory.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("NATIVE FAMILIES: 24 checks; %d failures"%failures)
	get_tree().quit(0 if failures == 0 else 1)
func _add(material: ShaderMaterial,label: String,kind: int = -1) -> void:
	var index := labels.size()
	var pos := Vector3((index%4-1.5)*1.1,(1-index/4)*1.1,0)
	var sphere := SphereMesh.new()
	sphere.radius = .4
	sphere.height = .8
	var surface: GeometryInstance3D
	if kind < 0:
		var mesh := MeshInstance3D.new()
		mesh.mesh = sphere
		surface = mesh
	else:
		var mesh := MultiMeshInstance3D.new()
		mesh.multimesh = MultiMesh.new()
		mesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.multimesh.use_custom_data = true
		mesh.multimesh.mesh = sphere
		mesh.multimesh.instance_count = 1
		mesh.multimesh.set_instance_transform(0,Transform3D.IDENTITY)
		mesh.multimesh.set_instance_custom_data(0,Color(kind,1,0,1))
		surface = mesh
	surface.material_override = material
	surface.position = pos
	add_child(surface)
	labels.append(label)
	centers.append(pos)
func _capture(label: String) -> Image:
	for frame in 16: await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(directory.path_join(label+".png"))
	return image
