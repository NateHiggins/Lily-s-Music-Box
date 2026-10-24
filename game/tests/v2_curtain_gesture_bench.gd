extends "res://tests/direct_manipulation_test.gd"
## INERT: actual grab/motion/release at two ranges and two fields of view.
func _run() -> void:
	RealityState.persistence_enabled=false
	var shower:=TapProp.new();shower.fixture="shower";shower.prop_type="shower";add_child(shower)
	player=PlayerController.new();add_child(player);player.set_physics_process(false);player.camera.make_current()
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-25,0);add_child(sun)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var rows: Array=[]
	for distance: float in [.85,1.55]:
		for fov: float in [55.,85.]:
			shower.set_curtain_open(false)
			player.position=Vector3(0,-.35,-distance)
			player.camera.fov=fov;player.camera.look_at(shower.to_global(Vector3(0,1.25,-.32)))
			for frame in 2:await get_tree().physics_frame
			click();check(player._grab.active() and shower._curtain_hand.held,"real cloth acquired")
			check(is_zero_approx(shower._curtain_hand.travel),"acquisition alone leaves cloth closed")
			for step in 24:drag(Vector2(-12,0));await get_tree().physics_frame
			var opened: float=shower._curtain_hand.travel
			check(is_equal_approx(opened,shower._curtain_hand.TRAVEL),"288 pixels open full U rail")
			for step in 24:drag(Vector2(12,0));await get_tree().physics_frame
			check(is_zero_approx(shower._curtain_hand.travel),"matching reverse gesture closes full U rail")
			click();check(not shower._curtain_hand.held,"next primary releases cloth")
			rows.append({"distance":distance,"fov":fov,"gesture_pixels":288,"opening_m":opened,"closing_m":shower._curtain_hand.travel})
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("gestures.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","rows":rows,"failures":failures},"\t"))
	print("CURTAIN GESTURE BENCH: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	get_tree().quit(failures.size())
