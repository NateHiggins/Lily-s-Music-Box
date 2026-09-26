extends RefCounted
## Adapt the production car/door/input owner to the installed V2 shaft.

func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> OrisonElevator:
	var shaft: Dictionary = {}
	for record: Dictionary in layout.risers:
		if record.id == "PASSENGER_LIFT_SHAFT": shaft = record
	if shaft.is_empty(): return null
	var stops := {}
	for landing: Dictionary in layout.lift_landings:
		if landing.shaft != shaft.id: continue
		for level: Dictionary in layout.levels:
			if level.id == landing.level: stops[level.id] = float(level.y)
	# B1 is a real passenger stop as well as the separate boiler stair.
	for level: Dictionary in layout.levels:
		if level.id == "B1": stops[level.id] = float(level.y)
	if stops.size() != 7: return null
	var lift := OrisonElevator.new()
	lift.name = "PassengerElevator"
	lift.rotation.y = PI
	adapter.root.add_child(lift)
	var center_x := (float(shaft.rect[0])+float(shaft.rect[2]))*.5
	var center_z := float(shaft.rect[1])+OrisonElevator.FRONT_Z
	# setup uses plan (x,-z) and creates sync-to-physics bodies. Establish
	# the final parent transform before those bodies cache their transforms.
	lift.setup({"shaft":[center_x-1.2,-center_z-1.1,center_x+1.2,-center_z+1.1], "cabin":[1.55,2.2],
		"stops":stops, "door_w":.91})
	# Only the old translucent reservation is retired. Authored shaft walls,
	# pit, landing aprons and the production moving door colliders remain.
	var reservation := adapter.resolve(str(shaft.id)) as Node3D
	if reservation != null: reservation.visible = false
	for landing: Dictionary in layout.lift_landings:
		if landing.shaft != shaft.id: continue
		var frame := adapter.resolve(str(landing.id)) as Node3D
		if frame != null: frame.visible = false
	return lift
