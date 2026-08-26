class_name ExteriorDetailPass
extends Node3D
## Cheap exterior finish pass layered over the generator's broad site pass.
## Everything except the damage cards is held in three shared MultiMeshes.

var detail_count := 0
var decal_count := 0
var puddle_count := 0
var faulty_lamp_count := 0
var boundary_count := 0
## Collision at the street ends is acceptable only when a visible architectural
## or weather span owns the same opening.  Kept as records so tests can compare
## the physical partition with the authored explanation after batching.
var boundary_visible_spans: Array = []

var _boxes: Array = []
var _city_masses: Array = []
var _city_facades: Array = []
var _cylinders: Array = []
var _puddles: Array = []
var _puddle_material: ShaderMaterial
var _storm_materials: Array[ShaderMaterial] = []
var _city_facade_material: ShaderMaterial
var _city_mass_material: ShaderMaterial

const STREET_END_PROBE_LAYER := 1 << 20


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
	_build_transit_shelter_sign(parent)
	_build_damage(parent)
	_build_puddles()
	_build_city_silhouettes(floor)
	# NO PARKED CARS (2026-08-11). Both passes are retained below and both are
	# unused: _build_car_details() decorated the kerbside rows the generator no
	# longer emits, and _build_arrival_rideshare() parked the hero car the
	# player arrived in, plus a 4.7 m collision box called
	# ArrivalRideshareCollision that a street-wide probe found as one of two
	# things stopping the player with nothing visible attached to it.
	#
	# The carriageway is becoming the thing you cross rather than scenery beside
	# it, and a parked car fights that on every axis: it hides oncoming traffic
	# from a player judging a gap, it costs submissions on the worst station in
	# the game, and a street full of switched-off vehicles reads as a diorama
	# whatever drives through it.
	#
	# The arrival car should come back MOVING - you get out, it pulls away into
	# the east tear - which is a better first minute than finding it parked
	# forever outside the door. See design/ORISON_STREET_BRIEF.md.
	_build_street_ends(parent)
	_emit_boxes(parent)
	# Unlike street hardware, neighbour scenery must survive F01 storey
	# streaming when the eye is on the roof. The pass itself is root-owned.
	var persistent_parent := get_parent() as Node3D
	_emit_city_masses(persistent_parent)
	_emit_city_facades(persistent_parent)
	_emit_cylinders(parent)
	_emit_puddles(parent)
	print("[BUILDING] exterior finish: %d batched details, %d decals, %d puddles"
			% [detail_count, decal_count, puddle_count])
	return {"details": detail_count, "decals": decal_count,
			"puddles": puddle_count}


func configure_street_lights(world: Node) -> void:
	# Every sodium head has old wiring and stained glass. Most only flutter;
	# one west of the entrance drops out long enough for moonlight to take over.
	for child in world.get_children():
		if child is LightFixtureProp \
				and child.name == "F01_ENTRY_SCONCE":
			child.set_weathered_exterior(true)
			child.set_entry_emphasis(1.42)
		elif child is LightFixtureProp \
				and child.prop_type == "street_lamp":
			child.set_weathered_exterior(true)
			child.set_exterior_composition_gain(0.52)
			if child.name != "F01_STREETLAMP_04":
				continue
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
	_build_composition_lights(world)


func set_weather_flash(level: float) -> void:
	if _puddle_material:
		_puddle_material.set_shader_parameter("weather_flash", level)
	for material in _storm_materials:
		material.set_shader_parameter("weather_flash", level)


func set_weather_profile(mist_color: Color) -> void:
	for material in _storm_materials:
		material.set_shader_parameter("storm_color", mist_color)


func set_neighbour_occupancy_gain(gain: float) -> void:
	for material in [_city_mass_material, _city_facade_material]:
		if material:
			material.set_shader_parameter(
					"occupancy_gain", clampf(gain, 0.0, 1.0))


func set_neighbour_light_profile(gain: float, direction: Vector3) -> void:
	for material in [_city_mass_material, _city_facade_material]:
		if material:
			material.set_shader_parameter("facade_light_gain",
					clampf(gain, 0.65, 4.5))
			material.set_shader_parameter("facade_light_direction", direction)


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


