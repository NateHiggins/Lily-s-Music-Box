extends "res://tests/orison_v2_public_doors_test.gd"
## The house gas service: the meter counts what the fittings burn, the mains
## pressure dims the mantles at the evening peak, the company cock is sealed,
## and residents turn the vestibule gas down and up only out of the player's
## sight, on their own timetables. Captures the meter for review.
const BRACKET := "F01_VESTIBULE_GAS_BRACKET"

func _init() -> void: route_label="HOUSE GAS SERVICE"

func _route() -> void:
	var service:=world.adapter.resolve("F01_GAS_METER") as OrisonV2GasService
	var bracket:=world.adapter.resolve(BRACKET) as OrisonV2GasFitting
	if service==null or bracket==null:
		failures.append("gas meter or bracket is not uniquely resolvable");return
	if world.household_state.snapshot().records.get("F01_GAS_METER",{}).get("kind")!="mechanism":
		failures.append("meter index is not in the household save");return
	var operable:=service.find_children("ManipulationTarget","",true,false).filter(func(n: Node): return not service.carton.is_ancestor_of(n))
	if operable.size()>0 or service.has_method("manipulation_target"):
		failures.append("the company's sealed cock must not be operable");return
	# The meter reads an hour of what the fittings actually burn.
	var info:={"valid":true,"month":11,"day":"tue","doy":325,"first_sat":false,"minute_of_day":1260.0,"absolute_minutes":500000.0}
	service.clock_override=info.duplicate()
	await get_tree().process_frame
	await get_tree().process_frame
	var rate:=0.0
	for fitting: OrisonV2GasFitting in service.fittings:rate+=fitting.gas_rate()
	var before:=service.cubic_feet
	var test_hand:=service.hands[0].rotation.z
	service.clock_override.absolute_minutes=500060.0
	await get_tree().process_frame
	if absf(service.cubic_feet-before-rate)>0.001 or is_equal_approx(service.hands[0].rotation.z,test_hand):
		failures.append("meter did not read an hour's burn: %s for %s" % [service.cubic_feet-before,rate]);return
	# Mains pressure: the evening peak dims the full mantle, the small hours lift it.
	bracket.set_opening(1.0)
	service.refresh({"valid":true,"month":11,"minute_of_day":1140.0})
	var peak:=bracket.brightness()
	service.refresh({"valid":true,"month":11,"minute_of_day":180.0})
	var night:=bracket.brightness()
	if not (peak<0.85 and night>1.0 and is_equal_approx(bracket.mantle(),1.0)):
		failures.append("pressure does not dim the evening peak: %s / %s" % [peak,night]);return
	# Residents: never within the player's sight range.
	var far: Vector3=world.adapter.root.to_global(Vector3(2.0,0,1.5))
	var near: Vector3=world.adapter.root.to_global(Vector3(0,0,-8.6))
	player.global_position=near
	service.place_override={"evelyn_marsh":"lobby"}
	service.refresh({"valid":true,"month":11,"day":"wed","doy":326,"minute_of_day":540.0})
	if not is_equal_approx(bracket.opening,1.0):
		failures.append("a resident turned the gas down in the player's sight");return
	player.global_position=far
	service.refresh({"valid":true,"month":11,"day":"wed","doy":326,"minute_of_day":545.0})
	if bracket.opening>0.01:
		failures.append("Evelyn's morning round did not turn the vestibule gas down");return
	if float(world.household_state.snapshot().records[BRACKET].value.cock)>0.01:
		failures.append("the resident's turn is not in the household save");return
	service.place_override={"cam_ortiz":"lobby"}
	service.refresh({"valid":true,"month":11,"day":"wed","doy":326,"minute_of_day":600.0})
	if bracket.opening>0.01:
		failures.append("the evening resident acted by daylight");return
	service.refresh({"valid":true,"month":11,"day":"wed","doy":326,"minute_of_day":1085.0})
	if not is_equal_approx(bracket.opening,1.0):
		failures.append("Cam's evening pass did not turn the vestibule gas up");return
	service.place_override={}
	service.clock_override={}
	player.set_physics_process(false)
	await _meter_view("gas_meter_workroom",Vector3(7.0,1.55,-11.0),Vector3(7.95,1.15,-12.2))
	await _meter_view("gas_meter_index",Vector3(7.92,1.25,-11.62),Vector3(7.92,1.2,-12.05))
	await _meter_view("gas_service_cock",Vector3(8.0,0.95,-11.8),Vector3(7.71,0.5,-12.24))
	player.set_physics_process(true)
	print("HOUSE GAS SERVICE: meter reads the burn, pressure dims the peak, cock sealed, residents act out of sight on their timetables")

func _meter_view(label: String, at: Vector3, target: Vector3) -> void:
	player.camera.global_position=world.adapter.root.to_global(at)
	player.camera.look_at(world.adapter.root.to_global(target))
	for i in 8:await RenderingServer.frame_post_draw
	await _capture(label)
