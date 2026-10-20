extends Node3D
## Loaded native handheld/character mip and compression diagnostics, not acceptance.
var failures: Array[String]=[]
var checks:=0
var maps: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(directory)
	var names: Array[String]=["res://assets/characters/mina_vale/texture_0.png"]
	var folder: String="res://assets/device/service_teletype"
	for name: String in DirAccess.get_files_at(folder):
		if name.ends_with(".png"):names.append(folder.path_join(name))
	check(names.size()>=28,"native handheld maps and character atlas present")
	for path: String in names:
		var texture:=load(path) as Texture2D
		check(texture!=null,"loaded map: "+path)
		if texture==null:continue
		var image: Image=texture.get_image()
		var expected:=int(floor(log(float(maxi(image.get_width(),image.get_height())))/log(2.)))
		check(image.has_mipmaps() and image.get_mipmap_count()==expected,"complete loaded mip chain: "+path)
		check(image.is_compressed(),"GPU-compressed physical map: "+path)
		maps.append({"path":path,"width":image.get_width(),"height":image.get_height(),"levels":image.get_mipmap_count(),"expected":expected,"compressed":image.is_compressed(),"loaded_bytes":image.get_data().size()})
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.16,.17,.19)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color(.8,.85,1.);environment.environment.ambient_light_energy=.4
	environment.environment.sky=Sky.new();environment.environment.sky.sky_material=ProceduralSkyMaterial.new();environment.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-25,0);sun.light_energy=1.1;add_child(sun)
	var camera:=Camera3D.new();camera.fov=38.;add_child(camera);camera.make_current()
	for station: Array in [["handheld","res://assets/device/service_teletype/service_teletype.glb"],["mina","res://assets/characters/mina_vale/mina_vale.gltf"]]:
		var model: Node3D=load(station[1]).instantiate();add_child(model)
		var bounds:=AABB();var first:=true
		for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			if draw.mesh==null:continue
			var box: AABB=draw.global_transform*draw.mesh.get_aabb()
			bounds=box if first else bounds.merge(box);first=false
		check(not first,"actual native model has visible geometry: "+station[0])
		var center: Vector3=bounds.get_center();var extent: float=maxf(bounds.size.x,bounds.size.y)
		camera.global_position=center+Vector3(extent*.45,extent*.22,extent*1.8);camera.look_at(center)
		for frame in 4:await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join(station[0]+".png"))==OK,"rendered native map response: "+station[0])
		model.free()
	var report: Dictionary={"evidence_class":"INERT","scope":"Loaded complete mip chains and GPU compression on the 28 repaired maps; native rendered specimens; no whole-world acceptance","checks":checks,"maps":maps,"failures":failures}
	var file:=FileAccess.open(directory.path_join("mip_repair.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("V2 MIP REPAIR BENCH: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," maps=",maps.size()," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