func _build_transit_shelter_sign(parent: Node3D) -> void:
	# The shelter must announce an actual service after dark without spending a
	# realtime light. A small enamel board joins the existing exterior box
	# batch; one physical Label3D supplies the period streetcar instruction.
	# "CARS STOP HERE" is deliberately infrastructure language, not modern
	# pictographic wayfinding and not a glowing advertisement.
	_box([-10.4, -25.50, 2.34], [1.28, 0.055, 0.34],
			Color(0.055, 0.105, 0.095))
	var label := Label3D.new()
	label.name = "TransitShelterStopSign"
	label.text = "CARS STOP HERE"
	label.font_size = 30
	label.pixel_size = 0.00145
	label.modulate = Color(0.91, 0.84, 0.62)
	label.outline_size = 4
	label.outline_modulate = Color(0.018, 0.030, 0.026, 0.96)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.no_depth_test = false
	label.position = GameBoot.b2g([-10.4, -25.465, 2.34])
	label.rotation_degrees.y = 180.0
	label.add_to_group("transit_shelter_architecture")
	parent.add_child(label)


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
	var envelope_tops := {}
	for item in floor.furniture:
		var id: String = item.id
		if not id.begins_with("site_") or id.ends_with("_cap"):
			continue
		var is_mass_segment := id.ends_with("_base0") \
				or id.ends_with("_s0") or id.ends_with("_s1")
		if float(item.get("h", 0.0)) < 8.0 and not is_mass_segment:
			continue
		if id.contains("ground") or id.contains("car"):
			continue
		buildings.append(item)
		if is_mass_segment:
			var envelope_id := id.trim_suffix("_base0").trim_suffix("_s0") \
					.trim_suffix("_s1")
			var top := float(item.get("z0", 0.0)) + float(item.h)
			if not envelope_tops.has(envelope_id) \
					or top > float(envelope_tops[envelope_id].top):
				envelope_tops[envelope_id] = {"item": item, "top": top}
	for index in buildings.size():
		var item: Dictionary = buildings[index]
		var id: String = item.id
		var rect: Array = item.rect
		var x := (float(rect[0]) + float(rect[2])) * 0.5
		var y := (float(rect[1]) + float(rect[3])) * 0.5
		var width := float(rect[2]) - float(rect[0])
		var h := float(item.h)
		var tone: Color = [
			Color(0.18, 0.12, 0.095), Color(0.13, 0.15, 0.16),
			Color(0.20, 0.16, 0.11), Color(0.12, 0.105, 0.10)
		][index % 4]
		# The imported neighbour envelopes live in F01 and correctly disappear
		# with that storey's interiors. Their windows are root-owned, though,
		# which left floating luminous cards from roof viewpoints. Rebuild only
		# each authored base envelope here; interiors remain streamed out.
		if id.ends_with("_base0") or id.ends_with("_s0") \
				or id.ends_with("_s1"):
			var depth := float(rect[3]) - float(rect[1])
			var z0 := float(item.get("z0", 0.0))
			_city_masses.append({
				"transform": Transform3D(Basis.IDENTITY.scaled(
						Vector3(width, h, depth)),
						GameBoot.b2g([x, y, z0 + h * 0.5])),
				"color": tone.lightened(0.08),
			})
			var horizontal_face := absf(x) <= absf(y)
			var face_width := width if horizontal_face else depth
			# Stand the finish 6 mm proud of the envelope toward the Orison.
			# Coplanar quads survived some angles and vanished at others, which is
			# exactly the partial-rendering defect visible in the roof captures. The
			# authored window panes stand another 8 mm proud of this finish.
			var face_x := x if horizontal_face else (float(rect[0]) - 0.006 \
					if x > 0.0 else float(rect[2]) + 0.006)
			var face_y := (float(rect[1]) - 0.006 \
					if y > 0.0 else float(rect[3]) + 0.006) \
					if horizontal_face else y
			var angle := 0.0 if horizontal_face else PI * 0.5
			var basis := Basis(Vector3.UP, angle) \
					* Basis.from_scale(Vector3(face_width, h, 1.0))
			_city_facades.append({
				"transform": Transform3D(basis,
						GameBoot.b2g([face_x, face_y, z0 + h * 0.5])),
				"color": tone.lightened(0.18),
			})
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
	# Roof furniture is skyline information, so it shares the persistent owner.
	# One irregular stair bulkhead per authored envelope breaks the procedural
	# parapets without adding a node or draw call per building.
	for envelope_id in envelope_tops:
		var record: Dictionary = envelope_tops[envelope_id]
		var item: Dictionary = record.item
		var rect: Array = item.rect
		var x := (float(rect[0]) + float(rect[2])) * 0.5
		var y := (float(rect[1]) + float(rect[3])) * 0.5
		var width := float(rect[2]) - float(rect[0])
		var depth := float(rect[3]) - float(rect[1])
		var top := float(record.top)
		var seed := absi(hash(envelope_id))
		var bulk_w := minf(width * (0.14 + float(seed % 7) * 0.012), 3.8)
		var bulk_d := minf(depth * 0.20, 2.6)
		var bulk_h := 0.75 + float(seed % 5) * 0.16
		var offset := (float((seed / 7) % 9) / 8.0 - 0.5) * width * 0.36
		_city_masses.append({
			"transform": Transform3D(Basis.IDENTITY.scaled(
					Vector3(bulk_w, bulk_h, bulk_d)),
					GameBoot.b2g([x + offset, y, top + bulk_h * 0.5])),
			"color": Color(0.08, 0.055, 0.043),
		})
		detail_count += 1
func _build_car_details(floor: Dictionary) -> void:
	var car_index := 0
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
		_build_car_identity(car_index, x0, x1, y0, y1)
		car_index += 1


