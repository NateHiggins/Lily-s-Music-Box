class_name WeatherFX
extends Node3D
## The tail end of a storm: light drizzle, a soft unsteady wind, and the
## leaves it is still bringing down.
##
## Two things shape the implementation. Volumetric fog does not exist on
## the Compatibility renderer, so "drizzle" cannot be a fog volume — it is
## particles plus the wet ground the generator already laid down, and the
## reflections in that wet do most of the work. And weather has to follow
## the camera: emitters are parked overhead and re-centred every frame, so
## a boxful of rain travels with you instead of existing once over the
## stoop.
##
## Everything is CPUParticles3D. GPU particles are supported in
## Compatibility but their behaviour across mobile drivers is exactly the
## kind of thing that works here and fails on a phone, and this is a few
## hundred quads either way.

const RAIN_COUNT := 430
const RAIN_BOX := Vector3(26.0, 1.0, 26.0)
const RAIN_HEIGHT := 11.0
const LEAF_COUNT := 44
const LEAF_BOX := Vector3(30.0, 2.0, 30.0)
const LEAF_HEIGHT := 13.0
## Gusts, not a constant draught: the base wind drifts and swells so the
## drizzle leans a little differently every few seconds.
const WIND_BASE := Vector3(1.15, 0.0, 0.55)
const GUST_SPEED := 0.21
const GUST_STRENGTH := 0.85

var wind := WIND_BASE

var _rain: CPUParticles3D
var _splash: CPUParticles3D
var _leaves: CPUParticles3D
var _player: Node3D
var _t := 0.0
var _lightning: Node3D
var _lightning_card: MeshInstance3D
var _lightning_material: StandardMaterial3D
var _ground_flash: MeshInstance3D
var _ground_flash_material: StandardMaterial3D
var _lightning_wait := 16.0
var _lightning_age := -1.0
var _rng := RandomNumberGenerator.new()


func setup(player: Node3D) -> void:
	_player = player


## Wet ground is only convincing because it REFLECTS, and this renderer has
## no screen-space reflections to give. A dark, smooth puddle material on
## its own just reads as a dark patch. So the reflections are drawn: an
## elongated additive smear on the pavement under every lamp and every
## neon sign, stretched along the viewing axis the way a real reflection
## smears across ripples. It is the oldest trick for a wet street and it
## costs one unlit quad per source.
func build_reflections(layout: Dictionary) -> int:
	var made := 0
	for fl in layout["floors"]:
		var fz: float = float(fl["z"])
		for m in fl["markers"]:
			var kind: String = m["kind"]
			var tint: Color
			var length: float
			var width: float
			if kind == "street_lamp":
				tint = Color(1.0, 0.66, 0.28)
				length = 6.4
				width = 1.5
			elif kind == "neon_sign":
				var t: Array = m.get("tint", [1.0, 0.3, 0.44])
				tint = Color(float(t[0]), float(t[1]), float(t[2]))
				length = 4.2
				width = 1.1
			else:
				continue
			var p: Array = m["pos"]
			var mi := MeshInstance3D.new()
			mi.name = "WetGlare_" + str(m["id"])
			var quad := QuadMesh.new()
			quad.size = Vector2(width, length)
			mi.mesh = quad
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.16)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			# fade to nothing at the ends so the smear has no hard edge
			var grad := Gradient.new()
			grad.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
			grad.set_color(1, Color(tint.r, tint.g, tint.b, 0.42))
			var gt := GradientTexture2D.new()
			gt.gradient = grad
			gt.fill = GradientTexture2D.FILL_RADIAL
			gt.fill_from = Vector2(0.5, 0.5)
			gt.fill_to = Vector2(0.5, 0.0)
			mat.albedo_texture = gt
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# flat on the pavement, just above the puddle decals
			mi.position = GameBoot.b2g([float(p[0]), float(p[1]) - 0.9,
					fz + 0.02])
			mi.rotation_degrees = Vector3(-90, 0, 0)
			add_child(mi)
			made += 1
	return made


func _ready() -> void:
	_rng.seed = 19280731
	_rain = _make_rain()
	add_child(_rain)
	_splash = _make_splash()
	add_child(_splash)
	_leaves = _make_leaves()
	add_child(_leaves)
	_build_lightning()


func _build_lightning() -> void:
	# Marker/timer node only. A shadowless directional flash penetrated every
	# interior wall and also proved unstable on the headless Compatibility
	# renderer. The sky and wet surfaces carry the distant flash instead.
	_lightning = Node3D.new()
	_lightning.name = "DistantLightning"
	_lightning.rotation_degrees = Vector3(-24, -58, 0)
	add_child(_lightning)
	_lightning_card = MeshInstance3D.new()
	var sky_quad := QuadMesh.new()
	sky_quad.size = Vector2(62.0, 34.0)
	_lightning_card.mesh = sky_quad
	_lightning_card.position = Vector3(35.0, 31.0, -76.0)
	_lightning_material = _flash_material()
	_lightning_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_lightning_card.material_override = _lightning_material
	_lightning_card.cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lightning_card)
	_ground_flash = MeshInstance3D.new()
	var ground_quad := QuadMesh.new()
	ground_quad.size = Vector2(34.0, 26.0)
	_ground_flash.mesh = ground_quad
	_ground_flash.rotation_degrees.x = -90
	_ground_flash_material = _flash_material()
	_ground_flash.material_override = _ground_flash_material
	_ground_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ground_flash)


