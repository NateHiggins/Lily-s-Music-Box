extends Node
## T5 proof: the restored south-pavement shelter is real collision, preserves
## both bypasses, provides local weather cover, and is served by the eastbound
## tram's one deterministic stop rather than merely implying a route.

const SHELTER_IDS := [
	"site_shelter_roof", "site_shelter_post0", "site_shelter_post42",
	"site_shelter_back", "site_shelter_mullion", "site_shelter_sill",
	"site_shelter_head", "site_shelter_bench",
]

var _fails := 0
var _space: PhysicsDirectSpaceState3D
var _capsule := CapsuleShape3D.new()
var _arrivals := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node3D = load(
			"res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	await get_tree().physics_frame
	_space = root.get_viewport().find_world_3d().direct_space_state
	_capsule.radius = PlayerController.BODY_RADIUS
	_capsule.height = 1.524

	var records := _shelter_records(root.layout)
	_check("all eight saved shelter source records returned",
			records.size() == SHELTER_IDS.size())
	_check("every shelter source record owns the bounded transit batch",
			records.size() == SHELTER_IDS.size()
			and records.values().all(func(record: Dictionary) -> bool:
				return record.get("batch", "") == "transit_shelter"))
	var roof: Dictionary = records.get("site_shelter_roof", {})
	var west_post: Dictionary = records.get("site_shelter_post0", {})
	var east_post: Dictionary = records.get("site_shelter_post42", {})
	_check("roof preserves the ruled 4.4 x 1.4 m footprint at 2.45 m",
			not roof.is_empty() and is_equal_approx(
			float(roof.rect[2]) - float(roof.rect[0]), 4.4)
			and is_equal_approx(float(roof.rect[3]) - float(roof.rect[1]), 1.4)
			and is_equal_approx(float(roof.z0), 2.45))
	_check("the two named posts are literal 100 mm rear corner posts, not fins",
			_post_is_literal(west_post) and _post_is_literal(east_post))
	_check("the production build has a physical roof",
			not _ray(GameBoot.b2g([-10.4, -26.25, 3.2]),
				GameBoot.b2g([-10.4, -26.25, 2.0])).is_empty())
	_check("the glazed back is physically present",
				not _ray(GameBoot.b2g([-10.4, -26.45, 1.2]),
				GameBoot.b2g([-10.4, -27.15, 1.2])).is_empty())
	var stop_sign := root.find_child("TransitShelterStopSign", true, false)
	_check("an in-world period stop sign identifies the served shelter",
			stop_sign is Label3D and stop_sign.text == "CARS STOP HERE")
	_check("the stop sign adds no realtime light",
			stop_sign != null and stop_sign.find_children(
			"*", "Light3D", true, false).is_empty())
	_check("the 1.66 m kerbside bypass remains capsule-clear",
			_not_stuck(GameBoot.b2g([-10.4, -24.72, 0.90])))
	_check("the 1.37 m rear bypass remains capsule-clear",
			_not_stuck(GameBoot.b2g([-10.4, -27.63, 0.90])))

	var under_roof := GameBoot.b2g([-10.4, -26.20, 0.03])
	_check("the shelter remains in the exposed STREET zone",
			root.weather_exposure_at(under_roof))
	_check("the exact shelter footprint supplies exterior cover",
			root.weather_cover_at(under_roof))
	root.player.global_position = under_roof
	await get_tree().process_frame
	await get_tree().process_frame
	var weather_state: Dictionary = root.weather.diagnostic_snapshot()
	_check("under-roof close rain and spatter suppress while far rain remains",
			weather_state.covered
			and not root.weather.get_node("DrivingRainSpatter").emitting
			and root.weather.get_node("DrivingRainMiddle").visible)
	root.player.global_position = GameBoot.b2g([-5.0, -26.20, 0.03])
	await get_tree().process_frame
	_check("leaving the canopy restores exposed close weather",
			root.weather.get_node("DrivingRainSpatter").emitting)

	var traffic: StreetTraffic = root.street_traffic
	traffic.set_process(false)
	traffic.transit_arrived.connect(_record_arrival)
	var tram_index := _kind_index("tram")
	_check("the serving vehicle is the authored tram", tram_index >= 0)
	traffic._live = [_vehicle(tram_index, false,
			StreetTraffic.TRANSIT_STOP_X - 1.0, 5.0)]
	traffic._advance(0.25)
	var stopped: Dictionary = traffic._live[0]
	_check("the eastbound tram stops at the shelter centre",
			is_equal_approx(float(stopped.x), StreetTraffic.TRANSIT_STOP_X)
			and int(stopped.stop_stage) == 1 and _arrivals == 1)
	traffic._advance(StreetTraffic.TRANSIT_STOP_DWELL - 0.10)
	_check("the tram holds for the complete boarding beat",
			is_equal_approx(float(traffic._live[0].x),
				StreetTraffic.TRANSIT_STOP_X))
	traffic._advance(0.20)
	_check("the served tram resumes east toward the storm mouth",
			float(traffic._live[0].x) > StreetTraffic.TRANSIT_STOP_X
			and int(traffic._live[0].stop_stage) == 2 and _arrivals == 1)

	traffic._live = [_vehicle(_kind_index("motor_car"), false,
			StreetTraffic.TRANSIT_STOP_X - 1.0, 5.0)]
	traffic._advance(0.25)
	_check("ordinary eastbound traffic does not fake a transit stop",
			float(traffic._live[0].x) > StreetTraffic.TRANSIT_STOP_X
			and int(traffic._live[0].stop_stage) == 0)
	traffic._live = [_vehicle(tram_index, true,
			StreetTraffic.TRANSIT_STOP_X + 1.0, 5.0)]
	traffic._advance(0.25)
	_check("westbound trams remain through service on the opposite lane",
			float(traffic._live[0].x) < StreetTraffic.TRANSIT_STOP_X
			and int(traffic._live[0].stop_stage) == 0)

	print("[TRANSIT SHELTER] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)


func _shelter_records(layout: Dictionary) -> Dictionary:
	var out := {}
	for floor: Dictionary in layout.floors:
		if str(floor.id) != "F01":
			continue
		for record: Dictionary in floor.furniture:
			if str(record.id) in SHELTER_IDS:
				out[record.id] = record
	return out


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collide_with_areas = false
	return _space.intersect_ray(query)


func _not_stuck(at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = 1
	query.collide_with_areas = false
	return _space.intersect_shape(query, 8).is_empty()


func _post_is_literal(record: Dictionary) -> bool:
	var rect: Array = record.get("rect", [])
	return rect.size() == 4 \
			and is_equal_approx(float(rect[2]) - float(rect[0]), 0.1) \
			and is_equal_approx(float(rect[3]) - float(rect[1]), 0.1) \
			and is_equal_approx(float(record.get("h", -99.0)), 2.45)


func _kind_index(label: String) -> int:
	for index in StreetTraffic.KINDS.size():
		if str(StreetTraffic.KINDS[index][0]) == label:
			return index
	return -1


func _vehicle(kind: int, westbound: bool, x: float,
		speed: float) -> Dictionary:
	return {"kind": kind, "lane": westbound,
			"dir": -1.0 if westbound else 1.0, "x": x, "speed": speed,
			"stop_stage": 0, "dwell": 0.0}


func _record_arrival(_stop_id: String, _vehicle_kind: String) -> void:
	_arrivals += 1
