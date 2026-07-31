class_name ExteriorDetailPass
extends Node3D
## Cheap exterior finish pass layered over the generator's broad site pass.
## Everything except the damage cards is held in three shared MultiMeshes.

var detail_count := 0
var decal_count := 0
var puddle_count := 0
var faulty_lamp_count := 0

var _boxes: Array = []
var _cylinders: Array = []
var _puddles: Array = []
var _puddle_material: ShaderMaterial


func build(layout: Dictionary, parent: Node3D) -> Dictionary:
	name = "ExteriorDetailPass"
	add_to_group("storm_reflectors")
	var floor: Dictionary = {}
	for candidate in layout.floors:
		if candidate.id == "F01":
			floor = candidate
			break
	if floor.is_empty():
		return {}
	_build_street_hardware()
	_build_damage(parent)
	_build_puddles()
	_build_city_silhouettes(floor)
	_build_car_details(floor)
	_emit_boxes(parent)
	_emit_cylinders(parent)
	_emit_puddles(parent)
	print("[BUILDING] exterior finish: %d batched details, %d decals, %d puddles"
			% [detail_count, decal_count, puddle_count])
	return {"details": detail_count, "decals": decal_count,
			"puddles": puddle_count}


func configure_street_lights(world: Node) -> void:
	# One lamp west of the entrance has a dying ballast. The others remain
	# dependable navigation anchors.
	for child in world.get_children():
		if child is LightFixtureProp \
				and child.prop_type == "street_lamp" \
				and child.name == "F01_STREETLAMP_04":
			child.set_intermittent_exterior_fault(true)
			var buzz := AudioStreamPlayer3D.new()
			buzz.name = "FailingBallastAudio"
			buzz.stream = PropAudio.get_stream("streetlamp_buzz_loop")
			buzz.volume_db = -18.0
			buzz.unit_size = 3.0
			buzz.max_distance = 18.0
			child.add_child(buzz)
			buzz.play()
			faulty_lamp_count = 1
			return


func set_weather_flash(level: float) -> void:
	if _puddle_material:
		_puddle_material.set_shader_parameter("weather_flash", level)


func _build_street_hardware() -> void:
	var iron := Color(0.10, 0.115, 0.12)
	# Continuous wet gutter trough along the Orison side of the street.
	_box([0.0, -14.76, 0.005], [124.0, 0.32, 0.018],
			Color(0.075, 0.085, 0.09))
	# Sidewalk sewer/utility grate by the entrance approach.
	_box([-5.3, -13.30, 0.018], [1.08, 0.72, 0.035], iron)
	_box([-5.3, -13.30, 0.039], [1.22, 0.07, 0.045],
			Color(0.22, 0.20, 0.17))
	for i in 8:
		_box([-5.73 + i * 0.125, -13.30, 0.045],
				[0.045, 0.60, 0.035], Color(0.025, 0.03, 0.03))
	# Storm drain in the gutter, with a curb inlet behind it.
	_box([7.2, -14.67, 0.025], [1.25, 0.40, 0.045], iron)
	_box([7.2, -14.565, 0.24], [1.30, 0.06, 0.42], iron)
	for i in 9:
		_box([6.70 + i * 0.125, -14.67, 0.052],
				[0.050, 0.34, 0.035], Color(0.025, 0.03, 0.03))
	# Manhole and paired service covers make the asphalt read at human scale.
	_cylinder([1.8, -16.10, 0.018], [0.72, 0.035, 0.72],
			Color(0.105, 0.115, 0.12))
	_cylinder([1.8, -16.10, 0.041], [0.51, 0.012, 0.51],
			Color(0.16, 0.15, 0.13))
	for x in [-20.5, 18.4]:
		_box([x, -12.20, 0.022], [0.62, 0.44, 0.035],
				Color(0.12, 0.125, 0.12))


