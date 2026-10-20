extends "res://tests/orison_v2_completion_interiors_test.gd"
## A render stall must not substitute a timer expiry for a settled door leaf.
func _open_door(identity: String) -> bool:
	var door := _leaf(identity)
	if not _require(door!=null,"production leaf exists: "+identity): return false
	if not _require(not door.open and door.leaf_state=="closed","leaf starts closed and usable: "+identity): return false
	if not await _use(door,door.to_global(Vector3(door.width*.5,1.1,0)),identity): return false
	var body := door.get_node_or_null("HingedLeaf") as AnimatableBody3D
	var deadline := Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<deadline:
		if door.open and not door._moving and body!=null and absf(body.rotation.y-door.motion_target_angle(true))<.01: break
		await get_tree().process_frame
	var settled := door.open and not door._moving and body!=null and absf(body.rotation.y-door.motion_target_angle(true))<.01
	if not settled:
		print("COMPLETION DOOR STATE ",identity," open=",door.open," moving=",door._moving,
			" angle=",body.rotation.y if body!=null else INF," locked=",player.call_locked)
	return _require(settled,"input opens physical leaf to its stop: "+identity)
