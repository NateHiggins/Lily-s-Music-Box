extends "res://tests/orison_v2_gas_cock_test.gd"
## Gas mantles wear out and are renewed by hand (RUL-013): a worn bracket
## mantle breaks to a naked flame; the player lifts the workroom carton's lid
## for a spare, slides the bracket's shade down (the ash crumbles), slides it
## back with the spare (a new mantle is hung and the spare consumed), and the
## household save holds it all. The lantern's door swings out on its post and
## shut again; with no spare in hand its bare burner stays bare.

func _init() -> void: route_label="GAS MANTLE RENEWAL"

func _route() -> void:
	var bracket:=world.adapter.resolve(BRACKET) as OrisonV2GasFitting
	var lantern:=world.adapter.resolve(LANTERN) as OrisonV2GasFitting
	var carton:=world.adapter.resolve("F01_GAS_MANTLE_CARTON") as OrisonV2MantleCarton
	if bracket==null or lantern==null or carton==null:
		failures.append("mantle owners are not uniquely resolvable");return
	if world.household_state.snapshot().records.get(str(carton.name),{}).get("kind")!="mechanism":
		failures.append("carton lid is not in the household save");return
	if carton.remaining()!=12 or not carton.carried().is_empty():
		failures.append("the carton does not start with a full dozen");return
	# Wear: the last hour of a worn mantle's life breaks it.
	bracket.set_opening(1.0)
	var lit:=bracket.brightness()
	bracket.mantle_hours=bracket.mantle_life-0.5
	bracket.burn(60.0)
	if bracket.mantle_state!="broken" or bracket.brightness()>lit*0.25 or not bracket.flame_mesh.visible \
			or bracket.mantle_mesh.visible or not bracket.broken_mesh.visible:
		failures.append("a spent mantle does not break to a naked flame");return
	for point in [Vector3(1.925,0,-6.5),Vector3(0,0,-8.6),Vector3(0,0,-9.85)]:
		if not await _walk(point):return
	player.face_world_point(bracket.flame_mesh.global_position)
	for i in 4:await RenderingServer.frame_post_draw
	await _capture("bracket_broken")
	# The carton: walk into the workroom and lift the lid.
	for point in [Vector3(0,0,-8.6),Vector3(4.85,0,-8.6),Vector3(4.85,0,-9.9),Vector3(4.6,0,-10.7),Vector3(6.4,0,-10.7),Vector3(7.55,0,-11.25)]:
		if not await _walk(point):return
	if not await _grab_to(carton.lid_part,carton.to_global(Vector3(0,0.075,0.07)),1.5):return
	if carton.carried()!="gas_mantle_01" or carton.remaining()!=11:
		failures.append("lifting the lid did not give one spare mantle");return
	await _capture("carton_open")
	if not await _grab_to(carton.lid_part,carton.lid_part.to_global(Vector3(0,0.004,0.15)),0.0):return
	if carton.remaining()!=11:
		failures.append("the carton gave a second spare while one is in hand");return
	# Back to the bracket: shade down, ash crumbles; shade up, spare hung.
	for point in [Vector3(6.4,0,-10.7),Vector3(4.6,0,-10.7),Vector3(4.85,0,-9.9),Vector3(4.85,0,-8.6),Vector3(0,0,-8.6),Vector3(0,0,-9.85)]:
		if not await _walk(point):return
	var rim:=func(): return bracket.access_part.to_global(Vector3(0.066,-0.09,0))
	if not await _grab_to(bracket.access_part,rim.call(),0.08):return
	if bracket.mantle_state!="bare" or bracket.broken_mesh.visible:
		failures.append("opening the shade did not crumble the spent ash");return
	await _capture("bracket_bare")
	if not await _grab_to(bracket.access_part,rim.call(),0.0):return
	if bracket.mantle_state!="intact" or bracket.mantle_number!=1 or bracket.mantle_hours>0.01 \
			or not world.maintenance_inventory.is_consumed("gas_mantle_01") or not carton.carried().is_empty() \
			or not is_equal_approx(bracket.mantle_life,bracket.seeded_life(1)):
		failures.append("closing the shade with a spare did not hang a new mantle");return
	if bracket.brightness()<=lit:
		failures.append("a new mantle does not burn off with a flare");return
	player.face_world_point(bracket.flame_mesh.global_position)
	for i in 4:await RenderingServer.frame_post_draw
	await _capture("bracket_renewed")
	await get_tree().physics_frame
	var saved: Dictionary=world.household_state.snapshot().records[BRACKET].value
	if saved.get("mantle")!="intact" or int(saved.get("number",-1))!=1:
		failures.append("the household save does not hold the renewed mantle");return
	# The lantern: break it, swing its door out and shut with no spare.
	lantern.mantle_hours=lantern.mantle_life-0.1
	lantern.clock_override={"valid":true,"month":11,"minute_of_day":1290}
	lantern.refresh_clock()
	lantern.burn(60.0)
	if lantern.mantle_state!="broken":
		failures.append("the lantern mantle does not break");return
	if not await _leave_front_entrance():return
	if not await _walk(Vector3(0.45,0,-13.2)):return
	if not await _close_front_entrance():return
	if not await _walk(Vector3(-0.55,0,-12.75)):return
	var knob:=func(): return lantern.access_part.to_global(Vector3(0.1395,-0.15,-0.0065))
	if not await _grab_to(lantern.access_part,knob.call(),1.1):return
	if lantern.mantle_state!="bare":
		failures.append("opening the lantern door did not crumble the spent ash");return
	await _capture("lantern_door_open")
	if not await _grab_to(lantern.access_part,knob.call(),0.0):return
	if lantern.mantle_state!="bare":
		failures.append("the lantern hung a mantle with no spare in hand");return
	print("GAS MANTLE RENEWAL: wear breaks, carton gives one spare, shade crumbles and renews, lantern door swings, save holds")

