extends Node3D
## Lightweight optical review; no production-world or completion claim.
const Manager := preload("res://scripts/building/WeatherManager.gd")
var sky_material: ShaderMaterial
func _ready() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new();clock.bind_state()
	var env := Environment.new();env.background_mode=Environment.BG_SKY
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var mat := ShaderMaterial.new();mat.shader=preload("res://shaders/v2_seasonal_sky.gdshader")
	sky_material=mat
	mat.set_shader_parameter("cloud_noise",preload("res://scripts/building/weather_noise.gd").load_volume())
	mat.set_shader_parameter("cirrus_tex",load("res://assets/environment/weather/cirrus.png"))
	mat.set_shader_parameter("moon_surface",load("res://assets/environment/lroc_color_poles_1k.jpg"))
	env.sky=Sky.new();env.sky.sky_material=mat;env.sky.radiance_size=Sky.RADIANCE_SIZE_128;env.sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
	var world_env := WorldEnvironment.new();world_env.environment=env;add_child(world_env)
	var key := DirectionalLight3D.new();add_child(key)
	var director := DayNightDirector.new();add_child(director);director.setup(self,env,key,mat)
	var camera := Camera3D.new();camera.fov=70;add_child(camera);camera.make_current()
	get_viewport().use_taa=true
	for month in [1,4,7,10]:
		clock.configure_date(1928,month,15,750)
		var conditions := LiveWeatherService.presentation(Manager.seasonal_snapshot({"month":month}))
		conditions["season_weights"]=Manager.season_weights(month)
		director.set_live_conditions(conditions);director._apply(750)
		mat.set_shader_parameter("season_weights",conditions.season_weights);mat.set_shader_parameter("humidity",conditions.relative_humidity)
		camera.look_at(Vector3(0,12,-30),Vector3.UP)
		await capture("season_%02d" % month)
	mat.set_shader_parameter("cloud_coverage",.08)
	for shape in [1,2,3]:
		mat.set_shader_parameter("shape_kind",shape);mat.set_shader_parameter("shape_opacity",1.0)
		camera.look_at(Vector3(1.6,2.3,-2.6),Vector3.UP)
		await capture("shape_%d" % shape)
	mat.set_shader_parameter("shape_kind",0)
	clock.configure_date(1928,7,15,1140);director._apply(1140)
	camera.look_at(Vector3(0,4,-30),Vector3.UP)
	await capture("summer_twilight")
	print("V2 SKY OPTICAL REVIEW COMPLETE")
	get_tree().quit(0)
func capture(label: String) -> void:
	for frame in 30:
		sky_material.set_shader_parameter("temporal_phase",float(frame))
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(label+".png"))
