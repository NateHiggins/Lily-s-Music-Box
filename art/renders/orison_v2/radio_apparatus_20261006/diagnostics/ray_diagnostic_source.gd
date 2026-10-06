extends "res://tests/orison_v2_radio_apparatus_test.gd"
func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var hit:=super._isolated_ray(world,model,part,start,finish)
	if part.ends_with("__valve_opal") or (part.begins_with("storm_shop_radio_service_chassis__") and (part.ends_with("__control_bakelite") or part.ends_with("__chassis_metal"))):
		var direction: Vector3=(finish-start).normalized();var middle: Vector3=(start+finish)*.5
		var extended:=super._isolated_ray(world,model,part,middle-direction*5.,middle+direction*5.)
		var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service
		print("RADIO RAY DIAGNOSTIC ",JSON.stringify({"part":part,"start":cell.to_local(start),"finish":cell.to_local(finish),"short_hit":null if hit.is_empty() else cell.to_local(hit.position),"extended_hit":null if extended.is_empty() else cell.to_local(extended.position)}))
	return hit
