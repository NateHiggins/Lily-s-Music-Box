extends "res://tests/orison_v2_first_slice_contract_test.gd".PatrolHand
## Current fixed-travel input driver; historical receipt-bound driver stays intact.
var motion_events:=0
var motion_pixels:=0.0

func move_to(goal: float) -> bool:
	if not player._grab.active():return false
	if float(player._grab.target.get("gesture_travel_px",0.))<=0.:return await super.move_to(goal)
	for step in 640:
		if not player._grab.active():return false
		var target: Dictionary=player._grab.target
		var value: float=target.read.call()
		if absf(goal-value)<.000001:return true
		var direction: Vector2=player._grab._gesture_axis
		if direction.is_zero_approx():
			var point: Vector3=target.part.to_global(player._grab.contact)
			var local_axis: Vector3=target.axis.call() if target.axis is Callable else target.axis
			var axis: Vector3=target.frame.global_basis*local_axis
			var tangent: Vector3=axis.cross(point-target.part.global_position) if target.kind=="hinge" else axis
			var screen: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
			if screen.length()<24. and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5:screen=Vector2(0,tangent.dot(player.camera.global_basis.z)*180.)
			direction=screen.normalized()
		var motion:=InputEventMouseMotion.new()
		var limit:=.12 if target.kind=="hinge" else .02
		motion.relative=direction*float(target.gesture_travel_px)*clampf(goal-value,-limit,limit)/(float(target.maximum)-float(target.minimum))/float(target.get("motion_scale",1.))
		motion_events+=1;motion_pixels+=motion.relative.length()
		player._unhandled_input(motion)
		await get_tree().physics_frame
	return false
