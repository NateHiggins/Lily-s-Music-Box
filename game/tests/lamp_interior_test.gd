extends Node3D
## Sealed-volume transport proof. This does not replace an authored creature.
var field: RefCounted
var observation: Node3D
var directory: String
var values := {}
var failures := 0
func _ready() -> void: call_deferred("_run")
func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(.8,0,0)
	camera.look_at(Vector3(0,0,-2))
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	camera.make_current()
	var lamp := SpotLight3D.new()
	lamp.spot_range = 6
	lamp.spot_angle = 35
	lamp.light_energy = 0
	add_child(lamp)
	observation = preload("res://scripts/lamp/carried_lamp_observation.gd").new()
	add_child(observation)
	observation.state.switched_on = true
	observation.state.intensity = 12
	observation.state.angle = 35
	observation.range_m = 6
	field = preload("res://scripts/lamp/lamp_optical_voxel_field.gd").new()
	field.initialize(0)
	for i in 120:
		await RenderingServer.frame_post_draw
		if field.ready or not field.failed.is_empty(): break
	if not field.ready:
		get_tree().quit(2)
		return
	var shadow := preload("res://scripts/lamp/lamp_scene_shadow.gd").new()
	add_child(shadow)
	shadow.setup(field,lamp)
	var cloud := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.6,.6,.6)
	cloud.mesh = box
	cloud.position.z = -2
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/lamp_optical_interior.gdshader")
	material.set_shader_parameter("half_extent",Vector3(.3,.3,.3))
	cloud.material_override = material
	add_child(cloud)
	field.bind_material(material)
	var full := await _sample("full_depth")
	var internal := MeshInstance3D.new()
	var internal_box := BoxMesh.new()
	internal_box.size = Vector3(.1,.3,.025)
	internal.mesh = internal_box
	internal.position = Vector3(.06,0,-1.85)
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	internal.material_override = black
	add_child(internal)
	var partial := await _sample("internal_depth_layer")
	_check(full>.01 and partial>0 and partial<full*.85,"internal geometry partially occludes cloud depth")
	internal.position = Vector3(0,0,-1)
	internal_box.size = Vector3(.5,1,.05)
	var blocked := await _sample("external_shadow")
	_check(blocked<full*.1,"external mesh shadow carves the sealed volume")
	internal.queue_free()
	observation.state.switched_on = false
	observation.state.intensity = 0
	var off := await _sample("off")
	_check(off<.001,"unlit volume adds no light")
	shadow.queue_free()
	field.dispose()
	field = null
	for i in 12: await RenderingServer.frame_post_draw
	FileAccess.open(directory.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(values,"\t"))
	print("INTERIOR TRANSPORT: 3 checks; %d failures"%failures)
	get_tree().quit(0 if failures==0 else 1)
func _sample(label: String) -> float:
	for i in 20:
		field.observe(observation,true)
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(directory.path_join(label+".png"))
	var p := image.get_size()/2
	var c := image.get_pixel(p.x,p.y)
	var value := (c.r+c.g+c.b)/3
	values[label] = value
	return value
func _check(ok: bool,label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
