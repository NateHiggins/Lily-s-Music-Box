extends Node3D
## Imported physical seat faces against original wall planes, all eight variants.
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	RealityState.persistence_enabled=false
	var factory:=preload("res://scripts/building/orison_v2_kitchen_plumbing.gd").new();factory.load_source()
	var rows: Array=[];var failures: Array[String]=[];var checks:=0
	# Preserve the generic fixture's original per-valve closed threshold.
	# Two sub-threshold openings must not sum into a running hot fixture.
	var tap:=TapProp.new();tap.set_stopper(true);tap.set_boiler_temperature(.8)
	tap.set_valve_opening(0,.00006);tap.set_valve_opening(1,.00006)
	checks+=1
	if tap.get_flow_state().temperature!=0. or tap.get_flow_state().hot or tap.get_flow_state().cold:failures.append("generic below-threshold controls changed temperature/flow flags")
	tap._process(1.);checks+=1
	if tap.get_flow_state().water_level!=0.:failures.append("generic below-threshold controls admitted basin inflow")
	tap.free()
	for template: Dictionary in factory.source.templates:
		var owner:=Node3D.new();add_child(owner)
		var body:=StaticBody3D.new();owner.add_child(body);factory._visuals(body,str(template.id),true)
		var wall:=StaticBody3D.new();add_child(wall)
		var box:=BoxShape3D.new();box.size=Vector3(1.5,1.6,.18)
		var shape:=CollisionShape3D.new();shape.shape=box;shape.position=Vector3(0,.8,float(template.wall_z)+.09);wall.add_child(shape)
		await get_tree().physics_frame;await get_tree().physics_frame
		for port: Vector3 in [Vector3(.04,.64+float(template.rim_y)-.9,float(template.wall_z)),Vector3(-.076,.22,float(template.wall_z)),Vector3(.114,.22,float(template.wall_z))]:
			var original:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(port-Vector3.BACK*.08,port+Vector3.BACK*.015,1,[body.get_rid()]))
			var rear:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(port+Vector3.BACK*.5,port-Vector3.BACK*.5,1,[wall.get_rid()]))
			var front:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(port-Vector3.BACK*.5,port+Vector3.BACK*.5,1,[wall.get_rid()]))
			var thickness:=.009 if is_equal_approx(port.x,.04) else .006
			for pair: Array in [[original,wall,port],[rear,body,port],[front,body,port-Vector3.BACK*thickness]]:
				checks+=1
				if pair[0].is_empty() or pair[0].collider!=pair[1] or pair[0].position.distance_to(pair[2])>.00004:failures.append(str(template.id)+str(port)+str(pair[0]))
			rows.append({"template":template.id,"port":str(port),"rear_error":rear.position.distance_to(port) if not rear.is_empty() else -1.})
		owner.free();wall.free()
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("contacts.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"rows":rows},"\t"))
	print("PLUMBING CONTACTS ",checks," checks; ",failures.size()," failures");get_tree().quit(0 if failures.is_empty() else 1)
