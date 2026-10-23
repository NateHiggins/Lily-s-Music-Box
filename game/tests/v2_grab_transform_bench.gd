extends "res://tests/v2_fire_nozzle_coupling_bench.gd"
## Actual-input precision controls on the installed native nozzle owner.
func press_axis(axis: int) -> void:
	var event:=InputEventKey.new();event.keycode=[KEY_X,KEY_Y,KEY_Z][axis];event.pressed=true
	player._unhandled_input(event)

func secondary(pressed: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=pressed
	player._unhandled_input(event)

func exercise_nozzle(actor: Node3D,hand: Node) -> void:
	var joint: Node3D=actor._nozzle_joint
	await aim(actor._tag.to_global(Vector3(0,0,.0035)));click();key(KEY_SPACE)
	if not check(player.inspecting() and player.inspect_owner==actor,"actual Space enters existing static inspection for XYZ manipulation"):return
	var point: Vector3=actor._play_pipe.to_global(Vector3(0,.155,.014))
	var lift: Vector3=joint.body.position+Vector3.UP*.001
	var clear: Vector3=lift+joint.receiver.basis.y*.012
	var goal: Vector3=joint.body.position+Vector3(0,.06,.06)
	if not check(await carry_path(actor,actor._play_pipe,point,[lift,clear,goal+joint.receiver.basis.y*.012,goal],.0001),"actual free carry positions nozzle clear of rack for precision input"):return
	point=actor._play_pipe.to_global(Vector3(0,.155,.014))
	if not check(await acquire_surface(actor._play_pipe,point),"precision input selects actual movable nozzle surface"):return
	click()
	if not check(player._grab.active() and actor._hand=="nozzle_body","primary click claims original nozzle owner"):return
	var eye: Transform3D=player.camera.global_transform
	player._grab.profiling=true
	for axis in 3:
		press_axis(axis)
		var before: Vector3=joint.body.position
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(8,0)
		player._unhandled_input(motion);await get_tree().physics_frame
		var delta: Vector3=joint.body.position-before
		check(delta[axis]>.0001,"actual mouse moves selected "+["X","Y","Z"][axis]+" translation axis")
		var remainder:=delta;remainder[axis]=0.
		check(remainder.length()<.00002,"axis translation retains other two coordinates")
		press_axis(axis)
	secondary(true)
	for axis in 3:
		press_axis(axis)
		var before: Basis=joint.body.basis
		var origin: Vector3=joint.body.position
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(3,0)
		player._unhandled_input(motion);await get_tree().physics_frame
		check(before.get_rotation_quaternion().angle_to(joint.body.basis.get_rotation_quaternion())>.01,"secondary drag rotates selected "+["X","Y","Z"][axis]+" axis")
		check(joint.body.position==origin and joint.body.basis.get_scale().is_equal_approx(Vector3.ONE),"rotation retains rigid origin and nozzle dimensions")
		press_axis(axis)
	secondary(false)
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join("xyz_nozzle_inspection.png"))==OK,"actual XYZ-manipulated nozzle inspection captured")
		FileAccess.open(directory.path_join("input_costs.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","records":player._grab.profile_records},"\t"))
	check(player.camera.global_transform==eye,"XYZ translation and rotation leave inspection eye static")
	var saved: Dictionary=actor.mechanism_snapshot()
	check(actor.valid_mechanism(saved),"household authority accepts rotated loose nozzle pose")
	actor.restore_mechanism(saved)
	check(actor.mechanism_snapshot()==saved,"rotated nozzle pose restores exactly through household owner")
	var bad: Dictionary=saved.duplicate(true);bad.nozzle.basis[0]=[0.,0.,0.]
	check(not actor.valid_mechanism(bad),"save rejects a collapsed nozzle basis")
	var pose: Transform3D=joint.body.transform
	click()
	check(not player._grab.active() and not player._grab.transform_rotating and player._grab.transform_axis==-1,"next primary click releases and clears precision gesture state")
	check(joint.body.transform==pose,"release does not snap rotated loose nozzle")
	key(KEY_ESCAPE)
