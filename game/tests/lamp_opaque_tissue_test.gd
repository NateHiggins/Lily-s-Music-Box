extends Node3D
const Ocular = preload("res://scripts/dream/entity/dream_ocular_assembly.gd")
var directory: String
var checks := 0
var failures := 0
var measurements := {}
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var owner := Ocular.new()
	owner.build(self,28)
	_check(owner.lid_materials[0].shader == preload("res://shaders/dream_eyelid.gdshader") and owner.lid_materials[1].shader == owner.lid_materials[0].shader,"two flesh lids use opaque material")
	_check(owner.lid_materials[2].shader == preload("res://shaders/dream_eyelid_translucent.gdshader"),"third membrane retains transparency")
	_check(owner.cornea_material.shader == preload("res://shaders/dream_cornea.gdshader") and owner.eye_material.shader == preload("res://shaders/dream_eye.gdshader"),"cornea separated from opaque globe")
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0,0,.7)
	camera.near = .01
	camera.make_current()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.BLACK
	add_child(environment)
	var lamp := SpotLight3D.new()
	add_child(lamp)
	lamp.position = Vector3(.12,.08,.45)
	lamp.look_at(Vector3.ZERO)
	lamp.light_energy = .15
	lamp.shadow_enabled = true
	var surface := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(.3,.3)
	surface.mesh = quad
	add_child(surface)
	var probe := MeshInstance3D.new()
	probe.mesh = QuadMesh.new()
	var probe_material := ShaderMaterial.new()
	var probe_shader := Shader.new()
	probe_shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never; uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest; void vertex(){POSITION=vec4(VERTEX.xy*2.0,1.0,1.0);} void fragment(){ALPHA=1.0;ALBEDO=vec3(step(0.00001,texture(depth_texture,SCREEN_UV).r));}"
	probe_material.shader = probe_shader
	probe_material.render_priority = 127
	probe.material_override = probe_material
	probe.extra_cull_margin = 10
	add_child(probe)
	probe.visible = false
	for family in ["dream_eyelid","dream_eye"]:
		var values: Array[float] = []
		for candidate in [false,true]:
			var material := ShaderMaterial.new()
			material.shader = load("res://shaders/"+family+".gdshader") if candidate else load("res://tests/fixtures/lamp_material/"+family+"_before.gdshader")
			material.set_shader_parameter("debug_gray",true)
			surface.material_override = material
			probe.visible = false
			await _capture(family+("_candidate" if candidate else "_before"))
			probe.visible = true
			var image: Image = await _capture(family+("_candidate_depth" if candidate else "_before_depth"))
			values.append(image.get_pixel(image.get_width()/2,image.get_height()/2).r)
		measurements[family] = values
		_check(values[0] < .1 and values[1] > .9,family+" restores actual opaque depth writing")
	FileAccess.open(directory.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
	print("OPAQUE TISSUE: %d checks; %d failures"%[checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
func _capture(label: String) -> Image:
	for frame in 12: await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(directory.path_join(label+".png"))
	return image
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
