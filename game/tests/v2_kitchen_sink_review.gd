extends RefCounted
## Test real water controls and physical bearing alignment in the production world.
func run(world: OrisonV2RuntimeRoot, suite: Node) -> void:
	var expected := 0
	for path: String in ["res://data/orison_v2/domestic_fittings.json","res://data/orison_v2/completion_interiors.json"]:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for row: Dictionary in source.fittings:
			if row.properties.get("fixture", "") == "kitchen_sink": expected += 1
	var count := 0
	# Snapshot the stable domain targets before any awaited capture. Renderer
	# caches can legitimately retire unrelated Node3Ds while this review runs.
	var kitchens: Array[Dictionary]=[]
	for node: Node in world.find_children("*", "Node3D", true, false):
		if node is TapProp and node.fixture=="kitchen_sink":
			kitchens.append({"tap":node,"unit":node.unit})
	var camera := Camera3D.new()
	camera.fov = 48
	world.add_child(camera)
	world.player.carried_device.set_capture_hidden(true)
	for entry: Dictionary in kitchens:
		suite.check(is_instance_valid(entry.tap),"reviewed sink remains mounted: "+str(entry.unit))
		if not is_instance_valid(entry.tap):continue
		var tap := entry.tap as TapProp
		count += 1
		suite.check(tap.get_script() == preload("res://scripts/building/orison_v2_kitchen_sink.gd"), "native kitchen owner: " + tap.unit)
		suite.check(world.boiler_tend.taps.count(tap) == 1, "one boiler supply: " + tap.unit)
		var top := tap.kitchen_rim_height()
		suite.check(tap._casting_mesh != null and _mesh_hit(tap._casting_mesh,Vector3(.08,top+.03,0),Vector3(.08,top-.17,0)),"native casting has a physical inner floor: " + tap.unit)
		suite.check(tap._casting_mesh != null and not _mesh_hit(tap._casting_mesh,Vector3(.012,top+.03,.01),Vector3(.012,top-.17,.01)),"drain bore passes through actual casting triangles: " + tap.unit)
		suite.check(not tap._basin_water.mesh is BoxMesh,"water footprint follows the rounded bowl: " + tap.unit)
		var saved := tap.get_flow_state()
		var temperature := tap._boiler_temperature
		var processing := tap.is_processing()
		tap.set_process(false)
		tap.set_running(false)
		tap.set_boiler_temperature(.8)
		var hot := tap.get_node("HotValveControl") as Area3D
		var cold := tap.get_node("ColdValveControl") as Area3D
		for control: Area3D in [hot,cold]:
			var query := PhysicsRayQueryParameters3D.create(control.global_position+tap.global_basis*Vector3(0,0,-.4),control.global_position,1,[world.player.get_rid()])
			query.collide_with_areas = true
			suite.check(world.get_world_3d().direct_space_state.intersect_ray(query).get("collider") == control,"unobstructed valve use ray: " + tap.unit + "/" + str(control.name))
		hot.interact(world.player)
		suite.check(tap.get_flow_state().hot and not tap.get_flow_state().cold and is_equal_approx(tap.get_flow_state().temperature,.8),"hot-only supply: " + tap.unit)
		cold.interact(world.player)
		suite.check(tap.get_flow_state().hot and tap.get_flow_state().cold and is_equal_approx(tap.get_flow_state().temperature,.4),"mixed supply: " + tap.unit)
		hot.interact(world.player)
		suite.check(not tap.get_flow_state().hot and tap.get_flow_state().cold and is_zero_approx(tap.get_flow_state().temperature),"cold-only supply: " + tap.unit)
		tap.set_stopper(true)
		tap._water_level = 0
		tap._process(1.0)
		suite.check(tap._kitchen_plug.position.distance_to(Vector3(0,top-.123,.01))<.001,"closed plug seats on drain ferrule: " + tap.unit)
		suite.check(tap._water_level > .07 and tap._basin_water.visible and tap._stream.visible,"cold flow fills stopped bowl: " + tap.unit)
		cold.interact(world.player)
		tap.set_stopper(false)
		tap._process(1.0)
		suite.check(tap._kitchen_plug.position.distance_to(Vector3(.095,top-.124,-.045))<.001,"open plug parks clear of drain: " + tap.unit)
		suite.check(not tap._stream.visible and is_zero_approx(tap._water_level),"both closed and bowl drains: " + tap.unit)
		var stand: Node3D = tap.get_node_or_null("KitchenStand") as Node3D
		var support_id := tap.unit + ("_sink_counter" if tap.unit == "4B" else "_sink_support")
		var candidates: Array[Node3D] = []
		for body: Node in world.find_children("*","StaticBody3D",true,false):
			if str(body.get_meta("v2_furniture_id","")) == support_id: candidates.append(body)
		if candidates.size() == 1: stand = candidates[0]
		suite.check(stand != null,"sink support retained: " + tap.unit)
		if stand != null:
			if tap.compact_kitchen:
				for x: float in [-.26,.26]:
					suite.check(_bearing(stand,tap.to_global(Vector3(x,tap.kitchen_rim_height()-.0125,0))),"compact lip bears on pierced worktop: " + tap.unit)
				if tap.has_drainboard:
					for z: float in [-.19,.19]:
						suite.check(_bearing(stand,tap.to_global(Vector3(.64,tap.kitchen_rim_height()-.016,z))),"compact drainboard bears on its frame: " + tap.unit)
			else:
				for x: float in [-.335,.775]:
					for z: float in [-.215,.215]:
						suite.check(_bearing(stand,tap.to_global(Vector3(x,.75,z))),"native bearer meets retained stand: " + tap.unit)
		if tap.unit in ["2A","4B","5C","1A"]:
			camera.make_current()
			camera.global_position = tap.to_global(Vector3(.6,1.5,-1.4))
			camera.look_at(tap.to_global(Vector3(.12,.88,0)))
			await suite.shot("kitchen_" + tap.unit + "_fit")
			hot.interact(world.player)
			tap._process(.5)
			camera.global_position = tap.to_global(Vector3(.25,1.3,-.55))
			camera.look_at(tap.to_global(Vector3(0,1.01,.10)))
			await suite.shot("kitchen_" + tap.unit + "_hot")
			if tap.unit in ["2A","4B"]:
				tap.set_stopper(true)
				tap._water_level = .85
				tap._process(.25)
				await suite.shot("kitchen_" + tap.unit + "_filled")
		tap.set_hot(bool(saved.hot)); tap.set_cold(bool(saved.cold)); tap.set_stopper(bool(saved.stopper))
		tap._water_level = float(saved.water_level)
		tap.set_boiler_temperature(temperature)
		tap._process(0)
		tap.set_process(processing)
		suite.check(tap.get_flow_state() == saved,"water review restores state: " + tap.unit)
	camera.free()
	world.player.camera.make_current()
	suite.check(count == expected and count > 0,"all authored kitchen sinks reviewed: " + str(count))

func _mesh_hit(mesh: Mesh, start: Vector3, end: Vector3) -> bool:
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			if Geometry3D.segment_intersects_triangle(start,end,points[indices[i]],points[indices[i+1]],points[indices[i+2]]) != null: return true
	return false

func _bearing(stand: Node3D, point: Vector3) -> bool:
	for node: Node in stand.find_children("*","CollisionShape3D",true,false):
		var shape := node as CollisionShape3D
		if shape.shape is ConcavePolygonShape3D:
			var faces := (shape.shape as ConcavePolygonShape3D).get_faces()
			var origin := shape.to_local(point+Vector3.UP*.01)
			var direction := shape.global_basis.inverse()*Vector3.DOWN
			for i in range(0,faces.size(),3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(origin,direction,faces[i],faces[i+1],faces[i+2])
				if hit != null and shape.to_global(hit).distance_to(point)<.003: return true
			continue
		if not shape.shape is BoxShape3D: continue
		var local := shape.to_local(point)
		var half := (shape.shape as BoxShape3D).size * .5
		if absf(local.y-half.y) < .003 and absf(local.x) <= half.x+.001 and absf(local.z) <= half.z+.001: return true
	return false
