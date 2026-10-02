extends "res://tests/orison_v2_ventilation_throat_test.gd"
## Full 172 mm duct volume and all 23 plenum interiors against actual fabric.
## Imported lining/masonry mapping is checked in production. Static construction
## scope; no airflow, pressure, weather, complete utility or ledger claim.

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production composition initializes")
	if world.player==null: world.free(); get_tree().quit(1); return
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false): layer.hide()
	var root: Node3D=world.adapter.root
	var graph: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/completion_interiors.json")).ventilation
	var legs: Array=[]
	var volumes: Array=[]
	var excludes: Array[RID]=[world.player.get_rid()]
	var lining_triangles:=0
	for spec: Dictionary in graph.stacks:
		var stack:=root.get_node("VentilationDucts/Stack_"+str(spec.id)) as StaticBody3D
		excludes.append(stack.get_rid())
		var lining:=stack.get_node("FabricLining") as MeshInstance3D
		check(lining.material_override==MatLib.get_mat("metal") and lining.get_child_count()==0,"lining has one existing material and no new state, light or collision")
		_check_mapping(lining.mesh,true)
		lining_triangles+=lining.mesh.get_faces().size()/3
		var fan:=world.adapter.resolve("ROOF_VENT_FAN_"+str(spec.id)) as Node3D
		excludes.append(fan.get_node("PlantCollision").get_rid())
		var roof:=root.to_local(fan.global_position)
		var top:=Vector3(spec.riser[0],roof.y-float(graph.roof_branch_drop_m),spec.riser[1])
		var lowest:=top.y
		for record: Dictionary in graph.registers:
			if record.stack!=spec.id: continue
			var grille:=root.to_local(world.adapter.resolve(record.anchor).global_position)
			volumes.append([str(record.anchor)+"_plenum",AABB(grille+Vector3(-.178,.002,-.168),Vector3(.356,.086,.336))])
			var start:=grille+Vector3.UP*.09
			lowest=minf(lowest,start.y)
			var end:=Vector3(top.x,start.y,top.z)
			var corner:=Vector3(end.x,start.y,start.z) if spec.branch_axis=="xz" else Vector3(start.x,start.y,end.z)
			legs.append([str(record.anchor)+"_1",start,corner]);legs.append([str(record.anchor)+"_2",corner,end])
		var corner:=Vector3(roof.x,top.y,top.z)
		var end:=Vector3(roof.x,top.y,roof.z)
		legs.append([str(spec.id)+"_stem",Vector3(top.x,lowest,top.z),top])
		legs.append([str(spec.id)+"_roof1",top,corner]);legs.append([str(spec.id)+"_roof2",corner,end])
		legs.append([str(spec.id)+"_uptake",end,roof+Vector3.UP*.169])
	var traced:=0
	var physics_samples:=0
	for leg: Array in legs:
		var a: Vector3=leg[1]
		var b: Vector3=leg[2]
		if a.distance_to(b)<.001: continue
		traced+=1
		volumes.append([leg[0],AABB(a,Vector3.ZERO).expand(b).grow(.086)])
		var axis: int=(b-a).abs().max_axis_index()
		var hits: Array=[]
		for du: float in [-.086,0.0,.086]:
			for dv: float in [-.086,0.0,.086]:
				var offset:=Vector3.ZERO;offset[(axis+1)%3]=du;offset[(axis+2)%3]=dv
				var ray:=PhysicsRayQueryParameters3D.create(root.to_global(a+offset),root.to_global(b+offset),1,excludes)
				ray.hit_from_inside=true
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty(): hits.append(str(world.get_path_to(hit.collider)))
				physics_samples+=1
		check(hits.is_empty(),"full-bore physics: "+str(leg[0])+" "+str(hits))
	var owners: Dictionary={"ExteriorMasonry":true}
	for table: String in ["spaces","risers","anchors"]:
		for record: Dictionary in root.layout[table]: owners[str(record.id)]=true
	var tested_draws:=0
	var tested_triangles:=0
	var obstructions: Dictionary={}
	for draw: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null or not draw.is_visible_in_tree(): continue
		var path:=str(root.get_path_to(draw))
		var owner:=path.get_slice("/",0)
		if not owners.has(owner) and draw.name!="FabricLining": continue
		# The grille is the deliberate open receptor boundary; moving roof fans
		# have their own imported throat/motor tests, rather than a solid-free fan.
		if owner.begins_with("ROOF_VENT_FAN_") or owner.ends_with("_VENT_REGISTER"): continue
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		var bound: AABB=pose*draw.mesh.get_aabb()
		var relevant: Array=[]
		for volume: Array in volumes:
			if bound.intersects(volume[1]): relevant.append(volume)
		if relevant.is_empty(): continue
		tested_draws+=1
		var faces:=pose*draw.mesh.get_faces()
		tested_triangles+=faces.size()/3
		if owner=="ExteriorMasonry": _check_mapping(draw.mesh,true)
		for volume: Array in relevant:
			for index in range(0,faces.size(),3):
				if _triangle_in_box(faces[index],faces[index+1],faces[index+2],volume[1]):
					obstructions[str(volume[0])+" -> "+path]=true
	for volume: Array in volumes:
		var hits: Array=[]
		for hit: String in obstructions:
			if hit.begins_with(str(volume[0])+" -> "):hits.append(hit)
		check(hits.is_empty(),"actual triangle volume: "+str(volume[0])+" "+str(hits))
	check(traced==59 and volumes.size()==82 and physics_samples==531,"all source branches, four stems/roof routes and 23 complete plenums are checked")
	var ventilation_wall_ports:=0
	for port: Dictionary in root.layout.wall_service_openings:
		if str(port.id).get_slice("_",0)=="VENT":ventilation_wall_ports+=1
	check(ventilation_wall_ports==67 and root.layout.masonry_service_openings.size()==26,"all reviewed ventilation structural owners retain their bounded ports in the shared table")
	var shower:=world.adapter.resolve("F03_3D_SHOWER_01") as Node3D
	check(absf(root.to_local(shower.global_position).z+11.84)<.0001,"retained third-floor shower clears the original north stack")
	await _capture(world,root)
	print("VENTILATION FABRIC: checks=%d legs=%d plenums=23 draws=%d tested_triangles=%d lining_triangles=%d physics_samples=%d obstructions=%d failures=%d" % [checks,traced,tested_draws,tested_triangles,lining_triangles,physics_samples,obstructions.size(),failures.size()])
	world.shutdown_for_tests();world.free()
	await _retired_audio()
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture(world: Node3D,root: Node3D) -> void:
	await super._capture(world,root)
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current()
	for view: Array in [
		["upper_B",Vector3(-7.7,17.524,-10.1),Vector3(-6.4,18.98,-11.8)],
		["upper_D",Vector3(14.15,17.524,-10.1),Vector3(15.3,18.98,-11.8)],
		["third_floor_shower",Vector3(-7.8,7.924,-10.4),Vector3(-6.1,7.5,-12.25)],
		["fourth_floor_shower",Vector3(-7.8,11.124,-10.4),Vector3(-6.1,10.7,-12.25)],
		["second_floor_C_wall",Vector3(-7.8,4.724,4.9),Vector3(-6.1,5.89,5.8)],
		["third_floor_C_wall",Vector3(-7.8,7.924,4.9),Vector3(-6.1,9.09,5.8)],
		["public_branch_kitchen",Vector3(10.5,1.524,-5),Vector3(11.15,2.8,-6.1)]]:
		camera.global_position=root.to_global(view[1]);camera.look_at(root.to_global(view[2]))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
		world.player.camera.global_transform=camera.global_transform
		world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0])

static func _triangle_in_box(a: Vector3,b: Vector3,c: Vector3,box: AABB) -> bool:
	# Triangle/AABB separating-axis test. A coarse transformed draw bound is
	# never treated as an obstruction to a hole in that draw's actual surface.
	var low:=a.min(b).min(c)
	var high:=a.max(b).max(c)
	for axis in 3:
		if high[axis]<=box.position[axis]+.000001 or low[axis]>=box.end[axis]-.000001:return false
	var center:=box.get_center();var half:=box.size*.5
	var points: Array[Vector3]=[a-center,b-center,c-center]
	var edges: Array[Vector3]=[b-a,c-b,a-c]
	var axes: Array[Vector3]=[edges[0].cross(edges[1])]
	for edge: Vector3 in edges:
		for basis: Vector3 in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]: axes.append(edge.cross(basis))
	for axis: Vector3 in axes:
		var first:=axis.dot(points[0]);var second:=axis.dot(points[1]);var third:=axis.dot(points[2])
		var radius:=axis.abs().dot(half)
		if minf(first,minf(second,third))>radius+.0000001 or maxf(first,maxf(second,third))< -radius-.0000001:return false
	return true