## The curbside car is the player's last contact with ordinary Queens. Its
## teal roof lozenge and phone-blue dash glow read as rideshare language
## without borrowing a real-world trademark. It never moves after arrival.
func _build_arrival_rideshare(parent: Node3D) -> void:
	var body_color := Color(0.028, 0.040, 0.052)
	var glass := Color(0.018, 0.030, 0.040)
	# Parked WEST of the crossing. At x 3.35 this car sat squarely
	# across the only legal way over the road, and a 4.7 m collision box
	# is not something a player walks around when they cannot see why.
	var cx := -6.40
	var cy := -15.92
	_box([cx, cy, 0.52], [4.72, 1.82, 0.68], body_color)
	_box([cx - 0.22, cy, 1.07], [2.42, 1.66, 0.54], body_color.lightened(0.025))
	_box([cx - 0.24, cy - 0.845, 1.12], [1.72, 0.025, 0.30], glass)
	_box([cx - 0.24, cy + 0.845, 1.12], [1.72, 0.025, 0.30], glass)
	# Motionless wheels, curb-facing brake lamps and a tiny roof identifier.
	for wx in [cx - 1.45, cx + 1.45]:
		for wy in [cy - 0.91, cy + 0.91]:
			_cylinder_rot([wx, wy, 0.36], [0.30, 0.12, 0.30],
					Color(0.022, 0.024, 0.027), Basis(Vector3.RIGHT, PI * 0.5))
	_box([cx - 2.38, cy, 0.60], [0.035, 1.30, 0.18], Color(0.42, 0.025, 0.018))
	_box([cx, cy, 1.39], [0.48, 0.22, 0.10], Color(0.04, 0.40, 0.43))
	_box([cx + 0.48, cy - 0.858, 0.90], [0.18, 0.018, 0.08], Color(0.05, 0.28, 0.38))
	# Give the hero car physical presence even though its finish is batched.
	var car_body := StaticBody3D.new()
	car_body.name = "ArrivalRideshareCollision"
	parent.add_child(car_body)
	_add_boundary_shape(car_body, "ArrivalRideshareHull",
			[cx, cy, 0.62], [4.74, 1.84, 1.24], "arrival_rideshare")


