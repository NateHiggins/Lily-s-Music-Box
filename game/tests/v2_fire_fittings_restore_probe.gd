extends "res://tests/v2_fire_hand_bench.gd"
## Diagnostic replay of the original disk1 save; never a substitute for composed proof.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var root: String=ProjectSettings.globalize_path("res://..").simplify_path()
	var document: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("tmp/v2-fire-hand-20261019/disk1/saved_fire_fittings.json")))
	var adapter:=FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=Native.new()
	if not native.mount(adapter,{"levels":[{"y":0.}]}):get_tree().quit(1);return
	var expected: Dictionary={}
	for identity: String in native.stations:
		var actor: Node3D=native.stations[identity].get_ref()
		expected[identity]=document.v2_household_controls.records[identity].value
		check(actor.valid_mechanism(expected[identity]),"original disk pose validates in fresh native station: "+identity)
		actor.restore_mechanism(expected[identity])
		print("RESTORE IMMEDIATE ",identity,": ",JSON.stringify(actor.mechanism_snapshot()))
	for frame in range(60):await get_tree().physics_frame
	var actual: Dictionary={}
	for identity: String in native.stations:
		var actor: Node3D=native.stations[identity].get_ref()
		actual[identity]=actor.mechanism_snapshot()
		print("RESTORE SETTLED ",identity,": ",JSON.stringify(actual[identity]))
		check(JSON.stringify(actual[identity],"",true)==JSON.stringify(expected[identity],"",true),"actual settled pose exactly retains the original disk snapshot: "+identity)
	var directory: String=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("restoration_diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"expected":expected,"actual":actual},"\t"))
	var first: Node3D=native.stations.B1_FIRE_LINE_STAIR.get_ref()
	var before: float=first._gasket_body.position.y
	for draw: MeshInstance3D in first.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("native_fire_part",""))=="F062":draw.position.y-=.020
	for frame in range(30):await get_tree().physics_frame
	check(first._gasket_body.position.y<before-.005,"removing the actual restored tin support wakes gravity instead of freezing the saved washer")
	print("FIRE RESTORE DIAGNOSTIC: ","PASS" if failures.is_empty() else "FAIL","; scoped native fixture, not composed acceptance")
	get_tree().quit(0 if failures.is_empty() else 1)
