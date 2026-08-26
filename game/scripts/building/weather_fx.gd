class_name WeatherFX
extends Node3D
## Canonical driving rain for STREET and the open roof. Near particles follow
## the player, a single inward-facing shell owns the middle distance, and one
## batched road-mist owner joins the carriageway to its two authored storm
## mouths. Near and middle streaks are two curved instances in one MultiMesh;
## the Compatibility renderer otherwise expands each particle into a costly
## submission. The building supplies exposure; this node never guesses
## "outside" from height alone.

signal weather_flash_changed(level: float)

const SPATTER_COUNT := 72
const LEAF_COUNT := 8
const LEAF_BOX := Vector3(15.0, 2.0, 15.0)
const LEAF_HEIGHT := 11.0
const WIND_BASE := Vector3(4.8, 0.0, 2.1)
const GUST_SPEED := 0.21
const GUST_STRENGTH := 0.38

var wind := WIND_BASE
var _observed_wind := WIND_BASE

var _splash: CPUParticles3D
var _leaves: CPUParticles3D
var _snow: CPUParticles3D
var _middle_rain: MultiMeshInstance3D
var _middle_material: ShaderMaterial
var _road_mist: MultiMeshInstance3D
var _mist_material: ShaderMaterial
var _splash_material: StandardMaterial3D
var _player: Node3D
var _exposure_query: Callable
var _cover_query: Callable
var _t := 0.0
var _lightning: Node3D
var _lightning_wait := 16.0
var _lightning_age := -1.0
var _rng := RandomNumberGenerator.new()
var _seed := 19280731
var _rain_enabled := true
var _mist_enabled := true
var _lightning_enabled := false
var _live_conditions: Dictionary = {}


func setup(player: Node3D, exposure_query := Callable(),
		cover_query := Callable()) -> void:
	_player = player
	_exposure_query = exposure_query
	_cover_query = cover_query


func _ready() -> void:
	var requested_seed := OS.get_environment("WEATHER_SEED")
	if requested_seed.is_valid_int():
		_seed = int(requested_seed)
	_rng.seed = _seed
	_rain_enabled = OS.get_environment("WEATHER_RAIN") != "0"
	_mist_enabled = OS.get_environment("WEATHER_MIST") != "0"
	_splash = _make_splash()
	add_child(_splash)
	_leaves = _make_leaves()
	add_child(_leaves)
	_snow = _make_snow()
	add_child(_snow)
	_middle_rain = _make_middle_rain()
	add_child(_middle_rain)
	_road_mist = _make_road_mist()
	add_child(_road_mist)
	_lightning = Node3D.new()
	_lightning.name = "DistantLightning"
	add_child(_lightning)


## Wet ground is only convincing because it reflects. Compatibility has no
## screen-space reflections, so each authored lamp/sign receives its existing
## cheap additive pavement smear.
func build_reflections(layout: Dictionary) -> int:
	var made := 0
	for fl in layout["floors"]:
		var fz: float = float(fl["z"])
		for marker in fl["markers"]:
			var kind: String = marker["kind"]
			var tint: Color
			var length: float
			var width: float
			if kind == "street_lamp":
				tint = Color(1.0, 0.66, 0.28)
				length = 6.4
				width = 1.5
			elif kind == "neon_sign":
				var authored: Array = marker.get("tint", [1.0, 0.3, 0.44])
				tint = Color(float(authored[0]), float(authored[1]),
						float(authored[2]))
				length = 4.2
				width = 1.1
			else:
				continue
			var authored_position: Array = marker["pos"]
			var glare := MeshInstance3D.new()
			glare.name = "WetGlare_" + str(marker["id"])
			var quad := QuadMesh.new()
			quad.size = Vector2(width, length)
			glare.mesh = quad
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			material.albedo_color = Color(tint.r, tint.g, tint.b, 0.16)
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			var gradient := Gradient.new()
			gradient.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
			gradient.set_color(1, Color(tint.r, tint.g, tint.b, 0.42))
			var texture := GradientTexture2D.new()
			texture.gradient = gradient
			texture.fill = GradientTexture2D.FILL_RADIAL
			texture.fill_from = Vector2(0.5, 0.5)
			texture.fill_to = Vector2(0.5, 0.0)
			material.albedo_texture = texture
			glare.material_override = material
			glare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			glare.position = GameBoot.b2g([float(authored_position[0]),
					float(authored_position[1]) - 0.9, fz + 0.02])
			glare.rotation_degrees = Vector3(-90, 0, 0)
			add_child(glare)
			made += 1
	return made