## A handful of dark profile cues makes the cheap site blocks read as actual
## remembered cars. No interiors, badges or high-poly panels are required;
## the player recognizes roofline, greenhouse, hood/trunk ratio and stance.
func _build_car_identity(index: int, x0: float, x1: float,
		y0: float, y1: float) -> void:
	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5
	var length := x1 - x0
	var width := y1 - y0
	var ink: Color = [Color(0.045, 0.052, 0.058), Color(0.065, 0.048, 0.042),
			Color(0.035, 0.047, 0.044), Color(0.075, 0.066, 0.047),
			Color(0.038, 0.038, 0.043), Color(0.052, 0.047, 0.062),
			Color(0.055, 0.058, 0.052)][index % 7]
	match index:
		0: # Volvo 240 wagon — upright full-length greenhouse and roof rack.
			_box([cx + 0.15, cy, 1.18], [length * 0.62, width * 0.86, 0.42], ink)
			for rail_y in [y0 + 0.18, y1 - 0.18]:
				_box([cx + 0.10, rail_y, 1.48], [length * 0.52, 0.025, 0.035], Color(0.12, 0.13, 0.13))
			_box([x0 + 0.18, cy, 0.78], [0.10, width * 0.76, 0.34], Color(0.25, 0.05, 0.035))
		1: # 1985 Lincoln Town Car — long formal hood, opera window, hood ornament.
			_box([cx - 0.10, cy, 1.20], [length * 0.43, width * 0.88, 0.38], ink)
			_box([x1 - 0.68, cy, 0.88], [length * 0.26, width * 0.94, 0.10], ink.lightened(0.04))
			_cylinder([x1 - 0.26, cy, 1.02], [0.012, 0.12, 0.012], Color(0.28, 0.25, 0.18))
			_box([cx - 0.70, y0 - 0.02, 1.22], [0.16, 0.03, 0.14], Color(0.015, 0.02, 0.022))
		2: # 1980 Chevrolet Caprice — square sedan, broad nose, quad lamps.
			_box([cx - 0.05, cy, 1.13], [length * 0.42, width * 0.90, 0.34], ink)
			for lamp_y in [cy - 0.38, cy - 0.13, cy + 0.13, cy + 0.38]:
				_box([x1 + 0.038, lamp_y, 0.61], [0.022, 0.12, 0.09], Color(0.30, 0.29, 0.20))
			_box([x0 + 0.22, cy, 0.92], [0.18, width * 0.88, 0.08], ink)
		3: # Checker Marathon — tall taxi canopy and slab-sided passenger cell.
			_box([cx, cy, 1.24], [length * 0.50, width * 0.91, 0.48], ink)
			_box([cx, cy, 1.54], [0.28, 0.16, 0.10], Color(0.24, 0.20, 0.08))
			_box([cx, y0 - 0.018, 0.92], [length * 0.46, 0.025, 0.035], Color(0.18, 0.16, 0.08))
		4: # Buick Grand National — low black coupe, long hood and rear spoiler.
			_box([cx - 0.26, cy, 1.04], [length * 0.37, width * 0.91, 0.25], ink)
			_box([x0 + 0.28, cy, 1.04], [0.07, width * 0.96, 0.055], Color(0.025, 0.025, 0.028))
			_box([x1 - 0.62, cy, 0.83], [length * 0.28, width * 0.94, 0.075], ink)
		5: # Ford Crown Victoria — cab/police silhouette and A-pillar spotlight.
			_box([cx - 0.04, cy, 1.17], [length * 0.44, width * 0.89, 0.36], ink)
			_cylinder([cx + 0.45, y0 - 0.08, 1.20], [0.045, 0.08, 0.045], Color(0.13, 0.13, 0.12))
			_box([x1 - 0.40, cy, 0.86], [0.42, width * 0.92, 0.06], ink)
		6: # First-generation Dodge Caravan — one-box roof and blunt tailgate.
			_box([cx, cy, 1.28], [length * 0.66, width * 0.92, 0.58], ink)
			_box([x0 + 0.14, cy, 1.03], [0.10, width * 0.88, 0.62], ink.darkened(0.08))
			_box([cx + 0.15, y0 - 0.018, 1.37], [length * 0.46, 0.025, 0.06], Color(0.018, 0.025, 0.027))
		7: # Saab 900 — long curved-hatch impression and cab-forward screen.
			_box([cx - 0.18, cy, 1.14], [length * 0.48, width * 0.88, 0.33], ink)
			_box([x0 + 0.66, cy, 1.06], [length * 0.22, width * 0.91, 0.23], ink.darkened(0.05))
			_box([x1 - 0.52, cy, 0.88], [0.62, width * 0.92, 0.09], ink)
		8: # Mercedes-Benz W123 — formal greenhouse, upright grille, taxi durability.
			_box([cx - 0.08, cy, 1.17], [length * 0.43, width * 0.87, 0.36], ink)
			_box([x1 + 0.032, cy, 0.70], [0.024, width * 0.46, 0.30], Color(0.18, 0.18, 0.16))
			_cylinder([x1 - 0.19, cy, 1.00], [0.010, 0.10, 0.010], Color(0.30, 0.27, 0.17))
		9: # Cadillac Fleetwood Brougham — vinyl roof, immense deck, sharp lamps.
			_box([cx - 0.20, cy, 1.20], [length * 0.39, width * 0.90, 0.39], Color(0.025, 0.028, 0.030))
			_box([x0 + 0.52, cy, 0.86], [length * 0.28, width * 0.95, 0.10], ink)
			for lamp_y in [y0 + 0.20, y1 - 0.20]:
				_box([x0 - 0.03, lamp_y, 0.63], [0.025, 0.18, 0.22], Color(0.30, 0.035, 0.025))
		10: # Volkswagen Rabbit — short upright hatch, wheels at the corners.
			_box([cx - 0.18, cy, 1.12], [length * 0.36, width * 0.86, 0.38], ink)
			_box([x0 + 0.18, cy, 0.95], [0.12, width * 0.88, 0.36], ink.darkened(0.08))
			_box([x1 - 0.30, cy, 0.78], [length * 0.18, width * 0.90, 0.07], ink)
		11: # Jeep Cherokee XJ — ruler-straight utility roof and vertical tail.
			_box([cx, cy, 1.33], [length * 0.64, width * 0.91, 0.62], ink)
			_box([x0 + 0.14, cy, 1.10], [0.10, width * 0.89, 0.72], ink.darkened(0.10))
			for rail_y in [y0 + 0.16, y1 - 0.16]:
				_box([cx, rail_y, 1.68], [length * 0.50, 0.025, 0.035], Color(0.10, 0.11, 0.11))
		12: # Ford Econoline — blunt dark van, shallow windshield, rear ladder.
			_box([cx - 0.02, cy, 1.43], [length * 0.72, width * 0.94, 0.82], ink)
			_box([x1 - 0.62, y0 - 0.018, 1.47], [0.72, 0.025, 0.30], Color(0.016, 0.022, 0.024))
			for rung in [0.82, 1.04, 1.26, 1.48]:
				_box([x0 - 0.035, y1 - 0.21, rung], [0.025, 0.30, 0.025], Color(0.12, 0.12, 0.11))
		13: # Oldsmobile Custom Cruiser — huge wagon with faux-wood belt shadow.
			_box([cx + 0.08, cy, 1.19], [length * 0.64, width * 0.90, 0.43], ink)
			_box([cx, y0 - 0.022, 0.91], [length * 0.72, 0.030, 0.16], Color(0.12, 0.065, 0.030))
			_box([x0 + 0.16, cy, 0.86], [0.10, width * 0.88, 0.36], ink.darkened(0.08))


