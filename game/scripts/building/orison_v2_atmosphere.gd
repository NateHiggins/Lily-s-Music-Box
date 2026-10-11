extends Node3D
## Runtime atmosphere owns its resources; DayNightDirector owns their values.
## Forward+ uses the seasonal native sky; Compatibility retains the V1 dome.
const SKY_SHADER := preload("res://shaders/orison_waking_sky.gdshader")
const NIGHT_TEXTURE := "res://assets/building/textures/sky/orison_queens_night_rain_half_dome_4k.png"
var director: DayNightDirector
var environment: Environment
var sky_material: ShaderMaterial
var weather_manager: Node

func _ready() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	# Keep bright lamp spill from bleaching dark lettering and nearby controls.
	# Optical reach/energy still belong to the carried lamp; this is bloom only.
	environment.glow_intensity = 0.02
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 2.0
	environment.glow_hdr_luminance_cap = 2.0
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		environment.ssao_enabled = true
		environment.ssao_radius = 0.9
		environment.ssao_intensity = 1.6
		environment.ssao_power = 1.4
		environment.ssao_detail = 0.6
		environment.ssao_light_affect = 0.15
		environment.ssil_enabled = true
		environment.ssil_radius = 2.2
		environment.ssil_intensity = 0.75
		environment.ssil_sharpness = 0.98
		environment.ssil_normal_rejection = 1.0
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	var panorama := load(NIGHT_TEXTURE) as Texture2D
	material.set_shader_parameter("panorama_a", panorama)
	material.set_shader_parameter("panorama_b", panorama)
	material.set_shader_parameter("moon_surface", load("res://assets/environment/lroc_color_poles_1k.jpg"))
	var cloud_seed := 19280731
	if OS.get_environment("WEATHER_SEED").is_valid_int():
		cloud_seed = int(OS.get_environment("WEATHER_SEED"))
	material.set_shader_parameter("cloud_phase", float(posmod(cloud_seed, 997)) / 997.0 * TAU)
	var sphere := SphereMesh.new()
	sphere.radius = 120.0
	sphere.height = 240.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var dome := MeshInstance3D.new()
	dome.name = "NightSkyHalfDome"
	dome.mesh = sphere
	dome.material_override = material
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)
	# Retain the spatial dome for Compatibility. Forward+ renders a native
	# half-resolution sky; the lighting director still owns celestial uniforms.
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		dome.visible = false
		var hybrid := ShaderMaterial.new()
		hybrid.shader = preload("res://shaders/v2_seasonal_sky.gdshader")
		hybrid.set_shader_parameter("panorama_a",panorama)
		hybrid.set_shader_parameter("panorama_b",panorama)
		hybrid.set_shader_parameter("moon_surface",load("res://assets/environment/lroc_color_poles_1k.jpg"))
		var native_sky := Sky.new()
		native_sky.sky_material=hybrid
		native_sky.radiance_size=Sky.RADIANCE_SIZE_128
		native_sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
		environment.sky=native_sky
		environment.background_mode=Environment.BG_SKY
		material=hybrid
	sky_material=material
	var key := DirectionalLight3D.new()
	key.name = "CelestialKey"
	key.shadow_enabled = true
	key.shadow_bias = 0.035
	key.shadow_normal_bias = 0.55
	key.directional_shadow_max_distance = 48.0
	key.directional_shadow_fade_start = 0.80
	add_child(key)
	director = DayNightDirector.new()
	director.name = "DayNightDirector"
	add_child(director)
	director.setup(self, environment, key, material)

func bind_weather(world: Node3D) -> void:
	var effects := preload("res://scripts/building/v2_weather_fx.gd").new()
	effects.name="WeatherFX"
	effects.setup(world.player,Callable(effects,"exposed"),Callable(effects,"covered"))
	world.add_child(effects)
	director.bind_weather(effects)
	weather_manager=preload("res://scripts/building/WeatherManager.gd").new()
	weather_manager.name="WeatherManager"
	weather_manager.configure(world.campaign_clock,director,sky_material,effects)
	add_child(weather_manager)
