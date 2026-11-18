extends Node
## Headless contract for the trolley line (design/V2_STREET_TRAMS_2026-11-08.md): the cars are period traffic on
## a fixed path, the rails and wire lie on that path, the line runs to its headway, never by the street's
## lottery, and arcs come more often on aurora nights and in the wet, and gently under reduced flashing.
const DT := 1.0 / 30.0

var failures := 0
var checks := 0


class FakeSky:
	extends Node
	var current: Dictionary = {}
	func weather_conditions() -> Dictionary:
		return current


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("TRAM CHECK: ", label, " = ", ok)


func _nearest(points: Array, at: Vector3) -> float:
	var best := INF
	for p: Vector3 in points:
		best = minf(best, Vector2(p.x - at.x, p.z - at.z).length())
	return best


func _run() -> void:
	var person := Node3D.new()
	add_child(person)
	person.position = Vector3(0, 0, -50)
	var sky := FakeSky.new()
	add_child(sky)
	var traffic := OrisonV2StreetTraffic.new()
	check(traffic.configure(person, 1929), "traffic configures from its table")
	traffic.clock_override = {"valid": true, "day": "fri", "month": 11, "day_of_month": 8, "year": 1929, "minute_of_day": 480.0}
	var line := OrisonV2StreetTrams.attach(traffic, sky)
	check(line != null, "the line attaches to the traffic from its generated table and stock")
	if line == null:
		get_tree().quit(1)
		return
	add_child(traffic)
	add_child(line)
	traffic.stage([])
	traffic._read_clock()
	check(not traffic.startup_failed and traffic._batches.has("tram_car"), "the car is drawn by the traffic's own batches")
	var kind: Dictionary = traffic._kinds[line.kind_index]
	check(bool(kind.get("rail", false)) and str(kind["class"]) == "tram", "the car is a rail kind of the tram class")

	# The lottery never sends a tram; the line does.
	var picked := false
	for i in 3000:
		if traffic._pick() == line.kind_index:
			picked = true
	check(not picked, "the street's lottery never picks a tram")

	# The path: in from a far-side cross street, along the avenue in its lane, out up the other.
	var junctions: Dictionary = traffic.data.junctions
	var far_kerb := float(line.data.far_kerb_z)
	for track in 2:
		var points: Array = line.paths[track]
		var lane_z := float(traffic.data.site.lane_west_z) if track == 0 else float(traffic.data.site.lane_east_z)
		var first: Vector3 = points[0]
		var last: Vector3 = points[points.size() - 1]
		check(first.z > far_kerb + 40.0 and last.z > far_kerb + 40.0, "track %d begins and ends up a far-side cross street" % track)
		var gap := 0.0
		var on_lane := true
		for i in points.size() - 1:
			gap = maxf(gap, (points[i] as Vector3).distance_to(points[i + 1]))
			var p: Vector3 = points[i]
			if absf(p.x) < 40.0 and absf(p.z - lane_z) > 0.02:
				on_lane = false
		check(gap < 1.3, "track %d is continuous (largest step %.2f m)" % [track, gap])
		check(on_lane, "track %d runs down the middle of its lane on the avenue" % track)
		var eastward: bool = first.x < last.x
		check(eastward == (track == 1), "track %d runs %s" % [track, "east" if track == 1 else "west"])
		check(absf(absf(first.x) - absf(float(junctions.west_x if track == 1 else junctions.east_x))) < 3.0,
				"track %d comes in at the %s junction" % [track, "west" if track == 1 else "east"])

	# A car follows its rails the whole way, round both corners, and leaves.
	for track in 2:
		traffic._live.clear()
		traffic._live.append(traffic.rail_journey(line.kind_index, track == 0))
		var worst := 0.0
		var seconds := 0.0
		while not traffic._live.is_empty() and seconds < 240.0:
			traffic._advance(DT)
			seconds += DT
			if traffic._live.is_empty():
				break
			var pose := traffic._world_pose(traffic._live[0])
			worst = maxf(worst, _nearest(line.paths[track], Vector3(float(pose[0]), 0.0, float(pose[1]))))
		check(traffic._live.is_empty(), "a car on track %d completes its run (%.0f s)" % [track, seconds])
		check(worst < 0.6, "the car on track %d stays on its rails (worst %.2f m off)" % [track, worst])

	# Sharing the road: a slow wagon ahead in the lane, and the car never passes through it.
	traffic._live.clear()
	traffic.stage([{"id": "ice_wagon", "lane_west": false, "x": -20.0, "speed": 0.0}])
	var tram := traffic.rail_journey(line.kind_index, false)
	tram.phase = "street"
	tram.p = -45.0
	tram.speed = 5.0
	traffic._live.append(tram)
	var clear := true
	for i in 300:
		traffic._advance(DT)
		var wagon: Dictionary = {}
		for v: Dictionary in traffic._live:
			if int(v.kind) != line.kind_index:
				wagon = v
		if wagon.is_empty() or str(wagon.phase) != "street" or str(tram.phase) != "street":
			break
		var wagon_back := float(wagon.p) + float(traffic._kinds[int(wagon.kind)].extent[0])
		if float(tram.p) + float(kind.extent[1]) > wagon_back + 0.01:
			clear = false
	check(clear, "the car follows a slow wagon and never drives through it")

	# Headway: the morning rush, about one car every four minutes each way.
	traffic._live.clear()
	line._due = [0.0, 0.0]
	var spawned := 0
	for i in int(30.0 * 60.0 / 0.5):
		var before := line.live_cars().size()
		line.spawn_step(0.5)
		spawned += line.live_cars().size() - before
		traffic._live.clear()
	check(spawned >= 12 and spawned <= 19, "the rush-hour line sends %d cars in 30 minutes, both ways (want about 15)" % spawned)

	# Arcs: more under the aurora and in the wet.
	var base := line.arc_rate()
	sky.current = {"phenomena": [{"id": "aurora", "level": 1.0}]}
	var aurora := line.arc_rate()
	sky.current = {"phenomena": [{"id": "steve", "level": 1.0}], "wet": true}
	var steve_wet := line.arc_rate()
	sky.current = {}
	check(absf(aurora / base - float(line.data.arcs.aurora_multiplier)) < 0.01, "aurora nights multiply the arcs (%.1f to %.1f a minute)" % [base, aurora])
	check(absf(steve_wet / base - float(line.data.arcs.aurora_multiplier) * float(line.data.arcs.wet_multiplier)) < 0.01, "STEVE and wet rails multiply together")

	# A flash sits at the trolley wheel, on the wire.
	traffic._live.clear()
	var car := traffic.rail_journey(line.kind_index, true)
	car.phase = "street"
	car.p = 0.0
	car.speed = 5.0
	traffic._live.append(car)
	check(line.flash(car), "a car's trolley wheel can flash")
	var lit: Dictionary = {}
	for f: Dictionary in line._flashes:
		if float(f.left) > 0.0:
			lit = f
	var wire_y := float(traffic.data.site.road_y) + float(line.data.line.wire_height_m)
	var spark: MeshInstance3D = lit.get("spark")
	check(spark != null and absf(spark.position.y - wire_y) < 0.25, "the flash is at the wire (y %.2f, wire %.2f)" % [spark.position.y if spark else 0.0, wire_y])
	var reduce := bool(GameBoot.settings.get("reduce_flashing", false))
	GameBoot.settings["reduce_flashing"] = true
	for f: Dictionary in line._flashes:
		f.left = 0.0
	var first_soft := line.flash(car)
	var second_soft := line.flash(car)
	check(first_soft and not second_soft, "reduced flashing allows one soft glow, then a quiet spell")
	GameBoot.settings["reduce_flashing"] = reduce

	# The overhead: poles, a rosette on the Orison's brick, and every span above both wires.
	for i in 3:
		await get_tree().physics_frame
	await get_tree().process_frame
	check(line.built, "the overhead is raised")
	var poles := line.get_node_or_null("TrolleyPoles") as MultiMeshInstance3D
	var rosettes := line.get_node_or_null("TrolleyRosettes") as MultiMeshInstance3D
	check(poles != null and poles.multimesh.instance_count >= 9, "the span poles stand (%d)" % (poles.multimesh.instance_count if poles else 0))
	check(rosettes != null and rosettes.multimesh.instance_count == 1, "one rosette on the Orison's facade")
	check(line.get_node_or_null("TrolleyWire") != null and line.get_node_or_null("TramRails") != null, "wire and rails are laid")
	var supports: Array = line.data.supports
	for s: Dictionary in supports:
		check(absf(float(s.x)) > 6.0 or str(s.near) == "rosette", "support at x %.0f leaves the door clear" % float(s.x))
		check(absf(float(s.x) - 14.0) > 3.0 and absf(float(s.x) - 8.1) > 2.0 and absf(float(s.x) - 13.3) > 2.0 and absf(float(s.x) + 9.6) > 2.0,
				"support at x %.0f keeps clear of the lamps and the crossing" % float(s.x))

	print("STREET TRAMS: %s; %d checks; %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