## The playable exterior ends in construction fabric on both pavements and a
## dense storm mouth over the carriageway.  This is the quiet common substrate
## of either future ruling in ORISON_STREET_BRIEF: it does not decide whether a
## tear is loud, emits debris, stops at night or admits anything but traffic.
## It does make every centimetre of collision visible and closes Check 1's
## south-pavement leak without extending another unexplained wall.
func _build_street_ends(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "StreetEndWeatherBoundary"
	# Layer 1 is normal player collision.  The extra diagnostic bit lets the
	# deterministic containment sweep isolate this owner from traffic, kerbs and
	# neighbouring fabric without changing what a shipped player collides with.
	body.collision_layer = 1 | STREET_END_PROBE_LAYER
	body.add_to_group("street_end_boundary")
	body.set_meta("visible_owner", "construction_works_and_storm_curtain")
	parent.add_child(body)
	# Check 3 retained these two exact controls.  Phase 4 changes their owner,
	# not their position, so no approved spatial decision is reopened.
	const STAGE_E := 20.60
	const STAGE_W := -20.10
	const NORTH_WALK_C := -12.10
	const NORTH_WALK_D := 5.30      # y -9.45 .. -14.75
	const ROAD_C := -19.322
	const ROAD_D := 9.144           # y -14.75 .. -23.894
	const SOUTH_WALK_C := -26.105
	const SOUTH_WALK_D := 4.422     # y -23.894 .. -28.316

	for side in [["West", STAGE_W], ["East", STAGE_E]]:
		var label: String = side[0]
		var x: float = side[1]
		# Three physical spans, three visible owners.  The two pavement pieces
		# are construction hoarding; the live carriageway remains visually open
		# to traffic but terminates for the player in dense, localised weather.
		_add_boundary_shape(body, "%sNorthWorks" % label,
				[x, NORTH_WALK_C, 1.20], [0.36, NORTH_WALK_D, 2.40],
				"construction_hoarding")
		_add_boundary_shape(body, "%sStormCore" % label,
				[x, ROAD_C, 1.20], [0.36, ROAD_D, 2.40],
				"storm_curtain")
		_add_boundary_shape(body, "%sSouthWorks" % label,
				[x, SOUTH_WALK_C, 1.20], [0.36, SOUTH_WALK_D, 2.40],
				"construction_hoarding")

		for walk in [[NORTH_WALK_C, NORTH_WALK_D, "north"],
				[SOUTH_WALK_C, SOUTH_WALK_D, "south"]]:
			var centre: float = walk[0]
			var depth: float = walk[1]
			_box([x, centre, 1.20], [0.36, depth, 2.40],
					Color(0.20, 0.145, 0.075))
			# Pale, battered timber posts keep the plane readable in production
			# darkness. They are structure, not a painted warning stripe.
			for i in range(5):
				var along := centre - depth * 0.5 + 0.24 \
						+ (depth - 0.48) * float(i) / 4.0
				_box([x - signf(x) * 0.22, along, 1.30],
						[0.10, 0.12, 2.60], Color(0.68, 0.43, 0.15))
			boundary_visible_spans.append({"side": label.to_lower(),
					"part": walk[2], "owner": "construction_hoarding",
					"centre": centre, "depth": depth})

		# The road mouth is framed like temporary works, but not boarded over:
		# traffic can disappear into the weather instead of driving through a
		# literal fence.  The renderer pays three transparent local quads per end.
		for edge in [-14.75, -23.894]:
			_box([x, edge, 2.70], [0.40, 0.34, 5.40],
					Color(0.13, 0.115, 0.085))
		_box([x, ROAD_C, 5.25], [0.40, ROAD_D + 0.34, 0.32],
				Color(0.13, 0.115, 0.085))
		_build_street_end_weather(parent, x, label)
		boundary_visible_spans.append({"side": label.to_lower(),
				"part": "road", "owner": "storm_curtain",
				"centre": ROAD_C, "depth": ROAD_D})

	_build_street_end_hoarding_faces(parent)
	_build_street_end_marker_lamps(parent)
	boundary_count = body.get_child_count()


func _build_street_end_hoarding_faces(parent: Node3D) -> void:
	# A baked wet-board face lets the architecture read under canonical 03:00
	# ambient without spending a real light.  The subtle warm pool belongs to
	# the instanced oil beacon below; it is material response, not illumination.
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

float rect(vec2 uv, vec2 centre, vec2 half_size) {
	vec2 inside = 1.0 - step(half_size, abs(uv - centre));
	return inside.x * inside.y;
}

void fragment() {
	float boards = fract(UV.x * 11.0);
	float seam = smoothstep(0.88, 1.0, boards);
	float wet = 0.84 + 0.16 * sin(UV.y * 43.0 + floor(UV.x * 11.0));
	float beacon_pool = 1.0 - smoothstep(0.05, 0.72,
			distance(UV, vec2(0.5, 0.12)));
	vec3 timber = mix(vec3(0.055, 0.032, 0.016),
			vec3(0.18, 0.105, 0.038), wet);
	timber *= 0.66 + beacon_pool * 0.44;
	timber = mix(timber, vec3(0.025, 0.018, 0.012), seam * 0.78);
	float paper = max(rect(UV, vec2(0.32, 0.53), vec2(0.08, 0.12)),
			rect(UV, vec2(0.69, 0.60), vec2(0.07, 0.10)));
	vec3 old_paper = vec3(0.34, 0.27, 0.15) * (0.72 + beacon_pool * 0.28);
	ALBEDO = mix(timber, old_paper, paper);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	# Each collision board has a finished face on both sides.  The original
	# four inward faces read correctly from the playable block, but canonical
	# Vantry approach 02 sees the outward side of EastSouthWorks; there the raw
	# batched collision box became a five-metre black rectangle.  Eight quads
	# remain one draw and move no boundary.
	multimesh.instance_count = 8
	var faces := [[-20.10, -12.10, 5.30], [-20.10, -26.105, 4.422],
			[20.60, -12.10, 5.30], [20.60, -26.105, 4.422]]
	for i in faces.size():
		var row: Array = faces[i]
		var x: float = row[0]
		# Scale in the quad's LOCAL axes before rotating its width from Godot X
		# onto street depth. Basis.scaled() here scales world rows and produced a
		# one-metre bright strip down the middle of a still-black hoarding.
		var basis := Basis(Vector3.UP, PI * 0.5) \
				* Basis.from_scale(Vector3(float(row[2]), 2.38, 1.0))
		for side_index in 2:
			var face_side := -1.0 if side_index == 0 else 1.0
			var surface_x := x + signf(x) * 0.205 * face_side
			multimesh.set_instance_transform(i * 2 + side_index,
					Transform3D(basis,
						GameBoot.b2g([surface_x, float(row[1]), 1.20])))
	var instance := MultiMeshInstance3D.new()
	instance.name = "StreetEndHoardingFaces"
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_to_group("street_end_architecture")
	parent.add_child(instance)


func _build_street_end_marker_lamps(parent: Node3D) -> void:
	# Four glow-only work beacons, one draw and zero real fixtures. They label
	# the pavement works without casting another shadow map.
	# (2026-08-16: this said "zero entries in the 16/16 light budget". That
	# budget is gone on desktop — the cap is 128 and LightRig takes UNLIMITED.
	# The decision stands on its second clause, which was always the stronger
	# one: shadow casters are still scarce, and one draw still beats four.)
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 10
	sphere.rings = 5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.32, 0.055)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.20, 0.025)
	material.emission_energy_multiplier = 3.2
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = sphere
	multimesh.instance_count = 4
	var lamps := [[-20.10, -12.10, 2.34], [-20.10, -26.105, 2.34],
			[20.60, -12.10, 2.34], [20.60, -26.105, 2.34]]
	for i in lamps.size():
		multimesh.set_instance_transform(i,
				Transform3D(Basis.IDENTITY, GameBoot.b2g(lamps[i])))
	var instance := MultiMeshInstance3D.new()
	instance.name = "StreetEndWorkBeacons"
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_to_group("street_end_architecture")
	parent.add_child(instance)
	detail_count += lamps.size()


