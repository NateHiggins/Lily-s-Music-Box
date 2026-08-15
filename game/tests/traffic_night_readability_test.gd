extends Node
## T2d contract: traffic may paint one shared, soft reflection on the wet road.
## It may not buy realtime lights, shadow casters or a new object per vehicle.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	var traffic := StreetTraffic.new()
	add_child(traffic)
	traffic.build()
	traffic.set_process(false)
	_check("one bounded pool covers the useful wet-road reading distance",
			StreetTraffic.HEADLIGHT_POOL_LENGTH >= 4.5
			and StreetTraffic.HEADLIGHT_POOL_LENGTH <= 5.5
			and StreetTraffic.HEADLIGHT_POOL_WIDTH <= 1.6)
	_check("the reflection stays restrained rather than becoming a glowing lane",
			StreetTraffic.HEADLIGHT_POOL_ALPHA > 0.08
			and StreetTraffic.HEADLIGHT_POOL_ALPHA <= 0.18)
	_check("traffic owns exactly one shared headlight-reflection draw",
			traffic.find_children("TrafficWetHeadlightPools",
					"MultiMeshInstance3D", false, false).size() == 1
			and traffic._headlight_pools.multimesh.instance_count
					== StreetTraffic.MAX_VEHICLES)
	_check("the wet-road reflection is never a light or shadow caster",
			traffic._headlight_pools.cast_shadow
					== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and traffic._headlight_pools.find_children(
					"*", "Light3D", true, false).is_empty())
	_check("the road material is one procedural shader, not per-car textures",
			traffic._headlight_pools.multimesh.mesh.material is ShaderMaterial)

	var motor := _kind_index("motor_car")
	traffic._live = [
		_vehicle(motor, false, -3.0),
		_vehicle(motor, true, 7.0),
	]
	traffic._write_instances()
	_check("two road users remain two instances inside the one draw",
			traffic._headlight_pools.multimesh.visible_instance_count == 2
			and traffic._headlight_pool_origins.size() == 2)
	var east_origin: Vector3 = traffic._headlight_pool_origins[0]
	var west_origin: Vector3 = traffic._headlight_pool_origins[1]
	var length := float(StreetTraffic.KINDS[motor][1])
	var east_nose := GameBoot.b2g([-3.0 + length * 0.5,
			StreetTraffic.LANE_EAST, 0.035])
	var west_nose := GameBoot.b2g([7.0 - length * 0.5,
			StreetTraffic.LANE_WEST, 0.035])
	_check("eastbound reflection lands ahead of the eastbound nose",
			east_origin.x > east_nose.x)
	_check("westbound reflection lands ahead of the westbound nose",
			west_origin.x < west_nose.x)
	_check("both reflections skim the paving rather than floating",
			is_equal_approx(east_origin.y, 0.035)
			and is_equal_approx(west_origin.y, 0.035))

	traffic._live.clear()
	traffic._write_instances()
	_check("an empty street submits zero pool instances",
			traffic._headlight_pools.multimesh.visible_instance_count == 0)
	_check("crossing cadence and transit rules remain untouched",
			is_equal_approx(StreetTraffic.MAX_WAIT, 8.0)
			and is_equal_approx(StreetTraffic.GAP_SECONDS, 3.4)
			and is_equal_approx(StreetTraffic.TRANSIT_STOP_DWELL, 4.5))

	print("[TRAFFIC NIGHT READABILITY] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)


func _vehicle(kind: int, westbound: bool, x: float) -> Dictionary:
	return {"kind": kind, "lane": westbound,
			"dir": -1.0 if westbound else 1.0,
			"x": x, "speed": 5.0, "stop_stage": 0, "dwell": 0.0}


func _kind_index(label: String) -> int:
	for index in StreetTraffic.KINDS.size():
		if str(StreetTraffic.KINDS[index][0]) == label:
			return index
	return -1
