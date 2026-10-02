extends "res://tests/orison_v2_ventilation_throat_test.gd"
## Existing light bodies, imported conduit, actual fabric bearings and sleeves.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world=_world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production initializes with independent bodega services")
	if world.player==null:
		world.free()
		get_tree().quit(1)
		return
	world.player.set_physics_process(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false): layer.hide()
	var cell: Node3D=world.exterior_cell.instance_node("SHOP_BODEGA")
	var power: Node3D=world.get_node("BodegaPower")
	var receiving: Node3D=world.get_node("BodegaReceiving")
	check(not power.startup_failed and power.global_transform.is_equal_approx(cell.global_transform),"power uses the actual registered shop frame")
	var draws=power.model.find_children("*","MeshInstance3D",true,false)
	check(draws.size()==3,"three shared catalogued service partitions")
	var triangles:=0
	var faces:=PackedVector3Array()
	for draw: MeshInstance3D in draws:
		var key:=str(draw.name).get_slice("__",1)
		check(draw.material_override==MatLib.get_mat(key),"catalogue material on "+key)
		_check_mapping(draw.mesh,true)
		triangles+=draw.mesh.get_faces().size()/3
		faces.append_array(draw.mesh.get_faces())
	check(power.find_children("*","Light3D",true,false).is_empty()
		and power.find_children("*","Area3D",true,false).is_empty(),"fixed fabrication adds no light or interactive electrical authority")
	var rear: Node3D=power.model.find_child("RearWallPort",true,false)
	var partition: Node3D=power.model.find_child("PartitionPort",true,false)
	for port: Node3D in [rear,partition]:
		var at:=port.position
		var hit:=_fabric_ray(world,cell,at-Vector3(0,0,.20),at+Vector3(0,0,.20))
		check(hit.is_empty(),"actual fabric sleeve stays clear at "+str(port.name))
		for dx in [-.035,.035]:
			hit=_fabric_ray(world,cell,at+Vector3(dx,0,-.20),at+Vector3(dx,0,.20))
			check(not hit.is_empty(),"wall fabric remains beside "+str(port.name))
		var metal:=_mesh_distance(faces,at,Vector3.RIGHT)
		var inner_radius:=.0105 if port==rear else .0078
		check(is_finite(metal) and absf(metal-inner_radius)<.0005,"hollow metal sleeve encloses the crossing at its authored radius")
	var bearings:=0
	for bearing: Node3D in power.model.find_children("Bearing_*","Node3D",true,false):
		var at:=bearing.position
		var ceiling:=at.y>3
		var normal:=Vector3.UP if ceiling else Vector3.FORWARD
		var hit:=_fabric_ray(world,cell,at-normal*.035,at+normal*.035)
		check(not hit.is_empty(),"support seats on actual fabric: "+str(bearing.name))
		if not hit.is_empty():
			check(cell.to_local(hit.position).distance_to(at)<.005,"support bearing is flush")
		bearings+=1
	check(bearings==power.bearing_count and bearings==20,"twenty supported stations retained")
	for bearing: Node3D in power.model.find_children("CabinetBearing_*","Node3D",true,false):
		var at:=bearing.position
		var hit:=_fabric_ray(world,cell,at+Vector3(0,0,.025),at-Vector3(0,0,.025))
		check(not hit.is_empty(),"service enclosure screws bear on existing rear wall")
		if not hit.is_empty():check(cell.to_local(hit.position).distance_to(at)<.005,"enclosure wall flange is flush")
	for name: String in ["front","middle","back","receiving"]:
		var target: Node3D=power.model.find_child("Fixture_"+name,true,false)
		check(target!=null,"existing fitting has a physical termination: "+name)
		var owner: MeshInstance3D
		if name=="receiving":
			owner=receiving.find_child("Receiving__cast_iron",true,false)
		else:
			for child in cell.get_children():
				if child is MeshInstance3D and child.get_meta("authored_record_id","")=="ceiling_practical_"+name:owner=child
		check(owner!=null,"original fitting owner remains")
		if owner!=null:
			var direction:=Vector3.LEFT if name=="receiving" else Vector3.DOWN
			var at:=owner.to_local(cell.to_global(target.position-direction*.025))
			var distance:=_mesh_distance(owner.mesh.get_faces(),at,owner.global_basis.inverse()*cell.global_basis*direction)
			check(is_finite(distance) and absf(distance-.020)<.001,"threaded drop contacts the actual original fitting")
	check(world.exterior_cell.shop_service==world.shop_service
		and world.exterior_cell.maintenance_inventory==world.maintenance_inventory,"existing shop/inventory owners remain")
	await _capture_bodega(world,cell)
	print("BODEGA POWER: checks=",checks," fittings=4 bearings=",bearings," draws=",draws.size()," triangles=",triangles," failures=",failures.size())
	world.shutdown_for_tests()
	world.free()
	await _retired_audio()
	get_tree().quit(0 if failures.is_empty() else 1)

func _fabric_ray(world: Node3D,cell: Node3D,a: Vector3,b: Vector3) -> Dictionary:
	var power: Node3D=world.get_node("BodegaPower")
	var ray:=PhysicsRayQueryParameters3D.create(cell.to_global(a),cell.to_global(b),1,
		[world.player.get_rid(),power.get_node("ServiceEnclosureCollision").get_rid()])
	return world.get_world_3d().direct_space_state.intersect_ray(ray)

func _capture_bodega(world: Node3D,cell: Node3D) -> void:
	for entry: Array in [["service_wall",Vector3(.8,1.50,-11.5),Vector3(1.6875,1.70,-12.54)],
		["receiving_crossing",Vector3(.25,1.50,-11.85),Vector3(1.6875,3.10,-10.56)],
		["shop_distribution",Vector3(0,1.50,-8),Vector3(.8,3.0,-5.35)],
		["front_fitting",Vector3(0,1.50,-3.7),Vector3(.5,2.98,-2)]]:
		world.player.global_position=cell.to_global(entry[1]-Vector3.UP*1.5)
		world.player.camera.global_position=cell.to_global(entry[1])
		world.player.camera.look_at(cell.to_global(entry[2]))
		world.player.set_lamp_enabled(true)
		await _settled_optics()
		await shot(entry[0])
