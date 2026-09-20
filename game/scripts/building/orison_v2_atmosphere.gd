extends Node3D
## Runtime atmosphere owns its resources; DayNightDirector owns their values.
## The sky shader is extracted unchanged from the preserved V1 implementation.
const SKY_SHADER := preload("res://shaders/orison_waking_sky.gdshader")
const NIGHT_TEXTURE := "res://assets/building/textures/sky/orison_queens_night_rain_half_dome_4k.png"
var director: DayNightDirector
var environment: Environment

func _ready() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.68
	environment.glow_bloom = 0.10
	environment.glow_hdr_threshold = 0.85
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
