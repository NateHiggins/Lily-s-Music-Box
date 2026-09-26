extends "res://tests/orison_v2_roof_route_test.gd"
## Initial placement only; input entry, real moving-platform rides and exit.

func _init() -> void:
	route_label = "V2 ELEVATOR ROUTE"

func _prepare_player_start() -> void:
	player.global_position = world.adapter.root.to_global(Vector3(2.3,.02,-3.5))
	player.velocity = Vector3.ZERO

func _route() -> void:
	var lift := world.elevator as OrisonElevator
	if not _require(lift != null and lift.stops.size() == 7, "production lift serves B1 through F06"): return
	for point in [Vector3(1.5,0,-3.4),Vector3(0,0,-3.4),Vector3(0,.12,-1.65)]:
		if not await _walk(point): return
	for floor_name: String in ["F02","F03","F04","F05","F06","B1","F01"]:
		var button: Area3D
		for child: Node in lift._cabin.get_children():
			if child is Area3D and child.get_meta("cabin_floor", "") == floor_name: button = child
		if not _require(button != null, "cab button exists " + floor_name): return
		if not await _use(button,button.global_position,"lift_select_"+floor_name): return
		var deadline := Time.get_ticks_msec()+30000
		while lift.moving and Time.get_ticks_msec()<deadline:
			await get_tree().physics_frame
			var local: Vector3 = world.adapter.root.to_local(player.global_position)
			if absf(local.x)>=.5 or local.z<= -2.5 or local.z>=-.8:
				_require(false,"player left moving cabin at " + str(local))
				return
		var target_y: float = lift.stops[floor_name]
		var at: Vector3 = world.adapter.root.to_local(player.global_position)
		if not _require(not lift.moving and lift.current==floor_name and absf(at.y-target_y-.12)<.08,
				"moving cabin carried player to " + floor_name + " at " + str(at)): return
		if not await _walk(Vector3(0,target_y,-3.4)): return
		await _roof_capture("lift_landing_"+floor_name,Vector3(0,target_y+1.2,-1.6))
		if floor_name not in ["B1","F01"]:
			# A ride must lead into the real apartment halls, not just leave the
			# player standing in front of a car surrounded by impassable walls.
			for point in [Vector3(-1.75,target_y,-3.4),Vector3(-1.75,target_y,0),
					Vector3(-.85,target_y,2.7),Vector3(-1.75,target_y,0),Vector3(-4.5,target_y,0)]:
				if not await _walk(point): return
			if floor_name in ["F02","F03","F04"]:
				if not await _walk(Vector3(-4.5,target_y,-5.1)): return
				if not await _walk(Vector3(-4.5,target_y,0)): return
			for point in [Vector3(-1.75,target_y,0),Vector3(-1.75,target_y,-3.4),Vector3(0,target_y,-3.4)]:
				if not await _walk(point): return
		if floor_name=="F06":
			# Move the empty car away, then challenge the actual closed landing
			# barrier with the live controller before recalling through its plate.
			lift.travel_to("F05")
			while lift.moving: await get_tree().physics_frame
			var toward: Vector3 = world.adapter.root.global_basis * Vector3.BACK
			player.rotation.y=atan2(-toward.x,-toward.z)
			player.camera.rotation=Vector3.ZERO
			Input.action_press("move_forward")
			await get_tree().create_timer(.8).timeout
			Input.action_release("move_forward")
			at=world.adapter.root.to_local(player.global_position)
			if not _require(at.z< -2.98 and absf(at.y-target_y)<.08,"empty shaft remains closed to player"): return
			if not await _walk(Vector3(-.7,target_y,-3.45)): return
			var call_button: Area3D
			for child: Node in lift.get_children():
				if child is Area3D and child.get_meta("call_level","")==floor_name: call_button=child
			if not _require(call_button!=null,"F06 call plate exists"): return
			if not await _use(call_button,call_button.global_position,"lift_recall"): return
			while lift.moving: await get_tree().physics_frame
			if not await _walk(Vector3(0,target_y,-3.4)): return
		if floor_name!="F01" and not await _walk(Vector3(0,target_y+.12,-1.65)): return
	_require(player.is_on_floor() and not player.noclip,"lift circuit ends standing in F01 hall")