func apply_profile(profile: Dictionary) -> void:
	var rain_color: Color = profile.get("rain", Color(0.62, 0.70, 0.82, 0.68))
	var mist_color: Color = profile.get("mist", Color(0.08, 0.10, 0.14, 0.34))
	if _splash_material:
		_splash_material.albedo_color = Color(rain_color.r, rain_color.g,
				rain_color.b, rain_color.a * 0.56)
	if _middle_material:
		_middle_material.set_shader_parameter("rain_color", rain_color)
	if _mist_material:
		_mist_material.set_shader_parameter("mist_color", mist_color)


func set_live_conditions(conditions: Dictionary) -> void:
	_live_conditions = conditions.duplicate(true)
	if _live_conditions.is_empty():
		return
	var wet := bool(_live_conditions.get("wet", false))
	var rain_intensity := float(_live_conditions.get(
			"rain_intensity", 1.0 if wet else 0.0))
	_rain_enabled = rain_intensity > 0.008 \
			and OS.get_environment("WEATHER_RAIN") != "0"
	_lightning_enabled = bool(_live_conditions.get("thunderstorm", false))
	if not _lightning_enabled:
		_lightning_age = -1.0
	_mist_enabled = (wet or float(_live_conditions.get("cloud_low", 0.0)) > 0.68) \
			and OS.get_environment("WEATHER_MIST") != "0"
	var speed := float(_live_conditions.get("wind_speed_kmh", 0.0)) / 3.6
	var bearing := deg_to_rad(float(_live_conditions.get(
			"wind_direction_degrees", 0.0)))
	# Meteorological bearings say where wind comes from.
	_observed_wind = Vector3(-sin(bearing), 0.0, cos(bearing)) * speed
	wind = _observed_wind


func is_exposed_at(point: Vector3) -> bool:
	if _exposure_query.is_valid():
		return bool(_exposure_query.call(point))
	return false


func is_covered_at(point: Vector3) -> bool:
	if _cover_query.is_valid():
		return bool(_cover_query.call(point))
	return false


func diagnostic_snapshot() -> Dictionary:
	return {
		"seed": _seed,
		"near_rain_mode": "procedural_close_shell",
		"spatter_count": SPATTER_COUNT,
		"leaf_count": LEAF_COUNT,
		"rain_enabled": _rain_enabled,
		"snow_enabled": bool(_live_conditions.get("snowing", false)),
		"lightning_enabled": _lightning_enabled,
		"mist_enabled": _mist_enabled,
		"live_conditions": _live_conditions.duplicate(true),
		"exposed": is_exposed_at(_player.global_position) if _player else false,
		"covered": is_covered_at(_player.global_position) if _player else false,
		"steady_weather_submissions": 4,
	}


func _make_splash() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "DrivingRainSpatter"
	particles.amount = SPATTER_COUNT
	particles.lifetime = 0.28
	particles.preprocess = 0.28
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(13.0, 0.02, 13.0)
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 34.0
	particles.initial_velocity_min = 0.45
	particles.initial_velocity_max = 1.1
	particles.gravity = Vector3(0, -6.2, 0)
	particles.scale_amount_min = 0.42
	particles.scale_amount_max = 0.9
	particles.set("seed", _seed + 23)
	var fleck := QuadMesh.new()
	fleck.size = Vector2(0.014, 0.075)
	particles.mesh = fleck
	_splash_material = StandardMaterial3D.new()
	_splash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_splash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_splash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_splash_material.albedo_color = Color(0.64, 0.72, 0.84, 0.38)
	_splash_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_splash_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	particles.material_override = _splash_material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


func _make_leaves() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "StormDebris"
	particles.amount = LEAF_COUNT
	particles.lifetime = 7.0
	particles.preprocess = 7.0
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = LEAF_BOX
	particles.position = Vector3(0, LEAF_HEIGHT, 0)
	particles.direction = Vector3(0.6, -1, 0.2)
	particles.spread = 24.0
	particles.initial_velocity_min = 0.7
	particles.initial_velocity_max = 1.8
	particles.gravity = Vector3(WIND_BASE.x * 0.8, -1.5, WIND_BASE.z * 0.8)
	particles.damping_min = 0.25
	particles.damping_max = 0.65
	particles.angular_velocity_min = -220.0
	particles.angular_velocity_max = 220.0
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.3
	particles.set("seed", _seed + 37)
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.16, 0.10)
	particles.mesh = leaf
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.38, 0.25, 0.12)
	material.roughness = 0.7
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	particles.material_override = material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