func _build_street_end_weather(parent: Node3D, x: float, label: String) -> void:
	var end := Node3D.new()
	end.name = "StreetEndWeather%s" % label
	end.add_to_group("street_end_weather")
	end.set_meta("collision_owner", "%sStormCore" % label)
	parent.add_child(end)
	var outward := -1.0 if x < 0.0 else 1.0
	for i in range(3):
		var curtain := MeshInstance3D.new()
		curtain.name = "StormCurtain_%s_%02d" % [label, i]
		var quad := QuadMesh.new()
		quad.size = Vector2(9.70, 7.80)
		curtain.mesh = quad
		curtain.position = GameBoot.b2g(
				[x + outward * float(i) * 0.32, -19.322, 3.85])
		curtain.rotation_degrees.y = 90.0
		curtain.material_override = _street_end_weather_material(
				(17.0 if label == "West" else 41.0) + float(i) * 9.0)
		curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		end.add_child(curtain)


func _street_end_weather_material(seed: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_prepass_alpha,
		shadows_disabled;
uniform float seed = 0.0;
uniform vec4 storm_color : source_color = vec4(0.06, 0.08, 0.12, 0.34);
uniform float weather_flash = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)),
				hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float mist = value_noise(vec2(uv.x * 4.2 + TIME * 0.055,
			uv.y * 2.6 + seed));
	float lane = floor(uv.x * 104.0);
	float chosen = step(0.58, hash(vec2(lane, seed)));
	float phase = fract(uv.y * 24.0 + TIME * 3.4
			+ hash(vec2(lane + seed, 9.0)));
	float rain = smoothstep(0.90, 1.0, phase) * chosen;
	float ground_mist = (1.0 - smoothstep(0.02, 0.72, uv.y))
			* value_noise(vec2(uv.x * 7.0 - TIME * 0.08, seed + 13.0));
	float edge = smoothstep(0.0, 0.07, uv.x)
			* smoothstep(0.0, 0.07, 1.0 - uv.x);
	vec3 cold = storm_color.rgb * 0.72;
	vec3 lift = storm_color.rgb * 2.15
			+ vec3(weather_flash * 0.16);
	ALBEDO = mix(cold, lift, clamp(mist * 0.72 + rain * 0.55, 0.0, 1.0));
	ALPHA = edge * clamp(storm_color.a * 0.38 + mist * 0.24 + rain * 0.23
			+ ground_mist * 0.22, 0.0, 0.68);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("seed", seed)
	_storm_materials.append(material)
	return material


