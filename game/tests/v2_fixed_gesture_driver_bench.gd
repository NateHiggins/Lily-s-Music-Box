extends Node3D
## INERT actual input migration check; no impact sweeps or runtime qualification.
var checks: Array=[]
func check(ok: bool,label: String) -> void:checks.append({"ok":ok,"label":label});print("FIXED DRIVER: ",label," = ",ok)
func _ready() -> void:run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	RealityState.persistence_enabled=false
	var floor_body:=StaticBody3D.new();floor_body.position.y=-.1;add_child(floor_body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(30,.2,30);shape.shape=box;floor_body.add_child(shape)
	var player:=PlayerController.new();add_child(player);player.camera.make_current();player.set_lamp_enabled(false);player.set_beam_mask_enabled(false);player.set_mouse_released(false)
	var hand:=preload("res://tests/fixed_gesture_patrol_hand.gd").new();hand.player=player;add_child(hand)
	var index:=0
	for swing in [false,true]:
		for distance in [.55,1.35]:
			var door:=preload("res://scripts/building/orison_v2_fitted_door.gd").new();door.swing_out=swing;door.position.x=index*3.;add_child(door);index+=1
			player.position=door.position+Vector3(.4,0,distance if swing else -distance);player.velocity=Vector3.ZERO;player.rotation.y=0. if swing else PI
			for frame in 3:await get_tree().physics_frame
			player.camera.look_at(door._body.to_global(Vector3(door.width/3.,1.1,door._hinge_offset)))
			hand.motion_events=0;hand.motion_pixels=0.
			hand.click();check(player._grab.active() and is_zero_approx(door._body.rotation.y),"primary grab preserves closed pose "+str(index))
			var goal: float=door.motion_target_angle(true)
			check(await hand.move_to(goal*.4),"fixed-gesture driver reaches an intermediate pose "+str(index))
			if player._grab.active():hand.click()
			check(absf(door._body.rotation.y-goal*.4)<1e-6,"release preserves intermediate pose "+str(index))
			check(await hand.operate(door._body.to_global(Vector3(door.width/3.,1.1,door._hinge_offset)),goal,door),"primary regrab/motion/release reaches open stop "+str(index))
			check(hand.motion_events>1 and absf(hand.motion_pixels-240.)<.001,"full opening uses240px across partial regrab "+str(index))
			hand.motion_pixels=0.
			check(await hand.operate(door._body.to_global(Vector3(door.width/3.,1.1,door._hinge_offset)),0.,door),"reverse mouse motion closes through shared driver "+str(index))
			check(absf(hand.motion_pixels-240.)<.001 and not player.noclip and (player.collision_mask&1)==1,"closing uses240px with ordinary player collision mask "+str(index))
	var ok: bool=checks.all(func(row):return row.ok)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("driver_checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks},"\t"))
	print("FIXED DRIVER: ","PASS" if ok else "FAIL"," checks=",checks.size());get_tree().quit(0 if ok else 1)
