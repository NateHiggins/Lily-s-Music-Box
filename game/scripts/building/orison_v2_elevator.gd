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
	_refine_landing_frames(lift)
	var controls := preload("res://scripts/building/orison_v2_lift_controls.gd").new()
	controls.name = "LandingControls"
	lift.add_child(controls)
	if not controls.mount(lift,layout):
		lift.queue_free()
		return null
	# Only the old translucent reservation is retired. Authored shaft walls,
	# pit, landing aprons and the production moving door colliders remain.
	var reservation := adapter.resolve(str(shaft.id)) as Node3D
	if reservation != null: reservation.visible = false
	for landing: Dictionary in layout.lift_landings:
		if landing.shaft != shaft.id: continue
		var frame := adapter.resolve(str(landing.id)) as Node3D
		if frame != null: frame.visible = false
	return lift


func _refine_landing_frames(lift: OrisonElevator) -> void:
	var library := (preload("res://assets/props/millwork_profile.glb") as PackedScene).instantiate()
	var profile := (library.find_child("LiftReveal",true,false) as MeshInstance3D).mesh
	library.free()
	for level: String in lift.stop_order:
		var header := lift._landing_frames[level]["head"] as MeshInstance3D
		var head_size := (header.mesh as BoxMesh).size
		var joint_y := header.position.y-head_size.y*.5
		# The V2 structural opening is 1.0 x 2.23 m. Cover its edges with
		# 45 mm side laps and a 50 mm head lap, keeping the clear aperture.
		head_size.y = .14
		header.position.y = joint_y+head_size.y*.5
		header.mesh = profile
		header.scale = head_size
		for side: String in ["west","east"]:
			var jamb := lift._landing_frames[level][side] as MeshInstance3D
			var size := (jamb.mesh as BoxMesh).size
			var inner_x := absf(jamb.position.x)-size.x*.5
			size.x = .09
			jamb.position.x = signf(jamb.position.x)*(inner_x+size.x*.5)
			# End the upright at the underside of the header: the original
			# boxes overlapped 20 mm, including their coplanar front faces.
			size.y = joint_y-float(lift.stops[level])
			jamb.position.y = float(lift.stops[level])+size.y*.5
			jamb.mesh = profile
			jamb.rotation.z = PI*.5
			jamb.scale = Vector3(size.y,size.x,size.z)
