extends Node
## Headless contract for the lit street: the lamp runs along the avenue and
## the cross streets each burn their own light from dusk to dawn, and the
## traffic throws light of its own after dark (a beam ahead of each motor and
## tram car, a tram's saloon, a wagon's lantern), handed to the vehicles
## nearest the player and gone by day.
const Lamps := preload("res://scripts/building/orison_v2_street_lamps.gd")
const VehicleLights := preload("res://scripts/building/orison_v2_street_vehicle_lights.gd")

const NIGHT := {"valid": true, "day": "tue", "month": 11, "day_of_month": 20, "year": 1928, "minute_of_day": 1290.0}
const NOON := {"valid": true, "day": "tue", "month": 11, "day_of_month": 20, "year": 1928, "minute_of_day": 720.0}

var failures := 0
var checks := 0


class BenchStreet extends RefCounted:
	var street: Node3D
	func instance_node(_identity: String) -> Node3D: return street


class BenchHost extends Node3D:
	var exterior_cell := BenchStreet.new()


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("STREET LIGHTS CHECK: ", label, " = ", ok)


func _run() -> void:
	RealityState.persistence_enabled = false
	# --- The lamp runs.
	var data := Lamps.load_table()
	check(not data.is_empty(), "the lamp table loads")
	var ids := {}
	var avenue := [0, 0]
	var cross := 0
	var nearest := INF
	var lamps: Array = data.lamps
	for lamp: Dictionary in lamps:
		ids[str(lamp.id)] = true
		if str(lamp.id).begins_with("lamp_run_avenue_n"):
			avenue[0] += 1
		elif str(lamp.id).begins_with("lamp_run_avenue_s"):
			avenue[1] += 1
		elif str(lamp.id).begins_with("lamp_run_cross"):
			cross += 1
	for i in lamps.size():
		for j in range(i + 1, lamps.size()):
			var a: Array = lamps[i].at
			var b: Array = lamps[j].at
			nearest = minf(nearest, Vector2(float(a[0]) - float(b[0]), float(a[2]) - float(b[2])).length())
	check(ids.size() == lamps.size() and lamps.size() >= 40, "every lamp has its own name, and there are runs of them (%d)" % lamps.size())
	check(avenue[0] >= 6 and avenue[1] >= 6 and cross >= 20, "both pavements of the avenue and the cross streets are lit (%d, %d, %d)" % [avenue[0], avenue[1], cross])
	check(nearest > 4.0, "no two lamps stand within four metres of each other (%.1f)" % nearest)
	var reach := true
	var clear_route := true
	for lamp: Dictionary in lamps:
		var at: Array = lamp.at
		reach = reach and Vector2(float(at[0]), float(at[2])).length() < 200.0
		# The crossing route walks the north kerb at x 14; only the authored signal post stands there.
		if str(lamp.id).begins_with("lamp_run") and absf(float(at[0]) - 14.0) < 2.5 and float(at[2]) < 5.0 and float(at[2]) > 2.0:
			clear_route = false
	check(reach, "every lamp stands inside the walkable city")
	check(clear_route, "the crossing route's kerb is left clear")

	var host := BenchHost.new()
	var street := Node3D.new()
	host.exterior_cell.street = street
	host.add_child(street)
	add_child(host)
	for lamp: Dictionary in lamps:
		for identity: String in lamp.replaces:
			var placeholder := MeshInstance3D.new()
			placeholder.mesh = BoxMesh.new()
			placeholder.set_meta("authored_record_id", identity)
			street.add_child(placeholder)
		if not str(lamp.authored_light).is_empty():
			var authored := OmniLight3D.new()
			authored.set_meta("authored_record_id", str(lamp.authored_light))
			street.add_child(authored)
	# Another owner's light that carries no record id: it is nobody's lamp.
	var stray := OmniLight3D.new()
	stray.name = "SomeoneElses"
	stray.position = Vector3(1, 2, 3)
	street.add_child(stray)
	var mounted := Lamps.mount(host)
	check(mounted != null, "the lamps mount")
	if mounted == null:
		get_tree().quit(1)
		return
	var clock := mounted.get_node("LampClock")
	var seen := {}
	for light: OmniLight3D in clock.lights:
		seen[light.get_instance_id()] = true
	check(clock.lights.size() == lamps.size() and seen.size() == lamps.size(), "every lamp burns a light of its own (%d lights, %d lamps)" % [seen.size(), lamps.size()])
	check(not seen.has(stray.get_instance_id()) and stray.position.is_equal_approx(Vector3(1, 2, 3)), "a light that is not a lamp's is left where it was")
	var over_globe := true
	var fades := 0
	var globe: Array = data.globe_local
	for lamp: Dictionary in lamps:
		var at: Array = lamp.at
		var want := Transform3D(Basis(Vector3.UP, deg_to_rad(float(lamp.yaw_degrees))), Vector3(at[0], at[1], at[2])) * Vector3(globe[0], globe[1], globe[2])
		var found := false
		for light: OmniLight3D in clock.lights:
			if street.to_local(light.global_position).distance_to(want) < 0.01:
				found = true
				if light.distance_fade_enabled:
					fades += 1
					over_globe = over_globe and is_equal_approx(light.distance_fade_begin, float(data.light.fade_begin_m)) and not light.shadow_enabled
		over_globe = over_globe and found
	check(over_globe, "each light hangs in its own globe")
	var midground: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/exterior/city_midground.json"))
	var crowded := 0
	for group: Dictionary in midground.furniture:
		if str(group.kind) != "lamp":
			continue
		for item: Array in group["items"]:
			for lamp: Dictionary in lamps:
				if Vector2(float(item[0]) - float(lamp.at[0]), float(item[2]) - float(lamp.at[2])).length() < 6.0:
					crowded += 1
	check(crowded == 0, "no lamp of the runs stands beside one the mid ground already has (%d)" % crowded)
	check(fades == lamps.size() - 2, "the runs' pools fade with distance and cast no shadows; the two authored lamps keep theirs (%d)" % fades)
	clock.clock_override = NIGHT
	clock.refresh()
	check(clock.lights.all(func(light: OmniLight3D) -> bool: return light.visible and light.light_energy > 0.5 and light.light_energy <= float(data.light.energy) * 1.2), "after dusk every lamp is lit, none brighter than a mantle burns")
	var burns := {}
	var tints := {}
	for index in clock.lights.size():
		burns[snappedf(clock.burn(index), 0.01)] = true
		tints[clock.lights[index].light_color.to_html()] = true
	check(burns.size() > 10 and tints.size() > 10 and float(data.light.energy) < 2.0, "it is gaslight: modest, and no two lamps burn alike (%d levels, %d tints)" % [burns.size(), tints.size()])
	var before: float = clock.lights[5].light_energy
	var moved := false
	for frame in 40:
		clock._process(0.05)
		moved = moved or absf(clock.lights[5].light_energy - before) > 0.005
	check(moved, "a mantle breathes")
	GameBoot.settings["reduce_flashing"] = true
	check(is_equal_approx(clock.burn(5), clock._share[5]), "with reduced flashing the lamps are uneven but steady")
	GameBoot.settings["reduce_flashing"] = false
	# Posts another owner stands are lit by the same clock.
	var before_adopting: int = clock.lights.size()
	var took: int = clock.adopt([Vector3(300, 4, 0), Vector3(300, 4, 30), Vector3(300, 4, 60)], street)
	var adopted: Array = clock.lights.slice(before_adopting)
	var alike := took == 3 and adopted.size() == 3
	for light: OmniLight3D in adopted:
		alike = alike and light.visible and light.distance_fade_enabled and not light.shadow_enabled and light.light_energy > 0.5 				and light.light_energy <= float(data.light.energy) * 1.2 and light.get_parent() == street
	check(alike, "adopted posts burn the same gas, lit with the rest")
	check(is_equal_approx((adopted[1] as OmniLight3D).position.z, 30.0) and clock._share.size() == clock.lights.size(), "each where it was asked for, with a character of its own")
	clock.clock_override = NOON
	clock.refresh()
	check(clock.lights.all(func(light: OmniLight3D) -> bool: return not light.visible), "by day every lamp is out")

	# --- The traffic's own light.
	var person := Node3D.new()
	add_child(person)
	person.position = Vector3(0, 0, 9.5)
	var traffic := OrisonV2StreetTraffic.new()
	check(traffic.configure(person, 1928), "traffic configures from its table")
	traffic.clock_override = NIGHT
	var line := OrisonV2StreetTrams.attach(traffic, self)
	street.add_child(traffic)
	if line != null:
		street.add_child(line)
	var lights := VehicleLights.attach(traffic, person)
	street.add_child(lights)
	traffic.stage([
		{"id": "model_a_tudor", "lane_west": true, "x": -6.0, "speed": 8.0},
		{"id": "checker_cab", "lane_west": false, "x": 12.0, "speed": 8.0},
		{"id": "ice_wagon", "lane_west": true, "x": 22.0, "speed": 1.8},
		{"id": "tram", "lane_west": false, "x": -34.0, "speed": 5.0},
		{"id": "mack_ac", "lane_west": false, "x": 150.0, "speed": 5.0},
	])
	traffic._read_clock()
	lights.refresh()
	check(not traffic.startup_failed and is_equal_approx(lights.lit, 1.0), "at night the lamps are lit")
	check(lights.burning() == Vector2i(3, 2), "two motors and the tram throw a beam, the tram's saloon and the wagon's lantern glow, and a truck far down the street throws none (%s)" % str(lights.burning()))
	var ahead := true
	var on_road := true
	var beams: Array = lights.find_children("Headlamp*", "SpotLight3D", false, false)
	for beam: SpotLight3D in beams:
		if not beam.visible:
			continue
		var aim := -beam.transform.basis.z
		var nearest_vehicle: Dictionary = {}
		var best := INF
		for v: Dictionary in traffic._live:
			var pose := traffic._world_pose(v)
			var gap := Vector2(float(pose[0]) - beam.position.x, float(pose[1]) - beam.position.z).length()
			if gap < best:
				best = gap
				nearest_vehicle = v
		var pose := traffic._world_pose(nearest_vehicle)
		var heading := Basis(Vector3.UP, float(pose[2])).x
		ahead = ahead and aim.dot(heading) > 0.95 and aim.y < 0.0 and aim.y > -0.25 and beam.light_energy < 2.0
		on_road = on_road and best < 7.0 and beam.position.y > 0.5 and beam.position.y < 1.6 and not beam.shadow_enabled
	check(ahead, "each beam points the way its vehicle is going, near enough, dipped to the road, and weak")
	var shares := {}
	for seed_value in 60:
		shares[snappedf(float(VehicleLights.character(seed_value)[0]), 0.01)] = true
	check(shares.size() > 20 and VehicleLights.character(7) == VehicleLights.character(7), "no two vehicles' lamps are alike, and a vehicle keeps its own")
	check(on_road, "each beam is at lamp height on the front of its vehicle and casts no shadow")
	# The pool follows the player down the street.
	person.position = Vector3(150, 0, 9.5)
	lights.refresh()
	check(lights.burning() == Vector2i(1, 0), "walk down the street and the far truck's beam is the one burning (%s)" % str(lights.burning()))
	person.position = Vector3(0, 0, 9.5)
	traffic.clock_override = NOON
	traffic._read_clock()
	lights.refresh()
	check(lights.burning() == Vector2i.ZERO and is_zero_approx(lights.lit), "by day the traffic runs dark")
	# More vehicles than the pool holds: nearest first, nothing left burning that is not handed out.
	traffic.clock_override = NIGHT
	var crowd: Array = []
	for index in 12:
		crowd.append({"id": "model_a_tudor", "lane_west": index % 2 == 0, "x": -44.0 + 8.0 * index, "speed": 6.0})
	traffic.stage(crowd)
	traffic._read_clock()
	lights.refresh()
	check(lights.burning().x == VehicleLights.BEAMS, "a crowded street burns the whole pool and no more (%s)" % str(lights.burning()))
	traffic.stage([])
	lights.refresh()
	check(lights.burning() == Vector2i.ZERO, "an empty street is dark")

	print("STREET LIGHTS RESULT: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
