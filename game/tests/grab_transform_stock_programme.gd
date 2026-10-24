extends RefCounted
## Uses the real player input route on a selected free stock owner.
func _axis(bench: Node,index: int) -> void:
	var event:=InputEventKey.new();event.pressed=true;event.keycode=[KEY_X,KEY_Y,KEY_Z][index]
	bench.player._unhandled_input(event)
func _motion(bench: Node,pixels: float) -> void:
	var event:=InputEventMouseMotion.new();event.relative=Vector2(pixels,0)
	bench.player._unhandled_input(event)
func run(bench: Node,stock: Node3D) -> void:
	var acquired:=false
	if stock.has_node("ManipulateSpine"):
		await bench.cursor_at(stock.get_node("ManipulateSpine").get_child(0).global_position)
		if bench.player._grab.find_target().get("part")==stock:
			bench.click();acquired=bench.player._grab.active()
	else:acquired=await bench.grab_visible_stock(stock)
	if not bench.check(acquired,"actual free cursor grabs stock for shared XYZ controls"):return
	# Flush OS cursor-warp motion from surface acquisition before measuring
	# the explicit relative events below. This is not an object pose assignment.
	for frame in 3:
		await RenderingServer.frame_post_draw
		await bench.get_tree().physics_frame
	var eye: Transform3D=bench.player.camera.global_transform
	for index in 3:
		_axis(bench,index)
		var before: Vector3=stock.position
		_motion(bench,3.);await bench.get_tree().physics_frame
		var delta: Vector3=stock.position-before
		print("PRECISION STOCK AXIS: ",index," delta=",delta," contact=",stock._last_motion," target=",bench.player._grab.target.get("part"))
		bench.check(delta[index]>.00001,"stock translates on selected "+["X","Y","Z"][index]+" axis through actual mouse input")
		delta[index]=0.
		bench.check(delta.length()<.00002,"stock translation retains unselected coordinates")
		_motion(bench,-3.);await bench.get_tree().physics_frame
		_axis(bench,index)
	var secondary:=InputEventMouseButton.new();secondary.button_index=MOUSE_BUTTON_RIGHT;secondary.pressed=true
	bench.player._unhandled_input(secondary)
	for index in 3:
		_axis(bench,index)
		var before: Basis=stock.basis
		_motion(bench,3.);await bench.get_tree().physics_frame
		bench.check(before.get_rotation_quaternion().angle_to(stock.basis.get_rotation_quaternion())>.01,"stock rotates on selected "+["X","Y","Z"][index]+" axis through actual secondary drag")
		_motion(bench,-3.);await bench.get_tree().physics_frame
		_axis(bench,index)
	var before_roll: Basis=stock.basis
	var wheel:=InputEventMouseButton.new();wheel.pressed=true;wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.factor=.1
	bench.player._unhandled_input(wheel);await bench.get_tree().physics_frame
	bench.check(before_roll.get_rotation_quaternion().angle_to(stock.basis.get_rotation_quaternion())>.005,"secondary wheel rotates stock around view roll axis")
	wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;bench.player._unhandled_input(wheel);await bench.get_tree().physics_frame
	secondary.pressed=false;bench.player._unhandled_input(secondary)
	bench.check(bench.player.camera.global_transform==eye,"stock precision controls retain static inspection camera")
	bench.click()
	var pose: Transform3D=stock.global_transform
	for frame in 8:await bench.get_tree().physics_frame
	bench.check(stock.global_transform.is_equal_approx(pose),"manipulated inspection stock stays static after release")
