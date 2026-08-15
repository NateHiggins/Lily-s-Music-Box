extends Node
## The WE TUNA PIANOS truck is an ordinary moving road user with one batched,
## non-emissive sign owner. It may be funny; it may not become a parked prop,
## realtime light, traffic-rule exception, or per-truck scene.

var _fails := 0


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
	var traffic: StreetTraffic = root.street_traffic
	traffic.set_process(false)
	var kind := StreetTraffic.PIANO_REPAIR_KIND
	var record: Array = StreetTraffic.KINDS[kind]
	_check("the authored kind resolves to the piano repair truck",
			str(record[0]) == "piano_repair")
	_check("the one-ton truck stays inside the traffic envelope",
			float(record[1]) <= 6.0 and float(record[2]) <= 2.1
			and float(record[3]) <= 2.3)
	_check("the truck is rare but can be selected by ordinary traffic",
			float(record[4]) > 0.0 and float(record[4]) <= 2.0)
	_check("the approved sign is a production texture",
			ResourceLoader.exists(StreetTraffic.PIANO_REPAIR_SIGN))
	var texture := load(StreetTraffic.PIANO_REPAIR_SIGN) as Texture2D
	_check("the complete painted advertisement imports at useful resolution",
			texture != null and texture.get_width() >= 1024
			and texture.get_height() >= 680)

	traffic._live = [
			_vehicle(kind, false, -3.0, 5.4),
			_vehicle(kind, true, 7.0, 4.8),
	]
	traffic._write_instances()
	await get_tree().process_frame
	_check("two trucks share one sign draw owner and four panel instances",
			traffic.find_children("*", "MultiMeshInstance3D", false, false).size()
					== 5
			and traffic._piano_signs.multimesh.visible_instance_count == 4)
	_check("the painted panels are dull geometry, not lights or shadow casters",
			traffic._piano_signs.cast_shadow
					== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and traffic._piano_signs.find_children(
					"*", "Light3D", true, false).is_empty())
	var south: Vector3 = traffic._piano_sign_origins[0]
	var north: Vector3 = traffic._piano_sign_origins[1]
	print("    panel origins south=%s north=%s" % [south, north])
	_check("each box carries the sign on both physical side faces",
			is_equal_approx(south.x, north.x)
			and absf(south.z - north.z) > 2.0)

	var east_before: float = float(traffic._live[0].x)
	var west_before: float = float(traffic._live[1].x)
	traffic._advance(0.5)
	_check("the branded truck obeys ordinary two-way motion",
			float(traffic._live[0].x) > east_before
			and float(traffic._live[1].x) < west_before)
	_check("the trade truck never fakes the tram's shelter stop",
			int(traffic._live[0].stop_stage) == 0
			and int(traffic._live[1].stop_stage) == 0)

	traffic._live = [_vehicle(_kind_index("motor_car"), false, 0.0, 5.0)]
	traffic._write_instances()
	_check("ordinary traffic pays no visible sign instances",
			traffic._piano_signs.multimesh.visible_instance_count == 0)
	_check("crossing promises and first-shift arrival remain unchanged",
			is_equal_approx(StreetTraffic.MAX_WAIT, 8.0)
			and is_equal_approx(StreetTraffic.GAP_SECONDS, 3.4)
			and StreetTraffic.ARRIVAL_START_X == -4.50)

	print("[PIANO REPAIR TRUCK] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)


func _vehicle(kind: int, westbound: bool, x: float, speed: float) -> Dictionary:
	return {"kind": kind, "lane": westbound,
			"dir": -1.0 if westbound else 1.0,
			"x": x, "speed": speed, "stop_stage": 0, "dwell": 0.0}


func _kind_index(label: String) -> int:
	for index in StreetTraffic.KINDS.size():
		if str(StreetTraffic.KINDS[index][0]) == label:
			return index
	return -1
