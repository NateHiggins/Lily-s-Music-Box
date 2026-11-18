extends Node3D
## The light the street's traffic throws after dusk. The vehicles' lamps are
## already lit surfaces (the traffic's and the trolley line's own finishes);
## this adds what those lamps do to the road: a headlamp beam ahead of each
## motor and tram car, a tram's lit saloon spilling on the pavement, and the
## small pool of a wagon's oil lantern.
##
## A fixed pool of lights is handed each frame to the vehicles nearest the
## player, and every light fades out with distance before the pool runs short,
## so nothing pops. The lights follow the traffic's own dusk and dawn rule and
## cast no shadows. They decide nothing: the traffic owns every vehicle.

const StreetSurface := preload("res://scripts/building/orison_v2_city_streets.gd")
const BEAMS := 8
const GLOWS := 5
## Beyond this distance from the player a vehicle throws no light of its own.
const REACH_M := 80.0
const FADE_M := 22.0
## 1928 lamps: six-volt bulbs behind a tin reflector, acetylene on the older
## trucks, kerosene on the wagons. Weak, yellow, and no two alike.
const HEADLAMP := {"colour": Color(1.0, 0.76, 0.46), "energy": 1.35, "range": 12.5, "angle": 27.0, "height": 0.92, "dip": 0.11}
const TRAM_LAMP := {"colour": Color(1.0, 0.8, 0.52), "energy": 1.7, "range": 16.0, "angle": 30.0, "height": 1.25, "dip": 0.09}
const SALOON := {"colour": Color(1.0, 0.76, 0.5), "energy": 0.7, "range": 6.5, "height": 2.3}
const LANTERN := {"colour": Color(1.0, 0.55, 0.22), "energy": 0.55, "range": 4.2, "height": 1.55}
## How far one vehicle's lamps may differ from the next: dimmer by up to this
## share, knocked this many degrees off true, and this share of motors running
## on one lamp.
const DIM_SPREAD := 0.45
const AIM_SPREAD_DEGREES := 5.0
const ONE_EYED_SHARE := 0.2

var traffic: OrisonV2StreetTraffic
var player: Node3D
## How lit the lamps are now, 0 by day to 1 at night.
var lit := 0.0
var _beams: Array[SpotLight3D] = []
var _glows: Array[OmniLight3D] = []
var _time := 0.0


static func attach(street_traffic: OrisonV2StreetTraffic, watcher: Node3D) -> Node3D:
	var lights: Node3D = new()
	lights.name = "VehicleLights"
	lights.traffic = street_traffic
	lights.player = watcher
	return lights


func _ready() -> void:
	process_priority = 10
	for index in BEAMS:
		var beam := SpotLight3D.new()
		beam.name = "Headlamp%d" % index
		beam.shadow_enabled = false
		beam.spot_attenuation = 1.1
		beam.spot_angle_attenuation = 0.8
		beam.light_specular = 0.3
		beam.visible = false
		add_child(beam)
		_beams.append(beam)
	for index in GLOWS:
		var glow := OmniLight3D.new()
		glow.name = "Glow%d" % index
		glow.shadow_enabled = false
		glow.light_specular = 0.2
		glow.visible = false
		add_child(glow)
		_glows.append(glow)


func _process(delta: float) -> void:
	_time += delta
	refresh()