func _build_damage(parent: Node3D) -> void:
	var specs := [
		[0, [-11.2, -12.2, 0.026], Vector2(2.1, 1.55), -12.0],
		[0, [10.9, -11.4, 0.026], Vector2(1.7, 1.4), 24.0],
		[0, [-2.0, -13.7, 0.026], Vector2(1.4, 1.0), 71.0],
		[1, [-8.0, -10.7, 0.027], Vector2(1.8, 1.25), 9.0],
		[1, [5.6, -12.7, 0.027], Vector2(1.5, 1.1), -35.0],
		[1, [13.0, -13.8, 0.027], Vector2(1.7, 1.2), 15.0],
		[2, [-13.25, -10.45, 0.028], Vector2(1.1, 1.9), 0.0],
		[2, [13.05, -10.42, 0.028], Vector2(1.0, 1.7), 4.0],
		[3, [-9.7, -16.0, 0.022], Vector2(2.5, 1.6), -18.0],
		[3, [12.6, -16.5, 0.022], Vector2(2.2, 1.5), 22.0],
		[3, [-24.0, -15.7, 0.022], Vector2(2.8, 1.4), 8.0],
	]
	for spec in specs:
		var decal := ExteriorGroundDecal.new()
		decal.setup(int(spec[0]), spec[2])
		decal.position = GameBoot.b2g(spec[1])
		decal.rotation_degrees = Vector3(-90, 0, float(spec[3]))
		parent.add_child(decal)
		decal_count += 1


func _build_puddles() -> void:
	var specs := [
		[-10.8, -14.55, 3.2, 0.68, 8.0],
		[-3.7, -14.62, 2.4, 0.55, -12.0],
		[4.8, -14.58, 3.6, 0.72, 4.0],
		[13.6, -14.61, 2.7, 0.61, -8.0],
		[-17.2, -16.5, 2.2, 0.82, 18.0],
		[9.4, -16.8, 1.8, 0.65, -21.0],
		[-7.0, -11.1, 1.45, 0.70, 31.0],
		[8.2, -12.3, 1.30, 0.58, -14.0],
	]
	for spec in specs:
		var basis := Basis(Vector3.UP, deg_to_rad(float(spec[4])))
		basis = basis.scaled(Vector3(float(spec[2]), 0.008, float(spec[3])))
		_puddles.append(Transform3D(
				basis, GameBoot.b2g([spec[0], spec[1], 0.030])))
		puddle_count += 1


func _build_city_silhouettes(floor: Dictionary) -> void:
	var buildings: Array = []
	for item in floor.furniture:
		var id: String = item.id
		if not id.begins_with("site_") or id.ends_with("_cap"):
			continue
		if float(item.get("h", 0.0)) < 8.0:
			continue
		if id.contains("ground") or id.contains("car"):
			continue
		buildings.append(item)
	for index in buildings.size():
		var item: Dictionary = buildings[index]
		var rect: Array = item.rect
		var x := (float(rect[0]) + float(rect[2])) * 0.5
		var y := (float(rect[1]) + float(rect[3])) * 0.5
		var width := float(rect[2]) - float(rect[0])
		var h := float(item.h)
		var tone: Color = [
			Color(0.18, 0.12, 0.095), Color(0.13, 0.15, 0.16),
			Color(0.20, 0.16, 0.11), Color(0.12, 0.105, 0.10)
		][index % 4]
		# Uneven rooftop bulkhead and mechanical cluster break box silhouettes.
		_box([x + width * 0.16, y, h + 0.55],
				[minf(width * 0.28, 3.4), 2.0, 1.1], tone)
		_cylinder([x - width * 0.18, y, h + 0.62],
				[0.17, 1.25, 0.17], Color(0.15, 0.16, 0.16))
		if index % 2 == 0:
			_cylinder([x - width * 0.25, y, h + 1.55],
					[0.035, 2.4, 0.035], Color(0.10, 0.11, 0.12))
			_box([x - width * 0.25, y, h + 2.52],
					[0.72, 0.06, 0.06], Color(0.10, 0.11, 0.12))
		# A narrow facade band varies age/color without covering brick texture.
		var street_y := float(rect[1]) - 0.035
		_box([x, street_y, h * 0.63], [width * 0.72, 0.055, 0.16],
				tone.lightened(0.10))


