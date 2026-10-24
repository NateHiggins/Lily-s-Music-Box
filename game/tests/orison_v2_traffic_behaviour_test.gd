extends Node
## Headless behaviour contract for V2 period traffic
## (design/V2_TRAFFIC_BEHAVIOUR_2026-10-24.md). Drives the real owner's
## simulation without the world: class acceleration and braking, the T stop
## and turn-off, following, hard stops and period warnings for a person in the
## road, never passing through them, and the clock-driven schedule and lamps.
const DT := 1.0 / 60.0

var failures := 0
var checks := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("TRAFFIC BEHAVIOUR CHECK: ", label, " = ", ok)


func _fresh(person: Node3D) -> OrisonV2StreetTraffic:
	var traffic := OrisonV2StreetTraffic.new()
	if not traffic.configure(person, 1928):
		return null
	traffic.clock_override = {"valid": true, "day": "tue", "month": 11, "day_of_month": 20, "year": 1928,
			"minute_of_day": 1260.0}
	add_child(traffic)
	traffic.stage([])
	return traffic


func _kind(traffic: OrisonV2StreetTraffic, id: String) -> Dictionary:
	for kind: Dictionary in traffic._kinds:
		if str(kind.id) == id:
			return kind
	return {}


func _run() -> void:
	var person := Node3D.new()
	add_child(person)
	person.position = Vector3(0, 0, -50)
	var traffic := _fresh(person)
	check(traffic != null and not traffic.startup_failed, "owner builds from the generated table and stock")
	if traffic == null:
		get_tree().quit(1)
		return
	var data := traffic.data
	var lane_east := float(data.site.lane_east_z)

	# Acceleration from rest follows the class, motor and horse alike.
	for spec in [["model_a_tudor", "car_four_wheel"], ["ice_wagon", "horse_heavy"], ["mack_ac", "heavy_truck"]]:
		traffic.stage([{"id": spec[0], "lane_west": false, "x": -15.0, "speed": 0.0}])
		for i in 60:
			traffic._advance(DT)
		var accel := float(traffic._classes[spec[1]].acceleration)
		var speed := float(traffic._live[0].speed)
		check(absf(speed - accel) < 0.05, "%s accelerates at its class rate (%.2f m/s after 1 s, want %.2f)" % [spec[0], speed, accel])

	# Cruising speeds are 1928 in-town speeds: motors 15-25 mph, horses walk or trot.
	var model_a := _kind(traffic, "model_a_tudor")
	var ice := _kind(traffic, "ice_wagon")
	check(float(model_a.speed[0]) >= 6.5 and float(model_a.speed[1]) <= 11.2, "motor cruise within 15-25 mph")
	check(float(ice.speed[1]) <= 3.5, "heavy horses keep to a walk")

	# The T: brake on the service curve to the stop line, wait, look, turn off.
	traffic.stage([{"id": "model_a_tudor", "lane_west": false, "x": 0.0, "speed": 9.0}])
	var v: Dictionary = traffic._live[0]
	var kind := model_a
	var stop_line := float(data.junctions.east_x) - float(data.junctions.cross_half_width) - float(data.junctions.stop_gap_m)
	var peak_decel := 0.0
	var last := float(v.speed)
	var stopped_at := INF
	var turned := false
	for i in 60 * 40:
		traffic._advance(DT)
		if traffic._live.is_empty():
			break
		v = traffic._live[0]
		if str(v.phase) == "street" or str(v.phase) == "stop":
			# The last centimetres are zeroed in one frame; judge the stop while moving.
			if last > 0.5:
				peak_decel = maxf(peak_decel, (last - float(v.speed)) / DT)
			last = float(v.speed)
			if str(v.phase) == "stop" and is_inf(stopped_at):
				stopped_at = float(v.p) + float(kind.extent[1])
		if str(v.phase) == "exit":
			turned = true
	check(not is_inf(stopped_at) and stopped_at <= stop_line + 0.01 and stopped_at > stop_line - 0.6,
			"stops with its nose at the T stop line (%.2f, line %.2f)" % [stopped_at, stop_line])
	check(peak_decel <= float(traffic._classes["car_four_wheel"].service_brake) * 1.6,
			"an ordinary stop uses service braking, not panic (peak %.2f m/s2)" % peak_decel)
	check(turned and traffic._live.is_empty(), "then turns off into the cross street and leaves")

	# Following: the follower never closes inside the leader.
	traffic.stage([{"id": "ice_wagon", "lane_west": false, "x": 0.0, "speed": 1.8},
			{"id": "checker_cab", "lane_west": false, "x": -20.0, "speed": 10.0}])
	var min_gap := INF
	for i in 60 * 6:
		traffic._advance(DT)
		var lead: Dictionary = {}
		var tail: Dictionary = {}
		for item in traffic._live:
			if str(traffic._kinds[int(item.kind)].id) == "ice_wagon": lead = item
			else: tail = item
		if lead.is_empty() or tail.is_empty() or str(lead.phase) != "street":
			continue
		var gap := (float(lead.p) + float(ice.extent[0])) - (float(tail.p) + float(_kind(traffic, "checker_cab").extent[1]))
		min_gap = minf(min_gap, gap)
	check(min_gap > 0.4, "a fast cab closes up behind a walking ice wagon and holds back (min gap %.2f m)" % min_gap)

	# A person steps into the road: hard stop, the period's warning, no contact.
	for spec in [["model_a_tudor", "traffic.klaxon", 9.5], ["checker_cab", "traffic.klaxon", 10.0],
			["saloon_bus", "traffic.foot_gong", 7.0], ["motorcycle", "traffic.bulb_horn", 10.0],
			["ice_wagon", "traffic.whip_crack", 2.0], ["mack_ac", "traffic.klaxon", 5.5]]:
		traffic.stage([{"id": spec[0], "lane_west": false, "x": -12.0, "speed": float(spec[2])}])
		var k := _kind(traffic, spec[0])
		person.position = Vector3(-12.0 + float(k.extent[1]) + float(spec[2]) * 1.4 + 2.0, 0, lane_east)
		traffic.warnings.clear()
		var clearance := INF
		# Inside the driver's patience: a later courtesy note is not a second scare.
		for i in int(60 * 3.6):
			traffic._advance(DT)
			var item: Dictionary = traffic._live[0]
			clearance = minf(clearance, person.position.x - OrisonV2StreetTraffic.PLAYER_RADIUS
					- (float(item.p) + float(k.extent[1])))
		var cues: Array = traffic.warnings.map(func(w): return w.cue)
		check(cues.count(spec[1]) == 1, "%s sounds %s once for a person stepping out (%s)" % [spec[0], spec[1], cues])
		check(clearance >= 0.0 and float(traffic._live[0].speed) < 0.05,
				"%s stops short of the person (clearance %.2f m)" % [spec[0], clearance])
		if traffic._classes[str(k["class"])].brake != "":
			check("traffic.brake_shriek" in cues, "%s brakes squeal under a hard stop" % spec[0])
	# Stepping out right under the nose: still never through.
	traffic.stage([{"id": "checker_cab", "lane_west": false, "x": -12.0, "speed": 10.0}])
	var cab := _kind(traffic, "checker_cab")
	person.position = Vector3(-12.0 + float(cab.extent[1]) + 1.2, 0, lane_east)
	var worst := INF
	for i in 60 * 3:
		traffic._advance(DT)
		worst = minf(worst, person.position.x - OrisonV2StreetTraffic.PLAYER_RADIUS
				- (float(traffic._live[0].p) + float(cab.extent[1])))
	check(worst >= -0.001, "a person who steps out under the bonnet is never driven through (%.3f m)" % worst)
	# A queue: only the vehicle with a clear view of the person warns.
	traffic.stage([{"id": "checker_cab", "lane_west": false, "x": -6.0, "speed": 0.0},
			{"id": "model_a_tudor", "lane_west": false, "x": -15.0, "speed": 8.0}])
	person.position = Vector3(-6.0 + float(cab.extent[1]) + 1.5, 0, lane_east)
	traffic.warnings.clear()
	for i in 60 * 4:
		traffic._advance(DT)
	check(traffic.warnings.filter(func(w): return w.kind == "model_a_tudor").is_empty(),
			"a car queued behind a cab does not sound off at the person the cab is waiting for")
	# Nobody on the box: the riderless milk horse stops without a sound.
	traffic.stage([{"id": "milk_wagon_riderless", "lane_west": false, "x": -12.0, "speed": 1.8}])
	person.position = Vector3(-12.0 + float(_kind(traffic, "milk_wagon_riderless").extent[1]) + 3.0, 0, lane_east)
	traffic.warnings.clear()
	for i in 60 * 4:
		traffic._advance(DT)
	check(traffic.warnings.is_empty() and float(traffic._live[0].speed) < 0.05, "the riderless milk horse stops in silence")
	# A long wait: two courtesy notes at most, however long the person stands there.
	traffic.stage([{"id": "checker_cab", "lane_west": false, "x": -12.0, "speed": 0.0}])
	person.position = Vector3(-12.0 + float(cab.extent[1]) + 1.2, 0, lane_east)
	traffic.warnings.clear()
	for i in 60 * 40:
		traffic._advance(DT)
	check(traffic.warnings.size() == 2, "a driver kept waiting gives two courtesy notes in forty seconds, then silence (%d)" % traffic.warnings.size())
	person.position = Vector3(0, 0, -50)

	# The schedule: the hour, the weekday, the season and the papers' dates.
	traffic.clock_override = {"valid": true, "day": "tue", "month": 11, "day_of_month": 20, "year": 1928, "minute_of_day": 180.0}
	traffic._read_clock()
	var night := traffic._flow_per_minute()
	traffic.clock_override.minute_of_day = 480.0
	traffic._read_clock()
	var rush := traffic._flow_per_minute()
	check(night < rush * 0.2, "the 3 a.m. street is nearly empty against the morning rush (%.2f vs %.2f per minute)" % [night, rush])
	traffic.clock_override = {"valid": true, "day": "tue", "month": 7, "day_of_month": 16, "year": 1929, "minute_of_day": 600.0}
	traffic._read_clock()
	var ice_summer := traffic._kind_rate(ice)
	var coal_summer := traffic._kind_rate(_kind(traffic, "coal_cart"))
	traffic.clock_override = {"valid": true, "day": "tue", "month": 1, "day_of_month": 15, "year": 1929, "minute_of_day": 600.0}
	traffic._read_clock()
	check(ice_summer > traffic._kind_rate(ice) * 4.0, "ice wagons are a summer trade")
	check(traffic._kind_rate(_kind(traffic, "coal_cart")) > coal_summer * 4.0, "coal carts are a winter trade")
	traffic.clock_override = {"valid": true, "day": "sun", "month": 1, "day_of_month": 13, "year": 1929, "minute_of_day": 600.0}
	traffic._read_clock()
	check(traffic._kind_rate(_kind(traffic, "coal_cart")) == 0.0 and traffic._kind_rate(_kind(traffic, "aa_stake")) < 0.2,
			"Sunday: no coal, hardly any trade")
	traffic.clock_override = {"valid": true, "day": "sat", "month": 3, "day_of_month": 16, "year": 1929, "minute_of_day": 600.0}
	traffic._read_clock()
	var stoppage := traffic._kind_rate(ice)
	traffic.clock_override.day_of_month = 23
	traffic._read_clock()
	check(stoppage > traffic._kind_rate(ice) * 1.5, "the carters' stoppage sends ice round by the side streets")
	traffic.clock_override = {"valid": true, "day": "tue", "month": 11, "day_of_month": 20, "year": 1928, "minute_of_day": 720.0}
	traffic._read_clock()
	var noon := float(traffic._materials["lamp_lit"].emission_energy_multiplier)
	traffic.clock_override.minute_of_day = 1260.0
	traffic._read_clock()
	check(noon < 0.01 and float(traffic._materials["lamp_lit"].emission_energy_multiplier) > 1.0, "lamps dark at noon and lit at night")

	# The middle distance: cross-street flow both ways, which holds for our turners.
	traffic.stage([])
	traffic.frozen = true
	traffic.clock_override.minute_of_day = 480.0
	traffic._read_clock()
	var headings := {}
	var junctions := {}
	var most := 0
	for i in 60 * 60:
		traffic._spawn_cross(DT)
		traffic._advance_cross(DT)
		most = maxi(most, traffic.cross_count())
		for c in traffic._cross:
			headings[float(c.heading)] = true
			junctions[signf(float(c.x))] = true
	check(most >= 3 and headings.size() == 2 and junctions.size() == 2,
			"both cross streets carry traffic both ways (up to %d at once)" % most)
	print("TRAFFIC BEHAVIOUR: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