## A vehicle's own lamps, the same for its whole journey: [share of the
## energy, aim off true in radians, sideways offset in metres, rhythm].
static func character(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var share := 1.0 - DIM_SPREAD * rng.randf()
	var aim := deg_to_rad(AIM_SPREAD_DEGREES) * rng.randf_range(-1.0, 1.0)
	var one_eyed := rng.randf() < ONE_EYED_SHARE
	return [share * (0.6 if one_eyed else 1.0), aim, (0.42 if rng.randf() < 0.5 else -0.42) if one_eyed else 0.0, rng.randf() * TAU]


## An engine shaking its lamps, a flame in a draught. Steady under reduced flashing.
func _tremor(rhythm: float, amount: float) -> float:
	if bool(GameBoot.settings.get("reduce_flashing", false)):
		return 1.0
	return 1.0 + amount * (0.6 * sin(_time * (7.3 + rhythm) + rhythm) + 0.4 * sin(_time * (17.9 + rhythm * 2.0) + rhythm * 3.0))


## How many beams and glows are burning now.
func burning() -> Vector2i:
	var beams := 0
	var glows := 0
	for beam in _beams:
		beams += int(beam.visible)
	for glow in _glows:
		glows += int(glow.visible)
	return Vector2i(beams, glows)


func refresh() -> void:
	if traffic == null or traffic.startup_failed or traffic.data.is_empty():
		return
	if traffic._now.is_empty():
		traffic._read_clock()
	lit = OrisonV2StreetTraffic.lamp_factor(traffic._now, traffic.data.schedule.dusk, traffic.data.schedule.dawn)
	var beams := 0
	var glows := 0
	if lit > 0.01:
		var eye := to_local(player.global_position) if is_instance_valid(player) and player.is_inside_tree() else Vector3.ZERO
		var road_y := float(traffic.data.site.road_y)
		var near: Array = []
		for v: Dictionary in traffic._live:
			var pose := traffic._world_pose(v)
			near.append([Vector2(float(pose[0]) - eye.x, float(pose[1]) - eye.z).length(), int(v.kind), float(pose[0]), float(pose[1]), float(pose[2]), int(v.id)])
		for c: Dictionary in traffic._cross:
			near.append([Vector2(float(c.x) - eye.x, float(c.z) - eye.z).length(), int(c.kind), float(c.x), float(c.z),
					-PI * 0.5 if float(c.heading) > 0.0 else PI * 0.5, hash(float(c.speed))])
		near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for entry: Array in near:
			var distance := float(entry[0])
			if distance >= REACH_M:
				break
			var level := lit * clampf((REACH_M - distance) / FADE_M, 0.0, 1.0)
			var kind: Dictionary = traffic._kinds[int(entry[1])]
			var x := float(entry[2])
			var frame := Transform3D(StreetSurface.road_basis(x, float(entry[4])),
					Vector3(x, road_y + StreetSurface.surface_height(x), float(entry[3])))
			var extent: Array = kind.extent
			var own := character(int(entry[5]))
			var horse: Variant = kind.get("horse")
			if horse is Dictionary:
				# One oil lantern on the near side of the driver's seat.
				if glows < GLOWS:
					var seat := float((horse as Dictionary).at[0]) - 1.15
					_glow(_glows[glows], frame * Vector3(seat, float(LANTERN.height), -float(kind.width) * 0.5 - 0.08), LANTERN, level * float(own[0]) * _tremor(float(own[3]), 0.16))
					glows += 1
				continue
			var lamp: Dictionary = TRAM_LAMP if bool(kind.get("rail", false)) else HEADLAMP
			if beams < BEAMS:
				var beam := _beams[beams]
				var ahead := (frame.basis.x - frame.basis.y * float(lamp.dip)).normalized().rotated(frame.basis.y.normalized(), float(own[1]))
				beam.transform = Transform3D(Basis.looking_at(ahead, frame.basis.y), frame * Vector3(float(extent[1]) - 0.12, float(lamp.height), float(own[2])))
				beam.light_color = lamp.colour
				beam.light_energy = float(lamp.energy) * level * float(own[0]) * _tremor(float(own[3]), 0.05)
				beam.spot_range = float(lamp.range)
				beam.spot_angle = float(lamp.angle)
				beam.visible = true
				beams += 1
			if bool(kind.get("rail", false)) and glows < GLOWS:
				_glow(_glows[glows], frame * Vector3(0.0, float(SALOON.height), 0.0), SALOON, level * _tremor(float(own[3]), 0.04))
				glows += 1
	for index in range(beams, BEAMS):
		_beams[index].visible = false
	for index in range(glows, GLOWS):
		_glows[index].visible = false


func _glow(light: OmniLight3D, at: Vector3, kind: Dictionary, level: float) -> void:
	light.position = at
	light.light_color = kind.colour
	light.light_energy = float(kind.energy) * level
	light.omni_range = float(kind.range)
	light.visible = true