func _make_snow() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "LiveSnow"
	particles.amount = 480
	particles.lifetime = 6.0
	particles.preprocess = 6.0
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(13.0, 1.0, 13.0)
	particles.position = Vector3(0.0, 10.0, 0.0)
	particles.direction = Vector3(0.08, -1.0, 0.03)
	particles.spread = 18.0
	particles.initial_velocity_min = 0.45
	particles.initial_velocity_max = 1.5
	particles.gravity = Vector3(0.22, -0.42, 0.08)
	particles.scale_amount_min = 0.28
	particles.scale_amount_max = 1.55
	var flake := QuadMesh.new()
	flake.size = Vector2(0.045, 0.045)
	particles.mesh = flake
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_prepass_alpha,
		shadows_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float core = 1.0 - smoothstep(0.26, 0.92, radius);
	ALBEDO = vec3(0.88, 0.93, 1.0);
	ALPHA = core * 0.76;
}
"""
	material.shader = shader
	particles.material_override = material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	return particles


func _make_middle_rain() -> MultiMeshInstance3D:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_prepass_alpha,
		shadows_disabled;
uniform vec4 rain_color : source_color = vec4(0.52, 0.63, 0.82, 0.28);
uniform float seed = 0.0;
uniform float close_suppression = 0.0;
varying flat float rain_shell;
float hash(vec2 n) {
	return fract(sin(dot(n, vec2(91.73, 37.11)) + seed) * 43758.5453);
}
void vertex() {
	rain_shell = float(INSTANCE_ID);
}

float streak_layer(vec2 screen_uv, vec2 cells, float speed, float slope,
		float salt, float keep, float min_length, float max_length) {
	// Slant the sampling lattice instead of drawing upright bars. Each
	// diagonal column receives its own vertical phase, so streak heads never
	// arrive in conspicuous rows.
	vec2 falling = vec2((screen_uv.x + screen_uv.y * slope) * cells.x,
			screen_uv.y * cells.y - TIME * speed);
	float column = floor(falling.x);
	falling.y += hash(vec2(column, salt + 151.0)) * 3.71;
	vec2 cell = floor(falling);
	vec2 local = fract(falling);
	float centre = 0.5 + (hash(cell + vec2(7.0, salt)) - 0.5) * 0.50;
	float width = mix(0.020, 0.070, hash(cell + vec2(31.0, salt)));
	float line = 1.0 - smoothstep(width, width * 2.2,
			abs(local.x - centre));
	float length = mix(min_length, max_length,
			hash(cell + vec2(59.0, salt)));
	float start = mix(0.04, 0.32, hash(cell + vec2(83.0, salt)));
	float head_fade = mix(0.08, 0.18, hash(cell + vec2(89.0, salt)));
	float tail_fade = mix(0.12, 0.28, hash(cell + vec2(97.0, salt)));
	float body = smoothstep(start, start + head_fade, local.y)
			* (1.0 - smoothstep(length,
			min(0.99, length + tail_fade), local.y));
	float chosen = step(keep, hash(cell + vec2(101.0, salt)));
	float opacity = mix(0.18, 0.82, hash(cell + vec2(127.0, salt)));
	return line * body * chosen * opacity;
}
void fragment() {
	// Two fine, differently angled middle exposures prevent a regular curtain;
	// the close exposure is sparser and longer, as a real shutter sees rain
	// that crosses the lens nearby. Every head and tail feathers independently.
	float fine = streak_layer(SCREEN_UV, vec2(286.0, 21.0), 8.7, 0.043,
			11.0, 0.55, 0.14, 0.40);
	float middle = streak_layer(SCREEN_UV, vec2(218.0, 15.0), 6.9, 0.067,
			29.0, 0.59, 0.22, 0.58);
	float close = streak_layer(SCREEN_UV, vec2(126.0, 7.2), 5.1, 0.092,
			53.0, 0.76, 0.32, 0.78);
	float is_close = step(0.5, rain_shell);
	float streak = mix(fine * 0.030 + middle * 0.052,
			(fine * 0.012 + close * 0.086) * (1.0 - close_suppression),
			is_close);
	float edge = smoothstep(0.02, 0.12, SCREEN_UV.y)
			* smoothstep(0.02, 0.14, 1.0 - SCREEN_UV.y);
	ALBEDO = rain_color.rgb;
	EMISSION = rain_color.rgb * 0.015;
	ALPHA = streak * edge * rain_color.a;
}
"""
	_middle_material = ShaderMaterial.new()
	_middle_material.shader = shader
	_middle_material.set_shader_parameter("seed", float(posmod(_seed, 4093)))
	var shell := SphereMesh.new()
	shell.radius = 18.0
	shell.height = 22.0
	shell.radial_segments = 48
	shell.rings = 24
	shell.material = _middle_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = shell
	multimesh.instance_count = 2
	multimesh.set_instance_transform(0, Transform3D.IDENTITY)
	multimesh.set_instance_transform(1, Transform3D(
			Basis.IDENTITY.scaled(Vector3(0.20, 0.34, 0.20)), Vector3.ZERO))
	var visual := MultiMeshInstance3D.new()
	visual.name = "DrivingRainMiddle"
	visual.multimesh = multimesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual


func _make_road_mist() -> MultiMeshInstance3D:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_prepass_alpha,
		shadows_disabled;
uniform vec4 mist_color : source_color = vec4(0.08, 0.10, 0.14, 0.34);
uniform float seed = 0.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)),
			hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	float a = noise(vec2(UV.x * 5.1 + TIME * 0.035, UV.y * 2.2));
	float b = noise(vec2(UV.x * 9.0 - TIME * 0.021, UV.y * 3.8 + 7.0));
	float edge = smoothstep(0.0, 0.10, UV.x)
			* smoothstep(0.0, 0.10, 1.0 - UV.x)
			* smoothstep(0.0, 0.16, UV.y)
			* smoothstep(0.0, 0.28, 1.0 - UV.y);
	ALBEDO = mist_color.rgb;
	ALPHA = edge * mist_color.a * (0.18 + a * 0.48 + b * 0.20);
}
"""
	_mist_material = ShaderMaterial.new()
	_mist_material.shader = shader
	_mist_material.set_shader_parameter("seed", float(posmod(_seed, 8191)))
	var ribbon := QuadMesh.new()
	ribbon.size = Vector2.ONE
	ribbon.material = _mist_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = ribbon
	multimesh.instance_count = 3
	# One low longitudinal body and one vertical thickening at each road mouth.
	var road_basis := Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))
	road_basis = road_basis.scaled(Vector3(40.6, 9.2, 1.0))
	multimesh.set_instance_transform(0,
			Transform3D(road_basis, Vector3(0.25, 0.16, 19.322)))
	var mouth_basis := Basis.from_euler(Vector3(0.0, PI * 0.5, 0.0))
	mouth_basis = mouth_basis.scaled(Vector3(9.2, 2.8, 1.0))
	multimesh.set_instance_transform(1,
			Transform3D(mouth_basis, Vector3(-19.78, 1.20, 19.322)))
	multimesh.set_instance_transform(2,
			Transform3D(mouth_basis, Vector3(20.28, 1.20, 19.322)))
	var visual := MultiMeshInstance3D.new()
	visual.name = "RoadwayMist"
	visual.multimesh = multimesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual


func _process(delta: float) -> void:
	_t += delta
	_update_lightning(delta)
	var gust := sin(_t * GUST_SPEED) * 0.6 \
			+ sin(_t * GUST_SPEED * 2.7) * 0.4
	wind = _observed_wind * (1.0 + gust * GUST_STRENGTH)
	if _leaves:
		_leaves.gravity = Vector3(wind.x * 0.85, -1.5, wind.z * 0.85)
	if _player == null:
		return
	var player_position := _player.global_position
	var at := Vector3(roundf(player_position.x), player_position.y,
			roundf(player_position.z))
	var exposed := is_exposed_at(player_position)
	var covered := exposed and is_covered_at(player_position)
	_leaves.global_position = at + Vector3(0, LEAF_HEIGHT, 0)
	_splash.global_position = at + Vector3(0, 0.025, 0)
	_middle_rain.global_position = at + Vector3(0, 4.0, 0)
	_snow.global_position = at + Vector3(0, 10.0, 0)
	_splash.emitting = exposed and not covered and _rain_enabled
	_leaves.emitting = exposed and not covered and _rain_enabled
	_middle_rain.visible = exposed and _rain_enabled
	_snow.emitting = exposed and not covered \
			and bool(_live_conditions.get("snowing", false))
	_middle_material.set_shader_parameter("close_suppression",
			1.0 if covered else 0.0)
	_road_mist.visible = _mist_enabled


func _update_lightning(delta: float) -> void:
	if not _lightning_enabled:
		weather_flash_changed.emit(0.0)
		return
	_lightning_wait -= delta
	if _lightning_age < 0.0 and _lightning_wait <= 0.0:
		_lightning_age = 0.0
		_lightning_wait = _rng.randf_range(22.0, 48.0)
		_lightning.rotation_degrees.y = _rng.randf_range(-110.0, 110.0)
	var level := 0.0
	if _lightning_age >= 0.0:
		_lightning_age += delta
		level = exp(-pow((_lightning_age - 0.07) / 0.045, 2.0))
		level += exp(-pow((_lightning_age - 0.31) / 0.075, 2.0)) * 0.58
		if _lightning_age > 0.72:
			_lightning_age = -1.0
			level = 0.0
	weather_flash_changed.emit(level)
