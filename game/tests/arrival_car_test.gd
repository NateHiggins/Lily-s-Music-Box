extends Node
## T6 proof: the first shift is delivered on the south kerb, the car occupies
## one ordinary traffic slot, holds, merges east and disappears through the
## authored storm boundary. It cannot replay or leave static collision behind.

var _fails := 0
var _weather_entries := 0
var _departures := 0


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
	traffic.arrival_entered_weather.connect(_on_weather_entry)
	traffic.arrival_departed.connect(_on_departure)
	_check("production traffic binds the player created later in BuildingRoot",
			traffic._player == root.player)
	_check("the retired static arrival hull remains absent",
			root.find_child("ArrivalRideshareCollision", true, false) == null)

	var began: bool = root.first_shift_director.begin_first_shift()
	_check("the real first-shift owner starts the arrival exactly once", began)
	_check("the player begins on the south kerb beside the passenger cab",
			root.player.global_position.distance_to(GameBoot.b2g([
			FirstShiftDirector.ARRIVAL_POSITION_B.x,
			FirstShiftDirector.ARRIVAL_POSITION_B.y,
			FirstShiftDirector.ARRIVAL_POSITION_B.z])) < 0.01)
	_check("the one-shot fact commits through existing intro state",
			bool(RealityState.data.get("intro_complete", false)))
	_check("arrival replaces random startup clutter with one motor car",
			traffic._live.size() == 1
			and bool(traffic._live[0].get("arrival", false))
			and str(StreetTraffic.KINDS[int(traffic._live[0].kind)][0])
					== "motor_car")
	_check("arrival submits only the four baseline traffic batches",
			traffic._mm.multimesh.visible_instance_count == 1
			and traffic._cabs.multimesh.visible_instance_count == 1
			and traffic._wheels.multimesh.visible_instance_count == 4
			and traffic._lamps.multimesh.visible_instance_count == 2
			and traffic._piano_signs.multimesh.visible_instance_count == 0)

	var start_x: float = float(traffic._live[0].x)
	traffic._advance(StreetTraffic.ARRIVAL_HOLD_SECONDS - 0.05)
	_check("the car holds while the player reads the first frame",
			is_equal_approx(float(traffic._live[0].x), start_x)
			and is_zero_approx(float(traffic._live[0].speed)))
	traffic._advance(0.10)
	_check("the car then accelerates east and merges off the kerb",
			float(traffic._live[0].x) > start_x
			and float(traffic._live[0].speed) > 0.0
			and float(traffic._live[0].y) > StreetTraffic.ARRIVAL_KERB_Y)

	var guard := 0
	while not traffic._live.is_empty() \
			and float(traffic._live[0].x) < StreetTraffic.EAST_TEAR_X \
			and guard < 200:
		traffic._advance(0.10)
		guard += 1
	_check("the moving car crosses the exact east weather boundary once",
			_weather_entries == 1 and not traffic._live.is_empty()
			and bool(traffic._live[0].weather_entered))
	while not traffic._live.is_empty() and guard < 300:
		traffic._advance(0.10)
		guard += 1
	traffic._write_instances()
	_check("the storm consumes the car instead of parking it forever",
			traffic._live.is_empty() and _departures == 1
			and traffic._mm.multimesh.visible_instance_count == 0)
	_check("neither lifecycle owner can replay the completed arrival",
			not traffic.begin_arrival()
			and not root.first_shift_director.begin_first_shift())

	traffic._spawn_accum = 0.0
	traffic._spawn(0.1)
	_check("ordinary two-way traffic resumes after the one-shot",
			traffic._live.size() == 1
			and not bool(traffic._live[0].get("arrival", false)))

	print("[ARRIVAL CAR] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)


func _on_weather_entry() -> void:
	_weather_entries += 1


func _on_departure() -> void:
	_departures += 1
