extends "res://tests/orison_v2_city_sweep.gd"
## Native ownership, actual wall bearings, thin cloth charts and retained signals.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"source-fitted stage curtains compose in the production city")
	if world.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var bar: OrisonV2BarRegion=world.bar_region;var cell: Node3D=bar.get_node("RetainedBarGeometry");var model: Node3D=cell.get_node("BarStage")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bar_stage.json"))
	check(FileAccess.get_sha256("res://assets/props/bar_stage.glb")==fixture.asset_sha256,"installed export matches the inspectable native fixture")
	var removed:=0
	for id: String in model.get_meta("removed_triangles"):
		check(int(model.get_meta("removed_triangles")[id])==12,"only one original box boundary is retired: "+id);removed+=12
	check(removed==204,"all seventeen curtain/pelmet boundaries have one replacement")
	for draw: MeshInstance3D in model.get_meta("original_meshes"):
		var original: Mesh=model.get_meta("original_meshes")[draw]
		var before: Array=original.get("_surfaces");var after: Array=draw.mesh.get("_surfaces")
		check(original.get_faces().size()/3==252 and draw.mesh.get_faces().size()/3==48,"restroom retains all forty-eight original triangles")
		check(before.size()==after.size(),"source material surface count remains")
		for surface in before.size():
			for key: String in before[surface]:
				if key in ["index_data","index_count","lods","material"]:continue
				check(before[surface][key]==after[surface][key],"unselected source buffers and decoding metadata are exact: "+key)
		var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
		check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces(),"retained restroom has one exact physical owner")
	var excluded: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body is Area3D or model.is_ancestor_of(body):excluded.append(body.get_rid())
	var parts:=0;var triangles:=0;var cloth_draw: MeshInstance3D;var iron_draw: MeshInstance3D
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var name:=str(draw.get_meta("bar_stage_part"));var part: Dictionary=fixture.parts.filter(func(row):return str(row.name)==name)[0]
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		check(draw.mesh.get_faces().size()==int(part.triangles)*3,"precise native partition retains its triangles: "+name)
		var material:=draw.mesh.surface_get_material(0) as StandardMaterial3D;var catalog:=MatLib.get_mat(str(part.key))
		check(material!=null and material!=catalog and not material.uv1_triplanar and catalog.uv1_triplanar,"local charts preserve shared library projection: "+name)
		check(material.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)),"local chart uses catalogue metre scale: "+name)
		check(material.albedo_texture==catalog.albedo_texture and material.roughness_texture==catalog.roughness_texture and material.normal_texture==catalog.normal_texture,"all three original maps reach the native stock: "+name)
		check(material.metallic==catalog.metallic and material.roughness==catalog.roughness and material.normal_scale==catalog.normal_scale,"catalogue optical settings remain: "+name)
		if str(part.key)=="fabric_warm":
			cloth_draw=draw;var tint: Array=part.tint
			check(material.albedo_color.is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3])),"heavy cloth receives only its scoped red tint")
			_check_cloth_chart(draw.mesh)
		else:_check_cap_mapping(draw.mesh,true)
		if str(part.key)=="iron_blackened":iron_draw=draw
		var shapes:=draw.find_children("*","CollisionShape3D",true,false)
		check(shapes.size()==1 and (shapes[0].shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shapes[0].global_transform.is_equal_approx(draw.global_transform),"visible native faces have one coincident collider: "+name)
	check(parts==3 and triangles==int(fixture.triangles),"entire installation is batched into three shipping partitions")
	var bearings:=0;var iron_faces:=iron_draw.mesh.get_faces()
	for contact: Dictionary in fixture.contacts:
		var at:=GameBoot.b2g(contact.point);var n:=GameBoot.b2g(contact.normal)
		for dx: float in [-float(contact.half_width),0.,float(contact.half_width)]:
			for dz: float in [-float(contact.half_height),0.,float(contact.half_height)]:
				var offset:=Vector3(dx,dz,0)
				var ray:=PhysicsRayQueryParameters3D.create(cell.to_global(at+n*.004+offset),cell.to_global(at-n*.004+offset),1,excluded)
				var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
				check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at+offset)<.00003,"entire plate seats on the actual retained wall")
				check(absf(_mesh_distance(iron_faces,at-n*.004+offset,n)-.004)<.00003,"native plate starts on its supporting wall")
				bearings+=2
	# Check actual face samples rather than filling the dado-clearance bend
	# with an artificial rectangular proxy. Native BVH checks all intersections.
	var sphere:=SphereShape3D.new();sphere.radius=.0002
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=sphere;query.exclude=excluded;query.collision_mask=1
	var cloth_faces:=cloth_draw.mesh.get_faces();var clear_samples:=0;var blocked:=0
	for i in range(0,cloth_faces.size(),3):
		for at: Vector3 in [cloth_faces[i],(cloth_faces[i]+cloth_faces[i+1]+cloth_faces[i+2])/3.]:
			query.transform=Transform3D(cell.global_basis,cell.to_global(at))
			var hits:=world.get_world_3d().direct_space_state.intersect_shape(query,1)
			if not hits.is_empty():
				blocked+=1
				if blocked<4:print("STAGE CLOTH BLOCKER ",hits[0].collider.get_path()," at=",at)
			clear_samples+=1
	check(blocked==0,"actual cloth face and corner samples clear retained physical fabric")
	var sign_actor: NeonSignProp=bar.actors.get_node("F01_BAR_STAGE_SIGN")
	var low:=Vector3(INF,INF,INF);var high:=-low
	for draw: MeshInstance3D in sign_actor.find_children("*","MeshInstance3D",true,false):
		for vertex: Vector3 in draw.mesh.get_faces():
			var at:=bar.to_local(draw.to_global(vertex));low=low.min(at);high=high.max(at)
	check(GameBoot.b2g(fixture.sign_bounds[0]).distance_to(Vector3(low.x,low.y,high.z))<.00003 and GameBoot.b2g(fixture.sign_bounds[1]).distance_to(Vector3(high.x,high.y,low.z))<.00003,"retained sign geometry has the original measured bounds")
	for vertex: Vector3 in cloth_faces:
		if vertex.y>=low.y and vertex.y<=high.y:check(vertex.z>high.z+.014,"cloth at signal height stays behind the complete retained hardware")
	for marker: Dictionary in fixture.markers:
		var actor: Node3D=bar.actors.get_node(str(marker.id))
		check(actor.position.distance_to(GameBoot.b2g(marker.pos))<.000001 and absf(angle_difference(actor.rotation.y,-deg_to_rad(float(marker.yaw_deg))))<.000001,"source signal actor position and orientation remain: "+str(marker.id))
	check(sign_actor.sign_text=="HARUKIYA" and not sign_actor.vertical,"original sign text and signal state owner remain")
	var glyphs:=sign_actor._letters.size()
	sign_actor._perform_synced_event(2,.7,220.)
	check(sign_actor._letters.size()==glyphs and glyphs==8 and sign_actor._surge>=.7,"original eight-glyph signal owner responds to motif input")
	await _stage_views(world,bar)
	print("BAR STAGE: checks=",checks," stocks=",fixture.stocks.size()," parts=",parts," triangles=",triangles," removed=",removed," bearing_samples=",bearings," cloth_clearance_samples=",clear_samples," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _check_cloth_chart(mesh: Mesh) -> void:
	var arrays:=mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	check(vertices.size()==normals.size() and vertices.size()==uv.size() and tangents.size()==vertices.size()*4,"cloth has a complete continuous chart and native tangent basis")
	var valid:=true;var derivatives:=true;var metric_samples:=0;var metric_bad:=0
	for index in vertices.size():
		var tangent:=Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
		valid=valid and vertices[index].is_finite() and uv[index].is_finite() and absf(normals[index].length()-1)<.001 and absf(tangent.length()-1)<.001 and absf(tangent.dot(normals[index]))<.001
	for start in range(0,indices.size(),3):
		var a:=indices[start];var b:=indices[start+1];var c:=indices[start+2]
		var e1:=vertices[b]-vertices[a];var e2:=vertices[c]-vertices[a];var u1:=uv[b]-uv[a];var u2:=uv[c]-uv[a];var determinant:=u1.x*u2.y-u2.x*u1.y
		derivatives=derivatives and absf(determinant)>1e-12
		if absf(determinant)>1e-12:
			var expected: Vector3=(e1*u2.y-e2*u1.y)/determinant
			for index: int in [a,b,c]:
				var projected: Vector3=(expected-normals[index]*expected.dot(normals[index])).normalized();var actual:=Vector3(tangents[index*4],tangents[index*4+1],tangents[index*4+2])
				derivatives=derivatives and projected.dot(actual)>.98
		# The sewn header gathers an unfolded chart. In the constant lower
		# pleats, horizontal fibres retain actual arc length within one percent.
		if vertices[a].y<-2. and vertices[b].y<-2. and absf(vertices[a].y-vertices[b].y)<.00001 and absf(uv[a].y-uv[b].y)<.00001 and vertices[a].distance_to(vertices[b])>.008:
			metric_samples+=1
			if absf(uv[a].distance_to(uv[b])/vertices[a].distance_to(vertices[b])-1.)>.01:metric_bad+=1
	check(valid and derivatives,"cloth basis matches nondegenerate imported UV derivatives")
	check(metric_samples>500 and metric_bad==0,"lower folded cloth retains its unfolded physical metre chart")
	print("CLOTH MAPPING: valid=",valid," derivatives=",derivatives," metric_samples=",metric_samples," bad=",metric_bad)

func _stage_views(world: OrisonV2RuntimeRoot,bar: Node3D) -> void:
	for view: Array in [["front",Vector3(-.7,-2.775,35.1),Vector3(-.7,-1.1,37.7)],["left",Vector3(-3.5,-2.775,35.5),Vector3(-1.8,-1.0,37.7)],["right",Vector3(.65,-2.775,35.3),Vector3(.65,-1.0,37.7)],["header",Vector3(-.7,-2.775,35.8),Vector3(-.7,-.38,37.7)]]:
		var feet: Vector3=view[1];var clear:=false
		for delta: Vector3 in [Vector3.ZERO,Vector3(0,0,.4),Vector3(0,0,.8),Vector3(0,0,-.4),Vector3(.4,0,0),Vector3(-.4,0,0),Vector3(1.2,0,.4),Vector3(-1.2,0,.4)]:
			if _city_clear_station(world,bar.to_global(feet+delta)):feet+=delta;clear=true;break
		check(clear,"installed stage view uses a clear ordinary standing capsule: "+str(view[0]))
		if not clear:continue
		world.player.global_position=bar.to_global(feet);world.player.face_world_point(bar.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0])+"_installed")
