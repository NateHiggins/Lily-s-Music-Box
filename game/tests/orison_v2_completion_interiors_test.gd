extends "res://tests/orison_v2_roof_route_test.gd"
## Each home has one initial hall placement, then actual walking and E input.

func _init() -> void:
	route_label="COMPLETION INTERIORS"

func _prepare_player_start() -> void:
	player.global_position=world.adapter.root.to_global(Vector3(2.3,.02,-3.5))
	player.velocity=Vector3.ZERO

func _route() -> void:
	var unit_filter:=OS.get_environment("V2_TEST_UNIT")
	if unit_filter.is_empty() or unit_filter == "1D":
		if not await _teresa_route(): return
	for unit: String in ["1A","3D","4D"]:
		if not unit_filter.is_empty() and unit_filter!=unit: continue
		var floor_index:=int(unit[0])-1
		var y:=float(floor_index)*3.2
		var prefix: String="F0"+unit[0]+"_"+unit[1]+"_"
		player.global_position=world.adapter.root.to_global(Vector3(-4.5,y+.02,-5.1))
		player.velocity=Vector3.ZERO
		await get_tree().physics_frame
		if not await _open_door(prefix+"ENTRY_DOOR"): return
		if not await _walk(Vector3(-6.8,y,-5.1)): return
		if not await _open_door(prefix+"VESTIBULE_MAIN_DOOR"): return
		for point in [Vector3(-9.1,y,-5.1),Vector3(-13.5,y,-5.7)]:
			if not await _walk(point): return
		if not await _open_door(prefix+"MAIN_BED_DOOR"): return
		for point in [Vector3(-13.5,y,-8),Vector3(-12.4,y,-10)]:
			if not await _walk(point): return
		await _roof_capture(unit+"_bedroom",Vector3(-14,y+1,-10.8))
		if not await _walk(Vector3(-12.25,y,-10.8)): return
		if not await _open_door(prefix+"BED_STORAGE_DOOR"): return
		if not await _walk(Vector3(-9.7,y,-10.8)): return
		await _roof_capture(unit+"_storage",Vector3(-9.7,y+1,-12))
		if not await _walk(Vector3(-12.25,y,-10.8)): return
		for point in [Vector3(-13.5,y,-8),Vector3(-13.5,y,-5.7),Vector3(-9.6,y,-5.7)]:
			if not await _walk(point): return
		if not await _open_door(prefix+"MAIN_KITCHEN_DOOR"): return
		if not await _walk(Vector3(-9.6,y,-8.2)): return
		if not await _use_water_valves("F0"+unit[0]+"_"+unit+"_KITCHEN_SINK_01"): return
		for point in [Vector3(-9.2,y,-8.3),Vector3(-7.3,y,-8.3),Vector3(-6.8,y,-8.3)]:
			if not await _walk(point): return
		if not await _open_door(prefix+"PRIVATE_HALL_BATH_DOOR"): return
		for point in [Vector3(-6.8,y,-10.3),Vector3(-7.35,y,-10.9)]:
			if not await _walk(point): return
		if not await _use_water_valves("F0"+unit[0]+"_"+unit+"_SINK_01"): return
		await _roof_capture(unit+"_bathroom",Vector3(-6.9,y+1,-11.8))
		for point in [Vector3(-6.8,y,-10.3),Vector3(-6.8,y,-8.1)]:
			if not await _walk(point): return
		if not await _open_door(prefix+"VESTIBULE_PRIVATE_HALL_DOOR"): return
		for point in [Vector3(-6.8,y,-5.1),Vector3(-4.5,y,-5.1)]:
			if not await _walk(point): return
	for unit: String in ["2C","4C"]:
		if not unit_filter.is_empty() and unit_filter!=unit: continue
		var y:=float(int(unit[0])-1)*3.2
		var prefix: String="F0"+unit[0]+"_C_"
		player.global_position=world.adapter.root.to_global(Vector3(-.85,y+.02,2.7))
		player.velocity=Vector3.ZERO
		await get_tree().physics_frame
		if not await _open_door(prefix+"ENTRY_DOOR"): return
		for point in [Vector3(-.85,y,5.3),Vector3(-.85,y,7.1),Vector3(-4,y,7.1),Vector3(-4,y,5.5)]:
			if not await _walk(point): return
		await _roof_capture(unit+"_household_storage",Vector3(-4,y+1,4.3))
		for point in [Vector3(-4,y,7.1),Vector3(-.85,y,7.1),Vector3(2.1,y,7.1)]:
			if not await _walk(point): return
		if not await _open_door(prefix+"PRIVATE_HALL_BATH_DOOR"): return
		for point in [Vector3(2.1,y,5.55),Vector3(1.05,y,5.1)]:
			if not await _walk(point): return
		if not await _use_water_valves("F0"+unit[0]+"_"+unit+"_SINK_01"): return
		for point in [Vector3(2.1,y,5.55),Vector3(2.1,y,7.1),Vector3(5.4,y,7.1)]:
			if not await _walk(point): return
		if not await _open_door(prefix+"PRIVATE_HALL_KITCHEN_DOOR"): return
		for point in [Vector3(5.4,y,5.5),Vector3(4.85,y,4.9)]:
			if not await _walk(point): return
		if not await _use_water_valves("F0"+unit[0]+"_"+unit+"_KITCHEN_SINK_01"): return
		for point in [Vector3(5.4,y,5.5),Vector3(5.4,y,7.1),Vector3(2.1,y,7.1)]:
			if not await _walk(point): return
		if not await _open_door(prefix+"PRIVATE_HALL_BED1_DOOR"): return
		if not await _walk(Vector3(2.5,y,9)): return
		await _roof_capture(unit+"_bedroom",Vector3(1.4,y+1,10.5))
		for point in [Vector3(2.1,y,7.1),Vector3(5.4,y,7.1)]:
			if not await _walk(point): return
		if not await _open_door(prefix+"PRIVATE_HALL_BED2_DOOR"): return
		if not await _walk(Vector3(5.4,y,9)): return
		await _roof_capture(unit+"_second_bedroom",Vector3(6,y+1,10.5))
		if not await _walk(Vector3(5.4,y,7.1)): return
		for point in [Vector3(2.1,y,7.1),Vector3(-.85,y,7.1),Vector3(-.85,y,5.3),Vector3(-.85,y,2.7)]:
			if not await _walk(point): return
	if unit_filter.is_empty() or unit_filter=="staff":
		player.global_position=world.adapter.root.to_global(Vector3(8.95,.02,-5.45))
		player.velocity=Vector3.ZERO
		await get_tree().physics_frame
		if not await _open_door("F01_STAFF_RESTROOM_DOOR"): return
		for point in [Vector3(7.1,0,-5.45),Vector3(6.1,0,-6.8)]:
			if not await _walk(point): return
		if not await _use_water_valves("F01_STAFF_SINK"): return
		await _roof_capture("staff_restroom",Vector3(7,1,-7.7))
		for point in [Vector3(7.1,0,-5.45),Vector3(8.95,0,-5.45)]:
			if not await _walk(point): return

