extends "res://tests/orison_v2_lift_joinery_test.gd"
## Imported airway triangles and authored fabric ports. Static scope only;
## ordinary roof movement, motor authority and lifetime have separate suites.

var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	super.check(ok,message)

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production world initializes")
	if world.player==null:
		world.free()
		get_tree().quit(1)
		return
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false): layer.hide()
	var root: Node3D=world.adapter.root
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/completion_interiors.json"))
	var layout: Dictionary=root.get("layout")
	var ports:=0
	var triangles:=0
	var batches:=0
	var exclusion: Array[RID]=[world.player.get_rid()]
	for stack: CollisionObject3D in root.get_node("VentilationDucts").get_children(): exclusion.append(stack.get_rid())
	for specification: Dictionary in source.ventilation.stacks:
		var identity:=str(specification.id)
		var stack:=root.get_node("VentilationDucts/Stack_"+identity) as StaticBody3D
		var faces:=PackedVector3Array()
		for entry: Array in [["SheetMetal","metal"],["SeamBands","cast_iron"]]:
			var draw:=stack.get_node(entry[0]) as MeshInstance3D
			check(draw!=null and draw.mesh is ArrayMesh,"hollow Blender partition on "+identity)
			if draw==null: continue
			check(draw.material_override==MatLib.get_mat(entry[1]),"existing catalogue material")
			check(draw.get_child_count()==0,"visual partition creates no extra collision or state owner")
			_check_mapping(draw.mesh,true)
			faces.append_array(draw.mesh.get_faces())
			triangles+=draw.mesh.get_faces().size()/3
			batches+=1
		var fan:=world.adapter.resolve("ROOF_VENT_FAN_"+identity) as ExhaustFanProp
		var roof:=root.to_local(fan.global_position)
		var top:=Vector3(specification.riser[0],roof.y-.22,specification.riser[1])
		var lowest:=top.y
		var count:=0
		for record: Dictionary in source.ventilation.registers:
			if record.stack!=identity: continue
			var grille:=root.to_local(world.adapter.resolve(record.anchor).global_position)
			var start:=grille+Vector3.UP*.09
			var end:=Vector3(top.x,start.y,top.z)
			var corner:=Vector3(end.x,start.y,start.z) if specification.branch_axis=="xz" else Vector3(start.x,start.y,end.z)
			lowest=minf(lowest,start.y)
			_clear(faces,grille+Vector3.UP*.035,Vector3.DOWN,.09,"register mouth: "+str(record.anchor))
			var side:=_mesh_distance(faces,grille+Vector3.UP*.035,Vector3(1,0,1).normalized())
			check(is_finite(side) and absf(side-.168*sqrt(2.0))<.001,"plenum corner remains sheet beside branch opening")
			for leg: Array in [[start,corner],[corner,end]]:
				var length: float=leg[0].distance_to(leg[1])
				if length<.001: continue
				var direction: Vector3=(leg[1]-leg[0]).normalized()
				_clear(faces,leg[0]+direction*.002,direction,length-.003,"branch and seam lumen reaches junction")
				if length>.5:
					var wall:=_mesh_distance(faces,(leg[0]+leg[1])*.5,Vector3.UP)
					check(is_finite(wall) and absf(wall-.088)<.001,"180 mm branch retains its 2 mm upper sheet")
			ports+=1
			count+=1
		check(stack.get_meta("registers").size()==count,"existing register roster stays with its geographic motor")
		_clear(faces,Vector3(top.x,lowest+.002,top.z),Vector3.UP,top.y-lowest-.003,"vertical stack and seam lumen reaches roof junction")
		var roof_corner:=Vector3(roof.x,top.y,top.z)
		var roof_end:=Vector3(roof.x,top.y,roof.z)
		for leg: Array in [[top,roof_corner],[roof_corner,roof_end]]:
			var length: float=leg[0].distance_to(leg[1])
			if length<.001: continue
			var direction: Vector3=(leg[1]-leg[0]).normalized()
			_clear(faces,leg[0]+direction*.002,direction,length-.003,"roof branch lumen")
		_clear(faces,roof_end+Vector3.UP*.002,Vector3.UP,.50,"roof uptake opens through flashing")
		var paint:=fan.get("fabricated").get_node("Paint") as MeshInstance3D
		_check_mapping(paint.mesh)
		_clear(paint.mesh.get_faces(),Vector3(.015,.40,.015),Vector3.DOWN,.5,"curb and flashing throat is open")
		var rim:=_mesh_distance(paint.mesh.get_faces(),Vector3(.13,.40,.015),Vector3.DOWN)
		check(is_finite(rim) and absf(rim-.231)<.001,"flashing remains supported beside throat")
		exclusion.append(fan.get_node("PlantCollision").get_rid())
		var aperture:=PhysicsRayQueryParameters3D.create(root.to_global(roof+Vector3.UP*.12),root.to_global(roof-Vector3.UP*.15),1,exclusion)
		var hole: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(aperture)
		check(hole.is_empty(),"actual deck and chase physics clear the fitted fan mouth: "+identity)
		var rim_at:=roof+Vector3.RIGHT*.12
		var support:=PhysicsRayQueryParameters3D.create(root.to_global(rim_at+Vector3.UP*.12),root.to_global(rim_at-Vector3.UP*.15),1,exclusion)
		var bearing: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(support)
		check(not bearing.is_empty() and absf(root.to_local(bearing.position).y-roof.y)<.001,"walking deck remains immediately beside 200 mm aperture")
	for opening: Dictionary in layout.slab_openings:
		var draw:=root.get_node(str(opening.space)+"/"+str(opening.surface)) as MeshInstance3D
		var cut: Array=opening.rect
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		var faces:=pose*draw.mesh.get_faces()
		var at:=Vector3((cut[0]+cut[2])*.5,19.5,(cut[1]+cut[3])*.5)
		_clear(faces,at,Vector3.DOWN,.6,"actual slab triangles clear their declared service aperture")
	var chase_faces:=PackedVector3Array()
	for draw: MeshInstance3D in root.get_node("WEST_WET_STACK").find_children("*","MeshInstance3D",true,false):
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		chase_faces.append_array(pose*draw.mesh.get_faces())
	for z in [3.65,5.8]:
		_clear(chase_faces,Vector3(-6.175,5.9,z),Vector3.UP,13.3,"west chase admits the authored stack")
		var wall:=_mesh_distance(chase_faces,Vector3(-6.175,8,z),Vector3.RIGHT)
		check(is_finite(wall) and absf(wall-.10)<.001,"masonry remains beside chase bore")
	check(ports==23 and batches==8,"all 23 source registers retain eight geographic visual draws")
	await _capture(world,root)
	print("VENTILATION THROATS: checks=%d ports=%d batches=%d imported_triangles=%d failures=%d" % [checks,ports,batches,triangles,failures.size()])
	world.shutdown_for_tests()
	world.free()
	await _retired_audio()
	get_tree().quit(0 if failures.is_empty() else 1)