func _add_boundary_shape(body: StaticBody3D, shape_name: String,
		pos_b: Array, size_b: Array, visible_owner: String) -> void:
	var collision := CollisionShape3D.new()
	collision.name = shape_name
	collision.set_meta("visible_owner", visible_owner)
	var shape := BoxShape3D.new()
	shape.size = Vector3(size_b[0], size_b[2], size_b[1])
	collision.shape = shape
	collision.position = GameBoot.b2g(pos_b)
	body.add_child(collision)


func _build_composition_lights(world: Node3D) -> void:
	var door_target := GameBoot.b2g([0.0, -9.84, 1.15])
	for spec in [[-6.8, -14.0, 1.45], [6.8, -14.0, 1.45]]:
		var light := SpotLight3D.new()
		light.name = "EntryCompositionRake"
		light.position = GameBoot.b2g(spec)
		light.light_color = Color(0.30, 0.37, 0.50)
		light.light_energy = 0.34
		light.spot_range = 10.5
		light.spot_angle = 29.0
		light.spot_attenuation = 1.9
		light.shadow_enabled = true
		light.shadow_bias = 0.016
		light.shadow_normal_bias = 0.10
		world.add_child(light)
		light.look_at(door_target, Vector3.UP)


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


func _emit_city_masses(parent: Node3D) -> void:
	if _city_masses.is_empty():
		return
	var mesh := BoxMesh.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform float facade_light_gain = 1.0;
uniform vec3 facade_light_direction = vec3(0.0, 1.0, 0.0);
uniform float occupancy_gain = 1.0;
varying vec3 world_position;
varying vec3 world_normal;
varying flat vec4 instance_tint;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	instance_tint = COLOR;
}
void fragment() {
	// These are the unlit side and rear planes of the same authored envelopes.
	// Keep them below the facade value: a night skyline needs volume, not
	// luminous cardboard boxes. World-space variation stops adjacent segments
	// from becoming one perfectly flat CG slab.
	float courses = smoothstep(0.965, 1.0, fract(world_position.y * 2.55));
	float soot = 0.84 + 0.10 * sin(world_position.x * 0.17
			+ world_position.z * 0.11);
	vec3 brick = vec3(0.062, 0.038, 0.028) * soot;
	float tint_luma = max(dot(instance_tint.rgb,
			vec3(0.2126, 0.7152, 0.0722)), 0.001);
	vec3 authored_tint = mix(vec3(1.0), instance_tint.rgb / tint_luma, 0.28);
	brick *= authored_tint;
	float exposure = 0.70 + 0.30 * abs(dot(normalize(world_normal),
			normalize(-facade_light_direction)));
	vec3 result = mix(brick, vec3(0.078, 0.058, 0.046), courses * 0.18);
	// A box side is still an apartment elevation. Build its grid in metres
	// from the dominant horizontal tangent so rear and return walls cannot
	// become windowless charcoal slabs when the roof camera sees past a corner.
	float along = abs(world_normal.x) > abs(world_normal.z)
			? world_position.z : world_position.x;
	vec2 grid = vec2(along / 1.45, world_position.y / 2.70);
	vec2 cell_id = floor(grid);
	vec2 edge = abs(fract(grid) - vec2(0.5));
	float vertical_face = 1.0 - step(0.35, abs(world_normal.y));
	float window = (1.0 - step(0.255, edge.x))
			* (1.0 - step(0.305, edge.y)) * vertical_face;
	float room_hash = fract(sin(dot(cell_id,
			vec2(12.9898, 78.233))) * 43758.5453);
	float occupied = step(0.72, room_hash) * occupancy_gain;
	vec3 dark_glass = vec3(0.007, 0.010, 0.013);
	vec3 warm_room = mix(vec3(0.088, 0.044, 0.016),
			vec3(0.046, 0.056, 0.061), step(0.91, room_hash));
	result = mix(result, mix(dark_glass, warm_room, occupied), window);
	ALBEDO = result * facade_light_gain * exposure;
	EMISSION = warm_room * occupied * window * (0.06 + room_hash * 0.06);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_city_mass_material = material
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = _city_masses.size()
	for index in _city_masses.size():
		multimesh.set_instance_transform(index, _city_masses[index].transform)
		multimesh.set_instance_color(index, _city_masses[index].color)
	var visual := MultiMeshInstance3D.new()
	visual.name = "PersistentNeighbourMasses"
	visual.multimesh = multimesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)


func _emit_city_facades(parent: Node3D) -> void:
	if _city_facades.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float occupancy_gain = 1.0;
