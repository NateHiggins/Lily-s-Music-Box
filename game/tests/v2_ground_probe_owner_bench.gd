extends Node3D
## Isolated actual source roof contacts; no soil is installed in this bench.
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	RealityState.persistence_enabled=false
	var shell:=preload("res://scripts/building/orison_v2_blockout.gd").new()
	shell.name="OrisonV2Blockout";shell.show_clearance_anchors=false;shell.show_reservation_volumes=false
	add_child(shell);preload("res://scripts/building/orison_v2_ceiling_top_closures.gd").mount(shell)
	var validator:=preload("res://tests/orison_v2_ceiling_top_closures_test.gd").new()
	validator.set_meta("shared_world_validation",true);add_child(validator)
	var data: Dictionary=validator._ground_probe_updates()
	await get_tree().physics_frame;await get_tree().physics_frame
	var physical:=get_world_3d().direct_space_state
	for row: Dictionary in data.records:
		var p: Array=row.point;var at:=Vector3(p[0],p[1],p[2])
		var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.05,at-Vector3.UP*.1,1)
		var hit: Dictionary=physical.intersect_ray(query)
		validator.check(validator._verify_ground_probe_revision(self,shell,row,at,hit,INF),"actual source roof passes its fixed ownership probe")
	var failed: bool=not validator.failures.is_empty()
	print("V2 GROUND PROBE OWNERS: ","FAIL" if failed else "PASS"," checks=",validator.checks," failures=",validator.failures.size())
	validator.free();shell.free();get_tree().quit(1 if failed else 0)
