extends "res://tests/orison_v2_public_doors_test.gd"
## The entrance's gas cocks through the player's own latched grab (RUL-013):
## shut to the pilot, part open, full open, saved by the household owner, and
## the street lantern's clockwork controller from dusk to dawn.
const BRACKET := "F01_VESTIBULE_GAS_BRACKET"
const LANTERN := "F01_ENTRANCE_GAS_LANTERN"

func _init() -> void: route_label="ENTRANCE GAS COCKS"

func _route() -> void:
	var bracket:=world.adapter.resolve(BRACKET) as OrisonV2GasFitting
	var lantern:=world.adapter.resolve(LANTERN) as OrisonV2GasFitting
	if bracket==null or lantern==null:
		failures.append("entrance gas fittings are not uniquely resolvable");return
	for fitting: OrisonV2GasFitting in [bracket,lantern]:
		var saved: Dictionary=world.household_state.snapshot().records.get(str(fitting.name),{})
		if saved.get("kind")!="mechanism":
			failures.append(str(fitting.name)+" cock is not in the household save");return
	# The lantern's controller: dark by day with the cock open, lit after dusk.
	lantern.clock_override={"valid":true,"month":11,"minute_of_day":720}
	lantern.refresh_clock()
	if lantern.mantle()>0.0 or lantern.light.visible:
		failures.append("street lantern burns at noon");return
	lantern.clock_override={"valid":true,"month":11,"minute_of_day":1290}
	lantern.refresh_clock()
	if not is_equal_approx(lantern.mantle(),1.0):
		failures.append("street lantern dark after dusk");return
	# The vestibule bracket, from the vestibule floor under it.
	for point in [Vector3(1.925,0,-6.5),Vector3(0,0,-7.65),Vector3(0,0,-9.85)]:
		if not await _walk(point):return
	if not await _turn(bracket,0.0):return
	if bracket.mantle()>0.0 or bracket.light.visible or not bracket.get_node("Pilot").is_visible_in_tree():
		failures.append("shut cock leaves the mantle lit or the pilot out");return
	await get_tree().physics_frame
	var shut: Dictionary=world.household_state.snapshot().records[BRACKET].value
	if float(shut.cock)>0.01:
		failures.append("household save does not hold the shut cock");return
	await _capture("bracket_shut")
	if not await _turn(bracket,PI*0.25):return
	if not (bracket.mantle()>0.1 and bracket.mantle()<1.0):
		failures.append("half-open cock is not a partial flame: "+str(bracket.mantle()));return
	if not await _turn(bracket,PI*0.5):return
	if not is_equal_approx(bracket.mantle(),1.0):
		failures.append("full cock does not bring the mantle up");return
	await _capture("bracket_open")
	# The lantern's cock from the pavement.
	# The open street leaf folds back against the lantern's pier: shut it
	# from the pavement first, as anyone reaching the lantern would.
	if not await _leave_front_entrance():return
	if not await _walk(Vector3(0.45,0,-13.2)):return
	if not await _close_front_entrance():return
	if not await _walk(Vector3(-0.55,0,-12.55)):return
	if not await _turn(lantern,0.0):return
	if lantern.mantle()>0.0:
		failures.append("lantern burns with its cock shut");return
	await _capture("lantern_shut")
	if not await _turn(lantern,PI*0.5):return
	if not is_equal_approx(lantern.mantle(),1.0):
		failures.append("lantern does not relight from its pilot");return
	print("ENTRANCE GAS COCKS: bracket shut/half/open and lantern shut/open by hand; pilot, save and clock hold")

## Grab the key, turn it by mouse through the controller's own hinge mapping,
## and release. The test only ever sends input; the fitting owns the value.
func _turn(fitting: OrisonV2GasFitting, goal: float) -> bool:
	var key: Node3D=fitting.key
	player.face_world_point(key.to_global(Vector3(0.016,0.024,0)))
	player.set_mouse_released(false)
	await get_tree().physics_frame
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	player._unhandled_input(click)
	if not player._grab.active() or player._grab.target.owner!=fitting:
		failures.append(str(fitting.name)+" key is not grabbed by the player's hand");return false
	var camera: Camera3D=player.camera
	for frame in 240:
		if not player._grab.active():break
		var angle: float=player._grab.target.read.call()
		if absf(angle-goal)<0.002:break
		var axis:=(fitting.global_basis*Vector3.UP).normalized()
		var point:=key.to_global(player._grab.contact)
		var tangent:=axis.cross(point-key.global_position)
		if tangent.length()<.025:
			tangent=axis.cross(camera.global_basis.x)*.06
			if tangent.length()<.01:tangent=axis.cross(camera.global_basis.y)*.06
		var screen:=(camera.unproject_position(point+tangent*.01)-camera.unproject_position(point))/.01
		if screen.length()<24.0 and absf(tangent.dot(camera.global_basis.z))>tangent.length()*.5:
			screen=Vector2(0,tangent.dot(camera.global_basis.z)*180.0)
		var motion:=InputEventMouseMotion.new();motion.relative=screen*clampf(goal-angle,-.2,.2)
		player._unhandled_input(motion)
		await get_tree().physics_frame
	if player._grab.active():player._unhandled_input(click)
	await get_tree().physics_frame
	if absf(fitting.opening*PI*0.5-goal)>.01:
		failures.append(str(fitting.name)+" did not reach "+str(goal)+" by hand: "+str(fitting.opening*PI*0.5));return false
	return true