uniform float facade_light_gain = 1.0;
uniform vec3 facade_light_direction = vec3(0.0, 1.0, 0.0);
varying vec3 world_position;
varying vec3 world_normal;
varying flat float instance_seed;
varying flat vec2 instance_extent;
varying flat vec4 instance_tint;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	instance_seed = float(INSTANCE_ID);
	instance_extent = vec2(length(MODEL_MATRIX[0].xyz),
			length(MODEL_MATRIX[1].xyz));
	instance_tint = COLOR;
}
void fragment() {
	// A cheap 1920s apartment-house finish. Window recess and light are one
	// calculation, so illumination physically cannot miss its opening. The old
	// site-light cards remain only as non-emissive compatibility geometry.
	// Derive the grid from metres, not UV. Fixed 7x5 cells stretched narrow
	// windows across wide houses and compressed them on tall ones.
	float bays = clamp(floor(instance_extent.x / 1.45), 4.0, 10.0);
	float floors = clamp(floor(instance_extent.y / 2.70), 3.0, 8.0);
	vec2 cell_id = floor(vec2(UV.x * bays, UV.y * floors));
	vec2 cell = fract(vec2(UV.x * bays, UV.y * floors));
	vec2 edge = abs(cell - vec2(0.5));
	float window = (1.0 - step(0.255, edge.x))
			* (1.0 - step(0.305, edge.y));
	float opening = (1.0 - step(0.292, edge.x))
			* (1.0 - step(0.342, edge.y));
	float reveal = max(0.0, opening - window);
	float sash = max(1.0 - step(0.018, abs(cell.x - 0.5)),
			1.0 - step(0.014, abs(cell.y - 0.5))) * window;
	float course = smoothstep(0.955, 1.0, fract(UV.y * 82.0));
	float pier = smoothstep(0.925, 1.0, fract(UV.x * bays));
	float storey = smoothstep(0.955, 1.0, fract(UV.y * floors));
	float parapet = smoothstep(0.90, 0.94, UV.y);
	float basement = 1.0 - smoothstep(0.0, 0.11, UV.y);
	float grime = 0.82 + 0.12 * sin(UV.y * 31.0 + UV.x * 13.0
			+ world_position.x * 0.07);
	vec3 brick = vec3(0.070, 0.035, 0.024) * grime;
	float tint_luma = max(dot(instance_tint.rgb,
			vec3(0.2126, 0.7152, 0.0722)), 0.001);
	vec3 authored_tint = mix(vec3(1.0), instance_tint.rgb / tint_luma, 0.34);
	brick *= authored_tint;
	brick = mix(brick, vec3(0.090, 0.052, 0.036), course * 0.24);
	brick *= 0.82 + 0.12 * max(pier, storey);
	vec3 stone = vec3(0.092, 0.080, 0.066);
	vec3 result = brick;
	result = mix(result, stone * 0.62, storey * 0.42);
	result = mix(result, brick * 0.58, parapet * 0.72);
	result = mix(result, vec3(0.025, 0.027, 0.027), basement * 0.75);
	result = mix(result, brick * 0.24, reveal);
	float room_hash = fract(sin(dot(cell_id + vec2(instance_seed * 0.37,
			instance_seed * 1.13),
			vec2(12.9898, 78.233))) * 43758.5453);
	float occupied = step(0.68, room_hash) * occupancy_gain;
	vec3 dark_glass = vec3(0.006, 0.009, 0.012);
	vec3 warm_room = mix(vec3(0.095, 0.047, 0.017),
			vec3(0.050, 0.061, 0.066), step(0.90, room_hash));
	result = mix(result, mix(dark_glass, warm_room, occupied), window);
	float head_shadow = window * smoothstep(0.36, 0.50, cell.y) * 0.18;
	result *= 1.0 - head_shadow;
	result = mix(result, vec3(0.020, 0.017, 0.015), sash);
	float exposure = 0.60 + 0.40 * abs(dot(normalize(world_normal),
			normalize(-facade_light_direction)));
	ALBEDO = result * facade_light_gain * exposure;
	EMISSION = warm_room * occupied * window * (0.08 + room_hash * 0.08);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_city_facade_material = material
	quad.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = _city_facades.size()
	for index in _city_facades.size():
		multimesh.set_instance_transform(index, _city_facades[index].transform)
		multimesh.set_instance_color(index, _city_facades[index].color)
	var visual := MultiMeshInstance3D.new()
	visual.name = "PersistentNeighbourFacades"
	visual.multimesh = multimesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)


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
uniform sampler2D puddle_surface : source_color, filter_linear_mipmap_anisotropic;
void fragment() {
	vec2 p = UV - vec2(0.5);
	vec3 scan = texture(puddle_surface, UV).rgb;
	float authored_mask = smoothstep(0.018, 0.16, max(scan.r, max(scan.g, scan.b)));
	float edge = smoothstep(0.52, 0.38, length(p)) * authored_mask;
	float ripple = sin(length(p) * 92.0 - TIME * 5.0) * 0.5 + 0.5;
	float rain = pow(ripple, 11.0) * 0.12;
	ALBEDO = mix(vec3(0.018, 0.026, 0.034), scan * 0.38,
			clamp(length(scan) * 0.7, 0.0, 0.55))
			+ rain * vec3(0.10, 0.14, 0.18);
	METALLIC = 0.38;
	ROUGHNESS = 0.065 + rain * 0.18 + (1.0 - authored_mask) * 0.3;
	SPECULAR = 0.90;
	EMISSION = vec3(0.035, 0.055, 0.085) * (0.15 + weather_flash * 2.4);
	ALPHA = edge * 0.82;
}
"""
	_puddle_material.shader = shader
	_puddle_material.set_shader_parameter("puddle_surface", load(
			"res://assets/building/textures/exterior_details/puddle_surface_v2.png"))
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
