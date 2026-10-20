extends "res://tests/orison_v2_lift_drive_test.gd"
## The preceding roof circuit leaves this real leaf open. Restore its state
## through ordinary E before the inherited closed-leaf test, never by assignment.
func _open_door(identity: String) -> bool:
	var leaf := _leaf(identity)
	if leaf != null and leaf.open:
		if not await _close_door(identity): return false
	return await super._open_door(identity)
