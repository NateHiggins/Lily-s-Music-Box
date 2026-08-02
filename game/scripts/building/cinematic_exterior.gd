class_name CinematicExterior
extends Node3D
## Exterior-scale illusion pass for the Orison street elevation.
## Compatibility renderer friendly: dark occlusion cards, one colored
## MultiMesh, and a few unshaded shader cards. No real rooms, dynamic lights,
## physics or shadow casters are added.

var fake_detail_count := 0
var animated_card_count := 0
var _dark_entries: Array = []
var _color_entries: Array = []
var _window_dark_entries: Array = []
var _window_color_entries: Array = []


func build(layout: Dictionary) -> Dictionary:
	name = "CinematicExterior"
	_build_orison_window_depth(layout)
	_build_orison_hero_relief()
	_build_industrial_horizon()
	_build_moving_city_light()
	_emit_batch(_dark_entries, Color(0.018, 0.022, 0.026), 0.92)
	_emit_colored_batch(_color_entries)
	_emit_window_batch(_window_dark_entries, false)
	_emit_window_batch(_window_color_entries, true)
	print("[EXTERIOR CINEMA] %d fake details, %d animated cards, 0 lights"
			% [fake_detail_count, animated_card_count])
	return {"fake_details": fake_detail_count,
			"animated_cards": animated_card_count, "lights": 0}


func _build_orison_window_depth(layout: Dictionary) -> void:
	# The real interior is never rendered as exterior set dressing. A black
	# back card, two curtain edges and one furniture silhouette make each
	# street window appear to contain a room several metres deep.
	for floor_data in layout.get("floors", []):
		var floor_z := float(floor_data.get("z", 0.0))
		if floor_z < 0.0 or floor_z > 16.1:
			continue
		for wall in floor_data.get("walls", []):
			var a: Array = wall.a
			var b: Array = wall.b
			# Street facade only: horizontal wall at plan y ~= -10.
			if absf(float(a[1]) + 10.0) > 0.35 \
					or absf(float(b[1]) + 10.0) > 0.35:
				continue
			var wall_length := absf(float(b[0]) - float(a[0]))
			var start_x := minf(float(a[0]), float(b[0]))
			for opening in wall.get("openings", []):
				if str(opening.get("type", "")) != "window":
					continue
				var width := float(opening.get("w", 1.2))
				var height := float(opening.get("h", 1.15))
				var sill := float(opening.get("sill", 1.05))
				var at := float(opening.get("at", wall_length * 0.5))
				var x := start_x + at
				var z := floor_z + sill + height * 0.5
				# Rear darkness, inset enough to create parallax at sidewalk range.
				_window_quad([x, -9.77, z], [width * 0.88, height * 0.86],
						Color(0.012, 0.016, 0.020), false)
				# Curtains vary deterministically by window position. The gap is the
				# only bright part, so the existing window glow reads as room depth.
				var seed := absi(int(x * 91.0 + floor_z * 37.0))
				var curtain := 0.12 + float(seed % 5) * 0.035
				var cloth: Color = [Color(0.12, 0.075, 0.055),
						Color(0.055, 0.085, 0.095), Color(0.11, 0.10, 0.075),
						Color(0.075, 0.055, 0.085)][seed % 4]
				_window_quad([x - width * 0.38, -9.79, z],
						[curtain, height * 0.82], cloth, true)
				_window_quad([x + width * 0.38, -9.79, z],
						[curtain, height * 0.82], cloth.darkened(0.12), true)
				# One low silhouette suggests a chair, plant or stack of boxes.
				var object_w := 0.18 + float(seed % 4) * 0.055
				var object_h := 0.17 + float(int(seed / 3) % 4) * 0.07
				var offset := -0.18 if seed % 2 == 0 else 0.16
				_window_quad([x + offset, -9.805,
						floor_z + sill + object_h * 0.5],
						[object_w, object_h], Color(0.012, 0.016, 0.020), false)


func _build_orison_hero_relief() -> void:
	# Large verticals read from down the block; shallow pieces are enough
	# because the night does the rest. These frame the Orison as a distinct,
	# older object among flatter neighboring facades.
	var stone := Color(0.15, 0.125, 0.105)
	for x in [-13.45, -7.15, 7.15, 13.45]:
		_color_box([x, -10.17, 10.0], [0.22, 0.18, 19.7], stone)
	for z in [3.08, 6.28, 9.48, 12.68, 15.88, 19.12]:
		_color_box([0.0, -10.16, z], [26.8, 0.17, 0.13],
				stone.lightened(0.04 if int(z) % 2 else 0.0))
	# Deep entry brow and glowing address slit: one architectural gesture
	# visible from either end of the street.
	_color_box([0.0, -10.62, 3.12], [5.4, 1.05, 0.22], Color(0.055, 0.06, 0.062))
	_color_box([0.0, -11.05, 2.93], [3.6, 0.12, 0.055], Color(0.68, 0.39, 0.13))
	# Rooftop plant silhouettes turn the roofline into a machine without
	# constructing machinery the player can approach.
	for spec in [[-8.2, 2.2, 1.4], [-4.7, 3.0, 2.0], [5.9, 2.5, 1.7], [9.0, 1.6, 2.5]]:
		_dark_box([spec[0], 0.2, 19.2 + spec[2] * 0.5],
				[spec[1], 2.0, spec[2]])
		_dark_box([spec[0] + 0.35, 0.0, 19.2 + spec[2] + 1.0],
				[0.08, 0.08, 2.0])


