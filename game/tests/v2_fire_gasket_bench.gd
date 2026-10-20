extends "res://tests/v2_fire_hand_bench.gd"
## Focused original-input diagnosis; does not replace the full family bench.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-30,0);add_child(sun)
	var adapter:=FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var station_id: String=OS.get_environment("ORISON_GASKET_WORLD_STATION")
	if not station_id.is_empty():
		var connection=preload("res://scripts/building/orison_v2_world_connection.gd")
		var source: Dictionary=connection.read_object("res://data/orison_v2_blockout.json")
		var resolved: Dictionary=connection.prepare(source,connection.read_object("res://data/orison_v2/exterior/exterior_geometry.json"),preload("res://scripts/building/orison_v2_exterior_spatial_resolver.gd").load_default(),connection.read_object(connection.CONFIG_PATH))
		if not check(not resolved.is_empty(),"production connection resolves gasket contact frame"):get_tree().quit(1);return
		var anchor: Dictionary=connection.unique_record(source.anchors,station_id)
		if not check(not anchor.is_empty(),"requested installed gasket station exists"):get_tree().quit(1);return
		var level: Dictionary=connection.unique_record(source.levels,str(anchor.level))
		var at:=Vector3(anchor.position[0],anchor.position[1]+level.y,anchor.position[2])
		var installed: Transform3D=resolved.interior_transform*Transform3D(Basis.IDENTITY,at)
		adapter.root.transform=Transform3D(installed.basis,installed.origin-installed.basis*Vector3(0,1.2,0))
		print("GASKET FIXTURE FRAME: ",station_id," ",installed)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=Native.new()
	if not check(native.mount(adapter,{"levels":[{"y":0.0}]}),"focused gasket fixture mounts native production stock"):
		get_tree().quit(1);return
	var actor: Node3D=native.stations.values()[0].get_ref()
	player=PlayerController.new();player.position=adapter.root.to_global(Vector3(-.1,.025,1.15));player.rotation.y=adapter.root.rotation.y;add_child(player);player.set_lamp_enabled(false);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame;await get_tree().physics_frame
	var hand: Node=Hand.PatrolHand.new();hand.player=player;add_child(hand)
	check(await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),"actual mouse opens gasket access leaf")
	await exercise_gasket(actor,hand)
	print("V2 FIRE GASKET BENCH: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
