extends Node3D
## Actual player-input helper derived from first-slice PatrolHand.
## Kept separate so the isolated fixture does not preload the entire V2 world.
var player: PlayerController
var follows_cursor := true
func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	player._unhandled_input(event)

func move_to(goal: float) -> bool:
	for i in 640:
		if not player._grab.active(): return false
		var target: Dictionary=player._grab.target
		var value: float=target.read.call()
		if absf(goal-value)<.000001: return true
		var point: Vector3=target.part.to_global(player._grab.contact)
		var local_axis: Vector3=target.axis.call() if target.axis is Callable else target.axis
		var axis: Vector3=target.frame.global_basis*local_axis
		var tangent: Vector3=axis
		if target.kind=="hinge":
			tangent=axis.cross(point-target.part.global_position)
			if tangent.length()<float(target.get("minimum_lever",.025)): tangent=axis.cross(player.camera.global_basis.x)*.06
			if tangent.length()<.01:tangent=axis.cross(player.camera.global_basis.y)*.06
		var screen: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
		var depth_gesture := screen.length()<24.0 and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5
		if depth_gesture: screen=Vector2(0,tangent.dot(player.camera.global_basis.z)*180.0)
		var event := InputEventMouseMotion.new()
		event.relative=screen*clampf(goal-value,-.12 if target.kind=="hinge" else -.02,.12 if target.kind=="hinge" else .02)/float(target.get("motion_scale",1.0))
		var before_screen: Vector2=player.camera.unproject_position(point)
		player._unhandled_input(event)
		await get_tree().physics_frame
		if not depth_gesture and target.kind=="hinge" and absf(float(target.read.call())-value)>.001:
			var after_screen: Vector2=player.camera.unproject_position(target.part.to_global(player._grab.contact))
			if (after_screen-before_screen).dot(event.relative)<0: follows_cursor=false
	return false

func operate(point: Vector3, target: float, owner: Node = null) -> bool:
	player.camera.look_at(point)
	await get_tree().physics_frame
	await get_tree().physics_frame
	click()
	if not player._grab.active():
		print("[PATROL POINTER] acquisition refused at ",point," camera=",player.camera.global_position)
		return false
	var picked: Dictionary=player._grab.target
	if owner!=null and picked.owner!=owner:
		print("[PATROL POINTER] wrong owner: ",picked.owner.get_path())
		click()
		return false
	var part_name: String=str(picked.part.get_path())
	var moved: bool=await move_to(target)
	if not moved:
		print("[PATROL POINTER] motion incomplete part=",part_name," wanted=",target," actual=",picked.read.call()," active=",player._grab.active()," captured=",Input.mouse_mode," call_locked=",player.call_locked," mouse_released=",player.mouse_released)
	if player._grab.active(): click()
	return moved and not player._grab.active()
