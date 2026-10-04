extends "res://tests/orison_v2_roof_bulkhead_caps_test.gd"
## Fixed weather-joint inspection. No whole-roof sealing or drainage proof.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production roof initializes")
	if world.player==null:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root
	var model: Node3D=root.get_node("RoofBaseFlashings")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_base_flashings.json"))
	var native:=PackedVector3Array()
	var bodies: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):bodies.append(body.get_rid())
	var parts:=0
	var triangles:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		parts+=1
		var actual_faces: PackedVector3Array=preload("res://scripts/building/orison_v2_native_faces.gd").read(draw.mesh)
		triangles+=actual_faces.size()/3
		var key: String=draw.get_meta("material_key")
		var material:=draw.material_override as StandardMaterial3D
		check(MatLib.SETS.has(key) and material!=null and not material.uv1_triplanar and material.albedo_texture==(MatLib.get_mat(key) as StandardMaterial3D).albedo_texture,"existing mapped weather material uses its actual local metre chart")
		_check_mapping(draw.mesh,true)
		# Preserve imported local precision without subtracting distant city
		# translations before measuring the thin sheet and its corner joints.
		var pose:=draw.transform
		var parent: Node3D=draw.get_parent()
		while parent!=root:
			pose=parent.transform*pose
			parent=parent.get_parent()
		var bounds: AABB=pose*draw.mesh.get_aabb()
		check(maxf(maxf(bounds.size.x,bounds.size.y),bounds.size.z)<4.00001,"bounded native partition")
		native.append_array(pose*actual_faces)
	check(parts==int(fixture.parts) and triangles==int(fixture.triangles),"installed native draw and triangle counts")
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	for station: Dictionary in fixture.stations:
		var at:=_v(station.wall_point)
		var normal:=_v(station.normal)
		var query:=PhysicsRayQueryParameters3D.create(root.to_global(at+normal*.04),root.to_global(at-normal*.04),1,bodies)
		var hit: Dictionary=space.intersect_ray(query)
		check(not hit.is_empty() and root.to_local(hit.position).distance_to(at)<.00005,"strip back seats on actual retained wall")
		check(absf(_mesh_distance(native,at+normal*.04,-normal)-(.04-float(fixture.sheet_thickness)))<.00005,"native folded upstand retains sheet thickness")
		check(absf(_mesh_distance(native,at-normal*.04,normal)-(.04+float(fixture.sheet_thickness)))<.00005,"original wall owns the omitted strip back contact")
		var foot:=_v(station.foot_point)
		check(absf(_mesh_distance(native,foot-Vector3.UP*.02,Vector3.UP)-.02)<.00005,"original deck owns the omitted strip underside contact")
		query=PhysicsRayQueryParameters3D.create(root.to_global(foot+Vector3.UP*.03),root.to_global(foot-Vector3.UP*.02),1,[world.player.get_rid()])
		hit=space.intersect_ray(query)
		check(not hit.is_empty() and hit.collider.get_parent()==model and root.to_local(hit.position).distance_to(foot)<.00005,"actual roof foot matches native top")
		query.exclude=bodies
		hit=space.intersect_ray(query)
		check(not hit.is_empty() and absf(root.to_local(hit.position).y-(foot.y-float(fixture.sheet_thickness)))<.00005,"roof foot rests on the original floor body's fitted field")
	for edge: Array in fixture.miter_edges:
		for vertex: Array in edge:
			var at:=_v(vertex)
			var nearest:=INF
			var nearest_point:=Vector3.ZERO
			for point: Vector3 in native:
				if point.distance_to(at)<nearest:
					nearest=point.distance_to(at)
					nearest_point=point
			check(nearest<.00002,"native folded corner retains its exact miter edge at "+str(at)+" delta "+str(nearest_point-at)+" gap "+str(nearest))
	# Door openings remain unobstructed through the full source aperture width.
	for record: Dictionary in root.layout.doors:
		if record.id not in ["ROOF_PUBLIC_DOOR","ROOF_SERVICE_DOOR"]:continue
		for offset: float in [-.49,0.,.49]:
			var at:=Vector3(float(record.center[0]),root.get_node(str(record.id)).position.y+.08,float(record.center[1])+offset*float(record.width))
			check(_mesh_distance(native,at-Vector3.RIGHT*.5,Vector3.RIGHT)>1.,"weather strips preserve the full retained doorway")
	var observations: Array[Dictionary]=[]
	for view: Array in [["public_base",Vector3(-3.8,20.61,-1.3),Vector3(-2.27,19.3,-1.3)],
		["service_base",Vector3(8.,20.61,2.3),Vector3(9.43,19.3,2.3)],
		["parapet_corner",Vector3(14.2,20.61,10.2),Vector3(15.49,19.3,11.49)],
		["public_miter_close",Vector3(6.1,19.55,4.55),Vector3(5.48,19.3,3.93)],
		["service_miter_close",Vector3(14.,19.55,11.),Vector3(13.28,19.3,10.28)]]:
		world.player.global_position=root.to_global(view[1])-Vector3.UP*world.player.STANDING_EYE
		world.player.face_world_point(root.to_global(view[2]))
		world.player.set_lamp_enabled(true)
		await _settled_optics()
		await shot(view[0])
		observations.append({"view":view[0],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
		if view[0]=="public_base":
			model.hide()
			await _settled_optics()
			await shot("public_base_before")
			observations.append({"view":"public_base_before","draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
			model.show()
	var file:=FileAccess.open(OS.get_environment("SHOT_DIR").path_join("inspection.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","parts":parts,"triangles":triangles,"checks":checks,"failures":failures,"observations":observations,"startup_ms":world.startup_ms},"\t"))
	print("ROOF BASE FLASHINGS: parts=",parts," triangles=",triangles," checks=",checks," failures=",failures.size())
	for failure: String in failures:print("ROOF BASE FAIL: ",failure)
	world.shutdown_for_tests()
	world.free()
	await _retired_audio()
	get_tree().quit(0 if failures.is_empty() else 1)

func _v(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))
