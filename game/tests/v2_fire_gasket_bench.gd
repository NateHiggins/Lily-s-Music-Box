extends "res://tests/v2_fire_hand_bench.gd"
## Focused original-input diagnosis; does not replace the full family bench.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-30,0);add_child(sun)
	var adapter:=FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=Native.new()
	if not check(native.mount(adapter,{"levels":[{"y":0.0}]}),"focused gasket fixture mounts native production stock"):
		get_tree().quit(1);return
	var actor: Node3D=native.stations.values()[0].get_ref()
	player=PlayerController.new();player.position=Vector3(-.1,.025,1.15);add_child(player);player.set_lamp_enabled(false);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame;await get_tree().physics_frame
	var hand: Node=Hand.PatrolHand.new();hand.player=player;add_child(hand)
	check(await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),"actual mouse opens gasket access leaf")
	await exercise_gasket(actor,hand)
	print("V2 FIRE GASKET BENCH: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
