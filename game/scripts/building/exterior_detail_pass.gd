class_name ExteriorDetailPass
extends Node3D
## Cheap exterior finish pass layered over the generator's broad site pass.
## Everything except the damage cards is held in three shared MultiMeshes.

var detail_count := 0
var decal_count := 0
var puddle_count := 0
var faulty_lamp_count := 0
var boundary_count := 0

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
	_build_playable_stage(parent)
	_emit_boxes(parent)
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
	_add_boundary_shape(car_body, [cx, cy, 0.62], [4.74, 1.84, 1.24])


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


## The playable exterior is a theatrical street slice. Parked vehicles and
## construction hoarding explain its edges; collision preserves the view cone
## before low-detail neighboring blocks can be inspected from behind.
func _build_playable_stage(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "ExteriorStreetStageBoundary"
	parent.add_child(body)
	# THE STAGE HAS TWO DOORS IN IT NOW.
	#
	# This boundary was authored when the playable street was the north
	# pavement and nothing else: one 32 m wall down the middle of the
	# road, side walls at x +-16.15, and a near-black kerb rail the full
	# width. Since then the Harukiya opened across the road and the
	# bodega opened to the east, and route discipline named both of them
	# legal destinations - so the fence that stopped the player
	# wandering was also stopping them arriving. It read exactly as
	# reported: a dark bar lying across the carriageway.
	#
	# The mid-road run is now split either side of the crossing, and the
	# east wall has moved out past the bodega frontage (x 15.2..19.6) so
	# the shop is inside the stage rather than behind its edge. Anything
	# added to the street from here on has to ask the same question:
	# does the boundary still leave a way to every place the schedules
	# send a resident?
	# THE ROAD IS OPEN NOW (2026-08-11).
	#
	# Two boundary segments used to run the length of the carriageway at
	# y -17.35, leaving one 7.45 m gap at the crossing. The visible near-black
	# kerb rail that once telegraphed them was deleted as "a wall wearing an
	# apology"; the collision stayed, so what was left was the apology's wall
	# with nothing wearing it. A street-wide shape probe found it as the single
	# largest blocker on the block, 113 hits, and it is the invisible wall the
	# owner reported walking into.
	#
	# It cannot survive the redesign in any case. The carriageway is becoming
	# the thing the player crosses, at any point along it, judging a gap in live
	# traffic - and you cannot do that through a fence with one door in it.
	# The reason not to step into the road is now the road.
	#
	# The lateral edges stay for the moment. They are the stage's real limits
	# and they are honest ones, backed by visible hoarding. They are also
	# temporary: the tears at either end are meant to replace them, at which
	# point the street stops having edges and starts having ends.
	const STAGE_E := 20.60       # east edge, clear of the bodega
	# The west edge now includes Otis & Son.  Keeping the old -16.15 m
	# theatre wall made the newly modelled druggist visible but placed its
	# public door 75 mm beyond the playable world.
	const STAGE_W := -20.10
	# Lateral only. The kerb-line segments are gone; see above.
	_add_boundary_shape(body, [STAGE_W, -13.45, 0.72], [0.30, 7.55, 1.44])
	_add_boundary_shape(body, [STAGE_E, -13.45, 0.72], [0.30, 7.55, 1.44])
	boundary_count = 2
	# Side hoardings and battered planters telegraph the lateral stop.
	for x in [STAGE_W + 0.10, STAGE_E - 0.10]:
		_box([x, -13.15, 0.83], [0.22, 5.2, 1.66], Color(0.055, 0.062, 0.064))
		for y in [-15.2, -13.6, -12.0, -10.8]:
			_box([x - signf(x) * 0.13, y, 1.15], [0.035, 0.74, 0.035], Color(0.46, 0.24, 0.08))
	# The near-black kerb rail is GONE. It was a 31.7 m bar of colour
	# 0.018,0.022,0.024 lying across the carriageway to telegraph the
	# stage edge, and what it actually read as was a black plane the
	# player could not get past - which is precisely what it was. The
	# collision above still holds the edge; the street already explains
	# itself with hoardings, open trenches and a parked row, and those
	# are closures a person believes. A bar of near-black is not a
	# reason, it is a wall wearing an apology.


func _add_boundary_shape(body: StaticBody3D, pos_b: Array, size_b: Array) -> void:
	var collision := CollisionShape3D.new()
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
