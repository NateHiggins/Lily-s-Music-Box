extends Node
const Manager := preload("res://scripts/building/WeatherManager.gd")
const Service := preload("res://scripts/building/live_weather_service.gd")
const Trim := preload("res://scripts/building/orison_v2_millwork.gd")
const Atmosphere := preload("res://scripts/building/orison_v2_atmosphere.gd")
const Review := preload("res://tests/v2_millwork_weather_review.gd")
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	print("[MW ","PASS" if ok else "FAIL","] ",label)
	if not ok: failures.append(label)
func _ready() -> void:
	var observation := {"clouds":{"all":80},"main":{"humidity":70,"temp":8},"wind":{"speed":10,"deg":359},"weather":[{"id":501}],"rain":{"1h":1.2}}
	var parsed := Service.parse_openweather(observation)
	check(parsed.get("wind_speed_kmh")==36.0 and parsed.get("cloud_total")==.8 and parsed.get("weather_code")==63,"provider unit and weather-family normalization")
	check(Service.parse_openweather({}).is_empty(),"malformed provider cannot partially update presentation")
	observation.wind.speed="bad"
	check(Service.parse_openweather(observation).is_empty(),"typed field validation")
	var a := {"cloud_total":0.0,"wind_direction_degrees":359.0}
	var b := {"cloud_total":1.0,"wind_direction_degrees":1.0}
	var mid := Manager.interpolate(a,b,.5)
	check(is_equal_approx(mid.cloud_total,.5) and minf(mid.wind_direction_degrees,360-mid.wind_direction_degrees)<.01,"five-minute interpolation uses shortest wind-bearing arc")
	check(Manager.interpolate(a,b,0).cloud_total==0 and Manager.interpolate(a,b,1).cloud_total==1,"transition reaches exact endpoints")
	check(Manager.seasonal_snapshot({"month":1}).temperature_c<2.0 and Manager.seasonal_snapshot({"month":7}).temperature_c>24,"verified NYC monthly temperature baseline")
	var shapes := 0
	for day in 10000:
		var one := Manager.shape_for_day(str(day),1928)
		check(one==Manager.shape_for_day(str(day),1928),"deterministic shape seed") if day==0 else null
		if one>0: shapes+=1
	check(shapes>50 and shapes<160,"rare shape draw stays approximately one percent per campaign day")
	# Independently described shared/cut room stock, including a real door gap.
	var stock: Array[Dictionary] = [{"owner":"neighbor","source":"shared","label":"WallSouth","along_x":true,"bounds":AABB(Vector3(0,0,-.06),Vector3(4,3,.12))},
		{"owner":"room","source":"cut","label":"WallNorth","along_x":true,"bounds":AABB(Vector3(0,0,3.94),Vector3(1,3,.12))},
		{"owner":"room","source":"cut2","label":"WallNorth","along_x":true,"bounds":AABB(Vector3(2,0,3.94),Vector3(2,3,.12))}]
	var room := Node3D.new();add_child(room)
	Trim.build(room,{"id":"room","rect":[0,0,4,4],"class":"public"},0,3,.12,null,null,[],[],stock)
	var cap := room.get_node_or_null("PublicWainscotCap") as MultiMeshInstance3D
	check(cap!=null and cap.multimesh.instance_count==3,"shared wall and both cut-wall segments receive separate molded cap")
	check(cap.get_meta("separate_wood_piece",false) and cap.material_override.get_shader_parameter("longitudinal_grain"),"cap has its own length-oriented wood material")
	var base := room.get_node("HistoricMillwork") as MultiMeshInstance3D
	var count := 0
	for i in base.multimesh.instance_count:
		var t := base.multimesh.get_instance_transform(i)
		if absf(t.origin.y-.07)<.001: count+=1
	check(count==3,"baseboard follows actual cut/shared stock without spanning doorway void")
	var source_layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	for identity: String in OrisonV2PassageRegion.CELLS:
		if not identity.begins_with("shop_") and identity!="passage": continue
		var cell := (load("res://assets/building/floor_01_cells/"+identity+".gltf") as PackedScene).instantiate() as Node3D
		cell.name=identity;add_child(cell)
		check(preload("res://scripts/building/orison_v2_shop_millwork.gd").mount_cell(cell,source_layout),"source-backed wall trim mounts "+identity)
		check(not cell.find_children("HistoricMillwork","MultiMeshInstance3D",true,false).is_empty(),"shop source produces actual millwork "+identity)
		cell.free()
	var volume := preload("res://scripts/building/weather_noise.gd").load_volume()
	check(volume!=null and volume.has_mipmaps() and volume.get_data().size()==127,"loaded Perlin-Worley contains full 3D mip pyramid")
	var cirrus := load("res://assets/environment/weather/cirrus.png") as Texture2D
	check(cirrus.get_image().has_mipmaps(),"loaded cirrus optical mask has real mipmaps")
	var sky := ShaderMaterial.new();sky.shader=preload("res://shaders/v2_seasonal_sky.gdshader")
	var env := WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_SKY;env.environment.sky=Sky.new();env.environment.sky.sky_material=sky;add_child(env)
	sky.set_shader_parameter("cloud_noise",volume);sky.set_shader_parameter("cirrus_tex",load("res://assets/environment/weather/cirrus.png"))
	var camera := Camera3D.new();add_child(camera);camera.make_current()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("V2 MILLWORK WEATHER RESULT: ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
