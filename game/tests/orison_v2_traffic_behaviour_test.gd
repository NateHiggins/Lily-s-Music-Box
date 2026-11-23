extends Node
## Headless behaviour contract for V2 period traffic
## (design/V2_TRAFFIC_BEHAVIOUR_2026-10-24.md). Drives the real owner's
## simulation without the world: class acceleration and braking, the T stop
## and turn-off, following, hard stops and period warnings for a person in the
## road, never passing through them, and the clock-driven schedule and lamps.
const DT := 1.0 / 60.0

var failures := 0
var checks := 0

class ContactProbe:
	extends Node3D
	var impulses: Array[Vector3] = []
	func stagger(impulse: Vector3) -> void:
		impulses.append(impulse)


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
	var person := ContactProbe.new()
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

	# Left turns give way at the T to anyone turning in across their path.
	var stopped := traffic._journey(0, false, 40.0)
	stopped.phase = "stop"
	stopped.side = -1.0
	var arriving := traffic._journey(0, true)
	traffic._live = [stopped, arriving]
	traffic._cross.clear()
	arriving.run = float(data.junctions.exit_run_m)
	var clear_far := traffic._junction_clear(stopped)
	arriving.run = 3.0
	var clear_near := traffic._junction_clear(stopped)
	stopped.side = 1.0
	var clear_right := traffic._junction_clear(stopped)
	check(clear_far and not clear_near and clear_right,
			"a left turn waits for a vehicle turning in from the same T; a right turn does not")
	# One lamp rule for vehicles and street lamps: dark by day, lit at night, a ramp between.
	var dusk: Array = data.schedule.dusk
	var dawn: Array = data.schedule.dawn
	var rule_noon := OrisonV2StreetTraffic.lamp_factor({"month": 11, "minute_of_day": 720.0}, dusk, dawn)
	var rule_night := OrisonV2StreetTraffic.lamp_factor({"month": 11, "minute_of_day": 1260.0}, dusk, dawn)
	var dusk_ramp := OrisonV2StreetTraffic.lamp_factor({"month": 11, "minute_of_day": float(dusk[10]) - 12.0}, dusk, dawn)
	check(rule_noon == 0.0 and rule_night == 1.0 and dusk_ramp > 0.0 and dusk_ramp < 1.0, "lamp rule: dark at noon, lit at night, ramping at dusk")

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
	_animation_contracts(traffic)
	_height_contacts(traffic, person, model_a, lane_east)
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var sources := {}
		for path: String in ["res://tests/orison_v2_traffic_behaviour_test.gd", "res://scripts/building/orison_v2_street_traffic.gd", "res://scripts/building/orison_v2_city_streets.gd", "res://data/orison_v2/exterior/street_traffic.json", "res://data/orison_v2/exterior/city_streets.json"]:
			sources[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
		FileAccess.open(directory.path_join("traffic_behaviour.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "scope":"Isolated real traffic-owner simulation; ground/elevated contact controls. No composed-world, visual, save or artistic acceptance.", "checks":checks, "failures":failures, "source_hashes":sources}, "\t"))
	print("TRAFFIC BEHAVIOUR: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _height_contacts(traffic: OrisonV2StreetTraffic, person: ContactProbe, kind: Dictionary, lane: float) -> void:
	var original_transform := traffic.transform
	# Repeat in a translated/rotated owner: the street's local frame matters.
	for transformed in [false, true]:
		traffic.transform = Transform3D(Basis(Vector3.UP, .5), Vector3(17, 2, -31)) if transformed else original_transform
		# Independent authored street anchors, not the production height helper.
		for datum: Vector2 in [Vector2(0, 0), Vector2(-55, -.4305)]:
			for height: float in [-.1, 0., 6.2, 11.38, -3.]:
				var ground := height in [-.1, 0.]
				traffic.stage([{"id":"model_a_tudor", "lane_west":false, "x":datum.x-float(kind.extent[1])-3., "speed":8.}])
				var vehicle: Dictionary = traffic._live[0]
				person.global_position = traffic.to_global(Vector3(datum.x, datum.y+height, lane))
				var front := float(vehicle.p)+float(kind.extent[1])
				var ahead := traffic._person_ahead(vehicle, kind, front)
				check(absf(ahead-2.65)<.001 if ground else is_inf(ahead), "height-aware yielding retains ground person and ignores separated level %s/%s/%s" % [transformed, datum.x, height])
				traffic.stage([{"id":"model_a_tudor", "lane_west":false, "x":datum.x, "speed":8.}])
				traffic._shove_cooldown = 0.
				person.impulses.clear()
				traffic._check_shove()
				check(person.impulses.size()==(1 if ground else 0), "height-aware shove retains ground challenge and ignores separated level %s/%s/%s" % [transformed, datum.x, height])
				if ground:
					check(person.impulses[0].is_equal_approx(traffic.global_transform.basis*Vector3(3.4,0,0)), "ground shove keeps its original impulse")
					traffic._check_shove()
					check(person.impulses.size()==1, "ground shove keeps its cooldown")
	traffic.transform = original_transform
	person.position = Vector3(0,0,-50)


## Animation that reads on the road (design/V2_TRAFFIC_INVENTORY_2026-11-23.md): whole vehicles the length of
## the block, wheels that roll without sliding, front axles that steer, bodies that pitch, gaits that never jump,
## cross-street stops on the braking curves, and the WE TUNA PIANOS truck with its legend and its solo rule.
func _animation_contracts(traffic: OrisonV2StreetTraffic) -> void:
	var data := traffic.data
	traffic.clock_override = {"valid": true, "day": "tue", "month": 11, "day_of_month": 20, "year": 1928, "minute_of_day": 600.0}
	traffic._read_clock()
	# Whole at the far end of the block, where the 24 m cut-off used to strip wheels and drivers.
	traffic.stage([{"id": "model_t_touring", "lane_west": false, "x": 55.0, "speed": 0.0}])
	var wheels_far: int = traffic._batches.wheel_artillery.multimesh.visible_instance_count
	var driver_far: int = traffic._batches.figure.multimesh.visible_instance_count
	check(wheels_far == 4 and driver_far == 1, "a Model T 55 m up the block keeps its four wheels and its driver (%d, %d)" % [wheels_far, driver_far])

	# Rolling, not sliding: the point of the tyre on the road stays put while the car moves on.
	traffic.stage([{"id": "model_a_tudor", "lane_west": false, "x": -10.0, "speed": 6.0}])
	traffic.tracing = true
	traffic._write_instances()
	var radius := float(_kind(traffic, "model_a_tudor").wheels[0].radius)
	var worst_slip := 0.0
	var moved := 0.0
	for i in 30:
		var before: Transform3D = traffic.trace.wheel_wire[0]
		var contact := before.affine_inverse() * (before.origin + Vector3.DOWN * radius)
		var p0 := float(traffic._live[0].p)
		traffic._advance(DT)
		traffic._write_instances(DT)
		var after: Transform3D = traffic.trace.wheel_wire[0]
		var step := float(traffic._live[0].p) - p0
		moved += step
		worst_slip = maxf(worst_slip, (after * contact - (before.origin + Vector3.DOWN * radius)).length() / maxf(step, 0.001))
	check(moved > 1.0 and worst_slip < 0.3, "wheels roll at ground speed: the tyre's road contact barely moves (worst %.3f of the step)" % worst_slip)

	# Braking into the T: the body dips, the wheels do not; the front axle steers through the turn and back.
	traffic.stage([{"id": "model_a_tudor", "lane_west": false, "x": 35.0, "speed": 9.0}])
	var v: Dictionary = traffic._live[0]
	var most_dip := 0.0
	var most_steer := 0.0
	var steer_jump := 0.0
	var last_steer := 0.0
	var last_surge := 0.0
	var straight_after := INF
	for i in 60 * 30:
		traffic._advance(DT)
		if traffic._live.is_empty():
			break
		v = traffic._live[0]
		traffic._write_instances(DT)
		var pitch := clampf(float(v.surge) * OrisonV2StreetTraffic.PITCH_PER_MS2, -OrisonV2StreetTraffic.PITCH_LIMIT, OrisonV2StreetTraffic.PITCH_LIMIT)
		if str(v.phase) == "street":
			most_dip = minf(most_dip, pitch)
		steer_jump = maxf(steer_jump, absf(float(v.steer) - last_steer))
		last_steer = float(v.steer)
		last_surge = float(v.surge)
		if str(v.phase) == "exit":
			most_steer = maxf(most_steer, absf(float(v.steer)))
			if float(v.run) > 6.0:
				straight_after = minf(straight_after, absf(float(v.steer)))
	check(most_dip < -0.008 and most_dip >= -OrisonV2StreetTraffic.PITCH_LIMIT, "the body dips under service braking (%.3f rad)" % most_dip)
	check(most_steer > 0.2 and steer_jump <= OrisonV2StreetTraffic.STEER_RATE * DT + 0.0001 and straight_after < 0.05,
			"the front axle steers into the turn and back out, never snapping (peak %.2f, step %.3f, after %.3f rad)" % [most_steer, steer_jump, straight_after])

	# Walk into trot: the horse's legs never jump.
	traffic.stage([{"id": "milk_wagon", "lane_west": false, "x": -30.0, "speed": 1.4}])
	v = traffic._live[0]
	v.cruise = 3.2
	var last_swing := NAN
	var swing_jump := 0.0
	var crossed := false
	for i in 60 * 6:
		traffic._advance(DT)
		traffic._write_instances(DT)
		var local: Transform3D = (traffic.trace.horse_body[0] as Transform3D).affine_inverse() * (traffic.trace.horse_leg[0] as Transform3D)
		var swing := atan2(local.basis.x.y, local.basis.x.x)
		if not is_nan(last_swing):
			swing_jump = maxf(swing_jump, absf(swing - last_swing))
		last_swing = swing
		crossed = crossed or float(traffic._live[0].speed) > OrisonV2StreetTraffic.TROT_BAND.y
	check(crossed and swing_jump < 0.09, "a milk horse breaks from walk into trot with no jump in its legs (largest step %.3f rad)" % swing_jump)

	# The cross street: a car comes up behind one standing and stops on its class's curve, short of it.
	var cab_index := -1
	for i in traffic._kinds.size():
		if str(traffic._kinds[i].id) == "checker_cab":
			cab_index = i
	var taxi: Dictionary = traffic._classes["taxi"]
	var x := float(data.junctions.east_x) + 20.0
	traffic.stage([])
	traffic._cross = [{"kind": cab_index, "x": x, "z": 0.0, "heading": 1.0, "cruise": 0.0, "speed": 0.0, "paint": Color.WHITE, "coat": Color.WHITE, "travel": 0.0},
			{"kind": cab_index, "x": x, "z": -22.0, "heading": 1.0, "cruise": 9.0, "speed": 9.0, "paint": Color.WHITE, "coat": Color.WHITE, "travel": 0.0}]
	var follower: Dictionary = traffic._cross[1]
	var peak := 0.0
	var last := 9.0
	for i in 60 * 8:
		traffic._advance_cross(DT)
		if last > 0.5:
			peak = maxf(peak, (last - float(follower.speed)) / DT)
		last = float(follower.speed)
	var cab := _kind(traffic, "checker_cab")
	var gap := (0.0 + float(cab.extent[0])) - (float(follower.z) + float(cab.extent[1]))
	check(float(follower.speed) < 0.05 and gap >= 1.5 and peak <= float(taxi.panic_brake) + 0.01,
			"a cross-street cab brakes to a stand behind another (gap %.2f m, peak %.2f m/s2), no instant stop" % [gap, peak])
	traffic._cross.clear()

	# WE TUNA PIANOS: one at a time, its legend on its body, busiest on New York's Moving Day.
	var piano := _kind(traffic, "piano_truck")
	check(not piano.is_empty() and bool(piano.solo) and (piano.signs as Array).size() == 4, "the piano truck is in the stock, solo, with its signwriting")
	var piano_index := -1
	for i in traffic._kinds.size():
		if str(traffic._kinds[i].id) == "piano_truck":
			piano_index = i
	traffic.clock_override = {"valid": true, "day": "wed", "month": 5, "day_of_month": 1, "year": 1929, "minute_of_day": 600.0}
	traffic._read_clock()
	var moving_day := traffic._kind_rate(piano)
	traffic.clock_override.day_of_month = 8
	traffic._read_clock()
	check(moving_day > traffic._kind_rate(piano) * 4.0, "Moving Day brings the piano truck out")
	traffic.clock_override.day_of_month = 1
	traffic._read_clock()
	traffic.stage([{"id": "piano_truck", "lane_west": true, "x": 6.0, "speed": 0.0}])
	var again := false
	for i in 4000:
		if traffic._pick() == piano_index:
			again = true
	check(not again, "while one piano truck is out, the lottery never sends another")
	var holder: Node3D = traffic._signs.get(piano_index)
	var body: Transform3D = traffic.trace.piano_truck[0]
	var legend := holder != null and holder.visible and holder.transform.is_equal_approx(body)
	var fits := true
	if holder != null:
		for i in holder.get_child_count():
			var label := holder.get_child(i) as Label3D
			var sign: Dictionary = piano.signs[i]
			var size := OrisonV2StreetTraffic.SIGN_FONT.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size) * label.pixel_size
			fits = fits and label.text == str(sign.text) and size.x <= float(sign.width) + 0.001 and size.y <= float(sign.height) + 0.001
	check(legend and fits and holder.get_child_count() == 4, "WE TUNA PIANOS rides on the truck as Label3D within its panels")
	traffic.stage([])
	check(holder != null and not holder.visible, "and goes with it")
	var picked := false
	for i in 4000:
		if traffic._pick() == piano_index:
			picked = true
	check(picked, "with the street clear, the piano truck can come again")
	traffic.tracing = false
	traffic.frozen = true
