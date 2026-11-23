extends Node3D
## Passive distant motion: headlights and tail lamps on the Queensboro roadway, lit
## elevated cars on its upper deck, one tug working the west channel, and smoke from
## the far districts' chimneys (game/data/orison_v2/exterior/city_far_districts.json).
## Presentation only: no collision, route, resident, schedule, weather or save owner.
## Lamps brighten with the campaign clock's darkness; smoke drifts with the wind the
## day-night director publishes to the sky.
const DATA := "res://data/orison_v2/exterior/city_far_districts.json"
const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")
const BRIDGE_AZIMUTH_DEG := 119.70833333333333
const QUEENS := Vector3(-250.0, 0.0, -529.8)  # roadway's Queens end, building frame
const SPAN_M := 1135.2276
## Upper (el) deck along the span, surveyed from city_bridge.glb every 100 m; the
## roadway runs 6.64 m beneath it.
const UPPER_DECK: Array[float] = [34.65, 38.05, 41.45, 44.85, 45.14, 45.14, 45.14, 45.14, 45.14, 42.65, 39.25, 35.85]
const ROADWAY_DROP_M := 6.64
const CARS_PER_LANE := 14
const ROADWAY_LANES: Array[float] = [-5.5, -2.0, 2.0, 5.5]
const EL_LANES: Array[float] = [-3.0, 3.0]
const EL_TRAIN_CARS := 5
const EL_CAR_M := 15.2
## Car paint (sRGB) and the rail top above the surveyed upper deck.
const EL_PAINT := Color(0.32, 0.36, 0.30)
const EL_RAIL_M := 0.3
const TUG_X := -960.0
const TUG_RANGE: Vector2 = Vector2(-3300.0, 2600.0)

var _along := Vector3.ZERO
var _across := Vector3.ZERO
var _lamps: MultiMesh
var _lamp_material: StandardMaterial3D
var _cars: Array[Dictionary] = []
var _el: MultiMesh
## The el cars' lit window band (the rail stock's `window` finish), dimmed by daylight.
var _el_windows: StandardMaterial3D
var _trains: Array[Dictionary] = []
var _tug: Node3D
var _tug_light: OmniLight3D
var _tug_z := 0.0
var _tug_dir := -1.0
var _smoke: GPUParticles3D
var _smoke_material: ParticleProcessMaterial
var _clock := CampaignClock.new()
var _clock_elapsed := 1.0
var darkness := 0.0


func _ready() -> void:
	var azimuth := deg_to_rad(BRIDGE_AZIMUTH_DEG)
	_along = Vector3(sin(azimuth), 0.0, -cos(azimuth))  # eastbound, Manhattan to Queens
	_across = _along.cross(Vector3.UP)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19290523
	_build_traffic(rng)
	_build_el(rng)
	_build_tug()
	_build_smoke()
	_refresh_light()


func _deck(s: float) -> float:
	var t := clampf(s / 100.0, 0.0, UPPER_DECK.size() - 1.001)
	var i := int(t)
	return lerpf(UPPER_DECK[i], UPPER_DECK[i + 1], t - i)


func _point(s: float, offset: float, upper: bool) -> Vector3:
	var p := QUEENS - _along * s + _across * offset
	p.y = _deck(s) - (0.0 if upper else ROADWAY_DROP_M)
	return p


func _build_traffic(rng: RandomNumberGenerator) -> void:
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_lamp_material.vertex_color_use_as_albedo = true
	_lamp_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lamp_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_lamp_material.disable_fog = true  # point lamps read through haze
	var quad := QuadMesh.new()
	# Screen-constant points (a few pixels) so lamps read from the roof and the street alike.
	_lamp_material.fixed_size = true
	quad.size = Vector2(0.0022, 0.0013)
	quad.material = _lamp_material
	_lamps = MultiMesh.new()
	_lamps.transform_format = MultiMesh.TRANSFORM_3D
	_lamps.use_colors = true
	_lamps.mesh = quad
	_lamps.instance_count = ROADWAY_LANES.size() * CARS_PER_LANE
	for lane in ROADWAY_LANES.size():
		for k in CARS_PER_LANE:
			# Lanes south of the centre run toward Queens; their lamps face Queens viewers.
			var toward_queens := ROADWAY_LANES[lane] > 0.0
			_cars.append({"lane": ROADWAY_LANES[lane], "s": rng.randf_range(-60.0, SPAN_M),
				"speed": rng.randf_range(8.0, 12.5) * (-1.0 if toward_queens else 1.0),
				"head": toward_queens})
	var draw := MultiMeshInstance3D.new()
	draw.name = "BridgeLamps"
	draw.multimesh = _lamps
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)


