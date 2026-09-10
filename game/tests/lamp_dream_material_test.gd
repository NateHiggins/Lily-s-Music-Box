extends Node3D
var checks := 0
var failures := 0
var directory: String
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var root := preload("res://scenes/dream/DreamMazeRoot.tscn").instantiate() as DreamMazeRoot
	root.autonomous = false
	root.configure_dream({"case_id":"juno_feedback_tetris","profile_id":"juno_release_print","window":{},"seed_hex":"f123456789abcdef","maze_revision":1,"outcome":"","night_index":3,"spawn_anchor":1})
	add_child(root)
	for frame in 20: await RenderingServer.frame_post_draw
	var bridge: Node3D = root.get("_optical_material_bridge")
	_check(is_instance_valid(bridge),"actual Dream root owns bridge")
	if not is_instance_valid(bridge):
		get_tree().quit(1)
		return
	_check(bridge.field.ready and bridge.field.failed.is_empty(),"production field initialized")
	_check(bridge.scene_shadow.effect.passes > 0,"actual Dream geometry injects into optical field")
	_check(bridge.bound.size() > 0,"actual collected materials bound")
	var paths := {}
	for material: ShaderMaterial in bridge.bound:
		paths[material.shader.resource_path] = true
		_check(bool(material.get_shader_parameter("lamp_optical_bound")),"production binding active")
	print("PRODUCTION SHADERS: ",paths.keys())
	# Isolate presentation after proving real ownership. No ecological update
	# is run during the on/off sample below; the test shader supplies maximal
	# retained and reversible exposure as a deliberate afterglow challenge.
	root.process_mode = Node.PROCESS_MODE_DISABLED
	await _sample("actual_root_optical")
	for bound_material: ShaderMaterial in bridge.bound:
		bound_material.set_shader_parameter("lamp_optical_bound",false)
	await _sample("actual_root_legacy_control")
	for bound_material: ShaderMaterial in bridge.bound:
		bound_material.set_shader_parameter("lamp_optical_bound",true)
	await _sample("actual_root_optical_restored")
	root.visible = false
	# The following synthetic sampling probe has its own lamp pose, so the
	# real root's depth view must not shadow that unrelated diagnostic pose.
	bridge.scene_shadow.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for canvas in root.find_children("*","CanvasLayer",true,false): canvas.hide()
	var camera := Camera3D.new()
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	add_child(camera)
	camera.make_current()
	var quad := MeshInstance3D.new()
	quad.mesh = QuadMesh.new()
	quad.position.z = -1
	add_child(quad)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = 'shader_type spatial; render_mode unshaded;\n#include "res://shaders/dream_irradiance.gdshaderinc"\nvarying vec3 world; void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){vec3 spectrum; vec4 light=dream_irradiance(world,vec3(0,0,1),vec2(1),vec3(0),spectrum); ALBEDO=vec3(light.w)*spectrum;}'
	material.shader = shader
	quad.material_override = material
	var observation: Node3D = bridge.observation
	observation.global_transform = Transform3D.IDENTITY
	observation.state.switched_on = true
	observation.state.intensity = 1.0
	bridge.field.bind_material(material)
	bridge.field.observe(observation)
	var on := await _sample("on")
	observation.state.color = Color(1.0,.25,.05)
	bridge.field.observe(observation)
	await _sample("warm_spectrum")
	var warm_image := get_viewport().get_texture().get_image()
	var warm_color := warm_image.get_pixel(warm_image.get_width()/2+30,warm_image.get_height()/2+30)
	_check(warm_color.r>warm_color.g and warm_color.g>warm_color.b,"shared sample carries lamp spectrum into material transfer")
	observation.state.color = Color.WHITE
	observation.position.x = 20
	bridge.field.observe(observation)
	var translated := await _sample("translated_away")
	_check(translated < .01,"translated lamp cannot wrap onto old material position")
	observation.position.x = 0
	observation.state.switched_on = false
	observation.state.intensity = 0
	bridge.field.observe(observation)
	var off := await _sample("off_retained_exposure")
	_check(on > .1 and off < .01,"live response turns off despite maximal ecological exposure")
	bridge.field.unbind_material(material)
	var legacy := await _sample("unbound_legacy")
	_check(legacy > .9,"unbound legacy response preserved")
	var retired: ShaderMaterial = bridge.bound[0]
	var empty: Array[ShaderMaterial] = []
	bridge.set_materials(empty)
	_check(bridge.bound.is_empty() and not bool(retired.get_shader_parameter("lamp_optical_bound")),"retired material unbound")
	var field_ref: WeakRef = weakref(bridge.field)
	root.queue_free()
	for frame in 10: await RenderingServer.frame_post_draw
	_check(field_ref.get_ref() == null,"root teardown releases field")
	FileAccess.open(directory.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify({"on":on,"translated":translated,"off":off,"legacy":legacy,"shaders":paths.keys(),"checks":checks,"failures":failures},"\t"))
	print("DREAM MATERIAL: %d checks; %d failures"%[checks,failures])
	get_tree().quit(0 if failures == 0 else 1)
func _sample(label: String) -> float:
	for frame in 12: await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(directory.path_join(label+".png"))
	return image.get_pixel(image.get_width()/2 + 30,image.get_height()/2 + 30).r
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