func _teresa_route() -> bool:
	player.global_position = world.adapter.root.to_global(Vector3(8.55,.02,-3.25))
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/v2_apartment_door_routes.json"))
	var entered := false
	for step: Dictionary in route.steps:
		if step.get("open", "") == "F02_B_ENTRY_DOOR": entered = true
		if not entered: continue
		if step.has("walk"):
			if not await _walk(Vector3(step.walk[0],0,step.walk[1])): return false
			if Vector2(step.walk[0],step.walk[1]).is_equal_approx(Vector2(11.4,-6.24)):
				if not await _walk(Vector3(11.1,0,-7.3)): return false
				if not await _use_water_valves("F01_1D_KITCHEN_SINK_01"): return false
				if not await _walk(Vector3(11.4,0,-6.24)): return false
			if Vector2(step.walk[0],step.walk[1]).is_equal_approx(Vector2(14.24,-10.6)):
				if not await _walk(Vector3(14.4,0,-10.05)): return false
				if not await _use_water_valves("F01_1D_SINK_01"): return false
				await _roof_capture("1D_bathroom", Vector3(15.3,1,-11.3))
				if not await _walk(Vector3(14.24,0,-10.6)): return false
		elif step.has("open"):
			if not await _open_door(str(step.open).replace("F02_B_","F01_D_")): return false
		else:
			if not await _close_door(str(step.close).replace("F02_B_","F01_D_")): return false
	return true
