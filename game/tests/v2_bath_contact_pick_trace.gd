extends "res://tests/toilet_inspection_test.gd"
func click() -> void:
	if player.inspecting() and not player._grab.active():
		var target: Dictionary=player._grab.find_target();var hit: Dictionary=player._grab.last_hit
		var description: Dictionary={"cursor":str(get_viewport().get_mouse_position()),"float_pixel":str(player.camera.unproject_position(wc.parts.FloatArm.to_global(Vector3(.25,-.023,0)))),"discharge_pixel":str(player.camera.unproject_position(wc.parts.FlushBall.to_global(Vector3(.015,.018,0)))),"target":str(target),"hit":str(hit)}
		if hit.get("collider") is CollisionObject3D:
			var collider: CollisionObject3D=hit.collider
			var index: int=collider.shape_find_owner(hit.shape)
			description.shape_owner=str(collider.shape_owner_get_owner(index))
		print("CONTACT PICK TRACE: ",description)
	super.click()
