extends Node3D
var directory: String
var material: ShaderMaterial
var values := {}
func _ready() -> void: call_deferred("_run")
func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var camera := Camera3D.new()
	camera.position.z = 1
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camera.environment.ambient_light_color = Color.BLACK
	add_child(camera)
	camera.make_current()
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(.6,.6)
	mesh.mesh = quad
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/dream_membrane.gdshader")
	material.set_shader_parameter("tension",.7)
	mesh.material_override = material
	add_child(mesh)
	var light := SpotLight3D.new()
	light.position.z = -1
	light.rotation.y = PI
	light.light_energy = 5
	light.shadow_enabled = true
	add_child(light)
	material.set_shader_parameter("membrane_thickness_m",.0002)
	var thin := await _sample("thin")
	material.set_shader_parameter("membrane_thickness_m",.004)
	var thick := await _sample("thick")
	light.light_energy = 0
	var off := await _sample("authored_emission_only")
	var ok := thin>off+.01 and thick-off<(thin-off)*.8
	FileAccess.open(directory.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(values,"\t"))
	if not ok: push_error("Native membrane transmission must decrease with thickness")
	print("THIN TRANSMISSION: ","PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
func _sample(label: String) -> float:
	for i in 15: await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(directory.path_join(label+".png"))
	var p := image.get_size()/2
	var c := image.get_pixel(p.x+10,p.y+10)
	var value := (c.r+c.g+c.b)/3
	values[label] = value
	return value
