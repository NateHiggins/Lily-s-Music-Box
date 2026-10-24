extends Node3D
## INERT engine positive control: distance fading in a minimal isolated scene.
var light: OmniLight3D
var records: Array=[]
var failures: Array[String]=[]
func _ready() -> void:run.call_deferred()
func sample(label: String) -> float:
	for frame in 24:await RenderingServer.frame_post_draw
	var picture:=get_viewport().get_texture().get_image()
	var brightness:=0.
	for y in range(200,520,20):
		for x in range(400,880,20):
			brightness+=picture.get_pixel(x,y).get_luminance()
	brightness/=384.
	var directory:=OS.get_environment("SHOT_DIR")
	picture.save_png(directory.path_join(label+".png"))
	records.append({"phase":label,"brightness":brightness,"camera_distance":light.global_position.distance_to(get_viewport().get_camera_3d().global_position),"enabled":light.distance_fade_enabled,"begin":light.distance_fade_begin,"length":light.distance_fade_length,"shadow_distance":light.distance_fade_shadow})
	return brightness
func run() -> void:
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=0.
	add_child(environment)
	var ground:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(3.,.2,3.);ground.mesh=box
	var material:=StandardMaterial3D.new();material.albedo_color=Color.WHITE;material.roughness=1.;ground.material_override=material;add_child(ground)
	var camera:=Camera3D.new();camera.position=Vector3(2,2,3);add_child(camera);camera.look_at(Vector3.ZERO);camera.make_current()
	light=OmniLight3D.new();light.position=Vector3(0,1.8,0);light.omni_range=8.;light.light_energy=3.;light.shadow_enabled=true;add_child(light)
	var original: float=await sample("original")
	light.distance_fade_begin=.1;light.distance_fade_length=.1;light.distance_fade_shadow=.1;light.distance_fade_enabled=true
	var faded: float=await sample("faded")
	light.distance_fade_enabled=false
	var restored: float=await sample("restored")
	if original<.02:failures.append("original lit fixture is dark")
	if faded>original*.1:failures.append("distance fade does not remove isolated illumination beyond its range")
	if absf(restored-original)>.01:failures.append("restored original illumination differs")
	FileAccess.open(directory.path_join("distance_control.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Isolated engine/API positive control, not V2 rendering or gameplay qualification.","records":records,"failures":failures},"\t"))
	print("LIGHT DISTANCE CONTROL: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size()," original=",original," faded=",faded," restored=",restored)
	get_tree().quit(0 if failures.is_empty() else 1)
