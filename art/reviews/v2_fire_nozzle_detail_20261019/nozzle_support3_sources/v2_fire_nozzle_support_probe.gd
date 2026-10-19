extends Node3D
## Headless passive support/timing diagnostic, never player-input acceptance.
const Fixture=preload("res://tests/v2_fire_hand_bench.gd")
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var adapter:=Fixture.FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=preload("res://scripts/building/orison_v2_native_fire_service.gd").new()
	if not native.mount(adapter,{"levels":[{"y":0.}]}):push_error(str(native.errors));get_tree().quit(1);return
	var before: Dictionary={};var started: int=Time.get_ticks_usec()
	for step in range(40):
		await get_tree().physics_frame
		if step not in [0,9,19,39]:continue
		for key: String in native.stations:
			var joint: Node3D=native.stations[key].get_ref()._nozzle_joint
			print("NOZZLE SUPPORT PROBE ",step," ",key," pose=",joint.body.position," support=",joint._support.get_ref().get_path() if joint._support!=null and joint._support.get_ref()!=null else "none"," last_sweep_ms=",joint.last_sweep_ms)
			if step==19:before[key]=joint.body.position
	var ok: bool=true
	for key: String in native.stations:
		var joint: Node3D=native.stations[key].get_ref()._nozzle_joint
		ok=ok and joint._support!=null and joint.body.position==before[key]
	var joint: Node3D=native.stations.values()[0].get_ref()._nozzle_joint
	var state: Dictionary=joint.snapshot();state.clocking=1.1;state.spin=1.1
	var at: Vector3=joint.thread_pose(joint.stock.maximum_angle(),1.1).origin
	state.position=[at.x,at.y,at.z];joint.restore(state)
	for step in range(40):await get_tree().physics_frame
	print("NOZZLE PHASE SUPPORT: ",joint.body.position," support=",joint._support.get_ref().get_path() if joint._support!=null and joint._support.get_ref()!=null else "none")
	if joint._support!=null and joint._support.get_ref()!=null:
		var floor: Node3D=joint._support.get_ref().get_parent_node_3d()
		print("NOZZLE MOVING SUPPORT: ",floor.get_path());floor.position.y-=.03
		for step in range(30):
			await get_tree().physics_frame
			if step in [0,1,10,29]:print("NOZZLE DROP ",step," at=",joint.body.position," hit=",joint._last_contact.get_path() if is_instance_valid(joint._last_contact) else "none"," cached=",joint._support.get_ref().get_path() if joint._support!=null and joint._support.get_ref()!=null else "none"," ms=",joint.last_sweep_ms)
	print("V2 FIRE NOZZLE PASSIVE SUPPORT: ","PASS" if ok else "FAIL"," ms=",(Time.get_ticks_usec()-started)/1000.)
	get_tree().quit(0 if ok else 1)
