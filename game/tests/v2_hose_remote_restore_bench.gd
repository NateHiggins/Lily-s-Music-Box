extends "res://tests/v2_fire_hand_bench.gd"
## The actual world-v4 remote payload through fresh translated native owners.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var wanted: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_hose_remote_restore_20261023.json"))
	var records: Array=[]
	for generation in 2:
		var adapter:=FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
		var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
		var native:=Native.new()
		if not check(native.mount(adapter,{"levels":[{"y":0.}]}) and native.mount_hose_deployment(),"fresh production hose owners mount: "+str(generation)):
			print(native.errors);get_tree().quit(1);return
		var actor: Node3D=native.stations.F02_FIRE_LINE_STAIR.get_ref()
		actor.global_transform=Transform3D(Basis(Vector3.UP,PI),Vector3(-4.349999,4.4,-7.87));actor.set_physics_process(false)
		check(actor.valid_mechanism(wanted),"captured remote payload validates against fresh receiver: "+str(generation))
		actor.restore_mechanism(wanted)
		for frame in 3:await get_tree().physics_frame
		var actual: Dictionary=actor.mechanism_snapshot()
		var comparison: Dictionary=preload("res://tests/hose_saved_pose_comparison.gd").compare(actual,wanted)
		records.append({"actual":actual,"wanted":wanted,"comparison":comparison})
		print("REMOTE RESTORE COMPARISON: ",JSON.stringify(comparison))
		check(actor.valid_mechanism(actual),"restored remote payload remains valid after three physics frames: "+str(generation))
		check(comparison.equal,"captured remote pose within10um and exact non-pose authority fields: "+str(generation))
		adapter.root.free()
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("restore.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Captured world payload in translated native fixture, two fresh owner generations; no full disk/world qualification.","records":records,"checks":observations,"failures":failures},"\t",true,true))
	print("HOSE REMOTE RESTORE: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
