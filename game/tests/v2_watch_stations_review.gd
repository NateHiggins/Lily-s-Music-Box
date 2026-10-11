extends RefCounted
## Loaded geometry and physical fit; existing patrol suite proves signal behavior.
func run(world: OrisonV2RuntimeRoot, suite: Node) -> void:
	var stations: Array[WatchStationProp]=[]
	for node: Node in world.find_children("*","Node3D",true,false):
		if node is WatchStationProp:stations.append(node)
	suite.check(stations.size()==7,"seven native patrol boxes retain existing station ownership")
	for station in stations:
		suite.check(station.get_meta("v2_native_watch_station",false) and station.native_parts>=18,"native stock replaces station visual primitives: "+station.station_id)
		var leaf: MeshInstance3D=station._door.get_node("DoorLeaf")
		var aperture_clear := true
		var arrays := leaf.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			if Geometry3D.ray_intersects_triangle(Vector3(0,.026,1),Vector3.FORWARD,vertices[indices[i]],vertices[indices[i+1]],vertices[indices[i+2]])!=null:aperture_clear=false
		suite.check(aperture_clear,"glazing aperture is cut through opaque leaf: "+station.station_id)
		# The entire door leaf stays in front of the actual 120 mm case rim.
		var clear := true
		for step in 24:
			var hinge := Transform3D(Basis(Vector3.UP,-1.35*step/23.0),station._door.position)
			for vertex in vertices:
				if (hinge*leaf.transform*vertex).z<.1205:clear=false
		suite.check(clear,"door leaf clears cast rim throughout ordinary and refusal range: "+station.station_id)
		var flag: MeshInstance3D=station._drop.get_node("DropFlag")
		var flag_vertices: PackedVector3Array=flag.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for angle in [0.0,1.35]:
			var inside := true
			var drop := Transform3D(Basis(Vector3.BACK,angle),station._drop.position)
			for vertex in flag_vertices:
				var p: Vector3=drop*flag.transform*vertex
				if p.x<-.105 or p.x>.105 or p.y<.020 or p.y>.300:inside=false
			suite.check(inside,"indicator fits inner case in both states: "+station.station_id)
	world.player.carried_device.set_capture_hidden(true)
	var station := stations[0]
	var camera := Camera3D.new();camera.fov=52;world.add_child(camera);camera.make_current()
	camera.global_position=station.to_global(Vector3(.23,.24,.62));camera.look_at(station.to_global(Vector3(0,.18,.07)),Vector3.UP)
	var fill := OmniLight3D.new();fill.light_energy=.35;fill.omni_range=2;world.add_child(fill);fill.global_position=camera.global_position
	var guard := world.find_child("F01_TOUR_KEY_GUARD",true,false) as TourKeyGuardProp
	await suite.shot("native_station_closed")
	suite.check(station.open_door(),"native door uses original open action")
	await suite.shot("native_station_open")
	suite.check(guard.take_key() and station.turn_crank(),"native wheel and flag use original keyed marking")
	await suite.shot("native_station_marked")
	suite.check(guard.return_key() and station.reset_station(),"native station and guard restore after review")
	station.close_door()
	fill.free();camera.free();world.player.camera.make_current()