## The el cars are the rail stock's `el_car` (art/blender/scripts/build_v2_street_trams.py), drawn with that
## table's finishes: one batch, a surface per finish, the window band lit at night.
func _build_el(rng: RandomNumberGenerator) -> void:
	var table := OrisonV2StreetTrams.load_table()
	var materials := {}
	for finish: Dictionary in table.get("finishes", []):
		materials[str(finish.id)] = OrisonV2StreetTraffic.stock_material(finish)
	var meshes := OrisonV2StreetTraffic.stock_meshes(str(table.get("stock", "")), materials)
	if not meshes.has("el_car"):
		push_error("Far motion: the rail stock lacks el_car")
		return
	_el_windows = materials.get("window")
	_el = MultiMesh.new()
	_el.transform_format = MultiMesh.TRANSFORM_3D
	_el.use_colors = true
	_el.mesh = meshes.el_car
	_el.instance_count = EL_LANES.size() * EL_TRAIN_CARS
	for i in _el.instance_count:
		_el.set_instance_color(i, EL_PAINT.srgb_to_linear())
	for lane in EL_LANES.size():
		_trains.append({"lane": EL_LANES[lane], "s": rng.randf_range(0.0, SPAN_M),
			"speed": 13.0 * (-1.0 if EL_LANES[lane] > 0.0 else 1.0)})
	var draw := MultiMeshInstance3D.new()
	draw.name = "ElCars"
	draw.multimesh = _el
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)


func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


func _build_tug() -> void:
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	hull.append_from(MetreUV.chart(_box(Vector3(6.4, 2.2, 22.0))), 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)))
	hull.append_from(MetreUV.chart(_box(Vector3(4.6, 2.6, 8.0))), 0, Transform3D(Basis.IDENTITY, Vector3(0, 3.0, 1.5)))
	hull.append_from(MetreUV.chart(_box(Vector3(3.2, 1.6, 3.4))), 0, Transform3D(Basis.IDENTITY, Vector3(0, 5.1, 3.0)))
	var stack := SurfaceTool.new()
	stack.begin(Mesh.PRIMITIVE_TRIANGLES)
	stack.append_from(MetreUV.chart(_box(Vector3(1.1, 3.6, 1.1))), 0, Transform3D(Basis.IDENTITY, Vector3(0, 5.6, -1.2)))
	_tug = Node3D.new()
	_tug.name = "Tug"
	add_child(_tug)
	for pair: Array in [[hull, "timber", Color(0.28, 0.22, 0.18)], [stack, "iron_neutral", Color(0.12, 0.12, 0.12)]]:
		var material := MatLib.get_mat(str(pair[1])).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.albedo_color = pair[2]
		var draw := MeshInstance3D.new()
		draw.mesh = (pair[0] as SurfaceTool).commit()
		draw.material_override = material
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tug.add_child(draw)
	_tug_light = OmniLight3D.new()
	_tug_light.light_color = Color(1.0, 0.7, 0.4)
	_tug_light.omni_range = 18.0
	_tug_light.shadow_enabled = false
	_tug_light.position = Vector3(0, 6.5, 3.0)
	_tug.add_child(_tug_light)
	_tug_z = 600.0
	_tug.position = Vector3(TUG_X, -6.0, _tug_z)


func _build_smoke() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	assert(int(data.schema) == 1 and str(data.frame) == "ORISON_V2_BUILDING_FRAME")
	var stacks: Array = data.stacks
	assert(not stacks.is_empty())
	var points := Image.create(stacks.size(), 1, false, Image.FORMAT_RGBF)
	for i in stacks.size():
		var row: Array = stacks[i]
		assert(row.size() == 4 and float(row[3]) > 0.0)
		points.set_pixel(i, 0, Color(float(row[0]), float(row[1]) + 1.0, float(row[2])))
	_smoke_material = ParticleProcessMaterial.new()
	_smoke_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	_smoke_material.emission_point_texture = ImageTexture.create_from_image(points)
	_smoke_material.emission_point_count = stacks.size()
	_smoke_material.direction = Vector3(0, 1, 0)
	_smoke_material.spread = 12.0
	_smoke_material.initial_velocity_min = 1.2
	_smoke_material.initial_velocity_max = 2.4
	_smoke_material.gravity = Vector3(3.0, 0.25, 0.0)
	_smoke_material.damping_min = 0.2
	_smoke_material.damping_max = 0.4
	_smoke_material.scale_min = 4.0
	_smoke_material.scale_max = 7.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 2.8))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	_smoke_material.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(0.42, 0.40, 0.38, 0.0))
	fade.set_color(1, Color(0.55, 0.54, 0.53, 0.0))
	fade.add_point(0.08, Color(0.36, 0.35, 0.34, 0.55))
	fade.add_point(0.6, Color(0.5, 0.49, 0.48, 0.28))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	_smoke_material.color_ramp = fade_texture
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = soft
	var sprite := StandardMaterial3D.new()
	sprite.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sprite.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sprite.vertex_color_use_as_albedo = true
	sprite.albedo_texture = puff
	sprite.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var quad := QuadMesh.new()
	quad.material = sprite
	_smoke = GPUParticles3D.new()
	_smoke.name = "ChimneySmoke"
	_smoke.process_material = _smoke_material
	_smoke.draw_pass_1 = quad
	_smoke.amount = stacks.size() * 18
	_smoke.lifetime = 36.0
	_smoke.preprocess = 36.0
	_smoke.local_coords = false
	_smoke.visibility_aabb = AABB(Vector3(-4000, -10, -4000), Vector3(8000, 400, 8000))
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_smoke)


