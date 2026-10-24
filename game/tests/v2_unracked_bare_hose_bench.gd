extends "res://tests/v2_fire_hand_bench.gd"
## INERT: actual removal input without imposing the coupled-nozzle precondition.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var adapter:=FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=Native.new()
	if not check(native.mount(adapter,{"levels":[{"y":0.}]}),"production installer mounts bare-end fixture"):get_tree().quit(1);return
	var actor: Node3D=native.stations.values()[0].get_ref()
	for station: WeakRef in native.stations.values():
		var other: Node3D=station.get_ref()
		if other!=actor:other.free()
	var ground:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(40,.2,10);shape.shape=box;ground.add_child(shape);add_child(ground);ground.position=Vector3(-12,-.1,0)
	actor.door_open=true;actor._refresh_cabinet()
	var joint: Node3D=actor._nozzle_joint
	check(joint.loose and not actor.nozzle_coupled,"default detached nozzle authority is preserved")
	var hose:=preload("res://scripts/props/fire_unracked_hose.gd").new();actor.add_child(hose);hose.guide_enabled=true;hose.ground_y_local=-1.2
	var projection: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_unracked_fire_hose_rig.json"))
	var placement: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_unracked_fire_hose_placement.json"))
	if not check(hose.configure(actor,"res://tests/fixtures/v2_unracked_fire_hose.glb",projection,placement),"bare end prepares independent hose"):get_tree().quit(1);return
	player=PlayerController.new();add_child(player);player.set_physics_process(false);player.collision_layer=0;player.collision_mask=0
	player.global_position=actor.to_global(Vector3(-.3,.15,.70))-player.camera.position;player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for frame in 60:await get_tree().physics_frame
	if not check(hose.prepare_contact(),"detached nozzle stays an external cloth obstacle"):print(hose.error);get_tree().quit(1);return
	joint.hose_seat_grip_provider=hose.grip
	var picked:=false
	for point: Vector3 in [Vector3(0,-.006,.023),Vector3(.023,-.006,0),Vector3(0,.009,.020),Vector3(0,.016,.020)]:
		await aim(joint.seat.to_global(point))
		if player._grab.find_target().get("part")==joint.seat:picked=true;break
	check(picked,"reticle selects the actual bare hose seat")
	if picked:
		click();check(player._grab.active() and player._grab.target.part==joint.seat and not hose.deployed,"primary click grabs bare end without swapping stock")
		for step in 40:
			if not player._grab.active() or hose.deployed:break
			var point: Vector3=joint.seat.to_global(player._grab.contact)
			var axis: Vector3=actor.global_basis*Vector3.BACK
			var screen: Vector2=(player.camera.unproject_position(point+axis*.01)-player.camera.unproject_position(point))/.01
			if screen.length()<24. and absf(axis.dot(player.camera.global_basis.z))>.5:screen=Vector2(0,axis.dot(player.camera.global_basis.z)*180.)
			var event:=InputEventMouseMotion.new();event.relative=screen*.008;player._unhandled_input(event);await get_tree().physics_frame
		check(joint.loose and not actor.nozzle_coupled,"bare-end extraction never invents a nozzle connection")
		if player._grab.active():click()
		check(not player._grab.active() and actor._hand.is_empty(),"next click releases bare hose end")
		if hose.deployed:
			print("V2 BARE HOSE: ","PASS" if failures.is_empty() else "FAIL"," default settled nozzle leaves extraction clear")
			get_tree().quit(0 if failures.is_empty() else 1);return
		# A default loose nozzle can settle into the removal path. Lift it
		# from its real bearing, then move it axially clear through actual input.
		var clear: Vector3=joint.body.position+Vector3.UP*.06
		var goal: Vector3=joint.body.position+joint.receiver.basis.y*.05
		var collar: Vector3=actor._play_pipe.to_global(Vector3(0,.155,.014))
		await aim(collar)
		var raised: Vector3=goal+Vector3.UP*.06
		check(await carry_path(actor,actor._play_pipe,collar,[clear,raised,raised+Vector3.BACK*.10,raised+Vector3.BACK*.20,raised+Vector3.BACK*.30],.0001),"actual grab, mouse motion and wheel move the detached nozzle out of the case and hose layout")
		picked=false
		for point: Vector3 in [Vector3(0,-.006,.023),Vector3(.023,-.006,0),Vector3(0,.009,.020),Vector3(0,.016,.020)]:
			await aim(joint.seat.to_global(point))
			if player._grab.find_target().get("part")==joint.seat:picked=true;break
		check(picked,"cleared bare seat remains independently selectable")
		if picked:
			click()
			for step in 40:
				if not player._grab.active() or hose.deployed:break
				var point: Vector3=joint.seat.to_global(player._grab.contact)
				var axis: Vector3=actor.global_basis*Vector3.BACK
				var screen: Vector2=(player.camera.unproject_position(point+axis*.01)-player.camera.unproject_position(point))/.01
				if screen.length()<24. and absf(axis.dot(player.camera.global_basis.z))>.5:screen=Vector2(0,axis.dot(player.camera.global_basis.z)*180.)
				var event:=InputEventMouseMotion.new();event.relative=screen*.008;player._unhandled_input(event);await get_tree().physics_frame
			check(hose.deployed and joint.loose and not actor.nozzle_coupled,"actual mouse pull removes hose after clearing the separate nozzle")
			if player._grab.active():click()
			check(not player._grab.active() and actor._hand.is_empty(),"next click releases the deployed bare hose end")
	print("V2 BARE HOSE: ","PASS" if failures.is_empty() else "FAIL"," error=",hose.error)
	get_tree().quit(0 if failures.is_empty() else 1)