func _flash_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.52, 0.64, 0.90, 0.0)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.70, 0.80, 1.0, 0.72))
	gradient.set_color(1, Color(0.24, 0.32, 0.50, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	material.albedo_texture = texture
	return material


func _make_rain() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Drizzle"
	p.amount = RAIN_COUNT
	p.lifetime = 1.5
	p.preprocess = 1.5          # already raining when you arrive
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = RAIN_BOX
	p.position = Vector3(0, RAIN_HEIGHT, 0)
	p.direction = Vector3(0, -1, 0)
	p.spread = 0.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 11.0
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	# A drop is a streak, not a dot: long, extremely thin, unshaded so it
	# stays visible against dark brick without needing a light on it.
	var m := QuadMesh.new()
	m.size = Vector2(0.017, 0.58)
	p.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.66, 0.74, 0.86, 0.55)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = mat
	return p


## The drizzle has to land on something. A thin sheet of short-lived
## upward flecks at pavement height reads as spatter without simulating
## a single collision.
func _make_splash() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Spatter"
	p.amount = 90
	p.lifetime = 0.32
	p.preprocess = 0.3
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(16.0, 0.02, 16.0)
	p.position = Vector3(0, 0.02, 0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 32.0
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.85
	p.gravity = Vector3(0, -5.5, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9
	var m := QuadMesh.new()
	m.size = Vector2(0.035, 0.035)
	p.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.70, 0.78, 0.90, 0.34)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = mat
	return p


func _make_leaves() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Leaves"
	p.amount = LEAF_COUNT
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = LEAF_BOX
	p.position = Vector3(0, LEAF_HEIGHT, 0)
	p.direction = Vector3(0.6, -1, 0.2)
	p.spread = 25.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.6
	# A wet leaf falls slowly and refuses to fall straight: light gravity,
	# strong damping, and enough angular velocity that it tumbles.
	p.gravity = Vector3(0, -1.35, 0)
	p.damping_min = 0.25
	p.damping_max = 0.65
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.35
	var m := QuadMesh.new()
	m.size = Vector2(0.16, 0.10)
	p.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.46, 0.30, 0.14)
	mat.roughness = 0.7
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# leaves are lit, so they catch the sodium as they pass a lamp
	p.material_override = mat
	return p


func _process(delta: float) -> void:
	_t += delta
	_update_lightning(delta)
	# Gusts: two out-of-phase sines so the wind never repeats on a beat the
	# ear or eye can latch onto.
	var gust := sin(_t * GUST_SPEED) * 0.6 + sin(_t * GUST_SPEED * 2.7) * 0.4
	wind = WIND_BASE * (1.0 + gust * GUST_STRENGTH)
	if _rain:
		# drizzle leans with the wind rather than falling plumb
		_rain.gravity = Vector3(wind.x * 1.6, -9.0, wind.z * 1.6)
	if _leaves:
		_leaves.gravity = Vector3(wind.x * 2.4, -1.35, wind.z * 2.4)
	if _player == null:
		return
	# Re-centre on the player so the weather is wherever they are. Kept on
	# whole metres: moving the emitter box every frame by a fraction makes
	# already-spawned drops appear to shear sideways.
	var p := _player.global_position
	var at := Vector3(roundf(p.x), 0.0, roundf(p.z))
	_rain.global_position = at + Vector3(0, RAIN_HEIGHT, 0)
	_leaves.global_position = at + Vector3(0, LEAF_HEIGHT, 0)
	_splash.global_position = Vector3(at.x, 0.02, at.z)
	# Indoors the sky is not overhead: suppress rather than rain through
	# six storeys of slab. The block's ground floor sits at y ~ 0, so
	# anything above the first slab is inside by definition.
	var outside: bool = p.y < 1.9 and (absf(p.x) > 14.2 or p.z > 10.4
			or p.z < -10.4)
	_rain.emitting = outside
	_splash.emitting = outside
	_leaves.emitting = outside


func _update_lightning(delta: float) -> void:
	_lightning_wait -= delta
	if _lightning_age < 0.0 and _lightning_wait <= 0.0:
		_lightning_age = 0.0
		_lightning_wait = _rng.randf_range(22.0, 48.0)
		_lightning.rotation_degrees.y = _rng.randf_range(-110.0, 110.0)
	var level := 0.0
	if _lightning_age >= 0.0:
		_lightning_age += delta
		# Two distant impulses, separated enough to read as cloud lightning
		# rather than a game-camera flash.
		level = exp(-pow((_lightning_age - 0.07) / 0.045, 2.0))
		level += exp(-pow((_lightning_age - 0.31) / 0.075, 2.0)) * 0.58
		if _lightning_age > 0.72:
			_lightning_age = -1.0
			level = 0.0
	if _lightning_material:
		_lightning_material.albedo_color.a = level * 0.34
	if _ground_flash_material:
		_ground_flash_material.albedo_color.a = level * 0.11
	if _player and _ground_flash:
		_ground_flash.global_position = Vector3(
				_player.global_position.x, 0.045, _player.global_position.z)