func _process(delta: float) -> void:
	var lamp := 0.15 + 0.85 * darkness
	var i := 0
	for car: Dictionary in _cars:
		car.s = float(car.s) + float(car.speed) * delta
		if car.s > SPAN_M:
			car.s = -60.0
		elif car.s < -60.0:
			car.s = SPAN_M
		var colour := Color(1.0, 0.86, 0.62, lamp) if bool(car.head) else Color(0.9, 0.12, 0.06, lamp * 0.8)
		_lamps.set_instance_transform(i, Transform3D(Basis.IDENTITY, _point(float(car.s), float(car.lane), false) + Vector3.UP * 0.9))
		_lamps.set_instance_color(i, colour)
		i += 1
	var car_index := 0
	for train: Dictionary in _trains:  # empty when the stock is missing
		train.s = fposmod(float(train.s) + float(train.speed) * delta, SPAN_M + 200.0)
		for k in EL_TRAIN_CARS:
			var s := float(train.s) - 100.0 + k * EL_CAR_M
			var position := _point(s, float(train.lane), true) + Vector3.UP * EL_RAIL_M
			var ahead := _point(s + 1.0, float(train.lane), true) + Vector3.UP * EL_RAIL_M
			var basis := Basis.looking_at((ahead - position).normalized(), Vector3.UP) * Basis(Vector3.UP, PI * 0.5)  # the stock is modelled +X forward
			var pose := Transform3D(basis, position)
			if s < -40.0 or s > SPAN_M:
				pose.origin.y = -500.0  # off the span: parked out of sight below the river
			_el.set_instance_transform(car_index, pose)
			car_index += 1
	_tug_z += _tug_dir * 3.6 * delta
	if _tug_z < TUG_RANGE.x or _tug_z > TUG_RANGE.y:
		_tug_dir = -_tug_dir
		_tug_z = clampf(_tug_z, TUG_RANGE.x, TUG_RANGE.y)
	_tug.position = Vector3(TUG_X, -6.0, _tug_z)
	_tug.rotation.y = 0.0 if _tug_dir < 0.0 else PI
	_clock_elapsed += delta
	if _clock_elapsed >= 2.0:
		_clock_elapsed = 0.0
		_refresh_light()


func _refresh_light() -> void:
	if _clock.bind_state():
		set_darkness_from_minute(_clock.minute_of_day())
	var sky := get_viewport().world_3d.environment.sky if get_viewport() and get_viewport().world_3d \
		and get_viewport().world_3d.environment and get_viewport().world_3d.environment.sky else null
	if sky != null and sky.sky_material is ShaderMaterial:
		var shader := sky.sky_material as ShaderMaterial
		var direction: Variant = shader.get_shader_parameter("cloud_wind_direction")
		var speed: Variant = shader.get_shader_parameter("cloud_wind_speed")
		if direction is Vector3 and speed != null:
			var push := (direction as Vector3) * clampf(float(speed) / 3.6, 0.0, 12.0) * 0.6
			_smoke_material.gravity = Vector3(push.x, 0.25, push.z)


## Also used by a capture or prologue that projects a detached clock.
func set_darkness_from_minute(minute_of_day: float) -> void:
	var hour := minute_of_day / 60.0
	darkness = 1.0 - smoothstep(6.0, 7.5, hour) * (1.0 - smoothstep(16.8, 18.3, hour))
	_lamp_material.albedo_color = Color(1, 1, 1, 1)
	if _el_windows != null:
		_el_windows.emission_energy_multiplier = float(_el_windows.get_meta("lamp_energy", 1.0)) * (0.08 + 0.92 * darkness)
	_tug_light.light_energy = 0.4 + 1.6 * darkness