## Grab `part` where `aim` lies, drive its owner's value to `goal` by mouse
## through the controller's own slide/hinge mapping, and release.
func _grab_to(part: Node3D, aim: Vector3, goal: float) -> bool:
	player.face_world_point(aim)
	player.set_mouse_released(false)
	await get_tree().physics_frame
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	player._unhandled_input(click)
	if not player._grab.active() or player._grab.target.part!=part:
		failures.append(str(part.get_parent().name)+"/"+str(part.name)+" is not grabbed by the player's hand");return false
	var camera: Camera3D=player.camera
	for step in 300:
		if not player._grab.active():break
		var target: Dictionary=player._grab.target
		var value: float=target.read.call()
		if absf(value-goal)<0.002:break
		var frame: Node3D=target.frame
		var local_axis: Vector3=target.axis
		var axis: Vector3=(frame.global_basis*local_axis).normalized()
		var point: Vector3=part.to_global(player._grab.contact)
		var tangent: Vector3=axis
		if target.kind=="hinge":
			tangent=axis.cross(point-part.global_position)
			if tangent.length()<.025:
				tangent=axis.cross(camera.global_basis.x)*.06
				if tangent.length()<.01:tangent=axis.cross(camera.global_basis.y)*.06
		var screen: Vector2=(camera.unproject_position(point+tangent*.01)-camera.unproject_position(point))/.01
		if screen.length()<24.0 and absf(tangent.dot(camera.global_basis.z))>tangent.length()*.5:
			screen=Vector2(0,tangent.dot(camera.global_basis.z)*180.0)
		var limit: float=.2 if target.kind=="hinge" else .07
		var motion:=InputEventMouseMotion.new();motion.relative=screen*clampf(goal-value,-limit,limit)
		player._unhandled_input(motion)
		await get_tree().physics_frame
	var reached: float=player._grab.target.read.call() if player._grab.active() else -1.0
	if player._grab.active():player._unhandled_input(click)
	await get_tree().physics_frame
	if absf(reached-goal)>.01:
		failures.append(str(part.get_parent().name)+"/"+str(part.name)+" did not reach "+str(goal)+" by hand: "+str(reached));return false
	return true