func _build_car_details(floor: Dictionary) -> void:
	for item in floor.furniture:
		var id: String = item.id
		var car := (id.begins_with("site_car") and not id.contains("top")
				and not id.contains("glass"))
		var south_car := (id.begins_with("site_scar")
				and not id.contains("top"))
		if not car and not south_car:
			continue
		var rect: Array = item.rect
		var x0 := float(rect[0])
		var x1 := float(rect[2])
		var y0 := float(rect[1])
		var y1 := float(rect[3])
		var cy := (y0 + y1) * 0.5
		var wheel_color := Color(0.035, 0.038, 0.04)
		for wx in [x0 + 0.78, x1 - 0.78]:
			for wy in [y0 - 0.025, y1 + 0.025]:
				_cylinder_rot([wx, wy, 0.39], [0.29, 0.12, 0.29],
						wheel_color, Basis(Vector3.RIGHT, PI * 0.5))
		# Bumpers, plate recesses and small lamps sell scale at almost no cost.
		for ex in [x0 - 0.025, x1 + 0.025]:
			_box([ex, cy, 0.34], [0.06, (y1 - y0) * 0.80, 0.12],
					Color(0.22, 0.23, 0.23))
		_box([x0 - 0.036, cy, 0.57], [0.025, 0.44, 0.17],
				Color(0.70, 0.10, 0.055))
		_box([x1 + 0.036, cy, 0.57], [0.025, 0.44, 0.17],
				Color(0.78, 0.70, 0.46))
		_box([x0 + 1.10, cy, 1.49], [0.035, y1 - y0 + 0.02, 0.045],
				Color(0.06, 0.07, 0.075))


func _box(position_b: Array, size_b: Array, color: Color) -> void:
	_boxes.append({
		"transform": Transform3D(
			Basis.IDENTITY.scaled(Vector3(size_b[0], size_b[2], size_b[1])),
			GameBoot.b2g(position_b)),
		"color": color,
	})
	detail_count += 1


func _cylinder(position_b: Array, size_b: Array, color: Color) -> void:
	_cylinder_rot(position_b, size_b, color, Basis.IDENTITY)


func _cylinder_rot(position_b: Array, size_b: Array, color: Color,
		rotation: Basis) -> void:
	_cylinders.append({
		"transform": Transform3D(
			rotation.scaled(Vector3(
					size_b[0] * 2.0, size_b[1], size_b[2] * 2.0)),
			GameBoot.b2g(position_b)),
		"color": color,
	})
	detail_count += 1


func _emit_boxes(parent: Node3D) -> void:
	var mesh := BoxMesh.new()
	_emit_colored_batch(parent, _boxes, mesh, 0.62)


func _emit_cylinders(parent: Node3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	_emit_colored_batch(parent, _cylinders, mesh, 0.54)


func _emit_colored_batch(parent: Node3D, entries: Array,
		mesh: PrimitiveMesh, roughness: float) -> void:
	if entries.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = roughness
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = entries.size()
	for index in entries.size():
		multimesh.set_instance_transform(index, entries[index].transform)
		multimesh.set_instance_color(index, entries[index].color)
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = multimesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(visual)


func _emit_puddles(parent: Node3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	_puddle_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_prepass_alpha;
uniform float weather_flash = 0.0;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float edge = smoothstep(0.51, 0.39, length(p));
	float ripple = sin(length(p) * 92.0 - TIME * 5.0) * 0.5 + 0.5;
	float rain = pow(ripple, 11.0) * 0.12;
	ALBEDO = vec3(0.025, 0.038, 0.052) + rain * vec3(0.10, 0.14, 0.18);
	METALLIC = 0.38;
	ROUGHNESS = 0.08 + rain * 0.18;
	SPECULAR = 0.90;
	EMISSION = vec3(0.035, 0.055, 0.085) * (0.15 + weather_flash * 2.4);
	ALPHA = edge * 0.76;
}
"""
	_puddle_material.shader = shader
	mesh.material = _puddle_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = _puddles.size()
	for index in _puddles.size():
		multimesh.set_instance_transform(index, _puddles[index])
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = multimesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