func _clear(faces: PackedVector3Array, at: Vector3, direction: Vector3, length: float, message: String) -> void:
	var hit:=_mesh_distance(faces,at,direction)
	check(not is_finite(hit) or hit>=length,message)

func _check_mapping(mesh: Mesh, check_derivatives: bool=false) -> void:
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
		check(vertices.size()>8 and normals.size()==vertices.size() and uv.size()==vertices.size() and tangents.size()==vertices.size()*4,"active UV, normal and tangent on imported vertices")
		var valid:=true
		for i in vertices.size():
			valid=valid and vertices[i].is_finite() and uv[i].is_finite() and absf(normals[i].length()-1)<.001
			if tangents.size()==vertices.size()*4:
				var tangent:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				valid=valid and tangent.is_finite() and absf(tangent.length()-1)<.001 and absf(tangent.dot(normals[i]))<.001 and absf(absf(tangents[i*4+3])-1)<.001
		check(valid,"finite unit normals and orthogonal tangent handedness")
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var mapped:=true
		var widest:=0.0
		var excess:=0.0
		var derivatives:=true
		for triangle in range(0,indices.size(),3):
			if check_derivatives:
				var a:=indices[triangle]
				var b:=indices[triangle+1]
				var c:=indices[triangle+2]
				var first:=vertices[b]-vertices[a]
				var second:=vertices[c]-vertices[a]
				var uv_first:=uv[b]-uv[a]
				var uv_second:=uv[c]-uv[a]
				var determinant:=uv_first.x*uv_second.y-uv_second.x*uv_first.y
				derivatives=derivatives and absf(determinant)>1e-12
				if absf(determinant)>1e-12:
					var expected: Vector3=(first*uv_second.y-second*uv_first.y)/determinant
					var bitangent: Vector3=(second*uv_first.x-first*uv_second.x)/determinant
					for index: int in [a,b,c]:
						var projected: Vector3=(expected-normals[index]*expected.dot(normals[index])).normalized()
						var actual:=Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
						derivatives=derivatives and projected.dot(actual)>.999
						derivatives=derivatives and normals[index].cross(actual).dot(bitangent)*tangents[index*4+3]>0
			for edge in 3:
				var a:=indices[triangle+edge]
				var b:=indices[triangle+(edge+1)%3]
				var length:=vertices[a].distance_to(vertices[b])
				var texture:=uv[a].distance_to(uv[b])
				mapped=mapped and texture<=length+.00005
				excess=maxf(excess,texture-length)
				if length>.01: widest=maxf(widest,texture/length)
		check(mapped and absf(widest-1)<.005,"planar mapping retains one texture metre per model metre")
		if check_derivatives: check(derivatives,"tangent direction and handedness match actual imported UV derivatives")
		print("THROAT MAPPING: mesh=",mesh.resource_name," valid_basis=",valid," max_uv_excess=",excess," widest=",widest)

func _capture(world: Node3D,root: Node3D) -> void:
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	for identity: String in ["A","B","C","D"]:
		var fan:=world.adapter.resolve("ROOF_VENT_FAN_"+identity) as Node3D
		camera.global_position=fan.to_global(Vector3(.85,1.524,-.90))
		camera.look_at(fan.to_global(Vector3(0,.45,0)))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
		await shot(identity+"_roof_view")
		camera.global_position=fan.to_global(Vector3(.015,.40,.015))
		camera.look_at(fan.to_global(Vector3(0,.08,0)),Vector3.FORWARD)
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
		world.player.camera.global_transform=camera.global_transform
		world.player.set_lamp_enabled(true)
		await _settled_optics()
		await shot(identity+"_inside_throat")
		world.player.set_lamp_enabled(false)
		await _settled_optics()
	# Record the source-fitted second-floor branch without adding fill lighting.
	camera.global_position=root.to_global(Vector3(-7.35,4.724,4.0))
	camera.look_at(root.to_global(Vector3(-6.8,5.89,4.375)))
	world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
	await shot("second_floor_branch")
	print("VENTILATION INSPECTION: startup_ms=",world.startup_ms)

func _retired_audio() -> void:
	await get_tree().create_timer(.25).timeout

func _settled_optics() -> void:
	# Rendering settlement only; this scope references no mechanism or actor.
	await get_tree().create_timer(.8).timeout