func _build_industrial_horizon() -> void:
	# Emissive stacks are flat cards placed among existing far skyline boxes.
	# From street level they imply heavy infrastructure; from the roof they
	# remain below the authored sky horizon.
	for spec in [
		[-54.0, 35.0, 20.0, 0.0], [48.0, 42.0, 27.0, 1.7],
		[-31.0, 58.0, 31.0, 3.4], [67.0, 18.0, 18.0, 5.1],
	]:
		var card := MeshInstance3D.new()
		card.name = "IndustrialPulse"
		var quad := QuadMesh.new()
		quad.size = Vector2(7.0, 12.0)
		card.mesh = quad
		card.position = GameBoot.b2g([spec[0], spec[1], spec[2]])
		card.material_override = _pulse_material(float(spec[3]))
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(card)
		animated_card_count += 1


func _build_moving_city_light() -> void:
	# Long, low cards under the street wall. The paired glints remain fixed:
	# traffic is gridlocked for the whole shift, an unmoving urban pressure
	# beyond the playable block with no vehicles or script work.
	for spec in [[0.0, -46.0, 0.32, 0.0], [-22.0, 29.0, 0.38, 4.2]]:
		var card := MeshInstance3D.new()
		card.name = "GridlockedTrafficRibbon"
		var quad := QuadMesh.new(); quad.size = Vector2(44.0, 0.65)
		card.mesh = quad
		card.position = GameBoot.b2g([spec[0], spec[1], spec[2]])
		card.material_override = _traffic_material(float(spec[3]))
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(card)
		animated_card_count += 1


func _pulse_material(phase: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new(); var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float phase = 0.0;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float stack = smoothstep(0.12, 0.09, abs(p.x)) * smoothstep(0.5, 0.16, p.y + 0.5);
	float horizon = smoothstep(0.50, 0.45, abs(p.y + 0.35));
	float pulse = pow(max(0.0, sin(TIME * 0.22 + phase)), 18.0);
	vec3 sodium = vec3(1.0, 0.25, 0.045);
	ALBEDO = sodium;
	EMISSION = sodium * (stack * 0.04 + horizon * pulse * 1.8);
	ALPHA = clamp(stack * 0.10 + horizon * pulse * 0.62, 0.0, 0.72);
}
"""
	mat.shader = shader; mat.set_shader_parameter("phase", phase)
	return mat


func _traffic_material(phase: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new(); var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float phase = 0.0;
void fragment() {
	float x = fract(UV.x - phase);
	float head = smoothstep(0.020, 0.0, abs(x - 0.50));
	float tail = smoothstep(0.014, 0.0, abs(x - 0.54));
	float lane = smoothstep(0.42, 0.08, abs(UV.y - 0.5));
	vec3 c = head * vec3(0.65, 0.80, 1.0) + tail * vec3(1.0, 0.08, 0.025);
	EMISSION = c * lane * 1.7;
	ALBEDO = c;
	ALPHA = clamp((head + tail) * lane * 0.62, 0.0, 0.7);
}
"""
	mat.shader = shader; mat.set_shader_parameter("phase", phase)
	return mat


func _dark_box(pos_b: Array, size_b: Array) -> void:
	_dark_entries.append(_transform(pos_b, size_b)); fake_detail_count += 1


func _color_box(pos_b: Array, size_b: Array, color: Color) -> void:
	_color_entries.append({"transform": _transform(pos_b, size_b), "color": color})
	fake_detail_count += 1


func _window_quad(pos_b: Array, size_b: Array, color: Color,
		colored: bool) -> void:
	var entry := {"transform": Transform3D(
			Basis.IDENTITY.scaled(Vector3(size_b[0], size_b[1], 1.0)),
			GameBoot.b2g(pos_b)), "color": color}
	(_window_color_entries if colored else _window_dark_entries).append(entry)
	fake_detail_count += 1


func _transform(pos_b: Array, size_b: Array) -> Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(Vector3(size_b[0], size_b[2], size_b[1])),
			GameBoot.b2g(pos_b))


func _emit_batch(entries: Array, color: Color, roughness: float) -> void:
	if entries.is_empty(): return
	var mesh := BoxMesh.new(); var mat := StandardMaterial3D.new()
	mat.albedo_color = color; mat.roughness = roughness; mesh.material = mat
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh; mm.instance_count = entries.size()
	for i in entries.size(): mm.set_instance_transform(i, entries[i])
	var visual := MultiMeshInstance3D.new(); visual.multimesh = mm
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)


func _emit_colored_batch(entries: Array) -> void:
	if entries.is_empty(): return
	var mesh := BoxMesh.new(); var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE; mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.68; mesh.material = mat
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true; mm.mesh = mesh; mm.instance_count = entries.size()
	for i in entries.size():
		mm.set_instance_transform(i, entries[i].transform)
		mm.set_instance_color(i, entries[i].color)
	var visual := MultiMeshInstance3D.new(); visual.multimesh = mm
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)


func _emit_window_batch(entries: Array, colored: bool) -> void:
	if entries.is_empty(): return
	var mesh := QuadMesh.new(); mesh.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE if colored else Color(0.012, 0.016, 0.020)
	mat.vertex_color_use_as_albedo = colored
	# Default QuadMesh winding faces local +Z: outward toward the south
	# sidewalk after GameBoot conversion. Back faces vanish from apartments.
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mesh.material = mat
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colored; mm.mesh = mesh; mm.instance_count = entries.size()
	for i in entries.size():
		mm.set_instance_transform(i, entries[i].transform)
		if colored: mm.set_instance_color(i, entries[i].color)
	var visual := MultiMeshInstance3D.new(); visual.multimesh = mm
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
